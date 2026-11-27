# Feature Specification: Docker y Compose

**Feature Branch**: `feature/07-docker-compose`

**Created**: 2026-11-26

**Status**: Draft

**Input**: User description: "HU-07: como evaluador, quiero levantar todo con un comando, para evitar instalaciones manuales." Fuentes, en el repositorio de backend: `docs/backlog.md` (HU-07) y `docs/adr/0001-arquitectura-api-listas-reproduccion.md` (secciones 3, 7, 10 y 12).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Levantar la aplicación con un comando (Priority: P1)

Como evaluador, descargo los tres repositorios, indico mis claves y contraseñas y arranco todo con `docker compose up`, para usar la aplicación sin instalar Java, Maven ni Node.

**Why this priority**: Es el objetivo de la historia. Sin este arranque no hay nada que probar.

**Independent Test**: En un equipo con solo Git y Docker, clonar los tres repositorios en carpetas hermanas, preparar la configuración siguiendo el README de infra, ejecutar `docker compose up`, abrir la web e iniciar sesión.

**Acceptance Scenarios**:

1. **Given** los tres repositorios en carpetas hermanas y la configuración preparada, **When** ejecuta `docker compose up` por primera vez, **Then** se construyen las imágenes de backend y frontend desde esas carpetas y arrancan los dos servicios, sin descargar imágenes propias de un registro ni compilar nada fuera de Docker.
2. **Given** la aplicación levantada, **When** abre la web en el navegador, **Then** inicia sesión como `admin` y crea, consulta y borra una lista, eligiendo el género del catálogo.
3. **Given** la aplicación levantada, **When** inicia sesión como `user`, **Then** consulta las listas y no ve las opciones de crear ni borrar.
4. **Given** la aplicación levantada, **When** recarga el navegador o abre directamente la dirección del detalle de una lista, **Then** la web carga esa pantalla, o la de inicio de sesión si no hay sesión, y no una página de error.
5. **Given** la aplicación levantada, **When** usa la colección de Postman o la documentación interactiva contra la API, **Then** funcionan igual que sin Docker.
6. **Given** que falta una de las variables obligatorias, **When** ejecuta `docker compose up`, **Then** el arranque se detiene con un mensaje que nombra la variable que falta.
7. **Given** la aplicación levantada, **When** ejecuta `docker compose down` y vuelve a levantarla, **Then** funciona de nuevo, con la base de datos vacía y los usuarios de demostración.

---

### User Story 2 - Usar la web como único punto de entrada (Priority: P1)

Como evaluador, la web del contenedor llega a la API por su propia dirección, para no configurar CORS ni direcciones a mano.

**Why this priority**: Es un criterio de la historia (nginx redirige las llamadas a la API) y sin él la web levantada no sirve.

**Independent Test**: Con la aplicación levantada, repetir las operaciones de la API a través de la dirección de la web, bajo `/api`, y comparar las respuestas con las de la API directa.

**Acceptance Scenarios**:

1. **Given** la aplicación levantada, **When** la web llama a una ruta bajo `/api`, **Then** el servidor web la reenvía a la misma ruta de la API sin ese prefijo, con su método, cuerpo y token.
2. **Given** una lista cuyo nombre tiene espacios, acentos, `;` o `%`, **When** la crea, consulta y borra desde la web, **Then** las tres operaciones actúan sobre esa lista.
3. **Given** una petición que la API rechaza (`400`, `401`, `403`, `404` o `409`), **When** se hace a través de la web, **Then** llegan el mismo código y el mismo cuerpo de error que al llamar a la API directamente.
4. **Given** una sesión vencida, **When** la web recibe `401`, **Then** redirige al inicio de sesión, como en desarrollo.

---

### User Story 3 - Sustituir Spotify por un simulador (Priority: P2)

Como evaluador, activo opcionalmente WireMock en lugar de Spotify, para ver los géneros con origen `SPOTIFY` sin credenciales ni cuenta.

**Why this priority**: Es un criterio de la historia, pero la aplicación ya es usable sin él gracias a la lista local.

**Independent Test**: Levantar la aplicación con la opción de WireMock activada y sin credenciales de Spotify, y consultar los géneros.

**Acceptance Scenarios**:

1. **Given** la configuración sin credenciales de Spotify, **When** levanta la aplicación con WireMock activado y consulta los géneros, **Then** recibe los géneros del simulador con origen `SPOTIFY`.
2. **Given** WireMock activado, **When** crea una lista con un género del simulador, **Then** se guarda; y con un género que no está en ese catálogo recibe `400`.
3. **Given** WireMock sin activar y sin credenciales de Spotify, **When** levanta la aplicación y consulta los géneros, **Then** no se arranca el simulador y recibe la lista local con origen `LOCAL`.
4. **Given** WireMock activado y credenciales reales de Spotify en la configuración, **When** la aplicación pide los géneros, **Then** consulta al simulador y las credenciales reales no se le envían.

---

### Edge Cases

- **Repositorios mal ubicados o con otro nombre**: la construcción falla; el README de infra indica la disposición de carpetas esperada.
- **Puerto ocupado**: los puertos de la web y de la API en el equipo se pueden cambiar sin editar el `docker-compose`.
- **La web arranca antes que la API**: el arranque no deja el servidor web detenido; en cuanto la API responde, la web funciona sin reiniciar nada.
- **API reiniciada**: la web sigue llegando a ella sin reiniciar el servidor web, aunque su dirección interna cambie. La sesión anterior sigue sirviendo mientras la clave de firma no cambie y el token no haya vencido; las listas se pierden.
- **Configuración no válida** (clave de firma de menos de 32 bytes o contraseña fuera de 1 a 72 bytes): la API no arranca y el motivo queda en los registros del contenedor, sin mostrar el valor.
- **Cambio en el código**: el README indica cómo reconstruir las imágenes, porque `docker compose up` reutiliza las ya construidas.
- **Restos locales en las carpetas hermanas** (`target/`, `node_modules/`, `dist/`, `.env`): no se copian a las imágenes ni cambian el resultado de la construcción.
- **Cuerpo de petición demasiado grande**: a través de la web también se rechaza con `413`.
- **Spotify real sin salida a internet o con error**: se usa la lista local, como sin Docker.

## Requirements *(mandatory)*

### Functional Requirements

**Imágenes**

- **FR-001**: Los repositorios de backend y frontend tienen cada uno un Dockerfile multietapa: una etapa construye la aplicación desde el código fuente y la imagen final contiene solo lo necesario para ejecutarla.
- **FR-002**: La imagen final del frontend sirve la web compilada con nginx.
- **FR-003**: Las imágenes finales no ejecutan la aplicación como usuario administrador y no contienen código fuente, herramientas de construcción, claves, contraseñas ni credenciales.
- **FR-004**: Las versiones de las imágenes base son explícitas, sin etiquetas móviles como `latest`.

**Redirección y web**

- **FR-005**: nginx reenvía las peticiones bajo `/api` a la API quitando el prefijo, igual que el proxy de desarrollo, sin alterar la codificación de la ruta, las cabeceras de autorización, los códigos ni los cuerpos de respuesta.
- **FR-006**: nginx entrega la aplicación web para cualquier ruta propia de la web, de modo que recargar o abrir un enlace directo funciona.
- **FR-007**: La dirección de la API que usa nginx se puede configurar al arrancar el contenedor, sin reconstruir la imagen.

**Compose**

- **FR-008**: El `docker-compose` está en el repositorio de infra, en `compose/`, y construye las imágenes desde las carpetas hermanas `quipux-playlist-backend` y `quipux-playlist-frontend`.
- **FR-009**: `docker compose up` deja la aplicación usable: web y API accesibles desde el equipo, sin pasos posteriores. Por defecto la web queda en el puerto 4200 y la API en el 8080, y ambos se pueden cambiar.
- **FR-010**: Las claves, contraseñas y credenciales se toman del entorno o de un archivo `.env` que no se versiona. El repositorio de infra incluye un `.env.example` sin valores secretos.
- **FR-011**: `JWT_SECRET`, `DEMO_USER_PASSWORD` y `DEMO_ADMIN_PASSWORD` son obligatorias y sin valor por defecto; si falta una, el arranque se detiene nombrándola.
- **FR-012**: Las demás variables que ya admite la API (vigencia del token y las de Spotify) se pueden definir en la misma configuración y, si se omiten, conservan su valor por defecto.

**WireMock**

- **FR-013**: WireMock es opcional, está desactivado por defecto y se activa sin editar archivos versionados.
- **FR-014**: Sus respuestas de token y de géneros están versionadas en el repositorio de infra y no requieren configuración manual.
- **FR-015**: Al activarlo, la API apunta sus dos direcciones de Spotify al simulador con credenciales ficticias; las reales no se usan.

**Documentación**

- **FR-016**: El README de infra explica los requisitos, la disposición de carpetas, las variables, cómo arrancar, detener, reconstruir y activar WireMock, y las direcciones de la web y de la API.
- **FR-017**: Los README de backend y frontend remiten a esas instrucciones y dejan de describir Docker como pendiente.

**Restricciones transversales**

- **FR-018**: El comportamiento de la API y de la web no cambia, y ejecutar el proyecto sin Docker sigue funcionando como describen sus README.

### Key Entities *(include if feature involves data)*

- **Imagen del backend**: la API lista para ejecutarse.
- **Imagen del frontend**: la web compilada y el servidor nginx que la entrega y reenvía las llamadas a la API.
- **Composición**: los servicios (web, API y WireMock opcional), sus puertos, su configuración y las carpetas desde las que se construyen.
- **Configuración de entorno**: variables obligatorias y opcionales, con una plantilla sin secretos.
- **Respuestas simuladas**: token y catálogo de géneros que sirve WireMock.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En un equipo con solo Git y Docker, una persona que no conoce el proyecto, siguiendo el README de infra, inicia sesión en la web en menos de 10 minutos, sin contar descargas ni construcción.
- **SC-002**: Después de preparar la configuración, un único comando levanta toda la aplicación, con 0 pasos manuales posteriores.
- **SC-003**: La colección de Postman termina con el 100 % de las comprobaciones en verde contra la API levantada con Compose, tanto directamente como a través de la web.
- **SC-004**: Las imágenes y los tres repositorios contienen 0 claves, contraseñas o credenciales reales.
- **SC-005**: Con las imágenes ya construidas, la aplicación queda usable en menos de 60 segundos desde el comando.
- **SC-006**: Con WireMock activado, `GET /genres` responde con origen `SPOTIFY` sin ninguna conexión a Spotify.
- **SC-007**: Todos los criterios de aceptación de HU-07 en el backlog quedan comprobados, por prueba automática o por revisión anotada.
- **SC-008**: La verificación del backend y las pruebas del frontend siguen pasando.

## Assumptions

- **Ubicación de la historia** (decidida el 2026-11-26): la especificación, el plan y las tareas viven en el repositorio de infra. Los cambios de backend y frontend van en ramas `feature/07-docker-compose` de cada repositorio.
- **Redis y Kafka** (decidido el 2026-11-26): no entran en HU-07. Aunque el ADR-0001 (sección 7) los incluye en el `docker-compose`, cada uno se añade en su historia (HU-10 y HU-11), cuando la aplicación lo use. La precisión se anota en el ADR al implementar.
- **"Un comando"**: la configuración de las tres variables obligatorias se hace una vez antes. No se generan ni se entregan contraseñas por defecto, porque no puede haber secretos en el repositorio.
- **Requisitos del evaluador**: Git para clonar, Docker con Compose y acceso a internet la primera vez, para descargar imágenes base y dependencias.
- **API publicada en el equipo**: además de la web, la API es accesible directamente para usar Postman y la documentación interactiva.
- **Uso local**: sin HTTPS. La aplicación sigue sin deber exponerse en una red pública.
- **Pruebas en la construcción**: construir las imágenes no ejecuta las pruebas ni los controles de calidad; eso se hace con los comandos de cada repositorio y, desde HU-08, en el CI.
- **Datos**: H2 en memoria; se pierden al detener la API.
- **Fuera de alcance**: CI, análisis de imágenes y publicación en un registro (HU-08), Kubernetes, rutas de salud y Argo CD (HU-09), Redis (HU-10) y Kafka (HU-11).
- **Dependencia**: HU-06 integrada en `main` de backend, y HU-05 en `main` de frontend.
