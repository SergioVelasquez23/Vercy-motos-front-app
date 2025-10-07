/// Configuración de endpoints de la API
///
/// Organiza los endpoints de autenticación de manera estructurada.
class EndpointsConfig {
  // Singleton
  static final EndpointsConfig _instance = EndpointsConfig._internal();
  factory EndpointsConfig() => _instance;
  EndpointsConfig._internal();

  // URL base por defecto (simplificada)
  String get baseUrl => _customBaseUrl ?? 'https://sopa-y-carbon.onrender.com';

  // Variable para almacenar una URL base personalizada
  String? _customBaseUrl;

  /// Establece una URL base personalizada
  void setCustomBaseUrl(String url) {
    _customBaseUrl = url;
    if (url.isNotEmpty) {
      print('📡 URL base personalizada establecida: $url');
    }
  }

  /// Elimina la URL base personalizada y vuelve a la URL por defecto
  void resetToDefaultBaseUrl() {
    _customBaseUrl = null;
    print('📡 URL base restaurada al valor predeterminado: $baseUrl');
  }

  /// Verifica si se está usando una URL base personalizada
  bool get isUsingCustomUrl => _customBaseUrl != null;

  /// Devuelve la URL base actual (personalizada o predeterminada)
  String get currentBaseUrl => _customBaseUrl ?? baseUrl;

  /// Endpoints de autenticación y usuarios (único endpoints usado)
  AuthEndpoints get auth => AuthEndpoints(currentBaseUrl);

  /// Endpoints para documentos de mesa
  DocumentoMesaEndpoints get documentosMesa =>
      DocumentoMesaEndpoints(currentBaseUrl);

  /// Endpoints para facturas
  FacturaEndpoints get facturas => FacturaEndpoints(currentBaseUrl);

  /// Endpoints para proveedores
  ProveedorEndpoints get proveedores => ProveedorEndpoints(currentBaseUrl);

  /// Endpoints para manejo de imágenes
  ImageEndpoints get images => ImageEndpoints(currentBaseUrl);

  /// Endpoints para información del negocio
  NegocioEndpoints get negocio => NegocioEndpoints(currentBaseUrl);
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
}

/// Endpoints relacionados con documentos de mesa
class DocumentoMesaEndpoints {
  final String baseUrl;

  DocumentoMesaEndpoints(this.baseUrl);

  /// Endpoint base para documentos de mesa
  String get base => '$baseUrl/api/documentos-mesa';

  /// Crear un nuevo documento
  String get crear => base;

  /// Listar todos los documentos (endpoint simplificado)
  String get listaCompleta => base;

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

  /// Listar todos los documentos (con filtros opcionales)
  String lista({String? tipo, String? mesa}) {
    final params = <String, String>{};
    if (tipo != null) params['tipo'] = tipo;
    if (mesa != null) params['mesa'] = mesa;

    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';

    return '$base$query';
  }

  /// Verificar si una mesa es especial
  String verificarMesaEspecial(String mesaNombre) =>
      '$base/verificar-mesa-especial/$mesaNombre';

  /// Obtener documentos con pedidos completos
  String documentosCompletos(String mesaNombre) =>
      '$base/mesa/$mesaNombre/completos';
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

  /// Obtener facturas por teléfono del cliente
  String porTelefono(String telefono) => '$base/telefono/$telefono';

  /// Obtener facturas por medio de pago
  String porMedioPago(String medioPago) => '$base/medio-pago/$medioPago';

  /// Obtener facturas por quien atendió
  String porAtendidoPor(String atendidoPor) =>
      '$base/atendido-por/$atendidoPor';

  /// Obtener facturas pendientes de pago
  String get pendientesPago => '$base/pendientes-pago';

  /// Obtener facturas del día
  String get ventasDia => '$base/ventas-dia';

  /// Obtener facturas por período
  String get ventasPeriodo => '$base/ventas-periodo';

  /// Crear factura desde un pedido
  String desdePedido(String pedidoId) => '$base/desde-pedido/$pedidoId';

  /// Emitir una factura
  String emitir(String id) => '$base/$id/emitir';

  /// Pagar una factura
  String pagar(String id) => '$base/$id/pagar';

  /// Anular una factura
  String anular(String id) => '$base/$id/anular';

  /// Generar resumen para impresión de un pedido
  String resumenImpresion(String pedidoId) =>
      '$base/resumen-impresion/$pedidoId';

  /// Generar factura para impresión
  String facturaImpresion(String facturaId) =>
      '$base/factura-impresion/$facturaId';

  /// Obtener resumen de ventas
  String get resumenVentas => '$base/resumen-ventas';
}

/// Endpoints relacionados con proveedores
class ProveedorEndpoints {
  final String baseUrl;

  ProveedorEndpoints(this.baseUrl);

  String get base => '$baseUrl/api/proveedores';

  /// Obtener proveedores activos (para selects/listas)
  String get activos => '$base/activos';

  /// Buscar proveedores por texto
  String buscar(String texto) =>
      '$base/buscar?texto=${Uri.encodeComponent(texto)}';

  /// Crear nuevo proveedor
  String get crear => base;

  /// Actualizar proveedor
  String actualizar(String id) => '$base/$id';

  /// Cambiar estado de proveedor (activar/desactivar)
  String cambiarEstado(String id) => '$base/$id/estado';

  /// Obtener proveedores para facturas de compras
  String get paraFacturas => '$baseUrl/api/facturas-compras/proveedores';
}

/// Endpoints relacionados con manejo de imágenes
class ImageEndpoints {
  final String baseUrl;

  ImageEndpoints(this.baseUrl);

  String get base => '$baseUrl/api/images';

  /// Subir imagen (multipart)
  String get upload => '$base/upload';

  /// Subir imagen base64 (para web)
  String get uploadBase64 => '$base/upload-base64';

  /// Listar todas las imágenes disponibles
  String get list => '$base/list';

  /// Verificar si una imagen existe
  String check(String filename) => '$base/check/$filename';

  /// Servir imagen de platos
  String plato(String filename) => '$base/platos/$filename';

  /// URL directa para acceder a imagen (para mostrar en UI)
  String directUrl(String filename) => '$baseUrl/images/platos/$filename';

  /// Eliminar imagen
  String delete(String filename) => '$base/platos/$filename';
}

/// Endpoints relacionados con información del negocio
class NegocioEndpoints {
  final String baseUrl;

  NegocioEndpoints(this.baseUrl);

  String get base => '$baseUrl/api/negocio';

  /// Subir logo del negocio
  String get uploadLogo => '$base/logo';

  /// Obtener información del negocio
  String get info => base;

  /// Actualizar información del negocio
  String update(String id) => '$base/$id';

  /// Eliminar negocio
  String delete(String id) => '$base/$id';
}
