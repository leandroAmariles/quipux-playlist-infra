# Feature Specification: Clúster local con Terraform y `make up`

**Feature Branch**: `feature/15-terraform-make-up`

**Created**: 2026-11-27

**Status**: Draft

**Input**: User description: "HU-15: en `quipux-playlist-infra`, usar Terraform con `make up` para levantar el clúster desde el repositorio de infra. Ollama se ejecuta desde Docker." Decisiones tomadas al especificar: todas las dependencias de IA corren en Docker, fuera del clúster; la aplicación se despliega desde los manifiestos locales y Argo CD es opcional; el clúster `quipux-playlist` creado a mano se recrea.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Levantar el clúster y la aplicación con un solo comando (Priority: P1)

Como desarrollador, ejecuto `make up` en `quipux-playlist-infra` y obtengo el clúster local con la web, la API, Redis y Kafka en marcha, junto con las direcciones y la forma de obtener las credenciales, sin crear el clúster, el `Secret` ni los accesos a mano.

**Why this priority**: Es el objetivo de la historia. Sustituye la secuencia manual de comandos del README y entrega valor aunque no haya IA.

**Independent Test**: En un equipo sin clúster del proyecto, con solo este repositorio y las herramientas requeridas, ejecutar `make up` con la IA desactivada, abrir la web, iniciar sesión como `admin` y crear una lista.

**Acceptance Scenarios**:

1. **Given** Docker en marcha y ningún clúster del proyecto, **When** se ejecuta `make up`, **Then** se crea el clúster, se despliegan `api`, `web`, `redis` y `kafka` desde los manifiestos locales, el comando termina solo cuando todos están listos y muestra las direcciones de la web, la API y Swagger.
2. **Given** `make up` terminado con éxito, **When** se abre `http://localhost:4200` y `http://localhost:8080`, **Then** ambas responden sin ejecutar ningún paso adicional y solo son accesibles desde el propio equipo.
3. **Given** que no se han definido contraseñas ni clave de firma, **When** se ejecuta `make up` por primera vez, **Then** se generan valores aleatorios, ninguno queda en un archivo versionado y existe un comando documentado para consultar las contraseñas de `user` y `admin`.
4. **Given** que el desarrollador definió sus propias contraseñas o credenciales de Spotify en el archivo local no versionado, **When** se ejecuta `make up`, **Then** la aplicación usa esos valores.
5. **Given** el entorno ya levantado y sin cambios, **When** se ejecuta `make up` de nuevo, **Then** termina con éxito sin recrear el clúster, sin cambiar credenciales y sin reiniciar la aplicación.
6. **Given** un cambio sin fusionar en `k8s/`, **When** se ejecuta `make up`, **Then** el clúster refleja ese cambio.

---

### User Story 2 - Recomendaciones con IA usando Ollama en Docker (Priority: P1)

Como desarrollador, el mismo `make up` deja en Docker, fuera del clúster, Ollama, la pasarela de modelos y la base de datos del catálogo, y conecta la API del clúster con ellos para obtener recomendaciones generadas por IA.

**Why this priority**: Fue pedido explícitamente y hoy el clúster solo puede responder con la lista de respaldo.

**Independent Test**: Tras `make up`, crear una lista y consultar sus recomendaciones: el origen es `IA` o `SIMILITUD` y las canciones tienen identificador de catálogo.

**Acceptance Scenarios**:

1. **Given** un equipo sin modelos descargados, **When** se ejecuta `make up`, **Then** arrancan en Docker las dependencias de IA, se descargan los modelos, se indexa el catálogo y el comando informa del progreso y termina solo cuando las recomendaciones están disponibles.
2. **Given** el entorno listo, **When** se consultan las recomendaciones de una lista, **Then** la respuesta indica origen `IA` o `SIMILITUD`.
3. **Given** el entorno listo, **When** se detiene Ollama, **Then** la API sigue funcionando y las recomendaciones que no estén en caché responden con origen `SIMILITUD` o `RESPALDO`.
4. **Given** un equipo con GPU NVIDIA utilizable por Docker, **When** se ejecuta `make up` sin indicar nada, **Then** los modelos se ejecutan en la GPU; **Given** un equipo sin ella, **Then** se ejecutan en CPU sin cambiar archivos versionados.
5. **Given** que el desarrollador desactiva la IA, **When** se ejecuta `make up`, **Then** no arranca ninguna dependencia de IA, no se descargan modelos y las recomendaciones responden con origen `RESPALDO`.

---

### User Story 3 - Consultar, detener y limpiar el entorno (Priority: P2)

Como desarrollador, consulto el estado del entorno, lo detengo o lo elimino desde el mismo repositorio, decidiendo si conservo los modelos descargados.

**Why this priority**: Sin una forma segura de apagar y limpiar, el entorno consume memoria y disco y obliga a recordar comandos de varias herramientas.

**Independent Test**: Con el entorno arriba, ejecutar los comandos de estado, eliminación conservando datos y limpieza total, y comprobar qué permanece tras cada uno.

**Acceptance Scenarios**:

1. **Given** el entorno arriba, **When** se ejecuta `make status`, **Then** se ve el estado del clúster, de la aplicación y de las dependencias en Docker, y las direcciones disponibles.
2. **Given** el entorno arriba, **When** se ejecuta `make down`, **Then** se eliminan el clúster y los contenedores creados por `make up`, se conservan los modelos y el catálogo, y no se toca ningún otro clúster ni contenedor del equipo.
3. **Given** un entorno eliminado con `make down`, **When** se ejecuta `make up`, **Then** no se vuelven a descargar los modelos.
4. **Given** cualquier estado, **When** se pide la limpieza total, **Then** se solicita confirmación antes de borrar modelos, catálogo y credenciales generadas.
5. **Given** Docker o el equipo reiniciados, **When** se ejecuta `make up`, **Then** el entorno vuelve a quedar accesible.

---

### User Story 4 - Activar Argo CD cuando se necesite (Priority: P3)

Como responsable de operaciones, puedo pedir que el entorno incluya Argo CD para probar el despliegue continuo desde la rama `main` de GitHub.

**Why this priority**: El despliegue continuo ya existe (HU-09); aquí solo se conserva como opción.

**Independent Test**: Levantar el entorno con Argo CD activado y comprobar que la aplicación queda `Synced` y `Healthy` y que las recomendaciones con IA siguen funcionando.

**Acceptance Scenarios**:

1. **Given** Argo CD sin activar (valor por defecto), **When** se ejecuta `make up`, **Then** no se instala.
2. **Given** Argo CD activado, **When** se ejecuta `make up`, **Then** Argo CD despliega `main`, queda `Synced` y `Healthy`, se avisa de que los cambios locales de `k8s/` no se aplican y se indica cómo abrir su consola.
3. **Given** Argo CD activado y la IA activada, **When** Argo CD sincroniza y corrige desviaciones, **Then** la conexión de la API con las dependencias de IA se mantiene.

---

### Edge Cases

- Falta una herramienta requerida o Docker está detenido: `make up` falla antes de crear nada e indica qué falta.
- Ya existe un clúster `quipux-playlist` que no creó `make up`: se detiene con un mensaje que explica cómo eliminarlo; nunca lo borra solo.
- El puerto `4200`, `8080` u otro necesario está ocupado: falla indicando el puerto y cómo cambiarlo.
- La memoria asignada a Docker es insuficiente para la IA: avisa antes de arrancar e indica cómo desactivar la IA o ampliar la memoria.
- `make up` se interrumpe o falla a medias: al repetirlo continúa y converge sin limpieza manual.
- El kubeconfig tiene otros clústeres o el contexto actual es otro: todas las operaciones actúan solo sobre el clúster del proyecto.
- Sin conexión a internet en la primera ejecución: falla con un mensaje claro; con todo descargado, `make up` no exige descargar modelos.
- Un valor de configuración local no es válido (por ejemplo, contraseña de más de 72 bytes o clave de firma de menos de 32): falla indicando la variable sin mostrar su valor.
- Hay otra pila del proyecto en Docker Compose en el mismo equipo: no se modifican sus contenedores ni sus volúmenes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El repositorio de infra MUST ofrecer `make up` como único comando para crear o actualizar el entorno local completo, usando Terraform para declarar el clúster y sus recursos.
- **FR-002**: `make up` MUST funcionar con solo el repositorio de infra clonado, usando las imágenes publicadas de la API y la web con las versiones fijadas en `k8s/`.
- **FR-003**: Antes de crear recursos, `make up` MUST comprobar las herramientas requeridas, que Docker responde y que los puertos necesarios están libres o ya pertenecen al entorno.
- **FR-004**: `make up` MUST terminar con éxito solo cuando la aplicación (y la IA, si está activada) esté lista, y con código de error y causa identificable en caso contrario.
- **FR-005**: Tras `make up`, la web y la API MUST estar accesibles en `localhost:4200` y `localhost:8080` sin pasos adicionales y sin escuchar en otras interfaces de red.
- **FR-006**: Repetir `make up` sin cambios MUST NOT recrear recursos, cambiar credenciales ni reiniciar la aplicación.
- **FR-007**: Los secretos que el usuario no defina MUST generarse aleatoriamente y conservarse entre ejecuciones hasta la limpieza total.
- **FR-008**: Ningún secreto, estado de Terraform ni archivo con valores locales MUST poder quedar versionado; la documentación MUST indicar dónde quedan y que el estado local contiene o puede contener secretos.
- **FR-009**: La salida de `make up` MUST NOT mostrar secretos; consultar las contraseñas de demostración MUST requerir un comando explícito.
- **FR-010**: Ollama, la pasarela de modelos y la base de datos del catálogo MUST ejecutarse como contenedores en Docker, fuera del clúster, y ser alcanzables por la API desplegada en el clúster.
- **FR-011**: Ollama MUST NOT publicar puertos en el equipo; los puertos de las demás dependencias, si se publican, MUST abrirse solo en `127.0.0.1`.
- **FR-012**: Las dependencias de IA MUST usar versiones fijadas y la misma configuración de modelos y de catálogo que la composición de IA existente, sin mantener dos definiciones divergentes de esa configuración.
- **FR-013**: `make up` MUST dejar los modelos descargados y el catálogo indexado.
- **FR-014**: El uso de GPU NVIDIA MUST detectarse automáticamente y poder forzarse o desactivarse; la IA completa MUST poder desactivarse (activada por defecto).
- **FR-015**: El repositorio MUST ofrecer comandos para ver el estado, eliminar el entorno conservando modelos y catálogo, y limpiar por completo con confirmación.
- **FR-016**: Los comandos MUST actuar solo sobre los recursos del entorno que gestionan.
- **FR-017**: Argo CD MUST ser opcional y estar desactivado por defecto; al activarlo MUST desplegar `main` sin revertir la configuración de IA ni los secretos del entorno local.
- **FR-018**: Los comandos MUST funcionar en Windows 11 (PowerShell y Git Bash), y no impedir su uso en Linux y macOS.
- **FR-019**: La integración continua del repositorio MUST validar el formato y la validez de la definición de Terraform y analizar su configuración, sin acceso a ningún clúster ni secreto.
- **FR-020**: La composición de Docker Compose existente MUST seguir funcionando sin cambios de uso.
- **FR-021**: El README MUST documentar requisitos, comandos, variables, direcciones, credenciales y solución de problemas, reemplazando la secuencia manual del clúster.

### Key Entities

- **Entorno local**: clúster del proyecto, recursos desplegados y contenedores de dependencias que `make up` gestiona.
- **Configuración local**: valores no versionados que el desarrollador puede definir (contraseñas, credenciales, puertos, interruptores de IA, GPU y Argo CD).
- **Secretos del entorno**: clave de firma, contraseñas de demostración, clave de la pasarela y contraseña del catálogo.
- **Datos persistentes**: modelos descargados y catálogo indexado; sobreviven a la eliminación normal.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Desde un repositorio recién clonado y con las herramientas instaladas, un desarrollador obtiene la aplicación utilizable con 1 comando y 0 pasos manuales intermedios.
- **SC-002**: Con imágenes y modelos ya descargados, crear el entorno completo tarda 5 minutos o menos en el equipo de referencia (Windows 11, 31 GB, GPU NVIDIA de 12 GB).
- **SC-003**: Repetir el comando sin cambios termina en 2 minutos o menos y no modifica ningún recurso.
- **SC-004**: En el 100 % de las pruebas de aceptación con la IA activada, una lista nueva recibe recomendaciones con origen `IA` o `SIMILITUD`.
- **SC-005**: 0 secretos en archivos versionados y 0 secretos en la salida de `make up`.
- **SC-006**: Tras eliminar y volver a crear el entorno, se descargan 0 bytes de modelos.
- **SC-007**: Tras eliminar el entorno, los demás clústeres y contenedores del equipo permanecen como estaban.

## Assumptions

- El desarrollador instala por su cuenta Docker, `make`, Terraform, `kind` y `kubectl`; la historia no instala herramientas.
- El entorno es de desarrollo local: sin HTTPS, sin alta disponibilidad y sin proveedor en la nube. El estado de Terraform es local.
- Las bases de datos efímeras siguen igual: las listas se pierden al reiniciar la API.
- Redis y Kafka permanecen dentro del clúster, como en HU-10 y HU-11.
- Langfuse y WireMock quedan fuera de alcance; siguen disponibles con Docker Compose.
- No se modifica el código de backend ni de frontend; la versión publicada de la API ya admite la configuración de IA y la indexación del catálogo.
- El clúster `quipux-playlist` creado a mano se eliminará durante la implementación, previa confirmación. Se pierden sus listas en memoria y su `Secret`.
- La IA necesita al menos 8 GB de memoria asignados a Docker, según lo medido en HU-12.
