# Feature Specification: Kubernetes y Argo CD

**Feature Branch**: `feature/09-kubernetes-argocd`

**Created**: 2026-11-27

**Status**: Draft

**Input**: User description: "HU-09: como responsable de operaciones, quiero manifiestos con Kustomize en el repositorio de infra aplicados por Argo CD, para desplegar de forma repetible y solo mediante Git." Fuentes, en el repositorio de backend: `docs/backlog.md` (HU-09) y `docs/adr/0001-arquitectura-api-listas-reproduccion.md` (secciones 3, 7 y 13).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Desplegar la aplicación en Kubernetes con Kustomize y sondas de salud (Priority: P1)

Como responsable de operaciones, despliego backend y frontend en un clúster local mediante manifiestos gestionados con Kustomize, usando las imágenes publicadas en GHCR, sondas de salud accesibles sin token y un `Secret` real creado fuera de Git, para levantar el sistema de forma repetible sin secretos en el repositorio.

**Why this priority**: Es la base de la historia. Sin manifiestos válidos, sondas de salud sin token y manejo seguro de secretos no se puede validar el despliegue en Kubernetes ni automatizarlo con Argo CD.

**Independent Test**: Crear el `Secret` real en el clúster local siguiendo el paso documentado, generar los manifiestos con `kustomize build` sobre `k8s/` y aplicarlos, comprobar que ambos pods alcanzan estado `Ready` con sus sondas respondiendo sin token, abrir la web e iniciar sesión como `admin` y `user`.

**Acceptance Scenarios**:

1. **Given** el directorio `k8s/` en `quipux-playlist-infra`, **When** se ejecuta `kustomize build`, **Then** genera manifiestos válidos (namespace o ámbito de despliegue, Deployments, Services y ConfigMap), con exactamente **1 réplica** para el backend y sin incluir el `Secret` de ejemplo ni valores secretos reales.
2. **Given** el `Secret` real creado en el clúster según el paso documentado y los manifiestos aplicados, **When** el clúster despliega los pods, **Then** descarga las imágenes de backend y frontend desde GHCR sin credenciales y ambos pods alcanzan estado `Ready`.
3. **Given** el pod del backend en ejecución, **When** Kubernetes (o una petición sin cabecera de autorización) consulta sus rutas de salud de liveness y readiness, **Then** responden con estado saludable (`200`) sin token JWT, mientras las rutas de negocio siguen exigiendo autenticación y no quedan expuestos endpoints administrativos ni secretos.
4. **Given** la aplicación desplegada y accesible localmente, **When** un usuario abre la web, **Then** las peticiones a `/api` se reenvían al `Service` del backend; `admin` puede iniciar sesión, crear, consultar y borrar listas, y `user` solo puede consultar.
5. **Given** que el `Secret` real todavía no existe en el clúster al aplicar los manifiestos, **When** Kubernetes intenta iniciar el pod del backend, **Then** el pod no arranca e informa claramente la ausencia del secreto; al crear el `Secret` real sin modificar Git, el pod arranca y queda `Ready`.
6. **Given** la incorporación de las rutas de salud en backend y frontend, **When** se ejecutan las pruebas existentes de ambos repositorios y el arranque local o con Docker Compose, **Then** el comportamiento funcional, el contrato OpenAPI y los flujos existentes siguen funcionando sin cambios ni regresiones.

---

### User Story 2 - Validar el repositorio de infra con CI y proteger `main` (Priority: P1)

Como responsable de operaciones, cada cambio en `quipux-playlist-infra` (manifiestos, tags de imagen, actualizaciones de Dependabot o PR de release) se valida automáticamente antes de fusionarse en `main`, para impedir que lleguen manifiestos rotos, configuraciones inseguras o secretos a la rama desde la que sincroniza Argo CD.

**Why this priority**: En GitOps la rama `main` es la fuente de verdad del clúster. Proteger `main` con comprobaciones automáticas evita desplegar errores o exposiciones de seguridad.

**Independent Test**: Abrir un PR válido en `quipux-playlist-infra` y comprobar que todas las comprobaciones quedan en verde; después, en pruebas controladas o PR temporales con un manifiesto Kustomize roto, una mala configuración `HIGH`/`CRITICAL` y un secreto ficticio, verificar que cada defecto falla el CI y bloquea la fusión.

**Acceptance Scenarios**:

1. **Given** un PR válido hacia `main` en `quipux-playlist-infra`, **When** se abre o actualiza, **Then** el CI ejecuta `kustomize build` sobre `k8s/`, Trivy de configuración y Trivy de secretos, y todas las comprobaciones quedan en verde.
2. **Given** un PR con un error de sintaxis o referencia en `k8s/` que rompe `kustomize build`, **When** se ejecuta el CI, **Then** queda en rojo indicando el fallo de construcción de Kustomize.
3. **Given** un PR con una mala configuración de severidad `HIGH` o `CRITICAL` en los manifiestos (por ejemplo, contenedor ejecutándose como `root` o con escalada de privilegios), **When** se ejecuta Trivy de configuración, **Then** el CI queda en rojo indicando el archivo y el hallazgo.
4. **Given** un PR que introduce un secreto real o reconocible en el repositorio de infra, **When** se ejecuta Trivy de secretos, **Then** el CI queda en rojo indicando el archivo afectado, sin mostrar el valor completo del secreto.
5. **Given** la protección de `main` configurada en `quipux-playlist-infra`, **When** alguien (incluido el propietario) intenta hacer push directo, forzado o borrado, o fusionar cualquier PR (incluidos los de Dependabot) con comprobaciones en rojo o pendientes, **Then** GitHub lo rechaza; con todas las comprobaciones en verde permite fusionar sin aprobaciones adicionales.
6. **Given** un PR procedente de un fork o abierto por Dependabot en `quipux-playlist-infra`, **When** se ejecuta el CI, **Then** todas las comprobaciones corren sin acceso a secretos ni permisos de escritura sobre el repositorio, y todas las acciones de terceros están fijadas por SHA con permisos mínimos.

---

### User Story 3 - Desplegar de forma continua con Argo CD desde Git (Priority: P1)

Como responsable de operaciones, Argo CD instalado en el clúster local observa la rama `main` de `quipux-playlist-infra` mediante una `Application` versionada en `argocd/`, para sincronizar automáticamente cualquier cambio fusionado en `k8s/` sin que el CI tenga acceso directo al clúster.

**Why this priority**: Completa el modelo GitOps exigido por la historia: todo cambio en el clúster pasa por Git y Argo CD elimina los despliegues manuales o desde el pipeline.

**Independent Test**: Instalar Argo CD en el clúster local, aplicar el manifiesto versionado en `argocd/` con el `Secret` real ya presente, verificar estado `Synced` y `Healthy`, y fusionar un cambio declarativo en `main` de infra comprobando la sincronización automática.

**Acceptance Scenarios**:

1. **Given** Argo CD instalado en el clúster local y el `Secret` real creado en el namespace de la aplicación, **When** se aplica la `Application` versionada en `argocd/`, **Then** Argo CD sincroniza `k8s/` desde `main` de `quipux-playlist-infra` y la aplicación alcanza estado `Synced` y `Healthy`.
2. **Given** sincronizaciones automáticas repetidas (incluida la poda de recursos huérfanos), **When** Argo CD compara el clúster con `main`, **Then** nunca sobrescribe ni elimina el `Secret` real creado manualmente en el clúster.
3. **Given** la aplicación gestionada por Argo CD, **When** se fusiona un cambio en `k8s/` en `main` de `quipux-playlist-infra` (por ejemplo, una variable del `ConfigMap` o una versión de imagen), **Then** Argo CD detecta el cambio, lo aplica al clúster y mantiene la aplicación `Synced` y `Healthy` sin ejecutar comandos de despliegue desde GitHub Actions.
4. **Given** un recurso gestionado por Git modificado manualmente en el clúster (deriva de configuración), **When** Argo CD evalúa la reconciliación, **Then** detecta la deriva y restablece el estado declarado en `main`.
5. **Given** los workflows de CI/CD de los tres repositorios, **When** se inspeccionan sus pasos y secretos, **Then** ninguno contiene `kubeconfig`, credenciales de acceso al clúster ni pasos de despliegue directo.

---

### User Story 4 - Proponer automáticamente nuevas versiones mediante PR en infra (Priority: P2)

Como responsable de operaciones, cada vez que backend o frontend publica una nueva imagen en GHCR tras una release, ese workflow abre automáticamente un PR en `quipux-playlist-infra` con el nuevo tag de imagen, para que el CI de infra lo valide y al fusionarlo Argo CD despliegue la nueva versión.

**Why this priority**: Automatiza la transición entre entrega continua (HU-08) y despliegue continuo (GitOps), aunque los manifiestos base, el CI de infra y Argo CD pueden probarse antes de forma independiente con la versión inicial `0.1.0`.

**Independent Test**: Publicar una nueva release de backend o frontend, comprobar que el workflow abre un PR en `quipux-playlist-infra` actualizando solo el tag de ese componente, esperar a que el CI de infra quede en verde, fusionar el PR y confirmar que Argo CD sincroniza el nuevo tag y queda `Healthy`.

**Acceptance Scenarios**:

1. **Given** una nueva release en backend o frontend que publica su imagen en GHCR, **When** termina la publicación de la imagen, **Then** el mismo workflow abre (o actualiza) un PR en `quipux-playlist-infra` modificando únicamente el tag de imagen de ese componente en `k8s/`.
2. **Given** el paso que abre el PR hacia `quipux-playlist-infra`, **When** se configura e inspecciona su autenticación, **Then** utiliza un token guardado como secreto cuyo alcance se limita exclusivamente al repositorio `quipux-playlist-infra`, sin permisos sobre los repositorios de backend ni frontend.
3. **Given** el PR de actualización de tag abierto en `quipux-playlist-infra`, **When** se crea o actualiza, **Then** ejecuta automáticamente el CI de infra y no puede fusionarse mientras alguna comprobación no esté en verde.
4. **Given** el PR de tag en verde y fusionado en `main` de `quipux-playlist-infra`, **When** Argo CD sincroniza `main`, **Then** el pod correspondiente se actualiza al nuevo tag de imagen y la aplicación queda `Synced` y `Healthy`.
5. **Given** que la construcción o el análisis de Trivy de la imagen falla en el workflow de release de backend o frontend, **When** el trabajo termina en rojo, **Then** la imagen no se publica y no se abre ningún PR en `quipux-playlist-infra`.

---

### User Story 5 - Versionar el repositorio de infra con release-please (Priority: P2)

Como responsable de operaciones, `quipux-playlist-infra` mantiene su propio versionado semántico y `CHANGELOG` automático mediante `release-please`, para tener trazabilidad de los cambios de infraestructura igual que en backend y frontend.

**Why this priority**: Completa la paridad de gobernanza y trazabilidad entre los tres repositorios, sin bloquear el despliegue inicial en Kubernetes ni el funcionamiento de Argo CD.

**Independent Test**: Fusionar en `main` de `quipux-playlist-infra` un cambio con Conventional Commit que genere versión, verificar que `release-please` abre el PR de release con el `CHANGELOG`, pasa el CI de infra y al fusionarlo crea tag y release sin construir imágenes.

**Acceptance Scenarios**:

1. **Given** cambios fusionados en `main` de `quipux-playlist-infra` que generan versión según Conventional Commits, **When** termina el workflow de release de infra, **Then** existe un PR de release abierto o actualizado con el número de versión propuesto y su `CHANGELOG`.
2. **Given** ese PR de release en `quipux-playlist-infra`, **When** se crea o actualiza, **Then** usa un token propio del repositorio de infra guardado como secreto para que el CI de infra se ejecute sobre él y permita fusionarlo en verde.
3. **Given** el PR de release fusionado en `main` de `quipux-playlist-infra`, **When** termina el workflow, **Then** se crean el tag y la release en GitHub sin construir ni publicar imágenes de contenedor.

---

### Edge Cases

- **Ausencia del `Secret` real en el clúster**: el pod del backend no arranca y reporta claramente la falta del secreto sin exponer valores; al crear el `Secret` manualmente con el paso documentado, el pod arranca sin tocar Git.
- **Poda (`prune`) en Argo CD frente al `Secret` real**: al no estar incluido en `kustomization.yaml` ni gestionado por el `Application`, Argo CD no intenta crear, sobrescribir ni borrar el `Secret` real del clúster.
- **Sondas de salud sin exposición indebida**: abrir las rutas de liveness y readiness no expone endpoints de entorno, métricas detalladas, trazas, configuración interna ni credenciales.
- **Fallo transitorio o reinicio del pod del backend**: las sondas reinician el pod si deja de responder; al usar H2 en memoria, las listas previas se pierden y se recrean únicamente los usuarios de demostración configurados en el `Secret`.
- **Restricción de réplicas del backend**: `Deployment` fijado en 1 réplica; aumentar réplicas provocaría estados divergentes por H2 en memoria y está explícitamente fuera de alcance.
- **Marcadores en el `Secret` de ejemplo frente a Trivy de secretos**: los valores de ejemplo usan marcadores claramente vacíos o ficticios que no disparan falsos positivos (o, si un patrón inevitable lo hiciera, se excluye de forma individual, versionada y justificada sin desactivar Trivy).
- **Hallazgos `HIGH` o `CRITICAL` de Trivy de configuración en manifiestos**: se corrigen endureciendo el diseño de los manifiestos (`securityContext`, usuario no root, límites de recursos, etc.); si algún hallazgo fuera falso positivo o inaplicable, se excluye individualmente con justificación versionada.
- **Orden de activación de la protección de `main` en infra**: las comprobaciones requeridas del CI se activan en la protección de `main` una vez que el workflow de CI ya existe en `main`, evitando PRs bloqueados esperando checks inexistentes.
- **PR automático cuando ya existe otro PR abierto para el mismo componente o tag sin cambios**: si llega una nueva release del mismo componente antes de fusionar el PR previo, el flujo actualiza la rama/PR de forma idempotente sin corromper `kustomization.yaml`; si el tag ya está en `main`, no abre un PR vacío.
- **Token de PR hacia infra ausente, vencido o sin permisos**: el paso final del workflow de release de backend/frontend falla indicando el error sin mostrar el token; la imagen ya publicada en GHCR permanece disponible y el job puede reintentarse tras corregir el secreto.
- **Independencia entre `k8s/` y `compose/`**: actualizar tags en `k8s/` no modifica `compose/`, que sigue construyendo desde carpetas hermanas.
- **Clúster local sin credenciales de GHCR**: las imágenes de backend y frontend son públicas en GHCR desde HU-08, por lo que el clúster local no requiere `imagePullSecrets`.

## Requirements *(mandatory)*

### Functional Requirements

**Sondas de salud (Backend y Frontend)**

- **FR-001**: El backend expone rutas de salud diferenciadas para liveness y readiness accesibles sin token JWT.
- **FR-002**: Ningún otro endpoint de gestión, diagnóstico, métricas o configuración interna queda accesible sin autenticación, y las respuestas de las rutas de salud no revelan secretos ni detalles internos de infraestructura.
- **FR-003**: El frontend responde a sondas de salud HTTP sin token a través de su servidor web existente, sin interferir con el enrutamiento SPA ni con el reenvío de `/api`.

**Manifiestos de Kubernetes y Kustomize**

- **FR-004**: El repositorio `quipux-playlist-infra` contiene en `k8s/` manifiestos gestionados con Kustomize que definen el ámbito de despliegue (namespace), `Deployment` y `Service` para backend y frontend, y un `ConfigMap` con la configuración no secreta (incluida la dirección interna del backend que consume la web).
- **FR-005**: El `Deployment` del backend fija exactamente 1 réplica, porque la base de datos H2 en memoria no se comparte entre múltiples pods.
- **FR-006**: Ambos `Deployment` configuran sondas de liveness y readiness contra rutas accesibles sin token, referencian imágenes de GHCR con versiones explícitas (sin etiqueta móvil `latest`) gestionadas con Kustomize y aplican configuración de seguridad endurecida (usuario sin privilegios, sin escalada de privilegios y recursos acotados) libre de hallazgos `HIGH` o `CRITICAL` en Trivy.
- **FR-007**: El repositorio de infra incluye un archivo de `Secret` de ejemplo sin valores reales que documenta las claves requeridas (`JWT_SECRET`, `DEMO_USER_PASSWORD`, `DEMO_ADMIN_PASSWORD` y variables opcionales de Spotify). Ese archivo **no** se incluye en `kustomization.yaml`.
- **FR-008**: No existen secretos reales en Git ni en la salida generada por `kustomize build`. El `Secret` real se crea manualmente en el clúster mediante un paso documentado.
- **FR-009**: Los manifiestos se despliegan y prueban en un clúster local de Kubernetes verificando el inicio de sesión y las operaciones completas de la web y la API.

**CI, seguridad y protección de `main` en infra**

- **FR-010**: En cada PR hacia `main` y cada push a `main` de `quipux-playlist-infra`, el CI ejecuta `kustomize build` sobre `k8s/` y falla si la construcción produce cualquier error.
- **FR-011**: El CI de infra ejecuta Trivy de configuración sobre los manifiestos de Kubernetes y Trivy de secretos sobre el repositorio, fallando ante cualquier hallazgo de severidad `HIGH` o `CRITICAL`.
- **FR-012**: Todas las acciones de terceros en los workflows de `quipux-playlist-infra` (y cualquier workflow nuevo o modificado en backend/frontend) están fijadas por SHA de commit con la versión indicada en comentario junto a él, y cada workflow declara permisos mínimos (`contents: read` por defecto).
- **FR-013**: El CI de infra no requiere secretos ni permisos de escritura para validar PRs, incluidos los provenientes de forks o de Dependabot.
- **FR-014**: La protección de la rama `main` en `quipux-playlist-infra` exige, además de PR sin push directo/forzado/borrado, que todas las comprobaciones del CI estén en verde para poder fusionar (incluidos PR de Dependabot, PR automáticos de tag y PR de `release-please`).
- **FR-015**: Dependabot en `quipux-playlist-infra` está configurado para cubrir `docker-compose` y `github-actions`, usando mensajes en formato Conventional Commits.

**Versionado (`release-please`) en infra**

- **FR-016**: `release-please` está configurado y activo en `quipux-playlist-infra` para abrir y mantener PRs de release con versión y `CHANGELOG` a partir de Conventional Commits, y generar tag y release al fusionarse.
- **FR-017**: `release-please` en infra usa un token propio del repositorio de infra guardado como secreto, de manera que el CI de infra se ejecuta sobre el PR de release y permite fusionarlo en verde.

**GitOps con Argo CD y PR automático de tag**

- **FR-018**: El manifiesto `Application` de Argo CD está versionado en `argocd/` dentro de `quipux-playlist-infra` y apunta a la rama `main` y ruta `k8s/` del repositorio público de infra.
- **FR-019**: Argo CD se instala y verifica en un clúster local, sincronizando la `Application` desde Git hasta alcanzar los estados `Synced` y `Healthy` sin sobrescribir ni eliminar el `Secret` real creado en el clúster.
- **FR-020**: Ningún workflow de CI/CD de los tres repositorios despliega directamente contra el clúster ni almacena credenciales de Kubernetes.
- **FR-021**: Tras publicar exitosamente una imagen en GHCR, el workflow de release de backend y el de frontend abren (o actualizan) un PR en `quipux-playlist-infra` actualizando únicamente el tag de imagen del componente correspondiente en `k8s/`.
- **FR-022**: El token utilizado para abrir ese PR en infra tiene permisos exclusivamente sobre `quipux-playlist-infra` y se almacena como secreto en los repositorios de aplicación.
- **FR-023**: Si la publicación de la imagen falla en backend o frontend, no se abre ningún PR en infra; al fusionar un PR de tag válido con el CI de infra en verde, Argo CD sincroniza la nueva versión y la aplicación vuelve a quedar `Synced` y `Healthy`.

**Documentación y restricciones transversales**

- **FR-024**: El README de `quipux-playlist-infra` explica cómo crear el `Secret` real en el clúster, cómo validar y aplicar los manifiestos en un clúster local, cómo instalar Argo CD y aplicar `argocd/`, cómo acceder localmente a la web/API y a Argo CD, qué comprueba el CI de infra, cómo se versiona infra con `release-please` y los pasos manuales de tokens y protección de `main`.
- **FR-025**: Los README de backend y frontend actualizan el estado del despliegue en Kubernetes/Argo CD (dejando de marcarlo como pendiente) y documentan las rutas de salud expuestas y el paso automático de PR hacia infra tras cada release.
- **FR-026**: El comportamiento funcional de la API y de la web, el contrato OpenAPI, la regla de no-bloqueo (`BlockHound`), Checkstyle, Qodana, cobertura mínima del 80 % por módulo en backend, ESLint y pruebas unitarias en frontend, y la ejecución local y con Docker Compose continúan funcionando sin regresiones.
- **FR-027**: Los tres repositorios, los manifiestos generados por `kustomize build`, las imágenes y los registros de CI/CD contienen 0 secretos reales.

### Key Entities *(include if feature involves data)*

- **Sonda de salud**: ruta HTTP sin autenticación de liveness o readiness usada por Kubernetes para verificar el estado del contenedor.
- **Manifiesto Kustomize**: conjunto declarativo versionado en `k8s/` (namespace, Deployments, Services, ConfigMap y referencias de tags de imagen).
- **Secret de ejemplo y Secret del clúster**: plantilla versionada sin valores reales (excluida de `kustomization.yaml`) frente al secreto real creado manualmente en el clúster.
- **Comprobación de infra**: validación automática del CI sobre `quipux-playlist-infra` (`kustomize build`, Trivy de configuración y Trivy de secretos).
- **Aplicación Argo CD (`Application`)**: manifiesto versionado en `argocd/` que vincula la rama `main` (`k8s/`) de infra con el clúster local.
- **PR automático de tag**: solicitud de cambio abierta por el workflow de release de backend o frontend para actualizar una versión de imagen en `k8s/`.
- **Versión de infra**: número semántico, tag, release y entrada de `CHANGELOG` generados por `release-please` en `quipux-playlist-infra`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100 % de los PR y push a `main` de `quipux-playlist-infra` ejecutan `kustomize build`, Trivy de configuración y Trivy de secretos y muestran su resultado en menos de 10 minutos, sin intervención manual.
- **SC-002**: El 100 % de los defectos introducidos a propósito en infra (manifiesto Kustomize inválido, mala configuración `HIGH`/`CRITICAL` y secreto de prueba) son bloqueados por el CI y no pueden fusionarse en `main`.
- **SC-003**: Con el `Secret` real creado según el paso documentado, la aplicación desplegada en el clúster local alcanza estado `Ready` y `Healthy` en menos de 3 minutos y permite completar el flujo de usuario (`admin` y `user`) a través de la web.
- **SC-004**: Las rutas de salud de liveness y readiness responden `200` sin token, mientras el 100 % de los endpoints protegidos de la API conservan sus respuestas de seguridad (`401`/`403`) y todas las pruebas y controles de calidad de backend (`mvn verify` con ≥ 80 % de cobertura, Checkstyle y `BlockHound`) y frontend pasan sin regresiones.
- **SC-005**: Al fusionar en `main` de infra un PR automático de actualización de tag tras una release de aplicación, Argo CD sincroniza la nueva versión y deja la aplicación `Synced` y `Healthy` en menos de 5 minutos, sin comandos manuales sobre el clúster ni pérdida del `Secret` real.
- **SC-006**: Existe al menos una release publicada en `quipux-playlist-infra` con su `CHANGELOG` mediante `release-please`, y al menos un PR automático de tag abierto por una release de backend o frontend y sincronizado por Argo CD.
- **SC-007**: Los tres repositorios, los manifiestos generados por `kustomize build` y los registros de CI/CD contienen 0 secretos reales.
- **SC-008**: El 100 % de los criterios de aceptación de HU-09 en `docs/backlog.md` quedan comprobados (por prueba automática o evidencia documentada).

## Assumptions

- **Ubicación de la historia**: siguiendo el mismo criterio usado en HU-07 y HU-08, la especificación, el plan y las tareas viven en `quipux-playlist-infra/specs/09-kubernetes-argocd/`. Los cambios en backend y frontend se implementan en ramas `feature/09-kubernetes-argocd` de cada repositorio.
- **Alcance combinado**: una sola historia cubre las fases 9 (manifiestos Kubernetes y CI de infra) y 10 (Argo CD y PR automático de tag) del `ADR-0001`.
- **Clúster local**: se emplea un clúster local de Kubernetes en la máquina de desarrollo con `kubectl` y salida a internet para descargar las imágenes públicas de GHCR y los manifiestos/imágenes de Argo CD; la distribución concreta de clúster local se elige en el plan.
- **Exposición local**: sin TLS ni exposición en red pública; el acceso a web, API y consola de Argo CD es local (por ejemplo mediante reenvío de puertos o exposición local equivalente).
- **Una réplica en backend**: H2 en memoria no persiste ni comparte estado entre pods; el reinicio de pod borra las listas creadas en esa sesión.
- **Géneros en Kubernetes**: WireMock no se despliega en Kubernetes; por defecto la API responde con la lista local (`LOCAL`), salvo que el operador configure credenciales de Spotify en el `Secret` del clúster.
- **Primera versión de infra y formato de commit del PR automático**: la primera versión de `quipux-playlist-infra` con `release-please` parte en `0.1.0`. El tipo de commit usado en los PR automáticos de tag (por ejemplo `chore(deploy)` vs `fix(deploy)`) y la estructura exacta del cambio en `k8s/` (p. ej. `kustomization.yaml`) se confirman en el plan.
- **Acciones manuales de la persona responsable**: crear el token restringido únicamente a `quipux-playlist-infra` (y guardarlo como secreto en backend y frontend), configurar el `RELEASE_PLEASE_TOKEN` propio de infra, actualizar la protección de `main` de infra cuando el CI esté en `main`, preparar el clúster local y crear el `Secret` real en el clúster.
- **Fuera de alcance**: Redis (HU-10), Kafka (HU-11), Terraform, múltiples overlays de entorno (dev/staging/prod), TLS/Ingress público, gestores externos de secretos (Sealed Secrets, External Secrets, Vault), escalado horizontal del backend y despliegue en clústeres gestionados en la nube.
- **Dependencia**: HU-08 integrada en `main` de los tres repositorios, con imágenes `0.1.0` públicas en GHCR y protección de `main` activa.
