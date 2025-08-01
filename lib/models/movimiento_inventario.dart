import 'package:intl/intl.dart';

class MovimientoInventario {
  final String? id;
  final String inventarioId;
  final String productoId;
  final String productoNombre;
  final String tipoMovimiento;
  final String motivo;
  final double cantidadAnterior;
  final double cantidadMovimiento;
  final double cantidadNueva;
  final String? responsable;
  final String? referencia;
  final String? observaciones;
  final double? costoUnitario;
  final double? precioTotal;
  final DateTime fecha;
  final String? facturaNo;
  final String? proveedor;

  MovimientoInventario({
    this.id,
    required this.inventarioId,
    required this.productoId,
    required this.productoNombre,
    required this.tipoMovimiento,
    required this.motivo,
    required this.cantidadAnterior,
    required this.cantidadMovimiento,
    required this.cantidadNueva,
    this.responsable,
    this.referencia,
    this.observaciones,
    this.costoUnitario,
    this.precioTotal,
    required this.fecha,
    this.facturaNo,
    this.proveedor,
  });

  factory MovimientoInventario.fromJson(Map<String, dynamic> json) {
    return MovimientoInventario(
      id: json['_id'] ?? json['id'],
      inventarioId: json['inventarioId'] ?? '',
      productoId: json['productoId'] ?? '',
      productoNombre: json['productoNombre'] ?? '',
      tipoMovimiento: json['tipoMovimiento'] ?? '',
      motivo: json['motivo'] ?? '',
      cantidadAnterior: (json['cantidadAnterior'] as num?)?.toDouble() ?? 0.0,
      cantidadMovimiento:
          (json['cantidadMovimiento'] as num?)?.toDouble() ?? 0.0,
      cantidadNueva: (json['cantidadNueva'] as num?)?.toDouble() ?? 0.0,
      responsable: json['responsable'],
      referencia: json['referencia'],
      observaciones: json['observaciones'],
      costoUnitario: (json['costoUnitario'] as num?)?.toDouble(),
      precioTotal: (json['precioTotal'] as num?)?.toDouble(),
      fecha: json['fecha'] != null
          ? json['fecha'] is String
                ? DateTime.parse(json['fecha'])
                : DateTime.fromMillisecondsSinceEpoch(json['fecha'])
          : DateTime.now(),
      facturaNo: json['facturaNo'],
      proveedor: json['proveedor'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'inventarioId': inventarioId,
      'productoId': productoId,
      'productoNombre': productoNombre,
      'tipoMovimiento': tipoMovimiento,
      'motivo': motivo,
      'cantidadAnterior': cantidadAnterior,
      'cantidadMovimiento': cantidadMovimiento,
      'cantidadNueva': cantidadNueva,
      'responsable': responsable,
      'referencia': referencia,
      'observaciones': observaciones,
      'costoUnitario': costoUnitario,
      'precioTotal': precioTotal,
      'fecha': fecha.toIso8601String(),
      'facturaNo': facturaNo,
      'proveedor': proveedor,
    };
  }

  // Formato para la fecha
  String get fechaFormateada {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  // Devuelve si es una entrada o salida
  bool get esEntrada => tipoMovimiento.toLowerCase().contains('entrada');

  // Devuelve el valor del movimiento
  double get valorMovimiento {
    return (costoUnitario ?? 0.0) * cantidadMovimiento.abs();
  }
}
