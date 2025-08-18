class FacturaCompra {
  final String? id; // Hacemos el ID opcional
  final String numeroFactura;
  final String? proveedorNit;
  final String proveedorNombre;
  final DateTime fechaFactura;
  final DateTime fechaVencimiento;
  final double total;
  final String estado;
  final bool pagadoDesdeCaja;
  final List<ItemFacturaCompra> items;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  FacturaCompra({
    this.id, // Ahora es opcional
    required this.numeroFactura,
    this.proveedorNit,
    String? proveedorNombre,
    required this.fechaFactura,
    required this.fechaVencimiento,
    required this.total,
    required this.estado,
    this.pagadoDesdeCaja = false,
    required this.items,
    required this.fechaCreacion,
    required this.fechaActualizacion,
  }) : proveedorNombre = proveedorNombre ?? 'Proveedor general';

  factory FacturaCompra.fromJson(Map<String, dynamic> json) {
    return FacturaCompra(
      id: json['_id'] ?? '',
      numeroFactura:
          json['numero'] ?? json['numeroFactura'] ?? '', // Backend usa 'numero'
      proveedorNit: json['proveedorNit'],
      proveedorNombre: json['proveedorNombre'],
      fechaFactura: DateTime.parse(
        json['fecha'] ??
            json['fechaFactura'] ??
            DateTime.now().toIso8601String(),
      ),
      fechaVencimiento: json['fechaVencimiento'] != null
          ? DateTime.parse(json['fechaVencimiento'])
          : DateTime.now().add(
              Duration(days: 30),
            ), // Default a 30 días si no existe
      total: (json['total'] ?? 0).toDouble(),
      estado: json['estado'] ?? 'PENDIENTE',
      pagadoDesdeCaja: json['pagadoDesdeCaja'] ?? false,
      items:
          (json['itemsIngredientes']
                  as List<dynamic>?) // Backend usa 'itemsIngredientes'
              ?.map((item) => ItemFacturaCompra.fromJson(item))
              .toList() ??
          (json['items']
                  as List<dynamic>?) // Fallback a 'items' por compatibilidad
              ?.map((item) => ItemFacturaCompra.fromJson(item))
              .toList() ??
          [],
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : DateTime.now(),
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.parse(json['fechaActualizacion'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'numero': numeroFactura, // Backend usa 'numero', no 'numeroFactura'
      'fecha': fechaFactura.toIso8601String(), // Backend usa 'fecha'
      'tipoFactura': 'compra', // Especificar que es una factura de compra
      'proveedorNit': proveedorNit,
      'proveedorNombre': proveedorNombre,
      'total': total,
      'pagadoDesdeCaja': pagadoDesdeCaja,
      'itemsIngredientes': items
          .map((item) => item.toJson())
          .toList(), // Backend usa 'itemsIngredientes'
      'medioPago': 'Efectivo', // Valor por defecto
      'formaPago': 'Contado', // Valor por defecto
      'registradoPor': 'admin', // Valor por defecto
      'observaciones': '', // Valor por defecto
    };

    // Solo incluir el ID si existe y no está vacío (para crear vs actualizar)
    if (id != null && id!.isNotEmpty) {
      json['_id'] = id;
    }

    return json;
  }
}

class ItemFacturaCompra {
  final String ingredienteId;
  final String ingredienteNombre;
  final double cantidad;
  final String unidad;
  final double precioUnitario;
  final double subtotal;

  ItemFacturaCompra({
    required this.ingredienteId,
    required this.ingredienteNombre,
    required this.cantidad,
    required this.unidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory ItemFacturaCompra.fromJson(Map<String, dynamic> json) {
    return ItemFacturaCompra(
      ingredienteId: json['ingredienteId'] ?? '',
      ingredienteNombre: json['ingredienteNombre'] ?? '',
      cantidad: (json['cantidad'] ?? 0).toDouble(),
      unidad: json['unidad'] ?? '',
      precioUnitario: (json['precioUnitario'] ?? 0).toDouble(),
      subtotal: (json['precioTotal'] ?? json['subtotal'] ?? 0)
          .toDouble(), // Backend usa 'precioTotal'
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ingredienteId': ingredienteId,
      'ingredienteNombre': ingredienteNombre,
      'cantidad': cantidad,
      'unidad': unidad,
      'precioUnitario': precioUnitario,
      'precioTotal': subtotal, // Backend espera 'precioTotal'
      'descontable': true, // Valor por defecto
      'observaciones': '', // Valor por defecto
    };
  }
}
