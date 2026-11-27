# quipux-playlist-infra

Infraestructura del proyecto de listas de reproducción. `make up` levanta en tu equipo la aplicación completa en un
clúster Kubernetes, con la IA en Docker. También se puede usar solo Docker Compose.

La documentación del proyecto está en [quipux-playlist-backend](https://github.com/leandroAmariles/quipux-playlist-backend).
Las especificaciones de infraestructura están en [`specs/07-docker-compose/`](specs/07-docker-compose/),
[`specs/09-kubernetes-argocd/`](specs/09-kubernetes-argocd/) y
[`specs/15-terraform-make-up/`](specs/15-terraform-make-up/).

## Tecnologías

| Capa | Tecnología | Para qué |
|---|---|---|
| Web | Angular 22, TypeScript 6, nginx 1.31 | interfaz; nginx sirve la web y reenvía `/api` a la API |
| API | Java 21, Spring Boot 4.1.3 con WebFlux, springdoc 3.2 | API REST reactiva y Swagger UI |
| Seguridad | Spring Security (OAuth2 Resource Server) con JWT | inicio de sesión y roles `admin` y `user` |
| Resiliencia | Resilience4j | cortacircuitos ante fallos del modelo |
| Base de datos | H2 en memoria con R2DBC | listas de reproducción |
| Caché | Redis 8.12 y Caffeine | géneros en Redis; recomendaciones en la memoria de la API |
| Mensajería | Apache Kafka 4.0 (KRaft, sin ZooKeeper) | eventos de auditoría de las listas |
| IA: integración | Spring AI 2.0 | llamadas desde la API a los modelos |
| IA: pasarela | LiteLLM 1.111 | alias de modelos y clave de acceso |
| IA: modelos | Ollama 0.40 con `llama3.2:3b` y `nomic-embed-text` | recomendaciones y embeddings, en local |
| IA: catálogo | PostgreSQL 18 con pgvector 0.8.7 | búsqueda de canciones por similitud |
| Infraestructura como código | Terraform 1.9 o posterior (proveedores `kind`, `kubernetes`, `random` y `local`) | secretos, clúster y recursos de Kubernetes |
| Clúster | kind 0.31 con Kubernetes 1.35 y Kustomize | clúster local y manifiestos |
| Contenedores | Docker y Docker Compose | IA del clúster y alternativa sin Kubernetes |
| Automatización | GNU Make y Bash | comandos `make` |
| Despliegue continuo | Argo CD 3.5.9 (opcional) | sincroniza `k8s/` desde `main` |
| Integración continua | GitHub Actions, Trivy, ShellCheck, Dependabot y release-please | validación, seguridad, actualizaciones y versiones |
| Opcionales con Docker Compose | Langfuse y WireMock | trazas de los modelos y simulación de Spotify |

Las versiones exactas están fijadas en [`k8s/`](k8s/), [`compose/`](compose/), [`terraform/`](terraform/) y en los
repositorios de [backend](https://github.com/leandroAmariles/quipux-playlist-backend) y
[frontend](https://github.com/leandroAmariles/quipux-playlist-frontend).

### Cómo encaja

```text
make up ──> Terraform ──> clúster kind ─┬─ web (:4200) ──> api (:8080) ─┬─ redis
        │                               └───────────────────────────────┴─ kafka
        │                                                  │
        └─> Docker Compose (fuera del clúster)             ├──> litellm ──> ollama (GPU o CPU)
                                                           └──> catalog-db (pgvector)
```

## Cómo levantarlo en local

| | [Clúster con `make up`](#clúster-local-con-make-up) | [Docker Compose](#docker-compose) |
|---|---|---|
| Qué levanta | clúster Kubernetes (kind) e IA en Docker | los contenedores, sin Kubernetes |
| Imágenes de la API y la web | las publicadas en GHCR (no compila tu código) | se construyen desde tu código |
| Repositorios necesarios | solo este | los tres |
| Herramientas | Git, Docker, `make`, Terraform, `kind` y `kubectl` | Git y Docker con Compose |
| IA local | incluida, se puede desactivar | opcional |
| WireMock y Langfuse | no incluidos | opcionales |

Las dos opciones usan los puertos `4200` y `8080`: detén una antes de arrancar la otra. En ninguna hace falta instalar
Java, Maven ni Node, y las dos necesitan internet la primera vez.

## Clúster local con `make up`

Un solo comando crea un clúster [kind](https://kind.sigs.k8s.io) con la web, la API, Redis y Kafka, arranca en Docker
la IA (Ollama, LiteLLM y PostgreSQL con pgvector) y conecta ambos. Especificación en
[`specs/15-terraform-make-up/`](specs/15-terraform-make-up/).

Los pasos se ejecutan en PowerShell o en Bash; donde difieren se muestran los dos. Se probaron en Windows 11 con
Docker 29.6, Compose 5.3, Terraform 1.15, `kind` 0.31, `kubectl` 1.34 y GNU Make 4.4. Linux y macOS no se han probado.
Las imágenes del proyecto solo se publican para `linux/amd64`.

### Paso 1. Preparar Docker

- Arranca Docker (en Windows y macOS, Docker Desktop). Necesita Compose 2.24 o posterior.
- Con la IA, asigna al menos 8 GB de memoria a Docker. En Windows se configura en `%UserProfile%\.wslconfig`
  (`[wsl2]`, `memory=16GB`) y reiniciando WSL.
- Opcional: GPU NVIDIA con un controlador compatible; en Windows, Docker Desktop con WSL 2 actualizado. Sin GPU, la IA
  usa la CPU.

### Paso 2. Instalar las herramientas

Hacen falta Git, `curl`, GNU `make`, [Terraform](https://developer.hashicorp.com/terraform/install) 1.9 o posterior,
[`kind`](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) y
[`kubectl`](https://kubernetes.io/docs/tasks/tools/). No hace falta Java, Maven, Node ni `kustomize`.

```powershell
# Windows (choco requiere Chocolatey)
winget install -e --id Git.Git
winget install -e --id Hashicorp.Terraform
winget install -e --id Kubernetes.kind
winget install -e --id Kubernetes.kubectl
choco install make
```

```bash
# macOS
brew install git make kind kubectl hashicorp/tap/terraform
```

Abre una terminal nueva y comprueba que todo responde:

```bash
docker compose version
terraform version
kind version
kubectl version --client
make --version
```

### Paso 3. Clonar este repositorio

No necesitas los repositorios de backend ni de frontend.

```bash
git clone https://github.com/leandroAmariles/quipux-playlist-infra.git
cd quipux-playlist-infra
```

### Paso 4. Configurar (opcional)

Sin configurar nada se generan las contraseñas y se usan los valores por defecto. Para cambiar puertos, contraseñas,
credenciales de Spotify o el uso de la GPU, copia la plantilla y descomenta lo que necesites
([variables](#configuración)):

```powershell
Copy-Item terraform/local.tfvars.example terraform/local.tfvars
```

```bash
cp terraform/local.tfvars.example terraform/local.tfvars
```

### Paso 5. Levantar

```bash
make up
```

Sin IA, más rápido y ligero: `make up AI=false`.

El comando comprueba los requisitos, genera los secretos, crea el clúster, prepara la IA, despliega la aplicación y
espera a que todo responda. La primera vez descarga imágenes de varios GB y 2,2 GB de modelos. Termina así:

```text
Entorno listo (IA: GPU, Argo CD: no)
  Web      http://localhost:4200
  API      http://localhost:8080
  Swagger  http://localhost:8080/swagger-ui.html
```

En el equipo de referencia (RTX 5070), crear todo desde cero, incluidos los modelos y con las imágenes de Docker ya
descargadas, tardó unos 4 minutos y medio; después de `make down`, unos 3 con IA y menos de minuto y medio sin ella;
repetirlo sin cambios, menos de 20 segundos.

### Paso 6. Ver las contraseñas

```bash
make credentials
```

Muestra las de `admin` (consulta, crea y borra) y `user` (solo consulta).

### Paso 7. Comprobar que funciona

```bash
make smoke    # inicia sesión, crea una lista temporal, pide recomendaciones y la borra
make status   # clúster, pods, contenedores de IA y direcciones
```

Con la IA, las recomendaciones tienen origen `IA` o `SIMILITUD`; sin ella, `RESPALDO`.

### Paso 8. Usar la aplicación

| Qué | Dirección |
|---|---|
| Aplicación web | <http://localhost:4200> |
| API a través de la web | <http://localhost:4200/api> |
| API | <http://localhost:8080> |
| Swagger UI | <http://localhost:8080/swagger-ui.html> |

No hace falta `port-forward`. Los puertos solo se abren en tu equipo (`127.0.0.1`). No hay HTTPS ni límite de intentos
de inicio de sesión: no lo expongas en una red pública.

Para probar la API desde la terminal, en PowerShell, con la contraseña de `admin` del paso 6:

```powershell
$base = 'http://localhost:4200/api'
$body = @{ username = 'admin'; password = '<contraseña-de-admin>' } | ConvertTo-Json
$login = Invoke-RestMethod -Method Post -Uri "$base/auth/login" -ContentType 'application/json' -Body $body
$headers = @{ Authorization = "Bearer $($login.accessToken)" }

$song = @{ titulo = 'Uno'; artista = 'Artista'; album = 'Album'; anno = '1999'; genero = 'rock' }
$list = @{ nombre = 'Demo'; descripcion = 'Prueba'; canciones = @($song) } | ConvertTo-Json -Depth 4
Invoke-RestMethod -Method Post -Uri "$base/lists" -Headers $headers -ContentType 'application/json' -Body $list
Invoke-RestMethod -Uri "$base/lists/Demo" -Headers $headers
Invoke-RestMethod -Uri "$base/lists/Demo/recommendations" -Headers $headers
Invoke-RestMethod -Method Delete -Uri "$base/lists/Demo" -Headers $headers
```

En Bash o Git Bash:

```bash
BASE=http://localhost:4200/api
ADMIN_PASS="$(make -s credentials | awk '$1 == "admin" { print $2 }')"
TOKEN="$(curl -s -X POST "$BASE/auth/login" -H 'Content-Type: application/json' \
  -d "{\"username\":\"admin\",\"password\":\"$ADMIN_PASS\"}" | sed 's/.*"accessToken":"\([^"]*\)".*/\1/')"
AUTH="Authorization: Bearer $TOKEN"

curl -i -X POST "$BASE/lists" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"nombre":"Demo","descripcion":"Prueba","canciones":[{"titulo":"Uno","artista":"Artista","album":"Album","anno":"1999","genero":"rock"}]}'
curl -i "$BASE/lists/Demo" -H "$AUTH"
curl -i "$BASE/lists/Demo/recommendations" -H "$AUTH"
curl -i -X DELETE "$BASE/lists/Demo" -H "$AUTH"
```

La colección de Postman está en el repositorio de backend. Para ver los eventos de auditoría y usar `kubectl`, el
entorno tiene su propio archivo y no cambia tu contexto actual:

```bash
kubectl --kubeconfig .local/kubeconfig -n quipux-playlist get pods
kubectl --kubeconfig .local/kubeconfig -n quipux-playlist logs deployment/api
```

### Paso 9. Detener o limpiar

```bash
make down    # elimina el clúster y los contenedores; conserva contraseñas, modelos y catálogo
make up      # lo vuelve a levantar sin descargar los modelos
make clean   # borra además modelos, catálogo, secretos y estado; pide confirmación
```

### Comandos

| Comando | Qué hace |
|---|---|
| `make up` | crea o actualiza el entorno; repetirlo sin cambios no modifica nada |
| `make status` | clúster, pods, contenedores de IA y direcciones |
| `make down` | elimina el clúster y los contenedores; conserva secretos, modelos y catálogo |
| `make clean` | además borra modelos, catálogo, secretos y estado; pide confirmación (`CONFIRM=yes` sin terminal) |
| `make credentials` | muestra las contraseñas de demostración |
| `make smoke` | prueba de extremo a extremo con una lista temporal |
| `make validate` | valida Terraform y, si está instalado `shellcheck`, los scripts |

`AI=true|false`, `GPU=auto|on|off` y `ARGOCD=true|false` cambian la configuración **solo en esa ejecución**: el
siguiente `make up` sin ellos vuelve a lo configurado.

Tras reiniciar Docker o el equipo, `make up` vuelve a dejar el entorno accesible. Los cambios en `k8s/` se aplican con
`make up`, aunque no estén fusionados.

### Configuración

Todo tiene un valor por defecto. Para cambiarlo, copia
[`terraform/local.tfvars.example`](terraform/local.tfvars.example) como `terraform/local.tfvars` (no se versiona).

| Variable | Por defecto | Para qué |
|---|---|---|
| `ai_enabled` | `true` | IA en Docker y su conexión con la API |
| `gpu` | `"auto"` | usar la GPU si Docker la ve; `"on"` la exige y `"off"` usa CPU |
| `argocd_enabled` | `false` | desplegar `main` con Argo CD |
| `web_port`, `api_port` | `4200`, `8080` | puertos en tu equipo; cambiarlos recrea el clúster |
| `demo_user_password`, `demo_admin_password` | generadas | de 1 a 72 bytes |
| `jwt_secret` | generado | 32 bytes como mínimo |
| `spotify_client_id`, `spotify_client_secret` | vacíos | credenciales opcionales de Spotify |
| `ai_api_key` | generada | clave de LiteLLM; empieza por `sk-` |
| `catalog_db_password` | generada | solo letras y números; cambiarla exige `make clean` |
| `ollama_chat_model`, `ollama_embedding_model` | `llama3.2:3b`, `nomic-embed-text` | modelos locales |
| `ai_timeout` | `30s` | tiempo máximo de la recomendación |

### Dónde quedan los secretos

`make up` genera los que no definas y los conserva hasta `make clean`. Ninguno se versiona ni aparece en la salida, pero
**están en texto plano en tu equipo**:

| Ubicación | Contenido |
|---|---|
| `terraform/*/terraform.tfstate*` | todos los secretos y la clave de administrador del clúster |
| `.local/` | `kubeconfig`, `compose.env` y los registros completos de Terraform |
| `terraform/local.tfvars` | lo que tú definas |
| `Secret` `playlist-secrets` del clúster | lo que lee la API |

### IA en Docker

- Ollama, LiteLLM y `catalog-db` corren como el proyecto de Compose `quipux-cluster`
  ([`compose/compose.cluster.yaml`](compose/compose.cluster.yaml)), con las mismas imágenes y modelos que
  `compose.ai.yaml`. Usan sus propios volúmenes, independientes de otras composiciones.
- Ninguno publica puertos en tu equipo. LiteLLM y PostgreSQL se unen a la red Docker `kind` para que los pods los
  alcancen: otros contenedores de esa red (por ejemplo, otros clústeres kind) también los ven y necesitan la clave o la
  contraseña. Ollama no entra en esa red.
- `make up` termina calentando los modelos: sin eso, las primeras peticiones tras crear Ollama con GPU tardan unos
  30 segundos y las recomendaciones salen de respaldo.
- Con `gpu = "auto"` se usa la GPU si un contenedor la ve. Comprobarlo:
  `docker exec quipux-cluster-ollama-1 ollama ps` (columna `PROCESSOR`).
- La API no depende de la IA: si se detiene, responde recomendaciones por similitud o de respaldo.
- Sin IA, las recomendaciones responden con `origen: RESPALDO`.

Sin credenciales de Spotify los géneros salen de la lista local y Redis queda vacío, porque solo guarda los de Spotify.
La base de datos de la aplicación está en memoria: las listas se pierden cada vez que se reinicia la API.

### Si algo falla en el clúster

| Síntoma | Causa y solución |
|---|---|
| `ya existe un clúster kind 'quipux-playlist' que no creó make up` | clúster creado a mano: bórralo con el comando que indica el mensaje |
| `el puerto ... está ocupado` | libéralo o cambia `web_port` / `api_port` |
| `Docker no responde` | arranca Docker |
| `terraform ... falló` | el mensaje indica el registro en `.local/logs/` |
| Un despliegue no está listo | los comandos del mensaje muestran el motivo; `make status` resume |
| La indexación o los modelos fallan | revisa la conexión y repite `make up`; continúa donde quedó |
| Se interrumpió la creación | repite `make up` |
| Se retiró un recurso de `k8s/` y sigue en el clúster | `make up` no lo elimina: `make down` y `make up` |

### Limitaciones

- `make up` aplica `k8s/` cuando cambian sus archivos: no revierte cambios hechos a mano ni elimina recursos retirados.
- Un solo nodo y una réplica por servicio; el estado de Terraform es local. Es un entorno de desarrollo.

## Despliegue continuo con Argo CD

Argo CD observa la rama `main` de este repositorio mediante [`argocd/application.yaml`](argocd/application.yaml)
(`path: k8s`, `prune: true`, `selfHeal: true`), sin desplegar desde GitHub Actions ni dar credenciales del clúster a los
workflows. No toca `playlist-secrets`, excluido de `kustomization.yaml`, ni la configuración de IA que va en él.

```bash
make up ARGOCD=true   # instala Argo CD v3.5.9 y espera a Synced y Healthy
make up               # vuelve a los manifiestos locales y desinstala Argo CD
```

Para dejarlo activado, define `argocd_enabled = true` en `terraform/local.tfvars`. Con Argo CD se despliega lo que hay en
`main` en GitHub, no tus archivos locales. Si usas un fork, cambia `repoURL` en `argocd/application.yaml`.

### Acceso a la consola de Argo CD

Contraseña inicial en Bash o Git Bash:

```bash
kubectl --kubeconfig .local/kubeconfig -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

En PowerShell:

```powershell
$encoded = kubectl --kubeconfig .local/kubeconfig -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}"
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
```

Después abre el acceso:

```bash
kubectl --kubeconfig .local/kubeconfig -n argocd port-forward svc/argocd-server 8443:443
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
trivy config --severity HIGH,CRITICAL --exit-code 1 terraform
trivy fs --scanners secret --severity HIGH,CRITICAL --exit-code 1 .
```

## Integración continua, versiones y protección de `main`

Cada PR hacia `main` y cada push a `main` ejecutan tres comprobaciones ([`ci.yml`](.github/workflows/ci.yml)) con permisos
de solo lectura (`contents: read`) y acciones de terceros fijadas por SHA:

| Comprobación | Qué valida | En local |
|---|---|---|
| `kustomize` | `kustomize build k8s`, ausencia de `kind: Secret` y `replicas: 1` en `api` | `kustomize build k8s` |
| `terraform` | formato y validez de `terraform/`, y `shellcheck` de los scripts, sin credenciales ni clúster | `make validate` |
| `trivy` | `trivy config` sobre el renderizado de `k8s/`, `argocd/` y `terraform/`, y `trivy fs --scanners secret` sobre el repositorio | [Validar los manifiestos](#validar-los-manifiestos) |

- **Dependabot** ([`dependabot.yml`](.github/dependabot.yml)): revisa semanalmente las imágenes de `docker-compose`, los
  proveedores de `terraform` y los SHA de `github-actions` con mensajes en formato Conventional Commits; todos sus PR pasan el CI antes de fusionarse.
- **Versionado con `release-please`** ([`release.yml`](.github/workflows/release.yml),
  [`release-please-config.json`](release-please-config.json)): versiona el repositorio de infraestructura con
  `release-type: simple` ([`version.txt`](version.txt) y `CHANGELOG.md`), generando tags y releases en GitHub sin
  construir imágenes.

### Ajustes manuales en GitHub

1. **Protección de `main`:** exige PR y las comprobaciones `kustomize`, `terraform` y `trivy` en verde (también para quien es
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
