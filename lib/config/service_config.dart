import 'endpoints_config.dart';

/// Configuración para facilitar la migración entre servicios antiguos y nuevos
///
/// Para usar los nuevos servicios estandarizados, cambia [useV2Services] a true
/// Para volver a los servicios antiguos, cambia [useV2Services] a false

class ServiceConfig {
  // Singleton
  static final ServiceConfig _instance = ServiceConfig._internal();
  factory ServiceConfig() => _instance;
  ServiceConfig._internal();

  /// Controla si se usan los servicios V2 (estandarizados) o los antiguos
  static const bool useV2Services = true;

  /// Obtiene la URL base del backend desde EndpointsConfig
  String get baseUrl => EndpointsConfig().currentBaseUrl + '/api';

  /// Timeout por defecto para peticiones HTTP
  static const Duration defaultTimeout = Duration(seconds: 10);

  /// Habilitar logging detallado
  static const bool enableLogging = true;

  /// Habilitar fallbacks locales cuando no hay conexión
  static const bool enableLocalFallbacks = true;

  /// Obtiene la instancia global de ServiceConfig
  static ServiceConfig get instance => _instance;
}

/// Factory para obtener la instancia correcta del servicio según la configuración
class ServiceFactory {
  /// Obtiene el servicio de mesas apropiado
  static dynamic getMesaService() {
    if (ServiceConfig.useV2Services) {
      // Importar dinámicamente cuando esté listo
      return null; // MesaServiceV2();
    } else {
      // Importar dinámicamente cuando esté listo
      return null; // MesaService();
    }
  }

  /// Obtiene el servicio de productos apropiado
  static dynamic getProductoService() {
    if (ServiceConfig.useV2Services) {
      return null; // ProductoServiceV2();
    } else {
      return null; // ProductoService();
    }
  }

  /// Obtiene el servicio de pedidos apropiado
  static dynamic getPedidoService() {
    if (ServiceConfig.useV2Services) {
      return null; // PedidoServiceV2();
    } else {
      return null; // PedidoService();
    }
  }
}

/// Configuración de endpoints
class ApiEndpoints {
  static const String mesas = '/mesas';
  static const String productos = '/productos';
  static const String categorias = '/categorias';
  static const String pedidos = '/pedidos';
  static const String inventario = '/inventario';
  static const String reportes = '/reportes';

  // Endpoints específicos de reportes
  static const String dashboard = '$reportes/dashboard';
  static const String ventasPeriodo = '$reportes/ventas-periodo';
  static const String productosVendidos = '$reportes/productos-mas-vendidos';
  static const String inventarioValorizado = '$reportes/inventario-valorizado';
  static const String movimientosInventario =
      '$reportes/movimientos-inventario';
  static const String alertas = '$reportes/alertas';
  static const String cuadreCaja = '$reportes/cuadre-caja';
}
