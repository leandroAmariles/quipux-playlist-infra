# Data Model: Kubernetes y Argo CD

No hay entidades nuevas de negocio ni tablas de base de datos. Estos son los objetos de operación, despliegue y entrega continua que gestiona HU-09.

## Sondas de salud

| Componente | Ruta | Método | Autenticación | Código esperado | Cuerpo / Comportamiento |
|---|---|---|---|---|---|
| Backend (liveness) | `/actuator/health/liveness` | `GET` | Pública (sin token) | `200` | `{"status":"UP"}`, sin detalles internos |
| Backend (readiness) | `/actuator/health/readiness` | `GET` | Pública (sin token) | `200` | `{"status":"UP"}`, sin detalles internos |
| Backend (otros Actuator) | `/actuator/health`, `/actuator/**` | cualquiera | Autenticada | `401` sin token | No expuestos públicamente ni en OpenAPI |
| Frontend (liveness / readiness) | `/` | `GET` | Pública (sin token) | `200` | HTML de entrada servido por nginx en puerto `8080` |

## Recursos de Kubernetes (namespace `quipux-playlist`)

| Recurso | Nombre | En `kustomization.yaml` | Origen | Restricciones clave |
|---|---|---|---|---|
| `Namespace` | `quipux-playlist` | Sí | Git / Argo CD | Aísla los recursos de la aplicación |
| `ConfigMap` | `playlist-config` | Sí | Git / Argo CD | Variables no secretas |
| `Secret` | `playlist-secrets` | **No** | Manual (`kubectl`) | Nunca en Git; `secret.example.yaml` solo documenta claves |
| `Deployment` | `api` | Sí | Git / Argo CD | `replicas: 1`, UID `10001`, `readOnlyRootFilesystem: true`, `emptyDir /tmp`, sin `latest` |
| `Service` | `api` | Sí | Git / Argo CD | `ClusterIP` puerto `8080` → `8080` |
| `Deployment` | `web` | Sí | Git / Argo CD | UID `101`, `readOnlyRootFilesystem: true`, `emptyDir` en `/etc/nginx/conf.d`, `/var/cache/nginx`, `/tmp`, sin `latest` |
| `Service` | `web` | Sí | Git / Argo CD | `ClusterIP` puerto `8080` → `8080` |

## Variables de configuración (`ConfigMap` vs `Secret`)

| Clave | Objeto | Obligatoria | Valor por defecto / Ejemplo |
|---|---|---|---|
| `JWT_TTL` | `ConfigMap` (`playlist-config`) | No | `30m` |
| `SPOTIFY_ACCOUNTS_BASE_URL` | `ConfigMap` (`playlist-config`) | No | `https://accounts.spotify.com` |
| `SPOTIFY_API_BASE_URL` | `ConfigMap` (`playlist-config`) | No | `https://api.spotify.com` |
| `SPOTIFY_TIMEOUT` | `ConfigMap` (`playlist-config`) | No | `3s` |
| `API_URL` | `ConfigMap` (`playlist-config`) | Sí (para `web`) | `http://api.quipux-playlist.svc.cluster.local:8080` |
| `JWT_SECRET` | `Secret` (`playlist-secrets`) | Sí | Mínimo 32 bytes; creado manualmente |
| `DEMO_USER_PASSWORD` | `Secret` (`playlist-secrets`) | Sí | 1 a 72 bytes; creado manualmente |
| `DEMO_ADMIN_PASSWORD` | `Secret` (`playlist-secrets`) | Sí | 1 a 72 bytes; creado manualmente |
| `SPOTIFY_CLIENT_ID` | `Secret` (`playlist-secrets`) | No | Vacío (`""`) por defecto |
| `SPOTIFY_CLIENT_SECRET` | `Secret` (`playlist-secrets`) | No | Vacío (`""`) por defecto |

## Comprobaciones de infra (`.github/workflows/ci.yml`)

| Trabajo obligatorio en `main` | Qué valida | Falla cuando |
|---|---|---|
| `kustomize` | `kustomize build k8s` | Error de sintaxis/estructura Kustomize, presencia de `kind: Secret` o `api` con `replicas != 1` |
| `trivy` | Manifiestos renderizados + `argocd/` (`config`) y repositorio (`.`, `secret`) | Hallazgo `HIGH` o `CRITICAL` de configuración o secreto |

## Aplicación Argo CD (`argocd/application.yaml`)

| Campo | Valor |
|---|---|
| `metadata.name` / `namespace` | `quipux-playlist` / `argocd` |
| `spec.source.repoURL` | `https://github.com/leandroAmariles/quipux-playlist-infra.git` |
| `spec.source.targetRevision` | `main` |
| `spec.source.path` | `k8s` |
| `spec.destination.namespace` | `quipux-playlist` |
| `spec.syncPolicy.automated` | `prune: true`, `selfHeal: true` |

Transiciones de estado observadas en Argo CD: `OutOfSync` → `Synced` tras fusionar en `main` (o revertir deriva); `Progressing` → `Healthy` cuando los pods pasan sus sondas de salud (o `Degraded` si falta `playlist-secrets` o falla un contenedor).

## PR automático de actualización de tag

| Campo | Backend | Frontend |
|---|---|---|
| Rama fija en infra | `chore/deploy-backend` | `chore/deploy-frontend` |
| Archivo modificado | `k8s/kustomization.yaml` | `k8s/kustomization.yaml` |
| Mensaje de commit | `chore(deploy): bump backend image to X.Y.Z` | `chore(deploy): bump frontend image to X.Y.Z` |
| Secreto utilizado | `INFRA_PR_TOKEN` | `INFRA_PR_TOKEN` |

Transiciones: `release_created` → `publish` OK en GHCR → `update-infra` crea/actualiza rama y abre PR si no existe → CI de infra (`kustomize` + `trivy`) en verde → fusión manual del PR en `main` → Argo CD sincroniza a `Synced` y `Healthy`. Si `publish` falla, no se abre PR.

## Versión de infra (`release-please`)

- `release-type`: `simple`, primera versión: `0.1.0`, `bump-minor-pre-major: true`.
- Archivos gestionados: `version.txt`, `CHANGELOG.md` y `.release-please-manifest.json`.
- Los PR automáticos de tag (`chore(deploy): ...`) no incrementan versión ni abren PR de release en infra.
