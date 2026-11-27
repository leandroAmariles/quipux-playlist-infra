# quipux-playlist-infra

Infraestructura del proyecto de listas de reproducción. Hoy permite levantar la aplicación completa con Docker Compose.
Kubernetes (Kustomize) y Argo CD están **pendientes**.

La documentación del proyecto está en [quipux-playlist-backend](https://github.com/leandroAmariles/quipux-playlist-backend).
La especificación de la composición está en [`specs/07-docker-compose/`](specs/07-docker-compose/).

## Requisitos

- Git
- Docker con Compose, con el motor en marcha
- Acceso a internet la primera vez, para descargar las imágenes base y las dependencias

No hace falta instalar Java, Maven ni Node.

## Carpetas

La composición construye las imágenes desde el código, así que los tres repositorios van como carpetas hermanas y con
sus nombres originales:

```bash
git clone https://github.com/leandroAmariles/quipux-playlist-backend.git
git clone https://github.com/leandroAmariles/quipux-playlist-frontend.git
git clone https://github.com/leandroAmariles/quipux-playlist-infra.git
cd quipux-playlist-infra/compose
```

Todos los comandos siguientes se ejecutan desde `quipux-playlist-infra/compose`.

## Preparación

Copia la plantilla (`cp .env.example .env`, o `Copy-Item .env.example .env` en PowerShell) y rellena en `.env` las tres
variables obligatorias. No hay valores por defecto para que no haya secretos en el repositorio. `.env` no se versiona.

| Variable | Regla |
|---|---|
| `JWT_SECRET` | clave que firma los tokens, de 32 bytes como mínimo |
| `DEMO_USER_PASSWORD` | contraseña que eliges para el usuario `user`, de 1 a 72 bytes |
| `DEMO_ADMIN_PASSWORD` | contraseña que eliges para el usuario `admin`, de 1 a 72 bytes |

Para generar `JWT_SECRET`:

```bash
openssl rand -base64 48
```

En PowerShell:

```powershell
$b = New-Object byte[] 48; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b)
```

Si un valor contiene `$`, escríbelo entre comillas simples: `DEMO_USER_PASSWORD='ab$cd'`.

Las variables que ya estén definidas en tu terminal tienen prioridad sobre `.env`. Si antes arrancaste la API sin Docker,
usa una terminal nueva.

## Arrancar

```bash
docker compose up
```

La primera vez construye las imágenes y tarda unos minutos. La web arranca cuando la API está lista.

| Qué | Dirección |
|---|---|
| Aplicación web | <http://localhost:4200> |
| API | <http://localhost:8080> |
| Swagger UI | <http://localhost:8080/swagger-ui.html> |
| API a través de la web | <http://localhost:4200/api> |

Entra en la web con `admin` (consulta, crea y borra) o con `user` (solo consulta) y la contraseña que elegiste. La
colección de Postman y sus instrucciones están en el repositorio de backend.

Los puertos solo se abren en tu equipo (`127.0.0.1`). No hay HTTPS ni límite de intentos de inicio de sesión: la
aplicación no debe exponerse en una red pública.

## Otros comandos

| Para | Comando |
|---|---|
| Arrancar en segundo plano y esperar | `docker compose up -d --wait` |
| Ver los registros | `docker compose logs -f` |
| Reconstruir tras cambiar el código | `docker compose up --build` |
| Detener | `docker compose down` |

La base de datos está en memoria: las listas se pierden al detener o reiniciar la API.

## Simular Spotify con WireMock

Contra el Spotify real los géneros salen de una lista local (`origen: LOCAL`), por la limitación que explica el
repositorio de backend. Para ver el origen `SPOTIFY` sin cuenta ni credenciales, añade el segundo archivo:

```bash
docker compose -f compose.yaml -f compose.wiremock.yaml up
```

`GET /genres` devuelve entonces `acoustic`, `pop`, `rock` y `salsa`. Las credenciales de Spotify que tengas en `.env` no
se usan. Las respuestas simuladas están en [`compose/wiremock/mappings/`](compose/wiremock/mappings/).

Para detenerlo, usa los mismos archivos:

```bash
docker compose -f compose.yaml -f compose.wiremock.yaml down
```

## Variables opcionales

| Variable | Por defecto | Para qué |
|---|---|---|
| `WEB_PORT` | `4200` | puerto de la web en tu equipo |
| `API_PORT` | `8080` | puerto de la API en tu equipo |
| `JWT_TTL` | `30m` | vigencia del token |
| `SPOTIFY_CLIENT_ID` | — | credencial de Spotify |
| `SPOTIFY_CLIENT_SECRET` | — | credencial de Spotify |
| `SPOTIFY_ACCOUNTS_BASE_URL` | `https://accounts.spotify.com` | dirección donde se pide el token |
| `SPOTIFY_API_BASE_URL` | `https://api.spotify.com` | dirección donde se consultan los géneros |
| `SPOTIFY_TIMEOUT` | `3s` | tiempo máximo para obtener los géneros |

Escríbelas en `.env` solo si quieres cambiarlas: una variable vacía sustituye al valor por defecto. Con WireMock, las
cuatro de credenciales y direcciones de Spotify quedan fijadas.

## Si algo falla

| Síntoma | Causa y solución |
|---|---|
| `required variable ... is missing a value` | falta esa variable en `.env` |
| `dependency api failed to start` | un valor no es válido; `docker compose logs api` dice cuál, sin mostrarlo |
| La construcción no encuentra una ruta | falta un repositorio hermano o tiene otro nombre |
| `port is already allocated` o `ports are not available` | el puerto está ocupado; cambia `WEB_PORT` o `API_PORT` |
| La web responde `502` | la API se está reiniciando o no está en marcha |
