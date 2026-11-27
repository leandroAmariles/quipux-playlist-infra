# Data Model: CI, dependencias y releases

No hay datos de la aplicación. Estos son los objetos que gestiona la entrega.

## Comprobación

| Repositorio | Nombre (obligatorio en `main`) | Falla cuando |
|---|---|---|
| backend | `verify` | falla una prueba, cobertura < 80 % en un módulo o violación de Checkstyle |
| backend | `qodana` | hallazgo `Critical` o `High` |
| backend | `trivy` | vulnerabilidad `HIGH`/`CRITICAL` corregible o secreto |
| frontend | `build-test` | error de compilación o prueba que falla |
| frontend | `lint` | error de ESLint |
| frontend | `trivy` | vulnerabilidad `HIGH`/`CRITICAL` corregible o secreto |

## Versión

- Una por repositorio, SemVer. Primera: `0.1.0`.
- Origen: commits convencionales desde la release anterior. `fix` sube parche; `feat` y los cambios incompatibles suben
  menor mientras la versión sea `< 1.0.0`; `chore`, `docs`, `test`, `refactor` y `build` no generan versión.
- Se declara en los `pom.xml` (backend) o en `package.json` y `package-lock.json` (frontend), y en
  `.release-please-manifest.json`.

| Estado | Pasa a | Cuando |
|---|---|---|
| sin cambios publicables | propuesta | llega a `main` un commit que genera versión |
| propuesta (PR de release) | publicada (tag y release) | se fusiona el PR de release |
| publicada | con imagen | la imagen pasa Trivy y se sube |
| publicada | sin imagen | Trivy la rechaza (se corrige en la siguiente) o fallo transitorio (se reintenta) |

## Imagen publicada

| Campo | Valor |
|---|---|
| Nombre | `ghcr.io/leandroamariles/<repositorio>` |
| Etiqueta | `X.Y.Z`, sin `v` y sin `latest` |
| Plataforma | `linux/amd64` |
| Origen | el código del tag `vX.Y.Z` |
| Visibilidad | pública |

## Excepción de análisis

| Herramienta | Dónde se declara | Datos |
|---|---|---|
| Trivy | `.trivyignore.yaml` | identificador, ruta y `statement` |
| Qodana | `qodana.yaml`, `exclude` | inspección y ruta; motivo en el commit |
| ESLint | `eslint.config.js` | regla y ruta; motivo en el commit |

Ninguna al empezar.
