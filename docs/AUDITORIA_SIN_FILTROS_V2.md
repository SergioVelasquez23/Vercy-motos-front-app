# Auditoría sin filtros V2 — Vercy Motos

**Fecha:** 14-jul-2026
**Contexto:** Segunda auditoría completa, pedida después de cerrar la mayoría de los puntos de la V1 (tests, CI, backups, logging, excepciones). Mismo trato: lo malo de frente, lo bueno también. Objetivo declarado: *"que esto se mantenga a largo plazo solo, sin yo mover casi nada"*.

Cobertura de esta pasada: backend completo (config, seguridad, servicios, integración DIAN), frontend Flutter (estructura, servicios, config), estado de git de ambos repos, CI/CD y datos.

---

## Veredicto en una frase

**El backend ya casi se cuida solo — pero hay una puerta trasera de SUPERADMIN que anula toda la seguridad que construiste, y el frontend es hoy la mitad del producto que nadie está cuidando: 136.000 líneas, cero tests, y un archivo de 6.300 líneas por el que pasa toda la plata.**

---

## 🔴 LO MUY GRAVE

### 1. Cualquier usuario sin roles (o cualquier error de BD) se convierte en SUPERADMIN

[JwtService.java:60-73](../src/main/java/com/prog3/security/services/seguridad/JwtService.java): al generar el token,

- si el usuario **no tiene roles asignados** → se le asigna `SUPERADMIN` "para pruebas";
- si ocurre **cualquier excepción** consultando los roles (un timeout de Mongo basta) → `SUPERADMIN` también.

Esto anula todo lo que arreglaste en la V1. `@EnableMethodSecurity`, los endpoints `eliminarTodo*` con rol ADMIN, el `RoleValidatorService` — todo eso valida contra los roles del token, y el token miente. Escenario concreto: un usuario nuevo se registra, nadie le asigna rol todavía, inicia sesión → su token dice SUPERADMIN → puede borrar la contabilidad completa. O peor: un atacante con credenciales de un usuario cualquiera solo necesita que la consulta de roles falle una vez.

Es probablemente el resto de un atajo de desarrollo ("para pruebas", dice el comentario dos veces), pero está en producción. **El fallback correcto es lo contrario: sin roles = sin permisos (lista vacía), y con error = fallar el login, no regalarlo.** Es un cambio de 4 líneas y es lo más urgente de todo este documento.

### 2. La contraseña de MongoDB sigue en el historial de git sin rotar en Atlas

Igual que en la V1. Decisión tuya pendiente; no insisto, solo dejo constancia de que sigue abierta y de que ningún avance del resto compensa esto: quien tenga esa credencial no necesita pasar por tu API.

### 3. CORS sigue abierto a cualquier origen con credenciales

[SecurityConfig.java:99](../src/main/java/com/prog3/security/configurations/SecurityConfig.java): `setAllowedOriginPatterns(List.of("*"))` + `setAllowCredentials(true)`, con el comentario "REVERTIR esta línea" y la lista real de orígenes (`allowedOrigins`) inyectada pero sin usar. Cualquier página web puede hacer requests autenticados con la sesión de tus usuarios. La solución está literalmente escrita a 4 líneas de distancia — falta resolver por qué no tomaba efecto en Render y activarla.

---

## 🟠 LO MALO — no tumba hoy, tumba después

### 4. La decisión contable de BNPL quedó aplicada en UN solo camino de los tres que arman pagos para la DIAN

Hoy (14-jul) decidiste la Postura B: Addi/Credilondon/Sistecredito se reportan como **Contado + Transferencia**. Se aplicó en `transformarPagosDesdePedido()` (el camino del flujo real `/invoices/auto-increment`). Pero `MatiasTransformer` tiene **tres** métodos que arman pagos, y los otros dos siguen con la lógica vieja:

- `transformarPagos(Factura)` ([MatiasTransformer.java:562](../src/main/java/com/prog3/security/services/integraciones/matias/MatiasTransformer.java)) — todavía reporta Addi como **Crédito(2)/47**, y todo lo demás como **Contado/10 fijo** sin mirar siquiera si fue tarjeta o transferencia. Este camino está vivo: lo usa `enviarFacturaAutomatica(Factura, Cliente)`.
- `transformarPagosDesdeDocumento(Documento)` (línea ~919) — misma lógica vieja de Addi. No le encontré callers (probablemente muerto), pero mientras exista es una trampa.

Una misma venta Addi puede salir como "Crédito" o "Contado" ante la DIAN según qué endpoint la facture. Para un ente que cruza información, la inconsistencia es peor que cualquiera de las dos posturas. Hay que unificar los tres métodos en uno solo (o hacer que los tres deleguen en la misma lógica) — esto además es el síntoma de fondo del punto 8.

### 5. Cero `@Transactional` en todo el backend

`grep -rn "@Transactional" src/main` → **0 resultados**. Pagar un pedido toca Pedido + CuadreCaja + Inventario + (ahora) Factura en operaciones separadas. Si el proceso muere a mitad (deploy, OOM, reinicio de Render), queda plata contada sin pedido pagado o stock descontado sin venta. Atlas ya es replica set — las transacciones funcionan sin config extra. Era el punto 7 del plan V1 y sigue exactamente igual. Los flujos que ameritan transacción: pagar pedido, cerrar caja, facturar documento (crear Factura + marcar Documento).

### 6. El frontend es la mitad del producto y nadie lo está cuidando

Este es el hallazgo estructural nuevo de esta auditoría. Todo el rigor de la V1 se aplicó al backend; el frontend quedó fuera del radar:

- **Cero tests.** 271 archivos Dart, ~136.000 líneas, ni un solo archivo en `test/`. El backend tiene 997 tests; el frontend, que decide cuánto cobrar, qué mandar a la DIAN y cómo se cierra la caja, tiene cero.
- **`facturacion_screen.dart` tiene 6.316 líneas** — más grande que cualquier clase del backend, incluido el `ReporteService` que la V1 señaló como "el archivo más grande del proyecto". Por ahí pasa toda venta. Le siguen `productos_screen.dart` (4.790), `crear_factura_compra_screen.dart` (4.134), `asesor_pedidos_screen.dart` (3.758). La lógica de negocio (mapeos de medios de pago, cálculo de montos, retenciones) vive dentro de widgets, imposible de testear.
- **Sin CI ni análisis estático automatizado**: nada corre `flutter analyze` en cada push.
- **La config de ambientes es ficticia**: en `api_config_new.dart`, `staging` y `production` apuntan a la **misma URL** de Render. No existe ambiente de pruebas (punto 11 de la V1, sigue pendiente) — cada prueba es contra producción, con datos reales y DIAN real.

Para "mantenerse solo a largo plazo", este repo necesita el mismo tratamiento que le diste al backend en la V1: tests de la lógica extraíble (empezando por los mapeos de pago y cálculos de facturación), partir los god-files, y un CI mínimo con `flutter analyze` + `flutter test`.

### 7. Trabajo valioso sin commitear ni pushear en ambos repos

Estado real de git hoy:

- **Backend**: la rama `refactor/matias-integration-service-split` no tiene upstream (nunca se ha pusheado). Encima del último commit hay cambios sin commitear que incluyen el fix de "A Crédito" ante la DIAN, la decisión BNPL, y la delegación de POS — correcciones fiscales que solo existen en tu disco.
- **Frontend**: **92 archivos modificados sin commitear** (todo el barrido de diálogos de error + fixes de esta sesión) y 1 commit sin push.

Un disco dañado hoy pierde trabajo fiscal ya decidido. Y el CI solo corre en `main` — nada de esto ha sido validado por el pipeline. Commitear/pushear/mergear es la acción más barata y más rentable de toda esta lista.

### 8. `MatiasIntegrationService`: el refactor va bien, pero dejó deuda propia

Bajó de 2.323 a 1.974 líneas (Nómina, DS, POS y Auditoría ya extraídos con tests). Lo que queda adentro y lo que la extracción dejó regado:

- `checkEnabledService()` copiado idéntico en **4 archivos**; `forceTypeDocumentId()` en **3** — en vez de vivir en `MatiasAuditService`, que se creó exactamente para eso.
- `enviarNotaCreditoDirecta`/`enviarNotaDebitoDirecta` son **no-ops silenciosos**: loguean un warning y devuelven `null` con ~30 líneas comentadas bajo TODO. Quien los llame cree que emitió una nota y no pasó nada.
- `construirLineas`/`crearLineaDesdeProducto` arma líneas de factura con **reflexión** (`getMethod`/`invoke`) y fallback silencioso a precio $0 — existiendo `MatiasTransformer` tipado en el mismo paquete.
- 5 setters `@Autowired(required = false)` siguen delatando ciclos de dependencias.
- Los 3 métodos de transformar pagos del punto 4 son parte de lo mismo: falta extraer Factura y NC/ND, que es donde vive esa triplicación.
- `PaymentService` (355 líneas de código muerto, hallazgo 7 de la V1) sigue sin decisión: ni borrado ni conectado.

### 9. Controllers de ejemplo/prueba vivos en producción

`MatiasIntegrationExampleController` expone `/api/facturas-matias-ejemplo/**` — endpoints reales que llaman `enviarFactura()` (el camino con la lógica de pagos vieja del punto 4) contra la DIAN real. También existe `WebSocketTestController`. Están autenticados (gracias al `anyRequest().authenticated()` de la V1), pero cualquier usuario logueado puede dispararlos, y son exactamente los caminos que NO reciben los fixes fiscales. Borrarlos (o moverlos a un profile `dev`) es una tarde.

### 10. El dashboard miente sobre el histórico (semana/mes/año) y va a seguir mintiendo un tiempo

Diagnóstico ya hecho hoy: las `Factura` solo se persisten desde el fix del 12-jul (`f185937`); todo lo facturado antes vive solo en `matias_transactions`. Por eso "hoy", "7 días", "30 días" y "año" muestran el mismo número. Se corrige solo hacia adelante, pero el histórico 2026 pre-12-jul no va a aparecer nunca salvo que se escriba la migración desde `matias_transactions` (los datos están: CUFE, tipo, fechas, estado). Decisión pendiente: migrar o aceptar el hueco.

### 11. Defaults de secretos que no deberían tener default

- `matias.webhook.secret=${MATIAS_WEBHOOK_SECRET:tu-token-secreto-muy-largo-y-complejo-2026}` — si la env var no está en Render, el "secreto" que valida los webhooks de Matias es una constante publicada en GitHub.
- `matias.api.password=${MATIAS_API_PASSWORD:DEMO123456}` — mismo patrón.

Un secreto con fallback no es un secreto. Quitar los defaults hace que la app falle ruidosamente al arrancar si falta la variable — que es lo correcto.

### 12. Los `findAll()` sin paginar no bajaron: 57 usos en ~30 archivos

La V1 reportó 46; hoy cuento 57 (el conteo exacto varía según el patrón, pero la dirección es clara: no está bajando). Los que crecen con las transacciones siguen siendo los mismos: `CuadreCajaService`, `PedidosAdminService`, `ReporteService`, y ahora también `DocumentoService` y `DeudaService`. Con el plan pago de Render ya activo (más memoria) esto duele menos hoy, pero es la clase de problema que aparece de golpe un sábado a mediodía dentro de un año.

---

## ✅ LO QUE ESTÁS HACIENDO BIEN — y esta vez es mucho más

1. **El ciclo V1 → correcciones fue real, no cosmético.** De los 13 puntos del plan V1: backups diarios probados con restauración real (14.096 docs, 0 errores), CI que bloquea (`mvn verify`, sin `-DskipTests`), 997 tests en 63 archivos, 648 printlns migrados a SLF4J con niveles, plan pago de Render activo (`plan: starter` ya commiteado — adiós cold starts). Eso es más de la mitad del plan ejecutado en días.
2. **La cadena de errores hoy es profesional de punta a punta.** `BusinessException`/`ResourceNotFoundException` con `ErrorCode` y status HTTP correcto en los ~20 servicios (barrido de hoy), `GlobalExceptionHandler` que lo respeta, y en el frontend un diálogo centrado y legible en vez del SnackBar perdido. El usuario ve "Ya existe un cliente con esa identificación", no "Error interno del servidor: 409 CONFLICT...".
3. **El refactor de Matias tiene el patrón correcto**: extraer con tests propios + fachada que delega + tests de delegación. Nómina, DS, POS y Auditoría ya salieron así. Es exactamente cómo se desarma un god-class sin romper nada.
4. **Piensas lo fiscal como negocio, no como código.** La conversación de hoy sobre Contado/Crédito y medios de pago ante la DIAN (y decidir la Postura B por flujo de caja real) es el tipo de decisión que la mayoría de sistemas "contables" nunca se plantea — solo mandan lo que sea y ya.
5. **La auditoría anterior funcionó como herramienta viva**: se actualizó con cada avance, con fechas y evidencia. Este documento existe porque el anterior sirvió.
6. **Sigues corrigiendo el mismo día que se detecta** — el fix de "A Crédito" → Contado/Consignación se diagnosticó y corrigió en la misma conversación en que lo reportaste.

---

## 📋 PLAN DE ACCIÓN V2

### HOY (no del mes — de hoy)

| # | Acción | Costo |
|---|--------|-------|
| 1 | **Quitar el fallback SUPERADMIN de `JwtService`**: sin roles → lista vacía; error → excepción (login falla). | 15 min + 1 test |
| 2 | **Commitear y pushear ambos repos** (backend: rama + PR a main para que el CI corra; frontend: los 92 archivos). | 30 min |

### ESTA SEMANA

| # | Acción |
|---|--------|
| 3 | Unificar los 3 `transformarPagos*` de `MatiasTransformer` en una sola lógica con la decisión BNPL (Postura B) — y test que cubra Addi/Sistecredito/Crédito/mixto por los tres caminos. |
| 4 | Borrar `MatiasIntegrationExampleController` y `WebSocketTestController` (o profile `dev`). |
| 5 | Quitar los defaults de `matias.webhook.secret` y `matias.api.password`. |
| 6 | CORS: activar la lista real (el bean ya existe). |
| 7 | Decidir sobre el histórico del dashboard: migrar desde `matias_transactions` o aceptar el hueco documentándolo. |

### ESTE MES

| # | Acción |
|---|--------|
| 8 | `@Transactional` en pagar-pedido, cerrar-caja y facturar-documento. |
| 9 | Frontend: CI mínimo (`flutter analyze` + `flutter test`) y primeros tests de la lógica pura (mapeos de pago de `facturacion_screen`, `DashboardHelper`, modelos). Extraer esa lógica de los widgets es el prerequisito. |
| 10 | Terminar el split de Matias: extraer Factura y NC/ND, centralizar `checkEnabledService`/`forceTypeDocumentId`, borrar los no-ops de NC/ND directa y la reflexión de `construirLineas`. Decidir `PaymentService` (mi voto: borrarlo, git lo recuerda). |
| 11 | Paginar los `findAll()` de `CuadreCajaService`, `PedidosAdminService`, `ReporteService`, `DocumentoService`. |

### ESTE TRIMESTRE

| # | Acción |
|---|--------|
| 12 | Ambiente de staging real (profile + DB separada + sandbox de Matias) — hoy "staging" es producción con otro nombre. |
| 13 | Partir `facturacion_screen.dart` (6.316L) igual que partiste los God Controllers del backend. |
| 14 | Atlas (cuando decidas) y el renombre `com.prog3.security` → `com.vercymotos.api`. |

---

## La reflexión final

La V1 terminaba diciendo que un SaaS que se mantiene solo se logra cuando *nada depende de que tú te acuerdes*. Avanzaste en serio: el CI prueba solo, el backup corre solo, los errores se explican solos. Pero esta pasada encontró las dos excepciones que confirman la regla: una línea de 2023 que regala SUPERADMIN "para pruebas" (nadie se acordaba de que existía) y un frontend entero que depende de que tú te acuerdes de cómo funciona, porque no hay ni un test que lo recuerde por ti. El backend ya aprendió a cuidarse; ahora le toca al frontend — y a esa línea, hoy mismo.
