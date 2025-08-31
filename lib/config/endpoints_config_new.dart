/// Configuración de endpoints de la API mejorada
///
/// MEJORAS:
/// - Recibe URL base como parámetro (no hardcodeada)
/// - Mejor organización de endpoints
/// - Documentación completa
/// - Validación de URLs
class EndpointsConfig {
  final String _baseUrl;

  /// Constructor que recibe la URL base detectada automáticamente
  EndpointsConfig(this._baseUrl) {
    if (_baseUrl.isEmpty) {
      throw ArgumentError('La URL base no puede estar vacía');
    }
  }

  /// URL base actual
  String get baseUrl => _baseUrl;

  /// Endpoints de autenticación y usuarios
  AuthEndpoints get auth => AuthEndpoints(_baseUrl);

  /// Endpoints para documentos de mesa
  DocumentoMesaEndpoints get documentosMesa => DocumentoMesaEndpoints(_baseUrl);

  /// Endpoints para facturas
  FacturaEndpoints get facturas => FacturaEndpoints(_baseUrl);

  /// Endpoints para proveedores
  ProveedorEndpoints get proveedores => ProveedorEndpoints(_baseUrl);

  /// Endpoints para pedidos
  PedidosEndpoints get pedidos => PedidosEndpoints(_baseUrl);

  /// Endpoints para productos
  ProductosEndpoints get productos => ProductosEndpoints(_baseUrl);

  /// Endpoints para inventario
  InventarioEndpoints get inventario => InventarioEndpoints(_baseUrl);

  /// Endpoints para reportes
  ReportesEndpoints get reportes => ReportesEndpoints(_baseUrl);

  /// Información de debug
  Map<String, dynamic> get debugInfo => {
    'baseUrl': _baseUrl,
    'authLogin': auth.login,
    'userInfo': auth.userInfo,
    'pedidosBase': pedidos.base,
  };
}

/// Endpoints relacionados con autenticación y usuarios
class AuthEndpoints {
  final String baseUrl;

  AuthEndpoints(this.baseUrl);

  /// Endpoint para iniciar sesión sin autenticación previa
  String get login => '$baseUrl/api/public/security/login-no-auth';

  /// Endpoint para obtener información del usuario actual
  String get userInfo => '$baseUrl/api/user-info/current';

  /// Endpoint para registrar un nuevo usuario
  String get register => '$baseUrl/api/users';

  /// Endpoint para validar un código de autenticación
  String validateCode(String code) =>
      '$baseUrl/api/public/security/login/validate/$code';

  /// Endpoint para logout
  String get logout => '$baseUrl/api/public/security/logout';

  /// Endpoint para refresh token
  String get refreshToken => '$baseUrl/api/public/security/refresh';
}

/// Endpoints relacionados con documentos de mesa
class DocumentoMesaEndpoints {
  final String baseUrl;

  DocumentoMesaEndpoints(this.baseUrl);

  /// Endpoint base para documentos de mesa
  String get base => '$baseUrl/api/documentos-mesa';

  /// Crear un nuevo documento
  String get crear => base;

  /// Listar todos los documentos
  String get lista => base;

  /// Obtener documentos por mesa
  String mesa(String mesaNombre) => '$base/mesa/$mesaNombre';

  /// Obtener documento por ID
  String documento(String id) => '$base/$id';

  /// Agregar pedido a documento
  String agregarPedido(String documentoId) =>
      '$base/$documentoId/agregar-pedido';

  /// Pagar un documento
  String pagar(String documentoId) => '$base/$documentoId/pagar';

  /// Eliminar un documento
  String eliminar(String documentoId) => '$base/$documentoId';

  /// Anular un documento
  String anular(String documentoId) => '$base/$documentoId/anular';

  /// Obtener documentos pendientes de una mesa
  String pendientes(String mesaNombre) => '$base/mesa/$mesaNombre/pendientes';

  /// Obtener documentos pagados de una mesa
  String pagados(String mesaNombre) => '$base/mesa/$mesaNombre/pagados';

  /// Obtener resumen de una mesa
  String resumen(String mesaNombre) => '$base/mesa/$mesaNombre/resumen';
}

/// Endpoints para Facturas
class FacturaEndpoints {
  final String baseUrl;

  FacturaEndpoints(this.baseUrl);

  /// Base URL para las facturas
  String get base => '$baseUrl/api/facturas';

  /// Lista de todas las facturas
  String get lista => base;

  /// Obtener una factura por ID
  String factura(String id) => '$base/$id';

  /// Obtener factura por número
  String porNumero(String numero) => '$base/numero/$numero';

  /// Obtener facturas por NIT
  String porNit(String nit) => '$base/nit/$nit';

  /// Obtener facturas pendientes de pago
  String get pendientesPago => '$base/pendientes-pago';

  /// Obtener facturas del día
  String get ventasDia => '$base/ventas-dia';

  /// Crear factura desde un pedido
  String desdePedido(String pedidoId) => '$base/desde-pedido/$pedidoId';

  /// Emitir una factura
  String emitir(String id) => '$base/$id/emitir';

  /// Pagar una factura
  String pagar(String id) => '$base/$id/pagar';

  /// Anular una factura
  String anular(String id) => '$base/$id/anular';
}

/// Endpoints relacionados con proveedores
class ProveedorEndpoints {
  final String baseUrl;

  ProveedorEndpoints(this.baseUrl);

  String get base => '$baseUrl/api/proveedores';

  /// Obtener proveedores activos
  String get activos => '$base/activos';

  /// Buscar proveedores por texto
  String buscar(String texto) =>
      '$base/buscar?texto=${Uri.encodeComponent(texto)}';

  /// Crear nuevo proveedor
  String get crear => base;

  /// Actualizar proveedor
  String actualizar(String id) => '$base/$id';

  /// Cambiar estado de proveedor
  String cambiarEstado(String id) => '$base/$id/estado';
}

/// Endpoints para Pedidos  
class PedidosEndpoints {
  final String baseUrl;

  PedidosEndpoints(this.baseUrl);

  /// Base para pedidos
  String get base => '$baseUrl/api/pedidos';

  /// Lista de todos los pedidos
  String get lista => base;

  /// Crear nuevo pedido
  String get crear => base;

  /// Obtener pedido por ID
  String pedido(String id) => '$base/$id';

  /// Actualizar pedido
  String actualizar(String id) => '$base/$id';

  /// Eliminar pedido
  String eliminar(String id) => '$base/$id';

  /// Pedidos por mesa
  String mesa(String mesaNombre) => '$base/mesa/$mesaNombre';

  /// Pedidos por tipo
  String tipo(String tipo) => '$base/tipo/$tipo';

  /// Pedidos por estado
  String estado(String estado) => '$base/estado/$estado';

  /// Pagar pedido
  String pagar(String id) => '$base/$id/pagar';

  /// Total de ventas
  String get totalVentas => '$base/total-ventas';

  /// Estadísticas
  String get estadisticas => '$base/estadisticas';
}

/// Endpoints para Productos
class ProductosEndpoints {
  final String baseUrl;

  ProductosEndpoints(this.baseUrl);

  String get base => '$baseUrl/api/productos';

  /// Lista de productos
  String get lista => base;

  /// Crear producto
  String get crear => base;

  /// Obtener producto por ID
  String producto(String id) => '$base/$id';

  /// Actualizar producto
  String actualizar(String id) => '$base/$id';

  /// Eliminar producto
  String eliminar(String id) => '$base/$id';

  /// Productos por categoría
  String categoria(String categoria) => '$base/categoria/$categoria';

  /// Productos activos
  String get activos => '$base/activos';

  /// Buscar productos
  String buscar(String texto) => '$base/buscar?q=${Uri.encodeComponent(texto)}';
}

/// Endpoints para Inventario
class InventarioEndpoints {
  final String baseUrl;

  InventarioEndpoints(this.baseUrl);

  String get base => '$baseUrl/api/inventario';

  /// Lista de inventario
  String get lista => base;

  /// Movimientos de inventario
  String get movimientos => '$base/movimientos';

  /// Ingredientes
  String get ingredientes => '$baseUrl/api/ingredientes';

  /// Actualizar stock
  String actualizarStock(String ingredienteId) => '$base/$ingredienteId/stock';
}

/// Endpoints para Reportes
class ReportesEndpoints {
  final String baseUrl;

  ReportesEndpoints(this.baseUrl);

  String get base => '$baseUrl/api/reportes';

  /// Reporte de ventas
  String get ventas => '$base/ventas';

  /// Reporte de productos más vendidos
  String get productosVendidos => '$base/productos-vendidos';

  /// Reporte de inventario
  String get inventario => '$base/inventario';

  /// Reporte financiero
  String get financiero => '$base/financiero';
}
