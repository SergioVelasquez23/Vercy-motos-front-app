import 'item_pedido.dart';

enum EstadoDeuda {
  pendiente,
  parcial,
  pagada,
  cancelada,
}

enum TipoDeuda {
  pedido,
  servicio,
  otro,
}

class Deuda {
  final String? id;
  final String descripcion;
  final double montoOriginal; // alias: montoTotal en nueva API
  final double montoPendiente; // alias: montoDeuda en nueva API
  final double? montoPagadoReal; // montoPagado directo del backend (nueva API)
  final DateTime fechaCreacion;
  final DateTime? fechaVencimiento;
  final DateTime? fechaUltimoPago;
  final String creadoPor;
  final String cliente; // alias: clienteInfo en nueva API
  final String? telefono;
  final bool activa; // nueva API: true=activa, false=inactiva
  final EstadoDeuda estado;
  final TipoDeuda tipo;
  final String? pedidoId;
  final String? mesaNombre;
  final List<ItemPedido> items;
  final List<PagoDeuda> pagos;
  final String? notas;

  const Deuda({
    this.id,
    required this.descripcion,
    required this.montoOriginal,
    required this.montoPendiente,
    this.montoPagadoReal,
    required this.fechaCreacion,
    this.fechaVencimiento,
    this.fechaUltimoPago,
    this.creadoPor = '',
    required this.cliente,
    this.telefono,
    this.activa = true,
    this.estado = EstadoDeuda.pendiente,
    this.tipo = TipoDeuda.pedido,
    this.pedidoId,
    this.mesaNombre,
    this.items = const [],
    this.pagos = const [],
    this.notas,
  });

  // ─── Aliases para nueva API ───────────────────────────────────────────────
  String get clienteInfo => cliente;
  double get montoTotal => montoOriginal;
  double get montoDeuda => montoPendiente;

  bool get estaVencida {
    if (fechaVencimiento == null) return false;
    return DateTime.now().isAfter(fechaVencimiento!) &&
        estado != EstadoDeuda.pagada &&
        activa;
  }

  double get montoPagado => montoPagadoReal ?? (montoOriginal - montoPendiente);

  double get porcentajePagado =>
      montoOriginal > 0 ? (montoPagado / montoOriginal) * 100 : 0;

  factory Deuda.fromJson(Map<String, dynamic> json) {
    // Leer montoTotal o montoOriginal
    final montoTotalVal = _parseToDouble(json['montoTotal'] ?? json['montoOriginal']);
    // Leer montoDeuda o montoPendiente
    final montoDeudaVal = _parseToDouble(json['montoDeuda'] ?? json['montoPendiente']);
    // Leer clienteInfo o cliente
    final clienteVal = (json['clienteInfo'] ?? json['cliente'])?.toString() ?? '';

    // Derivar estado de los campos de la nueva API
    EstadoDeuda estadoVal;
    final activaVal = json['activa'] as bool? ?? true;
    if (json['estado'] != null) {
      estadoVal = _parseEstado(json['estado']);
    } else {
      // Derivar de activa + montos
      if (!activaVal) {
        estadoVal = EstadoDeuda.cancelada;
      } else if (montoDeudaVal <= 0) {
        estadoVal = EstadoDeuda.pagada;
      } else {
        final montoPagadoVal = _parseToDouble(json['montoPagado']);
        estadoVal = montoPagadoVal > 0 ? EstadoDeuda.parcial : EstadoDeuda.pendiente;
      }
    }

    return Deuda(
      id: json['id']?.toString(),
      descripcion: json['descripcion']?.toString() ?? '',
      montoOriginal: montoTotalVal,
      montoPendiente: montoDeudaVal,
      montoPagadoReal: json['montoPagado'] != null ? _parseToDouble(json['montoPagado']) : null,
      fechaCreacion:
          DateTime.tryParse(json['fechaCreacion']?.toString() ?? '') ??
          DateTime.now(),
      fechaVencimiento: json['fechaVencimiento'] != null
          ? DateTime.tryParse(json['fechaVencimiento'].toString())
          : null,
      fechaUltimoPago: json['fechaUltimoPago'] != null
          ? DateTime.tryParse(json['fechaUltimoPago'].toString())
          : null,
      creadoPor: json['creadoPor']?.toString() ?? '',
      cliente: clienteVal,
      telefono: json['telefono']?.toString(),
      activa: activaVal,
      estado: estadoVal,
      tipo: _parseTipo(json['tipo']),
      pedidoId: json['pedidoId']?.toString(),
      mesaNombre: json['mesaNombre']?.toString(),
      items: json['items'] != null
          ? (json['items'] as List).map((i) => ItemPedido.fromJson(i)).toList()
          : [],
      pagos: json['pagos'] != null
          ? (json['pagos'] as List).map((p) => PagoDeuda.fromJson(p)).toList()
          : [],
      notas: json['notas']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'descripcion': descripcion,
      'montoOriginal': montoOriginal,
      'montoTotal': montoOriginal,
      'montoPendiente': montoPendiente,
      'montoDeuda': montoPendiente,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      if (fechaVencimiento != null)
        'fechaVencimiento': fechaVencimiento!.toIso8601String(),
      'creadoPor': creadoPor,
      'cliente': cliente,
      'clienteInfo': cliente,
      if (telefono != null) 'telefono': telefono,
      'activa': activa,
      'estado': estado.name,
      'tipo': tipo.name,
      if (pedidoId != null) 'pedidoId': pedidoId,
      if (mesaNombre != null) 'mesaNombre': mesaNombre,
      'items': items.map((i) => i.toJson()).toList(),
      'pagos': pagos.map((p) => p.toJson()).toList(),
      if (notas != null) 'notas': notas,
    };
  }

  Deuda copyWith({
    String? id,
    String? descripcion,
    double? montoOriginal,
    double? montoPendiente,
    double? montoPagadoReal,
    DateTime? fechaCreacion,
    DateTime? fechaVencimiento,
    DateTime? fechaUltimoPago,
    String? creadoPor,
    String? cliente,
    String? telefono,
    bool? activa,
    EstadoDeuda? estado,
    TipoDeuda? tipo,
    String? pedidoId,
    String? mesaNombre,
    List<ItemPedido>? items,
    List<PagoDeuda>? pagos,
    String? notas,
  }) {
    return Deuda(
      id: id ?? this.id,
      descripcion: descripcion ?? this.descripcion,
      montoOriginal: montoOriginal ?? this.montoOriginal,
      montoPendiente: montoPendiente ?? this.montoPendiente,
      montoPagadoReal: montoPagadoReal ?? this.montoPagadoReal,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      fechaUltimoPago: fechaUltimoPago ?? this.fechaUltimoPago,
      creadoPor: creadoPor ?? this.creadoPor,
      cliente: cliente ?? this.cliente,
      telefono: telefono ?? this.telefono,
      activa: activa ?? this.activa,
      estado: estado ?? this.estado,
      tipo: tipo ?? this.tipo,
      pedidoId: pedidoId ?? this.pedidoId,
      mesaNombre: mesaNombre ?? this.mesaNombre,
      items: items ?? this.items,
      pagos: pagos ?? this.pagos,
      notas: notas ?? this.notas,
    );
  }

  static double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static EstadoDeuda _parseEstado(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'parcial': return EstadoDeuda.parcial;
      case 'pagada': return EstadoDeuda.pagada;
      case 'cancelada': return EstadoDeuda.cancelada;
      default: return EstadoDeuda.pendiente;
    }
  }

  static TipoDeuda _parseTipo(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'servicio': return TipoDeuda.servicio;
      case 'otro': return TipoDeuda.otro;
      default: return TipoDeuda.pedido;
    }
  }

  @override
  String toString() =>
      'Deuda(id: $id, cliente: $cliente, montoPendiente: $montoPendiente, estado: $estado)';
}

class PagoDeuda {
  final String? id;
  final String deudaId;
  final double monto;
  final DateTime fecha;
  final String procesadoPor;
  final String formaPago;
  final String? referencia;
  final String? notas;

  const PagoDeuda({
    this.id,
    required this.deudaId,
    required this.monto,
    required this.fecha,
    required this.procesadoPor,
    required this.formaPago,
    this.referencia,
    this.notas,
  });

  factory PagoDeuda.fromJson(Map<String, dynamic> json) {
    return PagoDeuda(
      id: json['id']?.toString(),
      deudaId: json['deudaId']?.toString() ?? '',
      monto: Deuda._parseToDouble(json['monto']),
      fecha:
          DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
      procesadoPor: (json['procesadoPor'] ?? json['recibidoPor'])?.toString() ?? '',
      formaPago: (json['formaPago'] ?? json['medioPago'])?.toString() ?? 'efectivo',
      referencia: json['referencia']?.toString(),
      notas: json['notas']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'deudaId': deudaId,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'procesadoPor': procesadoPor,
      'formaPago': formaPago,
      if (referencia != null) 'referencia': referencia,
      if (notas != null) 'notas': notas,
    };
  }

  @override
  String toString() =>
      'PagoDeuda(monto: $monto, fecha: $fecha, formaPago: $formaPago)';
}
