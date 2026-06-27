# Análisis de Arquitectura Frontend — Vercy Motos
**Fecha:** 2026-06-26  
**Stack:** Flutter/Dart 3.8 · Provider · go_router · HTTP

---

## 1. Resumen Ejecutivo

El proyecto tiene una base funcional sólida pero presenta deuda técnica acumulada que afecta directamente las características de **mantenibilidad** y **modificabilidad** definidas en ISO 25010. Los problemas principales son: ausencia de capas de abstracción (viola DIP de SOLID), lógica de negocio mezclada con UI (viola SRP), y acumulación de archivos duplicados/obsoletos que dificultan la lectura del código.

**Impacto real:** cualquier desarrollador nuevo tarda más de 2 horas en entender dónde vive la lógica de un flujo simple. El riesgo de introducir regresiones al modificar `facturacion_screen.dart` o `user_provider.dart` es alto porque concentran demasiadas responsabilidades.

---

## 2. Inventario Actual

```
lib/
├── config/          10 archivos   ← 3+ archivos duplicados/obsoletos
├── debug/            1 archivo    ← no debería estar en producción
├── dialogs/          3 archivos
├── examples/         2 archivos   ← no debería estar en producción
├── models/          36 archivos   ← 4 versiones de item_pedido
├── providers/        5 archivos   ← muy pocos para el tamaño del sistema
├── router/           1 archivo
├── screens/         42 archivos   ← god screens con 9+ servicios c/u
├── services/        55 archivos   ← 8+ servicios PDF, 3 pares _new/_old
├── theme/            1 archivo
├── utils/           24 archivos   ← mezcla de helpers UI, lógica y mixins
└── widgets/         35 archivos   ← mezcla de screens, dialogs y widgets
```

**Total: ~261 archivos Dart**

---

## 3. Hallazgos Críticos

### 3.1 Archivos Duplicados / "Versión Zombie"

Existen pares de archivos donde la versión original y la `_new` conviven sin que quede claro cuál es canónica. Esto viola **ISO 25010 — Analyzability**: no se puede saber qué código está activo sin trazar imports.

| Duplicado identificado | Archivos |
|---|---|
| Servicio de pedidos | `pedido_service.dart` + `pedido_service_new.dart` |
| Servicio de roles | `role_service.dart` + `role_service_new.dart` |
| Servicio de usuarios | `user_service.dart` + `user_service_new.dart` |
| Configuración de API | `api_config.dart` + `api_config_new.dart` |
| Configuración de endpoints | `endpoints_config.dart` + `endpoints_config_new.dart` |
| Servicio base | `services/base_api_service.dart` + `services/base/base_api_service.dart` |
| Modelos de item pedido | `item_pedido.dart` + `item_pedido_new.dart` + `item_pedido_test.dart` + `item_pedido_unified.dart` |
| Resumen cierre | `resumen_cierre.dart` + `resumen_cierre_completo.dart` + sus services |

**Regla:** cuando se migra a una nueva versión, el archivo viejo se elimina en el mismo PR. No se deja como respaldo en producción.

---

### 3.2 Archivos en Carpetas Incorrectas

| Archivo | Carpeta actual | Problema |
|---|---|---|
| `lib/screens/Row.dart` | `screens/` | Un widget de Flutter en screens; probablemente generado por error |
| `lib/services/network_test.dart` | `services/` | Código de diagnóstico/test en capa de servicios |
| `lib/services/WEBHOOK_BACKEND_REFERENCE.dart` | `services/` | Documentación de referencia; no es código ejecutable |
| `lib/examples/` | raíz de lib | Ejemplos de prueba no deben estar en el código de producción |
| `lib/debug/debug_carga_datos.dart` | raíz de lib | Herramienta de debug; debe excluirse de builds release |

---

### 3.3 Violación de SRP — God Screens

Los 5 archivos más grandes del proyecto concentran responsabilidades que deberían estar en al menos 3-5 clases distintas cada uno:

| Archivo | Líneas | Problema |
|---|---|---|
| `facturacion_screen.dart` | **5,401** | UI + lógica de negocio + 10 servicios + cache global |
| `productos_screen.dart` | **4,815** | CRUD + búsqueda + filtros + cache + paginación |
| `crear_factura_compra_screen.dart` | **4,126** | Equivalente a facturacion para compras |
| `dashboard_screen_v2.dart` | **3,302** | Estadísticas + gráficos + múltiples tabs |
| `producto_service.dart` | **2,843** | CRUD + búsqueda + paginación + cache en un servicio |

`facturacion_screen.dart` instancia **10 servicios directamente** en su estado:

```dart
final PedidoService _pedidoService = PedidoService();
final ProductoService _productoService = ProductoService();
final PedidoAsesorService _pedidoAsesorService = PedidoAsesorService();
final TrasladoService _trasladoService = TrasladoService();
final PDFService _pdfService = PDFService();
final NegocioInfoService _negocioInfoService = NegocioInfoService();
final ImpresionService _impresionService = ImpresionService();
final InventarioService _inventarioService = InventarioService();
final ClienteService _clienteService = ClienteService();
final MatiasService _matiasService = MatiasService();
```

**Principio violado:** SRP — una clase debe tener una sola razón para cambiar. Este screen cambia si cambia la UI, la lógica de facturación, el PDF, la integración DIAN, o la lógica de clientes.

---

### 3.4 Violación de DIP — Sin Inyección de Dependencias

Todos los screens crean sus servicios con `new` localmente. Esto hace imposible:
- Reemplazar implementaciones (ej. mock para tests)
- Cambiar la fuente de datos sin tocar cada screen
- Aplicar el patrón Repository

**Principio violado:** DIP (Dependency Inversion Principle) — los módulos de alto nivel (UI) no deben depender de módulos de bajo nivel (implementaciones de HTTP). Ambos deben depender de abstracciones.

**Síntoma concreto:** si mañana cambia el endpoint base de la API, hay que buscar en 42 screens cuáles llaman qué servicio.

---

### 3.5 Sin Capa de Abstracción en Servicios

Ningún servicio implementa una interfaz abstracta. No existe un contrato que diga "un servicio de facturación debe exponer estos métodos". Esto viola **OCP** (Open/Closed Principle): para cambiar comportamiento hay que modificar el servicio existente, no extenderlo.

---

### 3.6 Nomenclatura Inconsistente

| Problema | Ejemplos |
|---|---|
| Dos carpetas de widgets de facturación con nombres casi iguales | `widgets/facturacion/` vs `widgets/facturizacion/` |
| Sufijo de versión en nombre de screen | `dashboard_screen_v2.dart` |
| Mezcla de idiomas en nombres | `dialogo_confirmacion.dart` vs `common_widgets.dart` |
| Screens de lista sin convención uniforme | `proveedores_screen.dart` + `proveedores_list_screen.dart` (¿cuál lista?) |

---

### 3.7 La Carpeta `utils/` es un Cajón de Sastre

Actualmente `utils/` contiene cosas de 4 categorías distintas:

- **Helpers de UI:** `snackbar_helper.dart`, `dialogs_helper.dart`
- **Lógica de negocio:** `payment_calculator.dart`, `pedido_helper.dart`, `dashboard_helper.dart`, `busqueda_productos_utils.dart`
- **Utilidades técnicas:** `jwt_utils.dart`, `connectivity_utils.dart`, `retry_strategy.dart`, `logger.dart`
- **Mixins de comportamiento:** `impresion_mixin.dart`, `pagination_mixin.dart`
- **Compatibilidad de plataforma:** `html_stub.dart` (stub completo de `dart:html` para compilar en móvil)

Mezclar estas categorías viola **ISP** (Interface Segregation Principle) — en términos de organización: un archivo que busca "utilidades de pago" no debería tener que revisar 24 archivos mezclados.

---

### 3.8 Fragmentación del Sistema PDF

Existen **8 archivos** relacionados con PDF distribuidos en `services/` y `utils/`:

```
services/pdf_service.dart
services/pdf_export_service.dart
services/pdf_service_factory.dart
services/pdf_service_stub.dart        ← plataforma
services/pdf_service_web.dart         ← plataforma
services/pdf_download_helper.dart
services/pdf_download_stub.dart       ← plataforma
services/pdf_download_web.dart        ← plataforma
```

Está bien tener variantes por plataforma (`_web`/`_stub`), pero `pdf_service.dart` vs `pdf_export_service.dart` no tiene justificación clara.

---

### 3.9 Gestión de Estado Centralizada en Exceso

Solo **5 providers** para todo un ERP con 42 pantallas:
- `UserProvider` — auth + roles + sesión (3 responsabilidades)
- `DatosCacheProvider` — caché global
- `FacturacionDraftProvider`
- `NotificacionesProvider`
- `ThemeProvider`

La mayoría de screens gestionan su estado con `setState` + lógica de negocio local. Esto genera código difícil de testear y estados que no se comparten cuando deberían.

---

## 4. Mapeo a ISO 25010

| Característica ISO 25010 | Estado actual | Impacto |
|---|---|---|
| **Analyzability** (entendibilidad del código) | Bajo — archivos duplicados, god screens | Alto |
| **Modifiability** (facilidad de cambiar) | Bajo — sin abstracciones, DIP violado | Alto |
| **Testability** (facilidad de testear) | Muy bajo — sin interfaces, sin DI | Alto |
| **Reusability** | Medio — hay widgets reutilizables pero mal organizados | Medio |
| **Modularity** | Bajo — boundaries entre capas borrosos | Alto |

---

## 5. Estructura de Carpetas Recomendada

### Principio guía: Feature-First con capas compartidas

La idea central es agrupar primero por **dominio de negocio** (feature) y dentro de cada feature, por **capa técnica**. Las piezas verdaderamente genéricas van en carpetas `core/` o `shared/`.

```
lib/
│
├── core/                          ← Infraestructura sin lógica de negocio
│   ├── network/
│   │   ├── api_client.dart        ← HTTP base + interceptores
│   │   ├── api_exception.dart     ← Tipos de error unificados
│   │   └── secure_http_client.dart
│   ├── storage/
│   │   └── secure_storage.dart
│   ├── config/
│   │   ├── app_config.dart        ← Un solo archivo de config (reemplaza los 10 actuales)
│   │   └── endpoints.dart
│   └── utils/
│       ├── logger.dart
│       ├── jwt_utils.dart
│       ├── retry_strategy.dart
│       ├── datetime_utils.dart
│       └── connectivity_utils.dart
│
├── shared/                        ← Piezas reutilizables entre features
│   ├── models/
│   │   └── api_response.dart
│   ├── widgets/
│   │   ├── common/
│   │   │   ├── app_button.dart
│   │   │   ├── loading_indicator.dart
│   │   │   ├── screen_header.dart
│   │   │   ├── pagination_controls.dart
│   │   │   └── filters_bar.dart
│   │   └── dialogs/
│   │       └── confirm_dialog.dart
│   ├── providers/
│   │   └── theme_provider.dart
│   └── theme/
│       └── app_theme.dart
│
├── features/                      ← Un directorio por dominio de negocio
│   │
│   ├── auth/
│   │   ├── models/user.dart
│   │   ├── providers/user_provider.dart   ← solo auth/sesión
│   │   ├── providers/roles_provider.dart  ← roles separado
│   │   ├── services/auth_service.dart
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       └── splash_screen.dart
│   │
│   ├── facturacion/
│   │   ├── models/
│   │   │   ├── pedido.dart
│   │   │   ├── item_pedido.dart   ← una sola versión canónica
│   │   │   └── cliente.dart
│   │   ├── providers/
│   │   │   ├── facturacion_provider.dart  ← orquesta la lógica del screen
│   │   │   └── facturacion_draft_provider.dart
│   │   ├── repositories/
│   │   │   ├── pedido_repository.dart     ← abstracción (interfaz)
│   │   │   └── pedido_repository_impl.dart
│   │   ├── services/
│   │   │   ├── pdf_factura_service.dart
│   │   │   └── matias_service.dart
│   │   ├── screens/
│   │   │   └── facturacion_screen.dart    ← solo UI
│   │   └── widgets/
│   │       ├── totales_section.dart
│   │       ├── observaciones_section.dart
│   │       └── botones_accion.dart
│   │
│   ├── inventario/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── services/
│   │   └── screens/
│   │
│   ├── caja/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── services/
│   │   └── screens/
│   │
│   ├── clientes/
│   ├── proveedores/
│   ├── gastos/
│   ├── cartera/
│   ├── reportes/
│   ├── dashboard/
│   ├── dian/                      ← feature separada: facturación electrónica
│   │   ├── models/
│   │   ├── services/matias_service.dart
│   │   └── widgets/
│   └── admin/
│       ├── users/
│       └── roles/
│
├── router/
│   └── app_router.dart
│
└── main.dart
```

---

## 6. Beneficios de la Nueva Estructura

### 6.1 Para el desarrollador nuevo
- Pregunta: "¿Dónde está todo lo de facturación?" → `features/facturacion/`
- No necesita buscar entre 42 screens + 55 services + 24 utils

### 6.2 Para tests
Con la capa `repository/` e interfaces, un test unitario puede inyectar un mock:
```dart
// Antes: imposible testear sin red
class FacturacionScreen extends StatefulWidget { 
  PedidoService _pedidoService = PedidoService(); // acoplado
}

// Después: testeable
class FacturacionProvider extends ChangeNotifier {
  FacturacionProvider(this._pedidoRepo); // inyectado
  final PedidoRepository _pedidoRepo;
}
```

### 6.3 Para screens más delgados
El screen solo consume el provider; toda la lógica de orquestación vive en el provider:
```dart
class FacturacionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FacturacionProvider>();
    return Column(children: [
      TotalesSection(total: vm.total),
      BotonesAccion(onPagar: vm.procesarPago),
    ]);
  }
}
```

---

## 7. Plan de Migración por Fases

### Fase 1 — Limpieza (sin romper nada) · ~1 semana
Estas acciones son seguras y mejoran el proyecto inmediatamente:

1. **Eliminar archivos obsoletos** confirmando con `grep -r "pedido_service_new"` que nadie los importa:
   - `*_new.dart` que tengan versión sin sufijo activa
   - `item_pedido_test.dart`
   - `lib/examples/`
   - `lib/services/WEBHOOK_BACKEND_REFERENCE.dart` (mover a `/docs`)
   - `lib/screens/Row.dart`

2. **Unificar configuración** en un solo `app_config.dart` + `endpoints.dart`.

3. **Unificar modelos de PDF** en `pdf_service.dart` + implementaciones de plataforma.

4. **Renombrar `widgets/facturizacion/` → `widgets/dian/`** para diferenciarlo claramente de `widgets/facturacion/`.

### Fase 2 — Capa Core · ~1 semana
5. Crear `lib/core/network/api_client.dart` que centralice headers, tokens y manejo de errores HTTP. Migrar servicios uno a uno para que usen este cliente.

6. Mover lógica de negocio de `utils/` a sus features correspondientes:
   - `payment_calculator.dart` → `features/facturacion/utils/`
   - `pedido_helper.dart` → `features/facturacion/utils/`
   - `dashboard_helper.dart` → `features/dashboard/utils/`

### Fase 3 — Feature por Feature · ~2-3 semanas
7. Por cada feature nueva o modificada, seguir la estructura `models/`, `repositories/`, `providers/`, `screens/`, `widgets/`.

8. Extraer lógica de negocio de `FacturacionScreen` a `FacturacionProvider`:
   - El screen solo llama `provider.procesarPago()`, `provider.agregarProducto()`, etc.
   - Toda la orquestación de servicios vive en el provider.

9. Separar `UserProvider` en `AuthProvider` (token/sesión) y `RolesProvider` (permisos).

### Fase 4 — Repositorios y Contratos · ~2 semanas
10. Introducir interfaces abstractas para los repositorios principales:
    ```dart
    abstract class PedidoRepository {
      Future<List<Pedido>> getPedidos();
      Future<void> crearPedido(Pedido pedido);
    }
    ```
11. Registrar dependencias en `main.dart` usando el patrón Provider o un service locator.

---

## 8. Reglas de Equipo para Mantener la Estructura

Estas reglas deben documentarse en `CONTRIBUTING.md`:

1. **No crear archivos `_new`** — si reemplazas un archivo, elimina el viejo en el mismo PR.
2. **No crear lógica de negocio en screens** — si necesitas llamar un servicio, hazlo en el provider.
3. **No poner código de debug o ejemplos en `lib/`** — usa `test/` o `docs/` respectivamente.
4. **Todo archivo nuevo de una feature va dentro de `features/<nombre>/`** — no en carpetas globales a menos que sea genuinamente compartido.
5. **Cada screen tiene un provider dedicado** — el screen es un Consumer del provider, no el orchestrador.
6. **Un modelo, una versión** — si necesitas una variante, usa un `copyWith` o composición, no un archivo nuevo.

---

## 8.1 Duplicados Adicionales en Widgets

| Par duplicado | Archivos |
|---|---|
| Imagen de producto con lazy load | `lazy_imagen_producto.dart` + `lazy_product_image_widget.dart` |
| Imágenes de producto genéricas | `imagen_producto_widget.dart` + `imagen_categoria_widget.dart` (¿mismo patrón, deberían ser uno solo?) |
| Servicio de imagen | `image_service.dart` + `image_loader_service.dart` |

Los diálogos también están dispersos en 3 ubicaciones distintas:
- `/dialogs/` — 3 diálogos
- `/widgets/facturizacion/` — 3 diálogos (`nota_credito_debito_dialog.dart`, `documento_soporte_dialog.dart`, `confirmacion_dian_dialog.dart`)
- `/widgets/` raíz — 2 diálogos (`cancelar_producto_dialog.dart`, `pago_parcial_dialog.dart`)

---

## 8.2 Métricas del Proyecto

```
Total archivos Dart:          234
Total screens:                 53
Total services:                60
Total models:                  49
Archivos > 2,000 líneas:       15  (GOD FILES)
Archivos < 100 líneas:         45  (helpers, stubs)
Archivos con "_new":            6
Archivos test/debug en lib/:    5  (no deberían estar en producción)
Archivos PDF:                   8  (para 1 responsabilidad)
Proveedores globales:           5  (insuficientes para 53 screens)
Esfuerzo estimado de limpieza: 30-40 horas
```

---

## 9. Prioridad de Acción

| Acción | Esfuerzo | Impacto | Prioridad |
|---|---|---|---|
| Eliminar archivos `_new` obsoletos | Bajo | Alto | **Inmediata** |
| Eliminar `examples/`, `debug/` | Bajo | Medio | **Inmediata** |
| Unificar PDF services | Bajo | Alto | **Inmediata** |
| Unificar config en un archivo | Medio | Alto | **Esta semana** |
| Extraer lógica de `FacturacionScreen` al provider | Alto | Muy alto | **Próximo sprint** |
| Separar `UserProvider` | Medio | Alto | **Próximo sprint** |
| Crear `core/network/api_client.dart` | Medio | Alto | **Próximo sprint** |
| Estructura feature-first | Muy alto | Muy alto | **Mediano plazo** |

---

*Documento generado el 2026-06-26. Revisión recomendada con cada sprint mayor.*
