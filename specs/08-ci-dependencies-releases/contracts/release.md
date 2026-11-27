# Contrato: workflow de release

Archivo `.github/workflows/release.yml` en backend y frontend, con `release-please-config.json` y
`.release-please-manifest.json` en la raíz.

| Elemento | Valor |
|---|---|
| Disparador | `push` sobre `main` |
| Concurrencia | un grupo por repositorio, sin cancelar la ejecución en marcha |
| Secreto | `RELEASE_PLEASE_TOKEN` (solo el trabajo `release-please`) |
| Permisos por defecto | `contents: read` |

## Trabajos

| Trabajo | Condición | Permisos | Hace |
|---|---|---|---|
| `release-please` | siempre | `contents: read` | abre o actualiza el PR de release; al fusionarlo crea tag y release |
| `publish` | `release_created == 'true'` | `contents: read`, `packages: write` | checkout del tag, construye, analiza y publica |

`publish` en orden:

1. `docker build` para `linux/amd64` con las etiquetas OCI `source`, `version` y `revision`.
2. Trivy sobre la imagen local: sistema y librerías, `HIGH,CRITICAL`, solo con corrección, código de salida 1.
3. Inicio de sesión en `ghcr.io` con `GITHUB_TOKEN`, pasando el token por la entrada estándar.
4. `docker push` de la imagen analizada.

## Resultado

| Repositorio | Imagen | Tag de Git |
|---|---|---|
| backend | `ghcr.io/leandroamariles/quipux-playlist-backend:X.Y.Z` | `vX.Y.Z` |
| frontend | `ghcr.io/leandroamariles/quipux-playlist-frontend:X.Y.Z` | `vX.Y.Z` |

El PR de release se titula `chore(main): release X.Y.Z` y pasa por el mismo CI que cualquier otro.
