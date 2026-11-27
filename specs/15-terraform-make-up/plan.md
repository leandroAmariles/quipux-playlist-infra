# Implementation Plan: Clúster local con Terraform y `make up`

**Branch**: `feature/15-terraform-make-up` | **Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/15-terraform-make-up/spec.md`

## Summary

`make up` orquesta tres piezas, cada una con una sola responsabilidad:

1. **Terraform** declara los secretos, el clúster `kind` y los recursos de Kubernetes (en tres raíces con ciclos de
   vida distintos).
2. **Docker Compose** ejecuta la IA fuera del clúster, reutilizando los servicios de `compose.ai.yaml`.
3. Un **script Bash** comprueba requisitos, ordena los pasos, resuelve los casos que Terraform no cubre y espera a que
   todo esté listo.

Los pods alcanzan LiteLLM y pgvector por nombre a través de la red Docker `kind`. La web y la API se publican en
`127.0.0.1` con `NodePort` propios del entorno local, sin `port-forward`. Los manifiestos de `k8s/` no cambian.

## Technical Context

**Language/Version**: HCL (Terraform ≥ 1.9, probado con 1.15.8), GNU Make 4.4.1, Bash (compatible con 3.2)

**Primary Dependencies**: proveedores `tehcyx/kind` 0.13.0, `hashicorp/kubernetes` 3.5.0, `hashicorp/random` 3.9.1 y
`hashicorp/local` 2.9.1; `kind` 0.31.0 con `kindest/node:v1.35.0` fijada por digest; `kubectl`; Docker Compose ≥ 2.24

**Storage**: estado local de Terraform; volúmenes Docker `quipux-cluster_ollama-models` y
`quipux-cluster_catalog-data`; `.local/` (kubeconfig, entorno de Compose y registros)

**Testing**: `terraform fmt` y `validate`, `shellcheck`, Trivy en CI; aceptación manual con
[quickstart.md](quickstart.md) y `make smoke`

**Target Platform**: Windows 11 con Docker Desktop (referencia); Linux y macOS sin bloqueos conocidos, no probados. Las
imágenes del proyecto son solo `linux/amd64`

**Project Type**: infraestructura y herramientas de línea de comandos

**Performance Goals**: creación completa en 5 minutos o menos con imágenes de Docker y modelos descargados (SC-002);
repetición sin cambios en 2 minutos o menos (SC-003)

**Constraints**: puertos solo en `127.0.0.1`; sin secretos versionados ni en la salida; no tocar otros clústeres,
contenedores ni el kubeconfig del usuario; IA con 8 GB de memoria de Docker como mínimo

**Scale/Scope**: un desarrollador, un nodo, una réplica por servicio

## Constitution Check

`.specify/memory/constitution.md` es la plantilla sin rellenar: no define principios ni puertas. **PASA** por ausencia
de reglas, antes y después del diseño. Se aplican las convenciones ya presentes en el repositorio: imágenes y acciones
fijadas por digest o SHA, permisos mínimos en CI, sin secretos en Git y puertos solo en el equipo.

## Verificado antes de diseñar

| Comprobación | Resultado |
|---|---|
| Un pod resuelve por alias un contenedor de la red `kind` | `PONG` en Docker Desktop sobre Windows |
| `tehcyx/kind` crea un clúster con la imagen fijada y puertos en `127.0.0.1` | 34 s; repetir `plan` no propone cambios |
| El proveedor respeta `kubeconfig_path` | el kubeconfig del usuario no cambió |
| Nodo detenido o borrado por fuera | `plan` **falla**: lo resuelve el script |
| `extends` con `!reset` reutiliza `compose.ai.yaml` sin los repositorios hermanos | `compose config` correcto |
| `make` desde PowerShell y Git Bash, con espacios en la ruta | correcto |
| `nvidia-smi` dentro de la imagen de Ollama con `--gpus all` | detecta la RTX 5070 |

Detalle y alternativas en [research.md](research.md).

## Secuencia de `make up`

1. **Requisitos**: herramientas, Docker, memoria (aviso), puertos y clúster ajeno con el mismo nombre.
2. **`terraform/config`**: genera los secretos, escribe `.local/compose.env` y publica los interruptores.
3. **Reconciliación**: si el nodo está detenido, arrancarlo; si fue borrado, quitarlo del estado.
4. **`terraform/cluster`**: crea o actualiza el clúster y espera al API server.
5. **IA** (si está activa): `ollama` → `ollama-init` (progreso visible) → `litellm` y `catalog-db` → `catalog-index` →
   calentamiento de los modelos (research.md R12).
   Si está inactiva, detiene esos contenedores y conserva sus volúmenes.
6. **`terraform/app`**: namespace, `Secret`, `NodePort` y los manifiestos locales o Argo CD.
7. **Esperas**: despliegues disponibles (o `Synced`/`Healthy`), conexión del pod `api` con la IA y direcciones.

## Project Structure

### Documentation (this feature)

```text
specs/15-terraform-make-up/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── make-targets.md
│   ├── configuration.md
│   └── network.md
└── checklists/requirements.md
```

### Source Code (repositorio `quipux-playlist-infra`)

```text
Makefile                       # nuevo: solo delega en scripts/local.sh
scripts/
├── local.sh                   # nuevo: up, down, status, clean, credentials, smoke, validate
└── lib/                       # nuevo: preflight.sh, terraform.sh, cluster.sh, ai.sh, app.sh, warm_up.py
terraform/
├── local.tfvars.example       # nuevo: plantilla sin valores
├── config/                    # nuevo: secretos, interruptores y compose.env (sobrevive a make down)
├── cluster/                   # nuevo: kind_cluster y puertos
└── app/                       # nuevo: namespace, Secret, NodePort, manifiestos o Argo CD
compose/
└── compose.cluster.yaml       # nuevo: IA para el clúster, con extends de compose.ai.yaml
.gitignore                     # cambia: estado, tfvars y .local/
.gitattributes                 # nuevo: finales de línea LF en scripts y Makefile
.github/workflows/ci.yml       # cambia: trabajo terraform
.github/dependabot.yml         # cambia: ecosistema terraform
.github/branch-protection.json # cambia: comprobación terraform
README.md                      # cambia: make up sustituye la secuencia manual
```

No cambian `k8s/`, `argocd/` ni los demás archivos de `compose/`.

**Structure Decision**: tres raíces de Terraform porque tienen ciclos de vida distintos y porque el proveedor de
Kubernetes no puede configurarse con un clúster que todavía no existe. `config` conserva los secretos mientras exista
el volumen del catálogo, que solo toma la contraseña al crearse.

## Riesgos y limitaciones

| Riesgo | Tratamiento |
|---|---|
| `tehcyx/kind` es un proveedor de terceros y publica la clave del clúster como atributo no sensible | versión y hashes fijados; el script filtra la salida de Terraform (FR-009) |
| El estado local contiene secretos en texto plano | fuera de Git y documentado (FR-008) |
| LiteLLM y pgvector son visibles para otros contenedores de la red `kind` | exigen clave y contraseña; no publican puertos; Ollama no entra en esa red |
| `kubectl apply -k` no elimina manifiestos retirados ni detecta cambios hechos a mano | documentado: `make down && make up` |
| La API con IA puede acercarse a su límite de 512 MiB (0,4 GiB medidos en Compose) | comprobar reinicios `OOMKilled` en la aceptación antes de tocar `k8s/` |
| Cambiar los puertos recrea el clúster y se pierden las listas | el script lo avisa antes de aplicar |
| La comprobación nueva no se exige en `main` hasta actualizar la protección en GitHub | paso manual del propietario, documentado |
| Linux y macOS sin probar | se indica en el README |

## Complexity Tracking

Sin violaciones.
