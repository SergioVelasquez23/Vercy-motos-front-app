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
    print('🚀 === EJEMPLO 1: CARGA MANUAL PÁGINA POR PÁGINA ===');

    try {
      // Iniciar carga progresiva con páginas de 30 productos
      var resultado = await _productoService.iniciarCargaProgresiva(
        pageSize: 30,
      );

      print(
        '📦 Primera página cargada: ${resultado['productos'].length} productos',
      );
      print(
        '📊 Estado: ${resultado['totalCargados']}/${resultado['totalElementos']} productos cargados',
      );

      // Cargar más páginas manualmente
      int paginasCargadas = 1;
      while (resultado['hasMore'] == true && paginasCargadas < 5) {
        // Límite de 5 páginas para el ejemplo
        print('\n⏳ Cargando página ${paginasCargadas + 1}...');

        resultado = await _productoService.cargarSiguientePaginaProductos();
        paginasCargadas++;

        print(
          '✅ Página cargada: ${resultado['productos'].length} productos nuevos',
        );
        print(
          '📊 Estado: ${resultado['totalCargados']}/${resultado['totalElementos']} productos cargados',
        );

        // Simular un delay para ver el progreso
        await Future.delayed(Duration(seconds: 1));
      }

      // Obtener todos los productos cargados hasta ahora
      final productosActuales = _productoService.productosActualmenteCargados;
      print(
        '\n🎯 Total de productos disponibles localmente: ${productosActuales.length}',
      );
    } catch (e) {
      print('❌ Error en carga manual: $e');
    }
  }

  /// Ejemplo 2: Carga automática completa con seguimiento de progreso
  Future<void> ejemploCargaAutomatica() async {
    print('\n🚀 === EJEMPLO 2: CARGA AUTOMÁTICA COMPLETA ===');

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

      print('🎉 ¡Carga completa! Total: ${productos.length} productos');
    } catch (e) {
      print('❌ Error en carga automática: $e');
    }
  }

  /// Ejemplo 3: Usar productos mientras se cargan en segundo plano
  Future<void> ejemploUsoMientrasCarga() async {
    print('\n🚀 === EJEMPLO 3: USO MIENTRAS SE CARGA ===');

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
      print('❌ Error: $e');
    }
  }

  /// Ejemplo 4: Búsqueda y filtrado en productos cargados
  Future<void> ejemploBusquedaYFiltrado() async {
    print('\n🚀 === EJEMPLO 4: BÚSQUEDA Y FILTRADO ===');

    try {
      // Asegurar que tenemos algunos productos cargados
      if (_productoService.productosActualmenteCargados.isEmpty) {
        await _productoService.iniciarCargaProgresiva(pageSize: 100);
      }

      // Buscar productos por nombre
      final productosConPizza = _productoService.filtrarProductosCargados(
        searchQuery: 'pizza',
      );
      print('🍕 Productos con "pizza": ${productosConPizza.length}');

      // Filtrar productos disponibles
      final productosDisponibles = _productoService.filtrarProductosCargados(
        disponible: true,
      );
      print('✅ Productos disponibles: ${productosDisponibles.length}');

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
      print('❌ Error en búsqueda: $e');
    }
  }

  /// Ejemplo 5: Integración con UI usando getProductos mejorado
  Future<void> ejemploIntegracionUI() async {
    print('\n🚀 === EJEMPLO 5: INTEGRACIÓN CON UI ===');

    try {
      // Opción 1: Carga tradicional (todo de una vez)
      print('📋 Cargando productos de forma tradicional...');
      final productosTradicion = await _productoService.getProductos(
        useProgressive: false,
      );
      print('✅ Método tradicional: ${productosTradicion.length} productos');

      // Limpiar cache para el siguiente ejemplo
      _productoService.reiniciarCargaProgresiva();

      // Opción 2: Carga progresiva automática
      print('\n📋 Cargando productos de forma progresiva...');
      final productosProgresivos = await _productoService.getProductos(
        useProgressive: true,
      );
      print('✅ Método progresivo: ${productosProgresivos.length} productos');
    } catch (e) {
      print('❌ Error en integración UI: $e');
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
    print('🏁 Carga en segundo plano completada');
  }

  /// Método auxiliar para mostrar productos
  void _mostrarProductos(List<Producto> productos) {
    print('📋 Productos disponibles:');
    for (int i = 0; i < productos.length && i < 5; i++) {
      // Mostrar solo los primeros 5
      final producto = productos[i];
      print('   ${i + 1}. ${producto.nombre} - \$${producto.precio}');
    }
    if (productos.length > 5) {
      print('   ... y ${productos.length - 5} productos más');
    }
  }

  /// Ejecutar todos los ejemplos
  Future<void> ejecutarTodosLosEjemplos() async {
    print('🎯 === INICIANDO EJEMPLOS DE CARGA PROGRESIVA ===\n');

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

    print('\n🎉 === TODOS LOS EJEMPLOS COMPLETADOS ===');
  }
}

/// Función principal para ejecutar los ejemplos
Future<void> main() async {
  final ejemplo = EjemploCargaProgresiva();
  await ejemplo.ejecutarTodosLosEjemplos();
}
