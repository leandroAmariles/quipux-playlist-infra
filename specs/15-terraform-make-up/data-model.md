# Data Model: Clúster local con Terraform y `make up`

No hay datos de negocio nuevos. Estas son las entidades del entorno.

## Raíces de Terraform

| Raíz | Contiene | Entradas | Salidas | La elimina |
|---|---|---|---|---|
| `config` | `random_password`, `random_id`, `local_sensitive_file` | `local.tfvars` | secretos (sensibles), interruptores, puertos, etiqueta del backend | `make clean` |
| `cluster` | `kind_cluster.this` | puertos de `config` | `cluster_instance`, nombre | `make down` |
| `app` | namespace, `kubernetes_secret_v1`, dos `NodePort`, `terraform_data` | `config` y `cluster_instance` | direcciones | `make down` (se vacía el estado) |

## Artefactos locales

| Ruta | Contenido | Sensible | Versionado |
|---|---|---|---|
| `terraform/local.tfvars` | valores del desarrollador | sí | no |
| `terraform/*/terraform.tfstate*` | estado | sí (`config`, `cluster`, `app`) | no |
| `terraform/*/.terraform.lock.hcl` | versiones y hashes | no | **sí** |
| `.local/kubeconfig` | acceso de administrador al clúster | sí | no |
| `.local/compose.env` | clave de LiteLLM, contraseña del catálogo, modelos, etiqueta | sí | no |
| `.local/logs/` | salida completa de Terraform | sí | no |
| `.local/cluster.pending` | marca de creación en curso | no | no |
| volumen `quipux-cluster_ollama-models` | modelos | no | — |
| volumen `quipux-cluster_catalog-data` | catálogo indexado | no | — |

## Secretos

| Nombre | Generación | Regla si lo define el usuario |
|---|---|---|
| `JWT_SECRET` | 64 caracteres alfanuméricos | 32 bytes como mínimo |
| `DEMO_USER_PASSWORD`, `DEMO_ADMIN_PASSWORD` | 20 caracteres alfanuméricos | de 1 a 72 bytes |
| `AI_API_KEY` | `sk-` y 64 hexadecimales | empieza por `sk-`, solo letras, números, `-` y `_` |
| `CATALOG_DB_PASSWORD` | 32 caracteres alfanuméricos | solo letras y números |
| `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET` | vacíos | libres |

Las reglas se validan en las variables de Terraform, marcadas como sensibles: el error nombra la variable y no muestra
su valor. Cambiar `CATALOG_DB_PASSWORD` con el volumen ya creado exige `make clean`.

## Estados del entorno

| Estado | Cómo se detecta | Qué hace `make up` |
|---|---|---|
| Ausente | sin contenedor ni recurso en estado | crea todo |
| Activo | nodo en marcha y recurso en estado | converge; sin cambios, no modifica nada |
| Detenido | contenedor del nodo parado | lo arranca y converge |
| Borrado por fuera | recurso en estado sin contenedor | limpia el estado de `cluster` y `app`, y crea |
| Creación interrumpida | contenedor, sin estado, con `.local/cluster.pending` | borra el clúster a medias y crea |
| Ajeno | contenedor, sin estado y sin marca | falla y explica cómo eliminarlo |

## Transiciones

```text
Ausente --make up--> Activo --make down--> Ausente (conserva secretos y volúmenes)
Activo --reinicio de Docker--> Detenido --make up--> Activo
cualquiera --make clean (confirmado)--> Ausente sin secretos ni volúmenes
```

Interruptores: al pasar la IA de activa a inactiva, el `Secret` pierde sus claves de IA, se recrea el pod `api` y se
detienen los contenedores. Al activar Argo CD se deja de aplicar `k8s/` local; al desactivarlo se desinstala y se
vuelve a aplicar.
