import 'package:flutter/material.dart';
import 'pedido.dart';

/// Modelo para representar un documento individual en las mesas especiales
/// Permite múltiples pedidos independientes por mesa
class DocumentoMesa {
  final String id;
  final String numeroDocumento;
  final DateTime fecha;
  final double total;
  final String vendedor;
  final String mesaNombre;
  final List<Pedido> pedidos;
  final bool pagado;
  final DateTime? fechaPago;
  final String? formaPago;
  final String? pagadoPor;
  final Color? colorIdentificacion;

  DocumentoMesa({
    required this.id,
    required this.numeroDocumento,
    required this.fecha,
    required this.total,
    required this.vendedor,
    required this.mesaNombre,
    required this.pedidos,
    this.pagado = false,
    this.fechaPago,
    this.formaPago,
    this.pagadoPor,
    this.colorIdentificacion,
  });

  /// Crea una copia del documento con campos actualizados
  DocumentoMesa copyWith({
    String? id,
    String? numeroDocumento,
    DateTime? fecha,
    double? total,
    String? vendedor,
    String? mesaNombre,
    List<Pedido>? pedidos,
    bool? pagado,
    DateTime? fechaPago,
    String? formaPago,
    String? pagadoPor,
    Color? colorIdentificacion,
  }) {
    return DocumentoMesa(
      id: id ?? this.id,
      numeroDocumento: numeroDocumento ?? this.numeroDocumento,
      fecha: fecha ?? this.fecha,
      total: total ?? this.total,
      vendedor: vendedor ?? this.vendedor,
      mesaNombre: mesaNombre ?? this.mesaNombre,
      pedidos: pedidos ?? this.pedidos,
      pagado: pagado ?? this.pagado,
      fechaPago: fechaPago ?? this.fechaPago,
      formaPago: formaPago ?? this.formaPago,
      pagadoPor: pagadoPor ?? this.pagadoPor,
      colorIdentificacion: colorIdentificacion ?? this.colorIdentificacion,
    );
  }

  /// Convierte el documento a JSON para envío al backend
  Map<String, dynamic> toJson() {
    return {
      '_id': id.isEmpty ? null : id,
      'numeroDocumento': numeroDocumento,
      'fecha': fecha.toIso8601String(),
      'total': total,
      'vendedor': vendedor,
      'mesaNombre': mesaNombre,
      'pedidos': pedidos.map((p) => p.toJson()).toList(),
      'pagado': pagado,
      'fechaPago': fechaPago?.toIso8601String(),
      'formaPago': formaPago,
      'pagadoPor': pagadoPor,
    };
  }

  /// Crea un documento desde JSON recibido del backend
  factory DocumentoMesa.fromJson(Map<String, dynamic> json) {
    return DocumentoMesa(
      id: json['_id'] ?? '',
      numeroDocumento: json['numeroDocumento'] ?? '',
      fecha: DateTime.parse(json['fecha']),
      total: (json['total'] as num).toDouble(),
      vendedor: json['vendedor'] ?? '',
      mesaNombre: json['mesaNombre'] ?? '',
      pedidos:
          (json['pedidos'] as List?)?.map((p) => Pedido.fromJson(p)).toList() ??
          [],
      pagado: json['pagado'] ?? false,
      fechaPago: json['fechaPago'] != null
          ? DateTime.parse(json['fechaPago'])
          : null,
      formaPago: json['formaPago'],
      pagadoPor: json['pagadoPor'],
    );
  }

  /// Formatea la fecha para mostrar en la UI
  String get fechaFormateada {
    return '${fecha.day.toString().padLeft(2, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.year} '
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }

  /// Obtiene el estado del documento para mostrar en la UI
  String get estadoTexto {
    return pagado ? 'Pagado' : 'Pendiente';
  }

  /// Obtiene el color del estado para la UI
  Color get estadoColor {
    return pagado ? Colors.green : Colors.orange;
  }
}
