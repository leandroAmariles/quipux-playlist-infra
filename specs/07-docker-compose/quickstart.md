# Quickstart: validar Docker y Compose

Contratos en [contracts/](contracts/). Los comandos usan Git Bash.

## Requisitos

- Docker con el motor en marcha (`docker info` responde) y Compose
- Los tres repositorios como carpetas hermanas
- Puertos 4200 y 8080 libres (detener `ng serve` y la API local)
- Node, solo para `newman`

## Preparación

```bash
cd quipux-playlist-infra/compose
cp .env.example .env    # rellenar JWT_SECRET, DEMO_USER_PASSWORD y DEMO_ADMIN_PASSWORD
```

## Escenarios

| # | Comprueba | Pasos | Resultado esperado |
|---|---|---|---|
| 1 | FR-011 | vaciar `JWT_SECRET` y `docker compose up` | no arranca y nombra `JWT_SECRET` |
| 2 | FR-001, FR-009, SC-002 | `docker compose build --no-cache`, `docker compose up -d --wait` | `api` y `web` en marcha |
| 3 | SC-005 | `docker compose down`, `time docker compose up -d --wait` | menos de 60 s |
| 4 | US1 2-3 | en el navegador, como `admin` y como `user` | `admin` crea y borra; `user` solo consulta |
| 5 | US1 4, FR-006 | recargar en el detalle y en `/playlists/new` | carga la pantalla, sin `404` |
| 6 | US2 2 | crear, consultar y borrar `Rock; 100% años` desde la web | las tres actúan sobre esa lista |
| 7 | SC-003 | `newman` contra los puertos 8080 y 4200 (abajo) | 100 % en verde en ambos |
| 8 | R7 | `POST /api/auth/login` con un cuerpo de 500 KB y de 2 MB | `413` en ambos, nunca `502` |
| 9 | R5 | `docker compose restart api` y, tras estar sana, usar la web | funciona sin reiniciar `web` |
| 10 | US3 1-2, SC-006 | arrancar con `compose.wiremock.yaml`, sin credenciales, `GET /genres` | `origen: SPOTIFY` y 4 géneros |
| 11 | US3 3 | arrancar sin él | no hay `wiremock`; `origen: LOCAL` |
| 12 | US3 4, FR-015 | credenciales cualesquiera en `.env` y arrancar con WireMock | sigue `origen: SPOTIFY` |
| 13 | FR-003, SC-004 | `docker image inspect` y `docker run --rm --entrypoint id <imagen>` | usuario distinto de `0`; sin secretos |
| 14 | FR-003 | listar el contenido de las imágenes finales | sin fuentes, `pom.xml`, `node_modules` ni `.env` |
| 15 | FR-007 | arrancar `web` sola con `-e API_URL=http://otra:9999` | la configuración generada usa esa dirección |
| 16 | FR-009 | `WEB_PORT=4300 API_PORT=8180 docker compose up -d --wait` | responden en esos puertos |
| 17 | SC-008 | `./mvnw verify` en backend, `npm test` en frontend | en verde |

```bash
for url in http://localhost:8080 http://localhost:4200/api; do
  npx --yes newman@6.2.3 run ../../quipux-playlist-backend/postman/quipux-playlist.postman_collection.json \
    --env-var baseUrl="$url" \
    --env-var userPassword="<DEMO_USER_PASSWORD>" --env-var adminPassword="<DEMO_ADMIN_PASSWORD>"
done
```

**SC-001** (menos de 10 minutos): seguir solo el README de infra desde tres copias recién clonadas.

**Resultado del 2026-11-27**: desde copias con solo los archivos que irían a Git, sin las imágenes propias y con la
caché de construcción del equipo, los pasos del README llevan a iniciar sesión con `admin` y `user`. La medición del
tiempo con una persona ajena al proyecto y un equipo limpio queda **pendiente de quien evalúe**.

## Limpieza

```bash
docker compose down --remove-orphans
```
