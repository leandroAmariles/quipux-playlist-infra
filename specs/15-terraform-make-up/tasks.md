# Tasks: Clúster local con Terraform y `make up`

**Input**: documentos de `specs/15-terraform-make-up/` ([plan.md](plan.md), [spec.md](spec.md),
[research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md))

**Prerequisites**: rama `feature/15-terraform-make-up`. Todas las rutas son relativas a la raíz de
`quipux-playlist-infra`.

**Tests**: la spec no pide pruebas automatizadas. Cada historia cierra con una tarea que ejecuta sus escenarios de
`quickstart.md`; anotar en ese archivo el resultado real (fecha, tiempos y desviaciones).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede hacerse en paralelo (archivos distintos y sin depender de tareas pendientes)
- **[Story]**: historia de `spec.md` (US1 a US4)

---

## Phase 1: Setup

**Purpose**: estructura y protecciones previas a generar cualquier secreto.

- [X] T001 Añadir a `.gitignore` las exclusiones de los artefactos marcados como no versionados en `data-model.md`
  (Artefactos locales): `.local/`, `terraform/local.tfvars`, `**/.terraform/`, `*.tfstate`, `*.tfstate.*`, `*.tfplan` y
  `crash*.log`; comprobar con `git check-ignore` que `.terraform.lock.hcl` y `terraform/local.tfvars.example` sí se
  versionan
- [X] T002 [P] Crear `.gitattributes` que fuerce `eol=lf` en `Makefile`, `*.sh`, `*.tf` y `*.yaml` (research.md R10)
- [X] T003 [P] Crear `terraform/local.tfvars.example` con todas las variables de `contracts/configuration.md`
  comentadas, sin valores secretos
- [X] T004 [P] Crear `Makefile` con los comandos y parámetros de `contracts/make-targets.md` (`help` por defecto), que
  solo delegue en `scripts/local.sh` y localice Bash como indica research.md R10
- [X] T005 Crear `scripts/local.sh` (compatible con Bash 3.2, `set -euo pipefail`, trabaja desde la raíz del
  repositorio): despacho de subcomandos, lectura de `AI`, `GPU`, `ARGOCD` y `CONFIRM` con rechazo de valores no
  admitidos, errores en una línea `ERROR:` y creación de `.local/logs/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: secretos, clúster y librerías que usan todas las historias.

**⚠️ CRITICAL**: ninguna historia empieza antes de terminar esta fase.

- [X] T006 [P] Crear `terraform/config/versions.tf` y `terraform/config/variables.tf` con las variables de
  `contracts/configuration.md`; marcar los secretos como `sensitive` y validar `data-model.md`
  `Secretos.JWT_SECRET`, `Secretos.DEMO_USER_PASSWORD`, `Secretos.DEMO_ADMIN_PASSWORD`, `Secretos.AI_API_KEY`,
  `Secretos.CATALOG_DB_PASSWORD`, `Secretos.SPOTIFY_CLIENT_ID` y `Secretos.SPOTIFY_CLIENT_SECRET` (longitudes en
  bytes, sin mostrar el valor en el error); validar también `gpu` y los puertos
- [X] T007 Crear `terraform/config/main.tf`: generar cada secreto no definido según la columna de generación de
  `data-model.md` (Secretos), obtener `BACKEND_TAG` del `newTag` del backend en `k8s/kustomization.yaml` y escribir
  `.local/compose.env` con `local_sensitive_file` (claves en `contracts/configuration.md`)
- [X] T008 Crear `terraform/config/outputs.tf` con secretos (sensibles), interruptores, puertos, modelos, `ai_timeout`
  y etiqueta del backend
- [X] T009 [P] Crear `terraform/cluster/` (`versions.tf`, `main.tf`, `outputs.tf`): leer `config` con
  `terraform_remote_state`, `kind_cluster` `quipux-playlist` según research.md R2 con los `extraPortMappings` de
  `contracts/network.md`, y salidas `cluster_instance` (hash de la CA) y nombre
- [X] T010 [P] Crear `scripts/lib/terraform.sh`: `init` y `apply` por raíz con `-var-file=../local.tfvars` si existe y
  los `-var` de `AI`, `GPU` y `ARGOCD` después (solo en `config`); guardar la salida completa en `.local/logs/`, mostrar
  únicamente progreso, resumen y bloques de error, y comprobar que ningún valor sensible llega a la terminal (FR-009,
  research.md R2)
- [X] T011 [P] Crear `scripts/lib/preflight.sh`: herramientas y versiones mínimas, Docker en marcha, Compose ≥ 2.24,
  puertos `web_port` y `api_port` libres o ya publicados por el nodo propio, y aviso si la IA está activa con menos de
  8 GB en Docker, indicando `AI=false`; antes de crear nada (FR-003, Edge Cases de `spec.md`)
- [X] T012 Crear `scripts/lib/cluster.sh` con los estados de `data-model.md` (Estados del entorno): detectar cada uno,
  arrancar el nodo detenido, `state rm` en `cluster` y `app` si fue borrado, gestionar `.local/cluster.pending`,
  rechazar el clúster ajeno sin borrarlo, avisar si el plan reemplaza el clúster y esperar con reintentos a que el API
  server y el nodo estén listos usando `.local/kubeconfig`

**Checkpoint**: `terraform validate` correcto en `config` y `cluster`.

---

## Phase 3: User Story 1 - Levantar el clúster y la aplicación (Priority: P1) 🎯 MVP

**Goal**: `make up AI=false` deja la web y la API accesibles sin pasos manuales.

**Independent Test**: sin clúster previo, `make up AI=false`, iniciar sesión como `admin` y crear una lista;
`make smoke` termina con éxito.

- [X] T013 [US1] Crear `terraform/app/versions.tf` y `terraform/app/variables.tf`: proveedor `kubernetes` con
  `.local/kubeconfig`, estado remoto de `config` y variable `cluster_instance`
- [X] T014 [US1] Crear `terraform/app/main.tf`: namespace con `terraform_data` (`kubectl apply -f
  k8s/namespace.yaml`), `kubernetes_secret_v1` `playlist-secrets` con las claves fijas de
  `contracts/configuration.md`, y los `Service` `web-local` y `api-local` de `contracts/network.md`
- [X] T015 [US1] Añadir en `terraform/app/manifests.tf` el `terraform_data` de `kubectl apply -k k8s` (disparadores:
  `cluster_instance` y hash de `k8s/**`) y el que elimina el pod `api` cuando cambia el hash del `Secret`, con
  `KUBECONFIG` por entorno y rutas relativas (research.md R6 y R7)
- [X] T016 [P] [US1] Crear `terraform/app/outputs.tf` con las direcciones de la web, la API y Swagger
- [X] T017 [US1] Implementar `up` en `scripts/local.sh` según los pasos 1-4, 6 y 7 de «Secuencia de `make up`» en
  `plan.md`: pasar `cluster_instance` a `app`, esperar los cuatro despliegues y el reinicio de `api`, y mostrar la
  salida final de `contracts/make-targets.md`
- [X] T018 [US1] Implementar `credentials` y `smoke` en `scripts/local.sh` según `contracts/make-targets.md`
  (`smoke` borra la lista temporal también si falla, y no imprime contraseñas ni tokens)
- [X] T019 [US1] Generar `terraform/config/.terraform.lock.hcl`, `terraform/cluster/.terraform.lock.hcl` y
  `terraform/app/.terraform.lock.hcl` con `terraform providers lock` para `windows_amd64`, `linux_amd64` y
  `darwin_arm64`
- [X] T020 [US1] Ejecutar el escenario 1 de `specs/15-terraform-make-up/quickstart.md` y, **solo tras confirmación
  explícita del usuario**, `kind delete cluster --name quipux-playlist` (se pierden sus listas y su `Secret`; cerrar
  los `port-forward` abiertos)
- [X] T021 [US1] Ejecutar los escenarios 2, 3, 5, 6, 7 y 8 de `specs/15-terraform-make-up/quickstart.md`, corregir lo
  que falle y anotar los resultados

**Checkpoint**: MVP utilizable sin IA.

---

## Phase 4: User Story 2 - Recomendaciones con IA usando Ollama en Docker (Priority: P1)

**Goal**: `make up` deja la IA en Docker y la API del clúster responde recomendaciones con ella.

**Independent Test**: `make up` y `make smoke` devuelven origen `IA` o `SIMILITUD`.

- [X] T022 [P] [US2] Crear `compose/compose.cluster.yaml` según research.md R8 y `contracts/network.md` (proyecto
  `quipux-cluster`, `extends` de `compose.ai.yaml`, volúmenes declarados, sin puertos publicados, red externa `kind`
  con alias, `catalog-index` con la imagen publicada) y comprobar `docker compose config` sin los repositorios hermanos
- [X] T023 [P] [US2] Crear `scripts/lib/ai.sh`: invocar Compose con `.local/compose.env` tras borrar del entorno sus
  cinco variables, detectar la GPU según research.md R9, ejecutar el orden de arranque de R8 con el progreso de la
  descarga visible, y detener los contenedores conservando volúmenes cuando la IA está inactiva
- [X] T024 [P] [US2] Añadir en `terraform/app/main.tf` las claves de IA del `Secret` de `contracts/configuration.md`,
  presentes solo con `ai_enabled`
- [X] T025 [US2] Integrar en `up` de `scripts/local.sh` el paso 5 de la secuencia de `plan.md`, la comprobación desde el
  pod `api` de `contracts/network.md` y el indicador `GPU`, `CPU` o `no` en la salida final
- [X] T026 [US2] Ejecutar los escenarios 4, 9, 10, 17 y 18 de `specs/15-terraform-make-up/quickstart.md`; si hay
  `OOMKilled` en `api`, informar al usuario antes de cambiar límites en `k8s/api-deployment.yaml`

**Checkpoint**: las dos historias P1 funcionan.

---

## Phase 5: User Story 3 - Consultar, detener y limpiar (Priority: P2)

**Goal**: ver el estado, eliminar el entorno conservando modelos y limpiar con confirmación.

**Independent Test**: `make status`, `make down`, `make up` sin descargas y `make clean` con confirmación.

- [X] T027 [US3] Implementar `status` en `scripts/local.sh` (solo lectura: estado de `data-model.md`, pods,
  contenedores de IA y direcciones; también con el entorno ausente o detenido)
- [X] T028 [US3] Implementar `down` en `scripts/local.sh`: vaciar el estado de `app`, `compose down` sin `-v`,
  destruir `cluster` (arrancando antes el nodo detenido o limpiando el estado si no existe) e idempotente, sin tocar
  recursos ajenos ni la red `kind` (FR-015, FR-016)
- [X] T029 [US3] Implementar `clean` en `scripts/local.sh`: confirmación interactiva o `CONFIRM=yes`, `down`,
  `compose down -v`, destruir `config` y borrar `.local/` y los estados; conservar `terraform/local.tfvars`
- [X] T030 [US3] Ejecutar los escenarios 11 a 15 y 19 de `specs/15-terraform-make-up/quickstart.md` y anotar los tiempos
  frente a SC-002 y SC-003

**Checkpoint**: ciclo completo sin comandos manuales.

---

## Phase 6: User Story 4 - Activar Argo CD (Priority: P3)

**Goal**: `make up ARGOCD=true` despliega `main` sin romper la IA.

**Independent Test**: aplicación `Synced` y `Healthy`, y `make smoke` correcto.

- [X] T031 [US4] Añadir en `terraform/app/argocd.tf` el `terraform_data` condicionado a `argocd_enabled` que instala
  Argo CD `v3.5.9` y aplica `argocd/application.yaml`, con provisioner de destrucción; condicionar en
  `terraform/app/manifests.tf` la aplicación local a que Argo CD esté inactivo (research.md R7)
- [X] T032 [US4] En `scripts/local.sh`, con Argo CD activo: esperar `Synced` y `Healthy`, avisar de que `k8s/` local no
  se aplica, mostrar cómo abrir la consola sin imprimir su contraseña e incluir Argo CD en `status`
- [X] T033 [US4] Ejecutar el escenario 16 de `specs/15-terraform-make-up/quickstart.md` y anotar el resultado

**Checkpoint**: las cuatro historias funcionan.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T034 Implementar `validate` en `scripts/local.sh` (`terraform fmt -check`, `init -backend=false` en directorio de
  datos temporal, `validate` y `shellcheck` si existe) y corregir sus hallazgos
- [X] T035 [P] Añadir a `.github/workflows/ci.yml` el trabajo `terraform` y el análisis Trivy de `terraform/` según
  research.md R11, con permisos de solo lectura y acciones fijadas por SHA
- [X] T036 [P] Añadir el ecosistema `terraform` de las tres raíces a `.github/dependabot.yml`
- [X] T037 [P] Añadir la comprobación `terraform` a `.github/branch-protection.json` (sin aplicarla en GitHub)
- [X] T038 Actualizar `README.md`: `make up` sustituye la secuencia manual (requisitos, comandos, variables,
  direcciones, credenciales, dónde quedan los secretos, solución de problemas, limitaciones de `plan.md`, paso manual de
  protección de `main`) y se conserva la sección de Docker Compose (FR-021)
- [X] T039 Ejecutar `make validate`, un análisis local de secretos si Trivy está disponible y revisar
  `git status --ignored` y el diff completo; ningún secreto ni artefacto de `data-model.md` queda versionable (SC-005)
- [X] T040 Ejecutar el escenario 20 de `specs/15-terraform-make-up/quickstart.md`, **previa confirmación del usuario**
  porque borra los modelos, dejar el entorno levantado y anotar el resultado
- [X] T041 Cuando el usuario pida publicar la rama, comprobar el escenario 21 de
  `specs/15-terraform-make-up/quickstart.md` en el PR

---

## Dependencies & Execution Order

### Phase Dependencies

```text
Setup (T001-T005) → Foundational (T006-T012) → US1 (T013-T021) ─┬─> US2 (T022-T026) ─┐
                                                                 ├─> US3 (T027-T030) ─┼─> Polish (T034-T041)
                                                                 └─> US4 (T031-T033) ─┘
```

- **US1** es la base: las demás necesitan el `up` y la raíz `app`.
- **US2**: depende de US1.
- **US3**: depende de US1; el escenario 14 (conservar modelos) necesita US2.
- **US4**: depende de US1; comprobar que la IA sigue necesita US2.
- US2, US3 y US4 editan `scripts/local.sh`: hacerlas en ese orden.

### Dentro de las fases

- T001 antes de cualquier `terraform apply`.
- T005 antes de T017; T007 y T008 después de T006.
- T010, T011 y T012 antes de T017.
- T020 requiere confirmación y precede a toda prueba que cree el clúster.
- T041 depende de que el usuario pida commit, push y PR.

## Parallel Opportunities

| Momento | En paralelo |
|---|---|
| Setup | T002, T003, T004 |
| Foundational | T006, T009, T010, T011 |
| US1 | T016, junto a T014 o T015 |
| US2 | T022, T023, T024 |
| Polish | T035, T036, T037 |

US3 y US4 no tienen tareas paralelas: comparten `scripts/local.sh`.

## Implementation Strategy

1. **MVP**: Setup, Foundational y US1. Validar con `AI=false`.
2. **US2**: la IA; completa lo pedido para `make up`.
3. **US3**: ciclo de vida.
4. **US4**: Argo CD opcional.
5. **Polish**: CI, README y comprobaciones finales.

Detenerse en cada checkpoint. No hacer commit ni push sin que el usuario lo pida.
