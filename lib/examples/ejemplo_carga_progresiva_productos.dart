/// Ejemplo de cómo usar la carga progresiva de productos
///
/// Este archivo muestra diferentes formas de implementar la carga
/// progresiva de productos usando el ProductoService mejorado.

import '../services/producto_service.dart';
import '../models/producto.dart';

class EjemploCargaProgresiva {
  final ProductoService _productoService = ProductoService();

  /// Ejemplo 1: Carga manual página por página
  Future<void> ejemploCargaManual() async {
      

    try {
      // Iniciar carga progresiva con páginas de 30 productos
      var resultado = await _productoService.iniciarCargaProgresiva(
        pageSize: 30,
      );
      // Cargar más páginas manualmente
      int paginasCargadas = 1;
      while (resultado['hasMore'] == true && paginasCargadas < 5) {
        // Límite de 5 páginas para el ejemplo
          

        resultado = await _productoService.cargarSiguientePaginaProductos();
        paginasCargadas++;
        
        // Simular un delay para ver el progreso
        await Future.delayed(Duration(seconds: 1));
      }

      // Obtener todos los productos cargados hasta ahora
      final productosActuales = _productoService.productosActualmenteCargados;
      print(
        '\n🎯 Total de productos disponibles localmente: ${productosActuales.length}',
      );
    } catch (e) {
        
    }
  }

  /// Ejemplo 2: Carga automática completa con seguimiento de progreso
  Future<void> ejemploCargaAutomatica() async {
      

    try {
      final productos = await _productoService
          .cargarTodosLosProductosProgresivamente(
            pageSize: 40, // Cargar de 40 en 40
            delayBetweenPages: Duration(
              milliseconds: 300,
            ), // Pausa de 300ms entre páginas
            onProgressUpdate: (progreso) {
              print(
                '📈 Progreso: ${progreso['porcentaje']}% - ${progreso['totalCargados']}/${progreso['totalElementos']} productos',
              );
            },
          );

        
    } catch (e) {
        
    }
  }

  /// Ejemplo 3: Usar productos mientras se cargan en segundo plano
  Future<void> ejemploUsoMientrasCarga() async {
      

    try {
      // Iniciar carga con la primera página
      var resultado = await _productoService.iniciarCargaProgresiva(
        pageSize: 50,
      );

      print(
        '📦 Primera página lista: ${resultado['productos'].length} productos',
      );

      // Mostrar productos de la primera página inmediatamente
      _mostrarProductos(resultado['productos']);

      // Continuar cargando en segundo plano
      _cargarEnSegundoPlano();

      // Simular uso de la aplicación
      await Future.delayed(Duration(seconds: 2));

      // Ver cuántos productos tenemos ahora
      final estado = _productoService.estadoPaginacion;
      print(
        '\n📊 Después de 2 segundos - Productos disponibles: ${estado['totalCargados']}',
      );
    } catch (e) {
        
    }
  }

  /// Ejemplo 4: Búsqueda y filtrado en productos cargados
  Future<void> ejemploBusquedaYFiltrado() async {
      

    try {
      // Asegurar que tenemos algunos productos cargados
      if (_productoService.productosActualmenteCargados.isEmpty) {
        await _productoService.iniciarCargaProgresiva(pageSize: 100);
      }

      // Buscar productos por nombre
      final productosConPizza = _productoService.filtrarProductosCargados(
        searchQuery: 'pizza',
      );
        

      // Filtrar productos disponibles
      final productosDisponibles = _productoService.filtrarProductosCargados(
        disponible: true,
      );
        

      // Buscar un producto específico en cache
      if (_productoService.productosActualmenteCargados.isNotEmpty) {
        final primerProducto =
            _productoService.productosActualmenteCargados.first;
        final productoEncontrado = _productoService.buscarProductoEnCache(
          primerProducto.id,
        );
        print(
          '🔍 Producto encontrado en cache: ${productoEncontrado?.nombre ?? 'No encontrado'}',
        );
      }
    } catch (e) {
        
    }
  }

  /// Ejemplo 5: Integración con UI usando getProductos mejorado
  Future<void> ejemploIntegracionUI() async {
      

    try {
      // Opción 1: Carga tradicional (todo de una vez)
        
      final productosTradicion = await _productoService.getProductos(
        useProgressive: false,
      );
        

      // Limpiar cache para el siguiente ejemplo
      _productoService.reiniciarCargaProgresiva();

      // Opción 2: Carga progresiva automática
        
      final productosProgresivos = await _productoService.getProductos(
        useProgressive: true,
      );
        
    } catch (e) {
        
    }
  }

  /// Método auxiliar para cargar productos en segundo plano
  void _cargarEnSegundoPlano() async {
    while (_productoService.estadoPaginacion['hasMore'] == true) {
      await Future.delayed(Duration(milliseconds: 500));

      if (!(_productoService.estadoPaginacion['isLoading'] as bool)) {
        await _productoService.cargarSiguientePaginaProductos();
        final estado = _productoService.estadoPaginacion;
        print(
          '🔄 Segundo plano: ${estado['totalCargados']} productos cargados',
        );
      }
    }
      
  }

  /// Método auxiliar para mostrar productos
  void _mostrarProductos(List<Producto> productos) {
      
    for (int i = 0; i < productos.length && i < 5; i++) {
      // Mostrar solo los primeros 5
      final producto = productos[i];
        
    }
    if (productos.length > 5) {
        
    }
  }

  /// Ejecutar todos los ejemplos
  Future<void> ejecutarTodosLosEjemplos() async {
      

    await ejemploCargaManual();
    await Future.delayed(Duration(seconds: 2));

    _productoService
        .reiniciarCargaProgresiva(); // Limpiar para el siguiente ejemplo
    await ejemploCargaAutomatica();
    await Future.delayed(Duration(seconds: 2));

    _productoService.reiniciarCargaProgresiva();
    await ejemploUsoMientrasCarga();
    await Future.delayed(Duration(seconds: 2));

    await ejemploBusquedaYFiltrado();
    await Future.delayed(Duration(seconds: 2));

    _productoService.reiniciarCargaProgresiva();
    await ejemploIntegracionUI();

      
  }
}

/// Función principal para ejecutar los ejemplos
Future<void> main() async {
  final ejemplo = EjemploCargaProgresiva();
  await ejemplo.ejecutarTodosLosEjemplos();
}
