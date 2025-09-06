import 'package:flutter/material.dart';
import 'pedido.dart';

/// Modelo para representar un documento individual en cualquier mesa
/// Permite múltiples pedidos independientes por mesa
class DocumentoMesa {
  final String? id;
  final String numeroDocumento;
  final DateTime fecha;
  final double total;
  final String vendedor;
  final String mesaNombre;
  final List<String> pedidosIds;
  final List<Pedido> pedidos;
  final bool pagado;
  final bool anulado;
  final String? motivoAnulacion;
  final DateTime? fechaCreacion;
  final DateTime? fechaPago;
  final String? formaPago;
  final String? pagadoPor;
  final double? propina;
  final Color? colorIdentificacion;
  final String estado; // Campo explícito para estado

  DocumentoMesa({
    this.id,
    required this.numeroDocumento,
    required this.fecha,
    required this.total,
    required this.vendedor,
    required this.mesaNombre,
    required this.pedidos,
    required this.pedidosIds,
    this.pagado = false,
    this.anulado = false,
    this.motivoAnulacion,
    this.fechaCreacion,
    this.fechaPago,
    this.formaPago,
    this.pagadoPor,
    this.propina,
    this.colorIdentificacion,
    this.estado = 'Pendiente', // Valor por defecto para estado
  });

  // Propiedades calculadas para la UI

  /// Devuelve el texto que describe el estado del documento
  String get estadoTexto {
    if (anulado) return 'Anulado';
    if (pagado) return 'Pagado';
    return 'Pendiente';
  }

  /// Devuelve el color que corresponde al estado del documento
  Color get estadoColor {
    if (anulado) return Colors.red;
    if (pagado) return Colors.green;
    return Colors.orange;
  }

  /// Devuelve la fecha formateada
  String get fechaFormateada {
    final DateTime dateToFormat = fechaCreacion ?? fecha;
    return '${dateToFormat.day}/${dateToFormat.month}/${dateToFormat.year} ${dateToFormat.hour.toString().padLeft(2, '0')}:${dateToFormat.minute.toString().padLeft(2, '0')}';
  }

  /// Crea una copia del documento con campos actualizados
  DocumentoMesa copyWith({
    String? id,
    String? numeroDocumento,
    DateTime? fecha,
    double? total,
    String? vendedor,
    String? mesaNombre,
    List<Pedido>? pedidos,
    List<String>? pedidosIds,
    bool? pagado,
    bool? anulado,
    String? motivoAnulacion,
    DateTime? fechaCreacion,
    DateTime? fechaPago,
    String? formaPago,
    String? pagadoPor,
    double? propina,
    Color? colorIdentificacion,
    String? estado,
  }) {
    return DocumentoMesa(
      id: id ?? this.id,
      numeroDocumento: numeroDocumento ?? this.numeroDocumento,
      fecha: fecha ?? this.fecha,
      total: total ?? this.total,
      vendedor: vendedor ?? this.vendedor,
      mesaNombre: mesaNombre ?? this.mesaNombre,
      pedidosIds: pedidosIds ?? this.pedidosIds,
      pedidos: pedidos ?? this.pedidos,
      pagado: pagado ?? this.pagado,
      anulado: anulado ?? this.anulado,
      motivoAnulacion: motivoAnulacion ?? this.motivoAnulacion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaPago: fechaPago ?? this.fechaPago,
      formaPago: formaPago ?? this.formaPago,
      pagadoPor: pagadoPor ?? this.pagadoPor,
      propina: propina ?? this.propina,
      colorIdentificacion: colorIdentificacion ?? this.colorIdentificacion,
      estado: estado ?? this.estado,
    );
  }

  /// Convierte el documento a JSON para envío al backend
  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'numeroDocumento': numeroDocumento,
      'fecha': fecha.toIso8601String(),
      'total': total,
      'vendedor': vendedor,
      'mesaNombre': mesaNombre,
      'pedidosIds': pedidosIds,
      'pedidos': pedidos.map((p) => p.toJson()).toList(),
      'pagado': pagado,
      'anulado': anulado,
      'estado': pagado
          ? 'Pagado'
          : (anulado
                ? 'Anulado'
                : 'Pendiente'), // Asegurar que el estado siempre esté presente
      if (motivoAnulacion != null) 'motivoAnulacion': motivoAnulacion,
      if (fechaCreacion != null)
        'fechaCreacion': fechaCreacion!.toIso8601String(),
      if (fechaPago != null) 'fechaPago': fechaPago!.toIso8601String(),
      if (formaPago != null) 'formaPago': formaPago,
      if (pagadoPor != null) 'pagadoPor': pagadoPor,
      if (propina != null) 'propina': propina,
    };
  }

  /// Crea un documento desde JSON recibido del backend
  factory DocumentoMesa.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para parsear fechas
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          print('Error parsing date: $e');
          return null;
        }
      }
      return null;
    }

    // Determinar si el documento está pagado considerando múltiples indicadores
    bool isPagado = false;
    if (json['pagado'] == true) {
      isPagado = true;
    } else if (json['estado'] != null &&
        (json['estado'].toString().toLowerCase() == 'pagado' ||
            json['estado'].toString().toLowerCase() == 'paid')) {
      // Si el estado es "Pagado" o "Paid", el documento está pagado
      isPagado = true;
    } else if (json['formaPago'] != null &&
        json['formaPago'].toString().isNotEmpty) {
      // Si tiene forma de pago especificada, probablemente esté pagado
      isPagado = true;
    } else if (json['fechaPago'] != null) {
      // Si tiene fecha de pago, definitivamente está pagado
      isPagado = true;
    }

    // Log para debug
    print('📄 DocumentoMesa fromJson: ${json['numeroDocumento']}');
    print('  - Estado recibido: ${json['estado']}');
    print('  - Forma de pago: ${json['formaPago']}');
    print('  - Fecha de pago: ${json['fechaPago']}');
    print('  - Pagado (flag): ${json['pagado']}');
    print('  - isPagado (calculado): $isPagado');

    // Si tenemos un documento pagado pero no tenemos forma de pago, asignar un valor por defecto
    String? formaPago = json['formaPago'];
    if (isPagado && (formaPago == null || formaPago.isEmpty)) {
      print(
        '⚠️ Documento pagado sin forma de pago especificada. Asignando efectivo por defecto.',
      );
      formaPago = 'efectivo';
    }

    // Determinar el estado correcto basado en el JSON y el flag pagado
    String estadoFinal;
    if (json['estado'] != null && json['estado'].toString().isNotEmpty) {
      estadoFinal = json['estado'].toString();
    } else if (isPagado) {
      estadoFinal = 'Pagado';
    } else if (json['anulado'] == true) {
      estadoFinal = 'Anulado';
    } else {
      estadoFinal = 'Pendiente';
    }
    
    print('  - Estado final asignado: $estadoFinal');

    return DocumentoMesa(
      id: json['_id'] ?? json['id'],
      numeroDocumento: json['numeroDocumento'] ?? '',
      fecha: parseDateTime(json['fecha']) ?? DateTime.now(),
      total: ((json['total'] ?? 0) as num).toDouble(),
      vendedor: json['vendedor'] ?? '',
      mesaNombre: json['mesaNombre'] ?? '',
      pedidosIds:
          (json['pedidosIds'] as List?)?.map((id) => id.toString()).toList() ??
          [],
      pedidos:
          (json['pedidos'] as List?)?.map((p) => Pedido.fromJson(p)).toList() ??
          [],
      pagado: isPagado,
      anulado: json['anulado'] ?? false,
      motivoAnulacion: json['motivoAnulacion'],
      fechaCreacion:
          parseDateTime(json['fechaCreacion']) ?? parseDateTime(json['fecha']),
      fechaPago: parseDateTime(json['fechaPago']),
      formaPago:
          formaPago, // Usamos la variable formaPago que puede tener un valor por defecto
      pagadoPor: json['pagadoPor'],
      propina: json['propina'] != null
          ? (json['propina'] as num).toDouble()
          : null,
      estado: estadoFinal, // ✅ Usar el estado determinado correctamente
    );
  }

  // Los métodos estadoTexto, fechaFormateada y estadoColor ya están definidos arriba
  // No necesitamos duplicarlos aquí
}
