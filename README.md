# quipux-playlist-infra

Infraestructura del proyecto de listas de reproducción. Permite levantar la aplicación completa con Docker Compose o
desplegarla en Kubernetes con Kustomize y Argo CD.

La documentación del proyecto está en [quipux-playlist-backend](https://github.com/leandroAmariles/quipux-playlist-backend).
Las especificaciones de infraestructura están en [`specs/07-docker-compose/`](specs/07-docker-compose/) y
[`specs/09-kubernetes-argocd/`](specs/09-kubernetes-argocd/).

## Cómo levantarlo en local

| | [Clúster Kubernetes](#clúster-local-con-kubernetes-kind) | [Docker Compose](#docker-compose) |
|---|---|---|
| Imágenes de la API y la web | las publicadas en GHCR (no compila tu código) | se construyen desde tu código |
| Repositorios necesarios | solo este | los tres |
| Herramientas | Git, Docker, `kind` y `kubectl` | Git y Docker con Compose |
| IA local, WireMock y Langfuse | no incluidos | opcionales |

Las dos opciones usan los puertos `4200` y `8080`: detén una antes de arrancar la otra. En ninguna hace falta instalar
Java, Maven ni Node, y las dos necesitan internet la primera vez.

## Clúster local con Kubernetes (kind)

Levanta en un clúster [kind](https://kind.sigs.k8s.io) la web, la API, Redis y Kafka. Todos los comandos se ejecutan
desde la raíz de este repositorio. Donde Bash y PowerShell difieren se muestran los dos; el resto sirve en ambos.

### 1. Instalar las herramientas

- Docker en marcha. El nodo del clúster ocupó 1,7 GiB en reposo, con Argo CD instalado; deja al menos 4 GB libres para
  Docker.
- [`kind`](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) y
  [`kubectl`](https://kubernetes.io/docs/tasks/tools/). No hace falta instalar `kustomize`: `kubectl` lo incluye.

```powershell
# Windows
winget install -e --id Kubernetes.kind
winget install -e --id Kubernetes.kubectl
```

```bash
# macOS
brew install kind kubectl
```

Abre una terminal nueva después de instalar. Probado en Windows 11 con Docker 29.6, `kind` 0.31 y `kubectl` 1.34. Las
imágenes del proyecto solo se publican para `linux/amd64`.

### 2. Clonar y crear el clúster

```bash
git clone https://github.com/leandroAmariles/quipux-playlist-infra.git
cd quipux-playlist-infra

kind create cluster --name quipux-playlist
kubectl config use-context kind-quipux-playlist
kubectl apply -f k8s/namespace.yaml
```

Si tienes otros clústeres, comprueba con `kubectl config current-context` que sigues en `kind-quipux-playlist` antes
de aplicar o borrar nada.

### 3. Crear el `Secret`

No hay secretos reales en el repositorio: crea `playlist-secrets` una vez, con las claves de
[`k8s/secret.example.yaml`](k8s/secret.example.yaml). `JWT_SECRET` necesita 32 bytes como mínimo y cada contraseña, de
1 a 72.

Bash o Git Bash:

```bash
USER_PASS='<elige-una-contraseña>'
ADMIN_PASS='<elige-otra-contraseña>'

kubectl -n quipux-playlist create secret generic playlist-secrets \
  --from-literal=JWT_SECRET="$(openssl rand -base64 48)" \
  --from-literal=DEMO_USER_PASSWORD="$USER_PASS" \
  --from-literal=DEMO_ADMIN_PASSWORD="$ADMIN_PASS"
```

PowerShell:

```powershell
$userPass = '<elige-una-contraseña>'
$adminPass = '<elige-otra-contraseña>'
$bytes = New-Object byte[] 48
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$jwt = [Convert]::ToBase64String($bytes)

kubectl -n quipux-playlist create secret generic playlist-secrets `
  --from-literal=JWT_SECRET="$jwt" `
  --from-literal=DEMO_USER_PASSWORD="$userPass" `
  --from-literal=DEMO_ADMIN_PASSWORD="$adminPass"
```

Las credenciales de Spotify son opcionales: si las tienes, añade al mismo comando
`--from-literal=SPOTIFY_CLIENT_ID=...` y `--from-literal=SPOTIFY_CLIENT_SECRET=...`.

### 4. Desplegar

```bash
kubectl apply -k k8s
kubectl -n quipux-playlist wait --for=condition=Available deployment --all --timeout=300s
kubectl -n quipux-playlist get pods
```

Deben quedar `api`, `kafka`, `redis` y `web` en `1/1 Running`. La primera vez se descargan las imágenes; en la prueba
tardó alrededor de un minuto. Los avisos `FailedScheduling` o `Startup probe failed` de ese primer minuto son
normales.

### 5. Abrir la aplicación

Cada `port-forward` ocupa su terminal; déjalas abiertas y cierra con `Ctrl+C`.

```bash
# Terminal 1: web
kubectl -n quipux-playlist port-forward svc/web 4200:8080
```

```bash
# Terminal 2: API (solo si quieres usarla directamente, Swagger o Postman)
kubectl -n quipux-playlist port-forward svc/api 8080:8080
```

| Qué | Dirección |
|---|---|
| Aplicación web | <http://localhost:4200> |
| API a través de la web | <http://localhost:4200/api> |
| API | <http://localhost:8080> |
| Swagger UI | <http://localhost:8080/swagger-ui.html> |
| Sondas sin token | <http://localhost:8080/actuator/health/readiness> y `/liveness` (`/actuator/health` pide token) |

Entra con `admin` (consulta, crea y borra) o con `user` (solo consulta) y la contraseña que elegiste.

### 6. Comprobar que funciona

Desde una tercera terminal, con la web reenviada. Si la terminal es nueva, vuelve a definir la contraseña.

Bash o Git Bash:

```bash
TOKEN=$(curl -s -X POST http://localhost:4200/api/auth/login -H 'Content-Type: application/json' \
  -d "{\"username\":\"admin\",\"password\":\"$ADMIN_PASS\"}" | sed 's/.*"accessToken":"\([^"]*\)".*/\1/')

curl -i -X POST http://localhost:4200/api/lists -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"nombre":"Demo","descripcion":"Prueba","canciones":[{"titulo":"Uno","anno":"1999","genero":"rock"}]}'

curl -i http://localhost:4200/api/lists/Demo -H "Authorization: Bearer $TOKEN"

kubectl -n quipux-playlist logs deployment/api | grep "Playlist audit event"
```

PowerShell:

```powershell
$credentials = @{ username = 'admin'; password = $adminPass } | ConvertTo-Json
$login = Invoke-RestMethod -Method Post -Uri http://localhost:4200/api/auth/login `
  -ContentType 'application/json' -Body $credentials
$headers = @{ Authorization = "Bearer $($login.accessToken)" }

$song = @{ titulo = 'Uno'; anno = '1999'; genero = 'rock' }
$list = @{ nombre = 'Demo'; descripcion = 'Prueba'; canciones = @($song) } | ConvertTo-Json -Depth 4
Invoke-RestMethod -Method Post -Uri http://localhost:4200/api/lists -Headers $headers `
  -ContentType 'application/json' -Body $list

Invoke-RestMethod -Uri http://localhost:4200/api/lists/Demo -Headers $headers

kubectl -n quipux-playlist logs deployment/api | Select-String 'Playlist audit event'
```

La creación responde `201` y el registro muestra el evento `PlaylistCreated`, que confirma el paso por Kafka. Repetir la
creación responde `409` porque la lista ya existe.

Dos respuestas esperadas en este clúster:

- Las recomendaciones responden con `origen: RESPALDO`: no incluye los servicios de IA.
- Sin credenciales de Spotify los géneros salen de la lista local y Redis queda vacío, porque solo guarda los de
  Spotify.

### Uso diario

| Para | Comando |
|---|---|
| Ver el estado | `kubectl -n quipux-playlist get pods` |
| Seguir los registros de la API | `kubectl -n quipux-playlist logs -f deployment/api` |
| Volver tras reiniciar Docker o el equipo | `docker start quipux-playlist-control-plane`, esperar a que los pods vuelvan a `1/1` y repetir los `port-forward` |
| Aplicar cambios de los manifiestos | `kubectl apply -k k8s` |
| Reiniciar la API | `kubectl -n quipux-playlist rollout restart deployment/api` |
| Cambiar el secreto | `kubectl -n quipux-playlist delete secret playlist-secrets`, crearlo de nuevo y reiniciar la API |
| Borrar el clúster | `kind delete cluster --name quipux-playlist` |

La base de datos está en memoria: las listas se pierden cada vez que se reinicia la API.

### Si algo falla en el clúster

| Síntoma | Causa y solución |
|---|---|
| `node(s) already exist for a cluster with the name` | el clúster ya existe: sigue desde `kubectl config use-context`, o bórralo |
| `secrets "playlist-secrets" already exists` | ya está creado; para cambiarlo, mira «Uso diario» |
| `api` en `CreateContainerConfigError` | falta `playlist-secrets`; créalo y el pod arranca solo |
| `api` en `CrashLoopBackOff` | un valor no es válido; `kubectl -n quipux-playlist logs deployment/api --previous` dice cuál |
| Pod en `ImagePullBackOff` | sin acceso a la imagen; `kubectl -n quipux-playlist describe pod <pod>` muestra el motivo |
| `unable to listen on port` | puerto ocupado; usa otro a la izquierda, por ejemplo `14200:8080` |
| El `port-forward` deja de responder | el pod se reinició; vuelve a lanzarlo |
| `connection refused` en cualquier `kubectl` | Docker o el nodo están detenidos; mira «Uso diario» |

## Despliegue continuo con Argo CD

En lugar de desplegar desde GitHub Actions (sin `kubeconfig` ni credenciales de clúster en los workflows), Argo CD
observa la rama `main` de este repositorio mediante [`argocd/application.yaml`](argocd/application.yaml) (`path: k8s`,
`prune: true`, `selfHeal: true`) sin tocar `playlist-secrets`, al estar excluido de `kustomization.yaml`.

Para usar la aplicación en local es opcional. Necesita el clúster y el `Secret` de los pasos 2 y 3. Despliega lo que hay
en la rama `main` en GitHub, no tus archivos locales, y deshace los cambios hechos a mano sobre esos recursos: no lo
instales si vas a probar manifiestos sin fusionar. Si usas un fork, cambia `repoURL` en ese mismo archivo.

### Instalación y aplicación

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.9/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=180s
kubectl apply -f argocd/application.yaml
kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/quipux-playlist --timeout=300s
kubectl -n argocd get application quipux-playlist
```

En PowerShell cambia la `\` del final de línea por una comilla invertida o escribe el comando en una sola línea.

### Acceso a la consola de Argo CD

Contraseña inicial en Bash o Git Bash:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

En PowerShell:

```powershell
$encoded = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
```

Después abre el acceso:

```bash
kubectl -n argocd port-forward svc/argocd-server 8443:443
```

Abre <https://localhost:8443> con el usuario `admin` y la contraseña anterior.

### Flujo automático tras una release

1. Al publicar una nueva versión en `quipux-playlist-backend` o `quipux-playlist-frontend`, su workflow `Release`
   ejecuta el trabajo `update-infra` (solo si la imagen se publicó en GHCR).
2. `update-infra` abre o actualiza automáticamente un PR `chore(deploy): bump <componente> image to X.Y.Z` modificando
   únicamente [`k8s/kustomization.yaml`](k8s/kustomization.yaml).
3. El CI de este repositorio valida el PR y, al fusionarlo en `main`, Argo CD sincroniza la nueva etiqueta en el clúster.

## Docker Compose

Construye las imágenes desde el código y levanta además una instancia efímera de **Redis** (caché de géneros) y otra de
**Kafka** en modo KRaft sin ZooKeeper (eventos `PlaylistCreated` y `PlaylistDeleted` de auditoría) en red interna: si
Redis o Kafka fallan o se detienen, `api` sigue arrancando y respondiendo con normalidad.

Los tres repositorios van como carpetas hermanas y con sus nombres originales. Si ya clonaste alguno, no lo repitas:

```bash
git clone https://github.com/leandroAmariles/quipux-playlist-backend.git
git clone https://github.com/leandroAmariles/quipux-playlist-frontend.git
git clone https://github.com/leandroAmariles/quipux-playlist-infra.git
cd quipux-playlist-infra/compose
```

Los comandos de Docker Compose de las secciones siguientes se ejecutan desde `quipux-playlist-infra/compose`.

### Preparación

Copia la plantilla (`cp .env.example .env`, o `Copy-Item .env.example .env` en PowerShell) y rellena en `.env` las tres
variables obligatorias. No hay valores por defecto para que no haya secretos en el repositorio. `.env` no se versiona.

| Variable | Regla |
|---|---|
| `JWT_SECRET` | clave que firma los tokens, de 32 bytes como mínimo |
| `DEMO_USER_PASSWORD` | contraseña que eliges para el usuario `user`, de 1 a 72 bytes |
| `DEMO_ADMIN_PASSWORD` | contraseña que eliges para el usuario `admin`, de 1 a 72 bytes |

Para generar `JWT_SECRET`:

```bash
openssl rand -base64 48
```

En PowerShell:

```powershell
$b = New-Object byte[] 48; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b)
```

Si un valor contiene `$`, escríbelo entre comillas simples: `DEMO_USER_PASSWORD='ab$cd'`.

Las variables que ya estén definidas en tu terminal tienen prioridad sobre `.env`. Si antes arrancaste la API sin Docker,
usa una terminal nueva.

### Arrancar

```bash
docker compose up
```

La primera vez construye las imágenes y tarda unos minutos. La web arranca cuando la API está lista.

| Qué | Dirección |
|---|---|
| Aplicación web | <http://localhost:4200> |
| API | <http://localhost:8080> |
| Swagger UI | <http://localhost:8080/swagger-ui.html> |
| API a través de la web | <http://localhost:4200/api> |

Entra en la web con `admin` (consulta, crea y borra) o con `user` (solo consulta) y la contraseña que elegiste. La
colección de Postman y sus instrucciones están en el repositorio de backend.

Los puertos solo se abren en tu equipo (`127.0.0.1`). No hay HTTPS ni límite de intentos de inicio de sesión: la
aplicación no debe exponerse en una red pública.

### Otros comandos

| Para | Comando |
|---|---|
| Arrancar en segundo plano y esperar | `docker compose up -d --wait` |
| Ver los registros | `docker compose logs -f` |
| Reconstruir tras cambiar el código | `docker compose up --build` |
| Detener | `docker compose down` |

La base de datos está en memoria: las listas se pierden al detener o reiniciar la API.

## Simular Spotify con WireMock

Contra el Spotify real los géneros salen de una lista local (`origen: LOCAL`), por la limitación que explica el
repositorio de backend. Para ver el origen `SPOTIFY` sin cuenta ni credenciales, añade el segundo archivo:

```bash
docker compose -f compose.yaml -f compose.wiremock.yaml up
```

`GET /genres` devuelve entonces `acoustic`, `pop`, `rock` y `salsa`. Las credenciales de Spotify que tengas en `.env` no
se usan. Las respuestas simuladas están en [`compose/wiremock/mappings/`](compose/wiremock/mappings/).

Para detenerlo, usa los mismos archivos:

```bash
docker compose -f compose.yaml -f compose.wiremock.yaml down
```

## Recomendaciones con IA (modelos locales)

Por defecto la IA está desactivada y `GET /lists/{listName}/recommendations` responde con una lista fija
(`origen: RESPALDO`). Un archivo adicional levanta [Ollama](https://ollama.com) y la pasarela
[LiteLLM](https://docs.litellm.ai), una base de datos PostgreSQL con pgvector para el catálogo de canciones, y activa la
IA en la API. Todo se ejecuta en tu equipo; no hay que instalar nada
fuera de Docker.

### Requisitos

| Recurso | Medido o necesario |
|---|---|
| Memoria del motor de Docker | en reposo y en CPU: `ollama` 4,3 GiB, `litellm` 1 GiB, `api` 0,4 GiB y `catalog-db` 40 MiB; deja al menos 8 GiB |
| Disco | imágenes de varios GB (Ollama es la mayor) y 2,2 GB de modelos |
| GPU | opcional: NVIDIA con controlador compatible; en Windows, Docker Desktop con WSL 2 actualizado |
| Red | solo la primera vez, para imágenes y modelos |

En Windows, la memoria del motor se amplía en `%UserProfile%\.wslconfig` (`[wsl2]`, `memory=16GB`) y reiniciando WSL.

### Clave

Añade `AI_API_KEY` a `.env`. Genera un valor aleatorio que empiece por `sk-`; LiteLLM rechaza claves vacías o
conocidas como inseguras.

```bash
echo "AI_API_KEY=sk-$(openssl rand -hex 32)" >> .env
```

```powershell
$b = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
Add-Content .env ("AI_API_KEY=sk-" + [BitConverter]::ToString($b).Replace('-', '').ToLower())
```

La configuración de la pasarela está en `compose/litellm/`: los modelos en `models.yaml`, incluido por `config.yaml`
y por `config.langfuse.yaml`.

En desarrollo local esta clave es la clave maestra de LiteLLM. Fuera de tu equipo haría falta una clave virtual con
límites, que requiere una base de datos en LiteLLM y no está incluida.

Añade también `CATALOG_DB_PASSWORD`, la contraseña que quieras para PostgreSQL (por ejemplo, `openssl rand -hex 24`).

**Si ya usabas la composición de la IA** (HU-12), añade esa variable antes de volver a levantarla: sin ella Compose no
arranca. Los modelos descargados se conservan.

### Catálogo (PostgreSQL con pgvector)

- `catalog-db` crea el esquema con [`compose/catalog-db/init.sql`](compose/catalog-db/init.sql) cuando su volumen
  `catalog-data` está vacío, y solo escucha en `127.0.0.1`.
- `catalog-index` indexa el catálogo del backend y termina; su registro dice cuántas canciones añadió, conservó y
  quitó. En CPU, indexar unas 200 canciones tardó unos 4 s. Para repetirlo:
  `docker compose -f compose.yaml -f compose.ai.yaml run --rm catalog-index`.
- La API no espera a ninguno de los dos: sin catálogo responde `RESPALDO`.
- `down -v` borra también el catálogo indexado y los modelos.

### Arrancar

```bash
docker compose -f compose.yaml -f compose.ai.yaml up -d --build
docker compose -f compose.yaml -f compose.ai.yaml logs -f ollama-init
```

El servicio `ollama-init` descarga los modelos que falten en el volumen `ollama-models`, los deja cargados y termina.
La API no espera a la IA: arranca aunque estos servicios no estén listos y responde con el respaldo mientras tanto.
`down` conserva los modelos; `down -v` obliga a descargarlos otra vez.

Con GPU NVIDIA añade el tercer archivo y comprueba que la columna `PROCESSOR` indica GPU:

```bash
docker compose -f compose.yaml -f compose.ai.yaml -f compose.ai.gpu.yaml up -d
docker compose -f compose.yaml -f compose.ai.yaml exec ollama ollama ps
```

Para no reemplazar otra pila del proyecto en el mismo equipo, añade `-p <nombre>` a todos los comandos y cambia
`API_PORT`, `WEB_PORT` y `LITELLM_PORT`.

### Latencia medida

Con `llama3.2:3b` en una RTX 5070 de 12 GB, medida antes de usar el catálogo (prompt más corto):

| Situación | CPU | GPU |
|---|---|---|
| Modelo sin cargar | 10,5 s | 3,8 s |
| En caliente | unos 8 s | menos de 1 s |
| Primera petición tras crear el contenedor con GPU | — | 26,9 s, una vez |

El backend espera 30 s (`AI_TIMEOUT`) y, si no llega la respuesta, usa el respaldo. Con 60 s o más habría que ampliar
también el tiempo de espera del servidor web.

### Variables de la IA

| Variable | Por defecto | Para qué |
|---|---|---|
| `AI_API_KEY` | — (obligatoria con `compose.ai.yaml`) | clave de LiteLLM |
| `OLLAMA_CHAT_MODEL` | `llama3.2:3b` | modelo detrás de `recomendador-chat` |
| `OLLAMA_EMBEDDING_MODEL` | `nomic-embed-text` | modelo detrás de `recomendador-embeddings` |
| `AI_TIMEOUT` | `30s` | tiempo máximo de la búsqueda y la llamada al modelo |
| `CATALOG_DB_PASSWORD` | — (obligatoria con `compose.ai.yaml`) | contraseña de PostgreSQL |
| `CATALOG_DB_PORT` | `5433` | puerto de PostgreSQL en tu equipo |
| `CATALOG_RETRIEVAL_TIMEOUT` | `5s` | tiempo máximo del embedding y la búsqueda |
| `AI_EMBEDDING_MODEL` | `recomendador-embeddings` | alias de embeddings que pide el backend |
| `AI_CHAT_MODEL` | `recomendador-chat` | alias que pide el backend |
| `LITELLM_PORT` | `4000` | puerto de LiteLLM en tu equipo |

### Seguridad de las imágenes

Las imágenes van fijadas por digest. LiteLLM sufrió publicaciones maliciosas en 2026: antes de cambiar de versión,
revisa sus [avisos](https://github.com/BerriAI/litellm/security/advisories) y verifica la firma:

```bash
docker run --rm ghcr.io/sigstore/cosign/cosign:v3.1.6 verify \
  --certificate-identity https://github.com/BerriAI/project-releaser/.github/workflows/release.yml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/berriai/litellm@<digest>
```

La versión usada (`1.111.0`) tiene un aviso de terceros sin parche, ZDI-26-1031, que el proveedor discute y requiere
ser administrador de la pasarela. Se acepta porque LiteLLM solo escucha en `127.0.0.1` y la clave no está en el
repositorio. Ollama no publica puertos y tiene desactivadas sus funciones en la nube.

## Prompts y trazas (Langfuse)

Un cuarto archivo levanta [Langfuse](https://langfuse.com) autoalojado y envía una traza por cada llamada al modelo
de chat. Es opcional y pesado: úsalo solo cuando haga falta.

```bash
docker compose -f compose.yaml -f compose.ai.yaml -f compose.langfuse.yaml up -d --build
```

Añade a `.env`, con valores aleatorios propios:

| Variable | Formato |
|---|---|
| `LANGFUSE_PUBLIC_KEY` | `pk-lf-…` |
| `LANGFUSE_SECRET_KEY` | `sk-lf-…` |
| `LANGFUSE_DB_PASSWORD` | solo letras y números (`openssl rand -hex 24`); la usan sus cuatro almacenes |
| `LANGFUSE_SALT`, `LANGFUSE_NEXTAUTH_SECRET` | `openssl rand -hex 32` |
| `LANGFUSE_ENCRYPTION_KEY` | 64 hexadecimales (`openssl rand -hex 32`) |
| `LANGFUSE_USER_PASSWORD` | contraseña para entrar; al menos 8 caracteres, con letra, número y símbolo |

Opcionales: `LANGFUSE_PORT` (3000) y `LANGFUSE_USER_EMAIL` (`admin@example.com`).

- La web queda en `http://localhost:3000`, solo en `127.0.0.1`; los almacenes no publican puertos.
- El proyecto, las claves y el usuario se crean con el volumen vacío; cambiarlos después no los actualiza.
- El prompt se publica desde el backend: `python tools/langfuse/publish_prompt.py`.
- Con Langfuse detenido, la API y la pasarela siguen funcionando.
- No incluye el AI Gateway de Langfuse: la pasarela de modelos es LiteLLM.
- Las trazas se quedan en tu equipo, sin el texto de los mensajes. `down -v` las borra; no hay retención automática.

La memoria necesaria está en [Memoria medida](#memoria-medida-con-langfuse).

### Memoria medida con Langfuse

Medida el 2026-11-27, recién arrancado y casi sin uso:

| Contenedor | Memoria |
|---|---|
| `langfuse-web` | 759 MiB |
| `langfuse-worker` | 715 MiB |
| `langfuse-clickhouse` | 296 MiB |
| `langfuse-postgres`, `langfuse-minio`, `langfuse-redis` | 212 MiB |
| **Langfuse, total** | **unos 2 GiB** |
| Resto de la pila (`litellm`, `ollama` con GPU, `api`, `catalog-db`) | unos 3 GiB |

Es una medida en reposo; con carga sube (`langfuse-web` llegó a 1,4 GiB y `ollama` a 3,3 GiB). No se amplió la memoria de Docker (`.wslconfig`). Ese mismo día, con esta
pila, otra del proyecto, un clúster local y el IDE abiertos, un equipo de 31 GB se quedó sin memoria libre y el motor
de Docker dejó de responder: no levantes Langfuse junto a otras pilas. Para soltarlo: `docker compose -f compose.yaml
-f compose.ai.yaml -f compose.langfuse.yaml down` (sin `-v`, que borraría las trazas).

## Variables opcionales

| Variable | Por defecto | Para qué |
|---|---|---|
| `WEB_PORT` | `4200` | puerto de la web en tu equipo |
| `API_PORT` | `8080` | puerto de la API en tu equipo |
| `JWT_TTL` | `30m` | vigencia del token |
| `SPOTIFY_CLIENT_ID` | — | credencial de Spotify |
| `SPOTIFY_CLIENT_SECRET` | — | credencial de Spotify |
| `SPOTIFY_ACCOUNTS_BASE_URL` | `https://accounts.spotify.com` | dirección donde se pide el token |
| `SPOTIFY_API_BASE_URL` | `https://api.spotify.com` | dirección donde se consultan los géneros |
| `SPOTIFY_TIMEOUT` | `3s` | tiempo máximo para obtener los géneros |
| `REDIS_PASSWORD` | — | contraseña opcional de Redis |
| `GENRES_CACHE_ENABLED` | `true` | activa o desactiva la caché de géneros en Redis |
| `GENRES_CACHE_TTL` | `24h` | vigencia de la caché de géneros |
| `GENRES_CACHE_TIMEOUT` | `1s` | tiempo máximo por operación en Redis |
| `PLAYLIST_EVENTS_ENABLED` | `true` | activa o desactiva los eventos de auditoría en Kafka |
| `PLAYLIST_EVENTS_TOPIC` | `playlist.events` | tópico de Kafka para `PlaylistCreated` y `PlaylistDeleted` |
| `PLAYLIST_EVENTS_CONSUMER_GROUP` | `playlist-audit` | grupo consumidor de auditoría |
| `PLAYLIST_EVENTS_PUBLISH_TIMEOUT` | `2s` | tiempo máximo por publicación hacia Kafka |

Escríbelas en `.env` solo si quieres cambiarlas: una variable vacía sustituye al valor por defecto. Con WireMock, las
cuatro de credenciales y direcciones de Spotify quedan fijadas.

## Si algo falla con Docker Compose

| Síntoma | Causa y solución |
|---|---|
| `required variable ... is missing a value` | falta esa variable en `.env` |
| `dependency api failed to start` | un valor no es válido; `docker compose logs api` dice cuál, sin mostrarlo |
| La construcción no encuentra una ruta | falta un repositorio hermano o tiene otro nombre |
| `port is already allocated` o `ports are not available` | el puerto está ocupado; cambia `WEB_PORT` o `API_PORT` |
| La web responde `502` | la API se está reiniciando o no está en marcha |

## Imágenes publicadas

Cada release de backend y frontend publica su imagen en GHCR, con el número de versión como etiqueta:

- `ghcr.io/leandroamariles/quipux-playlist-backend:X.Y.Z`
- `ghcr.io/leandroamariles/quipux-playlist-frontend:X.Y.Z`

La composición de `compose/` no las usa: sigue construyendo desde el código. Los manifiestos de `k8s/` sí las
descargan desde GHCR y fijan etiquetas explícitas mediante `kustomize`.

## Manifiestos de Kubernetes

El directorio [`k8s/`](k8s/) define el despliegue endurecido en el namespace `quipux-playlist`:

| Archivo | Recurso | Detalle principal |
|---|---|---|
| [`k8s/namespace.yaml`](k8s/namespace.yaml) | `Namespace` | Aísla los recursos en `quipux-playlist` |
| [`k8s/configmap.yaml`](k8s/configmap.yaml) | `ConfigMap` (`playlist-config`) | `JWT_TTL`, URLs y timeout de Spotify, `REDIS_HOST`/`REDIS_PORT`, `GENRES_CACHE_*`, `KAFKA_BOOTSTRAP_SERVERS`, `PLAYLIST_EVENTS_*` y `API_URL=http://api.quipux-playlist.svc.cluster.local:8080` |
| [`k8s/secret.example.yaml`](k8s/secret.example.yaml) | `Secret` de ejemplo | Plantilla vacía **excluida** de `kustomization.yaml` para evitar secretos reales en Git |
| [`k8s/api-deployment.yaml`](k8s/api-deployment.yaml) | `Deployment` (`api`) | `replicas: 1` (H2 en memoria), UID `10001`, `readOnlyRootFilesystem: true`, `emptyDir` en `/tmp`, sondas Actuator `/actuator/health/liveness` y `/readiness` sin token |
| [`k8s/api-service.yaml`](k8s/api-service.yaml) | `Service` (`api`) | Expone el puerto `8080` dentro del clúster |
| [`k8s/redis-deployment.yaml`](k8s/redis-deployment.yaml) | `Deployment` (`redis`) | Caché efímera (`--save "" --appendonly no --dir /tmp`), UID `999`, `readOnlyRootFilesystem: true`, `emptyDir` en `/tmp`, sondas `redis-cli ping` |
| [`k8s/redis-service.yaml`](k8s/redis-service.yaml) | `Service` (`redis`) | Expone el puerto `6379` (`ClusterIP`) dentro del clúster |
| [`k8s/kafka-deployment.yaml`](k8s/kafka-deployment.yaml) | `Deployment` (`kafka`) | Broker único efímero en modo KRaft (`apache/kafka-native:4.0.0`), UID `1000`, `readOnlyRootFilesystem: true`, `emptyDir` en datos/logs/config/tmp, sondas TCP `:9092` |
| [`k8s/kafka-service.yaml`](k8s/kafka-service.yaml) | `Service` (`kafka`) | Expone el puerto `9092` (`ClusterIP`) dentro del clúster |
| [`k8s/web-deployment.yaml`](k8s/web-deployment.yaml) | `Deployment` (`web`) | UID `101`, `readOnlyRootFilesystem: true`, `emptyDir` en `/etc/nginx/conf.d`, `/var/cache/nginx` y `/tmp`, sondas HTTP `GET /` |
| [`k8s/web-service.yaml`](k8s/web-service.yaml) | `Service` (`web`) | Expone el puerto `8080` dentro del clúster |
| [`k8s/kustomization.yaml`](k8s/kustomization.yaml) | `Kustomization` | Incluye los 10 manifiestos anteriores (sin `secret.example.yaml`) y las etiquetas explícitas de imagen |

### Validar los manifiestos

Opcional, con [`kustomize`](https://kubectl.docs.kubernetes.io/installation/kustomize/) y
[`trivy`](https://trivy.dev) instalados, en Bash o Git Bash:

```bash
kustomize build k8s > /tmp/rendered-k8s.yaml
trivy config --severity HIGH,CRITICAL --exit-code 1 /tmp/rendered-k8s.yaml
trivy config --severity HIGH,CRITICAL --exit-code 1 argocd
trivy fs --scanners secret --severity HIGH,CRITICAL --exit-code 1 .
```

## Integración continua, versiones y protección de `main`

Cada PR hacia `main` y cada push a `main` ejecutan dos comprobaciones ([`ci.yml`](.github/workflows/ci.yml)) con permisos
de solo lectura (`contents: read`) y acciones de terceros fijadas por SHA:

| Comprobación | Qué valida | En local |
|---|---|---|
| `kustomize` | `kustomize build k8s`, ausencia de `kind: Secret` y `replicas: 1` en `api` | `kustomize build k8s` |
| `trivy` | `trivy config` sobre el renderizado de `k8s/` y `argocd/`, y `trivy fs --scanners secret` sobre el repositorio | [Validar los manifiestos](#validar-los-manifiestos) |

- **Dependabot** ([`dependabot.yml`](.github/dependabot.yml)): revisa semanalmente las imágenes de `docker-compose` y
  los SHA de `github-actions` con mensajes en formato Conventional Commits; todos sus PR pasan el CI antes de fusionarse.
- **Versionado con `release-please`** ([`release.yml`](.github/workflows/release.yml),
  [`release-please-config.json`](release-please-config.json)): versiona el repositorio de infraestructura con
  `release-type: simple` ([`version.txt`](version.txt) y `CHANGELOG.md`), generando tags y releases en GitHub sin
  construir imágenes.

### Ajustes manuales en GitHub

1. **Protección de `main`:** exige PR y las comprobaciones `kustomize` y `trivy` en verde (también para quien es
   propietario), sin push directo, forzado ni borrado:

   ```bash
   gh api -X PUT repos/leandroAmariles/quipux-playlist-infra/branches/main/protection \
     --input .github/branch-protection.json
   gh api repos/leandroAmariles/quipux-playlist-infra/branches/main/protection
   ```

2. **Token de `release-please`:** crea un PAT de grano fino limitado a `leandroAmariles/quipux-playlist-infra` con
   **Contents**, **Pull requests** e **Issues** en lectura y escritura, y guárdalo como secreto del repositorio con
   `gh secret set RELEASE_PLEASE_TOKEN -R leandroAmariles/quipux-playlist-infra` (permite que el CI se ejecute sobre los
   PR de release).
