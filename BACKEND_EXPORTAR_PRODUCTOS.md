# Backend - Exportar Productos en Excel

## Endpoints Requeridos

### 1. Descargar Productos en Excel

**Endpoint:**
```
GET /api/productos/exportar-excel
```

**Descripción:**
Descarga todos los productos en formato Excel (.xlsx) con la misma estructura de columnas que se usa para la carga masiva.

**Parámetros de Query (opcionales):**
- `categoria` (string): Filtrar por categoría específica
- `bodega` (number): Filtrar por cantidad en bodega
- `almacen` (number): Filtrar por cantidad en almacén
- `conImagenes` (boolean): Si se deben incluir URLs de imágenes

**Respuesta:**
```
Status: 200 OK
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="productos.xlsx"
Body: Bytes del archivo Excel
```

**Ejemplo de uso desde Flutter:**
```dart
// Sin filtros - descargar todos
final bytes = await _productoService.descargarProductosExcel();

// Con filtros
final bytes = await _productoService.descargarProductosFiltrados(
  categoria: 'motocicletas',
  conImagenes: true,
);
```

## Estructura del Excel

El archivo Excel debe tener las siguientes columnas en este orden:

1. **CODIGO** (string) - Código único del producto
2. **NOMBRE** (string) - Nombre del producto
3. **CANTIDAD** (number) - Cantidad base
4. **UNIDAD MEDIDA** (string) - Unidad (Und, Kgs, Lts, etc.)
5. **PRECIO UNITARIO** (number) - Precio de venta
6. **COSTO PROMEDIO UNITARIO** (number) - Costo unitario promedio
7. **COSTO TOTAL** (number) - Costo total
8. **OPORTUNIDAD DE GANANCIA** (number)
9. **% UTILIDAD** (number) - Porcentaje de utilidad
10. **TIPO IMPUESTO** (string) - IVA, EXCLUIDO, etc.
11. **PORCENTAJE IMPUESTO** (number) - Porcentaje del impuesto
12. **TIPO LINEA** (string) - Tipo de línea de producto
13. **CLASE** (string) - Clasificación
14. **SUBCLASE** (string) - Subclasificación
15. **ILIMITADO** (boolean) - Producto sin límite de stock
16. **INVENTARIO BAJO** (number) - Umbral de stock bajo
17. **INVENTARIO OPTIMO** (number) - Stock óptimo
18. **MARCA** (string) - Marca del producto
19. **PROVEEDOR** (string) - Proveedor
20. **ESTADO** (string) - Activo/Inactivo
21. **ESTADO INV** (string) - Estado de inventario
22. **LISTA PRECIO 1** (number)
23. **LISTA PRECIO 2** (number)
24. **LISTA PRECIO 3** (number)
25. **LISTA PRECIO 4** (number)
26. **LISTA PRECIO 5** (number)
27. **COD. BARRAS** (string) - Código de barras
28. **BODEGA** (number) - Cantidad en bodega (para carga bodega)
   ó
    **ALMACEN** (number) - Cantidad en almacén (para carga almacén)

## Implementación Recomendada

### Node.js/Express + ExcelJS

```javascript
const express = require('express');
const ExcelJS = require('exceljs');
const app = express();

app.get('/api/productos/exportar-excel', async (req, res) => {
  try {
    // Obtener productos de la BD (aplicar filtros si existen)
    let query = Producto.find();
    
    if (req.query.categoria) {
      query = query.where('categoria').equals(req.query.categoria);
    }
    if (req.query.bodega) {
      query = query.where('bodega').gte(req.query.bodega);
    }
    
    const productos = await query.exec();

    // Crear workbook
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Productos');

    // Agregar encabezados
    const headers = [
      'CODIGO', 'NOMBRE', 'CANTIDAD', 'UNIDAD MEDIDA', 
      'PRECIO UNITARIO', 'COSTO PROMEDIO UNITARIO', 'COSTO TOTAL',
      'OPORTUNIDAD DE GANANCIA', '% UTILIDAD', 'TIPO IMPUESTO',
      'PORCENTAJE IMPUESTO', 'TIPO LINEA', 'CLASE', 'SUBCLASE',
      'ILIMITADO', 'INVENTARIO BAJO', 'INVENTARIO OPTIMO', 'MARCA',
      'PROVEEDOR', 'ESTADO', 'ESTADO INV', 'LISTA PRECIO 1',
      'LISTA PRECIO 2', 'LISTA PRECIO 3', 'LISTA PRECIO 4',
      'LISTA PRECIO 5', 'COD. BARRAS', 'BODEGA'
    ];
    
    worksheet.addRow(headers);

    // Agregar datos de productos
    productos.forEach(producto => {
      worksheet.addRow([
        producto.codigo,
        producto.nombre,
        producto.cantidad,
        producto.unidadMedida,
        producto.precioUnitario,
        producto.costoPromedioUnitario,
        producto.costoTotal,
        producto.oportunidadGanancia,
        producto.porcentajeUtilidad,
        producto.tipoImpuesto,
        producto.porcentajeImpuesto,
        producto.tipoLinea,
        producto.clase,
        producto.subclase,
        producto.ilimitado,
        producto.inventarioBajo,
        producto.inventarioOptimo,
        producto.marca,
        producto.proveedor,
        producto.estado,
        producto.estadoInv,
        producto.listaPrecios?.precio1 || 0,
        producto.listaPrecios?.precio2 || 0,
        producto.listaPrecios?.precio3 || 0,
        producto.listaPrecios?.precio4 || 0,
        producto.listaPrecios?.precio5 || 0,
        producto.codigoBarras,
        producto.bodega
      ]);
    });

    // Configurar respuesta
    res.setHeader('Content-Type', 
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 
      'attachment; filename="productos.xlsx"');

    // Escribir archivo
    await workbook.xlsx.write(res);
    res.end();

  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});
```

### Python/Django

```python
from django.http import HttpResponse
from django.views.decorators.http import require_http_methods
from openpyxl import Workbook
from io import BytesIO
from .models import Producto

@require_http_methods(["GET"])
def exportar_productos_excel(request):
    try:
        # Filtros opcionales
        query = Producto.objects.all()
        
        if request.GET.get('categoria'):
            query = query.filter(categoria=request.GET.get('categoria'))
        
        if request.GET.get('bodega'):
            query = query.filter(bodega__gte=int(request.GET.get('bodega')))

        # Crear workbook
        wb = Workbook()
        ws = wb.active
        ws.title = "Productos"

        # Encabezados
        headers = [
            'CODIGO', 'NOMBRE', 'CANTIDAD', 'UNIDAD MEDIDA',
            'PRECIO UNITARIO', 'COSTO PROMEDIO UNITARIO', 'COSTO TOTAL',
            'OPORTUNIDAD DE GANANCIA', '% UTILIDAD', 'TIPO IMPUESTO',
            'PORCENTAJE IMPUESTO', 'TIPO LINEA', 'CLASE', 'SUBCLASE',
            'ILIMITADO', 'INVENTARIO BAJO', 'INVENTARIO OPTIMO', 'MARCA',
            'PROVEEDOR', 'ESTADO', 'ESTADO INV', 'LISTA PRECIO 1',
            'LISTA PRECIO 2', 'LISTA PRECIO 3', 'LISTA PRECIO 4',
            'LISTA PRECIO 5', 'COD. BARRAS', 'BODEGA'
        ]
        
        ws.append(headers)

        # Agregar datos
        for producto in query:
            ws.append([
                producto.codigo,
                producto.nombre,
                producto.cantidad,
                producto.unidad_medida,
                producto.precio_unitario,
                producto.costo_promedio,
                producto.costo_total,
                producto.oportunidad_ganancia,
                producto.porcentaje_utilidad,
                producto.tipo_impuesto,
                producto.porcentaje_impuesto,
                producto.tipo_linea,
                producto.clase,
                producto.subclase,
                producto.ilimitado,
                producto.inventario_bajo,
                producto.inventario_optimo,
                producto.marca,
                producto.proveedor,
                producto.estado,
                producto.estado_inv,
                producto.lista_precio_1,
                producto.lista_precio_2,
                producto.lista_precio_3,
                producto.lista_precio_4,
                producto.lista_precio_5,
                producto.codigo_barras,
                producto.bodega
            ])

        # Preparar respuesta
        output = BytesIO()
        wb.save(output)
        output.seek(0)

        response = HttpResponse(
            output.read(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        )
        response['Content-Disposition'] = 'attachment; filename=productos.xlsx'
        
        return response

    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=500)
```

## Notas Importantes

1. ✅ El endpoint debe retornar el archivo Excel binario con headers CORS adecuados
2. ✅ El Content-Type debe ser exactamente: `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
3. ✅ El nombre del archivo en Content-Disposition es sugerido, el frontend renombrará con timestamp
4. ✅ Los filtros son opcionales y deben ignorarse si no se proporcionan
5. ✅ Los mismos encabezados usados en exportación deben coincidir con lo usado en importación (carga masiva)
