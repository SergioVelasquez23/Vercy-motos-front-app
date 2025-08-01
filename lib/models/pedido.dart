import 'package:flutter/material.dart';
import 'producto.dart';
import 'item_pedido.dart'; // Importar el ItemPedido correcto

enum TipoPedido { normal, rt, interno, cancelado, cortesia }

enum EstadoPedido { activo, pagado, cancelado, cortesia }

extension EstadoPedidoExtension on EstadoPedido {
  String toJson() {
    return toString().split('.').last;
  }

  static EstadoPedido fromJson(String json) {
    // Convertir a minúsculas para comparación case-insensitive
    final jsonLowerCase = json.toLowerCase();
    return EstadoPedido.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == jsonLowerCase,
      orElse: () => EstadoPedido.activo,
    );
  }
}

extension TipoPedidoExtension on TipoPedido {
  String toJson() {
    return toString().split('.').last;
  }

  static TipoPedido fromJson(String json) {
    // Convertir a minúsculas para comparación case-insensitive
    final jsonLowerCase = json.toLowerCase();
    return TipoPedido.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == jsonLowerCase,
      orElse: () => TipoPedido.normal,
    );
  }
}

class Pedido {
  String id;
  DateTime fecha;
  TipoPedido tipo;
  String mesa;
  String? cliente;
  String mesero;
  List<ItemPedido> items;
  double total;
  EstadoPedido estado;
  String? notas;
  String? plataforma;
  String? pedidoPor;
  String? guardadoPor;
  DateTime? fechaCortesia;
  String? formaPago;
  bool incluyePropina;
  double descuento;

  void setFormaPago(String formaPago) {
    this.formaPago = formaPago;
  }

  void setIncluyePropina(bool incluyePropina) {
    this.incluyePropina = incluyePropina;
  }

  void setDescuento(double descuento) {
    this.descuento = descuento;
  }

  Pedido({
    required this.id,
    required this.fecha,
    required this.tipo,
    required this.mesa,
    required this.mesero,
    required this.items,
    required this.total,
    required this.estado,
    this.cliente,
    this.notas,
    this.plataforma,
    this.pedidoPor,
    this.guardadoPor,
    this.fechaCortesia,
    this.formaPago,
    this.incluyePropina = false,
    this.descuento = 0,
  });

  String get tipoTexto {
    switch (tipo) {
      case TipoPedido.normal:
        return 'Normal';
      case TipoPedido.rt:
        return 'RT';
      case TipoPedido.interno:
        return 'Interno';
      case TipoPedido.cancelado:
        return 'Cancelado';
      case TipoPedido.cortesia:
        return 'Cortesía';
    }
  }

  String get estadoTexto {
    switch (estado) {
      case EstadoPedido.activo:
        return 'Activo';
      case EstadoPedido.pagado:
        return 'Pagado';
      case EstadoPedido.cancelado:
        return 'Cancelado';
      case EstadoPedido.cortesia:
        return 'Cortesía';
    }
  }

  Color getColorByTipo() {
    switch (tipo) {
      case TipoPedido.normal:
        return Colors.blue;
      case TipoPedido.rt:
        return Colors.purple;
      case TipoPedido.interno:
        return Colors.orange;
      case TipoPedido.cancelado:
        return Colors.red;
      case TipoPedido.cortesia:
        return Colors.green;
    }
  }

  Color getColorByEstado() {
    switch (estado) {
      case EstadoPedido.activo:
        return Colors.green;
      case EstadoPedido.pagado:
        return Colors.blue;
      case EstadoPedido.cancelado:
        return Colors.red;
      case EstadoPedido.cortesia:
        return Colors.green;
    }
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'fecha': fecha.toIso8601String(),
    'tipo': tipo.toJson(),
    'mesa': mesa,
    'cliente': cliente,
    'mesero': mesero,
    'items': items.map((item) => item.toJson()).toList(),
    'total': total,
    'estado': estado.toJson(),
    'notas': notas,
    'plataforma': plataforma,
    'pedidoPor': pedidoPor,
    'guardadoPor': guardadoPor,
    'fechaCortesia': fechaCortesia?.toIso8601String(),
    'formaPago': formaPago,
    'incluyePropina': incluyePropina,
    'descuento': descuento,
  };

  factory Pedido.fromJson(Map<String, dynamic> json) {
    return Pedido(
      id: json['_id'] ?? json['id'] ?? '',
      fecha: DateTime.parse(json['fecha']),
      tipo: TipoPedidoExtension.fromJson(json['tipo'] ?? 'normal'),
      mesa: json['mesa'] ?? '',
      cliente: json['cliente'],
      mesero: json['mesero'] ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => ItemPedido.fromJson(item))
              .toList() ??
          [],
      total: (json['total'] ?? 0).toDouble(),
      estado: EstadoPedidoExtension.fromJson(json['estado'] ?? 'activo'),
      notas: json['notas'],
      plataforma: json['plataforma'],
      pedidoPor: json['pedidoPor'],
      guardadoPor: json['guardadoPor'],
      fechaCortesia: json['fechaCortesia'] != null
          ? DateTime.parse(json['fechaCortesia'])
          : null,
      formaPago: json['formaPago'],
      incluyePropina: json['incluyePropina'] ?? false,
      descuento: (json['descuento'] ?? 0).toDouble(),
    );
  }
}
