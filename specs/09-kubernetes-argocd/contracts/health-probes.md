# Contrato: sondas de salud (Backend y Frontend)

## Backend (`quipux-playlist-backend`)

### Dependencia y propiedades

- Dependencia en `infrastructure/pom.xml`: `org.springframework.boot:spring-boot-starter-actuator` (sin versión explícita, gestionada por el parent de Spring Boot `4.1.3`).
- Propiedades en `bootstrap/src/main/resources/application.yml`:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health
  endpoint:
    health:
      probes:
        enabled: true
      show-details: never
```

### Rutas y seguridad (`SecurityConfig`)

| Ruta | Método | Acceso | Respuesta esperada |
|---|---|---|---|
| `/actuator/health/liveness` | `GET` | Público (sin token) | `200 OK`, `{"status":"UP"}` |
| `/actuator/health/readiness` | `GET` | Público (sin token) | `200 OK`, `{"status":"UP"}` |
| `/actuator/health` | `GET` | Protegido (sin `permitAll`) | `401 Unauthorized` (`ProblemDetail`) sin token |
| `/actuator/**` | cualquiera | Protegido (sin `permitAll`) | `401 Unauthorized` (`ProblemDetail`) sin token |

Reglas de implementación:
- Declarar las constantes de ruta en una clase/enum dedicada de `infrastructure/in/rest/` (por ejemplo `HealthPath`) en inglés.
- Añadir en `SecurityConfig` una `SecurityWebFilterChain` con `@Order` anterior a `apiSecurityFilterChain` (patrón análogo a `loginSecurityFilterChain`), usando `ServerWebExchangeMatchers.pathMatchers(HttpMethod.GET, ...)` exclusivamente sobre `/actuator/health/liveness` y `/actuator/health/readiness` con `.anyExchange().permitAll()`.
- No modificar `domain` ni `application` (`ArchitectureTest` debe seguir en verde).
- No exponer Actuator en Swagger/OpenAPI (`springdoc.show-actuator` se mantiene en `false` por defecto para que `OpenApiContractTest` siga pasando sin cambios).
- Todas las llamadas de liveness y readiness deben ser no bloqueantes (`PlaylistNonBlockingTest` con `BlockHound` debe seguir en verde).

## Frontend (`quipux-playlist-frontend`)

| Ruta | Método | Puerto | Acceso | Respuesta esperada |
|---|---|---|---|---|
| `/` | `GET` | `8080` | Público (sin token) | `200 OK` (`index.html` servido por nginx) |

No requiere cambios en el código Angular, en `nginx/default.conf.template` ni en el `Dockerfile` de frontend.
