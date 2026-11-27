# shellcheck shell=bash
# Requisitos que se comprueban antes de crear nada.

MIN_TERRAFORM="1.9"
MIN_COMPOSE="2.24"
# 8 GB, con margen para lo que Docker Desktop no declara.
MIN_AI_MEMORY_BYTES=7500000000

# version_at_least <actual> <mínima>, comparando mayor y menor.
version_at_least() {
  local major minor min_major min_minor
  IFS=. read -r major minor _ <<<"${1#v}"
  IFS=. read -r min_major min_minor _ <<<"$2"
  [ "$major" -gt "$min_major" ] || { [ "$major" -eq "$min_major" ] && [ "${minor%%[!0-9]*}" -ge "$min_minor" ]; }
}

preflight_tools() {
  local tool missing="" version
  for tool in git docker terraform kind kubectl curl; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
  done
  [ -z "$missing" ] || die "faltan herramientas:$missing. Instálalas y abre una terminal nueva (ver README)"

  version="$(terraform version 2>/dev/null | tr -d '\r' | awk 'NR == 1 { print $2 }')"
  version_at_least "$version" "$MIN_TERRAFORM" || die "se necesita Terraform $MIN_TERRAFORM o posterior (hay $version)"

  docker info >/dev/null 2>&1 || die "Docker no responde. Arranca Docker y vuelve a intentarlo"

  version="$(docker compose version --short 2>/dev/null | tr -d '\r')" ||
    die "falta Docker Compose $MIN_COMPOSE o posterior"
  version_at_least "$version" "$MIN_COMPOSE" ||
    die "se necesita Docker Compose $MIN_COMPOSE o posterior (hay $version)"
}

port_in_use() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1
}

# preflight_port <puerto> <NodePort> <variable>. Vale que ya lo publique el nodo del propio entorno.
preflight_port() {
  local port="$1" node_port="$2" variable="$3" published
  published="$(docker port "$NODE_NAME" "$node_port/tcp" 2>/dev/null | tr -d '\r' || true)"
  [ "$published" = "127.0.0.1:$port" ] && return 0
  if port_in_use "$port"; then
    die "el puerto $port está ocupado. Libéralo o cambia $variable en terraform/local.tfvars"
  fi
}

preflight_memory() {
  local memory
  [ "$1" = "true" ] || return 0
  memory="$(docker info --format '{{.MemTotal}}' 2>/dev/null | tr -d '\r')"
  if [ -n "$memory" ] && [ "$memory" -lt "$MIN_AI_MEMORY_BYTES" ]; then
    warn "la IA necesita 8 GB de memoria en Docker y hay menos. Amplíala o usa: make up AI=false"
  fi
}
