# Research: Kubernetes y Argo CD

Comprobado el 2026-11-27 sobre el entorno local y el estado de los tres repositorios tras HU-08.

## R0. Estado de partida

| Elemento / Herramienta | Estado observado |
|---|---|
| `kubectl` | `v1.34.1` (Kustomize integrado `v5.7.1`) |
| `kustomize` | `v5.8.1` |
| `kind` | `v0.31.0` (sobre Docker; `k3d` y `minikube` no instalados) |
| `helm` | instalado (`argocd` CLI no instalado) |
| `trivy` | `0.72.0` en local (el CI usa `v0.76.2`) |
| `gh`, `docker`, `mvn` | instalados (`mvn 3.9.11`) |
| Imágenes publicadas (HU-08) | `ghcr.io/leandroamariles/quipux-playlist-backend:0.1.0` (UID `10001:10001`) y `quipux-playlist-frontend:0.1.0` (UID `101`), `linux/amd64`, públicas |
| Backend (`SecurityConfig`, `pom.xml`) | sin `spring-boot-starter-actuator` ni rutas de salud en `SecurityConfig` |
| Infra (`k8s/`, `argocd/`, workflows) | sin manifiestos Kustomize, sin `argocd/`, sin `ci.yml` ni `release.yml`; `branch-protection.json` con `required_status_checks: null` |

## R1. Sondas de salud en backend (Actuator + Security + BlockHound + OpenAPI)

- **Decisión**: añadir `org.springframework.boot:spring-boot-starter-actuator` en `infrastructure/pom.xml` (versión gestionada por `spring-boot-starter-parent` `4.1.3`). En `bootstrap/src/main/resources/application.yml`, exponer únicamente `health` con sondas habilitadas y sin detalles:
  - `management.endpoints.web.exposure.include: health`
  - `management.endpoint.health.probes.enabled: true`
  - `management.endpoint.health.show-details: never`
  En `SecurityConfig`, añadir una cadena dedicada con `@Order` antes de `apiSecurityFilterChain` (siguiendo el patrón de `loginSecurityFilterChain`) cuyo `securityMatcher` cubra solo `GET /actuator/health/liveness` y `GET /actuator/health/readiness` con `permitAll()`. El resto de `/actuator/**` (incluido `/actuator/health`) queda bajo la cadena autenticada (`401` sin token).
- **Rationale**:
  1. `/actuator/health` incluye indicadores como `diskSpace` que hacen lecturas bloqueantes en disco y harían fallar `BlockHound` en `PlaylistNonBlockingTest`. Las rutas específicas `/actuator/health/liveness` y `/actuator/health/readiness` consultan `livenessState` y `readinessState` en memoria sin bloquear el event loop.
  2. Una `SecurityWebFilterChain` separada con `securityMatcher` evita que peticiones con una cabecera `Authorization` inválida fallen en el filtro JWT y mantiene el mismo patrón de `loginSecurityFilterChain`.
  3. `springdoc.show-actuator` es `false` por defecto, de modo que `/v3/api-docs` y `OpenApiContractTest` conservan exactamente las 6 operaciones de negocio.
  4. El cambio se limita a `infrastructure` y `bootstrap`, cumpliendo las reglas de dependencias de `ArchitectureTest`.
- **Alternativas descartadas**:
  - Abrir `/actuator/health` sin token (activa `diskSpace` bloqueante y expone estado agregado innecesario).
  - Implementar un controlador REST propio `/health` (el `ADR-0001`, sección 7, especifica probes con Actuator y se perdería la integración nativa con `AvailabilityState`).

## R2. Sondas de salud en frontend y `readOnlyRootFilesystem` de nginx

- **Decisión**: configurar `livenessProbe` y `readinessProbe` del contenedor `web` sobre `GET /` en el puerto `8080`, sin modificar el `Dockerfile` ni `nginx/default.conf.template`. Montar tres volúmenes `emptyDir` en `/etc/nginx/conf.d`, `/var/cache/nginx` y `/tmp` en el `Deployment` de `web`, y un `emptyDir` en `/tmp` en el `Deployment` de `api`.
- **Rationale**: `nginxinc/nginx-unprivileged:1.31.7-alpine` ejecuta al arrancar el script `20-envsubst-on-templates.sh`, que escribe `/etc/nginx/conf.d/default.conf` desde la plantilla, utiliza `/var/cache/nginx` para caché/buffers y guarda el PID en `/tmp/nginx.pid`. Sin esos `emptyDir`, activar `readOnlyRootFilesystem: true` (regla `AVD-KSV-0014` de Trivy) impediría el arranque del pod. Por su parte, `GET /` ya devuelve `200` desde nginx cuando los estáticos y la configuración están listos.
- **Alternativas descartadas**:
  - Desactivar `readOnlyRootFilesystem` (incumple el endurecimiento requerido frente a Trivy `config`).
  - Añadir una ruta `/healthz` en `nginx/default.conf.template` (obligaría a publicar una nueva imagen de frontend solo para la sonda cuando `GET /` ya valida la disponibilidad del servidor web).

## R3. Manifiestos de Kubernetes, Kustomize y endurecimiento Trivy `config`

- **Decisión**: estructura plana en `quipux-playlist-infra/k8s/` con `kustomization.yaml`, `namespace.yaml` (`quipux-playlist`), `configmap.yaml` (`playlist-config`), `api-deployment.yaml`, `api-service.yaml` (`api:8080`), `web-deployment.yaml`, `web-service.yaml` (`web:8080`) y `secret.example.yaml` (excluido de `kustomization.yaml`).
  - Las versiones de imagen se gestionan mediante el bloque `images:` de `k8s/kustomization.yaml` (inicialmente `0.1.0`, sin `latest`).
  - El `Deployment` de `api` fija `replicas: 1` con estrategia `RollingUpdate` para reemplazar el pod limpiamente en actualizaciones (aceptando la pérdida de datos de H2 en memoria).
  - Endurecimiento en ambos `Deployment`: `automountServiceAccountToken: false`, `securityContext` de pod (`runAsNonRoot: true`, `runAsUser`/`runAsGroup`/`fsGroup`: `10001` en `api` y `101` en `web`, `seccompProfile.type: RuntimeDefault`), `securityContext` de contenedor (`allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`) y `resources` (`requests` y `limits` de CPU y memoria).
  - `secret.example.yaml` declara `stringData` con cadenas vacías `""` para `JWT_SECRET`, `DEMO_USER_PASSWORD`, `DEMO_ADMIN_PASSWORD`, `SPOTIFY_CLIENT_ID` y `SPOTIFY_CLIENT_SECRET`, evitando falsos positivos en Trivy de secretos.
- **Rationale**: cumple `FR-004` a `FR-008` y evita los hallazgos `HIGH`/`CRITICAL` habituales de Trivy `config` (`AVD-KSV-0001`, `AVD-KSV-0014`, `AVD-KSV-0020`, `AVD-KSV-0043` y límites de recursos).
- **Alternativas descartadas**:
  - Overlays `base/` + `overlays/local/` (fuera de alcance en `spec.md`; un solo entorno local).
  - Helm charts (el backlog y el `ADR-0001` exigen Kustomize).
  - `SealedSecrets` o `ExternalSecrets` (fuera de alcance; el `Secret` real se crea a mano en el clúster).

## R4. CI de infra, protección de `main` y Dependabot

- **Decisión**: crear `.github/workflows/ci.yml` en `quipux-playlist-infra` en `ubuntu-24.04` (`permissions: contents: read`, sin secretos, `timeout-minutes: 10`) con dos trabajos:
  1. `kustomize`: ejecuta `kustomize build k8s > /tmp/manifests.yaml` (con `kustomize` preinstalado en `ubuntu-24.04`) y verifica que el resultado no contiene `kind: Secret` y que el `Deployment` de `api` declara `replicas: 1`.
  2. `trivy`: renderiza `kustomize build k8s > /tmp/rendered-k8s.yaml` y ejecuta `aquasecurity/trivy-action` (mismo SHA y versión de binario `v0.76.2` de HU-08) en dos pasos: (a) `scan-type: config` sobre `/tmp/rendered-k8s.yaml` y `argocd/` con `severity: HIGH,CRITICAL` y `exit-code: "1"`; (b) `scan-type: fs`, `scanners: secret` sobre `.` con `severity: HIGH,CRITICAL` y `exit-code: "1"`.
  Tras fusionar `ci.yml` en `main`, actualizar `.github/branch-protection.json` de infra con `required_status_checks: {"strict": false, "contexts": ["kustomize", "trivy"]}` y aplicarlo con `gh api`. En `.github/dependabot.yml` de infra, añadir `github-actions` en `/` (`chore(deps)`, grupo `github-actions`, semanal) conservando `docker-compose` en `/compose`.
- **Rationale**: `kustomize` ya viene preinstalado en `ubuntu-24.04`, por lo que no se añaden acciones externas nuevas; analizar el resultado de `kustomize build` valida exactamente los manifiestos finales que sincronizará Argo CD.
- **Alternativas descartadas**:
  - Instalar `kustomize` con una acción adicional de terceros (más superficie de cadena de suministro).
  - Analizar con Trivy solo los archivos YAML sin renderizar (no detecta referencias rotas ni transformaciones de `kustomization.yaml`).

## R5. `release-please` en `quipux-playlist-infra`

- **Decisión**: configurar `.github/workflows/release.yml` en `quipux-playlist-infra` con `googleapis/release-please-action` (mismo SHA `v5.0.0` de HU-08), `release-please-config.json` (`release-type: "simple"`, `initial-version: "0.1.0"`, `bump-minor-pre-major: true`, `include-component-in-tag: false`), `.release-please-manifest.json` (`{".": "0.0.0"}`) y `version.txt` (`0.0.0`), usando el secreto `RELEASE_PLEASE_TOKEN` propio del repositorio de infra (PAT de grano fino limitado a `quipux-playlist-infra` con `Contents`, `Pull requests` e `Issues` en lectura y escritura). Sin trabajo `publish`.
- **Rationale**: `simple` es el `release-type` estándar de `release-please` para repositorios sin Maven ni npm y gestiona `version.txt` junto con `CHANGELOG.md`. Usar un PAT propio garantiza que el PR de release dispare `ci.yml` y cumpla la protección de `main`.
- **Alternativas descartadas**:
  - Usar `GITHUB_TOKEN` (no dispara `ci.yml` en el PR de release y quedaría bloqueado por la protección de `main`).

## R6. Clúster local (`kind`) y Argo CD (`argocd/application.yaml`)

- **Decisión**: usar `kind` (`v0.31.0`, ya instalado sobre Docker) con un clúster local llamado `quipux-playlist`. Instalar Argo CD mediante su manifiesto oficial fijado a versión explícita (`v3.5.9`, `--server-side --force-conflicts`, namespace `argocd`). Versionar `argocd/application.yaml` apuntando a `https://github.com/leandroAmariles/quipux-playlist-infra.git`, `targetRevision: main`, `path: k8s`, destino `namespace: quipux-playlist`, con `syncPolicy.automated` (`prune: true`, `selfHeal: true`).
- **Rationale**: `kind` ya está disponible en el entorno local y usa Docker directamente; la interfaz web y el estado de Argo CD se validan con `kubectl` y `kubectl -n argocd port-forward svc/argocd-server 8443:443` sin requerir el CLI `argocd`. Como `playlist-secrets` se crea a mano fuera de `k8s/kustomization.yaml`, Argo CD no lo incluye en su inventario y no lo toca ni al podar (`prune: true`).
- **Alternativas descartadas**:
  - `minikube` o `k3d` (no están instalados en el equipo).
  - Instalación HA de Argo CD (sobredimensionada para un clúster local).
  - Sincronización manual sin `automated` (resta demostración del flujo GitOps automático al fusionar PRs).

## R7. PR automático de actualización de tag desde backend y frontend

- **Decisión**: añadir el trabajo `update-infra` en `.github/workflows/release.yml` de backend y frontend con `needs: [release-please, publish]`, `if: needs.release-please.outputs.release_created == 'true'` y `permissions: { contents: read }`.
  - Autenticación mediante un PAT de grano fino guardado como secreto `INFRA_PR_TOKEN` en backend y frontend, limitado **exclusivamente** a `leandroAmariles/quipux-playlist-infra` con `Contents: Read and write` y `Pull requests: Read and write`.
  - Pasos: `actions/checkout` de `leandroAmariles/quipux-playlist-infra` (`ref: main`, `token: ${{ secrets.INFRA_PR_TOKEN }}`), ejecutar en `k8s/` `kustomize edit set image ghcr.io/leandroamariles/<repo>=ghcr.io/leandroamariles/<repo>:${VERSION}`, comprobar si hay cambios con `git diff --quiet`, publicar en una rama fija por componente (`chore/deploy-backend` o `chore/deploy-frontend`) con `git push --force-with-lease` y commit `chore(deploy): bump <backend|frontend> image to <VERSION>`, y abrir el PR con `gh pr create` solo si no existe ya un PR abierto desde esa rama.
- **Rationale**: no añade acciones de terceros nuevas (usa `actions/checkout` fijado por SHA más `kustomize` y `gh` preinstalados en `ubuntu-24.04`), es idempotente ante reintentos o releases seguidas, `chore(deploy)` evita generar versiones innecesarias en infra por cada despliegue de aplicación, y `needs: [release-please, publish]` asegura que si Trivy rechaza la imagen nunca se abre un PR en infra.
- **Alternativas descartadas**:
  - `peter-evans/create-pull-request` (introduce una acción externa adicional que mantener por SHA).
  - Editar `kustomization.yaml` con `sed` (más frágil que `kustomize edit set image`).
  - Usar `fix(deploy)` (dispararía un PR de release en infra en cada cambio de tag).

## R8. Acciones fijadas por SHA y permisos

Se reutilizan exactamente las acciones y versiones fijadas por SHA en HU-08 (`actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`, `aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0` con binario `v0.76.2`, `googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0`). No se incorporan nuevas acciones de terceros.

## Fuentes

- [Spring Boot Actuator: Kubernetes Probes](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html#actuator.endpoints.kubernetes-probes)
- [Argo CD: Declarative Setup & Installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [Trivy: Kubernetes Misconfiguration Checks](https://avd.aquasecurity.github.io/trivy/latest/docs/target/kubernetes/)
- [release-please: Simple Release Type & Manifests](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md)
- [GitHub Actions runner-images: ubuntu-24.04](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
