# Auditoría sin filtros — Vercy Motos

**Fecha:** Julio 2026 (actualizado 14-jul-2026)
**Contexto:** Me pediste que te diga qué haces bien y qué haces muy mal, sin miedo, con el objetivo de tener un SaaS estable de facturación electrónica, inventario y contabilidad que se mantenga solo a largo plazo.

Esto no es el análisis académico de `ANALISIS_BUENAS_PRACTICAS.md`. Esto es lo que encontré revisando el código real, ordenado por lo que de verdad puede matar tu negocio. Los puntos que ya resolviste se sacaron de esta lista — quedan solo los pendientes.

---

## Veredicto en una frase

**Ya cerraste la puerta principal — falta cerrar dos ventanas.** La API dejó de estar abierta al público (`.anyRequest().authenticated()` + `@EnableMethodSecurity` ya están activos, los endpoints `eliminarTodo*` ya exigen rol ADMIN, las contraseñas ya usan BCrypt con migración transparente y ya no se loguean en texto plano). Lo que sigue pendiente y sí puede seguir mordiendo: la contraseña de MongoDB filtrada en el historial de git sigue sin rotar en Atlas, y el CORS sigue abierto a cualquier origen con credenciales. Mientras esas dos sigan así, cualquiera que haya visto el repo puede conectarse directo a tu base de datos, o un sitio malicioso puede hacer requests autenticados usando la sesión de un usuario tuyo.

---

## 🔴 LO MUY GRAVE — esto puede acabar el negocio esta semana

### 1. La contraseña de tu MongoDB de producción está commiteada en git

El código ya no tiene el password hardcodeado como default (`spring.data.mongodb.uri=${MONGODB_URI}`, sin fallback) — pero eso no borra el historial. La credencial `elemetrocks24_db_user` sigue en `HEAD` de git, o sea que cualquier persona que haya visto el repo (o lo vea en el futuro, o si algún día se hace público) puede conectarse **directamente** a tu Atlas, sin pasar por tu API, y leer/modificar/borrar todo.

**No basta con que el código ya no la muestre: hay que rotarla en Atlas.** Esto sigue pendiente por decisión tuya, no lo vuelvo a mencionar salvo que preguntes.

### 2. CORS abierto con credenciales

[SecurityConfig.java](../src/main/java/com/prog3/security/configurations/SecurityConfig.java): `allowedOriginPatterns("*")` + `setAllowCredentials(true)`. Traducción: cualquier página web del mundo puede hacer requests autenticados a tu API desde el navegador de tus usuarios. El comentario en el propio código dice que es temporal "mientras se investiga por qué la lista real no toma efecto en producción" — ya tienes la lista de orígenes reales escrita (`websocket.allowed.origins`) y hasta el bean `corsConfigurationSource()` preparado para usarla; solo falta revertir el hardcodeo a `"*"` una vez resuelvas por qué no tomaba efecto en Render.

---

## 🟠 LO MAL — no te tumba hoy, pero te tumba en 6 meses

**Progreso (13-jul-2026):** ✅ **completo.** Se pasó de **2 archivos de test para 326+ archivos Java** a **58 archivos de test con 976 tests**, todos en verde. Ya no queda ningún servicio de negocio real sin test — se cubrió el resto de la lista pendiente, incluyendo los dos archivos más grandes y críticos del proyecto:

- **`ReporteService`** (2,356 líneas, el archivo más grande de todo el proyecto): dashboard, libro contable, export mensual, reportes de ventas/clientes/productos — 54 tests.
- **`MatiasIntegrationService`** (integración con la DIAN — la clase más crítica del negocio, ver punto 7): autenticación, envío de facturas/notas crédito-débito, y las 6 sub-validaciones que protegen contra el envío de facturas mal calculadas a la DIAN. Documento Soporte, POS, Nómina y Auditoría ya se extrajeron a servicios propios con sus propios tests (ver punto 7) — entre los 5 archivos suman 136 tests.
- `WebhookService` y `DocumentoSoporteService` (paquete `integraciones.matias`).
- `TelegramService`, `TelegramGastosService`, `TelegramCuentasPorPagarService`.
- `BackupInventarioService`, `RecuperacionInventarioService`, `WebSocketNotificationService`.
- `CategoriaService` y `CodigoBarrasService`.
- Los 8 servicios delgados de infraestructura (`CacheOptimizationService`, `FileStorageService`, `LoggingService`, `EncryptionService`, `MemoryMonitoringService`, `RequestURL`, `ResponseService`, `InitialDataService`).

Y ya estaba cubierta la lógica de negocio real de:e el 

- **Pedidos y pagos**: `PedidoService`, `PedidoCalculosService`, `PedidoAsesorService`, `PedidosAdminService`, `ProductoPedidoService`, `PedidosPagoController`.
- **Facturación**: `FacturaCalculosService`, `TaxCalculationService`, `CotizacionService`.
- **Caja**: `CuadreCajaService`, `CuadreCajaCalculoService`, `CuadreCajaPedidoService`, `ResumenCierreService`, `GastoService`, `IngresoCajaService`, `TipoGastoService`.
- **Cartera**: `CarteraService`, `DeudaService`.
- **Inventario**: `InventarioService`, `InventarioIngredientesService`, `MovimientoStockService`, `TrasladoService`.
- **Compras**: `CompraService`, `ProveedorService`, y los 5 parsers de factura de compra en PDF (AKT, Cassarella, IdLaser, Industria IP, Inversiones P&G) + su factory — probados generando PDFs reales en memoria con PDFBox, no con texto simulado.
- **Clientes**: `ClienteService`, `ClienteImportService` (probado con un Excel real generado en memoria con Apache POI).
- **Documentos y negocio**: `DocumentoService`, `NegocioInfoService`.
- **Seguridad**: `JwtService`, `RoleValidatorService`, `ValidatorsService`.
- Además de los 2 que ya existían: `MatiasTransformer`.

Escribir esos tests sacó a la luz **8 bugs reales** que estaban en producción sin que nadie lo notara (7 ya corregidos, el 7º es un hallazgo de diseño pendiente de decisión):

1. `GastoService` guardaba el monto en $0 al crear/editar un gasto sin `subtotal` explícito (el frontend actual siempre lo manda, así que no se disparaba en la práctica, pero cualquier otro caller futuro caía en la trampa).
2. `MovimientoStockService` nunca detectaba productos tipo "servicio" por un choque de mayúsculas/minúsculas contra `Producto.getTipoItem()` — generaba movimientos de stock fantasma en cada venta de un servicio.
3. `PedidosAdminService`: el `catch (IllegalArgumentException)` no atrapaba `DateTimeParseException` (no es su subclase), así que una fecha con formato inválido tiraba un error crudo de 500 en vez del `BusinessException` 400 esperado.
4. `InventarioIngredientesService`: NPE al crear el registro de `Inventario` para un ingrediente sin stock/stock mínimo inicial (`Double` nulo pasado a un setter `double`) — el descuento de inventario fallaba en silencio, atrapado por un catch exterior.
5. Modelo `Cliente`: `generarRazonSocial()` se bloqueaba a sí misma — un cliente "Persona Natural" creado en el orden nombres→apellidos (el orden natural de un formulario) quedaba con la razón social truncada al nombre de pila. Ese dato va directo a la factura electrónica DIAN.
6. `ClienteImportService`: el contador `actualizados` nunca se incrementaba, así que el resumen de una importación masiva por Excel reportaba todo como "creado" aunque en realidad fueran actualizaciones de clientes existentes (los datos sí quedaban bien guardados; solo el resumen mentía).
7. `PaymentService` (355 líneas) resultó ser **código muerto**: `procesarPago`, `agregarPagoParcial`, `editarPagoParcial` y `eliminarPagoParcial` no tienen ningún llamador real en todo el proyecto — el flujo de pagos vive directamente dentro de `PedidosPagoController`. De paso explica un bug latente que nunca se manifestó (`PagarPedidoRequest.getMonto()` retorna solo la propina, no el monto pagado) porque el código que lo tenía nunca se ejecuta. Pendiente decidir: borrarlo o terminar de conectarlo.
8. `ReporteService.getVentasProductosAgrupado()`: el campo `cantidadTotal` se inicializaba como `Integer` pero se acumulaba sumando un `double` (la cantidad del item), lo que lo convertía silenciosamente en `Double` tras la primera suma — la siguiente acumulación hacía un cast `(Integer)` sobre un `Double` y lanzaba `ClassCastException`. El reporte "ventas por producto agrupado" se rompía **cada vez que un mismo producto aparecía más de una vez** en el período (el caso normal, no el raro). Ya corregido.

**✅ Lo que faltaba de este punto ya se cerró (13-jul-2026):** `.github/workflows/ci.yml` corre `mvn verify` en cada push/PR a `main`, y `render.yaml` ya no tiene `-DskipTests` (`buildCommand: mvn clean install`) — el build de Render falla si algún test falla, en vez de subir código roto. Los 976 tests dejaron de ser una red de seguridad manual y pasaron a ser un gate real.

Manejas dinero, impuestos y obligaciones ante la DIAN, así que esto no era opcional. Los bugs de descuento duplicado que has ido parchando en `PedidosPagoController`, y el `ClassCastException` que se encontró en `ReporteService`, son exactamente el tipo de bug que estos tests ya habrían atrapado antes de afectar plata real — y ahora, con CI, el próximo bug de ese tipo no llega a `main` si rompe un test.

### 4. ¿Tienes backups? Casi seguro que no

Si estás en Atlas M0 (tier gratuito), **no tiene backups automáticos**. Si alguien ejecuta un `eliminarTodoPorFechas()` (ya protegido con rol ADMIN, pero un admin también se equivoca) o si tú mismo cometes un error, **no hay vuelta atrás: se pierde la contabilidad completa del negocio**. Para un sistema de facturación esto es existencial, no opcional.

**Progreso (13-jul-2026):** ✅ **completo y probado de punta a punta.** `.github/workflows/backup-mongodb.yml` corre `mongodump` diario (3am Colombia) contra Atlas y sube el archivo comprimido a Google Drive vía `rclone`, con retención de 30 días — no depende de que Render esté corriendo. Se probó manualmente ("Run workflow"): corrió en 37s y subió el backup a Drive sin problema. Y lo más importante — **la restauración también se probó de verdad**: se bajó el backup, se restauró contra un cluster Atlas M0 separado (de prueba, no producción) con `mongorestore`, y los 33 colecciones (14,096 documentos: `producto`, `pedido`, `clientes`, `documentos`, `facturas`, etc.) se restauraron sin errores. El backup sirve. Instrucciones completas de setup y restauración (incluye restaurar una sola colección para un incidente puntual) en `docs/BACKUPS.md`.

### 5. 533 `System.out.println` en 28 archivos

**Progreso (13-jul-2026):** ✅ **completo.** Los 648 `System.out.println`/`System.err.println` que quedaban en `src/main` (30 archivos — el conteo real había crecido desde la auditoría original) se migraron a SLF4J (`log.debug/info/warn/error`) con niveles reales: trazas de diagnóstico a `debug` (invisibles en producción salvo que se active el nivel), eventos de negocio genuinos (cancelaciones, cierres de caja, migraciones de datos) a `info`, anomalías recuperables (stock insuficiente, cuadre no encontrado) a `warn`, y errores con la excepción real adjunta (antes se perdía el stacktrace) a `error`. Se priorizó por tamaño empezando por `ReporteService` (96 → 0) y los servicios de caja (`CuadreCajaCalculoService`, `CuadreCajaService`, `ResumenCierreService`, `CuadreCajaPedidoService`), siguiendo con inventario, compras, pedidos, cartera y el resto de servicios/controllers. `mvn test` sigue en 1002/1002 tras cada tanda. `LoggingService` + `logback-spring.xml` ahora sí se usan de punta a punta — el ruido en producción es filtrable por nivel.

### 6. `findAll()` sin paginar cargando colecciones completas en memoria

Sigue el patrón "traer toda la colección y filtrar en memoria" en varios archivos. Con 500 transacciones/día, en un año son ~180K documentos cargados en un heap acotado con `-XX:+ExitOnOutOfMemoryError`. El resultado puede ser el proceso **matándose solo** en horario laboral.

**Progreso (10-jul-2026):** ya se corrigieron los peores casos en `PedidosQueryController` (búsqueda y "sin pagar" ahora usan queries de Mongo en vez de cargar todo), `CompraService` (el cuadre de caja abierto ya no se busca con `findAll()+filter`, sino con la query `findByEstado` que ya existía) y `InventarioController` (el endpoint principal y el de movimientos ya aceptan paginación opcional `page`/`size`, retrocompatible). Se pasó de 51 a 46 ocurrencias en 27 archivos. Los índices compuestos (`@CompoundIndex`) para `Pedido` ya existen. Queda pendiente el resto — sobre todo `CuadreCajaService`, `PedidosAdminService` y `ReporteService`, que sí crecen con el volumen de transacciones.

### 7. `MatiasIntegrationService`: 2,323 líneas

La clase que habla con la DIAN — **la más crítica del negocio** — es la más grande, la menos testeable, y tiene 6 setters con `@Autowired(required = false)` que delatan ciclos de dependencias sin resolver.

**Progreso (14-jul-2026):** 🟡 **en curso.** Bajó de 2,323 a 1,974 líneas. Se extrajeron a servicios propios (cada uno con su test): `MatiasAuditService` (auditoría de transacciones, compartida entre todos), `MatiasNominaService` (nómina electrónica), `MatiasDocumentoSoporteApiService` (documento soporte), `MatiasPosService` (documento POS). `MatiasIntegrationService` quedó como fachada delegando en una línea a cada uno — los controllers no cambiaron. Los setters `@Autowired(required = false)` bajaron de 6 a 5, pero siguen ahí.

Quedan por extraer Factura (automática y con Transformer) y Notas Crédito/Débito — son los que más lógica de construcción de request todavía tienen adentro. Y de paso, la extracción dejó deuda propia que hay que resolver antes de seguir partiendo la clase:

- `checkEnabledService()` y `forceTypeDocumentId()` quedaron copiados y pegados en 4 y 3 archivos respectivamente en vez de vivir una sola vez en `MatiasAuditService` (que se creó justo para esto).
- `enviarNotaCreditoDirecta`/`enviarNotaDebitoDirecta` son no-ops silenciosos: solo loguean warning y devuelven `null`, con ~30 líneas de implementación comentada bajo un TODO sin resolver desde antes de esta extracción.
- `construirLineas`/`crearLineaDesdeProducto` arma líneas de factura con reflexión (`getMethod`/`invoke`) sobre un `Object` en vez de usar `MatiasTransformer`, que ya existe en el mismo paquete para eso — si el objeto no tiene exactamente los getters esperados, cae en un catch silencioso y genera una línea con precio 0.

### 8. Detalles que delatan el origen del proyecto

`pom.xml`: `<groupId>com.jcg</groupId>`, `<description>Demo project for Spring Boot</description>`, paquete raíz `com.prog3.security` (¿Programación 3?). El proyecto nació como trabajo de clase y creció hasta SaaS sin que nadie renombrara la casa. No es urgente, pero un `groupId com.vercymotos` y paquete `com.vercymotos.api` es una tarde de refactor con el IDE y señala que esto ya es un producto, no una tarea.

---

## ✅ LO QUE ESTÁS HACIENDO BIEN — y es más de lo que crees

Siendo igual de directo en la otra dirección:

1. **El producto funciona y resuelve un problema real.** Integración DIAN vía Matias con FE, NC, ND, DS, POS y nómina — eso es *difícil* y lo tienes andando. La mayoría de la gente que critica código nunca ha puesto una factura electrónica en producción.
2. **Documentas como muy pocos.** `VISION.md`, `PLAN_DIAN_COMPLETO`, `ANALISIS_BUENAS_PRACTICAS`, `SOLID_ANALYSIS`, diagramas de clases. Un dev nuevo (o una IA) puede entender el proyecto en una hora. Esto vale oro y casi nadie lo hace.
3. **Estás refactorizando en la dirección correcta y se nota en el git.** Los God Controllers de 2,300+ líneas ya se partieron en `PedidosPagoController`, `PedidosQueryController`, `PedidoCalculosService`, etc. La inyección por constructor ya es el patrón dominante. El `GlobalExceptionHandler` con `BusinessException`/`ResourceNotFoundException` está bien diseñado, y desde el 14-jul-2026 ya lo usan de verdad los ~20 servicios que antes tiraban `RuntimeException`/`ResponseStatusException` crudos — esos se colaban por el catch-all genérico y siempre volvían como 500 con el mensaje envuelto ("Error interno del servidor: 409 CONFLICT ..."), sin importar el status real de la excepción original.
4. **Hay diseño real, no solo CRUD:** Strategy para impuestos, Value Objects (`Money`, `Address`), DTOs separados del dominio, transformer centralizado para Matias, auditoría con `AuditoriaLogRepository`, alertas por Telegram, rate limiting. Piensas en arquitectura.
5. **Piensas en operación:** health checks, Actuator, gzip, tuning de GC, control de sesiones, WebSockets para notificar la caja en tiempo real. La mentalidad de "que se mantenga sola" ya la tienes.
6. **Cuando te dicen que algo está mal, lo corriges de verdad y rápido.** Cerraste la API, migraste a BCrypt con migración transparente, sacaste el log de contraseñas, le pusiste rol ADMIN a los endpoints destructivos y empezaste a paginar — todo eso en el mismo día que se detectó. Esa velocidad de reacción es la diferencia entre deuda técnica normal e incidente.
7. **Los comentarios de tu código explican el *porqué* de los bugs corregidos** (el descuento duplicado, el redondeo de punto flotante). Eso es madurez — la mayoría solo parcha y olvida.

---

## 📋 PLAN DE ACCIÓN — lo que queda pendiente

### YA (mientras decides lo de Atlas)

| # | Acción | Dónde |
|---|--------|-------|
| 1 | CORS: reemplazar `*` por la lista real de orígenes (ya la tienes en `websocket.allowed.origins`, y el bean ya está listo, solo falta usarlo) | `SecurityConfig.java` |

### ESTA SEMANA (asegurar los datos y el dinero)

| # | Acción |
|---|--------|
| 2 | ✅ **Hecho y probado (13-jul-2026):** `.github/workflows/backup-mongodb.yml` corre diario, `mongodump` → Google Drive vía `rclone`. Restauración probada de verdad contra un cluster de prueba (14,096 documentos, 0 errores). Detalles en `docs/BACKUPS.md`. |
| 3 | ✅ **Hecho (13-jul-2026):** `.github/workflows/ci.yml` corre `mvn verify` (976 tests) en cada push/PR a `main`. `render.yaml` ya no tiene `-DskipTests` — el build de Render ahora falla si algún test falla, en vez de subir código roto. |

### ESTE MES (estabilidad de largo plazo)

| # | Acción |
|---|--------|
| 4 | Confirmar y desplegar el cambio de plan de Render a uno pago (ya está editado localmente en `render.yaml`/`Dockerfile` pero sin commitear/desplegar) — elimina cold starts. |
| 5 | ✅ **Hecho y superado** (13-jul-2026): 976 tests en 58 archivos — meta original era 20. Cubre pedidos/pagos, caja, cartera, inventario, compras, clientes, seguridad, `ReporteService`, `MatiasIntegrationService`, integraciones (Matias/Telegram) y los servicios de infraestructura. No queda ningún servicio de negocio sin test. Único pendiente real: quitar `-DskipTests` + armar el CI (ver punto 3). |
| 6 | Terminar la paginación de `findAll()` en `CuadreCajaService`, `PedidosAdminService` y `ReporteService` — son los que más crecen con el volumen de transacciones. |
| 7 | `@Transactional` en pago + caja (Atlas ya es replica set, funciona sin config extra). |
| 8 | ✅ **Hecho (13-jul-2026):** los 648 `System.out.println`/`System.err.println` de `src/main` (30 archivos) migrados a SLF4J con niveles reales (debug/info/warn/error). Ver detalle en el punto 5. |

### ESTE TRIMESTRE (calidad sostenida)

| # | Acción |
|---|--------|
| 9 | 🟡 **En curso (14-jul-2026):** de 2,323 a 1,974 líneas — ya se extrajeron Auditoría, Nómina, Documento Soporte y POS (ver punto 7). Falta Factura y Notas Crédito/Débito, y limpiar la duplicación (`checkEnabledService`/`forceTypeDocumentId`) que dejó la extracción. |
| 10 | `@ConfigurationProperties` para los grupos `matias.*` y `telegram.*` (hoy duplicados en 3 clases cada uno). |
| 11 | Ambiente de staging (profile + DB separada + ambiente de pruebas de Matias) para no probar contra producción. |
| 12 | Renombrar `com.prog3.security` → `com.vercymotos.api` y limpiar el `pom.xml` de "Demo project". |
| 13 | Los puntos de prioridad BAJA/MEDIA ya documentados (`@Valid` masivo, `@Builder`, versionado `/api/v1`). |

---

    ## La reflexión final

    Ya demostraste lo que importaba probar: que cuando algo está mal de verdad, lo arreglas rápido y bien — no con parches, con la solución correcta (migración transparente de BCrypt, roles reales en vez de anotaciones decorativas, paginación retrocompatible, backups probados de punta a punta, CI que sí bloquea). El trabajo de fondo (tests, CI, backups) ya dejó de ser una promesa: corre solo. Lo que queda son dos decisiones tuyas pendientes (Atlas, CORS) y trabajo incremental (paginación, partir `MatiasIntegrationService`) que ya está en marcha. Un SaaS que "se mantenga solo" no se logra con más features; se logra cuando **nada depende de que tú te acuerdes**: la seguridad rechaza sola, el CI prueba solo, el backup corre solo, el índice pagina solo.
