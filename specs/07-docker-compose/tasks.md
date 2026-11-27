---
description: "Tareas de HU-07: Docker y Compose"
---

# Tasks: Docker y Compose

**Input**: documentos de diseño en `quipux-playlist-infra/specs/07-docker-compose/`

**Tests**: no hay pruebas unitarias nuevas, porque no cambia código de la aplicación (plan, Estrategia de pruebas). Cada
comprobación es un escenario de `quickstart.md`; su resultado se anota debajo de la tarea (SC-007).

**Orden de las historias**: US1 y US2 son P1 y US3 es P2. Las dos imágenes son comunes, así que van antes.

**Rutas**: relativas a la carpeta que contiene los tres repositorios, con estos prefijos:

| Prefijo | Ruta |
|---|---|
| `{back}` | `quipux-playlist-backend` |
| `{front}` | `quipux-playlist-frontend` |
| `{infra}` | `quipux-playlist-infra` |
| `{spec}` | `quipux-playlist-infra/specs/07-docker-compose` |

**En todas las tareas**:

- Sin comentarios en Dockerfiles, Compose, nginx ni ningún otro archivo.
- Ningún secreto, contraseña real ni token en los repositorios ni en las imágenes. Los valores de prueba se escriben
  solo en `{infra}/compose/.env`, que no se versiona.
- No cambia el código ni el comportamiento de la aplicación (FR-018).
- En Git Bash, anteponer `MSYS_NO_PATHCONV=1` a los comandos de Docker que lleven rutas del contenedor.
- Sin commits hasta que se pidan; después, uno por repositorio con ámbito `HU-07`.

## Phase 1: Setup

- [X] T001 Comprobar que `docker info` y `docker compose version` responden; si el motor no arranca, detener la
      implementación y avisar (requisito de `{spec}/quickstart.md`)
  - Resultado: Docker 29.6.1 y Compose 5.3.0.
- [X] T002 En `{back}` y `{front}`, confirmar que no hay cambios sin guardar, hacer `git fetch` y crear
      `feature/07-docker-compose` desde `origin/main`; `{infra}` ya está en esa rama
- [X] T003 [P] Añadir `specs/*/.token-usage.json` a `{infra}/.gitignore`

## Phase 2: Foundational

**Purpose**: las dos imágenes, de las que dependen las tres historias.

- [X] T004 [P] Crear `{back}/.dockerignore` por lista de permitidos: `pom.xml` y, de `domain`, `application`,
      `infrastructure` y `bootstrap`, su `pom.xml` y su `src` (research R3)
- [X] T005 Crear `{back}/Dockerfile` multietapa según research R1 y R2: construcción con caché de BuildKit para
      `/root/.m2`; imagen final con solo `/app/app.jar`, `USER 10001`, `EXPOSE 8080` y `ENTRYPOINT` en forma de lista
  - Resultado: Se fija `USER 10001:10001`: con solo el usuario, el grupo quedaba en `root`.
- [X] T006 `docker build {back}`; arrancar el contenedor con las tres variables obligatorias y comprobar que
      `/v3/api-docs` responde `200`, que `id` no es `0` y que la imagen no tiene fuentes, `pom.xml` ni `.env`
      (escenarios 13 y 14 de `{spec}/quickstart.md`)
  - Resultado: `api-docs` 200; usuario 10001; en `/app` solo `app.jar`, sin fuentes, `.env` ni herramientas.
- [X] T007 [P] Crear `{front}/.dockerignore` por lista de permitidos: `package.json`, `package-lock.json`,
      `angular.json`, `tsconfig*.json`, `public`, `src` y `nginx` (research R3)
- [X] T008 [P] Crear `{front}/nginx/default.conf.template` según `{spec}/contracts/web-server.md` y research R4 a R7:
      `map` sobre `$request_uri`; `listen 8080`; `absolute_redirect off`; `resolver ${NGINX_LOCAL_RESOLVERS} valid=10s`; en `location /api/`,
      `proxy_pass` solo con variables (`${API_URL}` y la ruta del `map`), `404` si el `map` no da ruta,
      `proxy_http_version 1.1`, `proxy_set_header Host $http_host` y `proxy_redirect off`; en `location /`,
      `try_files $uri /index.html`
- [X] T009 Crear `{front}/Dockerfile` multietapa según research R1: `npm ci` con caché y `npm run build`; imagen final
      con `dist/quipux-playlist-frontend/browser` en `/usr/share/nginx/html`, la plantilla en `/etc/nginx/templates/`,
      `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` y `API_URL` (`data-model.md` `API_URL`), sin usuario `root`
- [X] T010 `docker build {front}`; arrancar el contenedor solo y comprobar que sigue en marcha sin API, que `/` y
      `/playlists/detail?name=x` entregan `index.html`, que `/api/genres` da `502`, que `nginx -T` muestra la dirección
      pasada con `-e API_URL` (escenario 15) y los escenarios 13 y 14
  - Resultado: Arranca sin API; `/` y el detalle 200, `/api/genres` 502, `API_URL` aplicada; usuario 101, sin fuentes.

**Checkpoint**: las dos imágenes se construyen y arrancan por separado.

## Phase 3: User Story 1 - Levantar la aplicación con un comando (P1) 🎯 MVP

**Goal**: `docker compose up` deja la web y la API utilizables.

**Independent Test**: preparar `.env`, `docker compose up`, abrir la web e iniciar sesión.

- [X] T011 [US1] Crear `{infra}/compose/compose.yaml` según `{spec}/contracts/compose.md`: `name: quipux-playlist`;
      `api` y `web` con `build` hacia `../../quipux-playlist-backend` y `../../quipux-playlist-frontend`, sin `image`;
      puertos de `data-model.md` (Servicios) en `127.0.0.1`; variables de `data-model.md` `JWT_SECRET`,
      `DEMO_USER_PASSWORD` y `DEMO_ADMIN_PASSWORD` con `${NOMBRE:?mensaje}`, y `SPOTIFY_CLIENT_ID`,
      `SPOTIFY_CLIENT_SECRET`, `JWT_TTL`, `SPOTIFY_ACCOUNTS_BASE_URL`, `SPOTIFY_API_BASE_URL` y `SPOTIFY_TIMEOUT` sin
      valor (research R9); `WEB_PORT` y `API_PORT` en la publicación; salud de `api` con `nc -z 127.0.0.1 8080`
      (intervalo 3 s, espera 2 s, 5 reintentos, `start_period` 60 s) y `web` con `depends_on` de `api` sana
- [X] T012 [P] [US1] Crear `{infra}/compose/.env.example` solo con las variables marcadas en la columna
      "En `.env.example`" de `data-model.md`, todas vacías
- [X] T013 [US1] Ejecutar el escenario 1 de `{spec}/quickstart.md` con cada obligatoria vacía y ausente; y con un
      `JWT_SECRET` de menos de 32 bytes, comprobar que `api` termina con el motivo, sin mostrar el valor, y que `web`
      no arranca
  - Resultado: Cada obligatoria, vacía o ausente, detiene el arranque y la nombra. Con clave corta `api` sale, `web` queda
    creada sin arrancar y el valor no aparece en los registros.
- [X] T014 [US1] Ejecutar los escenarios 2, 3 y 16 de `{spec}/quickstart.md` y comprobar que `http://localhost:4200` y
      `http://localhost:8080` responden con `curl`, con Node y en el navegador (research R11); ajustar
      `{infra}/compose/compose.yaml` si alguno falla
  - Resultado: Construcción sin caché de capas 71 s; arranque 7 s (SC-005); puertos 4300 y 8180 correctos; `localhost`
    responde a `curl`, Node y Edge.
- [X] T015 [US1] En el navegador, escenarios 4 y 5 de `{spec}/quickstart.md`, Swagger UI en el puerto de la API y
      `docker compose down` seguido de `up`: base vacía y los dos usuarios disponibles
  - Resultado: Edge sin ventana, 13 comprobaciones correctas (escenarios 4 y 5, Swagger UI con 6 operaciones). Tras `down`
    y `up`, lista vacía y los dos usuarios.

**Checkpoint**: la aplicación se usa desde el navegador con un solo comando.

## Phase 4: User Story 2 - Usar la web como único punto de entrada (P1)

**Goal**: bajo `/api`, la web responde igual que la API.

**Independent Test**: repetir las operaciones a través de `http://localhost:4200/api` y compararlas con las directas.

Si una tarea falla, se corrige `{front}/nginx/default.conf.template` y se reconstruye con `docker compose up --build`.

- [X] T016 [US2] Escenario 6 de `{spec}/quickstart.md` desde la web y con `curl`, con nombres con espacios, acentos,
      `;` y `%`; comprobar en los registros de `web` o `api` que la ruta llega sin recodificar y que `Location` es la
      de la API (research R4)
  - Resultado: Correcto desde Edge y con `curl`; `Location` sin `/api`.
- [X] T017 [US2] Provocar `400`, `401`, `403`, `404` y `409` directamente y bajo `/api`, y comparar código, cuerpo y
      cabeceras de `{spec}/contracts/web-server.md`; incluir un `POST` con la cabecera `Origin` de la web
  - Resultado: `400`, `401`, `403`, `404` y `409` con código, cuerpo y cabeceras iguales (sin contar fecha ni conexión).
- [X] T018 [US2] Escenario 8 de `{spec}/quickstart.md`. Si con 500 KB llega `502`, fijar `client_max_body_size 256k` en
      `{front}/nginx/default.conf.template` y actualizar research R7 y `{spec}/contracts/web-server.md`
  - Resultado: 500 KB y 2 MB dan `413`; no hizo falta cambiar el límite.
- [X] T019 [US2] Escenario 9 de `{spec}/quickstart.md` (research R5); después, cambiar `JWT_SECRET`, recrear `api` y
      comprobar que la web, con la sesión anterior, redirige al inicio de sesión
  - Resultado: La web responde tras reiniciar `api` sin recrearse; con otra clave redirige al login.
- [X] T020 [US2] Escenario 7 de `{spec}/quickstart.md`: `newman` contra `http://localhost:8080` y contra
      `http://localhost:4200/api`, ambos al 100 % (SC-003)
  - Resultado: 18 peticiones y 21 comprobaciones sin fallos en los dos puertos.

**Checkpoint**: US1 y US2 completas; la entrega mínima funciona.

## Phase 5: User Story 3 - Sustituir Spotify por un simulador (P2)

**Goal**: géneros con origen `SPOTIFY` sin cuenta ni conexión.

**Independent Test**: arrancar con `compose.wiremock.yaml` y sin credenciales, y consultar `GET /genres`.

- [X] T021 [P] [US3] Crear `{infra}/compose/wiremock/mappings/spotify-token.json` según `data-model.md` (Respuestas
      simuladas), con `basicAuthCredentials`, `access_token` `simulado`, `token_type` `bearer`, `expires_in` `3600` y
      `Content-Type: application/json`
- [X] T022 [P] [US3] Crear `{infra}/compose/wiremock/mappings/spotify-genre-seeds.json` según `data-model.md`
      (Respuestas simuladas): exige `Authorization: Bearer simulado` y devuelve el catálogo indicado
- [X] T023 [US3] Crear `{infra}/compose/compose.wiremock.yaml` según research R10: servicio `wiremock`
      (`wiremock/wiremock:3.13.2`) sin puertos, con las respuestas montadas en solo lectura en
      `/home/wiremock/mappings`, con la comprobación de salud que ya trae la imagen; en `api`, las dos
      direcciones a `http://wiremock:8080`, `SPOTIFY_CLIENT_ID` y `SPOTIFY_CLIENT_SECRET` a `simulado` y
      `depends_on` de `wiremock` sano
- [X] T024 [US3] Escenarios 10, 11 y 12 de `{spec}/quickstart.md`; además, crear una lista con `salsa` (`201`) y con
      `metal` (`400`)
  - Resultado: Origen `SPOTIFY` con 4 géneros; `salsa` 201 y `metal` 400; sin el archivo, `LOCAL` y sin `wiremock`; con
    credenciales ajenas en `.env`, el simulador no las recibe.

**Checkpoint**: las tres historias funcionan.

## Phase 6: Polish

- [X] T025 [P] Escribir `{infra}/README.md` (FR-016): requisitos, carpetas hermanas, preparación de `.env` y cómo
      generar `JWT_SECRET`, variables de `data-model.md`, comandos y direcciones de `{spec}/contracts/compose.md`,
      comillas simples para valores con `$`, WireMock, errores frecuentes y aviso de no exponerlo en una red pública;
      quitar "En construcción" solo para Compose
- [X] T026 [P] Actualizar `{back}/README.md` (FR-017): sección de Docker que remite a infra y tabla de repositorios sin
      "aún pendiente" para Compose; Kubernetes y Argo CD siguen pendientes
- [X] T027 [P] Actualizar `{front}/README.md` (FR-017): imagen, `API_URL` y enlace a las instrucciones de infra
- [X] T028 [P] Anotar en `{back}/docs/adr/0001-arquitectura-api-listas-reproduccion.md`, sección 7, la concreción de
      HU-07: Redis y Kafka llegan con HU-10 y HU-11, WireMock con un segundo archivo y puertos solo en la máquina local
- [X] T029 Generar `{spec}/requests.http` con casos de US2 sobre `baseUrl` `http://localhost:4200/api`, sin secretos, y
      ejecutarlo contra la composición
  - Resultado: 12 peticiones, sin fallos en dos ejecuciones.
- [X] T030 Copiar los tres repositorios sin `target/`, `node_modules/`, `dist/` ni `.env` a una carpeta temporal,
      seguir solo `{infra}/README.md` hasta iniciar sesión y corregir lo que falte; anotar en `{spec}/quickstart.md` el
      resultado y dejar el tiempo de una persona ajena (SC-001) como pendiente de quien evalúe
  - Resultado: Copias limpias, con LF y con los CRLF de un clon en Windows: arranca y se inicia sesión (incluida una
    contraseña con `$`). Se añadió al README el mensaje de puerto ocupado de Docker Desktop. SC-001 queda
    pendiente de quien evalúe.
- [X] T031 Ejecutar el escenario 17 de `{spec}/quickstart.md`, buscar secretos en los tres repositorios y en las
      imágenes (SC-004) y confirmar con `git diff origin/main --stat` en `{back}` y `{front}` que no cambió código de
      la aplicación (FR-018); terminar con `docker compose down --remove-orphans`
  - Resultado: `mvn verify` en verde con cobertura cumplida; 106 pruebas del frontend; sin secretos reales (solo la credencial
    ficticia `simulado`); ningún archivo de la aplicación cambió.
- [X] T032 Marcar en `{back}/docs/backlog.md` los criterios de HU-07 que hayan quedado comprobados (SC-007)
  - Resultado: Los cuatro criterios de HU-07 marcados.
- [X] T033 Buscar comentarios de revisión en los archivos tocados y, si hay, registrarlos en `{spec}/code-review.md`; y
      entregar la lista de propiedades nuevas con valor de ejemplo
  - Resultado: Sin comentarios de revisión, así que no se crea `code-review.md`. Variables nuevas: `API_URL`, `WEB_PORT` y
    `API_PORT`.

## Dependencies

- Setup → Foundational → US1 → US2 y US3 → Polish.
- Backend (T004 a T006) y frontend (T007 a T010) son independientes entre sí.
- US2 y US3 necesitan la composición de US1 y no dependen entre sí.
- T029 a T032 necesitan las tres historias terminadas.

## Parallel Opportunities

- Foundational: la imagen del backend y la del frontend.
- US1: T012 junto a T011.
- US3: T021 y T022.
- Polish: T025 a T028, en archivos distintos.

## Implementation Strategy

**MVP**: Setup, Foundational y US1. US2 confirma que la web se comporta como la API y US3 se añade con un archivo
aparte. La historia no se entrega a medias: se cierra con las tres y Polish.
