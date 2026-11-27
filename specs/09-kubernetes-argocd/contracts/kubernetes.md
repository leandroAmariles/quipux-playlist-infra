# Contrato: manifiestos de Kubernetes y Kustomize

Ubicación en `quipux-playlist-infra/k8s/`.

## Estructura de `k8s/`

```text
k8s/
├── kustomization.yaml
├── namespace.yaml
├── configmap.yaml
├── api-deployment.yaml
├── api-service.yaml
├── web-deployment.yaml
├── web-service.yaml
└── secret.example.yaml   # NO incluido en kustomization.yaml
```

## Reglas de `kustomization.yaml`

- `namespace: quipux-playlist`
- `resources:` incluye únicamente `namespace.yaml`, `configmap.yaml`, `api-deployment.yaml`, `api-service.yaml`, `web-deployment.yaml` y `web-service.yaml`. **Nunca** incluye `secret.example.yaml`.
- `images:` declara explícitamente ambas imágenes con tag semántico (inicialmente `0.1.0`, nunca `latest`):
  - `ghcr.io/leandroamariles/quipux-playlist-backend` (`newTag: "0.1.0"`)
  - `ghcr.io/leandroamariles/quipux-playlist-frontend` (`newTag: "0.1.0"`)

## Recursos

### `Namespace` y `ConfigMap`

- `Namespace`: `quipux-playlist`.
- `ConfigMap` (`playlist-config` en `quipux-playlist`):
  - `JWT_TTL: "30m"`
  - `SPOTIFY_ACCOUNTS_BASE_URL: "https://accounts.spotify.com"`
  - `SPOTIFY_API_BASE_URL: "https://api.spotify.com"`
  - `SPOTIFY_TIMEOUT: "3s"`
  - `API_URL: "http://api:8080"`

### `Secret` de ejemplo y creación manual (`playlist-secrets`)

- `k8s/secret.example.yaml` documenta `kind: Secret`, `metadata.name: playlist-secrets`, `metadata.namespace: quipux-playlist`, `type: Opaque` y `stringData` con cadenas vacías `""` para `JWT_SECRET`, `DEMO_USER_PASSWORD`, `DEMO_ADMIN_PASSWORD`, `SPOTIFY_CLIENT_ID` y `SPOTIFY_CLIENT_SECRET`.
- Creación manual obligatoria en el clúster antes o durante el despliegue:

```bash
kubectl create secret generic playlist-secrets \
  --namespace quipux-playlist \
  --from-literal=JWT_SECRET='<clave-min-32-bytes>' \
  --from-literal=DEMO_USER_PASSWORD='<password-user>' \
  --from-literal=DEMO_ADMIN_PASSWORD='<password-admin>' \
  --from-literal=SPOTIFY_CLIENT_ID='' \
  --from-literal=SPOTIFY_CLIENT_SECRET=''
```

### `Deployment` y `Service` del backend (`api`)

- `Deployment` `api`:
  - `replicas: 1` (obligatorio: H2 en memoria no se comparte entre pods).
  - `automountServiceAccountToken: false`.
  - Pod `securityContext`: `runAsNonRoot: true`, `runAsUser: 10001`, `runAsGroup: 10001`, `fsGroup: 10001`, `seccompProfile.type: RuntimeDefault`.
  - Contenedor `api`:
    - Imagen `ghcr.io/leandroamariles/quipux-playlist-backend`, `imagePullPolicy: IfNotPresent`, puerto `8080`.
    - `envFrom`: `configMapRef` (`playlist-config`) y `secretRef` (`playlist-secrets`, `optional: false`).
    - Container `securityContext`: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`.
    - `resources`: `requests` (`cpu: 100m`, `memory: 256Mi`) y `limits` (`cpu: 500m`, `memory: 512Mi`).
    - Sondas HTTP en puerto `8080`: `startupProbe` (`/actuator/health/readiness`), `readinessProbe` (`/actuator/health/readiness`), `livenessProbe` (`/actuator/health/liveness`).
    - Volumen `emptyDir` montado en `/tmp`.
- `Service` `api`: `ClusterIP`, puerto `8080` → `targetPort: 8080`.

### `Deployment` y `Service` del frontend (`web`)

- `Deployment` `web`:
  - `replicas: 1`, `automountServiceAccountToken: false`.
  - Pod `securityContext`: `runAsNonRoot: true`, `runAsUser: 101`, `runAsGroup: 101`, `fsGroup: 101`, `seccompProfile.type: RuntimeDefault`.
  - Contenedor `web`:
    - Imagen `ghcr.io/leandroamariles/quipux-playlist-frontend`, `imagePullPolicy: IfNotPresent`, puerto `8080`.
    - `env` desde `playlist-config`: `API_URL`.
    - Container `securityContext`: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`.
    - `resources`: `requests` (`cpu: 50m`, `memory: 64Mi`) y `limits` (`cpu: 200m`, `memory: 128Mi`).
    - Sondas HTTP en puerto `8080`: `readinessProbe` (`GET /`) y `livenessProbe` (`GET /`).
    - Volúmenes `emptyDir` montados en `/etc/nginx/conf.d`, `/var/cache/nginx` y `/tmp`.
- `Service` `web`: `ClusterIP`, puerto `8080` → `targetPort: 8080`.

## Acceso local

```bash
kubectl -n quipux-playlist port-forward svc/web 4200:8080
kubectl -n quipux-playlist port-forward svc/api 8080:8080
```
