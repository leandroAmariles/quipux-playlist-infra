---
description: "Tareas de HU-09: Kubernetes y Argo CD"
---

# Tasks: Kubernetes y Argo CD

**Input**: documentos de diseño en `quipux-playlist-infra/specs/09-kubernetes-argocd/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: se incluyen pruebas de integración/seguridad y de no-bloqueo para las nuevas rutas HTTP de salud en el backend (`HealthProbeTest`, `PlaylistNonBlockingTest`); las validaciones de Kustomize, Trivy, CI, protección de `main`, Argo CD y `release-please` se comprueban con los 18 escenarios de `quickstart.md` (SC-008).

**Orden de las historias**: US1, US2 y US3 son `P1`; US4 y US5 son `P2`.

**Rutas**: relativas a la carpeta que contiene los tres repositorios, con estos prefijos:

| Prefijo | Ruta |
|---|---|
| `{back}` | `quipux-playlist-backend` |
| `{front}` | `quipux-playlist-frontend` |
| `{infra}` | `quipux-playlist-infra` |
| `{spec}` | `quipux-playlist-infra/specs/09-kubernetes-argocd` |

**En todas las tareas**:

- Sin comentarios en los archivos ni workflows, salvo `# vX.Y.Z` junto a cada SHA de acción (`{spec}/research.md`, R8).
- Ningún secreto ni token real en los repositorios, en los manifiestos generados, en los registros de CI ni en la conversación.
- No cambia el comportamiento funcional de la API ni de la web ni el contrato OpenAPI (`FR-026`).
- **(confirmar)**: antes de hacer push, abrir un PR o cambiar un ajuste en GitHub, pedir confirmación.
- **(persona)**: lo hace la persona responsable; detenerse, pedirlo y esperar.
- Commits en Conventional Commits, en inglés y con ámbito `HU-09` (salvo el commit del PR automático de tag `chore(deploy)`).
- En Git Bash sobre Windows, anteponer `MSYS_NO_PATHCONV=1` a los comandos de Docker que lleven rutas del contenedor.

---

## Phase 1: Setup

**Purpose**: Comprobar herramientas locales y preparar las ramas de trabajo en los tres repositorios.

- [X] T001 Comprobar `docker info`, `kind version`, `kubectl version --client`, `kustomize version`, `trivy --version`, JDK 21, Node 22 y permisos de administración de `gh` en los tres repositorios (`{spec}/quickstart.md`); si falta algo, detener y avisar
  - Resultado: Docker `29.6.1`, `kind v0.31.0`, `kubectl v1.34.1`, `kustomize v5.8.1`, `trivy 0.72.0`, JDK `21.0.12.1`, Node `v22.22.3` y `gh` con `admin=true` en los tres repositorios.
- [X] T002 En `{back}` y `{front}`, confirmar árbol limpio, ejecutar `git fetch` y crear la rama `feature/09-kubernetes-argocd` desde `origin/main` sin seguimiento; `{infra}` ya se encuentra en esa rama
  - Resultado: ramas `feature/09-kubernetes-argocd` creadas desde `origin/main` en `{back}` (`0.1.1`) y `{front}`.

---

## Phase 2: Foundational — Sondas de salud en backend

**Purpose**: Exponer y publicar las rutas de salud de Actuator sin token en `quipux-playlist-backend` (`0.2.0`) antes de desplegar en `kind` y Argo CD, ya que la imagen `0.1.0` de HU-08 aún no incluye Actuator.

**⚠️ CRITICAL**: Ninguna historia que despliegue en Kubernetes (`US1`, `US3`) puede validarse de extremo a extremo hasta completar esta fase.

- [X] T003 Añadir `org.springframework.boot:spring-boot-starter-actuator` en `{back}/infrastructure/pom.xml` (`{spec}/contracts/health-probes.md`)
- [X] T004 [P] Crear `{back}/infrastructure/src/main/java/com/quipux/playlist/infrastructure/in/rest/health/HealthPath.java` declarando las rutas de liveness y readiness (`{spec}/data-model.md`, `Sondas de salud.Ruta`; `{spec}/contracts/health-probes.md`)
- [X] T005 [P] Configurar Actuator (`management.endpoints.web.exposure.include: health`, `management.endpoint.health.probes.enabled: true`, `management.endpoint.health.show-details: never`) en `{back}/bootstrap/src/main/resources/application.yml` (`{spec}/contracts/health-probes.md`)
- [X] T006 Actualizar `{back}/infrastructure/src/main/java/com/quipux/playlist/infrastructure/in/rest/config/SecurityConfig.java` añadiendo una `SecurityWebFilterChain` con `@Order` anterior a `apiSecurityFilterChain` y `securityMatcher` solo sobre `GET` de `HealthPath` con `permitAll()`, manteniendo `/actuator/health` y `/actuator/**` protegidos (`{spec}/data-model.md`, `Sondas de salud.Autenticación`; `{spec}/contracts/health-probes.md`)
- [X] T007 [P] Crear `{back}/bootstrap/src/test/java/com/quipux/playlist/HealthProbeTest.java` comprobando `200` y `{"status":"UP"}` sin detalles internos en liveness y readiness sin token, y `401` en `/actuator/health` y `/actuator/env` (`{spec}/data-model.md`, `Sondas de salud.Código esperado` y `Sondas de salud.Cuerpo / Comportamiento`)
- [X] T008 [P] Ampliar `{back}/bootstrap/src/test/java/com/quipux/playlist/PlaylistNonBlockingTest.java` para ejercitar `GET /actuator/health/liveness` y `GET /actuator/health/readiness` bajo `BlockHound`
- [X] T009 Ejecutar `./mvnw verify` en `{back}` (`HealthProbeTest`, `PlaylistNonBlockingTest`, `OpenApiContractTest`, `ArchitectureTest`, Checkstyle, JaCoCo ≥ 80 %) y `trivy rootfs` sobre `{back}/bootstrap/target` (escenario 1 de `{spec}/quickstart.md`)
  - Resultado: `.\mvnw.cmd -B -ntp verify` en verde across los 5 módulos (`domain` 151, `application` 36, `infrastructure` 212, `bootstrap` 213 + `PlaylistNonBlockingTest` 8 + `RecommendationNonBlockingTest` 2; `HealthProbeTest` 7, `OpenApiContractTest` 21, `ArchitectureTest` 5), `0` violaciones de Checkstyle y cobertura JaCoCo cumplida. `trivy rootfs` (`0` vulnerabilidades `HIGH`/`CRITICAL`) y `trivy fs --scanners secret` (`0` secretos) en verde.
- [X] T010 **(confirmar)** Commit `feat(HU-09): expose Actuator liveness and readiness probes`, push en `{back}` y abrir PR hacia `main`; **(persona)** fusionar el PR y luego fusionar el PR de `release-please` (`0.2.0`) para publicar `ghcr.io/leandroamariles/quipux-playlist-backend:0.2.0`
  - Resultado: PR `backend#21` (`9c8e57c`) fusionado y release `v0.2.0` publicada (`Release` run `45962258193` en verde); `ghcr.io/leandroamariles/quipux-playlist-backend:0.2.0` verificada en GHCR.

**Checkpoint**: `ghcr.io/leandroamariles/quipux-playlist-backend:0.2.0` publicada en GHCR con sondas de salud verificadas y sin regresiones.

---

## Phase 3: User Story 1 - Desplegar la aplicación en Kubernetes con Kustomize y sondas de salud (Priority: P1) 🎯 MVP

**Goal**: Definir los manifiestos endurecidos con Kustomize en `{infra}/k8s/` y validar el despliegue completo de web y API en un clúster local `kind`, con backend en 1 réplica, sondas sin token y `Secret` real creado fuera de Git.

**Independent Test**: Crear `playlist-secrets` manualmente en `kind`, aplicar `kustomize build k8s`, verificar ambos pods `Ready`, consultar las sondas sin token e iniciar sesión en la web como `admin` y `user`.

- [X] T011 [P] [US1] Crear `{infra}/k8s/namespace.yaml` definiendo el namespace `quipux-playlist` (`{spec}/data-model.md`, `Recursos de Kubernetes.Namespace`; `{spec}/contracts/kubernetes.md`)
- [X] T012 [P] [US1] Crear `{infra}/k8s/configmap.yaml` (`playlist-config`) con `JWT_TTL`, `SPOTIFY_ACCOUNTS_BASE_URL`, `SPOTIFY_API_BASE_URL`, `SPOTIFY_TIMEOUT` y `API_URL` (`{spec}/data-model.md`, `Variables de configuración.ConfigMap`; `{spec}/contracts/kubernetes.md`)
- [X] T013 [P] [US1] Crear `{infra}/k8s/secret.example.yaml` (`playlist-secrets` con `stringData` vacío para `JWT_SECRET`, `DEMO_USER_PASSWORD`, `DEMO_ADMIN_PASSWORD`, `SPOTIFY_CLIENT_ID` y `SPOTIFY_CLIENT_SECRET`, excluido de `kustomization.yaml`) (`{spec}/data-model.md`, `Variables de configuración.Secret`; `{spec}/contracts/kubernetes.md`)
- [X] T014 [P] [US1] Crear `{infra}/k8s/api-deployment.yaml` y `{infra}/k8s/api-service.yaml` (`replicas: 1`, UID `10001`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, `seccompProfile: RuntimeDefault`, `resources`, sondas Actuator, `emptyDir` en `/tmp`, `Service` `api:8080`) (`{spec}/data-model.md`, `Recursos de Kubernetes.Deployment api` y `Recursos de Kubernetes.Service api`; `{spec}/contracts/kubernetes.md`)
- [X] T015 [P] [US1] Crear `{infra}/k8s/web-deployment.yaml` y `{infra}/k8s/web-service.yaml` (UID `101`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, `seccompProfile: RuntimeDefault`, `resources`, sondas `GET /`, `emptyDir` en `/etc/nginx/conf.d`, `/var/cache/nginx` y `/tmp`, `API_URL` desde `playlist-config`, `Service` `web:8080`) (`{spec}/data-model.md`, `Recursos de Kubernetes.Deployment web` y `Recursos de Kubernetes.Service web`; `{spec}/contracts/kubernetes.md`)
- [X] T016 [US1] Crear `{infra}/k8s/kustomization.yaml` declarando los 6 recursos (sin `secret.example.yaml`) y el bloque `images:` con tags `0.2.0` para backend y `0.1.0` para frontend (`{spec}/contracts/kubernetes.md`)
- [X] T017 [US1] Ejecutar en local `kustomize build {infra}/k8s`, comprobar ausencia de `kind: Secret` y `replicas: 1` en `api`, y ejecutar `trivy config --severity HIGH,CRITICAL --exit-code 1` sobre el renderizado y `trivy fs --scanners secret --severity HIGH,CRITICAL --exit-code 1 {infra}` (escenario 2 de `{spec}/quickstart.md`)
  - Resultado: `kustomize build` en verde (`0` `Secret`, `api` `replicas: 1`), `trivy config` (`0` misconfiguraciones `HIGH`/`CRITICAL`) y `trivy fs --scanners secret` (`0` secretos).
- [X] T018 [US1] Crear el clúster local `kind` (`kind create cluster --name quipux-playlist`), aplicar `kustomize build {infra}/k8s` sin `playlist-secrets` para comprobar el fallo claro, luego crear `playlist-secrets` con `kubectl create secret generic` y comprobar ambos pods `Ready` en < 3 min (`SC-003`) y sondas `200` sin token / `/actuator/health` `401` (escenario 3 de `{spec}/quickstart.md`)
  - Resultado: sin `playlist-secrets`, el pod `api` quedó en `CreateContainerConfigError` (`secret "playlist-secrets" not found`); tras crear `playlist-secrets`, `api` y `web` alcanzaron `Running 1/1` en `25.5 s` (`< 3 min`, `SC-003`); `/actuator/health/liveness` y `/readiness` respondieron `200 {"status":"UP"}` sin token y `/actuator/health` `401`.
- [X] T019 [US1] Probar la aplicación desplegada en `kind` mediante `kubectl -n quipux-playlist port-forward` (`web` `4200:8080`, `api` `8080:8080`): inicio de sesión `admin`/`user`, CRUD web, colección `newman`, y comprobar que `docker compose up` en `{infra}/compose` sigue pasando sin regresiones (escenario 4 de `{spec}/quickstart.md`)
  - Resultado: ajustado `API_URL` en `{infra}/k8s/configmap.yaml` a `http://api.quipux-playlist.svc.cluster.local:8080` (requerido por el `resolver` de nginx en Kubernetes); flujo `admin`/`user` por `/api` (`201`/`200`/`403`/`204`), `newman` (`20` peticiones, `25` aserciones, `0` fallos) directo en `18080` y vía web `14200/api`, y `docker compose config --quiet` en verde.

**Checkpoint**: User Story 1 (MVP) funciona y está probada en un clúster local real con sondas sin token y sin secretos en Git.

---

## Phase 4: User Story 2 - Validar el repositorio de infra con CI y proteger `main` (Priority: P1)

**Goal**: Validar automáticamente cada PR y push a `main` de `quipux-playlist-infra` con `kustomize` y `trivy`, actualizar Dependabot y exigir el CI en verde en la protección de `main`.

**Independent Test**: Abrir un PR válido en infra y verificar las comprobaciones en verde; probar los defectos en un PR borrador `probe/hu-09` (Kustomize roto, misconfiguración Trivy) y el secreto ficticio en copia local, y comprobar que `main` bloquea push directo y PRs en rojo.

- [X] T020 [P] [US2] Crear `{infra}/.github/workflows/ci.yml` con trabajos `kustomize` y `trivy` (`config` sobre renderizado de `k8s/` + `argocd/` y `secret` sobre `.`), acciones fijadas por SHA (`{spec}/research.md`, R8) y `permissions: contents: read` (`{spec}/data-model.md`, `Comprobaciones de infra.kustomize` y `Comprobaciones de infra.trivy`; `{spec}/contracts/gitops-ci.md`)
- [X] T021 [P] [US2] Actualizar `{infra}/.github/dependabot.yml` añadiendo el ecosistema `github-actions` en `/` (`chore(deps)`, grupo `github-actions`) junto a `docker-compose` (`{spec}/contracts/gitops-ci.md`)
- [X] T022 [P] [US2] Actualizar `{infra}/.github/branch-protection.json` configurando `required_status_checks` con `{"strict": false, "contexts": ["kustomize", "trivy"]}` (`{spec}/contracts/gitops-ci.md`)
- [X] T023 [US2] Validar `{infra}/.github/workflows/ci.yml` con `rhysd/actionlint:1.7.12` en Docker y verificar SHA de 40 caracteres, permisos mínimos y ausencia de secretos/`kubeconfig` (escenario 9 de `{spec}/quickstart.md`)
  - Resultado: `rhysd/actionlint:1.7.12` en `0`; todas las acciones fijadas por SHA + `# vX.Y.Z`, `contents: read`, sin secretos ni `kubeconfig`.
- [X] T024 [US2] **(confirmar)** Commit y push en `{infra}` (`k8s/`, `ci.yml`, `dependabot.yml`, `branch-protection.json`) y abrir el primer PR hacia `main`; comprobar `kustomize` y `trivy` en verde en < 10 min (`SC-001`, escenario 5 de `{spec}/quickstart.md`)
  - Resultado: PR `infra#4` (`https://github.com/leandroAmariles/quipux-playlist-infra/pull/4`) en verde (`kustomize` `12 s`, `trivy` `22 s`, `< 10 min`, `SC-001`).
- [X] T025 [US2] **(confirmar)** Ejecutar las pruebas de defectos en el PR borrador `probe/hu-09` de `{infra}`: manifiesto Kustomize roto (`kustomize` en rojo, escenario 6) y misconfiguración `HIGH`/`CRITICAL` (`trivy` en rojo, escenario 7); probar un secreto ficticio en copia local temporal de `{infra}` con `trivy fs --scanners secret --exit-code 1 .` y eliminar la copia (escenario 8 de `{spec}/quickstart.md`). Dejar `probe/hu-09` abierto en rojo para `T027`
  - Resultado: PR `infra#5` (`probe/hu-09`): `2218f22` (`run 45963910091`) falló `kustomize` (`12 s`); `3bfdfe9` (`run 45963974683`) pasó `kustomize` (`5 s`) y falló `trivy` (`11 s`). Prueba local de secreto en copia temporal (`probe-secret.pem`, `AsymmetricPrivateKey` `HIGH`): código `1`, valor enmascarado y copia eliminada.
- [X] T026 [US2] **(persona)** Fusionar el primer PR de `{infra}` para que `ci.yml` exista en `main`, y **(confirmar)** aplicar `{infra}/.github/branch-protection.json` con `gh api -X PUT repos/leandroAmariles/quipux-playlist-infra/branches/main/protection --input .github/branch-protection.json`
  - Resultado: `infra#4` fusionado en `main` (`56a2a49`) y protección aplicada y verificada vía `gh api` (`enforce_admins: true`, `approvals: 0`, `checks: ["kustomize","trivy"]`, `force_pushes: false`, `deletions: false`).
- [X] T027 [US2] **(confirmar)** Comprobar la protección de `main` en `{infra}`: rechazo de `git push origin HEAD:main` con commit vacío, `probe/hu-09` marcado como listo con `mergeStateStatus: BLOCKED` y cierre/borrado de `probe/hu-09` (escenario 10); comprobar la pestaña de Dependabot con `docker-compose` y `github-actions` sin errores (escenario 11 de `{spec}/quickstart.md`)
  - Resultado: push directo `git push origin HEAD:main` rechazado con `GH006` (`Changes must be made through a pull request`, `2 of 2 required status checks are expected`); `infra#5` marcado como listo devolvió `mergeStateStatus: BLOCKED` y fue cerrado con borrado de rama `probe/hu-09`. `.github/dependabot.yml` en `main` configurado para `docker-compose` y `github-actions`.

**Checkpoint**: `main` de `quipux-playlist-infra` protegida y validada automáticamente por `kustomize`, `trivy` y Dependabot.

---

## Phase 5: User Story 3 - Desplegar de forma continua con Argo CD desde Git (Priority: P1)

**Goal**: Versionar el manifiesto `Application` en `{infra}/argocd/` e instalar Argo CD en el clúster local `kind` para sincronizar automáticamente `main/k8s` respetando `playlist-secrets`.

**Independent Test**: Instalar Argo CD `v3.5.9` en `kind`, aplicar `argocd/application.yaml` con `playlist-secrets` presente, comprobar `Synced` y `Healthy`, provocar deriva manual para validar `selfHeal` y fusionar un cambio declarativo en `main` de infra.

- [X] T028 [US3] Crear `{infra}/argocd/application.yaml` apuntando a `https://github.com/leandroAmariles/quipux-playlist-infra.git`, `targetRevision: main`, `path: k8s`, destino `namespace: quipux-playlist` y `syncPolicy.automated` (`prune: true`, `selfHeal: true`) (`{spec}/data-model.md`, `Aplicación Argo CD.spec.source` y `Aplicación Argo CD.spec.syncPolicy.automated`; `{spec}/contracts/gitops-ci.md`)
- [X] T029 [US3] Validar `{infra}/argocd/application.yaml` en local con `trivy config --severity HIGH,CRITICAL --exit-code 1`; **(confirmar)** commit, push y PR en `{infra}`, **(persona)** fusionar en verde a `main`
  - Resultado: `trivy config` (`0` hallazgos); PR `infra#6` (`6840ef3`) en verde (`kustomize` `7 s`, `trivy` `13 s`) y fusionado en `main` (`010c183`).
- [X] T030 [US3] Instalar Argo CD `v3.5.9` en el clúster `kind` (`namespace argocd`, `--server-side --force-conflicts`), esperar a que sus pods estén listos, aplicar `{infra}/argocd/application.yaml` manteniendo `playlist-secrets` y comprobar estado `Synced` y `Healthy` sin sobrescribir `playlist-secrets` (escenario 12 de `{spec}/quickstart.md`)
  - Resultado: Argo CD `v3.5.9` instalado (`7` pods `Running 1/1`), `Application` `quipux-playlist` alcanzó `Synced Healthy` y `playlist-secrets` conservó su `uid` intacto.
- [X] T031 [US3] Probar corrección de deriva (`selfHeal`) y seguridad de `prune: true`: modificar manualmente un recurso gestionado en el namespace `quipux-playlist` y comprobar que Argo CD revierte la deriva manteniendo intacto `playlist-secrets` (escenario 13 de `{spec}/quickstart.md`)
  - Resultado: escalado manual `deployment/web` a `2` réplicas revertido automáticamente por Argo CD a `1` réplica (`Synced Healthy`), manteniendo intacto el `uid` de `playlist-secrets`.
- [ ] T032 [US3] **(confirmar)** Abrir PR con un cambio declarativo menor en `{infra}/k8s/configmap.yaml`, **(persona)** fusionarlo en verde y comprobar que Argo CD sincroniza automáticamente `main` hasta `Synced` y `Healthy` sin intervención del CI en el clúster (escenario 14 de `{spec}/quickstart.md`)

**Checkpoint**: Despliegue continuo GitOps operativo con Argo CD sobre `main` de infra.

---

## Phase 6: User Story 4 - Proponer automáticamente nuevas versiones mediante PR en infra (Priority: P2)

**Goal**: Hacer que cada release exitosa de backend o frontend que publique imagen en GHCR abra o actualice automáticamente un PR en `quipux-playlist-infra` con el nuevo tag de imagen.

**Independent Test**: Configurar `INFRA_PR_TOKEN` y `update-infra` en backend y frontend, disparar una release de prueba, verificar que se abre el PR en infra tocando solo `k8s/kustomization.yaml` con CI en verde y que tras fusionarlo Argo CD sincroniza el nuevo tag.

- [X] T033 [US4] **(persona)** Crear un PAT de grano fino limitado **exclusivamente** a `leandroAmariles/quipux-playlist-infra` (`Contents` y `Pull requests` en lectura/escritura) y guardarlo como secreto `INFRA_PR_TOKEN` en `{back}` y `{front}` (`{spec}/contracts/gitops-ci.md`); confirmar existencia con `gh secret list`
  - Resultado: secreto `INFRA_PR_TOKEN` configurado y verificado con `gh secret list` en `{back}` y `{front}`.
- [X] T034 [P] [US4] Añadir el trabajo `update-infra` (`needs: [release-please, publish]`, `permissions: { contents: read }`, `INFRA_PR_TOKEN`, `kustomize edit set image`, rama fija `chore/deploy-backend`, commit `chore(deploy): bump backend image to ${VERSION}`, `gh pr create` idempotente) en `{back}/.github/workflows/release.yml` (`{spec}/data-model.md`, `PR automático de tag.Backend`; `{spec}/contracts/gitops-ci.md`)
- [X] T035 [P] [US4] Añadir el trabajo `update-infra` (rama fija `chore/deploy-frontend`, commit `chore(deploy): bump frontend image to ${VERSION}`) en `{front}/.github/workflows/release.yml` (`{spec}/data-model.md`, `PR automático de tag.Frontend`; `{spec}/contracts/gitops-ci.md`)
- [X] T036 [US4] Validar ambos `release.yml` con `rhysd/actionlint:1.7.12` y comprobar SHA fijados, permisos mínimos y condición `needs: [release-please, publish]` para no abrir PR si falla `publish` (escenarios 9 y 17 de `{spec}/quickstart.md`)
  - Resultado: `rhysd/actionlint:1.7.12` en `0` en `{back}` y `{front}`; todas las acciones con SHA + `# vX.Y.Z`, `contents: read` y `needs: [release-please, publish]`.
- [ ] T037 [US4] **(confirmar)** Commit y push en `{back}` y `{front}` actualizados desde `origin/main` (incluyendo un cambio publicable `fix(HU-09): ...` en al menos un repositorio para probar el flujo completo de tag) y abrir PRs; **(persona)** fusionar esos PRs y el PR de `release-please` resultante, verificando la imagen en GHCR y el PR automático abierto en `{infra}` tocando solo `k8s/kustomization.yaml` con CI en verde (escenario 15 de `{spec}/quickstart.md`)
- [ ] T038 [US4] **(persona)** Fusionar el PR automático de tag en `main` de `{infra}` y comprobar que Argo CD sincroniza la nueva versión en < 5 min (`SC-005`) dejando la aplicación `Synced` y `Healthy` con `playlist-secrets` intacto (escenario 16 de `{spec}/quickstart.md`)

**Checkpoint**: Ciclo completo código → release → imagen GHCR → PR automático en infra → CI verde → merge → Argo CD `Synced`/`Healthy`.

---

## Phase 7: User Story 5 - Versionar el repositorio de infra con release-please (Priority: P2)

**Goal**: Activar `release-please` en `quipux-playlist-infra` con `release-type: simple` y token propio para generar `CHANGELOG`, tag y release sin construir imágenes.

**Independent Test**: Fusionar un commit `feat(HU-09): ...` en `main` de infra, comprobar el PR de release `0.1.0` con CI en verde y verificar la creación del tag y release `v0.1.0` tras fusionarlo.

- [X] T039 [US5] **(persona)** Crear un PAT de grano fino limitado a `leandroAmariles/quipux-playlist-infra` (`Contents`, `Pull requests` e `Issues` en lectura/escritura) y guardarlo como secreto `RELEASE_PLEASE_TOKEN` en `{infra}` (`{spec}/contracts/gitops-ci.md`); confirmar existencia con `gh secret list`
  - Resultado: secreto `RELEASE_PLEASE_TOKEN` configurado y verificado con `gh secret list` en `{infra}`.
- [X] T040 [P] [US5] Crear `{infra}/release-please-config.json` (`release-type: "simple"`, `initial-version: "0.1.0"`, `bump-minor-pre-major: true`, `include-component-in-tag: false`), `{infra}/.release-please-manifest.json` (`{".": "0.0.0"}`) y `{infra}/version.txt` (`0.0.0`) (`{spec}/data-model.md`, `Versión de infra`; `{spec}/contracts/gitops-ci.md`)
- [X] T041 [P] [US5] Crear `{infra}/.github/workflows/release.yml` con un único trabajo `release-please` (`googleapis/release-please-action` SHA `v5.0.0` y `${{ secrets.RELEASE_PLEASE_TOKEN }}`) (`{spec}/contracts/gitops-ci.md`)
  - Resultado: `rhysd/actionlint:1.7.12` en `0`.
- [ ] T042 [US5] Validar `{infra}/.github/workflows/release.yml` con `rhysd/actionlint:1.7.12`; **(confirmar)** commit `feat(HU-09): configure release-please for infra repository`, push y PR en `{infra}`, **(persona)** fusionar en verde
- [ ] T043 [US5] Comprobar que `release-please` abre el PR `chore(main): release 0.1.0` en `{infra}` con `CHANGELOG.md` y `version.txt` y CI en verde; **(persona)** fusionarlo y verificar el tag `v0.1.0` y la release sin construcción de imágenes (escenario 18 de `{spec}/quickstart.md`, `SC-006`)

**Checkpoint**: Los tres repositorios cuentan con CI, protección de `main`, Dependabot y `release-please` activos.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentación en los tres repositorios, casos HTTP de las sondas, cierre del backlog y ADR, verificación final de seguridad/no-regresión y revisión de comentarios.

- [ ] T044 [P] Actualizar `{infra}/README.md` documentando `k8s/`, la creación manual de `playlist-secrets`, `kind`, instalación y uso de Argo CD, el CI de infra, `release-please` y los ajustes manuales de GitHub (`FR-024`)
- [ ] T045 [P] Actualizar `{back}/README.md` y `{front}/README.md` documentando las rutas de salud (`/actuator/health/liveness`, `/actuator/health/readiness`), el trabajo `update-infra` (`INFRA_PR_TOKEN`) y el estado operativo de Kubernetes y Argo CD (`FR-025`)
- [ ] T046 [P] Generar `{spec}/requests.http` con los casos de prueba HTTP para las rutas de salud (`GET /actuator/health/liveness` `200`, `GET /actuator/health/readiness` `200`, `GET /actuator/health` `401`, `GET /actuator/env` `401`) según `.ai/rules/http-test-requests.md`
- [ ] T047 [P] Marcar los 12 criterios de HU-09 como comprobados en `{back}/docs/backlog.md` (`SC-008`) y registrar las concreciones de HU-09 (`kind`, Argo CD `v3.5.9`, Actuator `liveness`/`readiness`, `INFRA_PR_TOKEN`, `chore(deploy)`) en `{back}/docs/adr/0001-arquitectura-api-listas-reproduccion.md` (secciones 7, 13 y pendientes)
- [ ] T048 Ejecutar `trivy fs --scanners secret --severity HIGH,CRITICAL --exit-code 1` en `{back}`, `{front}` e `{infra}` y revisar logs de CI/release confirmando `0` secretos reales (`SC-007`), y confirmar `./mvnw verify` (`{back}`), `npm test` (`{front}`) y `docker compose` (`{infra}/compose`) sin regresiones (`FR-026`)
- [ ] T049 **(confirmar)** Commit `docs(HU-09): ...` y PRs de cierre documental en `{back}`, `{front}` e `{infra}`, **(persona)** fusionarlos en verde; revisar comentarios `REVIEW:`/`TODO:`/`FIXME:` en archivos tocados (crear `{spec}/code-review.md` si hubiera) y entregar el resumen de secretos y propiedades nuevas sin valores reales

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: sin dependencias; puede iniciar de inmediato.
- **Phase 2 (Foundational — Sondas en backend)**: depende de Phase 1; bloquea `US1` y `US3` porque publica `quipux-playlist-backend:0.2.0` con las sondas reales de Actuator.
- **Phase 3 (US1 — Kubernetes y Kustomize, P1)**: depende de Phase 2 (`backend:0.2.0` disponible en GHCR).
- **Phase 4 (US2 — CI y protección de `main` en infra, P1)**: depende de `k8s/` de `US1` (`T011`–`T017`) para que `kustomize` y `trivy` tengan manifiestos que validar.
- **Phase 5 (US3 — Argo CD, P1)**: depende de `US1` (`k8s/` y `kind` con `playlist-secrets`) y `US2` (`main` de infra validada por CI).
- **Phase 6 (US4 — PR automático de tag, P2)**: depende de `US1` (`k8s/kustomization.yaml`) y `US2` (CI en `main` de infra para validar el PR automático); conviene ejecutar tras `US3` para cerrar el flujo completo hasta Argo CD `Synced`/`Healthy`.
- **Phase 7 (US5 — `release-please` en infra, P2)**: depende de `US2` (CI y protección de `main` en infra para validar el PR de release). Puede avanzar en paralelo con `US4` tras `T026` (usando `feat(HU-09)` en `T042` para disparar la `0.1.0`).
- **Phase 8 (Polish)**: depende de completar las fases anteriores.

### Within Each User Story

- En Phase 2 (sondas): dependencia y configuración antes de pruebas y `./mvnw verify`; publicar `0.2.0` antes de validar `k8s/` en `kind`.
- En `US1`: manifiestos individuales (`T011`–`T015`) en paralelo antes de `kustomization.yaml` (`T016`), validación local (`T017`) y despliegue en `kind` (`T018`–`T019`).
- En `US2`: `ci.yml`, `dependabot.yml` y `branch-protection.json` en paralelo (`T020`–`T022`) → `actionlint` → PR y pruebas de fallo → fusión de `ci.yml` en `main` → **solo después** aplicar `branch-protection.json` (`T026`).
- En `US4`: secreto `INFRA_PR_TOKEN` creado antes de probar `update-infra` (`T033` antes de `T037`); los cambios en `release.yml` de backend y frontend son paralelos (`T034`–`T035`).
- En `US5`: secreto `RELEASE_PLEASE_TOKEN` de infra (`T039`) y archivos de `release-please` (`T040`–`T041`) listos antes de fusionar `T042`.

### Parallel Opportunities

- **Phase 2**: `T004`, `T005`, `T007` y `T008` (archivos distintos de backend) en paralelo tras `T003` / `T006`.
- **Phase 3 (US1)**: `T011`, `T012`, `T013`, `T014` y `T015` (manifiestos independientes bajo `k8s/`).
- **Phase 4 (US2)**: `T020`, `T021` y `T022` (archivos distintos bajo `{infra}/.github/`).
- **Phase 6 (US4)**: `T034` y `T035` (`release.yml` de backend y frontend).
- **Phase 7 (US5)**: `T040` y `T041` (configuración y workflow de `release-please` en infra).
- **Phase 8 (Polish)**: `T044`, `T045`, `T046` y `T047` (documentación, `requests.http`, backlog y ADR).

---

## Parallel Example: User Story 1

```text
# Crear todos los manifiestos base de k8s/ en paralelo:
Task: "T011 [P] [US1] Crear {infra}/k8s/namespace.yaml"
Task: "T012 [P] [US1] Crear {infra}/k8s/configmap.yaml"
Task: "T013 [P] [US1] Crear {infra}/k8s/secret.example.yaml"
Task: "T014 [P] [US1] Crear {infra}/k8s/api-deployment.yaml y api-service.yaml"
Task: "T015 [P] [US1] Crear {infra}/k8s/web-deployment.yaml y web-service.yaml"
```

---

## Implementation Strategy

### MVP First (Phase 1 + Phase 2 + User Story 1)

1. Completar Phase 1 (Setup) y Phase 2 (Sondas Actuator en backend y publicación de `0.2.0`).
2. Completar Phase 3 (`US1`: manifiestos `k8s/`, validación local `kustomize`/`trivy` y despliegue verificado en `kind` con `playlist-secrets` fuera de Git).
3. **STOP and VALIDATE**: Confirmar sondas sin token, web/API funcionales por `port-forward` y `newman` en verde antes de automatizar CI y GitOps.

### Incremental Delivery

1. **Setup + Foundational (`T001`–`T010`)**: `backend:0.2.0` publicado con sondas no bloqueantes.
2. **US1 (`T011`–`T019`) — MVP**: despliegue repetible en `kind` con Kustomize.
3. **US2 (`T020`–`T027`)**: CI de infra y `main` protegida.
4. **US3 (`T028`–`T032`)**: Argo CD sincronizando `main/k8s` automáticamente.
5. **US4 (`T033`–`T038`) + US5 (`T039`–`T043`)**: PR automático de tag tras releases de aplicación y `release-please` en infra.
6. **Polish (`T044`–`T049`)**: READMEs, `requests.http`, backlog, ADR y verificación final sin secretos ni regresiones. Hay pausas obligadas con `**(persona)**` para tokens (`T033`, `T039`) y fusiones de PR en repositorios protegidos (`T010`, `T026`, `T029`, `T032`, `T037`, `T038`, `T042`, `T043`, `T049`).
