import 'package:intl/intl.dart';

class MovimientoStock {
  final String id;
  final String productoId;
  final String productoNombre;
  final int cantidad; // Positivo (+) o negativo (-)
  final String tipo; // 'entrada', 'salida', 'ajuste', 'devolución', 'venta'
  final DateTime fecha;
  final String? observaciones;
  final String? usuario;
  final String? bodegaOrigen;
  final String? bodegaDestino;

  MovimientoStock({
    required this.id,
    required this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.tipo,
    required this.fecha,
    this.observaciones,
    this.usuario,
    this.bodegaOrigen,
    this.bodegaDestino,
  });

  factory MovimientoStock.fromJson(Map<String, dynamic> json) {
    return MovimientoStock(
      id: json['_id'] ?? json['id'] ?? '',
      productoId: json['productoId'] ?? '',
      productoNombre: json['productoNombre'] ?? '',
      cantidad: json['cantidad'] ?? 0,
      tipo: json['tipo'] ?? 'ajuste',
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'])
          : DateTime.now(),
      observaciones: json['observaciones'],
      usuario: json['usuario'],
      bodegaOrigen: json['bodegaOrigen'],
      bodegaDestino: json['bodegaDestino'],
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'productoId': productoId,
    'productoNombre': productoNombre,
    'cantidad': cantidad,
    'tipo': tipo,
    'fecha': fecha.toIso8601String(),
    if (observaciones != null) 'observaciones': observaciones,
    if (usuario != null) 'usuario': usuario,
    if (bodegaOrigen != null) 'bodegaOrigen': bodegaOrigen,
    if (bodegaDestino != null) 'bodegaDestino': bodegaDestino,
  };

  String get tipoLabel {
    switch (tipo) {
      case 'entrada':
        return 'Entrada';
      case 'salida':
        return 'Salida';
      case 'ajuste':
        return 'Ajuste';
      case 'devolución':
        return 'Devolución';
      case 'venta':
        return 'Venta';
      default:
        return tipo;
    }
  }

  bool get esEntrada => cantidad > 0;
}
