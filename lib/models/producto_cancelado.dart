/// Modelo para representar productos cancelados en pedidos
///
/// Este modelo rastrea productos que fueron eliminados/cancelados
/// de pedidos con información del usuario y motivo.
library;

import 'item_pedido.dart';

/// Motivo de cancelación de un producto
enum MotivoCancelacion {
  clienteSolicito,     // Cliente pidió cancelar
  errorPedido,         // Error al tomar el pedido
  noDisponible,        // Producto no disponible
  cambioMesa,          // Producto movido a otra mesa
  errorSistema,        // Error del sistema
  otro,                // Otro motivo
}

/// Estado de la cancelación
enum EstadoCancelacion {
  pendiente,           // Cancelación registrada pero pendiente
  confirmada,          // Cancelación confirmada
  revertida,           // Cancelación revertida (producto restaurado)
}

class ProductoCancelado {
  final String? id;
  final String pedidoId;              // ID del pedido original
  final String mesaNombre;            // Nombre de la mesa
  final ItemPedido itemOriginal;      // Producto que fue cancelado
  final DateTime fechaCancelacion;    // Cuándo se canceló
  final String canceladoPor;          // Usuario que canceló
  final MotivoCancelacion motivo;     // Motivo de la cancelación
  final String? descripcionMotivo;    // Descripción detallada del motivo
  final EstadoCancelacion estado;     // Estado actual de la cancelación
  final String? observaciones;       // Observaciones adicionales
  
  // Información adicional del contexto
  final double? montoReembolsado;     // Monto reembolsado si aplica
  final String? metodoPago;           // Método de pago para reembolso
  final String? autorizadoPor;        // Usuario que autorizó la cancelación
  final DateTime? fechaReembolso;     // Cuándo se procesó el reembolso

  const ProductoCancelado({
    this.id,
    required this.pedidoId,
    required this.mesaNombre,
    required this.itemOriginal,
    required this.fechaCancelacion,
    required this.canceladoPor,
    required this.motivo,
    this.descripcionMotivo,
    this.estado = EstadoCancelacion.pendiente,
    this.observaciones,
    this.montoReembolsado,
    this.metodoPago,
    this.autorizadoPor,
    this.fechaReembolso,
  });

  /// Getter para obtener el monto del producto cancelado
  double get montoProducto => itemOriginal.precioUnitario * itemOriginal.cantidad;

  /// Getter para verificar si se procesó reembolso
  bool get tieneReembolso => montoReembolsado != null && montoReembolsado! > 0;

  /// Factory constructor desde JSON
  factory ProductoCancelado.fromJson(Map<String, dynamic> json) {
    return ProductoCancelado(
      id: json['id']?.toString(),
      pedidoId: json['pedidoId']?.toString() ?? '',
      mesaNombre: json['mesaNombre']?.toString() ?? '',
      itemOriginal: ItemPedido.fromJson(json['itemOriginal'] ?? {}),
      fechaCancelacion: DateTime.tryParse(json['fechaCancelacion']?.toString() ?? '') 
          ?? DateTime.now(),
      canceladoPor: json['canceladoPor']?.toString() ?? '',
      motivo: _parseMotivo(json['motivo']),
      descripcionMotivo: json['descripcionMotivo']?.toString(),
      estado: _parseEstado(json['estado']),
      observaciones: json['observaciones']?.toString(),
      montoReembolsado: _parseToDouble(json['montoReembolsado']),
      metodoPago: json['metodoPago']?.toString(),
      autorizadoPor: json['autorizadoPor']?.toString(),
      fechaReembolso: json['fechaReembolso'] != null 
          ? DateTime.tryParse(json['fechaReembolso'].toString())
          : null,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'pedidoId': pedidoId,
      'mesaNombre': mesaNombre,
      'itemOriginal': itemOriginal.toJson(),
      'fechaCancelacion': fechaCancelacion.toIso8601String(),
      'canceladoPor': canceladoPor,
      'motivo': motivo.name,
      if (descripcionMotivo != null) 'descripcionMotivo': descripcionMotivo,
      'estado': estado.name,
      if (observaciones != null) 'observaciones': observaciones,
      if (montoReembolsado != null) 'montoReembolsado': montoReembolsado,
      if (metodoPago != null) 'metodoPago': metodoPago,
      if (autorizadoPor != null) 'autorizadoPor': autorizadoPor,
      if (fechaReembolso != null) 'fechaReembolso': fechaReembolso!.toIso8601String(),
    };
  }

  /// Crear copia con valores modificados
  ProductoCancelado copyWith({
    String? id,
    String? pedidoId,
    String? mesaNombre,
    ItemPedido? itemOriginal,
    DateTime? fechaCancelacion,
    String? canceladoPor,
    MotivoCancelacion? motivo,
    String? descripcionMotivo,
    EstadoCancelacion? estado,
    String? observaciones,
    double? montoReembolsado,
    String? metodoPago,
    String? autorizadoPor,
    DateTime? fechaReembolso,
  }) {
    return ProductoCancelado(
      id: id ?? this.id,
      pedidoId: pedidoId ?? this.pedidoId,
      mesaNombre: mesaNombre ?? this.mesaNombre,
      itemOriginal: itemOriginal ?? this.itemOriginal,
      fechaCancelacion: fechaCancelacion ?? this.fechaCancelacion,
      canceladoPor: canceladoPor ?? this.canceladoPor,
      motivo: motivo ?? this.motivo,
      descripcionMotivo: descripcionMotivo ?? this.descripcionMotivo,
      estado: estado ?? this.estado,
      observaciones: observaciones ?? this.observaciones,
      montoReembolsado: montoReembolsado ?? this.montoReembolsado,
      metodoPago: metodoPago ?? this.metodoPago,
      autorizadoPor: autorizadoPor ?? this.autorizadoPor,
      fechaReembolso: fechaReembolso ?? this.fechaReembolso,
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

  static MotivoCancelacion _parseMotivo(dynamic value) {
    if (value == null) return MotivoCancelacion.otro;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'clientesolicito': return MotivoCancelacion.clienteSolicito;
      case 'errorpedido': return MotivoCancelacion.errorPedido;
      case 'nodisponible': return MotivoCancelacion.noDisponible;
      case 'cambiomesa': return MotivoCancelacion.cambioMesa;
      case 'errorsistema': return MotivoCancelacion.errorSistema;
      case 'otro': return MotivoCancelacion.otro;
      default: return MotivoCancelacion.otro;
    }
  }

  static EstadoCancelacion _parseEstado(dynamic value) {
    if (value == null) return EstadoCancelacion.pendiente;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'pendiente': return EstadoCancelacion.pendiente;
      case 'confirmada': return EstadoCancelacion.confirmada;
      case 'revertida': return EstadoCancelacion.revertida;
      default: return EstadoCancelacion.pendiente;
    }
  }

  @override
  String toString() {
    return 'ProductoCancelado(mesa: $mesaNombre, producto: ${itemOriginal.productoNombre}, canceladoPor: $canceladoPor)';
  }
}

/// Extensiones para obtener texto descriptivo
extension MotivoCancelacionExtension on MotivoCancelacion {
  String get descripcion {
    switch (this) {
      case MotivoCancelacion.clienteSolicito:
        return 'Cliente solicitó cancelar';
      case MotivoCancelacion.errorPedido:
        return 'Error al tomar el pedido';
      case MotivoCancelacion.noDisponible:
        return 'Producto no disponible';
      case MotivoCancelacion.cambioMesa:
        return 'Producto movido a otra mesa';
      case MotivoCancelacion.errorSistema:
        return 'Error del sistema';
      case MotivoCancelacion.otro:
        return 'Otro motivo';
    }
  }
}

extension EstadoCancelacionExtension on EstadoCancelacion {
  String get descripcion {
    switch (this) {
      case EstadoCancelacion.pendiente:
        return 'Pendiente';
      case EstadoCancelacion.confirmada:
        return 'Confirmada';
      case EstadoCancelacion.revertida:
        return 'Revertida';
    }
  }
}