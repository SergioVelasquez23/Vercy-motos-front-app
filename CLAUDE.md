# Vercy Motos — Frontend (Flutter)

App de punto de venta / ERP para repuestos de motos. Backend Java/Spring
separado (otro repo local).

## Antes de construir UI o helpers nuevos

Repetidas veces en este proyecto se ha reconstruido una funcionalidad que ya
existía en otro archivo (dos diálogos de selección de caja, la feature de
"pago mixto" en gastos duplicada entre sesiones, un snackbar de éxito
reimplementado a mano cuando ya había uno compartido). Antes de escribir un
diálogo, un formateador de campo, un snackbar o un helper de validación
nuevo, revisa la lista de abajo.

## Widgets compartidos (`lib/widgets/`)

- `widgets/common/screen_header.dart` — `ScreenHeader` + `ScreenHeaderAction`:
  encabezado estándar de pantallas de listado (título, acciones, badges).
- `widgets/common/pagination_controls.dart` — `PaginationControls`: controles
  de paginación reutilizables para listas.
- `widgets/caja/caja_ui_helpers.dart` — `CajaUiHelpers.buildCard` /
  `buildInfoTile` / `buildInfoRow`: tarjetas e info-rows con el estilo
  estándar de las pantallas de caja.
- `widgets/caja/formulario_abrir_caja_widget.dart`,
  `caja_ya_abierta_widget.dart` — formulario de apertura y el aviso de "caja
  ya abierta"; patrón a seguir para separar screens grandes en widgets
  reutilizables sin lógica de negocio.
- `widgets/facturacion/*` — secciones del formulario de facturación
  (totales, método de pago, dropdown de tipo de factura, etc.).
- `widgets/facturizacion/*` — diálogos de DIAN (confirmación, nota
  crédito/débito, documento soporte). **Nombre inconsistente con
  `facturacion/` por un typo histórico** — es el mismo dominio
  (facturación). No crear una tercera carpeta: los diálogos de
  facturación/DIAN van en una de estas dos, no en una nueva.
- `widgets/productos/*`, `widgets/compras/*`, `widgets/dashboard/*`,
  `widgets/reportes/*` — widgets específicos de cada listado/pantalla grande,
  ya separados por pestaña o sección.

## Diálogos y mensajes compartidos (`lib/utils/`)

- `dialogs_helper.dart` — `showConfirmDialog`, `showErrorDialog`,
  `showInfoDialog`, `showEleccionCajaDialog` (elegir LOCAL/ENVÍOS). Antes de
  escribir un `AlertDialog` nuevo para confirmar/elegir/avisar algo, revisar
  si ya hay uno acá.
- `snackbar_helper.dart` — `showSuccessSnackBar`, `showWarningSnackBar`,
  `showInfoSnackBar`, `showErrorSnackBar` (este último en realidad abre un
  diálogo, no un snackbar — es intencional, para que el error se lea con
  calma). Usar estos en vez de construir `ScaffoldMessenger(...).showSnackBar`
  a mano en cada screen.
- `api_error.dart` — `errorMessage(e)` / `throwBackendError(...)` para
  mensajes de error consistentes desde las respuestas del backend.

## Utilidades de negocio reutilizables (`lib/utils/`)

- `currency_utils.dart` — `CurrencyUtils` (formateo de moneda para mostrar) y
  `MilesInputFormatter` (`TextInputFormatter` que agrega separador de miles
  mientras el usuario escribe). **Todo campo de monto en un `TextFormField`
  debe usar `MilesInputFormatter`** — si no, `double.tryParse` puede
  interpretar mal un monto escrito con puntos de miles. Ya se usa en
  `facturacion_screen.dart` y `asesor_pedidos_screen.dart`; si un campo de
  monto nuevo no lo tiene, probablemente sea un bug, no una decisión
  deliberada.
- `payment_calculator.dart` — `PaymentCalculator`: cálculos de pago
  (mixto, cambio, etc.) centralizados.
- `payment_mapping.dart`, `detalle_pago_options.dart` — mapeo de formas de
  pago entre front y backend.
- `facturacion_calculos.dart` — cálculos de IVA/descuentos/AIU para
  facturación.
- `validacion_caja_util.dart` — `ValidacionCajaUtil` / `DetallesEfectivo`:
  parseo y validación de montos declarados al cerrar caja.
- `pagination_mixin.dart` — `PaginacionMixin<T>`: mixin de paginación para
  `State` de listas largas (productos, clientes, etc.).
- `submit_guard.dart` — `SubmitGuard` mixin + `runGuarded(...)`: evita que un
  doble-tap dispare la misma acción (crear, eliminar, pagar) dos veces.
  Usar en cualquier botón que dispare una petición de escritura al backend.
- `retry_strategy.dart` — `RetryStrategyFactory.forEnvironment(...)`: reintentos
  HTTP con estrategia distinta según el entorno (local/producción/Render).

## Servicios (`lib/services/`, 48 archivos)

- Los servicios con interfaz (ej. `ICuadreCajaService` +
  `CuadreCajaService`) permiten inyectar un fake en tests de widget sin
  mockito/mocktail — es el patrón a seguir para servicios nuevos que se
  vayan a testear con interacción de UI (ver `caja_y_gastos_secuencias_test.dart`,
  `facturas_compras_screen_secuencias_test.dart`).
- Varios servicios cachean en memoria con un flag `forzar`/`forceRefresh`
  (`ProveedorService.getProveedores`, `ClienteService`, `NegocioInfoService`,
  `ReportesService`) para evitar round-trips repetidos en pantallas que se
  reconstruyen seguido (dashboard, listas). Si se agrega un nuevo método de
  lectura que se llama muy seguido, revisar si conviene el mismo patrón antes
  de pegarle a la red cada vez.

## Arquitectura: guía general (basada en la guía oficial de Flutter)

Estructura actual: **layer-first** (`screens/`, `widgets/`, `services/`,
`models/`, `providers/`, `utils/`). Es razonable para el tamaño actual del
equipo — no migrar a feature-first solo por esto, el costo no se paga solo
todavía. Si el proyecto crece mucho más, revisar
https://docs.flutter.dev/app-architecture/guide.

Mientras tanto:
- **Las screens (`State`) no deberían crecer con lógica de negocio.** Si una
  pantalla empieza a acumular validaciones, parseo y llamadas a servicios
  directamente en el `State`, extraer esa lógica a una clase plana
  (controller/view model sin `Widget`) que se pueda testear sin montar el
  árbol de widgets. `abrir_caja_screen.dart` es un ejemplo de lo que falta
  extraer (validación de monto, manejo de errores de "ya existe una caja").
- **No matchear errores por texto libre** (`e.toString().contains('...')`).
  Si hace falta distinguir un caso de error del backend, agregar un código o
  tipo de excepción en `api_error.dart` en vez de depender del wording exacto
  del mensaje.
- **Antes de borrar algo "que no se usa", confirmar con grep en `lib/` y
  `test/`**, no asumir por el nombre del archivo — varias veces código
  comentado con "✅ COMENTADO: ya no se usa" resultó sí tener lectores reales
  en otro archivo.

## Verificación obligatoria antes de dar por terminado un cambio

```
flutter analyze                    # se espera 0 errores (puede haber infos/warnings preexistentes)
flutter test --concurrency=1       # 280+ tests, correr con concurrency=1 por memoria; en background si el entorno lo requiere
```

## NUNCA empujar a `main` ni desplegar

- **Un `git push` a `main` de este repo PUBLICA el sitio real** (`vercy-motos.web.app`) por GitHub Actions, sin ninguna
  aprobación. Por eso: **trabaja siempre en una rama** (`feature/…`, `fix/…`) y deja el cambio listo para un Pull Request.
  Nada de `git push` a `main`, `--force` ni borrar ramas remotas.
- No ejecutes `firebase deploy` ni toques el hosting. Para ver un cambio antes de publicarlo existe un canal de
  vista previa de staging (`firebase hosting:channel:deploy staging`) que lanza el dueño.
- El backend a producción es manual y lo lanza el dueño (ver `CLAUDE.md` del repo `Vercy-motos-app`). El front de staging
  se compila con `--dart-define=BACKEND_URL=https://staging.204-168-190-85.nip.io`; sin ese parámetro apunta a producción.

## Stock y datos que el front no debe pisar

- Al guardar un producto, **solo se envía el stock que el usuario cambió** (`updateProducto(producto, original: …)`).
  Mandar siempre el stock del formulario deshace ventas que ocurrieron mientras estaba abierto. Si agregas otra pantalla
  que edite productos, pasa `original:`. Test: `test/stock_solo_si_cambia_test.dart`.
- Un producto nuevo se crea con `controlInventario: 'SI'` (los de "mano de obra" los fuerza el backend a no controlar).
- Los snackbars y avisos van por `utils/snackbar_helper.dart`; los errores de venta/compra/caja se muestran, no se tragan.

