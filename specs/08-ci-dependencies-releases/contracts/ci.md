# Contrato: workflow de CI

Archivo `.github/workflows/ci.yml` en backend y frontend.

## Comunes

| Elemento | Valor |
|---|---|
| Disparadores | `pull_request` y `push`, ambos sobre `main`; sin filtros de rutas |
| Permisos | `contents: read` |
| Secretos | ninguno |
| Concurrencia | por referencia; en PR cancela la ejecución anterior |
| Runner | `ubuntu-24.04` |
| Tiempo máximo | 15 minutos por trabajo (SC-003) |
| Checkout | sin conservar credenciales |

El nombre de cada trabajo es el nombre de la comprobación que exige la protección de `main`. Cambiarlo obliga a
actualizar `.github/branch-protection.json`.

## Backend

| Trabajo | Pasos |
|---|---|
| `verify` | JDK 21 Temurin con caché de Maven; `./mvnw -B -ntp verify` |
| `qodana` | `qodana-action` con `qodana.yaml`; resultado como artefacto |
| `trivy` | JDK 21; `./mvnw -B -ntp -DskipTests package`; vulnerabilidades del jar de `bootstrap`; secretos del repositorio |

## Frontend

| Trabajo | Pasos |
|---|---|
| `build-test` | Node 22.22.3 con caché de npm; `npm ci`; `npm run build`; `npm test` |
| `lint` | `npm ci`; `npm run lint` |
| `trivy` | vulnerabilidades de `package-lock.json`; secretos del repositorio |

## Mismas comprobaciones en local

| Repositorio | Comandos |
|---|---|
| backend | `./mvnw verify`; `docker run --rm -v "$PWD:/data/project" jetbrains/qodana-jvm-community:2026.3`; `trivy` |
| frontend | `npm run build`; `npm test`; `npm run lint`; `trivy` |
