enum TipoAlerta {
  cuentaPorCobrarVencida,
  cuentaPorPagarProximaVencer,
  descuentoProveedorRiesgo,
  gastoProgramadoProximoPagar,
  flujoEfectivoNegativo,
}

enum EstadoAlerta { pendiente, enviada, fallida, cancelada }

enum MetodoNotificacion { whatsapp, email, ambos }

enum CanalAlerta { whatsapp, email, ambos }

class AlertaNotificacion {
  final String? alertId;
  final TipoAlerta tipo;
  final CanalAlerta canal;
  final String whatsapp;
  final String email;
  final String mensaje;
  final DateTime fechaEnvio;
  final bool exitoso;
  final List<String> canalesEnviados;
  final List<String> errores;
  final Map<String, dynamic> datosAdicionales;

  AlertaNotificacion({
    this.alertId,
    required this.tipo,
    required this.canal,
    required this.whatsapp,
    required this.email,
    required this.mensaje,
    required this.fechaEnvio,
    this.exitoso = false,
    this.canalesEnviados = const [],
    this.errores = const [],
    this.datosAdicionales = const {},
  });

  factory AlertaNotificacion.fromJson(Map<String, dynamic> json) {
    return AlertaNotificacion(
      alertId: json['alertId'],
      tipo: TipoAlerta.values.firstWhere(
        (e) => e.toString().split('.').last == (json['tipo'] ?? 'STOCK'),
        orElse: () => TipoAlerta.flujoEfectivoNegativo,
      ),
      canal: CanalAlerta.values.firstWhere(
        (e) => e.toString().split('.').last == (json['canal'] ?? 'ambos'),
        orElse: () => CanalAlerta.ambos,
      ),
      whatsapp: json['whatsapp'] ?? '',
      email: json['email'] ?? '',
      mensaje: json['mensaje'] ?? json['message'] ?? '',
      fechaEnvio: json['fechaEnvio'] != null
          ? DateTime.parse(json['fechaEnvio'])
          : DateTime.now(),
      exitoso: json['success'] ?? json['exitoso'] ?? false,
      canalesEnviados: json['channelsSent'] != null
          ? List<String>.from(json['channelsSent'])
          : (json['canalesEnviados'] != null
                ? List<String>.from(json['canalesEnviados'])
                : []),
      errores: json['errors'] != null ? List<String>.from(json['errors']) : [],
      datosAdicionales: json['datosAdicionales'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (alertId != null) 'alertId': alertId,
      'tipo': tipo.toString().split('.').last,
      'canal': canal.toString().split('.').last,
      'whatsapp': whatsapp,
      'email': email,
      'mensaje': mensaje,
      'fechaEnvio': fechaEnvio.toIso8601String(),
      'exitoso': exitoso,
      'canalesEnviados': canalesEnviados,
      'errores': errores,
      'datosAdicionales': datosAdicionales,
    };
  }

  // Métodos específicos para crear alertas de diferentes tipos
  static Map<String, dynamic> crearAlertaStock({
    required String whatsapp,
    required String email,
    required CanalAlerta canal,
    required String productoId,
    required String nombreProducto,
    required int stockActual,
    required int stockMinimo,
    String? proveedor,
  }) {
    return {
      'whatsapp': whatsapp,
      'email': email,
      'channel': canal.toString().split('.').last,
      'productoId': productoId,
      'nombreProducto': nombreProducto,
      'stockActual': stockActual,
      'stockMinimo': stockMinimo,
      if (proveedor != null) 'proveedor': proveedor,
    };
  }

  static Map<String, dynamic> crearAlertaFactura({
    required String whatsapp,
    required String email,
    required CanalAlerta canal,
    required String facturaId,
    required String clienteId,
    required String nombreCliente,
    required double monto,
    required String fechaVencimiento,
    required int diasVencimiento,
  }) {
    return {
      'whatsapp': whatsapp,
      'email': email,
      'channel': canal.toString().split('.').last,
      'facturaId': facturaId,
      'clienteId': clienteId,
      'nombreCliente': nombreCliente,
      'monto': monto,
      'fechaVencimiento': fechaVencimiento,
      'diasVencimiento': diasVencimiento,
    };
  }

  static Map<String, dynamic> crearAlertaDeuda({
    required String whatsapp,
    required String email,
    required CanalAlerta canal,
    required String deudaId,
    required String clienteId,
    required String nombreCliente,
    required double montoDeuda,
    required String fechaVencimiento,
    required int diasVencidos,
  }) {
    return {
      'whatsapp': whatsapp,
      'email': email,
      'channel': canal.toString().split('.').last,
      'deudaId': deudaId,
      'clienteId': clienteId,
      'nombreCliente': nombreCliente,
      'montoDeuda': montoDeuda,
      'fechaVencimiento': fechaVencimiento,
      'diasVencidos': diasVencidos,
    };
  }
}

class EstadoMicroservicio {
  final bool healthy;
  final String status;
  final DateTime timestamp;
  final String? mensaje;
  final String? url;
  final bool disponible;
  final List<String> canalesDisponibles;
  final List<String> tiposAlerta;

  EstadoMicroservicio({
    required this.healthy,
    required this.status,
    required this.timestamp,
    this.mensaje,
    this.url,
    this.disponible = false,
    this.canalesDisponibles = const [],
    this.tiposAlerta = const [],
  });

  factory EstadoMicroservicio.fromJson(Map<String, dynamic> json) {
    return EstadoMicroservicio(
      healthy: json['microservice_healthy'] ?? json['healthy'] ?? false,
      status: json['status'] ?? 'UNKNOWN',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      mensaje: json['message'] ?? json['mensaje'],
      url: json['microservice_url'] ?? json['url'],
      disponible: json['microservice_available'] ?? json['disponible'] ?? false,
      canalesDisponibles: json['available_channels'] != null
          ? List<String>.from(json['available_channels'])
          : [],
      tiposAlerta: json['alert_types'] != null
          ? List<String>.from(json['alert_types'])
          : [],
    );
  }

  bool get estaOperativo => healthy && status.toUpperCase() == 'UP';
}
