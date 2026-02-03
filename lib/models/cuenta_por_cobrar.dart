class CuentaPorCobrar {
  final String? id;
  final String facturaId;
  final String clienteId;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? clienteEmail;
  final double montoTotal;
  final double montoAbonado;
  final double saldoPendiente;
  final DateTime fechaVencimiento;
  final int diasVencimiento;
  final EstadoCuenta estado;
  final DateTime? fechaCreacion;
  final DateTime? fechaUltimoAbono;

  CuentaPorCobrar({
    this.id,
    required this.facturaId,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteTelefono,
    this.clienteEmail,
    required this.montoTotal,
    this.montoAbonado = 0.0,
    required this.saldoPendiente,
    required this.fechaVencimiento,
    required this.diasVencimiento,
    required this.estado,
    this.fechaCreacion,
    this.fechaUltimoAbono,
  });

  factory CuentaPorCobrar.fromJson(Map<String, dynamic> json) {
    return CuentaPorCobrar(
      id: json['_id'],
      facturaId: json['facturaId'] ?? '',
      clienteId: json['clienteId'] ?? '',
      clienteNombre: json['clienteNombre'] ?? '',
      clienteTelefono: json['clienteTelefono'],
      clienteEmail: json['clienteEmail'],
      montoTotal: (json['montoTotal'] ?? 0).toDouble(),
      montoAbonado: (json['montoAbonado'] ?? 0).toDouble(),
      saldoPendiente: (json['saldoPendiente'] ?? 0).toDouble(),
      fechaVencimiento: DateTime.parse(
        json['fechaVencimiento'] ?? DateTime.now().toIso8601String(),
      ),
      diasVencimiento: json['diasVencimiento'] ?? 0,
      estado: EstadoCuenta.values.firstWhere(
        (e) => e.toString().split('.').last == (json['estado'] ?? 'PENDIENTE'),
        orElse: () => EstadoCuenta.PENDIENTE,
      ),
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : null,
      fechaUltimoAbono: json['fechaUltimoAbono'] != null
          ? DateTime.parse(json['fechaUltimoAbono'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'facturaId': facturaId,
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      if (clienteTelefono != null) 'clienteTelefono': clienteTelefono,
      if (clienteEmail != null) 'clienteEmail': clienteEmail,
      'montoTotal': montoTotal,
      'montoAbonado': montoAbonado,
      'saldoPendiente': saldoPendiente,
      'fechaVencimiento': fechaVencimiento.toIso8601String(),
      'diasVencimiento': diasVencimiento,
      'estado': estado.toString().split('.').last,
      if (fechaCreacion != null)
        'fechaCreacion': fechaCreacion!.toIso8601String(),
      if (fechaUltimoAbono != null)
        'fechaUltimoAbono': fechaUltimoAbono!.toIso8601String(),
    };
  }

  CuentaPorCobrar copyWith({
    String? id,
    String? facturaId,
    String? clienteId,
    String? clienteNombre,
    String? clienteTelefono,
    String? clienteEmail,
    double? montoTotal,
    double? montoAbonado,
    double? saldoPendiente,
    DateTime? fechaVencimiento,
    int? diasVencimiento,
    EstadoCuenta? estado,
    DateTime? fechaCreacion,
    DateTime? fechaUltimoAbono,
  }) {
    return CuentaPorCobrar(
      id: id ?? this.id,
      facturaId: facturaId ?? this.facturaId,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      clienteEmail: clienteEmail ?? this.clienteEmail,
      montoTotal: montoTotal ?? this.montoTotal,
      montoAbonado: montoAbonado ?? this.montoAbonado,
      saldoPendiente: saldoPendiente ?? this.saldoPendiente,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      diasVencimiento: diasVencimiento ?? this.diasVencimiento,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaUltimoAbono: fechaUltimoAbono ?? this.fechaUltimoAbono,
    );
  }

  bool get estaVencida => DateTime.now().isAfter(fechaVencimiento);
  bool get proximaAVencer => diasVencimiento <= 7 && diasVencimiento > 0;
  double get porcentajePagado =>
      montoTotal > 0 ? (montoAbonado / montoTotal) * 100 : 0;
}

enum EstadoCuenta { PENDIENTE, VENCIDA, PAGADA, ABONADA }

extension EstadoCuentaExtension on EstadoCuenta {
  String get displayName {
    switch (this) {
      case EstadoCuenta.PENDIENTE:
        return 'Pendiente';
      case EstadoCuenta.VENCIDA:
        return 'Vencida';
      case EstadoCuenta.PAGADA:
        return 'Pagada';
      case EstadoCuenta.ABONADA:
        return 'Abonada';
    }
  }

  String get colorName {
    switch (this) {
      case EstadoCuenta.PENDIENTE:
        return 'orange';
      case EstadoCuenta.VENCIDA:
        return 'red';
      case EstadoCuenta.PAGADA:
        return 'green';
      case EstadoCuenta.ABONADA:
        return 'blue';
    }
  }
}
