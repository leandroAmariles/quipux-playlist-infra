# shellcheck shell=bash
# Invocación de Terraform. La salida completa puede contener secretos: se guarda en .local/logs/ y a la terminal solo
# llegan el progreso, el resumen y los errores.

tf_log_file() {
  printf '%s/%s-%s-%s.log' "$LOG_DIR" "$(date +%Y%m%d-%H%M%S)" "$1" "$2"
}

# Deja pasar progreso, resumen y errores. Quita los identificadores y las líneas de código de los errores, que
# reproducen el valor escrito en local.tfvars.
tf_filter() {
  awk '
    /^[^A-Za-z0-9]*Error: / { in_error = 1 }
    in_error {
      if ($0 !~ /^[^A-Za-z0-9]*[0-9]+: /) { print; fflush() }
      next
    }
    /^(Plan:|Apply complete!|Destroy complete!|No changes\.)/ { print "    " $0; fflush(); next }
    /^[a-z0-9_]+\.[][A-Za-z0-9_.]+: (Creating|Creation complete|Destroying|Destruction complete|Modifying|Modifications complete|Still )/ {
      sub(/ \[id=[^]]*\]/, "")
      print "    " $0
      fflush()
    }
  '
}

tf_init() {
  local root="$1" log
  log="$(tf_log_file "$root" init)"
  if ! terraform -chdir="terraform/$root" init -input=false -no-color >"$log" 2>&1; then
    tf_filter <"$log" >&2
    die "terraform init falló en '$root'. Registro: $log (la primera vez necesita internet)"
  fi
}

# tf_run <raíz> <apply|destroy> [argumentos]
tf_run() {
  local root="$1" action="$2" log status
  shift 2
  log="$(tf_log_file "$root" "$action")"
  set +e
  terraform -chdir="terraform/$root" "$action" -auto-approve -input=false -no-color "$@" 2>&1 |
    tee "$log" | tf_filter
  status=${PIPESTATUS[0]}
  set -e
  [ "$status" -eq 0 ] || die "terraform $action falló en '$root'. Registro: $log"
}

# Argumentos de la raíz config: archivo local y, después, los parámetros de esta ejecución, que mandan.
TF_CONFIG_ARGS=()
tf_set_config_args() {
  TF_CONFIG_ARGS=()
  [ -f terraform/local.tfvars ] && TF_CONFIG_ARGS+=("-var-file=../local.tfvars")
  [ -n "$PARAM_AI" ] && TF_CONFIG_ARGS+=("-var=ai_enabled=$PARAM_AI")
  [ -n "$PARAM_GPU" ] && TF_CONFIG_ARGS+=("-var=gpu=$PARAM_GPU")
  [ -n "$PARAM_ARGOCD" ] && TF_CONFIG_ARGS+=("-var=argocd_enabled=$PARAM_ARGOCD")
  return 0
}

# Valor de una variable de config antes de aplicarla. console no ejecuta las validaciones (lo hace apply) y puede
# escribir avisos en la salida: el valor es la última línea.
tf_config_var() {
  local log value
  log="$(tf_log_file config console)"
  if ! value="$(printf 'var.%s\n' "$1" |
    terraform -chdir=terraform/config console ${TF_CONFIG_ARGS[@]+"${TF_CONFIG_ARGS[@]}"} 2>"$log")"; then
    tf_filter <"$log" >&2
    die "la configuración local no es válida (terraform/local.tfvars). Registro: $log"
  fi
  printf '%s\n' "$value" | tail -n 1 | tr -d '"\r\n'
}

tf_output() {
  terraform -chdir="terraform/$1" output -raw "$2" 2>/dev/null | tr -d '\r'
}

# tf_in_state <raíz> <dirección>
tf_in_state() {
  local resources
  resources="$(terraform -chdir="terraform/$1" state list 2>/dev/null | tr -d '\r')" || return 1
  printf '%s\n' "$resources" | grep -qxF "$2"
}

# Olvida todo el estado de una raíz sin tocar los recursos: se usa cuando su clúster ya no existe.
tf_forget() {
  local root="$1" resources address
  resources="$(terraform -chdir="terraform/$root" state list 2>/dev/null | tr -d '\r')" || return 0
  for address in $resources; do
    case "$address" in
      data.*) continue ;;
    esac
    terraform -chdir="terraform/$root" state rm "$address" >>"$(tf_log_file "$root" forget)" 2>&1 ||
      die "no se pudo limpiar el estado de '$root'"
  done
}
