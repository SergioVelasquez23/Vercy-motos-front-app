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
    double? total,
    required this.estado,
    this.pagadoDesdeCaja = false,
    required this.items,
    required this.fechaCreacion,
    required this.fechaActualizacion,
  }) : proveedorNombre = proveedorNombre ?? 'Proveedor general',
       // Si no se proporciona un total, calcularlo automáticamente de los items
       total =
           total ?? items.fold<double>(0, (sum, item) => sum + item.subtotal);

  factory FacturaCompra.fromJson(Map<String, dynamic> json) {
    // Primero extraemos los items para poder calcular el total
    final items =
        (json['itemsIngredientes']
                as List<dynamic>?) // Backend usa 'itemsIngredientes'
            ?.map((item) => ItemFacturaCompra.fromJson(item))
            .toList() ??
        (json['items']
                as List<dynamic>?) // Fallback a 'items' por compatibilidad
            ?.map((item) => ItemFacturaCompra.fromJson(item))
            .toList() ??
        [];

    // Calculamos el total basado en los items
    double calculatedTotal = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    // Si el total del JSON es 0 pero hay items con valores, usamos el calculado
    double jsonTotal = (json['total'] ?? 0).toDouble();
    double finalTotal = jsonTotal > 0 ? jsonTotal : calculatedTotal;

    if (jsonTotal == 0 && calculatedTotal > 0) {
      print(
        '⚠️ Corrigiendo total en fromJson: JSON=$jsonTotal, Calculado=$calculatedTotal',
      );
    }

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
      total: finalTotal, // Usar el total calculado si el del JSON es 0
      estado: json['estado'] ?? 'PENDIENTE',
      pagadoDesdeCaja: json['pagadoDesdeCaja'] ?? false,
      items: items,
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : DateTime.now(),
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.parse(json['fechaActualizacion'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    // Calcular el total basado en los ítems, incluso si ya está establecido
    double calculatedTotal = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );

    // Verificar que hay items y que no son nulos
    List<Map<String, dynamic>> itemsJsonList = [];
    if (items.isNotEmpty) {
      itemsJsonList = items.map((item) => item.toJson()).toList();
      print('📦 Serializando ${items.length} items para enviar al servidor');
      for (var i = 0; i < items.length; i++) {
        print(
          '📦 Item $i: ${items[i].ingredienteNombre} - ${items[i].cantidad} ${items[i].unidad} = ${items[i].subtotal}',
        );
      }
    } else {
      print('⚠️ No hay items para serializar en la factura');
    }

    final Map<String, dynamic> json = {
      'numero': numeroFactura, // Backend usa 'numero', no 'numeroFactura'
      'fecha': fechaFactura.toIso8601String(), // Backend usa 'fecha'
      'tipoFactura': 'compra', // Especificar que es una factura de compra
      'proveedorNit': proveedorNit,
      'proveedorNombre': proveedorNombre,
      'total':
          calculatedTotal, // Usar el total recalculado para asegurar consistencia
      'pagadoDesdeCaja': pagadoDesdeCaja,
      'itemsIngredientes': itemsJsonList, // Backend usa 'itemsIngredientes'
      // También incluimos una copia en 'items' por si el backend busca ahí
      'items': itemsJsonList,
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
    // Calcular el subtotal de nuevo para estar seguros
    double calculatedSubtotal = cantidad * precioUnitario;

    // Usar el calculado solo si hay una discrepancia significativa
    double finalSubtotal = (calculatedSubtotal - subtotal).abs() < 0.001
        ? subtotal
        : calculatedSubtotal;

    // Validar que todos los valores numéricos sean positivos
    double validCantidad = cantidad > 0 ? cantidad : 0.01;
    double validPrecioUnitario = precioUnitario > 0 ? precioUnitario : 0.01;
    double validSubtotal = finalSubtotal > 0
        ? finalSubtotal
        : validCantidad * validPrecioUnitario;

    return {
      'ingredienteId': ingredienteId,
      'ingredienteNombre': ingredienteNombre,
      'cantidad': validCantidad,
      'unidad': unidad,
      'precioUnitario': validPrecioUnitario,
      'precioTotal': validSubtotal, // Backend espera 'precioTotal'
      'subtotal': validSubtotal, // Incluir también como 'subtotal' por si acaso
      'descontable': true, // Valor por defecto
      'observaciones': '', // Valor por defecto
    };
  }
}
