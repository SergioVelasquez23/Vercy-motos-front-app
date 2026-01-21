class FacturaCompra {
  final String? id;
  final String numeroFactura;
  final String? proveedorNit;
  final String proveedorNombre;
  final DateTime fechaFactura;
  final DateTime fechaVencimiento;
  final double total;
  final String estado;
  final bool pagadoDesdeCaja;
  final List<ItemFacturaCompra> items;
  final String? descripcion;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  
  // 💰 Campos DIAN para impuestos y retenciones
  final double subtotal;
  final double totalDescuentos;
  final double baseGravable;
  final double totalImpuestos;
  final double totalRetenciones;

  // Retención en la fuente
  final double porcentajeRetencion;
  final double valorRetencion;

  // Retención de IVA
  final double porcentajeReteIva;
  final double valorReteIva;

  // Retención de ICA
  final double porcentajeReteIca;
  final double valorReteIca;

  FacturaCompra({
    this.id,
    required this.numeroFactura,
    this.proveedorNit,
    String? proveedorNombre,
    required this.fechaFactura,
    required this.fechaVencimiento,
    double? total,
    required this.estado,
    this.pagadoDesdeCaja = false,
    required this.items,
    this.descripcion,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    // Campos DIAN con valores por defecto
    double? subtotal,
    this.totalDescuentos = 0.0,
    double? baseGravable,
    this.totalImpuestos = 0.0,
    this.totalRetenciones = 0.0,
    this.porcentajeRetencion = 0.0,
    this.valorRetencion = 0.0,
    this.porcentajeReteIva = 0.0,
    this.valorReteIva = 0.0,
    this.porcentajeReteIca = 0.0,
    this.valorReteIca = 0.0,
  }) : proveedorNombre = proveedorNombre ?? 'Proveedor general',
       subtotal =
           subtotal ??
           items.fold<double>(0, (sum, item) => sum + item.subtotal),
       baseGravable =
           baseGravable ??
           (subtotal ??
               items.fold<double>(0, (sum, item) => sum + item.subtotal)),
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
          json['numero'] ?? json['numeroFactura'] ?? '',
      proveedorNit: json['proveedorNit'],
      proveedorNombre: json['proveedorNombre'],
      fechaFactura: DateTime.parse(
        json['fecha'] ??
            json['fechaFactura'] ??
            DateTime.now().toIso8601String(),
      ),
      fechaVencimiento: json['fechaVencimiento'] != null
          ? DateTime.parse(json['fechaVencimiento'])
          : DateTime.now().add(Duration(days: 30)),
      total: finalTotal,
      estado: json['estado'] ?? 'PENDIENTE',
      pagadoDesdeCaja: json['pagadoDesdeCaja'] ?? false,
      items: items,
      descripcion: json['descripcion'],
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : DateTime.now(),
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.parse(json['fechaActualizacion'])
          : DateTime.now(),
      // Campos DIAN
      subtotal: (json['subtotal'] ?? calculatedTotal).toDouble(),
      totalDescuentos: (json['totalDescuentos'] ?? 0).toDouble(),
      baseGravable: (json['baseGravable'] ?? calculatedTotal).toDouble(),
      totalImpuestos: (json['totalImpuestos'] ?? 0).toDouble(),
      totalRetenciones: (json['totalRetenciones'] ?? 0).toDouble(),
      porcentajeRetencion: (json['porcentajeRetencion'] ?? 0).toDouble(),
      valorRetencion: (json['valorRetencion'] ?? 0).toDouble(),
      porcentajeReteIva: (json['porcentajeReteIva'] ?? 0).toDouble(),
      valorReteIva: (json['valorReteIva'] ?? 0).toDouble(),
      porcentajeReteIca: (json['porcentajeReteIca'] ?? 0).toDouble(),
      valorReteIca: (json['valorReteIca'] ?? 0).toDouble(),
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
      'numero': numeroFactura,
      'fecha': fechaFactura.toIso8601String(),
      'tipoFactura': 'compra',
      'proveedorNit': proveedorNit,
      'proveedorNombre': proveedorNombre,
      'total': calculatedTotal,
      'pagadoDesdeCaja': pagadoDesdeCaja,
      'itemsIngredientes': itemsJsonList,
      'items': itemsJsonList,
      'medioPago': 'Efectivo',
      'formaPago': 'Contado',
      'registradoPor': 'admin',
      'descripcion': descripcion ?? '',
      'observaciones': '',
      // Campos DIAN para impuestos y retenciones
      'subtotal': subtotal,
      'totalDescuentos': totalDescuentos,
      'baseGravable': baseGravable,
      'totalImpuestos': totalImpuestos,
      'totalRetenciones': totalRetenciones,
      'porcentajeRetencion': porcentajeRetencion,
      'valorRetencion': valorRetencion,
      'porcentajeReteIva': porcentajeReteIva,
      'valorReteIva': valorReteIva,
      'porcentajeReteIca': porcentajeReteIca,
      'valorReteIca': valorReteIca,
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
  
  // 💰 Campos DIAN para impuestos detallados por item
  final double porcentajeImpuesto;
  final double valorImpuesto;
  final double porcentajeDescuento;
  final double valorDescuento;

  ItemFacturaCompra({
    required this.ingredienteId,
    required this.ingredienteNombre,
    required this.cantidad,
    required this.unidad,
    required this.precioUnitario,
    required this.subtotal,
    this.porcentajeImpuesto = 0.0,
    this.valorImpuesto = 0.0,
    this.porcentajeDescuento = 0.0,
    this.valorDescuento = 0.0,
  });

  factory ItemFacturaCompra.fromJson(Map<String, dynamic> json) {
    return ItemFacturaCompra(
      ingredienteId: json['ingredienteId'] ?? '',
      ingredienteNombre: json['ingredienteNombre'] ?? '',
      cantidad: (json['cantidad'] ?? 0).toDouble(),
      unidad: json['unidad'] ?? '',
      precioUnitario: (json['precioUnitario'] ?? 0).toDouble(),
      subtotal: (json['precioTotal'] ?? json['subtotal'] ?? 0).toDouble(),
      porcentajeImpuesto: (json['porcentajeImpuesto'] ?? 0).toDouble(),
      valorImpuesto: (json['valorImpuesto'] ?? 0).toDouble(),
      porcentajeDescuento: (json['porcentajeDescuento'] ?? 0).toDouble(),
      valorDescuento: (json['valorDescuento'] ?? 0).toDouble(),
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
      'precioTotal': validSubtotal,
      'subtotal': validSubtotal,
      'descontable': true,
      'observaciones': '',
      // Campos DIAN
      'porcentajeImpuesto': porcentajeImpuesto,
      'valorImpuesto': valorImpuesto,
      'porcentajeDescuento': porcentajeDescuento,
      'valorDescuento': valorDescuento,
    };
  }
}
