/// Modelo Deuda para gestionar pedidos pendientes entre cuadres
///
/// Este modelo representa una deuda que debe persistir entre
/// diferentes cuadres de caja hasta ser pagada completamente.
library;

import 'item_pedido.dart';

/// Estado de una deuda
enum EstadoDeuda {
  pendiente, // Deuda activa sin pagar
  parcial, // Deuda parcialmente pagada
  pagada, // Deuda completamente pagada
  cancelada, // Deuda cancelada (no se cobrará)
}

/// Tipo de deuda según origen
enum TipoDeuda {
  pedido, // Deuda originada por un pedido normal
  servicio, // Deuda por servicios adicionales
  otro, // Otros tipos de deuda
}

class Deuda {
  final String? id;
  final String descripcion; // Descripción de la deuda
  final double montoOriginal; // Monto total inicial
  final double montoPendiente; // Monto que aún falta por pagar
  final DateTime fechaCreacion; // Cuándo se creó la deuda
  final DateTime? fechaVencimiento; // Fecha límite de pago (opcional)
  final String creadoPor; // Usuario que creó la deuda
  final String cliente; // Nombre del cliente/deudor
  final String? telefono; // Teléfono del cliente (opcional)
  final EstadoDeuda estado;
  final TipoDeuda tipo;

  // Información del pedido asociado (si aplica)
  final String? pedidoId;
  final String? mesaNombre;
  final List<ItemPedido> items; // Items que generaron la deuda

  // Historial de pagos
  final List<PagoDeuda> pagos;

  // Notas adicionales
  final String? notas;

  const Deuda({
    this.id,
    required this.descripcion,
    required this.montoOriginal,
    required this.montoPendiente,
    required this.fechaCreacion,
    this.fechaVencimiento,
    required this.creadoPor,
    required this.cliente,
    this.telefono,
    this.estado = EstadoDeuda.pendiente,
    this.tipo = TipoDeuda.pedido,
    this.pedidoId,
    this.mesaNombre,
    this.items = const [],
    this.pagos = const [],
    this.notas,
  });

  /// Getter para saber si la deuda está vencida
  bool get estaVencida {
    if (fechaVencimiento == null) return false;
    return DateTime.now().isAfter(fechaVencimiento!) &&
        estado != EstadoDeuda.pagada;
  }

  /// Getter para calcular cuánto se ha pagado
  double get montoPagado => montoOriginal - montoPendiente;

  /// Getter para calcular porcentaje pagado
  double get porcentajePagado =>
      montoOriginal > 0 ? (montoPagado / montoOriginal) * 100 : 0;

  /// Factory constructor desde JSON
  factory Deuda.fromJson(Map<String, dynamic> json) {
    return Deuda(
      id: json['id']?.toString(),
      descripcion: json['descripcion']?.toString() ?? '',
      montoOriginal: _parseToDouble(json['montoOriginal']),
      montoPendiente: _parseToDouble(json['montoPendiente']),
      fechaCreacion:
          DateTime.tryParse(json['fechaCreacion']?.toString() ?? '') ??
          DateTime.now(),
      fechaVencimiento: json['fechaVencimiento'] != null
          ? DateTime.tryParse(json['fechaVencimiento'].toString())
          : null,
      creadoPor: json['creadoPor']?.toString() ?? '',
      cliente: json['cliente']?.toString() ?? '',
      telefono: json['telefono']?.toString(),
      estado: _parseEstado(json['estado']),
      tipo: _parseTipo(json['tipo']),
      pedidoId: json['pedidoId']?.toString(),
      mesaNombre: json['mesaNombre']?.toString(),
      items: json['items'] != null
          ? (json['items'] as List)
                .map((item) => ItemPedido.fromJson(item))
                .toList()
          : [],
      pagos: json['pagos'] != null
          ? (json['pagos'] as List)
                .map((pago) => PagoDeuda.fromJson(pago))
                .toList()
          : [],
      notas: json['notas']?.toString(),
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'descripcion': descripcion,
      'montoOriginal': montoOriginal,
      'montoPendiente': montoPendiente,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      if (fechaVencimiento != null)
        'fechaVencimiento': fechaVencimiento!.toIso8601String(),
      'creadoPor': creadoPor,
      'cliente': cliente,
      if (telefono != null) 'telefono': telefono,
      'estado': estado.name,
      'tipo': tipo.name,
      if (pedidoId != null) 'pedidoId': pedidoId,
      if (mesaNombre != null) 'mesaNombre': mesaNombre,
      'items': items.map((item) => item.toJson()).toList(),
      'pagos': pagos.map((pago) => pago.toJson()).toList(),
      if (notas != null) 'notas': notas,
    };
  }

  /// Crear copia con valores modificados
  Deuda copyWith({
    String? id,
    String? descripcion,
    double? montoOriginal,
    double? montoPendiente,
    DateTime? fechaCreacion,
    DateTime? fechaVencimiento,
    String? creadoPor,
    String? cliente,
    String? telefono,
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
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      creadoPor: creadoPor ?? this.creadoPor,
      cliente: cliente ?? this.cliente,
      telefono: telefono ?? this.telefono,
      estado: estado ?? this.estado,
      tipo: tipo ?? this.tipo,
      pedidoId: pedidoId ?? this.pedidoId,
      mesaNombre: mesaNombre ?? this.mesaNombre,
      items: items ?? this.items,
      pagos: pagos ?? this.pagos,
      notas: notas ?? this.notas,
    );
  }

  // Métodos utilitarios estáticos
  static double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }

  static EstadoDeuda _parseEstado(dynamic value) {
    if (value == null) return EstadoDeuda.pendiente;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'pendiente':
        return EstadoDeuda.pendiente;
      case 'parcial':
        return EstadoDeuda.parcial;
      case 'pagada':
        return EstadoDeuda.pagada;
      case 'cancelada':
        return EstadoDeuda.cancelada;
      default:
        return EstadoDeuda.pendiente;
    }
  }

  static TipoDeuda _parseTipo(dynamic value) {
    if (value == null) return TipoDeuda.pedido;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'pedido':
        return TipoDeuda.pedido;
      case 'servicio':
        return TipoDeuda.servicio;
      case 'otro':
        return TipoDeuda.otro;
      default:
        return TipoDeuda.pedido;
    }
  }

  @override
  String toString() {
    return 'Deuda(id: $id, cliente: $cliente, montoPendiente: $montoPendiente, estado: $estado)';
  }
}

/// Modelo para representar un pago realizado hacia una deuda
class PagoDeuda {
  final String? id;
  final String deudaId;
  final double monto;
  final DateTime fecha;
  final String procesadoPor;
  final String formaPago; // efectivo, tarjeta, transferencia, etc.
  final String? referencia; // número de referencia del pago
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
      procesadoPor: json['procesadoPor']?.toString() ?? '',
      formaPago: json['formaPago']?.toString() ?? 'efectivo',
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
  String toString() {
    return 'PagoDeuda(monto: $monto, fecha: $fecha, formaPago: $formaPago)';
  }
}
