#!/usr/bin/env bash
# Orquesta el entorno local: requisitos, Terraform, Docker Compose y esperas. Se invoca desde el Makefile.
# Compatible con Bash 3.2. Todas las rutas son relativas a la raíz del repositorio.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

LOCAL_DIR=".local"
LOG_DIR="$LOCAL_DIR/logs"

info() { printf '==> %s\n' "$*"; }
warn() { printf 'AVISO: %s\n' "$*" >&2; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# shellcheck source=scripts/lib/terraform.sh
. scripts/lib/terraform.sh
# shellcheck source=scripts/lib/preflight.sh
. scripts/lib/preflight.sh
# shellcheck source=scripts/lib/cluster.sh
. scripts/lib/cluster.sh
# shellcheck source=scripts/lib/app.sh
. scripts/lib/app.sh
# shellcheck source=scripts/lib/ai.sh
. scripts/lib/ai.sh

PARAM_AI=""
PARAM_GPU=""
PARAM_ARGOCD=""
PARAM_CONFIRM=""

parse_params() {
  local param
  for param in "$@"; do
    case "$param" in
      AI=true | AI=false) PARAM_AI="${param#AI=}" ;;
      GPU=auto | GPU=on | GPU=off) PARAM_GPU="${param#GPU=}" ;;
      ARGOCD=true | ARGOCD=false) PARAM_ARGOCD="${param#ARGOCD=}" ;;
      CONFIRM=yes) PARAM_CONFIRM="yes" ;;
      AI=* | ARGOCD=*) die "valor no admitido en '$param': usa true o false" ;;
      GPU=*) die "valor no admitido en '$param': usa auto, on u off" ;;
      CONFIRM=*) die "valor no admitido en '$param': usa CONFIRM=yes" ;;
      *) die "parámetro desconocido: '$param'" ;;
    esac
  done
}

cmd_help() {
  cat <<'HELP'
Entorno local de quipux-playlist

  make up           crea o actualiza el entorno y espera a que esté listo
  make status       muestra el estado sin modificar nada
  make down         elimina el clúster y los contenedores; conserva secretos, modelos y catálogo
  make clean        elimina además modelos, catálogo, secretos y estado (pide confirmación)
  make credentials  muestra los usuarios y contraseñas de demostración
  make smoke        comprueba inicio de sesión, listas y recomendaciones
  make validate     valida Terraform y los scripts

Parámetros (solo para esa ejecución): AI=true|false  GPU=auto|on|off  ARGOCD=true|false  CONFIRM=yes
Configuración persistente: terraform/local.tfvars (plantilla en terraform/local.tfvars.example)
HELP
}

require_environment() {
  tf_in_state config local_sensitive_file.compose_env || die "el entorno no existe todavía: ejecuta make up"
}

# print_summary <IA> <Argo CD> <puerto web> <puerto api>
print_summary() {
  local argocd_label="no"
  [ "$2" = "true" ] && argocd_label="sí"
  cat <<SUMMARY

Entorno listo (IA: $1, Argo CD: $argocd_label)
  Web      http://localhost:$3
  API      http://localhost:$4
  Swagger  http://localhost:$4/swagger-ui.html
  Credenciales: make credentials
  kubectl:      kubectl --kubeconfig $KUBECONFIG_FILE -n $APP_NAMESPACE get pods
SUMMARY
}

cmd_up() {
  local state instance_before instance ai ai_label argocd web_port api_port

  info "Comprobando requisitos"
  preflight_tools
  state="$(cluster_state)"
  cluster_reject_foreign "$state"

  tf_set_config_args
  tf_init config
  web_port="$(tf_config_var web_port)"
  api_port="$(tf_config_var api_port)"
  ai="$(tf_config_var ai_enabled)"
  preflight_port "$web_port" 30080 web_port
  preflight_port "$api_port" 30081 api_port
  preflight_memory "$ai"

  info "Preparando secretos y configuración"
  tf_run config apply ${TF_CONFIG_ARGS[@]+"${TF_CONFIG_ARGS[@]}"}
  argocd="$(tf_output config argocd_enabled)"

  info "Preparando el clúster"
  tf_init cluster
  cluster_reconcile "$state"
  case "$state" in
    active | stopped) cluster_warn_port_change "$web_port" "$api_port" ;;
  esac
  instance_before="$(tf_output cluster cluster_instance || true)"
  : >"$PENDING_MARK"
  tf_run cluster apply
  rm -f "$PENDING_MARK"
  cluster_ensure_kubeconfig
  cluster_wait_ready
  instance="$(tf_output cluster cluster_instance)"
  # Un clúster distinto no tiene nada de lo que recuerda el estado de app.
  if [ "$instance" != "$instance_before" ]; then
    tf_forget app
  fi

  # Después del clúster: la red de Docker `kind` la crea él.
  ai="$(tf_output config ai_enabled)"
  ai_label="no"
  if [ "$ai" = "true" ]; then
    info "Preparando la IA en Docker"
    ai_select_gpu "$(tf_output config gpu)"
    ai_label="CPU"
    [ "$AI_USE_GPU" = "true" ] && ai_label="GPU"
    ai_up
  else
    ai_down
  fi

  info "Desplegando la aplicación"
  tf_init app
  tf_run app apply "-var=cluster_instance=$instance"

  if [ "$argocd" = "true" ]; then
    app_wait_argocd
  fi
  info "Esperando a que la aplicación esté lista"
  app_wait_deployments
  app_wait_http "http://localhost:$api_port/actuator/health/readiness"
  app_wait_http "http://localhost:$web_port/"
  if [ "$ai" = "true" ]; then
    ai_check_from_api
  fi

  print_summary "$ai_label" "$argocd" "$web_port" "$api_port"
  if [ "$argocd" = "true" ]; then
    app_argocd_notice
  fi
}

cmd_credentials() {
  require_environment
  printf 'user   %s\n' "$(tf_output config demo_user_password)"
  printf 'admin  %s\n' "$(tf_output config demo_admin_password)"
}

cmd_smoke() {
  require_environment
  [ "$(cluster_state)" = "active" ] || die "el clúster no está en marcha: ejecuta make up"
  smoke_run "http://localhost:$(tf_output config web_port)/api" "$(tf_output config demo_admin_password)" \
    "$(tf_output config ai_enabled)"
}

# Solo lee: no crea archivos ni cambia recursos.
cmd_status() {
  local state label
  preflight_tools
  state="$(cluster_state)"
  case "$state" in
    absent) label="no existe" ;;
    active) label="en marcha" ;;
    stopped) label="detenido (make up lo arranca)" ;;
    deleted) label="borrado por fuera de make (make up lo crea de nuevo)" ;;
    interrupted) label="creación a medias (make up la repite)" ;;
    foreign) label="existe, pero no lo creó make up" ;;
  esac
  printf 'Clúster %s: %s\n' "$CLUSTER_NAME" "$label"

  if [ "$state" = "active" ]; then
    printf '\n'
    kc -n "$APP_NAMESPACE" get deployments,pods 2>&1 || warn "el clúster todavía no responde"
    if kc get namespace argocd >/dev/null 2>&1; then
      printf '\nArgo CD:\n'
      kc -n argocd get application quipux-playlist 2>&1 || true
    fi
  fi

  printf '\nIA en Docker (proyecto %s):\n' "$AI_PROJECT"
  if [ -n "$(ai_containers)" ]; then
    docker ps --all --filter "label=com.docker.compose.project=$AI_PROJECT" --format 'table {{.Names}}\t{{.Status}}'
  else
    printf '  sin contenedores\n'
  fi

  if [ "$state" = "active" ]; then
    printf '\nWeb      http://localhost:%s\n' "$(tf_output config web_port)"
    printf 'API      http://localhost:%s\n' "$(tf_output config api_port)"
  fi
}

# Elimina el clúster y los contenedores. Conserva los secretos y los volúmenes con los modelos y el catálogo.
cmd_down() {
  preflight_tools
  remove_environment
  info "Entorno eliminado. Se conservan los secretos, los modelos y el catálogo"
}

remove_environment() {
  local state
  state="$(cluster_state)"

  ai_down

  case "$state" in
    active | stopped)
      [ "$state" = "stopped" ] && cluster_start_node
      info "Eliminando el clúster"
      tf_init cluster
      tf_run cluster destroy
      # Lo desplegado desapareció con el clúster. Solo se olvida si la destrucción terminó bien.
      tf_forget app
      ;;
    deleted)
      tf_forget cluster
      tf_forget app
      ;;
    interrupted)
      info "Eliminando el clúster creado a medias"
      cluster_delete_leftover
      tf_forget app
      ;;
    absent) tf_forget app ;;
    foreign) warn "el clúster '$CLUSTER_NAME' no lo creó make up: no se toca" ;;
  esac
  rm -f "$PENDING_MARK"
}

confirm_clean() {
  local answer
  [ "$PARAM_CONFIRM" != "yes" ] || return 0
  printf 'Se borrarán el clúster, los modelos, el catálogo, los secretos y el estado.\n'
  printf 'Escribe "si" para continuar: '
  read -r answer || answer=""
  answer="$(printf '%s' "$answer" | tr -d '\r')"
  [ "$answer" = "si" ] || die "limpieza cancelada: no se borró nada (sin terminal usa make clean CONFIRM=yes)"
}

cmd_clean() {
  preflight_tools
  confirm_clean
  remove_environment
  ai_down --volumes
  if [ -f terraform/config/terraform.tfstate ]; then
    info "Eliminando los secretos"
    tf_init config
    tf_run config destroy
  fi
  rm -f terraform/config/terraform.tfstate* terraform/cluster/terraform.tfstate* terraform/app/terraform.tfstate*
  rm -rf "$LOCAL_DIR"
  info "Limpieza completa. terraform/local.tfvars, si existe, se conserva"
}

cmd_validate() {
  local root
  command -v terraform >/dev/null 2>&1 || die "falta terraform"
  terraform fmt -check -recursive terraform ||
    die "hay archivos sin formato: ejecuta terraform fmt -recursive terraform"
  for root in config cluster app; do
    info "Validando terraform/$root"
    # Directorio de datos aparte para no alterar el de make up.
    TF_DATA_DIR="../../$LOCAL_DIR/validate/$root" terraform -chdir="terraform/$root" init \
      -backend=false -input=false -no-color -lockfile=readonly >"$(tf_log_file "$root" validate)" 2>&1 ||
      die "terraform init falló en '$root'. Registros en $LOG_DIR"
    TF_DATA_DIR="../../$LOCAL_DIR/validate/$root" terraform -chdir="terraform/$root" validate -no-color ||
      die "terraform validate falló en '$root'"
  done
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x scripts/local.sh || die "shellcheck encontró problemas"
  else
    warn "shellcheck no está instalado: la integración continua analiza los scripts"
  fi
  info "Validación correcta"
}

main() {
  local command="${1:-help}"
  [ "$#" -gt 0 ] && shift
  parse_params "$@"
  case "$command" in
    help | status) ;;
    *) mkdir -p "$LOG_DIR" ;;
  esac

  case "$command" in
    help) cmd_help ;;
    up) cmd_up ;;
    status) cmd_status ;;
    down) cmd_down ;;
    clean) cmd_clean ;;
    credentials) cmd_credentials ;;
    smoke) cmd_smoke ;;
    validate) cmd_validate ;;
    *) die "comando desconocido: '$command'" ;;
  esac
}

main "$@"
