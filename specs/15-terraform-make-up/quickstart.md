# Quickstart: validar HU-15

Requisitos: Docker con 8 GB o más, `git`, `make`, Terraform ≥ 1.9, `kind` y `kubectl`. Comandos desde la raíz de
`quipux-playlist-infra`. Contratos en [contracts/](contracts/).

> Antes de la primera ejecución hay que eliminar el clúster creado a mano (`kind delete cluster --name
> quipux-playlist`). Se pierden sus listas y su `Secret`.

| # | Escenario | Pasos | Resultado esperado | Cubre |
|---|---|---|---|---|
| 1 | Rechazo de clúster ajeno | con el clúster manual, `make up` | falla sin borrarlo y explica cómo | Edge |
| 2 | Requisitos | detener Docker y `make up`; ocupar `4200` y repetir | falla antes de crear, nombrando la causa | FR-003 |
| 3 | Sin IA | `make up AI=false`; `make smoke` | web y API accesibles; origen `RESPALDO`; sin contenedores de IA | US1, 2.5 |
| 4 | Con IA | `make up`; `make smoke` | origen `IA` o `SIMILITUD` | US2, SC-004 |
| 5 | Idempotencia | anotar edad de pods y contraseñas; cronometrar `make up` | ≤ 2 min, sin cambios ni reinicios | FR-006, SC-003 |
| 6 | Cambio local | modificar `k8s/configmap.yaml` sin fusionar; `make up` | el `ConfigMap` refleja el cambio; revertir | 1.6 |
| 7 | Valores propios | contraseña en `local.tfvars`; después una de 73 bytes | se usa; la inválida falla sin mostrar el valor | 1.4 |
| 8 | Secretos | revisar la salida de `up`; `git status --ignored` | sin secretos; estado y `.local/` ignorados | SC-005 |
| 9 | Ollama caído | `docker stop` de `ollama`; pedir recomendaciones de una lista nueva | `SIMILITUD` o `RESPALDO`; `make up` lo recupera | 2.3 |
| 10 | GPU | `make up GPU=off` y luego `GPU=auto`; `ollama ps` | columna `PROCESSOR`: CPU y GPU | FR-014 |
| 11 | Reinicio | `docker stop quipux-playlist-control-plane`; `make up` | vuelve a estar accesible | 3.5 |
| 12 | Borrado externo | `kind delete cluster --name quipux-playlist`; `make up` | se recrea sin pasos manuales | Edge |
| 13 | Interrupción | `Ctrl+C` durante la creación; `make up` | converge | Edge |
| 14 | `down` y `up` | anotar `docker ps -a`, `kind get clusters` y kubeconfig; `make down`; `make up` | sin descargar modelos; mismas contraseñas; lo ajeno intacto | SC-006, SC-007 |
| 15 | Tiempo | `make down`; cronometrar `make up` | ≤ 5 min | SC-002 |
| 16 | Argo CD | `make up ARGOCD=true`; `make smoke`; volver con `make up` | `Synced`/`Healthy` y la IA sigue; al volver se desinstala | US4 |
| 17 | Estabilidad | repetir `make smoke` y revisar reinicios del pod `api` | sin `OOMKilled` | riesgo |
| 18 | Compose | `docker compose -f compose.yaml -f compose.ai.yaml config` en `compose/` | sin cambios | FR-020 |
| 19 | Terminales | `make status` desde PowerShell y Git Bash | mismo resultado | FR-018 |
| 20 | Limpieza | `make clean` respondiendo no, y luego sí | solo borra al confirmar | 3.4 |
| 21 | CI | PR con la rama | `kustomize`, `trivy` y `terraform` en verde | FR-019 |

El escenario 20 borra los modelos descargados: ejecutarlo al final.

## Resultados

Equipo de referencia, 2026-11-27.

| # | Resultado | Notas |
|---|---|---|
| 1 | OK | con el clúster manual, `make up` falló sin crear estado; se eliminó tras confirmación |
| 2 | OK | Docker inaccesible (simulado con `DOCKER_HOST`) y puerto ocupado (14200): fallan sin modificar el estado |
| 3 | OK | primera creación sin IA en 81 s; origen `RESPALDO`; ningún contenedor de IA |
| 4 | OK | primera creación con IA en 193 s (modelos nuevos en el volumen; imágenes ya presentes); GPU; 214 canciones; la primera recomendación fue `SIMILITUD` y las siguientes `IA` |
| 5 | OK | sin IA 7 s; con IA 18 s; mismos pods, contenedores, reinicios, contraseñas y `Secret` |
| 6 | OK | `SPOTIFY_TIMEOUT` pasó a `6s` y volvió a `5s` |
| 7 | OK | contraseña propia aplicada en 32 s; la de 73 bytes falla sin mostrar el valor |
| 8 | OK | ningún secreto en la salida de `up`; estado y `.local/` ignorados |
| 9 | OK | con Ollama detenido, `RESPALDO`; `make up` lo recuperó en 24 s |
| 10 | OK | `100% CPU` con `GPU=off` y `100% GPU` con `auto`; falló la primera recomendación tras volver a GPU, corregido (R12) |
| 11 | OK | nodo y contenedores detenidos: accesible de nuevo en 87 s |
| 12 | OK | recreado en 97 s con aviso |
| 13 | OK | procesos de Terraform terminados durante la creación; el siguiente `up` convergió en 76 s (sin IA) |
| 14 | OK | `down` en 7 s; otros contenedores, volúmenes, clústeres y kubeconfig intactos; 0 descargas de modelos; mismas contraseñas |
| 15 | OK | creación completa tras `down`: 186 s (SC-002: 300 s) |
| 16 | OK | activación en 184 s; `Synced`/`Healthy`; origen `IA`; al volver se desinstala antes de aplicar lo local |
| 17 | OK | 5 pruebas seguidas; 0 reinicios; `api` en unos 400 MB de 512 MiB |
| 18 | OK | `compose.yaml` + `compose.ai.yaml` válidos y sin cambios |
| 19 | OK | misma salida de `make status` en PowerShell y Git Bash |
| 20 | OK | `no` cancela sin borrar; `si` y `CONFIRM=yes` borran clúster, volúmenes, estados y `.local/`, conservan `local.tfvars` y no tocan nada ajeno; el `up` posterior, sin estado, volúmenes ni proveedores, tardó 260 s |
| 21 | OK | PR #29: `kustomize`, `terraform` y `trivy` en verde |

Corregido durante la validación: con el nodo ausente, la detección del estado tomaba el clúster por ajeno.
