# Implementation Plan: CI, dependencias y releases

**Branch**: `feature/08-ci-dependencies-releases` | **Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `quipux-playlist-infra/specs/08-ci-dependencies-releases/spec.md`

## Summary

En backend y frontend, un workflow de CI y otro de release que publica la imagen en GHCR; Dependabot y protección de
`main` en los tres repositorios. Antes hay que corregir lo que dejaría el CI o la publicación en rojo: un hallazgo de
Qodana y las dos imágenes base. Detalle en [research.md](research.md).

## Technical Context

**Language/Version**: workflows de GitHub Actions en YAML. La aplicación sigue en Java 21 y Angular 22

**Primary Dependencies**: Qodana `jvm-community` 2026.3, Trivy 0.76.2, `angular-eslint` 22, release-please 17,
Dependabot, GHCR. Versiones y SHA en [research.md](research.md), R9

**Storage**: N/A; las imágenes en GHCR

**Testing**: `./mvnw verify`, `npm test`, `actionlint` 1.7.12 sobre los workflows y escenarios de
[quickstart.md](quickstart.md)

**Target Platform**: runners `ubuntu-24.04`; imágenes `linux/amd64`

**Project Type**: web application (tres repositorios)

**Performance Goals**: CI de un PR en menos de 15 minutos (SC-003); imagen disponible en menos de 15 minutos tras
fusionar la release (SC-005)

**Constraints**: repositorios públicos y plan gratuito; sin secretos en el CI de PR; permisos mínimos; sin cambios de
comportamiento (FR-024)

**Scale/Scope**: 4 workflows, 3 configuraciones de Dependabot, 3 de protección, 1 clase y 2 Dockerfiles modificados,
3 README

## Constitution Check

La constitución sigue sin rellenar. Se usan como puertas el ADR-0001 y las reglas de `CLAUDE.md`.

| Puerta | Antes de Phase 0 | Tras Phase 1 |
|---|---|---|
| Controles por repositorio (ADR, sección 13) | Cumple | Cumple (R2 a R4) |
| Acciones por SHA, permisos mínimos | Cumple | Cumple (R9) |
| release-please con token propio e imagen en el mismo workflow | Cumple | Cumple (R5, R6) |
| Arquitectura hexagonal, cobertura y Checkstyle | Cumple | Cumple: el cambio queda dentro de `application` |
| Sin secretos en el repositorio | Cumple | Cumple |
| Sin comentarios explicativos | Cumple | Cumple: solo la versión junto a cada SHA |
| Imágenes con versión explícita (HU-07, FR-004) | Cumple | Desviación parcial, justificada abajo |
| PR automático en infra (ADR, sección 13) | No aplica: es de HU-09 | No aplica |

## Project Structure

### Documentation (this feature)

```text
quipux-playlist-infra/specs/08-ci-dependencies-releases/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/        ci.md, release.md, repository.md
└── tasks.md          /speckit-tasks
```

No habrá `requests.http`: la historia no añade ni cambia endpoints.

### Source Code

Tres repositorios hermanos. `+` nuevo, `~` cambia.

```text
quipux-playlist-backend/
├── .github/                          + workflows/ci.yml, workflows/release.yml,
│                                       dependabot.yml, branch-protection.json
├── qodana.yaml                       +
├── release-please-config.json        +
├── .release-please-manifest.json     +
├── application/.../LoginUseCase.java ~ hallazgo de Qodana
├── Dockerfile                        ~ base 3.24 y apk upgrade
├── README.md                         ~
└── docs/                             ~ backlog.md, adr/0001 (secciones 7 y 13)

quipux-playlist-frontend/
├── .github/                          + los mismos cuatro archivos
├── eslint.config.js                  +
├── angular.json, package*.json       ~ ESLint
├── release-please-config.json        +
├── .release-please-manifest.json     +
├── Dockerfile                        ~ nginx 1.31.7 y apk upgrade
└── README.md                         ~

quipux-playlist-infra/
├── .github/                          + dependabot.yml, branch-protection.json
└── README.md                         ~
```

**Structure Decision**: cada repositorio lleva sus workflows y ajustes (ADR, sección 3). No se comparten workflows
reutilizables: son dos pilas distintas y compartirlos añade un acoplamiento entre repositorios.

### Flujo

| Caso | Recorrido |
|---|---|
| PR | `ci.yml` → tres comprobaciones → fusión permitida |
| Push a `main` | `ci.yml` y `release.yml` → PR de release abierto o actualizado |
| Fusión del PR de release | `release.yml` → tag y release → construir → Trivy → GHCR |
| Actualización | Dependabot → PR → `ci.yml` |

### Orden de trabajo

0. Ramas `feature/08-ci-dependencies-releases` en backend y frontend desde `origin/main`.
1. **Dejar en verde**: `LoginUseCase`, Dockerfiles, ESLint. `./mvnw verify`, `npm test`, Compose y Trivy en local.
2. **CI** (historias 1 y 2): `ci.yml` y `qodana.yaml`. Primer PR de backend y frontend; escenarios 1 a 10.
3. Fusionar ese PR.
4. **Protección** (historia 3): aplicar en los tres repositorios; escenarios 11 a 13.
5. **Tokens**: la persona responsable crea los dos PAT y sus secretos.
6. **Releases** (historia 4): segundo PR de backend y frontend con su documentación; fusionar la release, hacer
   públicos los paquetes; escenarios 15 a 21.
7. **Dependabot** (historia 5): PR de backend, frontend e infra; escenario 14. Va después para que sus PR no se mezclen
   con la primera release.
8. Cierre, con el escenario 22.

Los pasos 2 a 8 cambian cosas visibles fuera del equipo. Cada push, PR, fusión o ajuste de GitHub se confirma
antes de hacerlo; las fusiones, los tokens y la visibilidad de los paquetes los hace la persona responsable.

### Estrategia de pruebas

No se añade lógica de aplicación, así que no hay pruebas unitarias nuevas. El cambio de `LoginUseCase` lo cubren sus
pruebas actuales, que deben pasar sin modificarse. Cada control se ve fallar con su defecto antes de darlo por bueno
(escenarios 2 a 8). El resultado de cada escenario se anota en `tasks.md` (SC-008).

### Cierre de la historia

README de los tres repositorios, `docs/backlog.md` (criterios marcados), concreción en el ADR-0001 (secciones 7 y 13),
lista de propiedades y secretos nuevos y revisión de comentarios para `code-review.md`. Commits con ámbito `HU-08`.

### Riesgos

| Riesgo | Respuesta |
|---|---|
| Aparece una vulnerabilidad nueva entre el plan y la implementación | actualizar la dependencia o la base; si no hay forma, excepción individual |
| Qodana en CI da hallazgos que no salieron en local | corregir sin cambiar comportamiento antes de exigir la comprobación |
| La prueba de rendimiento (límite de 1 s) es inestable en el runner | medir en el primer PR; cambiar el límite requiere decisión aparte |
| El CI de PR no construye las imágenes | fuera de alcance en la spec; los Dockerfiles se validan con Compose en el paso 1 |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| `apk upgrade` deja sin fijar los paquetes de Alpine | Sin él la imagen web no pasa Trivy y no se puede publicar | Esperar imágenes base nuevas bloquea las releases |
| nginx pasa de la rama estable (1.30) a la principal (1.31) | No hay imagen sin privilegios de 1.30.7 | La imagen oficial 1.30.7 exige rehacer la configuración de usuario |
| La historia cambia tres repositorios con una sola spec | Protección y Dependabot son comunes | Tres specs reparten una historia que se valida entera |
