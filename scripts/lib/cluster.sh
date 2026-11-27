# shellcheck shell=bash
# Estado del clúster y casos que Terraform no resuelve (ver data-model.md, «Estados del entorno»).

CLUSTER_NAME="quipux-playlist"
NODE_NAME="$CLUSTER_NAME-control-plane"
CLUSTER_ADDRESS="kind_cluster.this"
KUBECONFIG_FILE="$LOCAL_DIR/kubeconfig"
PENDING_MARK="$LOCAL_DIR/cluster.pending"
APP_NAMESPACE="quipux-playlist"

kc() {
  kubectl --kubeconfig "$KUBECONFIG_FILE" "$@"
}

node_status() {
  local status
  # Sin contenedor, docker inspect falla pero escribe una línea vacía: su salida no sirve.
  status="$(docker inspect --format '{{.State.Status}}' "$NODE_NAME" 2>/dev/null)" || status="missing"
  printf '%s' "$status" | tr -d '\r'
}

# absent | active | stopped | deleted | interrupted | foreign
cluster_state() {
  local node
  node="$(node_status)"

  if tf_in_state cluster "$CLUSTER_ADDRESS"; then
    case "$node" in
      missing) printf 'deleted' ;;
      running) printf 'active' ;;
      *) printf 'stopped' ;;
    esac
  elif [ "$node" = "missing" ]; then
    printf 'absent'
  elif [ -f "$PENDING_MARK" ]; then
    printf 'interrupted'
  else
    printf 'foreign'
  fi
}

cluster_reject_foreign() {
  [ "$1" != "foreign" ] || die "ya existe un clúster kind '$CLUSTER_NAME' que no creó make up. Para sustituirlo:
       kind delete cluster --name $CLUSTER_NAME   (se pierden sus listas y su Secret)"
}

cluster_delete_leftover() {
  kind delete cluster --name "$CLUSTER_NAME" --kubeconfig "$KUBECONFIG_FILE" >>"$LOG_DIR/kind.log" 2>&1 ||
    die "no se pudo borrar el clúster a medias. Registro: $LOG_DIR/kind.log"
}

cluster_start_node() {
  info "Arrancando el nodo del clúster"
  docker start "$NODE_NAME" >/dev/null || die "no se pudo arrancar el contenedor $NODE_NAME"
}

# Deja el estado de Terraform y Docker de acuerdo antes de planificar.
cluster_reconcile() {
  case "$1" in
    interrupted)
      warn "la creación anterior quedó a medias: se borra y se crea de nuevo"
      cluster_delete_leftover
      ;;
    deleted)
      warn "el clúster se borró por fuera de make: se crea de nuevo"
      tf_forget cluster
      tf_forget app
      ;;
    stopped) cluster_start_node ;;
  esac
}

cluster_ensure_kubeconfig() {
  [ -s "$KUBECONFIG_FILE" ] && return 0
  kind export kubeconfig --name "$CLUSTER_NAME" --kubeconfig "$KUBECONFIG_FILE" >>"$LOG_DIR/kind.log" 2>&1 ||
    die "no se pudo obtener el kubeconfig. Registro: $LOG_DIR/kind.log"
}

# Tras arrancar el nodo, el API server puede rechazar peticiones unos instantes.
cluster_wait_ready() {
  local attempt
  for attempt in $(seq 1 60); do
    if kc wait --for=condition=Ready node --all --timeout=5s >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  die "el clúster no respondió a tiempo (intentos: $attempt). Prueba: kubectl --kubeconfig $KUBECONFIG_FILE get nodes"
}

# Cambiar los puertos obliga a recrear el clúster.
cluster_warn_port_change() {
  local web="$1" api="$2" published_web published_api
  published_web="$(docker port "$NODE_NAME" 30080/tcp 2>/dev/null | tr -d '\r' || true)"
  published_api="$(docker port "$NODE_NAME" 30081/tcp 2>/dev/null | tr -d '\r' || true)"
  if [ "$published_web" != "127.0.0.1:$web" ] || [ "$published_api" != "127.0.0.1:$api" ]; then
    warn "los puertos cambiaron: el clúster se recrea y se pierden las listas"
  fi
}
