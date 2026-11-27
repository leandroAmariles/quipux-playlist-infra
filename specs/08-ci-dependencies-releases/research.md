# Research: CI, dependencias y releases

Comprobado el 2026-11-27 sobre `origin/main` de cada repositorio.

## R0. Estado de partida

| Comprobación | Resultado |
|---|---|
| `./mvnw verify` en un contenedor Linux (Maven 3.9.11, JDK 21) | en verde |
| Trivy, vulnerabilidades `HIGH`/`CRITICAL` corregibles, dependencias de backend y frontend | 0 |
| Trivy, secretos `HIGH`/`CRITICAL` en los tres repositorios | 0 |
| ESLint con las reglas recomendadas de Angular sobre una copia del frontend | 0 errores |
| Qodana `jvm-community` 2026.3, perfil `qodana.starter`, backend | 1 hallazgo `High` |
| Imagen del backend de HU-07 | 1 `HIGH` corregible (`libfontenc`) |
| Base de la imagen del frontend, `nginx-unprivileged:1.30.6-alpine` | 26 `HIGH`/`CRITICAL` corregibles |

El hallazgo de Qodana es `OptionalUsedAsFieldOrParameterType` en `LoginUseCase.java:42`. Las dos imágenes se
bloquearían al publicar (FR-019), así que se corrigen en esta historia.

### Lo que apareció al ejecutar el CI (2026-11-27)

- `OpenApiContractTest.proposesExamplesThatTheApiAccepts` dependía del orden de las clases: el ejemplo del contrato,
  `Mis favoritas`, también está en `special-names.properties` y las clases comparten la base en memoria. En el runner
  daba `409`. Se reproduce con `-Dsurefire.runOrder=reversealphabetical`. La prueba borra ahora ese nombre antes de
  crearlo; pasan las 419 pruebas en cinco órdenes distintos.
- `mvnw` no pudo descargar la distribución de Maven en dos de cuatro intentos sin caché. `setup-java` la cachea aparte
  en cuanto un trabajo pasa, y entonces no se repite la descarga. No se cambia nada; si se repite con caché, habrá que
  decidir otra fuente para el binario.

## R1. Imágenes base

- **Decisión**: backend `eclipse-temurin:21.0.13.1_2-jre-alpine-3.24`; frontend
  `nginxinc/nginx-unprivileged:1.31.7-alpine`. En ambas, la etapa final ejecuta `apk upgrade --no-cache` como
  administrador y vuelve al usuario sin privilegios (`10001:10001` en backend, `101` en frontend).
- **Rationale**: la base del backend sale sin hallazgos. La del frontend con `apk upgrade` también (probado; usuario
  `101`). `apk upgrade` recoge parches de Alpine publicados después de la imagen base, que si no bloquearían releases.
- **Descartado**: `nginx-unprivileged:1.30.6-alpine` con `apk upgrade` conserva 6 hallazgos de nginx y no hay imagen
  1.30.7 sin privilegios. `nginx:1.30.7-alpine` obliga a reconfigurar el usuario y aún tiene 7 de `libxml2`.
- **Consecuencia**: nginx pasa de la rama estable (1.30) a la principal (1.31). Los paquetes de Alpine ya no quedan
  fijados por la etiqueta base.

## R2. Qodana

- **Decisión**: `JetBrains/qodana-action` fijada por SHA (v2026.3.1), con `qodana.yaml`: linter `qodana-jvm-community`,
  perfil `qodana.starter` y `failureConditions.severityThresholds` con `critical: 0` y `high: 0`. Sin token, sin
  comentarios en el PR, sin modo PR (analiza el proyecto completo en PR y en `main`) y subiendo el resultado como
  artefacto.
- **Rationale**: el linter community no necesita cuenta; los umbrales por severidad están disponibles para JVM. La
  ejecución local tarda unos 5 minutos.
- **Descartado**: `qodana.recommended` y las inspecciones sugeridas (amplían el alcance); ejecutar la imagen con
  `docker run` (Dependabot no actualizaría su versión).
- **Corrección del hallazgo**: quitar el parámetro `Optional` de `authenticate` sin cambiar el comportamiento. Las
  pruebas de `LoginUseCase`, incluida la comparación contra el hash señuelo, deben seguir pasando sin modificarse.

## R3. Trivy

- **Decisión**: `aquasecurity/trivy-action` v0.36.0 fijada por SHA y binario `v0.76.2`, con dos pasos: vulnerabilidades
  (`ignore-unfixed`, `HIGH,CRITICAL`, código de salida 1) y secretos (`HIGH,CRITICAL`, código de salida 1).
- **Backend**: `./mvnw -DskipTests package` y análisis `rootfs` del jar ejecutable. Lee las 118 dependencias que se
  entregan, sin resolver nada contra Maven Central.
- **Frontend**: análisis `fs` del `package-lock.json`, que excluye las dependencias de desarrollo.
- **Descartado**: analizar los `pom.xml` (resuelve en remoto y puede sufrir límites de peticiones).
- **Excepciones**: `.trivyignore.yaml`, una entrada por hallazgo con `statement`. Hoy no hace falta ninguna.
- **Nota**: la acción sufrió un ataque en marzo de 2026 (ADR-0001, sección 13); por eso se fija por SHA y se fija la
  versión del binario.

## R4. ESLint

- **Decisión**: `angular-eslint` 22.8.0, `eslint` 10, `typescript-eslint` 8, con `ng add` (deja `npm run lint`).
  Reglas `recommended` y `stylistic` de TypeScript y `recommended` y accesibilidad de plantillas.
- **Rationale**: es la integración estándar de Angular 22; `typescript-eslint` admite el TypeScript 6.0 del proyecto.
  Con esas reglas no hay errores.
- **Descartado**: añadir una comprobación de Prettier (no está en el backlog).

## R5. release-please

- **Decisión**: `googleapis/release-please-action` v5.0.0 por SHA, en modo manifiesto. Backend `release-type: maven`
  con `skip-snapshot: true`; frontend `release-type: node`. En ambos `initial-version: 0.1.0`,
  `bump-minor-pre-major: true`, `include-component-in-tag: false` y manifiesto `{".": "0.0.0"}`.
- **Rationale** (código de release-please 17.11.2): `0.0.0` se trata como "sin releases" y se usa `initial-version`,
  que por defecto sería `1.0.0`. `maven` actualiza todos los `pom.xml`, incluido el padre de cada módulo. Con
  `skip-snapshot` la versión declarada es siempre la publicada (FR-017).
- **Descartado**: SNAPSHOT entre releases (incumple FR-017).
- **Consecuencia**: el README del backend nombra `playlist-bootstrap-0.1.0-SNAPSHOT.jar`; pasa a no depender de la
  versión. El Dockerfile ya usa un comodín.
- **Token**: PAT de grano fino por repositorio, secreto `RELEASE_PLEASE_TOKEN`, permisos sobre ese repositorio:
  Contents, Pull requests e Issues (etiquetas) en lectura y escritura.

## R6. Construcción y publicación de la imagen

- **Decisión**: en el mismo workflow, un trabajo condicionado a `release_created` que hace checkout del tag,
  `docker build`, análisis de la imagen local con Trivy y `docker push` de esa misma imagen, con `GITHUB_TOKEN` y
  `packages: write`. Etiqueta OCI `org.opencontainers.image.source` para enlazar el paquete al repositorio.
- **Rationale**: se publica exactamente lo analizado y no se añaden acciones de terceros para construir ni para
  iniciar sesión.
- **Reintento**: "Re-run failed jobs" conserva las salidas de release-please y publica la misma versión.
- **Descartado**: `docker/build-push-action` (reconstruir al publicar puede dar una imagen distinta de la analizada).
- **Visibilidad**: el paquete se crea privado y hay que hacerlo público a mano. En GitHub ese cambio no se puede
  deshacer.

## R7. Dependabot

- **Decisión**: semanal. `prefix: fix` en `maven`, `npm` y `docker`, con `prefix-development: chore` en `maven` y
  `npm`; `chore` en `github-actions` y `docker-compose`; `include: scope` en todos.
- **Grupos**: Angular (`@angular/*`, `angular-eslint`), ESLint y GitHub Actions, para que lo que va junto se
  actualice junto.
- **Versiones mayores ignoradas**: imágenes de Java, Maven y Node, y Angular. Cambian la plataforma acordada o
  necesitan migración.
- **Rationale**: `prefix-development` no existe para `docker`. Los PR de Dependabot no reciben secretos y el CI no los
  necesita.

## R8. Protección de `main`

- **Decisión**: protección clásica, versionada en `.github/branch-protection.json` y aplicada con
  `gh api -X PUT repos/<dueño>/<repo>/branches/main/protection --input`. PR obligatorio con 0 aprobaciones,
  `enforce_admins`, sin push forzado ni borrado y sin exigir la rama al día. Comprobaciones por nombre de trabajo.
- **Rationale**: repetible y revisable (FR-023).
- **Descartado**: rulesets (más opciones sin necesidad) y configurarlo en la web (no queda registro).

## R9. Acciones y permisos

| Acción | Versión | SHA |
|---|---|---|
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/setup-java` | v6.3.0 | `d1374f8ac74474200d16ef8ecee22c7ae7a51880` |
| `actions/setup-node` | v7.1.0 | `949feb2413d6458794dcd2491c4babbbce0c15c1` |
| `JetBrains/qodana-action` | v2026.3.1 | `aa698739cd4b8204ad53291bea7e16cd75da3c9f` |
| `aquasecurity/trivy-action` | v0.36.0 | `ed142fd0673e97e23eac54620cfb913e5ce36c25` |
| `googleapis/release-please-action` | v5.0.0 | `45996ed1f6d02564a971a2fa1b5860e934307cf7` |

Junto a cada SHA va `# vX.Y.Z` (FR-008); es el único comentario de los workflows. Los permisos de cada workflow son
`contents: read` y se amplían por trabajo. Nunca `pull_request_target`.

Los repositorios ya tienen el escaneo de secretos de GitHub con bloqueo de push; Trivy lo complementa.

## Fuentes

- [Qodana: quality gate](https://www.jetbrains.com/help/qodana/quality-gate.html)
- [Qodana para JVM](https://www.jetbrains.com/help/qodana/jvm.html)
- [release-please: manifiesto](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md)
- [release-please: Java y Maven](https://github.com/googleapis/release-please/blob/main/docs/java.md)
- [release-please-action](https://github.com/googleapis/release-please-action)
- [Opciones de Dependabot](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)
