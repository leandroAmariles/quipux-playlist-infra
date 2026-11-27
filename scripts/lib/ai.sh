# shellcheck shell=bash
# IA en Docker: Ollama, LiteLLM, PostgreSQL con pgvector e indexación del catálogo.

AI_PROJECT="quipux-cluster"
AI_ENV_FILE="$LOCAL_DIR/compose.env"
AI_USE_GPU="false"

# Las variables de la terminal mandan sobre el archivo de entorno: se quitan para que no lo sustituyan.
ai_compose() {
  (
    unset AI_API_KEY CATALOG_DB_PASSWORD OLLAMA_CHAT_MODEL OLLAMA_EMBEDDING_MODEL BACKEND_TAG AI_EMBEDDING_MODEL
    if [ "$AI_USE_GPU" = "true" ]; then
      docker compose -p "$AI_PROJECT" --env-file "$AI_ENV_FILE" \
        -f compose/compose.cluster.yaml -f compose/compose.ai.gpu.yaml "$@"
    else
      docker compose -p "$AI_PROJECT" --env-file "$AI_ENV_FILE" -f compose/compose.cluster.yaml "$@"
    fi
  )
}

# ai_select_gpu <auto|on|off>. Prueba la ruta real: que un contenedor vea la GPU.
ai_select_gpu() {
  local mode="$1" image
  AI_USE_GPU="false"
  [ "$mode" != "off" ] || return 0

  image="$(ai_compose config --images ollama | tr -d '\r')"
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    info "Descargando la imagen de Ollama (varios GB la primera vez)"
    docker pull "$image" || die "no se pudo descargar la imagen de Ollama (hace falta internet)"
  fi

  if docker run --rm --gpus all --entrypoint nvidia-smi "$image" -L >>"$LOG_DIR/gpu.log" 2>&1; then
    AI_USE_GPU="true"
  elif [ "$mode" = "on" ]; then
    die "gpu = on, pero Docker no ve ninguna GPU NVIDIA. Registro: $LOG_DIR/gpu.log"
  fi
}

ai_fail() {
  die "$1. Revisa: docker compose -p $AI_PROJECT logs $2"
}

ai_up() {
  info "Arrancando Ollama"
  ai_compose up -d --wait ollama || ai_fail "Ollama no arrancó" ollama
  info "Preparando los modelos (la primera vez descarga unos 2,2 GB)"
  ai_compose run --rm -T ollama-init || ai_fail "no se pudieron descargar o cargar los modelos" ollama
  info "Arrancando la pasarela de modelos y el catálogo"
  ai_compose up -d --wait --no-deps litellm catalog-db ||
    ai_fail "la pasarela o el catálogo no arrancaron" "litellm catalog-db"
  info "Indexando el catálogo de canciones"
  if ! ai_compose run --rm -T --no-deps catalog-index >"$LOG_DIR/catalog-index.log" 2>&1; then
    tail -n 20 "$LOG_DIR/catalog-index.log" >&2
    die "la indexación del catálogo falló. Registro: $LOG_DIR/catalog-index.log"
  fi
  grep -i 'index' "$LOG_DIR/catalog-index.log" | tail -n 1 | sed 's/^.* : /    /' || true
  ai_warm_up
}

# Sin esto, las primeras recomendaciones tras crear Ollama superan el tiempo del backend y salen de respaldo.
ai_warm_up() {
  info "Calentando los modelos"
  ai_compose exec -T litellm python - <scripts/lib/warm_up.py ||
    ai_fail "los modelos no responden a tiempo" "litellm ollama"
}

ai_containers() {
  docker ps --all --quiet --filter "label=com.docker.compose.project=$AI_PROJECT"
}

# ai_down [--volumes]. Sin --volumes conserva los modelos y el catálogo.
ai_down() {
  local containers volumes
  containers="$(ai_containers)"
  if [ -n "$containers" ]; then
    info "Deteniendo la IA en Docker"
    if [ -f "$AI_ENV_FILE" ]; then
      ai_compose down >>"$LOG_DIR/ai.log" 2>&1 || die "no se pudo detener la IA. Registro: $LOG_DIR/ai.log"
    else
      # Sin el archivo de entorno Compose no puede leer la definición: se borra por la etiqueta del proyecto.
      # shellcheck disable=SC2086
      docker rm --force $containers >>"$LOG_DIR/ai.log" 2>&1 || die "no se pudo detener la IA"
      docker network rm "${AI_PROJECT}_default" >>"$LOG_DIR/ai.log" 2>&1 || true
    fi
  fi
  if [ "${1:-}" = "--volumes" ]; then
    volumes="$(docker volume ls --quiet --filter "label=com.docker.compose.project=$AI_PROJECT")"
    if [ -n "$volumes" ]; then
      info "Borrando modelos y catálogo"
      # shellcheck disable=SC2086
      docker volume rm $volumes >>"$LOG_DIR/ai.log" 2>&1 || die "no se pudieron borrar los volúmenes de la IA"
    fi
  fi
}

# Los pods deben alcanzar la pasarela y el catálogo por la red de kind.
ai_check_from_api() {
  local target attempt reached
  for target in "quipux-litellm 4000" "quipux-catalog-db 5432"; do
    reached="false"
    for attempt in $(seq 1 20); do
      # shellcheck disable=SC2086
      if kc -n "$APP_NAMESPACE" exec deployment/api -- nc -z -w 3 $target >/dev/null 2>&1; then
        reached="true"
        break
      fi
      sleep 3
    done
    [ "$reached" = "true" ] || die "el pod api no llega a ${target/ /:} (intentos: $attempt)"
  done
  info "La API llega a la IA desde el clúster"
}
