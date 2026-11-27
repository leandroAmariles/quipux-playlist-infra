# Research: Docker y Compose

**Fecha**: 2026-11-26

**Estado del entorno**: Docker 29.6.1 y Compose 5.3.0. Lo marcado como **comprobado** se probó con una composición
temporal (JAR de HU-06, nginx y WireMock) fuera de los repositorios, o consultando Docker Hub. Las imágenes propias
todavía no existen.

## R1. Imágenes base

**Decisión**:

| Uso | Imagen |
|---|---|
| Construir el backend | `maven:3.9.11-eclipse-temurin-21` |
| Ejecutar el backend | `eclipse-temurin:21.0.13.1_2-jre-alpine-3.23` |
| Construir el frontend | `node:22.22.3-alpine` |
| Ejecutar el frontend | `nginxinc/nginx-unprivileged:1.30.6-alpine` |
| Simulador | `wiremock/wiremock:3.13.2` |

**Motivo**: etiquetas con versión (FR-004). Maven 3.9.11 es la del wrapper, Node 22.22.3 la local y WireMock 3.13.2 la
de las pruebas. La imagen de nginx sin privilegios cumple FR-003 sin ajustes. Las cinco etiquetas existen en Docker
Hub (**comprobado**).

**Alternativas**: usar `mvnw` dentro de la imagen (descarga Maven en cada construcción sin caché); imágenes jlink o
distroless (más trabajo sin requisito que lo pida); fijar por digest (lo puede proponer Dependabot en HU-08).

## R2. Construcción del backend

**Decisión**: dos etapas. `mvn -B -ntp package -Dmaven.test.skip=true -Dcheckstyle.skip=true -Djacoco.skip=true`, con
caché de BuildKit para el repositorio de Maven. La imagen final copia solo el JAR de `bootstrap`
(`playlist-bootstrap-*.jar`, para no depender de la versión) y se ejecuta con el usuario `10001`.

**Motivo**: la construcción no ejecuta pruebas ni controles (supuesto de la spec).

**Alternativa**: capas del JAR de Spring Boot; acelera subidas a un registro que aquí no existe.

## R3. Contexto de construcción

**Decisión**: `.dockerignore` por lista de permitidos en backend (los `pom.xml` y `src` de cada módulo) y en frontend
(`package.json`, `package-lock.json`, `angular.json`, `tsconfig*.json`, `public`, `src`, `nginx`).

**Motivo**: `target/`, `node_modules/`, `.env` y cualquier archivo nuevo quedan fuera sin acordarse de excluirlos.

## R4. Reenvío de `/api` sin alterar la ruta

**Decisión**: un `map` toma de `$request_uri` (la ruta tal como llegó) lo que sigue a `/api`, y `proxy_pass` lo usa con
una variable. `proxy_set_header Host $http_host`, `proxy_redirect off`.

La redirección de `/api` a `/api/` que añade nginx apuntaba al puerto del contenedor; se corrige con
`absolute_redirect off`.

**Motivo**: `proxy_pass http://api:8080/;` reenvía la ruta ya descodificada y vuelta a codificar, y cambia nombres con
`;` o `%`. `$http_host` conserva el puerto: con otro `Host`, el `Origin` del navegador haría la petición de otro origen.

**Comprobado**: un nombre con espacios, `;`, `%` y `ñ` se crea, consulta y borra a través de nginx; `Location`, códigos,
cuerpos y `WWW-Authenticate` de `400`, `401`, `403`, `404` y `409` son iguales que en la API. Un `;` sin codificar da
`404` en ambos. `newman` termina con 18 peticiones y 21 comprobaciones sin fallos en los dos puertos.

## R5. La web arranca antes que la API o la API cambia de dirección

**Decisión**: `resolver` con los DNS del contenedor (`NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1`) y `valid=10s`; al usar
variables en `proxy_pass`, nginx resuelve el nombre en cada periodo y arranca aunque `api` no exista aún.

**Motivo**: sin variables, nginx resuelve una vez al arrancar y falla si no encuentra el nombre.

**Comprobado**: con la API detenida la web da `502`; tras recrearla con otra IP responde al primer intento. La web
sola, sin `api`, arranca.

## R6. Dirección de la API configurable

**Decisión**: plantilla en `/etc/nginx/templates/` con `API_URL` (por defecto `http://api:8080`), que la imagen oficial
sustituye al arrancar. Solo sustituye variables de entorno definidas, así que las de nginx no se tocan.

## R7. Tamaño del cuerpo

**Decisión**: se deja el límite de nginx (1 MB), mayor que el de la API (256 KB). Entre ambos responde la API con su
`ProblemDetail`; por encima responde nginx con `413`.

**Comprobado**: con 500 KB llega el `413` de la API y con 2 MB el de nginx, en HTML. Ningún `502`.

## R8. Cuándo está usable la aplicación

**Decisión**: comprobación de salud de `api` por puerto (`nc -z 127.0.0.1 8080`) y `web` depende de `api` sana.

**Comprobado**: la imagen JRE trae `nc`; la composición queda sana en unos 14 s, y con una clave corta `api` termina
con el motivo, sin el valor, y `web` no arranca.

**Motivo**: los usuarios de demostración se crean antes de abrir el puerto (`SmartInitializingSingleton`), así que el
puerto abierto significa que se puede iniciar sesión. Las rutas de salud son de HU-09.

**Alternativa**: consultar `/v3/api-docs`; genera el contrato solo para saber si hay servidor.

## R9. Variables obligatorias y opcionales

**Decisión**: obligatorias como `${NOMBRE:?mensaje}`. Las opcionales de la API se declaran sin valor (`- JWT_TTL`).

**Motivo** (**comprobado**, Compose 5.3.0):

- `:?` detiene el arranque si la variable falta o está vacía y la nombra (FR-011).
- Una variable declarada sin valor toma el de `.env` y, si no está, no llega al contenedor: Spring usa su valor por
  defecto (FR-012). `${NOMBRE:-}` entregaría una cadena vacía, que Spring no sustituye.
- Una contraseña con `$` se conserva si va entre comillas simples en `.env`.

## R10. Activar WireMock

**Decisión**: segundo archivo, `compose.wiremock.yaml`, que añade el servicio y fija en `api` las dos direcciones y las
credenciales `simulado`. Se activa con `docker compose -f compose.yaml -f compose.wiremock.yaml up`.

**Motivo**: cumple FR-013 y FR-015 sin editar nada; los valores del segundo archivo sustituyen a los de `.env`
(**comprobado**). El stub del token exige esas credenciales, así que enviar las reales daría origen `LOCAL`.

**Alternativa**: un perfil de Compose añade el servicio pero no cambia las variables de `api`; obligaría a editar `.env`.

**Comprobado**: la imagen de WireMock ya declara su comprobación de salud, así que la composición no define otra. Con
credenciales distintas en `.env`, `GET /genres` responde `origen: SPOTIFY`.

## R11. Puertos publicados

**Decisión**: `127.0.0.1:${WEB_PORT:-4200}` y `127.0.0.1:${API_PORT:-8080}`. WireMock no publica puerto.

**Motivo**: la aplicación no debe exponerse en una red pública (README del backend).

**Comprobado**: `localhost` responde a `curl`, Node y `newman` (`[::1]` no, como se espera). **Por comprobar**: el
navegador.
