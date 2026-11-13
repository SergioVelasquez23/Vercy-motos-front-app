# Plan: qué conviene implementar de la lista "20 cosas antes de lanzar tu web"

**Contexto:** la lista está pensada para sitios de marketing (landing, hero, testimonios).
Vercy Motos es una **app interna de punto de venta / ERP**, donde el usuario es un
cajero o asesor que factura rápido y no un visitante que hay que convencer. Por eso el
criterio de decisión es: *¿ayuda a facturar más rápido, a equivocarse menos o a que cargue
antes?* Si solo "se ve bonito", se descarta.

El estado actual se verificó en el código (fecha de revisión: 12-nov-2026).

## Resumen

| # | Ítem | Veredicto | Prioridad |
|---|------|-----------|-----------|
| 1 | Animaciones suaves al hacer scroll | Descartar | — |
| 2 | Microinteracciones con botones | Implementar (acotado) | Media |
| 3 | Estados hover | Implementar (barato) | Baja |
| 4 | Mobile responsiveness | Auditar y corregir | **Alta** |
| 5 | Navegación móvil | Ya está | — |
| 6 | Favicon custom | Ya está (falta un detalle) | Baja |
| 7 | Botón de volver arriba | Implementar en listados largos | Baja |
| 8 | Loading screen / skeleton | Parcial: falta skeleton | Media |
| 9 | Transiciones entre pantallas | Opcional | Baja |
| 10 | Animación del hero | Descartar | — |
| 11 | CTA repetido | Descartar | — |
| 12 | Formulario de contacto | Descartar | — |
| 13 | Validación | Implementar | **Alta** |
| 14 | Exit / error | Implementar (interpretación abajo) | **Alta** |
| 15 | Modo oscuro | Ya está | — |
| 16 | Idioma | Descartar | — |
| 17 | Botones de redes sociales | Descartar | — |
| 18 | Testimonios | Descartar | — |
| 19 | Optimización de velocidad | Implementar | **Alta** |
| 20 | (vacío en la imagen) | — | — |

---

## Detalle

### Descartar (no aplican a un POS interno)

- **1, 10 – Animaciones de scroll y del hero:** no hay hero ni páginas de scroll
  narrativo. Una animación de entrada en listados de 3.000+ productos solo añade latencia.
- **11, 12, 17, 18 – CTA repetido, formulario de contacto, redes sociales, testimonios:**
  son elementos de captación de clientes. La app no tiene visitantes anónimos: requiere login.
- **16 – Idioma:** el negocio es colombiano y la app ya fija `es_CO`
  ([main.dart:91](../lib/main.dart#L91)). Traducirla no aporta valor.

### Ya está

- **5 – Navegación móvil:** `app_shell.dart` usa `Drawer` en móvil y menú lateral en escritorio.
- **15 – Modo oscuro:** existe `ThemeProvider` y se guarda en `SharedPreferences`.
  Único ajuste opcional: hoy el valor inicial es `ThemeMode.light`; se podría usar
  `ThemeMode.system` para quien no haya elegido nada.
- **6 – Favicon:** ya usa `icons/logo.png` y hay manifest con nombre y `theme_color`.
  **Falta un detalle:** `web/index.html:23` tiene `<meta name="description" content="A new Flutter project.">`
  (el valor por defecto). Cambiarlo a "Sistema de gestión para Vercy Motos". Es de 1 minuto.

### Implementar

**4 – Mobile responsiveness (Alta).** Hay ~210 usos de `MediaQuery`/`LayoutBuilder`, o sea,
hay trabajo hecho, pero nunca se auditó pantalla por pantalla. Pantallas críticas donde un
cajero usa el teléfono o una tablet: facturación, caja, pedidos del asesor, productos.
- Probar a 360 px y 768 px de ancho. Buscar desbordes (`RenderFlex overflowed`) y botones fuera de alcance.
- Entregable: lista de pantallas con problemas y su corrección.

**13 – Validación (Alta).** Es el hueco más claro y ya lo señala `CLAUDE.md`:
- `MilesInputFormatter` se usa en **4 archivos**, pero hay 25+ campos de monto
  (precio, costo, valor, monto). Sin él, `double.tryParse` puede leer mal un monto con puntos de miles.
- Hay 24 `validator:` frente a 53 `TextFormField`: casi la mitad de los campos no se validan.
- Acción: revisar cada campo de monto, añadir `MilesInputFormatter` y un validador (obligatorio, mayor que 0, no negativo).

**14 – Exit / error (Alta).** En el video suele ser un "popup al salir" de marketing; aquí
lo traduzco a lo que sí sirve en un POS:
- **Salir con datos sin guardar:** confirmar con `PopScope` al abandonar facturación,
  crear compra o editar producto con cambios pendientes. Ya existen borradores
  (`draftProvider`), así que parte de la infraestructura está.
- **Pantalla de error útil:** hoy hay `errorBuilder` en el router y `FlutterError.onError`,
  pero no un estado "sin conexión / error del servidor" con botón **Reintentar**.
  Hacerlo un widget compartido en `widgets/common/`.

**19 – Optimización de velocidad (Alta).**
- `build/web/main.dart.js` pesa **7,2 MB** y no hay ningún `deferred as` en el código:
  todo se descarga al abrir la app.
- Acciones, de mayor a menor retorno:
  1. Cargar en diferido las pantallas pesadas y poco usadas (reportes, exportación a Excel/PDF, DIAN).
  2. Revisar la advertencia de compatibilidad con WebAssembly que muestra `flutter build web`
     y evaluar `--wasm`.
  3. Comprobar que los headers de caché de `firebase.json` cubren los assets estáticos.
- Medir antes y después con Lighthouse. Ver también `docs/INFORME_RENDIMIENTO_PANTALLAS.md`.

**8 – Loading / skeleton (Media).** Ya existe un `#loading` en `index.html`, pero dentro de la
app hay **147** `CircularProgressIndicator` y ningún skeleton. En listados (productos,
facturas, pedidos) un skeleton se siente más rápido y evita que la pantalla "salte".
Hacerlo como widget compartido (`widgets/common/skeleton_list.dart`) y aplicarlo primero a productos y facturas.

**2 – Microinteracciones con botones (Media, acotado).** No hace falta animar todo. Lo útil:
el botón de acción (guardar, cobrar) debe mostrar estado de carga y quedar deshabilitado
mientras viaja la petición, lo que refuerza el `SubmitGuard` existente y evita dobles clics.
Ya existe `GradientActionButton`; es el sitio natural para agregarlo.

**3 – Hover (Baja).** Hay ~75 `InkWell`/`MouseRegion`, así que muchos ya responden. Revisar
que filas de tablas y tarjetas clicables muestren cursor de mano y un resaltado. Se puede
resolver en el `ThemeData` (`hoverColor`) sin tocar pantalla por pantalla.

**7 – Volver arriba (Baja).** Solo en listados largos (productos ~3.200, pedidos ~4.600).
Un widget compartido que aparezca tras hacer scroll. Poco valor si la paginación ya se usa.

**9 – Transiciones (Baja / opcional).** Se puede definir una transición suave en
`pageTransitionsTheme` o en `GoRoute`. Cuidado: una transición lenta frena a quien navega
todo el día. Si se hace, que sea un fundido corto (≤150 ms).

---

## Estado

**Fase 1: hecha (12-nov-2026), sin commitear ni desplegar.**
- `meta description` corregida en `web/index.html`.
- Montos con `MilesInputFormatter` + lectura con `CurrencyUtils.parse/parseDecimal` en: productos
  (precio, costo), facturación (los 10 montos del pago múltiple), caja (apertura/efectivo y cierre),
  abonos por pagar/cobrar, monto total de cuenta por pagar, deudas, gastos programados,
  ingresos de caja, compras (costo/precio/valor unitario) y cotizaciones.
- **Bug de base corregido:** `CurrencyUtils.parseDecimal("1.500")` devolvía 1,5 (y `"1.500.000"`, 1500)
  en campos con `decimalDigits: 2`. Afectaba al valor unitario de facturación cuando el cajero
  tecleaba un precio. Ahora una agrupación de miles pura se lee como miles.
- Widget compartido `widgets/common/error_retry_view.dart`, que sustituye 5 copias de
  `_buildErrorWidget()`.
- Confirmación al salir de "Crear compra" con productos sin guardar.
- 11 tests nuevos (291 en total).

**Quedan fuera, a propósito:** el descuento general de compras (mezcla valor y %), los
"Precio de venta opción 1-5" (el backend los ignora por nombre distinto), los campos por fila del
importador de PDF, y la confirmación de salida cuando se navega desde el menú lateral
(`PopScope` no intercepta `context.go`).

**Fase 2: hecha en código (12-nov-2026), sin commitear ni desplegar y sin probar en navegador.**
- **Carga diferida (19):** el router importa con `deferred as` todas las pantallas salvo `splash`, `login`
  y `AppShell` (nuevo `lib/router/deferred_screen.dart`, con spinner y botón Reintentar si falla la descarga).
  Medido con `flutter build web --release`:

  | | Antes | Después |
  |---|---|---|
  | `main.dart.js` (lo que se baja antes de ver el login) | 7,26 MB | **3,83 MB (−47%)** |
  | Total principal + partes | 7,26 MB | 7,50 MB (+3%, 332 partes) |

  La ganancia es de **arranque**: el total descargado no baja, solo se reparte. El dashboard también es
  diferido, así que tras iniciar sesión se baja su parte y la de las pantallas que use.
- **Skeletons (8):** nuevo `widgets/common/skeleton_list.dart`, aplicado en productos y facturas.
- **Botones con estado de carga (2):** revisado, **ya estaba** en los principales (Comprar, guardar
  producto, cobrar en facturación con `isLoading`), así que no se tocó nada.
- Tests: 294 (3 nuevos del skeleton). `flutter analyze`: 0 errores, mismo número de avisos que antes.

**Pendiente de verificar a mano antes de desplegar:** abrir la app en el navegador, iniciar sesión y
navegar por dashboard, facturación, productos, reportes y compras. El análisis estático no detecta un
fallo de `loadLibrary`. Al desplegar, un cliente con la versión vieja en caché puede pedir partes que ya
no existen; `DeferredScreen` mostrará el error con Reintentar, y recargar la página lo resuelve.

**Fase 3: hecha en código (12-nov-2026), sin commitear ni desplegar.**
- **Responsive (4):** nuevo `test/responsive_widgets_test.dart` (21 tests) que monta los widgets compartidos
  de facturación y listados a **320, 360 y 412 px** con la fuente Roboto real (la fuente de prueba de
  Flutter, Ahem, es mucho más ancha y daba desbordes falsos). Encontró y corrigió 3 desbordes reales:
  - `PaginationControls`: una `Row` rígida de ~560 px desbordaba **incluso a 412 px**; ahora es un `Wrap`.
  - `MetodoPagoSection`: el indicador "Suma ingresada" del pago múltiple desbordaba a 320 px.
  - `ScreenHeader`: un título largo con insignia no recortaba (faltaba `Flexible`).
  Lo que **no** cubre: las pantallas completas (necesitan providers y red); siguen sin auditarse a mano.
- **Hover (3):** Material 3 ya da hover a botones, `ListTile` e `InkWell`; un `hoverColor` global no habría
  cambiado nada. Lo que faltaba era el cursor de mano en 12 `GestureDetector` clicables (chips de filtro,
  limpiar búsqueda, selectores de fecha, escáner), ahora envueltos en `MouseRegion`.

**Decididos a no hacer:**
- **Modo oscuro por defecto del sistema (15):** cambiaría la apariencia de todos los usuarios que nunca
  tocaron el tema (para ellos no hay nada guardado). No se cambia en silencio en un POS de mostrador.
- **Botón de volver arriba (7):** los listados grandes ya usan paginación; aporta poco.
- **Transiciones entre pantallas (9):** frenarían a quien navega todo el día sin dar valor real.

## Orden sugerido

**Fase 1 – Rápidas y de alto retorno**
1. Cambiar la `meta description` de `index.html`.
2. Validación y `MilesInputFormatter` en todos los campos de monto (13).
3. Widget de error con **Reintentar** y confirmación al salir con cambios sin guardar (14).

**Fase 2 – Rendimiento y percepción de velocidad**
4. Carga diferida de pantallas pesadas + medición con Lighthouse (19).
5. Skeleton en productos y facturas (8).
6. Estado de carga en los botones de acción (2).

**Fase 3 – Auditoría y detalles**
7. Auditoría de responsive en 360 px y 768 px, con corrección de desbordes (4).
8. Hover vía tema (3), botón "volver arriba" (7) y valor inicial del tema (15).

## Cómo verificar cada cambio

Cada fase debe cerrar con lo que pide `CLAUDE.md`: `flutter analyze` sin errores y
`flutter test --concurrency=1` en verde. Para la fase 2, además, comparar el tamaño de
`main.dart.js` y el tiempo de carga antes y después.
