# Research: Clúster local con Terraform y `make up`

Fecha: 2026-11-27. Equipo: Windows 11, Docker 29.6.1, Compose 5.3.0, Terraform 1.15.8, `kind` 0.31.0, Make 4.4.1.
Las pruebas usaron recursos temporales que se eliminaron; el clúster `quipux-playlist` no se modificó, salvo un pod y
un contenedor efímeros para la prueba de red.

## R1. Reparto entre Terraform, Compose y script

- **Decision**: Terraform para secretos, clúster y recursos de Kubernetes; Docker Compose para la IA; Bash para el
  orden y las esperas.
- **Rationale**: FR-012 exige una sola definición de la IA y ya existe en `compose.ai.yaml`, con healthchecks y tareas de
  un solo uso que Compose resuelve de forma nativa.
- **Alternatives**: proveedor `kreuzwerker/docker` (duplica imágenes, variables y healthchecks); invocar Compose desde
  `local-exec` (Terraform no vería su estado y el orden de destrucción sería frágil).
- **Consecuencia**: Terraform no gestiona los contenedores de IA. Es una lectura de FR-001: «el clúster y sus recursos»
  son los de Kubernetes; la IA es una dependencia externa en Docker.

## R2. Proveedor del clúster

- **Decision**: `tehcyx/kind` 0.13.0, con `node_image` `kindest/node:v1.35.0@sha256:452d707d…1ac31f` y
  `kubeconfig_path` en `.local/kubeconfig`.
- **Rationale**: creó el clúster en 34 s, publicó `127.0.0.1:14200->30080`, no tocó el kubeconfig del usuario y un
  segundo `plan` salió sin cambios.
- **Alternatives**: `terraform_data` con `kind create cluster` (sin estado real ni detección de reemplazo).
- **Hallazgos**:
  - Con el nodo detenido, `plan` falla (`failed to get cluster internal kubeconfig`). El script ejecuta `docker start`
    antes de Terraform.
  - Con el clúster borrado por fuera, `plan` y `destroy` fallan (`could not locate any control plane nodes`). El script
    detecta que no hay contenedor y ejecuta `terraform state rm`.
  - Tras `docker start`, el API server respondió `Forbidden` unos instantes: la espera debe reintentar.
  - `client_key` y `kubeconfig` no están marcados como sensibles: la salida de Terraform se guarda en `.local/logs/` y
    solo se muestran el progreso y los errores.

## R3. Estados separados

- **Decision**: raíces `config`, `cluster` y `app`; `cluster` y `app` leen a `config` con `terraform_remote_state` local.
- **Rationale**: los secretos deben sobrevivir a `make down` (FR-007); PostgreSQL solo aplica la contraseña al crear el
  volumen. El proveedor de Kubernetes necesita un kubeconfig existente al planificar.
- **Alternatives**: raíz única (configuración de proveedor con valores desconocidos); `-target` en cada paso (desaconsejado
  por Terraform para uso habitual).
- `app` recibe `cluster_instance` (hash de la CA) para volver a aplicar todo cuando el clúster es otro. Al destruir el
  clúster, el estado de `app` se vacía con `terraform state rm`.

## R4. Red entre pods y Docker

- **Decision**: `litellm` y `catalog-db` se unen a la red externa `kind` con los alias `quipux-litellm` y
  `quipux-catalog-db`. Ollama queda solo en la red interna de Compose.
- **Rationale**: un pod hizo `redis-cli -h <alias> ping` contra un contenedor temporal de esa red y obtuvo `PONG`. Los
  nombres sobreviven a cambios de IP.
- **Alternatives**: `host.docker.internal` (obliga a publicar puertos y no es portable a Linux); `Service` sin selector con
  la IP del contenedor (la IP cambia al reiniciar).

## R5. Acceso a la web y la API

- **Decision**: `extraPortMappings` `127.0.0.1:4200→30080` y `127.0.0.1:8080→30081`, con `Service` `web-local` y
  `api-local` de tipo `NodePort` creados por Terraform.
- **Rationale**: cumple FR-005 sin tocar `k8s/`. Argo CD no gestiona esos servicios y no los elimina.
- **Alternatives**: superposición de Kustomize (Argo CD despliega `k8s/` y revertiría el tipo); ingress (más piezas);
  `port-forward` en segundo plano (muere al reiniciar el pod).

## R6. Configuración de IA compatible con Argo CD

- **Decision**: las variables de IA van en el `Secret` `playlist-secrets`, que crea Terraform.
- **Rationale**: el `Deployment` ya lo lee con `envFrom` después del `ConfigMap`, y está fuera de `kustomization.yaml`:
  Argo CD no lo revierte y no hace falta fusionar nada en `main` (FR-017).
- **Alternatives**: añadirlas al `ConfigMap` (Argo CD las revierte); un `ConfigMap` nuevo (exige cambiar el `Deployment`
  en `main`).
- **Coste**: valores no secretos como `AI_PROVIDER` quedan en un `Secret`.
- Al cambiar el `Secret`, se elimina el pod `api` para que se recree; no altera el manifiesto que Argo CD compara.

## R7. Aplicación de los manifiestos y Argo CD

- **Decision**: `terraform_data` con `local-exec` de `kubectl apply -k k8s`, disparado por el hash de los archivos y por
  `cluster_instance`. Con Argo CD activo no se aplica y se instala el manifiesto `v3.5.9` más
  `argocd/application.yaml`.
- **Rationale**: es el mismo comando que ya documenta el README y usa Argo CD; alternar Argo CD no destruye la aplicación.
- **Alternatives**: `kbst/kustomization` (al activar Argo CD destruiría los recursos para que Argo los recree);
  `helm_release` de Argo CD (cambia la forma de instalación ya probada).
- **Limitaciones**: no poda ni detecta cambios manuales.
- Los comandos de `local-exec` se ejecutan desde la raíz del repositorio, con rutas relativas y `KUBECONFIG` por
  variable de entorno, para no citar rutas con espacios en `cmd`.

## R8. Reutilizar Compose

- **Decision**: `compose.cluster.yaml`, proyecto `quipux-cluster`, con `extends` de cada servicio de `compose.ai.yaml`,
  `ports: !reset []`, red `kind` y, en `catalog-index`, `build: !reset null` con la imagen publicada del backend.
- **Rationale**: `docker compose config` resolvió imágenes, dependencias y volúmenes sin los repositorios hermanos.
  `compose.ai.gpu.yaml` se añade sin cambios. Los volúmenes deben declararse de nuevo.
- La etiqueta del backend se toma de `k8s/kustomization.yaml` (raíz `config`). La `v0.4.0` incluye `index-catalog`.
- El proyecto propio evita tocar la pila `quipux-ia`; la primera vez descarga sus modelos (2,2 GB).
- Orden: `up -d --wait ollama`, `run --rm ollama-init`, `up -d --wait --no-deps litellm catalog-db`,
  `run --rm --no-deps catalog-index`.

## R9. GPU

- **Decision**: `gpu = "auto"` prueba `docker run --rm --gpus all --entrypoint nvidia-smi <imagen de Ollama> -L`; con
  éxito añade `compose.ai.gpu.yaml`. `on` falla si no hay GPU; `off` usa CPU.
- **Rationale**: comprueba la ruta real de Docker, no solo el controlador del equipo. La prueba detectó la RTX 5070.

## R10. Portabilidad de `make`

- **Decision**: el `Makefile` solo llama a `scripts/local.sh`. En Windows localiza Git Bash con `git --exec-path`; en
  otros sistemas usa `bash`.
- **Rationale**: funcionó desde PowerShell y Git Bash en una ruta con espacios, y evita el `bash.exe` de WSL.
- `.gitattributes` fuerza LF para que los scripts no se rompan con `core.autocrlf`.
- **Alternatives**: scripts duplicados en PowerShell y Bash; Python (requisito nuevo).

## R11. Integración continua

- **Decision**: trabajo `terraform` con `hashicorp/setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e` (`v4.0.1`):
  `fmt -check`, `init -backend=false` y `validate` por raíz, y `shellcheck`. El trabajo `trivy` analiza también
  `terraform/`. Los `.terraform.lock.hcl` incluyen `windows_amd64`, `linux_amd64` y `darwin_arm64`.
- Dependabot añade el ecosistema `terraform`. La imagen del nodo se actualiza a mano.

## R12. Calentamiento de los modelos (hallado al implementar)

- **Problema**: justo después de crear Ollama con GPU, el primer embedding pedido por la pasarela tardó entre 7,5 y 18 s y
  el primer chat unos 26 s. El backend corta la búsqueda a los 5 s, así que la primera recomendación salía
  `RESPALDO` aunque `make up` hubiera terminado (contra el escenario 2.1 de la spec). La precarga de `ollama-init` no
  lo evita.
- **Decision**: `scripts/lib/warm_up.py`, ejecutado dentro del contenedor `litellm`, pide un embedding y un chat por los
  mismos alias que usa la API hasta que respondan en 3 s y 20 s (5 intentos como máximo).
- **Rationale**: tras añadirlo, la primera recomendación posterior a recrear Ollama salió `IA`. No crea datos en la
  aplicación ni consume su cupo de recomendaciones. Con los modelos calientes añade menos de 1 s.
- **Alternatives**: pedir una recomendación real desde `make up` (crea listas y eventos de auditoría); ampliar
  `CATALOG_RETRIEVAL_TIMEOUT` (cambia el comportamiento de la aplicación).
