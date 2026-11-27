# Contrato: CI, releases y GitOps (Argo CD y PR automático)

## 1. CI de infra (`quipux-playlist-infra/.github/workflows/ci.yml`)

| Elemento | Valor |
|---|---|
| Disparadores | `pull_request` y `push` sobre `main`; sin filtros de rutas |
| Permisos | `contents: read` |
| Secretos | ninguno |
| Concurrencia | `ci-${{ github.ref }}`; en PR cancela la ejecución anterior |
| Runner | `ubuntu-24.04` |
| Timeout | `10` minutos por trabajo (`SC-001`) |
| Acciones | `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` (`persist-credentials: false`), `aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0` (`version: v0.76.2`) |

| Trabajo (nombre exigido en `main`) | Qué ejecuta | Falla si |
|---|---|---|
| `kustomize` | `kustomize build k8s > /tmp/manifests.yaml`; verifica ausencia de `kind: Secret` y `replicas: 1` en `Deployment` `api` | Error de Kustomize, aparece un `Secret` en la salida o cambia las réplicas de `api` |
| `trivy` | `kustomize build k8s > /tmp/rendered-k8s.yaml`; Trivy `config` sobre `/tmp/rendered-k8s.yaml` y `argocd/` (`HIGH,CRITICAL`, `exit-code: "1"`); Trivy `fs` (`scanners: secret`, `HIGH,CRITICAL`, `exit-code: "1"`) sobre `.` | Hallazgo `HIGH` o `CRITICAL` de configuración o secreto |

### Comprobaciones equivalentes en local

```bash
kustomize build k8s > /tmp/rendered-k8s.yaml
trivy config --severity HIGH,CRITICAL --exit-code 1 /tmp/rendered-k8s.yaml
trivy config --severity HIGH,CRITICAL --exit-code 1 argocd
trivy fs --scanners secret --severity HIGH,CRITICAL --exit-code 1 .
```

## 2. Protección de `main` y Dependabot en infra

- `.github/branch-protection.json` en `quipux-playlist-infra` (se aplica tras existir `ci.yml` en `main`):
  - `required_status_checks`: `{"strict": false, "contexts": ["kustomize", "trivy"]}`
  - `enforce_admins: true`, `required_approving_review_count: 0`, `allow_force_pushes: false`, `allow_deletions: false`
- `.github/dependabot.yml` en `quipux-playlist-infra`:
  - `docker-compose` en `/compose` (semanal, `chore(deps)`)
  - `github-actions` en `/` (semanal, `chore(deps)`, grupo `github-actions`)

## 3. `release-please` en infra

- Archivos en la raíz de `quipux-playlist-infra`:
  - `release-please-config.json`: `release-type: "simple"`, `initial-version: "0.1.0"`, `bump-minor-pre-major: true`, `include-component-in-tag: false`
  - `.release-please-manifest.json`: `{".": "0.0.0"}`
  - `version.txt`: `0.0.0`
- `.github/workflows/release.yml` en `quipux-playlist-infra`:
  - Disparador: `push` sobre `main`; `permissions: contents: read`; `concurrency: group: release, cancel-in-progress: false`.
  - Un único trabajo `release-please` con `googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0` y `token: ${{ secrets.RELEASE_PLEASE_TOKEN }}`. Sin trabajo `publish`.

## 4. Argo CD (`quipux-playlist-infra/argocd/application.yaml`)

- Versión de instalación en el clúster local (`kind`): `v3.5.9` (`https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.9/manifests/install.yaml`) en el namespace `argocd`.
- Manifiesto versionado `argocd/application.yaml`:
  - `apiVersion: argoproj.io/v1alpha1`, `kind: Application`, `metadata.name: quipux-playlist`, `metadata.namespace: argocd`
  - `spec.project: default`
  - `spec.source`: `repoURL: https://github.com/leandroAmariles/quipux-playlist-infra.git`, `targetRevision: main`, `path: k8s`
  - `spec.destination`: `server: https://kubernetes.default.svc`, `namespace: quipux-playlist`
  - `spec.syncPolicy.automated`: `prune: true`, `selfHeal: true`

## 5. PR automático de actualización de tag (`update-infra`)

En `.github/workflows/release.yml` de `quipux-playlist-backend` y `quipux-playlist-frontend`:

- Nuevo trabajo `update-infra`:
  - `needs: [release-please, publish]`
  - `if: needs.release-please.outputs.release_created == 'true'`
  - `runs-on: ubuntu-24.04`, `timeout-minutes: 10`, `permissions: { contents: read }`
  - Checkout de `leandroAmariles/quipux-playlist-infra` (`ref: main`, `token: ${{ secrets.INFRA_PR_TOKEN }}`)
  - Actualización en `k8s/` con `kustomize edit set image ghcr.io/leandroamariles/<repo>=ghcr.io/leandroamariles/<repo>:${VERSION}`
  - Si `git diff --quiet`, termina sin abrir PR
  - En caso contrario: rama fija `chore/deploy-backend` o `chore/deploy-frontend`, commit `chore(deploy): bump <backend|frontend> image to ${VERSION}`, `git push --force-with-lease origin <rama>`, y `gh pr create` solo si no existe ya un PR abierto desde esa rama.

## 6. Ajustes manuales (persona responsable)

| Ajuste | Repositorio / Clúster | Permisos / Alcance | Cuándo |
|---|---|---|---|
| PAT y secreto `RELEASE_PLEASE_TOKEN` | `quipux-playlist-infra` | Solo `infra`: `Contents`, `Pull requests`, `Issues` (R/W) | Antes de fusionar `release.yml` en infra |
| PAT y secreto `INFRA_PR_TOKEN` | `backend` y `frontend` | Exclusivamente sobre `quipux-playlist-infra`: `Contents`, `Pull requests` (R/W) | Antes de probar el PR automático en una release |
| Aplicar `.github/branch-protection.json` | `quipux-playlist-infra` | `kustomize` y `trivy` obligatorios | Después de fusionar `ci.yml` en `main` de infra |
| Crear `playlist-secrets` | Clúster local (`quipux-playlist`) | `JWT_SECRET`, `DEMO_USER_PASSWORD`, `DEMO_ADMIN_PASSWORD` | Antes/durante el primer despliegue en Kubernetes |
