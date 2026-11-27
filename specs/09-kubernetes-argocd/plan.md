# Implementation Plan: Kubernetes y Argo CD

**Branch**: `feature/09-kubernetes-argocd` | **Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `quipux-playlist-infra/specs/09-kubernetes-argocd/spec.md`

## Summary

Añadir sondas de salud de Actuator sin token en el backend (`/actuator/health/liveness` y `/actuator/health/readiness`), definir los manifiestos de Kubernetes endurecidos con Kustomize en `quipux-playlist-infra/k8s/` (backend con 1 réplica, `Secret` real fuera de Git) y validarlos con un CI propio (`kustomize` + `trivy`) más protección de `main` y `release-please`. Cerrar el flujo GitOps desplegando Argo CD en un clúster local `kind` sincronizado con `main` de infra y añadiendo en backend y frontend el trabajo `update-infra` que abre un PR en infra tras cada imagen publicada. Detalle en [research.md](research.md).

## Technical Context

**Language/Version**: YAML (Kubernetes/Kustomize, Argo CD, GitHub Actions), Java 21 / Spring Boot `4.1.3` (Actuator en backend); Angular 22 / nginx sin cambios de código en frontend

**Primary Dependencies**: `kustomize` `v5.8.1` (`v5.7.1` en `kubectl`), `kubectl` `v1.34.1`, `kind` `v0.31.0`, Trivy `v0.76.2` (`aquasecurity/trivy-action` `v0.36.0`), Argo CD `v3.5.9`, `release-please` (`googleapis/release-please-action` `v5.0.0`), `spring-boot-starter-actuator`. Versiones y SHA en [research.md](research.md), R8

**Storage**: N/A en infraestructura; la aplicación sigue usando H2 en memoria en un único pod (`replicas: 1`)

**Testing**: `./mvnw verify` (con pruebas de sondas, `BlockHound`, `OpenApiContractTest` y `ArchitectureTest`), `kustomize build k8s`, `trivy config` y `trivy fs --scanners secret`, `actionlint` `1.7.12` y los 18 escenarios de [quickstart.md](quickstart.md)

**Target Platform**: clúster local `kind` sobre Docker (`linux/amd64`) y runners `ubuntu-24.04` en GitHub Actions

**Project Type**: web application (tres repositorios)

**Performance Goals**: CI de infra en menos de 10 minutos (`SC-001`); despliegue inicial en `kind` `Ready`/`Healthy` en menos de 3 minutos (`SC-003`); sincronización de Argo CD tras merge de tag en menos de 5 minutos (`SC-005`)

**Constraints**: repositorios públicos en plan gratuito; sin secretos en Git ni en el CI de PR; sin `kubeconfig` ni acceso al clúster desde GitHub Actions; acciones fijadas por SHA; permisos mínimos; backend con 1 réplica; sin cambios en comportamiento funcional ni contrato OpenAPI (`FR-026`)

**Scale/Scope**: sondas Actuator en backend, 8 manifiestos en `k8s/`, 1 `Application` en `argocd/`, 2 workflows nuevos en infra (`ci.yml`, `release.yml`), actualización de `release.yml` en backend y frontend (`update-infra`), `branch-protection.json` y `dependabot.yml` en infra, y 3 README + ADR + backlog

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

La constitución base sigue con la plantilla sin rellenar; se usan como puertas el `ADR-0001` y las reglas de `CLAUDE.md`.

| Puerta | Antes de Phase 0 | Tras Phase 1 |
|---|---|---|
| Kustomize, CI `kustomize`+`trivy`, `release-please` y Argo CD en infra (`ADR-0001` secciones 7 y 13) | Cumple | Cumple ([research.md](research.md) R3–R6) |
| Sin secretos en Git; `Secret` de ejemplo fuera de `kustomization.yaml` | Cumple | Cumple (`secret.example.yaml` excluido; R3) |
| Backend con exactamente 1 réplica (H2 en memoria) | Cumple | Cumple (`replicas: 1` validado en CI; R3–R4) |
| CI sin acceso al clúster; despliegue solo vía Argo CD desde `main` | Cumple | Cumple (`update-infra` solo abre PR; R6–R7) |
| Acciones fijadas por SHA (`# vX.Y.Z`) y permisos mínimos | Cumple | Cumple (mismos SHA de HU-08; R8) |
| Sondas con Actuator sin romper hexagonal, `BlockHound`, OpenAPI ni ≥ 80 % cobertura | Cumple | Cumple (solo `/liveness` y `/readiness` en `infrastructure`; R1) |
| Sin comentarios explicativos en código/workflows salvo `# vX.Y.Z` junto a cada SHA | Cumple | Cumple |

## Project Structure

### Documentation (this feature)

```text
quipux-playlist-infra/specs/09-kubernetes-argocd/
├── plan.md              # Este archivo
├── research.md          # Phase 0: sondas, emptyDir, Trivy, kind/Argo CD, update-infra
├── data-model.md        # Phase 1: sondas, recursos K8s, ConfigMap/Secret, estados Argo CD
├── quickstart.md        # Phase 1: 18 escenarios de validación extremo a extremo
├── contracts/           # Phase 1: health-probes.md, kubernetes.md, gitops-ci.md
├── requests.http        # Al implementar: casos HTTP para las nuevas rutas de salud
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code

Tres repositorios hermanos. `+` nuevo, `~` cambia.

```text
quipux-playlist-infra/
├── k8s/
│   ├── kustomization.yaml              + recursos (sin secret.example.yaml) e images:
│   ├── namespace.yaml                  + quipux-playlist
│   ├── configmap.yaml                  + playlist-config
│   ├── api-deployment.yaml             + 1 réplica, sondas, securityContext, resources
│   ├── api-service.yaml                + ClusterIP 8080
│   ├── web-deployment.yaml             + sondas, emptyDir nginx, securityContext, resources
│   ├── web-service.yaml                + ClusterIP 8080
│   └── secret.example.yaml             + plantilla sin secretos (excluida de kustomization)
├── argocd/
│   └── application.yaml                + Application apuntando a main/k8s
├── .github/
│   ├── workflows/ci.yml                + kustomize + trivy (config y secret)
│   ├── workflows/release.yml           + release-please simple
│   ├── branch-protection.json          ~ exigir kustomize y trivy
│   └── dependabot.yml                  ~ añadir github-actions en /
├── release-please-config.json          + release-type: simple
├── .release-please-manifest.json       + {".": "0.0.0"}
├── version.txt                         + 0.0.0
└── README.md                           ~ guía K8s, Secret, kind, Argo CD, CI y release-please

quipux-playlist-backend/
├── infrastructure/pom.xml              ~ añadir spring-boot-starter-actuator
├── infrastructure/.../SecurityConfig.java ~ cadena pública solo para liveness y readiness
├── infrastructure/.../HealthPath.java  + constantes de rutas de salud
├── infrastructure/src/test/.../HealthProbeTest.java + 200 sin token, 401 en /actuator/health
├── bootstrap/src/main/resources/application.yml ~ probes y exposure: health
├── bootstrap/src/test/.../PlaylistNonBlockingTest.java ~ cubrir sondas bajo BlockHound
├── .github/workflows/release.yml       ~ trabajo update-infra (PR a infra)
├── README.md                           ~ rutas de salud, update-infra y estado de K8s/Argo CD
└── docs/                               ~ backlog.md (HU-09) y adr/0001 (concreciones)

quipux-playlist-frontend/
├── .github/workflows/release.yml       ~ trabajo update-infra (PR a infra)
└── README.md                           ~ update-infra y referencia al README de infra
```

**Structure Decision**: mantener los manifiestos `k8s/`, `argocd/` y las especificaciones de diseño en `quipux-playlist-infra` (igual que `compose/` en HU-07 y el CI de entrega en HU-08), limitando los cambios de `quipux-playlist-backend` a las sondas de Actuator + `update-infra` y los de `quipux-playlist-frontend` a `update-infra` + documentación.

### Flujo GitOps

| Caso | Recorrido |
|---|---|
| Cambio en infra | PR a `main` → `ci.yml` (`kustomize` + `trivy`) → merge → Argo CD sincroniza `k8s/` en `kind` |
| Release en backend/frontend | Merge a `main` → `release.yml` (`release-please` → `publish` GHCR → `update-infra` abre PR en infra) → CI de infra en verde → merge → Argo CD despliega nueva imagen |
| Release en infra | Merge a `main` → `release.yml` (`release-please`) → PR de release → CI de infra → merge → tag y release (`v0.1.0`) |

### Orden de trabajo

0. **Ramas**: `quipux-playlist-infra` ya está en `feature/09-kubernetes-argocd`; crear `feature/09-kubernetes-argocd` desde `origin/main` en backend y frontend.
1. **Sondas en backend** (US1, FR-001–FR-002): Actuator, `SecurityConfig`, `HealthProbeTest`, `PlaylistNonBlockingTest` y validación local (`./mvnw verify`, Trivy del jar).
2. **Manifiestos Kustomize y prueba local en `kind`** (US1, FR-004–FR-009): crear `k8s/`, validar `kustomize build`, `trivy config`/`secret`, crear clúster `kind`, probar despliegue sin y con `playlist-secrets`, `port-forward` y `newman`.
3. **CI de infra y Dependabot** (US2, FR-010–FR-015): crear `ci.yml`, actualizar `dependabot.yml`, probar `actionlint`, abrir PR inicial en infra, ejecutar pruebas controladas de fallo en `probe/hu-09` (escenarios 6–8) y fusionar el PR inicial de infra.
4. **Protección de `main` en infra** (US2, FR-014): actualizar y aplicar `.github/branch-protection.json` exigiendo `kustomize` y `trivy`, y validar escenarios 10–11.
5. **Tokens manuales (persona responsable)**: crear `RELEASE_PLEASE_TOKEN` en infra e `INFRA_PR_TOKEN` (exclusivo sobre infra) en backend y frontend, y recordar la rotación pendiente de `RELEASE_PLEASE_TOKEN` en backend/frontend del `ADR-0001`.
6. **Argo CD y `release-please` en infra** (US3 y US5): añadir `argocd/application.yaml`, `release.yml`, `release-please-config.json`, `.release-please-manifest.json`, `version.txt` y `README.md` en infra; instalar Argo CD `v3.5.9` en `kind`, verificar `Synced`/`Healthy`, `selfHeal` y `prune` respetando `playlist-secrets`, y completar la primera release `0.1.0` de infra.
7. **`update-infra` y flujo extremo a extremo** (US4): añadir `update-infra` en `release.yml` de backend y frontend junto con sus READMEs, fusionar backend (`feat(HU-09): ...`), publicar release `0.2.0` de backend, validar que se abre automáticamente el PR en infra con CI en verde, fusionarlo y verificar que Argo CD sincroniza backend `0.2.0` hasta `Synced` y `Healthy` sirviendo `/actuator/health/liveness` y `readiness`.
8. **Cierre**: `requests.http` en esta carpeta de spec (por las nuevas rutas HTTP de salud), marcar HU-09 en `docs/backlog.md`, anotar concreciones en `ADR-0001`, revisar comentarios para `code-review.md` y entregar lista final de secretos/propiedades.

### Estrategia de pruebas

- **Backend**: nuevas pruebas de integración/seguridad `HealthProbeTest` (`200` sin token en `/liveness` y `/readiness`, `401` en `/actuator/health`, sin detalles expuestos) y ampliación de `PlaylistNonBlockingTest` bajo `BlockHound`.
- **Infra**: validación sintáctica y de invariantes (`replicas: 1`, sin `Secret`) en `kustomize build`, `trivy config` y `trivy secret` en local y en CI, `actionlint` sobre los workflows, defectos provocados en `probe/hu-09`, y verificación real en clúster `kind` con Argo CD.

### Cierre de la historia

Actualizar README de los tres repositorios, generar `requests.http` de las sondas de salud, marcar los 12 criterios de HU-09 en `docs/backlog.md`, actualizar `docs/adr/0001-arquitectura-api-listas-reproduccion.md`, revisar comentarios de revisión y resumir secretos/propiedades nuevos sin valores reales.

### Riesgos

| Riesgo | Respuesta |
|---|---|
| Hallazgo `HIGH`/`CRITICAL` de Trivy `config` en manifiestos Kustomize | Ajustar `securityContext`/`resources`/`emptyDir` antes de abrir el PR; si un check es inaplicable, documentar exclusión individual |
| `DiskSpaceHealthIndicator` u otro indicador bloquea bajo `BlockHound` | Exponer solo `/liveness` y `/readiness` con `probes.enabled: true` y probar con `PlaylistNonBlockingTest` |
| Conflicto de `release.yml` en backend al actualizar desde `main` | Trabajar desde `origin/main` actualizado (`0.1.0` en backend y frontend) |
| Exposición accidental de `INFRA_PR_TOKEN` en logs o scope excesivo | PAT de grano fino limitado exclusivamente a `quipux-playlist-infra` y usado solo en el checkout/env de `update-infra` (nunca en PRs) |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| La historia abarca tres repositorios bajo una sola spec | Las sondas viven en backend, `update-infra` en backend/frontend y los manifiestos/Argo CD en infra | Dividir en tres specs fragmentaría un flujo GitOps que solo se valida completo de extremo a extremo |
