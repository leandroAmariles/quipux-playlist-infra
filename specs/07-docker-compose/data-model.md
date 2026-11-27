# Data Model: Docker y Compose

La historia no añade datos de negocio ni tablas. Lo que modela es la composición y su configuración.

## Servicios

| Servicio | Origen | Puerto interno | Publicado | Depende de |
|---|---|---|---|---|
| `api` | construye `../../quipux-playlist-backend` | 8080 | `127.0.0.1:${API_PORT:-8080}` | `wiremock` sano, solo si está activado |
| `web` | construye `../../quipux-playlist-frontend` | 8080 | `127.0.0.1:${WEB_PORT:-4200}` | `api` sana |
| `wiremock` | `wiremock/wiremock:3.13.2`, opcional | 8080 | no | — |

**Estados de `api`**: arrancando → sana (puerto abierto, usuarios creados). Con configuración no válida termina sin
llegar a sana, y `web` no arranca.

## Variables de la composición

| Variable | Obligatoria | Por defecto | Dónde va | En `.env.example` |
|---|---|---|---|---|
| `JWT_SECRET` | sí | — | `api` | sí, vacía |
| `DEMO_USER_PASSWORD` | sí | — | `api` | sí, vacía |
| `DEMO_ADMIN_PASSWORD` | sí | — | `api` | sí, vacía |
| `SPOTIFY_CLIENT_ID` | no | — | `api` | sí, vacía |
| `SPOTIFY_CLIENT_SECRET` | no | — | `api` | sí, vacía |
| `JWT_TTL` | no | el de la API (`30m`) | `api` | no |
| `SPOTIFY_ACCOUNTS_BASE_URL` | no | el de la API | `api` | no |
| `SPOTIFY_API_BASE_URL` | no | el de la API | `api` | no |
| `SPOTIFY_TIMEOUT` | no | el de la API (`3s`) | `api` | no |
| `WEB_PORT` | no | `4200` | publicación de `web` | no |
| `API_PORT` | no | `8080` | publicación de `api` | no |

**Reglas**:

- Una opcional con valor por defecto no se escribe vacía en `.env.example`: vacía sustituiría al valor por defecto.
- `SERVER_PORT` no se expone: dentro del contenedor la API usa siempre el 8080.
- Con WireMock, las cuatro de Spotify de direcciones y credenciales quedan fijadas por `compose.wiremock.yaml`.

## Variable de la imagen del frontend

| Variable | Por defecto | Regla |
|---|---|---|
| `API_URL` | `http://api:8080` | esquema, nombre y puerto, sin ruta ni `/` final |

## Respuestas simuladas

| Petición | Condición | Respuesta |
|---|---|---|
| `POST /api/token` | autenticación Basic `simulado` / `simulado` | `200` con `access_token`, `token_type`, `expires_in` |
| `GET /v1/recommendations/available-genre-seeds` | `Authorization: Bearer simulado` | `200` con `genres` |

El catálogo simulado es `acoustic`, `pop`, `rock` y `salsa`.
