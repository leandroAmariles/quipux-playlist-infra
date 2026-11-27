# Feature Specification: CI, dependencias y releases

**Feature Branch**: `feature/08-ci-dependencies-releases`

**Created**: 2026-11-27

**Status**: Draft

**Input**: User description: "HU-08: como responsable del sistema, quiero validar cada cambio y generar versiones automáticamente, para detectar errores y vulnerabilidades y saber qué se despliega." Fuentes, en el repositorio de backend: `docs/backlog.md` (HU-08) y `docs/adr/0001-arquitectura-api-listas-reproduccion.md` (secciones 3, 11 y 13).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Validar cada cambio (Priority: P1)

Como responsable del sistema, cada PR y cada push a `main` de backend y frontend se compila, se prueba y se analiza solo, para detectar errores antes de que lleguen a `main`.

**Why this priority**: Es la base de la historia. La protección de `main`, las actualizaciones y las releases dependen de estas comprobaciones.

**Independent Test**: Abrir un PR correcto y comprobar que todas las comprobaciones quedan en verde. Abrir después PR temporales con un defecto cada uno y comprobar que cada uno queda en rojo.

**Acceptance Scenarios**:

1. **Given** un PR de backend sin defectos, **When** se abre o se actualiza, **Then** se ejecutan `mvn verify` y Qodana, y quedan en verde.
2. **Given** un PR de backend con una prueba que falla, cobertura inferior al 80 % en un módulo o una violación de Checkstyle, **When** se ejecuta el CI, **Then** queda en rojo e indica cuál de las tres causas es.
3. **Given** un PR de backend con un hallazgo de Qodana de severidad crítica o alta, **When** se ejecuta el CI, **Then** queda en rojo y el hallazgo se puede consultar con su archivo y línea.
4. **Given** un PR de frontend sin defectos, **When** se abre o se actualiza, **Then** se compila la web, se ejecutan sus pruebas y ESLint, y quedan en verde.
5. **Given** un PR de frontend con un error de compilación, una prueba que falla o un error de ESLint, **When** se ejecuta el CI, **Then** queda en rojo.
6. **Given** un cambio ya fusionado, **When** llega el push a `main`, **Then** se ejecutan las mismas comprobaciones sobre `main`.

---

### User Story 2 - Detectar vulnerabilidades y secretos (Priority: P1)

Como responsable del sistema, cada cambio se revisa en busca de dependencias vulnerables y de secretos, para no incorporarlos sin saberlo.

**Why this priority**: Los repositorios son públicos: un secreto publicado queda expuesto de inmediato.

**Independent Test**: En backend y frontend, abrir un PR temporal que añada una dependencia con una vulnerabilidad conocida y corregible, y otro que añada un secreto ficticio con formato reconocible.

**Acceptance Scenarios**:

1. **Given** un PR que añade una dependencia, directa o transitiva, con una vulnerabilidad `HIGH` o `CRITICAL` que tiene corrección, **When** se ejecuta Trivy, **Then** queda en rojo e indica la dependencia y la versión que la corrige.
2. **Given** una vulnerabilidad `HIGH` o `CRITICAL` sin corrección disponible, o una de severidad menor, **When** se ejecuta Trivy, **Then** no hace fallar el CI.
3. **Given** un PR que añade un secreto, **When** se ejecuta Trivy, **Then** queda en rojo e indica el archivo, sin mostrar el valor completo.
4. **Given** un PR desde un fork o creado por Dependabot, **When** se ejecuta el CI, **Then** todas las comprobaciones funcionan sin acceder a secretos ni tener permisos de escritura sobre el repositorio.

---

### User Story 3 - Proteger `main` (Priority: P1)

Como responsable del sistema, `main` solo admite cambios por PR y, donde hay CI, con las comprobaciones en verde, para que nada se salte la validación.

**Why this priority**: Sin protección, las comprobaciones son solo informativas.

**Independent Test**: Intentar un push directo a `main` en los tres repositorios e intentar fusionar un PR en rojo en backend y frontend.

**Acceptance Scenarios**:

1. **Given** cualquiera de los tres repositorios, **When** alguien, incluido el propietario, intenta hacer push directo, forzar o borrar `main`, **Then** se rechaza.
2. **Given** un PR de backend o frontend con alguna comprobación en rojo o sin terminar, **When** intenta fusionarlo, **Then** no se permite.
3. **Given** un PR de backend o frontend con todo en verde, **When** lo fusiona, **Then** se permite sin la aprobación de otra persona.
4. **Given** un PR de infra, **When** lo fusiona, **Then** se permite sin comprobaciones de CI, que llegan con HU-09.

---

### User Story 4 - Versionar y publicar imágenes (Priority: P2)

Como responsable del sistema, al fusionar el PR de release obtengo una versión con su CHANGELOG y una imagen publicada con ese número, para saber qué se despliega.

**Why this priority**: Es necesaria para desplegar en HU-09, pero solo tiene sentido cuando `main` ya está validada.

**Independent Test**: En backend y frontend, fusionar un cambio que genere versión, fusionar el PR de release y descargar la imagen publicada desde un equipo sin sesión en el registro.

**Acceptance Scenarios**:

1. **Given** cambios fusionados en `main` que corresponden a una versión nueva, **When** termina el workflow de release, **Then** hay un PR de release abierto o actualizado, con el número de versión propuesto y el CHANGELOG.
2. **Given** ese PR de release, **When** se crea o se actualiza, **Then** se ejecuta el CI sobre él y se puede fusionar si queda en verde.
3. **Given** el PR de release fusionado, **When** termina el mismo workflow, **Then** existen el tag y la release, y la imagen construida desde ese código está en GHCR con el número de versión como tag.
4. **Given** que la imagen construida tiene una vulnerabilidad `HIGH` o `CRITICAL` con corrección, **When** Trivy la analiza, **Then** la imagen no se publica y el workflow queda en rojo.
5. **Given** un merge a `main` que no es un PR de release, **When** se ejecuta el workflow, **Then** no se publica ninguna imagen.
6. **Given** una imagen publicada, **When** se descarga sin credenciales, **Then** se descarga y arranca como la que construye Compose.

---

### User Story 5 - Mantener las dependencias al día (Priority: P2)

Como responsable del sistema, recibo PR con las actualizaciones de dependencias ya validados, para aplicarlas sin revisarlas a mano una a una.

**Why this priority**: Reduce el riesgo con el tiempo, pero el sistema se puede validar y publicar sin ello.

**Independent Test**: Con la configuración en `main`, comprobar en cada repositorio que Dependabot reconoce todos sus ecosistemas sin errores y revisar los PR que abre.

**Acceptance Scenarios**:

1. **Given** la configuración fusionada, **When** Dependabot revisa cada repositorio, **Then** cubre: en backend, Maven, Docker y GitHub Actions; en frontend, npm, Docker y GitHub Actions; en infra, las imágenes de Compose.
2. **Given** un PR de Dependabot, **When** se revisa su commit, **Then** cumple Conventional Commits.
3. **Given** un PR de Dependabot en backend o frontend, **When** se abre, **Then** pasa por el mismo CI y no se puede fusionar si falla.
4. **Given** una acción fijada por SHA con una versión nueva, **When** Dependabot la actualiza, **Then** el PR la sigue fijando por SHA.

---

### Edge Cases

- **Hallazgos que ya existen** (Trivy, Qodana o ESLint sobre el código y las dependencias actuales): se corrigen dentro de HU-08. Si uno es un falso positivo o no se puede corregir, se excluye de forma individual, versionada y con el motivo; no se desactiva el control completo.
- **Valores ficticios en pruebas o ejemplos** que Trivy tome por secretos: se excluyen de la misma forma individual.
- **Orden de activación**: la protección que exige el CI se aplica cuando las comprobaciones ya existen en `main`, para no dejar PR bloqueados esperando una comprobación que no se ejecuta.
- **PR que solo cambia documentación**: las comprobaciones obligatorias también informan su resultado y el PR no se queda pendiente.
- **Token de release-please ausente, vencido o sin permisos**: el workflow queda en rojo con el motivo, sin mostrar el token.
- **Fallo transitorio al publicar la imagen** (la release ya existe): se puede reintentar la publicación de esa misma versión sin crear otra.
- **Imagen rechazada por Trivy** (la release ya existe): esa versión queda sin imagen; la corrección sale en la siguiente versión.
- **Cambio de número de versión**: no rompe la construcción de las imágenes, ni con el release ni con Compose.
- **Servicio externo caído** (descarga de dependencias o de la base de vulnerabilidades): la comprobación queda en rojo, nunca en verde sin haberse ejecutado, y se puede reintentar.

## Requirements *(mandatory)*

### Functional Requirements

**Integración continua**

- **FR-001**: En backend y frontend, cada PR hacia `main` y cada push a `main` ejecuta el CI, que compila y prueba el proyecto.
- **FR-002**: El CI del backend ejecuta `mvn verify`, con la cobertura mínima del 80 % por módulo, Checkstyle y las pruebas con Testcontainers que existan.
- **FR-003**: Qodana (`qodana-jvm-community`) analiza el backend en el CI y lo hace fallar ante hallazgos de severidad crítica o alta.
- **FR-004**: El CI del frontend compila la web, ejecuta sus pruebas unitarias y ejecuta ESLint, que lo hace fallar ante cualquier error. ESLint se puede ejecutar también en local con un solo comando.
- **FR-005**: El CI no necesita credenciales de Spotify ni otros secretos de la aplicación.

**Seguridad**

- **FR-006**: Trivy revisa en el CI de backend y frontend las dependencias que se entregan, incluidas las transitivas, y falla ante vulnerabilidades `HIGH` o `CRITICAL` con corrección disponible.
- **FR-007**: Trivy revisa en el CI el contenido de ambos repositorios en busca de secretos y falla ante los de severidad `HIGH` o `CRITICAL`.
- **FR-008**: Las acciones de terceros de todos los workflows están fijadas por SHA de commit, con la versión indicada junto a él. Las herramientas y las imágenes de análisis usan versiones explícitas.
- **FR-009**: Cada workflow declara sus permisos y solo concede los que necesita; por defecto, lectura.
- **FR-010**: El código de un PR nunca se ejecuta con acceso a secretos del repositorio ni con permisos de escritura, si el PR viene de un fork o de Dependabot.

**Protección de `main`**

- **FR-011**: `main` está protegida en los tres repositorios: exige PR y rechaza push directo, push forzado y borrado, también al propietario.
- **FR-012**: En backend y frontend, `main` exige además que todas las comprobaciones del CI estén en verde para fusionar.

**Dependencias**

- **FR-013**: Dependabot está configurado en los tres repositorios para los ecosistemas que usa cada uno: Maven, Docker y GitHub Actions en backend; npm, Docker y GitHub Actions en frontend; imágenes de Compose en infra.
- **FR-014**: Los commits de Dependabot siguen Conventional Commits. Las actualizaciones de lo que se entrega (dependencias de la aplicación e imágenes base) usan un tipo que genera versión; las de acciones y herramientas de desarrollo, uno que no la genera.
- **FR-015**: En backend y frontend, cada PR de Dependabot pasa el CI antes de fusionarse. En infra se exige desde HU-09.

**Releases e imágenes**

- **FR-016**: En backend y frontend, release-please abre y mantiene el PR de release a partir de los Conventional Commits, con el número de versión y el CHANGELOG. Al fusionarlo se crean el tag y la release.
- **FR-017**: La versión declarada en el proyecto coincide con la versión publicada.
- **FR-018**: release-please usa un token propio de cada repositorio, limitado a ese repositorio y guardado como secreto, de modo que el CI se ejecuta en el PR de release.
- **FR-019**: Al crearse una release, el mismo workflow construye la imagen desde el código de esa versión, la analiza con Trivy y, solo si no hay vulnerabilidades `HIGH` o `CRITICAL` con corrección, la publica en GHCR con el número de versión como tag.
- **FR-020**: Las imágenes se pueden descargar desde el clúster sin credenciales: los paquetes de GHCR son públicos.
- **FR-021**: Las imágenes publicadas cumplen las mismas condiciones que las de HU-07: sin usuario administrador, sin código fuente, herramientas de construcción ni secretos.

**Documentación**

- **FR-022**: El README de backend y de frontend explica qué comprueba el CI, cómo ejecutar esas comprobaciones en local, cómo se publica una versión y dónde están las imágenes.
- **FR-023**: Los ajustes que no quedan versionados (protección de `main`, tokens y visibilidad de los paquetes) están documentados paso a paso en cada repositorio al que afectan, para poder repetirlos y revisarlos.

**Restricciones transversales**

- **FR-024**: El comportamiento de la API y de la web no cambia, incluso al corregir hallazgos de los análisis, y la ejecución en local y con Compose sigue funcionando.

### Key Entities *(include if feature involves data)*

- **Comprobación**: validación automática de un cambio (compilación y pruebas, análisis estático, vulnerabilidades y secretos), con resultado en verde o rojo.
- **Reglas de `main`**: condiciones para aceptar un cambio en cada repositorio.
- **Propuesta de actualización**: PR de Dependabot sobre una dependencia de un ecosistema.
- **Versión**: número, tag, release y entrada del CHANGELOG, independiente en cada repositorio.
- **Imagen publicada**: imagen de backend o frontend en GHCR, identificada por su versión.
- **Excepción de análisis**: hallazgo excluido de forma individual, con su motivo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100 % de los PR y de los push a `main` de backend y frontend muestran el resultado de todas las comprobaciones, sin pasos manuales.
- **SC-002**: El 100 % de los defectos introducidos a propósito se bloquean: en backend, prueba rota, cobertura insuficiente, violación de estilo, hallazgo de análisis, dependencia vulnerable y secreto; en frontend, error de compilación, prueba rota, error de lint, dependencia vulnerable y secreto.
- **SC-003**: El resultado del CI de un PR está disponible en menos de 15 minutos.
- **SC-004**: Los push directos a `main` se rechazan en los 3 repositorios.
- **SC-005**: Después de fusionar un PR de release, la imagen con esa versión se puede descargar sin credenciales en menos de 15 minutos, sin pasos manuales.
- **SC-006**: Hay al menos una versión publicada de backend y otra de frontend, cada una con su CHANGELOG y su imagen.
- **SC-007**: Los repositorios, las imágenes y los registros del CI contienen 0 secretos reales.
- **SC-008**: Todos los criterios de aceptación de HU-08 en el backlog quedan comprobados, por prueba automática o por revisión anotada.

## Assumptions

- **Ubicación de la historia** (decidida el 2026-11-27): la especificación, el plan y las tareas viven en el repositorio de infra. Los cambios de backend y frontend van en ramas `feature/08-ci-dependencies-releases` de cada repositorio.
- **Una sola historia**: cubre las fases 7 y 8 del ADR-0001 (CI y releases). La entrega es en este orden: CI en `main`, protección de `main`, Dependabot y releases.
- **Umbrales no definidos en el backlog**: Qodana falla con severidad crítica o alta, y ESLint con errores (las advertencias no bloquean).
- **Alcance de las dependencias revisadas por Trivy**: las que se entregan. Las de pruebas y desarrollo no bloquean; Dependabot propone sus actualizaciones.
- **Secretos**: se revisa el contenido de cada cambio, no el historial completo.
- **Aprobaciones**: el proyecto tiene una sola persona responsable, así que se exige PR sin aprobaciones.
- **Primera versión**: `0.1.0` en backend y frontend; los tags de imagen son el número de versión, sin `latest`.
- **Plataforma de las imágenes**: `linux/amd64`, la del clúster local previsto.
- **Construcción de imágenes en PR**: no forma parte del CI. Una actualización de imagen base que rompa la construcción se detecta al publicar la versión.
- **Plan de GitHub**: gratuito, con los tres repositorios públicos, lo que permite proteger `main`. No se usan servicios externos de pago ni cuentas fuera de GitHub.
- **Acciones manuales de la persona responsable**: crear los dos tokens de release-please y hacer públicos los paquetes de GHCR. Siguen pendientes en el ADR-0001.
- **Fuera de alcance**: PR automático en infra con el nuevo tag y su token, CI y release-please de infra, validación de Kustomize, Kubernetes y Argo CD (HU-09); Redis (HU-10) y Kafka (HU-11), incluidas sus pruebas con Testcontainers; firma de imágenes y despliegue.
- **Dependencia**: HU-05 y HU-07 integradas en `main` (comprobado el 2026-11-27 en los tres repositorios).
