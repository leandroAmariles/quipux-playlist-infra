# Contrato: ajustes de cada repositorio

## Protección de `main` (`.github/branch-protection.json`)

| Ajuste | backend | frontend | infra |
|---|---|---|---|
| PR obligatorio, 0 aprobaciones | sí | sí | sí |
| Se aplica a administradores | sí | sí | sí |
| Push forzado y borrado | no | no | no |
| Exigir rama al día | no | no | — |
| Comprobaciones obligatorias | `verify`, `qodana`, `trivy` | `build-test`, `lint`, `trivy` | ninguna |

## Dependabot (`.github/dependabot.yml`)

| Repositorio | Ecosistema y directorio | Prefijo del commit |
|---|---|---|
| backend | `maven` `/` | `fix(deps)`, `chore(deps-dev)` |
| backend | `docker` `/` | `fix(deps)` |
| backend, frontend | `github-actions` `/` | `chore(deps)` |
| frontend | `npm` `/` | `fix(deps)`, `chore(deps-dev)` |
| frontend | `docker` `/` | `fix(deps)` |
| infra | `docker-compose` `/compose` | `chore(deps)` |

Frecuencia semanal. Grupos y versiones ignoradas en [research.md](../research.md), R7.

## Ajustes manuales (los hace la persona responsable)

| Ajuste | Repositorios | Cuándo |
|---|---|---|
| PAT de grano fino y secreto `RELEASE_PLEASE_TOKEN` | backend, frontend | antes de fusionar `release.yml` |
| Paquete de GHCR en público (no reversible) | backend, frontend | tras la primera publicación |
