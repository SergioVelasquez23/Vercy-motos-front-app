# Diagrama: Productos, Inventario y Compras — Frontend + Backend

**Fecha:** 2026-11-03

Diagrama de capas (modelos, services, controllers, repositorios) para los dominios
Productos, Inventario y Compras, cubriendo tanto el frontend (Flutter, este repo)
como el backend (Spring/Java, repo `vercy/src`). Construido verificando los
archivos y dependencias reales de ambos repos, no es una estructura genérica.

```mermaid
flowchart TB
    subgraph FRONT["🖥️ FRONTEND (Flutter)"]
        direction LR

        subgraph FP["Productos"]
            direction TB
            FP_S["productos_screen.dart
productos_list_screen.dart
categorias_screen.dart
informes_productos_screen.dart"]
            FP_SRV["producto_service.dart
(maneja tambien categorias,
no existe categoria_service.dart)"]
            FP_M["producto.dart
categoria.dart
ingrediente.dart"]
            FP_S --> FP_SRV --> FP_M
        end

        subgraph FI["Inventario"]
            direction TB
            FI_S["historial_inventario_screen.dart
costeo_inventario_screen.dart"]
            FI_SRV["inventario_service.dart
backup_inventario_service.dart"]
            FI_M["inventario.dart
movimiento_inventario.dart
movimiento_stock.dart"]
            FI_S --> FI_SRV --> FI_M
        end

        subgraph FC["Compras"]
            direction TB
            FC_S["compras_list_screen.dart
facturas_compras_screen.dart
crear_factura_compra_screen.dart
detalle_factura_compra_screen.dart
importar_factura_compra_pdf_screen.dart"]
            FC_SRV["factura_compra_service.dart"]
            FC_M["factura_compra.dart
factura_compra_pdf_preview.dart"]
            FC_S --> FC_SRV --> FC_M
        end
    end

    subgraph BACK["☕ BACKEND (Spring / Java)"]
        direction LR

        subgraph BP["Productos"]
            direction TB
            BP_C1["ProductosController
/api/productos"]
            BP_C2["CategoriaController"]
            BP_R1["ProductoRepository
IngredienteRepository"]
            BP_SV["CategoriaService"]
            BP_R2["CategoriaRepository"]
            BP_MD["Producto · Categoria
IngredienteProducto"]
            BP_C1 -- "sin service,
repo directo" --> BP_R1
            BP_C2 --> BP_SV --> BP_R2
            BP_R1 --> BP_MD
            BP_R2 --> BP_MD
        end

        subgraph BI["Inventario"]
            direction TB
            BI_C["InventarioController /api/inventario
ProductosMovimientosController /api/productos
BackupInventarioController"]
            BI_SV["InventarioService
InventarioIngredientesService
MovimientoStockService
BackupInventarioService"]
            BI_R["InventarioRepository
MovimientoInventarioRepository
MovimientoStockRepository"]
            BI_MD["Inventario · MovimientoInventario
MovimientoStock · AjusteInventario"]
            BI_C --> BI_SV --> BI_R --> BI_MD
        end

        subgraph BC["Compras"]
            direction TB
            BC_C["CompraController
/api/compras, /api/facturas-compras
FacturaCompraPdfImportController"]
            BC_SV["CompraService
FacturaCompraPdfParserFactory
(parsers por proveedor: Akt, Cassarella,
IdLaser, Pysta, etc.)"]
            BC_R["CompraRepository"]
            BC_MD["Compra"]
            BC_C --> BC_SV --> BC_R --> BC_MD
        end
    end

    FP_SRV -- "HTTP REST" --> BP_C1
    FP_SRV -- "HTTP REST" --> BP_C2
    FI_SRV -- "HTTP REST" --> BI_C
    FC_SRV -- "HTTP REST" --> BC_C

    BC_SV -. "actualiza stock\nal procesar/anular compra" .-> BP_R1
    BC_SV -. "registra movimiento\nde inventario" .-> BI_R
```

## Notas verificadas en el código (no es un diagrama inventado)

- **Backend asimétrico**: `ProductosController` NO tiene `ProductoService` — va
  directo al `ProductoRepository` (extiende `BaseController<Producto, String>`).
  `Categoria`, en cambio, sí tiene su stack completo Controller→Service→Repository.
  Es inconsistencia real del backend, no una simplificación del diagrama.
- **Frontend sin capa de repositorio/controller**: como se señala en
  [`componentes_compartidos_y_duplicacion.md`](componentes_compartidos_y_duplicacion.md),
  el frontend no tiene repository ni controller — las screens llaman servicios
  directo, y la mayoría de servicios tampoco pasan por `BaseApiService`.
- **El acoplamiento real "Compras → Inventario/Productos"**: `CompraService`
  inyecta `ProductoRepository`, `InventarioRepository`,
  `MovimientoInventarioRepository` y `MovimientoStockService` directamente —
  confirma que el backend revierte/aplica stock al procesar o anular una compra;
  el frontend solo consulta el historial de movimientos.
- **Categorías en el frontend** no tienen servicio propio: `categorias_screen.dart`
  usa `producto_service.dart`, aunque el backend sí las separa en su propio
  Controller/Service/Repository.

*Generado a partir de los archivos reales en `lib/` (este repo) y
`vercy/src/main/java/com/prog3/security/` (backend), no de una plantilla genérica.
Volver a verificar con grep si ha pasado tiempo desde esta fecha.*
