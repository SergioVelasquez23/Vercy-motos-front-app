import 'cuenta_por_cobrar.dart';

class CuentaPorPagar {
  final String? id;
  final String proveedorId;
  final String proveedorNombre;
  final String numeroFactura;
  final double montoTotal;
  final double montoAbonado;
  final double saldoPendiente;
  final DateTime fechaVencimiento;
  final int diasVencimiento;
  final bool tieneDescuento;
  final double porcentajeDescuento;
  final double montoDescuento;
  final DateTime? fechaLimiteDescuento;
  final int? diasParaPerderDescuento;
  final bool descuentoPerdido;
  final EstadoCuentaPagar estado;
  final DateTime? fechaCreacion;

  CuentaPorPagar({
    this.id,
    required this.proveedorId,
    required this.proveedorNombre,
    required this.numeroFactura,
    required this.montoTotal,
    this.montoAbonado = 0.0,
    required this.saldoPendiente,
    required this.fechaVencimiento,
    required this.diasVencimiento,
    this.tieneDescuento = false,
    this.porcentajeDescuento = 0.0,
    this.montoDescuento = 0.0,
    this.fechaLimiteDescuento,
    this.diasParaPerderDescuento,
    this.descuentoPerdido = false,
    required this.estado,
    this.fechaCreacion,
  });

  factory CuentaPorPagar.fromJson(Map<String, dynamic> json) {
    return CuentaPorPagar(
      id: json['_id'],
      proveedorId: json['proveedorId'] ?? '',
      proveedorNombre: json['proveedorNombre'] ?? '',
      numeroFactura: json['numeroFactura'] ?? '',
      montoTotal: (json['montoTotal'] ?? 0).toDouble(),
      montoAbonado: (json['montoAbonado'] ?? 0).toDouble(),
      saldoPendiente: (json['saldoPendiente'] ?? 0).toDouble(),
      fechaVencimiento: DateTime.parse(
        json['fechaVencimiento'] ?? DateTime.now().toIso8601String(),
      ),
      diasVencimiento: json['diasVencimiento'] ?? 0,
      tieneDescuento: json['tieneDescuento'] ?? false,
      porcentajeDescuento: (json['porcentajeDescuento'] ?? 0).toDouble(),
      montoDescuento: (json['montoDescuento'] ?? 0).toDouble(),
      fechaLimiteDescuento: json['fechaLimiteDescuento'] != null
          ? DateTime.parse(json['fechaLimiteDescuento'])
          : null,
      diasParaPerderDescuento: json['diasParaPerderDescuento'],
      descuentoPerdido: json['descuentoPerdido'] ?? false,
      estado: EstadoCuentaPagar.values.firstWhere(
        (e) => e.toString().split('.').last == (json['estado'] ?? 'PENDIENTE'),
        orElse: () => EstadoCuentaPagar.PENDIENTE,
      ),
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'proveedorId': proveedorId,
      'proveedorNombre': proveedorNombre,
      'numeroFactura': numeroFactura,
      'montoTotal': montoTotal,
      'montoAbonado': montoAbonado,
      'saldoPendiente': saldoPendiente,
      'fechaVencimiento': fechaVencimiento.toIso8601String(),
      'diasVencimiento': diasVencimiento,
      'tieneDescuento': tieneDescuento,
      'porcentajeDescuento': porcentajeDescuento,
      'montoDescuento': montoDescuento,
      if (fechaLimiteDescuento != null)
        'fechaLimiteDescuento': fechaLimiteDescuento!.toIso8601String(),
      if (diasParaPerderDescuento != null)
        'diasParaPerderDescuento': diasParaPerderDescuento,
      'descuentoPerdido': descuentoPerdido,
      'estado': estado.toString().split('.').last,
      if (fechaCreacion != null)
        'fechaCreacion': fechaCreacion!.toIso8601String(),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'proveedorId': proveedorId,
      'numeroFactura': numeroFactura,
      'monto': montoTotal,
      'diasVencimiento': diasVencimiento,
      if (tieneDescuento) 'porcentajeDescuento': porcentajeDescuento,
      if (tieneDescuento && fechaLimiteDescuento != null)
        'diasDescuento': fechaLimiteDescuento!
            .difference(DateTime.now())
            .inDays,
    };
  }

  bool get proximoAPerderDescuento =>
      tieneDescuento &&
      !descuentoPerdido &&
      diasParaPerderDescuento != null &&
      diasParaPerderDescuento! <= 5;

  bool get estaVencida => DateTime.now().isAfter(fechaVencimiento);

  double get montoConDescuento => tieneDescuento && !descuentoPerdido
      ? montoTotal - montoDescuento
      : montoTotal;
}

enum EstadoCuentaPagar { PENDIENTE, VENCIDA, PAGADA, ABONADA }

extension EstadoCuentaPagarExtension on EstadoCuentaPagar {
  String get displayName {
    switch (this) {
      case EstadoCuentaPagar.PENDIENTE:
        return 'Pendiente';
      case EstadoCuentaPagar.VENCIDA:
        return 'Vencida';
      case EstadoCuentaPagar.PAGADA:
        return 'Pagada';
      case EstadoCuentaPagar.ABONADA:
        return 'Abonada';
    }
  }

  String get colorName {
    switch (this) {
      case EstadoCuentaPagar.PENDIENTE:
        return 'orange';
      case EstadoCuentaPagar.VENCIDA:
        return 'red';
      case EstadoCuentaPagar.PAGADA:
        return 'green';
      case EstadoCuentaPagar.ABONADA:
        return 'blue';
    }
  }
}
