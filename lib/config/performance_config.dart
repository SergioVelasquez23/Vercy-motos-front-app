// 🚀 CONFIGURACIÓN DE RENDIMIENTO - OPTIMIZACIONES DE CARGA
// Este archivo centraliza todos los parámetros de rendimiento para facilitar ajustes

class PerformanceConfig {
  // ===== CONFIGURACIÓN DE CACHE =====

  /// Duración del cache para ingredientes (en memoria)
  static const Duration ingredientesCacheDuration = Duration(minutes: 10);

  /// Duración del cache para productos
  static const Duration productosCacheDuration = Duration(minutes: 30);

  /// Duración del cache para categorías
  static const Duration categoriasCacheDuration = Duration(hours: 1);

  // ===== CONFIGURACIÓN DE PAGINACIÓN =====

  /// Elementos por página en listas de ingredientes
  static const int ingredientesPorPagina = 20;

  /// Elementos por página en listas de productos
  static const int productosPorPagina = 15;

  /// Elementos por página en búsqueda de ingredientes (diálogos)
  static const int ingredientesDialogoPorPagina = 15;

  // ===== CONFIGURACIÓN DE LAZY LOADING =====

  /// Retraso antes de iniciar precarga de datos (ms)
  static const int precargaDelayMs = 500;

  /// Cache extent para ListView optimizado (pixels)
  static const double listViewCacheExtent = 500.0;

  /// Número máximo de elementos a renderizar simultáneamente
  static const int maxElementosSimultaneos = 50;

  // ===== CONFIGURACIÓN DE UI/UX =====

  /// Duración del debounce para búsquedas (ms)
  static const int searchDebounceMs = 300;

  /// Tiempo de espera para mostrar loading en recargas (ms)
  static const int loadingDelayMs = 200;

  /// Duración de animaciones de transición (ms)
  static const int animationDurationMs = 250;

  // ===== CONFIGURACIÓN DE RED =====

  /// Timeout para requests de API (segundos)
  static const int apiTimeoutSeconds = 15;

  /// Número máximo de reintentos para requests fallidos
  static const int maxRetries = 3;

  /// Retraso entre reintentos (ms)
  static const int retryDelayMs = 1000;

  // ===== MÉTODOS DE AYUDA =====

  /// Verifica si el cache es válido basado en timestamp
  static bool isCacheValid(DateTime? cacheTime, Duration maxAge) {
    if (cacheTime == null) return false;
    return DateTime.now().difference(cacheTime) < maxAge;
  }

  /// Calcula el número de elementos a mostrar por página basado en altura de pantalla
  static int calcularElementosPorPagina(
    double screenHeight,
    double itemHeight,
  ) {
    final visibleItems = (screenHeight / itemHeight).floor();
    return (visibleItems * 1.5)
        .clamp(10, 50)
        .toInt(); // 50% más para smooth scroll
  }

  /// Determina si debe mostrar loading basado en el tiempo transcurrido
  static bool shouldShowLoading(DateTime startTime) {
    return DateTime.now().difference(startTime).inMilliseconds > loadingDelayMs;
  }

  // ===== CONFIGURACIÓN DE LOGGING =====

  /// Habilitar logs de rendimiento detallados
  static const bool enablePerformanceLogs = true;

  /// Habilitar logs de cache hits/misses
  static const bool enableCacheLogs = true;

  /// Habilitar logs de tiempo de carga
  static const bool enableTimingLogs = true;

  // ===== CONFIGURACIÓN ESPECÍFICA POR PANTALLA =====

  static const Map<String, int> elementosPorPantalla = {
    'productos': 15,
    'ingredientes': 20,
    'categorias': 25,
    'pedidos': 12,
    'mesas': 18,
  };

  /// Obtiene la configuración de paginación para una pantalla específica
  static int getElementosPorPagina(String pantalla) {
    return elementosPorPantalla[pantalla] ?? productosPorPagina;
  }
}

// ===== ENUMS PARA CONFIGURACIÓN =====

enum CacheStrategy {
  aggressive, // Cache todo lo posible
  balanced, // Balance entre memoria y performance
  minimal, // Solo cache esencial
}

enum LoadingStrategy {
  immediate, // Mostrar loading inmediatamente
  delayed, // Esperar antes de mostrar loading
  progressive, // Loading progresivo por secciones
}

// ===== EXTENSIONES DE AYUDA =====

extension DurationExtensions on Duration {
  bool get isExpired =>
      DateTime.now().difference(DateTime.now().subtract(this)).abs() > this;
}
