# shellcheck shell=bash
# Esperas sobre la aplicación desplegada y comprobación de extremo a extremo.

WAIT_TIMEOUT="300s"

app_wait_http() {
  local url="$1" attempt
  for attempt in $(seq 1 60); do
    curl --fail --silent --output /dev/null --max-time 5 "$url" && return 0
    sleep 2
  done
  die "no hay respuesta en $url (intentos: $attempt)"
}

app_wait_deployments() {
  local deployment
  for deployment in redis kafka api web; do
    kc -n "$APP_NAMESPACE" rollout status "deployment/$deployment" --timeout="$WAIT_TIMEOUT" \
      >>"$LOG_DIR/rollout.log" 2>&1 ||
      die "el despliegue '$deployment' no está listo. Revisa:
       kubectl --kubeconfig $KUBECONFIG_FILE -n $APP_NAMESPACE describe deployment/$deployment
       kubectl --kubeconfig $KUBECONFIG_FILE -n $APP_NAMESPACE logs deployment/$deployment"
    info "Listo: $deployment"
  done
}

# app_wait_argocd: Argo CD despliega main; se espera a que lo sincronice y quede sano.
app_wait_argocd() {
  local check
  info "Esperando a que Argo CD sincronice la rama main"
  for check in '{.status.sync.status}=Synced' '{.status.health.status}=Healthy'; do
    kc -n argocd wait "--for=jsonpath=$check" application/quipux-playlist --timeout="$WAIT_TIMEOUT" \
      >>"$LOG_DIR/argocd.log" 2>&1 ||
      die "Argo CD no llegó a ${check#*=}. Revisa:
       kubectl --kubeconfig $KUBECONFIG_FILE -n argocd describe application quipux-playlist"
  done
  info "Argo CD: Synced y Healthy"
}

app_argocd_notice() {
  cat <<NOTICE

Con Argo CD se despliega la rama main de GitHub: los cambios locales de k8s/ no se aplican.
Consola: https://localhost:8443 (usuario admin; el README explica cómo leer la contraseña), tras ejecutar:
  kubectl --kubeconfig $KUBECONFIG_FILE -n argocd port-forward svc/argocd-server 8443:443
NOTICE
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# Primer valor de texto de una clave en un JSON.
json_string() {
  sed -n "s/.*\"$1\":\"\\([^\"]*\\)\".*/\\1/p"
}

SMOKE_LIST_URL=""
SMOKE_AUTH=""

smoke_cleanup() {
  [ -n "$SMOKE_LIST_URL" ] || return 0
  curl --silent --output /dev/null --max-time 15 -X DELETE -H "$SMOKE_AUTH" "$SMOKE_LIST_URL" || true
  SMOKE_LIST_URL=""
}

# smoke_run <url base de la API a través de la web> <contraseña de admin> <ai_enabled>
smoke_run() {
  local base="$1" password="$2" ai="$3" token name body status origin

  token="$(printf '{"username":"admin","password":"%s"}' "$(json_escape "$password")" |
    curl --silent --max-time 15 -X POST "$base/auth/login" -H 'Content-Type: application/json' --data-binary @- |
    json_string accessToken)" || true
  [ -n "$token" ] || die "el inicio de sesión como admin falló en $base/auth/login"
  info "Inicio de sesión correcto"
  SMOKE_AUTH="Authorization: Bearer $token"

  # Nombre y canción distintos en cada ejecución: las recomendaciones se guardan en caché según las canciones.
  name="smoke-$(date +%s)-$$"
  body="{\"nombre\":\"$name\",\"descripcion\":\"Comprobacion automatica\",\"canciones\":["
  body="$body{\"titulo\":\"Prueba $name\",\"artista\":\"Artista\",\"album\":\"Album\",\"anno\":\"1999\",\"genero\":\"rock\"},"
  body="$body{\"titulo\":\"Bohemian Rhapsody\",\"artista\":\"Queen\",\"album\":\"A Night at the Opera\",\"anno\":\"1975\",\"genero\":\"rock\"}]}"

  trap smoke_cleanup EXIT
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 15 -X POST "$base/lists" \
    -H "$SMOKE_AUTH" -H 'Content-Type: application/json' --data-binary "$body")" || true
  [ "$status" = "201" ] || die "crear la lista temporal respondió $status (se esperaba 201)"
  SMOKE_LIST_URL="$base/lists/$name"
  info "Lista temporal creada"

  status="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 15 -H "$SMOKE_AUTH" \
    "$SMOKE_LIST_URL")" || true
  [ "$status" = "200" ] || die "consultar la lista temporal respondió $status (se esperaba 200)"

  origin="$(curl --silent --max-time 90 -H "$SMOKE_AUTH" "$SMOKE_LIST_URL/recommendations" |
    json_string origen)" || true
  case "$ai:$origin" in
    true:IA | true:SIMILITUD | false:RESPALDO) info "Recomendaciones correctas (origen: $origin)" ;;
    true:*) die "con la IA activa se esperaba origen IA o SIMILITUD y llegó '${origin:-sin respuesta}'" ;;
    *) die "sin IA se esperaba origen RESPALDO y llegó '${origin:-sin respuesta}'" ;;
  esac

  smoke_cleanup
  info "Lista temporal borrada. Todo correcto"
}
