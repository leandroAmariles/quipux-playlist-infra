# Quickstart: validar CI, dependencias y releases

Contratos en [contracts/](contracts/). Los comandos usan Git Bash.

## Requisitos

- `gh` autenticado con permisos de administración sobre los tres repositorios
- Docker en marcha y Trivy
- JDK 21 y Node 22.22.3
- Los dos tokens de release-please creados (ver [contracts/repository.md](contracts/repository.md))

## Defectos a propósito

Cada repositorio usa un solo PR en borrador desde `probe/hu-08`, con un commit por defecto, uno tras otro; se cierra sin
fusionar y su rama se borra (decidido el 2026-11-27 para dejar menos rastro en repositorios públicos).
El secreto no se sube: el escenario 8 se prueba en local con una clave privada generada para ello, así que no queda
demostrado en un PR que el CI lo bloquee.

## Escenarios

| # | Comprueba | Pasos | Resultado esperado |
|---|---|---|---|
| 1 | US1 1 y 4 | PR sin defectos en backend y frontend | las seis comprobaciones en verde en menos de 15 min |
| 2 | US1 2 | PR con una prueba rota | `verify` en rojo, nombra la prueba |
| 3 | US1 2 | PR con una clase sin pruebas que baje la cobertura | `verify` en rojo por JaCoCo |
| 4 | US1 2 | PR con un import sin usar | `verify` en rojo por Checkstyle |
| 5 | US1 3 | PR con un parámetro `Optional` | `qodana` en rojo; resultado con archivo y línea |
| 6 | US1 5 | PRs de frontend con error de tipos, prueba rota y error de lint | `build-test` o `lint` en rojo |
| 7 | US2 1 | PR con una dependencia vulnerable (`commons-collections` 3.2.1; `lodash` 4.17.15) | `trivy` en rojo, indica la corrección |
| 8 | US2 3 | en local, clave de prueba y `trivy fs --scanners secret --exit-code 1 .` | falla, nombra el archivo y oculta el valor |
| 9 | US2 4, FR-009 | revisar los workflows y el primer PR de Dependabot | en verde sin secretos; permisos mínimos |
| 10 | FR-008 | buscar `uses:` en los workflows | todas con SHA de 40 caracteres y su versión |
| 11 | US3 1 | `git push origin HEAD:main` con un commit vacío en los tres | rechazado |
| 12 | US3 2 | intentar fusionar el PR del escenario 2 | no se permite |
| 13 | US3 3 y 4 | fusionar un PR en verde, y uno de infra | se permite sin aprobaciones |
| 14 | US5 1 y 2 | pestaña de Dependabot de cada repositorio y sus commits | sin errores; Conventional Commits |
| 15 | US4 1 y 2 | tras fusionar `release.yml` | PR de release `0.1.0` con CHANGELOG y CI ejecutándose |
| 16 | US4 3, SC-005 | fusionar el PR de release | tag, release e imagen `0.1.0` en menos de 15 min |
| 17 | FR-017 | versión en `pom.xml` o `package.json` de `main` | `0.1.0` |
| 18 | US4 5 | fusionar un `docs:` | no hay `publish` |
| 19 | US4 6, FR-020 | `DOCKER_CONFIG="$(mktemp -d)" docker pull <imagen>:0.1.0` | descarga sin credenciales |
| 20 | US4 6, FR-021 | `docker run --rm --entrypoint id <imagen>` y listar su contenido | sin administrador, fuentes ni secretos |
| 21 | US4 4 | en local, `trivy image --exit-code 1` sobre `nginx-unprivileged:1.30.6-alpine` | código 1, así que `publish` se detendría |
| 22 | FR-024 | `docker compose up -d --wait --build` en infra y `newman` en 8080 y 4200 | como en HU-07 |

Los escenarios 11 a 13 se ejecutan después de aplicar la protección. El 11 usa un commit vacío para que, si la
protección fallara, no llegue ningún cambio.
