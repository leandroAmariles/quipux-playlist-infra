# Implementation Plan: Docker y Compose

**Branch**: `feature/07-docker-compose` | **Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `quipux-playlist-infra/specs/07-docker-compose/spec.md`

## Summary

Un Dockerfile multietapa en backend y frontend, y una composición en infra que los construye desde las carpetas
hermanas. nginx entrega la web y reenvía `/api` sin tocar la codificación de la ruta. Un segundo archivo de Compose
activa WireMock. No cambia código de la aplicación. Detalle en [research.md](research.md).

## Technical Context

**Language/Version**: Dockerfile, Compose y configuración de nginx. La aplicación sigue en Java 21 y Angular 22

**Primary Dependencies**: Docker con BuildKit y Compose. Imágenes base en [research.md](research.md), R1

**Storage**: H2 en memoria, sin cambios

**Testing**: `docker compose config`, escenarios de [quickstart.md](quickstart.md), `newman` 6.2.3; `mvn verify` y
`npm test` sin cambios

**Target Platform**: contenedores Linux sobre Docker en Windows, macOS o Linux

**Project Type**: web application (tres repositorios)

**Performance Goals**: aplicación usable en menos de 60 s con las imágenes construidas (SC-005)

**Constraints**: sin secretos en imágenes ni repositorios; imágenes sin usuario administrador y con versión explícita;
sin cambios de comportamiento (FR-018)

**Scale/Scope**: 2 imágenes propias, 3 servicios, 2 archivos de Compose, 1 configuración de nginx, 3 README

## Constitution Check

La constitución sigue sin rellenar. Se usan como puertas el ADR-0001 y las reglas de `CLAUDE.md`.

| Puerta | Antes de Phase 0 | Tras Phase 1 |
|---|---|---|
| Dockerfiles en backend y frontend, compose en infra (ADR, secciones 3 y 7) | Cumple | Cumple |
| nginx en el mismo origen, sin CORS (ADR, sección 12) | Cumple | Cumple (R4) |
| Compose con Redis y Kafka (ADR, sección 7) | Desviación | Justificada abajo |
| Sin secretos en el repositorio | Cumple | Cumple (R3, R9) |
| Sin comentarios explicativos | Cumple | Cumple |
| Arquitectura hexagonal, cobertura y Checkstyle | No aplica: no cambia código | No aplica |

## Project Structure

### Documentation (this feature)

```text
quipux-playlist-infra/specs/07-docker-compose/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/        compose.md, web-server.md
├── requests.http     al terminar la implementación
└── tasks.md          /speckit-tasks
```

### Source Code

Tres repositorios hermanos. `+` nuevo, `~` cambia.

```text
quipux-playlist-backend/
├── Dockerfile                          +
├── .dockerignore                       +
├── README.md                           ~
└── docs/                               ~ backlog.md, adr/0001 (sección 7)

quipux-playlist-frontend/
├── Dockerfile                          +
├── .dockerignore                       +
├── nginx/default.conf.template         +
└── README.md                           ~

quipux-playlist-infra/
├── compose/
│   ├── compose.yaml                    +
│   ├── compose.wiremock.yaml           +
│   ├── .env.example                    +
│   └── wiremock/mappings/              + spotify-token.json, spotify-genre-seeds.json
├── .gitignore                          ~ specs/*/.token-usage.json
└── README.md                           ~
```

**Structure Decision**: cada imagen se define donde está su código, y la composición en infra (ADR, sección 3). La
configuración de nginx es parte de la imagen del frontend.

### Flujo

| Caso | Recorrido |
|---|---|
| Pantalla de la web | navegador → `web` (nginx) → archivo o `index.html` |
| Llamada a la API desde la web | navegador → `web` `/api/...` → `api` |
| Postman y Swagger UI | equipo → `api` |
| Géneros | `api` → Spotify, o `wiremock` con el segundo archivo; si falla, lista local |

### Orden de trabajo

0. Requisito: Docker Desktop en marcha. Ramas `feature/07-docker-compose` en backend y frontend desde `origin/main`.
1. Imagen del backend.
2. Imagen del frontend con nginx.
3. `compose.yaml` y `.env.example`: escenarios 1 a 9 (historias 1 y 2).
4. WireMock: escenarios 10 a 12 (historia 3).
5. README, escenarios restantes y cierre.

### Estrategia de pruebas

No hay código con lógica propia, así que no se añaden pruebas unitarias. Antes de escribir cada pieza se ejecuta su
escenario del quickstart y se ve fallar; después, pasar. R4, R5, R7 y R10 ya se probaron con una composición temporal
(research.md) y se repiten sobre las imágenes reales; de R11 queda el navegador. El resultado de cada escenario se anota en `tasks.md` (SC-007).

### Cierre de la historia

README de los tres repositorios, `docs/backlog.md` (criterios marcados), concreción en el ADR-0001 (sección 7),
`requests.http` con las rutas a través de `/api`, lista de propiedades nuevas y revisión de comentarios para
`code-review.md`. Un commit por repositorio, con ámbito `HU-07`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| La composición no incluye Redis ni Kafka, que el ADR (sección 7) enumera | Decisión del usuario: llegan con HU-10 y HU-11 | Levantarlos ahora deja contenedores sin uso |
| La historia cambia tres repositorios con una sola spec | La composición solo tiene sentido con las dos imágenes | Tres specs reparten una historia que se valida entera |
