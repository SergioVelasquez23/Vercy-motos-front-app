import 'item_pedido.dart';

class PedidoAsesor {
  String? id;
  String clienteNombre;
  String? clienteId;
  String asesorNombre;
  String? asesorId;
  List<ItemPedido> items;
  double subtotal;
  double impuestos;
  double descuento;
  double total;
  String estado; // PENDIENTE, FACTURADO, CANCELADO
  DateTime fechaCreacion;
  DateTime? fechaFacturacion;
  String? observaciones;
  String? facturadoPor;

  PedidoAsesor({
    this.id,
    required this.clienteNombre,
    this.clienteId,
    required this.asesorNombre,
    this.asesorId,
    required this.items,
    required this.subtotal,
    required this.impuestos,
    this.descuento = 0,
    required this.total,
    this.estado = 'PENDIENTE',
    required this.fechaCreacion,
    this.fechaFacturacion,
    this.observaciones,
    this.facturadoPor,
  });

  factory PedidoAsesor.fromJson(Map<String, dynamic> json) {
    return PedidoAsesor(
      id: json['_id'] ?? json['id'],
      clienteNombre: json['clienteNombre'] ?? '',
      clienteId: json['clienteId'],
      asesorNombre: json['asesorNombre'] ?? '',
      asesorId: json['asesorId'],
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => ItemPedido.fromJson(item))
              .toList() ??
          [],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      impuestos: (json['impuestos'] ?? 0).toDouble(),
      descuento: (json['descuento'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      estado: json['estado'] ?? 'PENDIENTE',
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : DateTime.now(),
      fechaFacturacion: json['fechaFacturacion'] != null
          ? DateTime.parse(json['fechaFacturacion'])
          : null,
      observaciones: json['observaciones'],
      facturadoPor: json['facturadoPor'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'clienteNombre': clienteNombre,
      if (clienteId != null) 'clienteId': clienteId,
      'asesorNombre': asesorNombre,
      if (asesorId != null) 'asesorId': asesorId,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'impuestos': impuestos,
      'descuento': descuento,
      'total': total,
      'estado': estado,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      if (fechaFacturacion != null)
        'fechaFacturacion': fechaFacturacion!.toIso8601String(),
      if (observaciones != null) 'observaciones': observaciones,
      if (facturadoPor != null) 'facturadoPor': facturadoPor,
    };
  }
}
