import 'dart:async';
import '../models/producto.dart';
import 'producto_service.dart';

/// Servicio para carga progresiva y lazy loading de imágenes de productos
///
/// Estrategia:
/// 1. Los productos se cargan sin imágenes (rápido)
/// 2. Las imágenes se cargan en lotes de 20 productos
/// 3. Se cargan solo las imágenes visibles en pantalla
/// 4. Se precargan imágenes cercanas para scroll suave
class ImageLoaderService {
  static final ImageLoaderService _instance = ImageLoaderService._internal();
  factory ImageLoaderService() => _instance;
  ImageLoaderService._internal();

  final ProductoService _productoService = ProductoService();

  // Cache de imágenes ya cargadas: productoId -> imagenUrl
  final Map<String, String> _imagenesCache = {};

  // IDs de productos con carga en progreso
  final Set<String> _cargandoImagenes = {};

  // Callbacks para notificar cambios de imágenes
  final Map<String, List<Function(String? imagenUrl)>> _listeners = {};

  /// Registra un listener para cambios de imagen de un producto
  void addImageListener(
    String productoId,
    Function(String? imagenUrl) callback,
  ) {
    if (!_listeners.containsKey(productoId)) {
      _listeners[productoId] = [];
    }
    _listeners[productoId]!.add(callback);
  }

  /// Elimina un listener
  void removeImageListener(
    String productoId,
    Function(String? imagenUrl) callback,
  ) {
    _listeners[productoId]?.remove(callback);
    if (_listeners[productoId]?.isEmpty ?? false) {
      _listeners.remove(productoId);
    }
  }

  /// Obtiene una imagen del cache (si existe)
  String? getImagenFromCache(String productoId) {
    return _imagenesCache[productoId];
  }

  /// Verifica si una imagen está en cache
  bool hasImageInCache(String productoId) {
    return _imagenesCache.containsKey(productoId);
  }

  /// Carga las imágenes de un lote de productos (máximo 20)
  /// NOTA: Usa endpoint individual GET /api/productos/{id}/imagen
  Future<void> cargarImagenesLote(List<Producto> productos) async {
    // 🚫 CARGA DE IMÁGENES DESACTIVADA - No hace nada
    return;

    // CÓDIGO DESACTIVADO TEMPORALMENTE:
    /*
    // Filtrar productos que no tienen imagen cargada y no están en proceso
    final productosNecesitanImagen = productos
        .where(
          (p) =>
              !_imagenesCache.containsKey(p.id) &&
              !_cargandoImagenes.contains(p.id),
        )
        .toList();

    if (productosNecesitanImagen.isEmpty) {
      print('✅ Todas las imágenes ya están en cache');
      return;
    }

    // Limitar a 20 productos
    final productosLimitados = productosNecesitanImagen.take(20).toList();

    print(
      '🖼️ Cargando ${productosLimitados.length} imágenes individualmente...',
    );

    // ⚡ CAMBIO: Cargar cada imagen individualmente usando el endpoint correcto
    for (var producto in productosLimitados) {
      // Marcar como en progreso
      _cargandoImagenes.add(producto.id);

      try {
        // Usar endpoint individual: GET /api/productos/{id}/imagen
        final imagenUrl = await _productoService.cargarImagenProducto(
          producto.id,
        );
        
        if (imagenUrl != null && imagenUrl.isNotEmpty) {
          // Guardar en cache
          _imagenesCache[producto.id] = imagenUrl;

          // Notificar a todos los listeners de este producto
          _notificarListeners(producto.id, imagenUrl);
        }
      } catch (e) {
        print('❌ Error cargando imagen de ${producto.id}: $e');
      } finally {
        // Remover de lista de carga
        _cargandoImagenes.remove(producto.id);
      }
    }

    print('✅ Lote completado: ${_imagenesCache.length} imágenes en cache');
    */
  }

  /// Carga la imagen de un solo producto
  Future<String?> cargarImagenProducto(String productoId) async {
    // 🚫 CARGA DE IMÁGENES DESACTIVADA - Retorna null inmediatamente
    return null;

    // CÓDIGO DESACTIVADO TEMPORALMENTE:
    /*
    // Si ya está en cache, retornar
    if (_imagenesCache.containsKey(productoId)) {
      return _imagenesCache[productoId];
    }

    // Si ya está cargando, esperar
    if (_cargandoImagenes.contains(productoId)) {
      print('⏳ Ya se está cargando la imagen de $productoId');
      return null;
    }

    print('🖼️ Cargando imagen individual: $productoId');
    _cargandoImagenes.add(productoId);

    try {
      final imagenUrl = await _productoService.cargarImagenProducto(productoId);

      if (imagenUrl != null) {
        _imagenesCache[productoId] = imagenUrl;

        // Notificar listeners
        _notificarListeners(productoId, imagenUrl);

        return imagenUrl;
      }

      return null;
    } catch (e) {
      print('❌ Error cargando imagen: $e');
      return null;
    } finally {
      _cargandoImagenes.remove(productoId);
    }
    */
  }

  /// Precarga imágenes de productos cercanos (para scroll suave)
  Future<void> precargarImagenesCercanas(
    List<Producto> todosProductos,
    int indiceActual, {
    int cantidadAdelante = 10,
    int cantidadAtras = 5,
  }) async {
    // 🚫 CARGA DE IMÁGENES DESACTIVADA - No hace nada
    return;

    // CÓDIGO DESACTIVADO TEMPORALMENTE:
    /*
    final inicio = (indiceActual - cantidadAtras).clamp(
      0,
      todosProductos.length,
    );
    final fin = (indiceActual + cantidadAdelante).clamp(
      0,
      todosProductos.length,
    );

    final productosCercanos = todosProductos.sublist(inicio, fin);

    print(
      '🔄 Precargando imágenes cercanas: ${productosCercanos.length} productos',
    );
    await cargarImagenesLote(productosCercanos);
    */
  }

  /// Notifica a los listeners sobre cambios en la imagen
  void _notificarListeners(String productoId, String? imagenUrl) {
    if (_listeners.containsKey(productoId)) {
      for (var callback in _listeners[productoId]!) {
        callback(imagenUrl);
      }
    }
  }

  /// Invalida la imagen en caché de un producto específico
  void invalidateProductImage(String productoId) {
    _imagenesCache.remove(productoId);
    print('🗑️ Cache de imagen invalidado para producto: $productoId');

    // ✅ Notificar a los listeners que el cache fue invalidado
    // Pasar null para indicar que deben recargar
    _notificarListeners(productoId, null);
  }

  /// Limpia el cache de imágenes
  void clearCache() {
    _imagenesCache.clear();
    _cargandoImagenes.clear();
    _listeners.clear();
    print('🧹 Cache de imágenes limpiado');
  }

  /// Obtiene estadísticas del cache
  Map<String, dynamic> getStats() {
    return {
      'imagenesEnCache': _imagenesCache.length,
      'imagenesEnProgreso': _cargandoImagenes.length,
      'listenersActivos': _listeners.length,
    };
  }
}
