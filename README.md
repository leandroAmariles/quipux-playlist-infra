# quipux-playlist-infra

Infraestructura del proyecto de listas de reproducción. Hoy permite levantar la aplicación completa con Docker Compose.
Kubernetes (Kustomize) y Argo CD están **pendientes**.

La documentación del proyecto está en [quipux-playlist-backend](https://github.com/leandroAmariles/quipux-playlist-backend).
La especificación de la composición está en [`specs/07-docker-compose/`](specs/07-docker-compose/).

## Requisitos

- Git
- Docker con Compose, con el motor en marcha
- Acceso a internet la primera vez, para descargar las imágenes base y las dependencias

No hace falta instalar Java, Maven ni Node.

## Carpetas

La composición construye las imágenes desde el código, así que los tres repositorios van como carpetas hermanas y con
sus nombres originales:

```bash
git clone https://github.com/leandroAmariles/quipux-playlist-backend.git
git clone https://github.com/leandroAmariles/quipux-playlist-frontend.git
git clone https://github.com/leandroAmariles/quipux-playlist-infra.git
cd quipux-playlist-infra/compose
```

Todos los comandos siguientes se ejecutan desde `quipux-playlist-infra/compose`.

## Preparación

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

## Arrancar

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

## Otros comandos

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

Escríbelas en `.env` solo si quieres cambiarlas: una variable vacía sustituye al valor por defecto. Con WireMock, las
cuatro de credenciales y direcciones de Spotify quedan fijadas.

## Si algo falla

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

La composición de este repositorio no las usa: sigue construyendo desde el código.

## Dependencias y protección de `main`

Dependabot revisa cada semana las imágenes de Compose ([`dependabot.yml`](.github/dependabot.yml)). Sus PR se revisan a
mano porque este repositorio todavía no tiene CI.

`main` solo admite cambios por PR, sin push directo, forzado ni borrado, también para quien es propietario. La
protección no vive en el código; para aplicarla o revisarla:

```bash
gh api -X PUT repos/leandroAmariles/quipux-playlist-infra/branches/main/protection \
  --input .github/branch-protection.json
gh api repos/leandroAmariles/quipux-playlist-infra/branches/main/protection
```
