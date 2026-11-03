# Componentes compartidos y duplicación entre screens — Vercy Motos

**Fecha:** 2026-11-03
**Alcance:** 59 screens (`lib/screens/`), 48 servicios (`lib/services/`), 41 widgets (`lib/widgets/`).
**Método:** conteos con `grep`/`comm` sobre el código real, no estimación. Cada número de esta tabla se puede reproducir con el comando que lo acompaña.

Este documento es complementario a [`analisis_arquitectura_frontend.md`](analisis_arquitectura_frontend.md)
(ese cubre la estructura de carpetas feature-first a largo plazo). Este se enfoca en
algo más inmediato: **qué piezas de UI y de servicios ya existen compartidas, cuáles
screens las usan, y dónde se está reconstruyendo a mano algo que ya existe.**

**Nota de vigencia:** varios hallazgos del documento de junio (`analisis_arquitectura_frontend.md`)
ya no aplican — se resolvieron en la limpieza de código muerto de esta sesión: los
archivos `*_new.dart`, `lib/examples/`, `lib/debug/` y la fragmentación de servicios
PDF (de 8 a 5 archivos) ya no existen. `facturacion_screen.dart` sigue siendo el
god-file más grande (5,634 líneas, incluso creció) — ese problema sigue vigente.

---

## 1. Resumen ejecutivo

| Patrón | Helper compartido ya existe | Screens que SÍ lo usan | Screens que lo reconstruyen a mano | Prioridad |
|---|---|---|---|---|
| Snackbar de éxito/error/info | `utils/snackbar_helper.dart` | 8 | 41 (144 llamadas directas a `ScaffoldMessenger`) | **Alta** |
| Diálogo de confirmación | `utils/dialogs_helper.dart` → `showConfirmDialog` | 48 | — pero existe una **segunda implementación paralela, muerta** (`dialogs/dialogo_confirmacion.dart`) | **Alta** (es dead code real) |
| Diálogo "motivo" (texto + confirmar) | No existe todavía | 0 | 3 (`compras_list_screen.dart`, `eliminar_pedidos_screen.dart`, `facturas_compras_screen.dart`) | Media |
| Selector de imagen (cámara/galería) | No existe todavía | 0 | 2 (`categorias_screen.dart`, `productos_screen.dart`) | Media |
| Botón con degradado (`AppTheme.primaryGradient` + `ElevatedButton`) | No existe todavía | 0 | 6 archivos | Media |
| Formateo de monto con separador de miles | `utils/currency_utils.dart` → `MilesInputFormatter` | 2 | el resto de campos de monto usan `double.tryParse` directo (riesgo real de mal-parseo) | **Alta** |
| Paginación (lógica) | `utils/pagination_mixin.dart` | 9 | — | Buena adopción |
| Paginación (UI) | `widgets/common/pagination_controls.dart` | 1 | 8 de las 9 que usan el mixin reconstruyen su propia UI de paginación | Media |
| Encabezado de pantalla | `widgets/common/screen_header.dart` | 11 | resto usa `AppBar` inline con estilos repetidos | Baja |
| Llamadas HTTP genéricas (get/post/put/delete + headers + timeout + manejo de error) | `services/base_api_service.dart` (`get<T>/post<T>/put<T>/delete`) | **0 servicios la extienden**; 8 la componen solo para `getHeaders()` | 33 de 48 servicios hacen su propio `http.get/post` con su propio timeout y manejo de respuesta | **Alta** (mucho código repetido, no solo estético) |
| Mensajes de error estandarizados | `utils/api_error.dart` (`throwBackendError`/`wrapOrThrow`) | 20 de 48 servicios | resto usa `try/catch` ad hoc con mensajes propios | Media |

---

## 2. Widgets, diálogos y snackbars compartidos

### 2.1 Snackbars — el caso más claro de duplicación

```
grep -c "ScaffoldMessenger.of(context).showSnackBar" lib/screens/*.dart | awk -F: '{sum+=$2} END {print sum}'
→ 144 ocurrencias en 41 screens distintos
```

Ya existe `utils/snackbar_helper.dart` con `showSuccessSnackBar`, `showWarningSnackBar`,
`showInfoSnackBar`, `showErrorSnackBar` (estilo, color y duración consistentes). Solo
8 screens lo usan. El resto repite el mismo bloque `ScaffoldMessenger.of(context)
..hideCurrentSnackBar()..showSnackBar(SnackBar(...))` con colores y duraciones que
varían ligeramente entre archivos — esto es lo que hace que la app se vea inconsistente
(unos snackbars duran 2s, otros 3s, algunos no tienen `floating`).

**Ejemplo real ya corregido esta sesión:** `abrir_caja_screen.dart` tenía su propio
`_mostrarExito()` reimplementando exactamente lo que ya hace `showSuccessSnackBar`.

### 2.2 Diálogo de confirmación — dos implementaciones paralelas, una de ellas muerta

- `utils/dialogs_helper.dart` → `showConfirmDialog(context, title:, content:, confirmColor:, isDangerous:)`.
  Usado por 48 de 59 screens. Es el estándar de facto.
- `lib/dialogs/dialogo_confirmacion.dart` → clase `DialogoConfirmacion` con
  `.mostrar()`, `.confirmarEliminacion()`, `.confirmarOperacionEfectivo()`. Visualmente
  **no coincide** con el primero (usa `Colors.red` fijo en vez de `AppTheme.error`, sin
  `Theme.of(context)`, sin bordes redondeados).

Verificado con grep: **nada en `lib/` importa `dialogs/dialogo_confirmacion.dart` ni
`validacion_caja_util.dart`** (la única clase que lo invoca) salvo su propio archivo de
test (`test/validacion_caja_util_test.dart`). Es decir, hoy esto es código inalcanzable
desde la app real — se coló en la depuración de código muerto anterior porque el test
lo mantenía "vivo" para un grep que no distinguía `lib/` de `test/`.

**Acción sugerida (no aplicada todavía, a decidir):** si nadie planea retomar esa
feature de confirmación con "fondos insuficientes", eliminar `dialogs/dialogo_confirmacion.dart`,
el método de `validacion_caja_util.dart` que lo invoca, y actualizar/eliminar su test. Si
la validación de fondos insuficientes sí es una regla de negocio vigente, migrar esas
tres llamadas a usar `showConfirmDialog` (ya soporta `isDangerous`/`confirmColor`).

### 2.3 Patrones repetidos sin helper todavía (candidatos a extraer)

- **Diálogo de "motivo"** (texto libre + Cancelar/Confirmar, usado al eliminar/anular):
  duplicado en `compras_list_screen.dart`, `eliminar_pedidos_screen.dart`,
  `facturas_compras_screen.dart`. Candidato a `showMotivoDialog(context, {title, label})`
  en `dialogs_helper.dart`.
- **Selector de imagen (cámara/galería)**: duplicado byte-a-byte en `categorias_screen.dart`
  y `productos_screen.dart`. Candidato a `showImageSourceDialog(context)` reutilizable.
- **Botón con degradado** (`Container` + `BoxDecoration(gradient: AppTheme.primaryGradient)`
  + `ElevatedButton` transparente encima): el mismo bloque de ~15 líneas aparece en
  `admin_panel_screen.dart`, `cerrar_caja_screen.dart`, `deudas_list_screen.dart`,
  `traslados_screen.dart`, `widgets/caja/formulario_abrir_caja_widget.dart` y
  `widgets/facturacion/botones_accion_facturacion.dart`. Candidato a un widget
  `GradientButton(label:, icon:, onPressed:, gradient:)` en `widgets/common/`.

### 2.4 Lo que ya funciona bien y vale la pena generalizar

- `widgets/common/screen_header.dart` (`ScreenHeader`) — 11 screens, buena adopción.
- `widgets/caja/*` — la screen de apertura de caja está bien separada en widgets sin
  lógica de negocio; es el patrón a copiar cuando se refactorice otra screen grande.
- `utils/submit_guard.dart` (`SubmitGuard` + `runGuarded`) — mixin pequeño, reutilizable,
  ya adoptado en 12 screens para evitar doble-submit.
- `utils/currency_utils.dart` → `MilesInputFormatter` — existe y funciona, pero solo 2
  screens lo usan. **Cualquier `TextFormField` de monto que no lo tenga es sospechoso**:
  sin él, un usuario que escribe "100.000" (notación colombiana de miles) puede terminar
  guardando 100.0 en vez de 100000, porque `double.tryParse` no entiende el punto como
  separador de miles. Ya se corrigió un caso concreto esta sesión (`FormularioAbrirCajaWidget`).

---

## 3. Servicios — funciones y patrones en común

### 3.1 `BaseApiService`: existe, pero casi nadie lo usa para lo que fue creado

`services/base_api_service.dart` es un singleton con headers/autenticación centralizados
y métodos genéricos `get<T>`, `getList<T>`, `post<T>`, `put<T>`, `delete` que ya manejan
timeout, parseo de `ApiResponse` y errores HTTP de forma consistente.

```
grep -l "class.*extends BaseApiService" lib/services/*.dart   → 0 archivos
grep -l "BaseApiService().get"            lib/services/*.dart   → 8 archivos (solo para getHeaders()/getToken())
grep -l "^import 'package:http/http.dart'" lib/services/*.dart  → 33 de 48 servicios
```

En la práctica, **33 de 48 servicios hacen su propio `http.get/post/put/delete`**,
reimplementando headers, timeout y manejo de respuesta cada vez, en vez de usar los
métodos genéricos que `BaseApiService` ya ofrece. Esto no es solo un tema de estilo:
cada reimplementación es una oportunidad distinta de tener un bug sutil (timeout
distinto, un header que falta, un código de estado que no se contempla). El patrón
"componer solo para headers" (8 servicios) es un punto intermedio razonable cuando el
servicio necesita algo que los métodos genéricos no cubren (ej. multipart, streaming),
pero para el CRUD estándar no hay razón para no usar `get<T>/post<T>/etc` directamente.

**No se sugiere una migración masiva ahora** (alto riesgo, bajo beneficio inmediato en
un cambio de ese tamaño) — sí se sugiere: todo servicio **nuevo** que haga REST estándar
debería partir de `BaseApiService().get/post/put/delete`, no de `http` directo.

### 3.2 Manejo de errores: adopción parcial pero real

`utils/api_error.dart` (`throwBackendError`, `wrapOrThrow`, `errorMessage`) está adoptado
en 20 de 48 servicios — es el patrón más consistente que hay en la capa de servicios.
Los otros 28 usan `try/catch` con mensajes construidos a mano, lo que es parte de por
qué aparecen bugs como el de `abrir_caja_screen.dart` (matchear `e.toString().contains(...)`
en vez de un tipo de excepción).

### 3.3 Patrón de caché `forceRefresh` — bueno, pero no documentado como convención

Varios servicios (`ProveedorService`, `ClienteService`, `NegocioInfoService`,
`ReportesService`) ya implementan caché en memoria con un parámetro
`forzar`/`forceRefresh` para evitar peticiones repetidas en pantallas que se
reconstruyen seguido (dashboard, listas). Es un buen patrón — vale la pena que
cualquier servicio de solo-lectura que se llame seguido desde un `build()` lo copie,
en vez de pegarle a la red cada vez. (Ya documentado como convención en `CLAUDE.md`.)

### 3.4 Servicios más usados transversalmente (candidatos a no duplicar su lógica)

```
grep -rhoE "import '\.\./services/[a-z_]+\.dart'" lib/screens/*.dart | sort | uniq -c | sort -rn
```

| Servicio | Screens que lo importan |
|---|---|
| `producto_service.dart` | 11 |
| `pedido_service.dart` | 9 |
| `cliente_service.dart` | 9 |
| `pdf_service.dart` | 8 |
| `cuadre_caja_service.dart` | 7 |
| `proveedor_service.dart` | 6 |

Son los puntos de mayor impacto si se decide introducir una interfaz (`IProductoService`,
etc.) para poder inyectar fakes en tests, siguiendo el mismo patrón que ya existe en
`ICuadreCajaService` (usado en `caja_y_gastos_secuencias_test.dart` y
`facturas_compras_screen_secuencias_test.dart` sin mockito/mocktail).

---

## 4. Estructura sugerida para una screen nueva (o al refactorizar una existente)

No es obligatorio ni requiere migrar nada hoy — es la checklist de "qué reusar antes de
escribir código nuevo", pensada para que no se repitan los casos de la sección 2:

1. **Encabezado** → `ScreenHeader` (`widgets/common/screen_header.dart`), no un `AppBar` a mano.
2. **Mensajes al usuario** → `snackbar_helper.dart` / `dialogs_helper.dart`, nunca
   `ScaffoldMessenger` ni `AlertDialog` directo salvo que el contenido sea genuinamente
   custom (un formulario dentro del diálogo, no un simple confirmar/cancelar).
3. **Campos de monto** → `TextFormField` + `inputFormatters: [MilesInputFormatter()]`,
   parseo con `CurrencyUtils.parse(...)` (o `.parseDecimal(...)` si hay decimales).
4. **Botones de acción primaria con degradado** → una vez exista `GradientButton`
   (sección 2.3), usarlo en vez de repetir el `Container`+`BoxDecoration`.
5. **Doble-submit** → `SubmitGuard` + `runGuarded(...)` en cualquier botón que dispare
   una escritura al backend (crear, eliminar, pagar, anular).
6. **Listas largas** → `PaginacionMixin` para la lógica y `PaginationControls` para la UI
   (hoy solo 1 screen usa ambas juntas — el resto del mixin reimplementa la UI).
7. **Lógica de negocio** → si el `State` empieza a acumular validaciones y llamadas a
   servicios más allá de lo trivial, extraerla a una clase plana (controller/view model
   sin `Widget`), como se señala en `CLAUDE.md`.
8. **Servicios nuevos de CRUD estándar** → partir de `BaseApiService().get<T>/post<T>/...`
   en vez de `http` directo; si el servicio se va a testear con interacción de UI, darle
   una interfaz (`IXxxService`) igual que `ICuadreCajaService`.

---

## 5. Plan de acción priorizado

| Acción | Esfuerzo | Riesgo | Impacto |
|---|---|---|---|
| Decidir qué hacer con `dialogs/dialogo_confirmacion.dart` (código muerto) | Bajo | Bajo | Resuelve una inconsistencia visual real si se elimina |
| Migrar snackbars directos a `snackbar_helper.dart`, screen por screen al tocarlas | Bajo (incremental) | Bajo | Alto — consistencia visual inmediata |
| Auditar campos de monto sin `MilesInputFormatter` y agregarlo | Bajo-medio | Bajo | Alto — previene bugs de monto mal interpretado |
| Crear `showMotivoDialog` y `showImageSourceDialog` en `dialogs_helper.dart`, migrar los 5 sitios que los duplican | Medio | Bajo | Medio |
| Crear `GradientButton` compartido, migrar los 6 sitios que lo duplican | Medio | Bajo | Medio (visual) |
| Unificar `PaginacionMixin` + `PaginationControls` en las 8 screens que usan solo el mixin | Medio | Bajo | Medio |
| Todo servicio nuevo parte de `BaseApiService().get/post/put/delete` | — (regla hacia adelante) | — | Alto a largo plazo |
| Extraer lógica de negocio de screens grandes a controllers/view models | Alto | Medio | Muy alto, pero es el ítem de `analisis_arquitectura_frontend.md` — no duplicar esfuerzo aquí |

---

*Documento generado el 2026-11-03 a partir de conteos reproducibles sobre el código
actual del repositorio (rama `integracion/refactor-inventario`). Volver a correr los
comandos `grep` de cada sección antes de actuar sobre un número si ha pasado tiempo
desde esta fecha — el código cambia rápido en este proyecto.*
