# Quickstart: validar Kubernetes y Argo CD

Contratos en [contracts/](contracts/). Los comandos usan Git Bash (en Windows con `MSYS_NO_PATHCONV=1` si se pasan rutas de contenedor a Docker).

## Requisitos

- `docker` en marcha, `kind` (`v0.31.0`), `kubectl` (`v1.34.1`), `kustomize` (`v5.8.1`), `trivy`, `gh` autenticado con permisos de administración y JDK 21 / Node 22.
- Secretos en GitHub creados por la persona responsable ([contracts/gitops-ci.md](contracts/gitops-ci.md)): `RELEASE_PLEASE_TOKEN` en infra e `INFRA_PR_TOKEN` en backend y frontend.

## Defectos a propósito

En infra se usa un único PR en borrador desde `probe/hu-09`, con un commit por defecto y uno tras otro, cerrándolo y borrando su rama al terminar. La prueba de secreto (escenario 8) se ejecuta en local sobre una copia temporal sin subir nada a GitHub.

## Escenarios

| # | Comprueba | Pasos | Resultado esperado |
|---|---|---|---|
| 1 | FR-001, FR-002, FR-026, SC-004 | En backend: `./mvnw verify` (con `HealthProbeTest` y `PlaylistNonBlockingTest`), `OpenApiContractTest`, `ArchitectureTest` y Trivy `rootfs` del jar | Todo en verde, cobertura ≥ 80 %, 0 violaciones Checkstyle, `BlockHound` OK, `/v3/api-docs` sin rutas de Actuator |
| 2 | US1 1, FR-004 a FR-008 | En infra: `kustomize build k8s > /tmp/rendered-k8s.yaml` y `trivy config` + `trivy fs --scanners secret` | 0 errores Kustomize, 0 `kind: Secret`, `api` con `replicas: 1`, 0 hallazgos `HIGH`/`CRITICAL` |
| 3 | US1 2, 3 y 5, SC-003 | En clúster `kind`: aplicar `kustomize build k8s` **sin** `playlist-secrets`; luego crear `playlist-secrets` con `kubectl create secret generic` | Sin secreto el pod `api` falla claramente; tras crear el secreto ambos pods quedan `Ready` en < 3 min; `GET /actuator/health/liveness` y `readiness` devuelven `200` sin token y `GET /actuator/health` devuelve `401` |
| 4 | US1 4 y 6, FR-009, FR-026 | `kubectl -n quipux-playlist port-forward svc/web 4200:8080` y `svc/api 8080:8080`; probar login `admin`/`user`, CRUD web, `newman` y `docker compose up` | Flujo completo funcional por `4200` y `8080`; `newman` y Compose siguen en verde |
| 5 | US2 1, SC-001 | Abrir PR válido en `quipux-playlist-infra` con `ci.yml` | Trabajos `kustomize` y `trivy` en verde en < 10 min |
| 6 | US2 2, SC-002 | En PR borrador `probe/hu-09`, romper referencia o YAML en `k8s/` | Trabajo `kustomize` en rojo |
| 7 | US2 3, SC-002 | En PR borrador `probe/hu-09`, introducir `runAsUser: 0` o `allowPrivilegeEscalation: true` | Trabajo `trivy` en rojo indicando archivo y hallazgo |
| 8 | US2 4, SC-002, SC-007 | En copia local temporal de infra, añadir clave ficticia y ejecutar `trivy fs --scanners secret --severity HIGH,CRITICAL --exit-code 1 .` | Código `1`, nombra el archivo y enmascara el valor; borrar copia |
| 9 | US2 6, US3 5, FR-012, FR-013, FR-020 | Inspeccionar workflows de infra y `update-infra` y el primer PR de Dependabot | Todos los `uses:` con SHA de 40 caracteres y `# vX.Y.Z`, permisos `contents: read`, 0 secretos en CI de PR, 0 `kubeconfig` |
| 10 | US2 5, FR-014 | Aplicar `.github/branch-protection.json` en infra; probar `git push origin HEAD:main` con commit vacío, revisar `mergeStateStatus` del PR en rojo y fusionar PR en verde | Push directo rechazado; PR en rojo `BLOCKED`; PR en verde fusionable sin aprobaciones |
| 11 | FR-015 | Revisar pestaña de Dependabot en `quipux-playlist-infra` | `docker-compose` y `github-actions` activos sin errores y con Conventional Commits |
| 12 | US3 1 y 2, FR-018, FR-019 | Instalar Argo CD `v3.5.9` en `kind` y aplicar `argocd/application.yaml` manteniendo `playlist-secrets` | `Application` `quipux-playlist` alcanza `Synced` y `Healthy`; `playlist-secrets` intacto |
| 13 | US3 2 y 4 | Modificar manualmente en el clúster una etiqueta o réplica de recurso gestionado | Argo CD revierte la deriva (`selfHeal`) y mantiene `playlist-secrets` intacto con `prune: true` |
| 14 | US3 3 | Fusionar cambio menor en `k8s/configmap.yaml` en `main` de infra | Argo CD sincroniza automáticamente y vuelve a `Synced` y `Healthy` |
| 15 | US4 1, 2 y 3, SC-006 | Release `0.2.0` en backend (incluye sondas de salud y `update-infra`) | `publish` sube `0.2.0` a GHCR y `update-infra` abre PR en infra tocando solo `k8s/kustomization.yaml` con CI en verde |
| 16 | US4 4, SC-005 | Fusionar el PR de tag `0.2.0` en `main` de infra | Argo CD sincroniza `0.2.0` y queda `Synced` y `Healthy` en < 5 min, manteniendo `playlist-secrets` |
| 17 | US4 5, Edge Cases | Comprobar condición `needs: [release-please, publish]` y re-ejecución con el mismo tag | Sin publicación no abre PR; si el tag coincide no abre PR vacío |
| 18 | US5 1, 2 y 3, SC-006 | Fusionar cambio publicable en `main` de infra (`feat(HU-09): ...`) | `release-please` abre PR `chore(main): release 0.1.0` con `CHANGELOG.md` y CI en verde; al fusionar crea tag/release `v0.1.0` sin imágenes |
