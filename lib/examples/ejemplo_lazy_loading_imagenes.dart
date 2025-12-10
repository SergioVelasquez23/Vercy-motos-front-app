import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../widgets/lazy_imagen_producto.dart';

/// EJEMPLO DE USO: Cómo usar el lazy loading de imágenes
///
/// Este ejemplo muestra cómo implementar correctamente el lazy loading
/// de imágenes de productos usando los endpoints optimizados:
///
/// 1. GET /api/productos/ligero?page=0&size=40
///    → Carga productos SIN imágenes (ultra rápido: 5-15s)
///
/// 2. GET /api/productos/{id}/imagen
///    → Carga imagen individual cuando se muestra (lazy loading)

class EjemploLazyLoadingProductos extends StatelessWidget {
  final List<Producto> productos;

  const EjemploLazyLoadingProductos({Key? key, required this.productos})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Productos con Lazy Loading'),
        backgroundColor: Colors.orange,
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: productos.length,
        itemBuilder: (context, index) {
          final producto = productos[index];
          return _buildProductoCard(producto);
        },
      ),
    );
  }

  Widget _buildProductoCard(Producto producto) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ✅ LAZY LOADING: La imagen se carga solo cuando es visible
          Expanded(
            child: LazyImagenProducto(
              productoId: producto.id,
              productoNombre: producto.nombre,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  '\$${producto.precio.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// EJEMPLO 2: Lista vertical con imágenes más pequeñas
class EjemploListaVerticalProductos extends StatelessWidget {
  final List<Producto> productos;

  const EjemploListaVerticalProductos({Key? key, required this.productos})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final producto = productos[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            // ✅ LAZY LOADING: Imagen pequeña 60x60
            leading: LazyImagenProducto(
              productoId: producto.id,
              productoNombre: producto.nombre,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
            title: Text(producto.nombre),
            subtitle: Text('\$${producto.precio.toStringAsFixed(2)}'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navegar a detalle del producto
            },
          ),
        );
      },
    );
  }
}

/// EJEMPLO 3: Cómo cargar los productos RÁPIDAMENTE
/// 
/// Usa esto en tu initState o al abrir la pantalla:
/// 
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   _cargarProductosRapido();
/// }
/// 
/// Future<void> _cargarProductosRapido() async {
///   final provider = Provider.of<DatosCacheProvider>(context, listen: false);
///   
///   // Esto carga productos SIN imágenes en 5-15 segundos
///   await provider.warmupProductos();
///   
///   // Después cada LazyImagenProducto cargará su imagen individual
///   // cuando sea visible en pantalla
/// }
/// ```
