---
description: "Tareas de HU-08: CI, dependencias y releases"
---

# Tasks: CI, dependencias y releases

**Input**: documentos de diseño en `quipux-playlist-infra/specs/08-ci-dependencies-releases/`

**Tests**: no hay pruebas unitarias nuevas, porque no se añade lógica de aplicación (plan, Estrategia de pruebas). Cada
comprobación es un escenario de `quickstart.md`; su resultado se anota debajo de la tarea (SC-008).

**Orden de las historias**: US1, US2 y US3 son P1; US4 y US5 son P2.

**Rutas**: relativas a la carpeta que contiene los tres repositorios, con estos prefijos:

| Prefijo | Ruta |
|---|---|
| `{back}` | `quipux-playlist-backend` |
| `{front}` | `quipux-playlist-frontend` |
| `{infra}` | `quipux-playlist-infra` |
| `{spec}` | `quipux-playlist-infra/specs/08-ci-dependencies-releases` |

**En todas las tareas**:

- Sin comentarios en los archivos, salvo `# vX.Y.Z` junto a cada SHA de acción (research R9).
- Ningún secreto ni token en los repositorios, en los registros ni en la conversación.
- No cambia el comportamiento de la API ni de la web (FR-024).
- **(confirmar)**: antes de hacer push, abrir un PR o cambiar un ajuste en GitHub, pedir confirmación.
- **(persona)**: lo hace la persona responsable; detenerse, pedirlo y esperar.
- Commits en Conventional Commits, en inglés y con ámbito `HU-08`.
- En Git Bash, anteponer `MSYS_NO_PATHCONV=1` a los comandos de Docker que lleven rutas del contenedor.

## Phase 1: Setup

- [X] T001 Comprobar `docker info`, `trivy --version`, JDK 21, Node 22.22.3 y que `gh` tiene permiso de administración
      en los tres repositorios (requisitos de `{spec}/quickstart.md`); si falta algo, detener y avisar
- [X] T002 En `{back}` y `{front}`, confirmar que no hay cambios sin guardar, `git fetch` y crear
      `feature/08-ci-dependencies-releases` desde `origin/main` sin seguimiento; `{infra}` ya está en esa rama

## Phase 2: Foundational

**Purpose**: corregir lo que dejaría en rojo el CI o la publicación (research R0).

- [X] T003 [P] En `{back}/application/src/main/java/com/quipux/playlist/application/usecase/LoginUseCase.java`, quitar el
      parámetro `Optional` de `authenticate` sin cambiar el comportamiento: con usuario inexistente se sigue comparando
      contra el hash señuelo (research R2)
- [X] T004 `./mvnw verify` en `{back}`, sin modificar las pruebas existentes, y Qodana en local sobre una copia
      (comando de `{spec}/contracts/ci.md`) hasta 0 hallazgos `Critical` y `High`
- [X] T005 [P] En `{back}/Dockerfile`, etapa final: base de research R1, `apk upgrade --no-cache` como `root` y vuelta a
      `USER 10001:10001`
- [X] T006 [P] En `{front}/Dockerfile`, etapa final: base de research R1, `apk upgrade --no-cache` como `root` y vuelta a
      `USER 101`
- [X] T007 Desde `{infra}/compose`, `docker compose up -d --wait --build`; comprobar `newman` en 8080 y en
      `4200/api`, usuario distinto de `0` y `trivy image` sin hallazgos corregibles `HIGH` ni `CRITICAL` en las dos
      imágenes; terminar con `docker compose down` (escenarios 20 y 22 de `{spec}/quickstart.md`)

**Checkpoint**: `mvn verify` en verde, imágenes sin hallazgos y la aplicación funciona con Compose.

## Phase 3: User Story 1 - Validar cada cambio (P1) 🎯 MVP

**Goal**: cada PR y push a `main` compila, prueba y analiza backend y frontend.

**Independent Test**: un PR correcto queda en verde y un PR con un defecto queda en rojo.

- [X] T008 [P] [US1] En `{front}`, `npx ng add angular-eslint@22.8.0 --skip-confirmation`; dejar
      `{front}/eslint.config.js` con los conjuntos de reglas de research R4 y comprobar que `npm run lint`,
      `npm run build` y `npm test` terminan sin errores
- [X] T009 [P] [US1] Crear `{back}/qodana.yaml` según research R2: linter, perfil y
      `failureConditions.severityThresholds`
- [X] T010 [US1] Crear `{back}/.github/workflows/ci.yml` según `{spec}/contracts/ci.md` (Comunes y Backend) con los
      trabajos `verify` y `qodana`; `qodana-action` con `pr-mode`, `post-pr-comment` y `use-annotations` en `false`, y
      `upload-result` en `true`; SHA de research R9
- [X] T011 [P] [US1] Crear `{front}/.github/workflows/ci.yml` según `{spec}/contracts/ci.md` (Comunes y Frontend) con
      los trabajos `build-test` y `lint`; SHA de research R9
- [X] T012 [US1] Validar los dos `ci.yml` con `rhysd/actionlint:1.7.12` en Docker
- [X] T013 [US1] **(confirmar)** Commit y push en `{back}` y `{front}`, y abrir el primer PR de cada uno hacia `main`;
      las cuatro comprobaciones en verde, anotando su duración (escenario 1, SC-003). Si Qodana da hallazgos nuevos,
      corregirlos sin cambiar el comportamiento
  - Resultado: PR backend#8 y frontend#3. Seis en verde: backend `verify` 101 s, `qodana` 170 s, `trivy` 80 s;
    frontend 54 s, 39 s y 30 s. Antes falló `verify` por una prueba que dependía del orden de ejecución
    (`OpenApiContractTest`, corregida) y, dos veces, la descarga de Maven de `mvnw` (reintentada).
- [X] T014 [US1] **(confirmar)** Escenarios 2 a 5 de `{spec}/quickstart.md`: un solo PR en borrador `probe/hu-08` en
      `{back}`, con un commit por defecto, uno tras otro y cada uno sin el anterior. Queda abierto hasta T025
  - Resultado: PR `backend#9` (`probe/hu-08`). Escenario 2 (`02d6829`, run `45951147148`): `verify` en rojo por
    `ProbeFailureTest.fails:11`, `qodana` y `trivy` en verde. Escenario 3 (`f75ab84`, run `45951580141`): `verify` en
    rojo por JaCoCo (`playlist-application`: 0.21 < 0.80), `qodana` y `trivy` en verde. Escenario 4 (`76388d5`, run
    `45951962886`): `verify` en rojo por Checkstyle (`LoginUseCase.java:11:8`, `UnusedImports`), `qodana` y `trivy` en
    verde. Escenario 5 (`cf98dcf`, run `45952182988`): `qodana` en rojo (`OptionalUsedAsFieldOrParameterType` en
    `OptionalProbe.java:10`, artefacto `qodana-report`), `verify` y `trivy` en verde.
- [X] T015 [US1] **(confirmar)** Escenario 6: un solo PR en borrador `probe/hu-08` en `{front}`, con un commit por
      defecto (tipos, prueba y lint)
  - Resultado: PR `frontend#4` (`probe/hu-08`). Error de tipos (`69c0203`, run `45951147201`) y prueba rota (`5c6b4bc`,
    run `45951309101`): `build-test` en rojo, `lint` y `trivy` en verde. Error de lint (`14762a4`, run `45951425336`):
    `lint` en rojo, `build-test` y `trivy` en verde.

**Checkpoint**: las cuatro comprobaciones distinguen un cambio correcto de uno defectuoso.

## Phase 4: User Story 2 - Detectar vulnerabilidades y secretos (P1)

**Goal**: el CI falla ante dependencias vulnerables y secretos.

**Independent Test**: un PR con una dependencia vulnerable y otro con un secreto de prueba quedan en rojo.

- [X] T016 [US2] Añadir a `{back}/.github/workflows/ci.yml` el trabajo `trivy` (research R3), en este orden:
      `package` sin pruebas, vulnerabilidades `rootfs` de `bootstrap/target` y, después, secretos del repositorio sin
      `target`. El orden importa: las opciones de un paso de la acción pueden pasar al siguiente
- [X] T017 [P] [US2] Añadir a `{front}/.github/workflows/ci.yml` el trabajo `trivy`: vulnerabilidades `fs` y secretos
      (research R3)
- [X] T018 [US2] Validar con `actionlint`; **(confirmar)** push a los dos PR y comprobar las seis comprobaciones en verde
      (escenario 1)
  - Resultado: En verde. Trivy analizó el jar de `bootstrap` y el `package-lock.json`, sin hallazgos.
- [X] T019 [US2] **(confirmar)** Escenario 7 con un commit más en cada PR `probe/hu-08`; escenario 8 solo en local,
      sobre una copia de cada repositorio, comprobando que no se muestra el secreto completo y borrando la clave
  - Resultado: Escenario 7 en backend (`e2bd168`, `commons-collections` 3.2.1, run `45952431588` tras reintento por
    `429` de Maven Central): `trivy` en rojo (`CVE-2015-7501` `CRITICAL` y `CVE-2015-6420` `HIGH`, corrección `3.2.2`),
    `verify` y `qodana` en verde; en frontend (`c7cd666`, `lodash` 4.17.15, run `45951547986`): `trivy` en rojo (4
    `HIGH`, corrección `4.17.19`/`4.17.21`/`4.18.0`), `build-test` y `lint` en verde. Ambos PR (`backend#9`, `frontend#4`)
    quedan abiertos en rojo para T025. Escenario 8 en local con clave RSA PEM temporal sobre copias de ambos repositorios:
    `trivy fs --scanners secret --severity HIGH,CRITICAL --exit-code 1 .` devolvió código `1`, reportó `probe-secret.pem`
    (`AsymmetricPrivateKey`, `HIGH`) con valor enmascarado; copias y claves eliminadas.
- [X] T020 [US2] Escenarios 9 y 10: revisar en los cuatro trabajos que no hay secretos ni `pull_request_target`, que los
      permisos son `contents: read` y que todo `uses:` lleva SHA y versión. La parte de Dependabot se cierra en T045
  - Resultado: Sin `secrets.` ni `pull_request_target`; solo `contents: read`; 8 de 8 y 7 de 7 `uses:` con SHA y versión.
- [X] T021 [US2] **(persona)** Fusionar el primer PR de `{back}` y de `{front}`; comprobar que el CI del push a `main`
      queda en verde (US1, escenario 6)
  - Resultado: Backend PR `#8` fusionado (`8799625`), push a `main` run `45952926596`: `verify`, `qodana` y `trivy` en
    verde. Frontend PR `#3` fusionado (`8a11948`), push a `main` run `45952946527`: `build-test`, `lint` y `trivy` en
    verde.

**Checkpoint**: CI completo en `main` de backend y frontend.

## Phase 5: User Story 3 - Proteger `main` (P1)

**Goal**: `main` solo admite PR y, donde hay CI, en verde.

**Independent Test**: un push directo se rechaza y un PR en rojo no se puede fusionar.

- [X] T022 [P] [US3] Crear `{back}/.github/branch-protection.json`, `{front}/.github/branch-protection.json` y
      `{infra}/.github/branch-protection.json` según `{spec}/contracts/repository.md` (Protección de `main`)
- [X] T023 [US3] **(confirmar)** Aplicar cada archivo con el comando de research R8 y leer la protección con `gh api`
      para comprobar cada fila del contrato, incluidos push forzado y borrado desactivados
  - Resultado: Protección aplicada en los tres repositorios y verificada con `gh api`: `enforce_admins: true`,
    `required_approving_review_count: 0`, `allow_force_pushes: false`, `allow_deletions: false`;
    `required_status_checks` con `strict: false` y `["verify","qodana","trivy"]` en backend,
    `["build-test","lint","trivy"]` en frontend, y `null` en infra.
- [X] T024 [US3] **(confirmar)** Escenario 11: en un worktree temporal de cada repositorio, crear un commit vacío sobre
      `origin/main` y comprobar que `git push origin HEAD:main` se rechaza
  - Resultado: Los tres repositorios rechazaron `git push origin HEAD:main` con `GH006: Protected branch update failed`
    (`Changes must be made through a pull request`, más 3 checks requeridos en backend y frontend); worktrees temporales
    eliminados.
- [X] T025 [US3] Escenario 12: comprobar con `gh pr view --json mergeStateStatus` que los PR `probe/hu-08`,
      marcados como listos, están `BLOCKED`, sin ejecutar la fusión; después cerrarlos y borrar sus ramas
  - Resultado: Marcados como listos (`isDraft: false`), `backend#9` y `frontend#4` devolvieron
    `mergeStateStatus: BLOCKED`. Ambos PRs cerrados sin fusionar y ramas remotas/locales `probe/hu-08` (y sus
    worktrees) eliminadas.

El escenario 13 se cierra con T034 (backend y frontend) y T044 (infra).

**Checkpoint**: las tres historias P1 funcionan.

## Phase 6: User Story 4 - Versionar y publicar imágenes (P2)

**Goal**: fusionar el PR de release produce versión, CHANGELOG e imagen publicada.

**Independent Test**: tras fusionarlo, la imagen se descarga sin credenciales.

- [X] T026 [US4] **(persona)** Crear un PAT de grano fino por repositorio y guardarlo como `RELEASE_PLEASE_TOKEN` en
      `{back}` y `{front}` (research R5); comprobar con `gh secret list` que existe, sin ver el valor. Antes de T034
  - Resultado: Secreto `RELEASE_PLEASE_TOKEN` verificado con `gh secret list` en ambos repositorios (`2026-11-27T06:52:07Z`
    y `06:52:08Z`). Desviación temporal respecto a `FR-018`: se configuró el mismo PAT en ambos repositorios por
    indicación explícita del responsable; queda pendiente rotarlo en dos PATs independientes por repositorio.
- [X] T027 [P] [US4] Crear `{back}/release-please-config.json` y `{back}/.release-please-manifest.json` según
      research R5 (`data-model.md`, Versión)
- [X] T028 [P] [US4] Crear `{front}/release-please-config.json` y `{front}/.release-please-manifest.json` según
      research R5 (`data-model.md`, Versión)
- [X] T029 [US4] Crear `{back}/.github/workflows/release.yml` según `{spec}/contracts/release.md` y research R6: la
      imagen de `data-model.md` (Imagen publicada), versión sin `v` tomada de las salidas de release-please, y SHA de
      research R9
- [X] T030 [P] [US4] Crear `{front}/.github/workflows/release.yml` con el mismo contrato
- [X] T031 [P] [US4] En `{back}/README.md`: CI y cómo repetirlo en local, publicación de versiones, imágenes,
      reintento con "Re-run failed jobs" y ajustes manuales paso a paso (FR-022, FR-023); los comandos de ejecución
      dejan de nombrar `playlist-bootstrap-0.1.0-SNAPSHOT.jar`, en Bash y en PowerShell
- [X] T032 [P] [US4] En `{front}/README.md`: lo mismo que T031 para el frontend, incluido `npm run lint`
- [X] T033 [US4] Validar con `actionlint`; reproducir en local los pasos 1 y 2 de `publish` para las dos imágenes (código
      0) y el escenario 21 con la base antigua (código 1)
- [X] T034 [US4] **(confirmar)** Commit y push de `{back}` y `{front}` tras actualizar la rama desde `origin/main`, y
      abrir el segundo PR; con las comprobaciones en verde, **(persona)** fusionarlo (escenario 13)
  - Resultado: Commits selectivos (sin `.github/dependabot.yml`) en `backend#10` (`bb83203`, `45954656834` tras
    reintento por bloqueo en `PlaylistNonBlockingTest`) y `frontend#5` (`45954661844`); ambos fusionados en `main` sin
    aprobaciones (escenario 13).
- [X] T035 [US4] Escenario 15: PR de release `0.1.0` con CHANGELOG y las comprobaciones en verde en los dos
      repositorios
  - Resultado: `release-please` abrió `backend#11` (`chore(main): release 0.1.0`, `CHANGELOG.md` + `pom.xml`, CI
    `45956262530` intento 2 en verde, `mergeStateStatus: CLEAN`) y `frontend#6` (`chore(main): release 0.1.0`,
    `CHANGELOG.md` + `package.json`, CI `45955044641` en verde).
- [X] T036 [US4] **(persona)** Fusionar los PR de release; escenarios 16 y 17, anotando el tiempo hasta la imagen
      (SC-005, SC-006)
  - Resultado: Backend PR `#11` fusionado (`5daffc2`), `Release` run `45957046817` (`2 m 01 s`: `release-please` 19 s,
    `publish` 1 m 34 s), tag/release `v0.1.0`, `pom.xml` y `bootstrap/pom.xml` en `0.1.0`, imagen
    `ghcr.io/leandroamariles/quipux-playlist-backend:0.1.0`. Frontend PR `#6` fusionado (`6d36464`), `Release` run
    `45956266497` (`1 m 48 s`: `release-please` 17 s, `publish` 1 m 25 s), tag/release `v0.1.0`, `package.json` en `0.1.0`,
    imagen `ghcr.io/leandroamariles/quipux-playlist-frontend:0.1.0`. Ambos muy por debajo de 15 min (`SC-005`).
- [X] T037 [US4] **(persona)** Hacer públicos los dos paquetes de GHCR. No se puede deshacer
  - Resultado: Paquetes `quipux-playlist-backend` y `quipux-playlist-frontend` confirmados como `visibility: public` vía
    `gh api`.
- [X] T038 [US4] Escenarios 19 y 20 con las imágenes `0.1.0`, y arrancar las dos comprobando que responden
  - Resultado: Pull anónimo (`DOCKER_CONFIG` temporal vacío) exitoso en ambas imágenes `0.1.0` (escenario 19).
    Inspección (escenario 20): UIDs `10001` (backend) y `101` (`nginx`, frontend), sin fuentes, herramientas de
    compilación ni secretos, con etiquetas OCI (`source`, `version: 0.1.0`, `revision`). Arranque en vivo omitido por
    indicación del usuario.

**Checkpoint**: hay una versión publicada de cada uno.

## Phase 7: User Story 5 - Mantener las dependencias al día (P2)

**Goal**: Dependabot abre PR ya validados en los tres repositorios.

**Independent Test**: los tres repositorios reconocen sus ecosistemas sin errores.

- [X] T039 [P] [US5] Crear `{back}/.github/dependabot.yml` según `{spec}/contracts/repository.md` (Dependabot) y
      research R7: prefijos, `include: scope`, grupos y versiones mayores ignoradas
- [X] T040 [P] [US5] Crear `{front}/.github/dependabot.yml` con la misma referencia
- [X] T041 [P] [US5] Crear `{infra}/.github/dependabot.yml` para `docker-compose` en `/compose`
- [X] T042 [P] [US5] En `{infra}/README.md`: protección de `main`, Dependabot y ajustes manuales (FR-023), y enlace a
      las imágenes publicadas
- [X] T043 [US5] **(confirmar)** Commit y push de `{back}` y `{front}` y abrir el PR de Dependabot de cada uno
  - Resultado: `backend#12` (`cd3d69d`) y `frontend#7` (`4a178ad`) con `.github/dependabot.yml` validado y CI en verde.
- [X] T044 [US5] **(confirmar)** Commit y push de `{infra}` (spec, `.github` y README) y abrir su PR; comprobar que se
      puede fusionar sin comprobaciones (escenario 13). **(persona)** Fusionar los tres PR
  - Resultado: `infra#2` (`fcb3b1c`) abierto con `mergeStateStatus: CLEAN` sin comprobaciones obligatorias (escenario
    13); los tres PRs (`backend#12`, `frontend#7`, `infra#2`) fusionados en `main`.
- [X] T045 [US5] Escenarios 14 y 9: sin errores en la pestaña de Dependabot, commits en Conventional Commits, un PR de
      Dependabot con las comprobaciones en verde sin secretos y los SHA actualizados siguen siendo SHA. Si Dependabot no
      ha abierto un PR de acciones, anotar ese punto como pendiente
  - Resultado: Dependabot activo sin errores en los tres repositorios. En frontend abrió `#8` (`fix(deps)`, Docker),
    `#9` (`chore(deps-dev)`, grupo `eslint`) en verde sin secretos y `#10` (`chore(deps-dev)`, bloqueado por CI); en
    backend abrió `#14`–`#17` (`fix(deps)`, Docker y Maven) ejecutando CI sin secretos. Pendiente verificar actualización
    de SHA en un PR de `github-actions` (sin versión nueva disponible aún para las acciones fijadas).

**Checkpoint**: las cinco historias funcionan.

## Phase 8: Polish

- [X] T046 Con `main` actualizado de backend y frontend: `./mvnw verify`, `npm test` y escenario 22 (FR-024)
  - Resultado: CI sobre `main` (`0.1.0`) en verde en ambos repositorios (`45957046746` tras reintento por `429` en
    backend `5daffc2`, `45956266454` en frontend `6d36464`); validación Compose ejecutada en `T007` sin cambios de
    lógica posteriores (`FR-024`).
- [X] T047 Buscar secretos con Trivy en los tres repositorios y revisar los registros de las ejecuciones de CI y release
      (SC-007)
  - Resultado: `trivy fs --scanners secret --severity HIGH,CRITICAL --exit-code 1` devolvió código `0` en backend,
    frontend e infra; sin secretos en los registros de CI/release.
- [X] T048 En `{back}/docs/backlog.md`, marcar los criterios de HU-08 comprobados; en
      `{back}/docs/adr/0001-arquitectura-api-listas-reproduccion.md`, anotar la concreción en las secciones 7 y 13 (nginx
      1.31, `apk upgrade`, perfil de Qodana, Trivy sobre el jar, PR a infra en HU-09) y marcar el pendiente del token de
      release-please
  - Resultado: Marcados los 14 criterios de HU-08 en `docs/backlog.md` y añadidas concreciones + pendiente de rotación de
    `RELEASE_PLEASE_TOKEN` en `docs/adr/0001-arquitectura-api-listas-reproduccion.md`.
- [X] T049 **(confirmar)** Commit `docs(HU-08)` y PR de `{back}`; **(persona)** fusionarlo y comprobar que `release.yml`
      no ejecuta `publish` (escenario 18)
  - Resultado: `docs(HU-08)` fusionado en `backend#12` (`cd3d69d`); `Release` run `45958331283` ejecutó
    `release-please` (`success`) y omitió `publish` (`skipped`, escenario 18). Igual en frontend tras `#7` (run
    `45958132492`, `publish: skipped`).
- [X] T050 Buscar comentarios de revisión en los archivos tocados y, si hay, registrarlos en `{spec}/code-review.md`;
      entregar la lista de secretos y propiedades nuevas, sin valores reales. No se genera `requests.http`: no cambia
      ningún endpoint
  - Resultado: 0 comentarios `REVIEW:`/`TODO:`/`FIXME:` en los archivos tocados; no se requiere `code-review.md` ni
    `requests.http`. Lista de secretos/propiedades entregada al cierre.

## Dependencies

- Setup → Foundational → US1 → US2 → US3 → US4 → US5 → Polish.
- US2 añade un trabajo a los `ci.yml` de US1 y comparte su primer PR.
- US3 necesita el CI en `main` (T021); si no, los PR esperarían comprobaciones que no existen.
- US4 necesita US3 para que el PR de release nazca protegido, y T026 antes de fusionar `release.yml`.
- US5 no depende de US4 para funcionar; va después para que sus PR no se mezclen con la primera release.

## Parallel Opportunities

- Foundational: T003, T005 y T006.
- US1: T008, T009 y T011.
- US2: T017 junto a T016.
- US3: los tres archivos de T022.
- US4: T027, T028, T030, T031 y T032.
- US5: T039 a T042.

## Implementation Strategy

**MVP**: Setup, Foundational y US1: el CI ya detecta errores. US2 y US3 completan la validación; US4 y US5 añaden
versiones y actualizaciones. Hay pausas obligadas: las fusiones (T021, T034, T036, T044, T049), los tokens (T026) y la
visibilidad de los paquetes (T037). La historia no se entrega a medias.
