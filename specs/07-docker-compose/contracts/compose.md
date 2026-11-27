# Contrato: composición

Lo que usa quien evalúa. Servicios y variables en [data-model.md](../data-model.md).

## Archivos

```text
quipux-playlist-infra/compose/
├── compose.yaml            proyecto "quipux-playlist": api y web
├── compose.wiremock.yaml   añade wiremock y apunta api a él
├── .env.example            plantilla; se copia a .env
└── wiremock/mappings/      respuestas simuladas
```

Los tres repositorios van como carpetas hermanas con sus nombres originales.

## Comandos

Desde `quipux-playlist-infra/compose`:

| Para | Comando | Resultado |
|---|---|---|
| Preparar | copiar `.env.example` a `.env` y rellenar las tres obligatorias | — |
| Arrancar | `docker compose up` | construye si no hay imágenes; web y API disponibles |
| Arrancar y esperar | `docker compose up -d --wait` | termina cuando `api` está sana |
| Detener | `docker compose down` | se pierden las listas |
| Reconstruir | `docker compose up --build` | recoge cambios del código |
| Con WireMock | `docker compose -f compose.yaml -f compose.wiremock.yaml up` | géneros con origen `SPOTIFY` |
| Detener con WireMock | `docker compose -f compose.yaml -f compose.wiremock.yaml down` | detiene los tres |

## Direcciones

| Qué | Dirección por defecto |
|---|---|
| Web | <http://localhost:4200> |
| API | <http://localhost:8080> |
| Swagger UI | <http://localhost:8080/swagger-ui.html> |
| API a través de la web | <http://localhost:4200/api> |

## Errores

| Situación | Comportamiento |
|---|---|
| Falta una variable obligatoria o está vacía | Compose no arranca nada y nombra la variable |
| Valor obligatorio no válido | `api` termina con el motivo en sus registros, sin el valor; `web` no arranca |
| Falta una carpeta hermana | la construcción falla indicando la ruta |
| Puerto ocupado | Compose lo indica; se cambia con `WEB_PORT` o `API_PORT` |
