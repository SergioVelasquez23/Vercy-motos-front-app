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
       // Si total es null o 0, usar la suma de items
       total = (total != null && total > 0)
           ? total
           : items.fold<double>(0, (sum, item) => sum + item.subtotal);

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
             }

    // ⚠️ El modelo Compra del backend (Java) NO tiene campos 'fecha'/'fechaFactura'
    // ni 'estado' (string): solo tiene 'fechaCreacion' y 'pagado' (bool). Si solo
    // se busca 'fecha'/'fechaFactura'/'estado', al editar una compra guardada
    // siempre se muestra la fecha de HOY y el estado por defecto, no lo real.
    final fechaFacturaRaw =
        json['fecha'] ?? json['fechaFactura'] ?? json['fechaCreacion'];
    final estadoDerivado = json['pagado'] == true ? 'PAGADO' : 'PENDIENTE';

    return FacturaCompra(
      id: json['_id'] ?? '',
      numeroFactura:
          json['numero'] ?? json['numeroFactura'] ?? '',
      proveedorNit: json['proveedorNit'],
      proveedorNombre: json['proveedorNombre'],
      fechaFactura: fechaFacturaRaw != null
          ? DateTime.parse(fechaFacturaRaw)
          : DateTime.now(),
      fechaVencimiento: json['fechaVencimiento'] != null
          ? DateTime.parse(json['fechaVencimiento'])
          : DateTime.now().add(Duration(days: 30)),
      total: finalTotal,
      estado: json['estado'] ?? estadoDerivado,
      pagadoDesdeCaja: json['pagadoDesdeCaja'] ?? false,
      items: items,
      descripcion: json['descripcion'],
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : (fechaFacturaRaw != null
              ? DateTime.parse(fechaFacturaRaw)
              : DateTime.now()),
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.parse(json['fechaActualizacion'])
          : DateTime.now(),
      // Campos DIAN. El backend guarda el IVA en el campo 'iva' (no 'totalImpuestos').
      subtotal: (json['subtotal'] ?? calculatedTotal).toDouble(),
      totalDescuentos: (json['totalDescuentos'] ?? 0).toDouble(),
      baseGravable: (json['baseGravable'] ?? calculatedTotal).toDouble(),
      totalImpuestos: (json['totalImpuestos'] ?? json['iva'] ?? 0).toDouble(),
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
    // Calcular el total basado en los ítems siempre
    double calculatedTotal = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    
    // Calcular el total con impuestos
    double calculatedTotalConImpuestos = items.fold<double>(
      0,
      (sum, item) =>
          sum + item.subtotal + item.valorImpuesto - item.valorDescuento,
    );

    // Usar el total calculado si el actual es 0 o menor
    double finalTotal = total > 0
        ? total
        : (calculatedTotalConImpuestos > 0
              ? calculatedTotalConImpuestos
              : calculatedTotal);

       
    // Verificar que hay items y que no son nulos
    List<Map<String, dynamic>> itemsJsonList = [];
    if (items.isNotEmpty) {
      itemsJsonList = items.map((item) => item.toJson()).toList();
        
      for (var i = 0; i < items.length; i++) {
                 }
    } else {
        
    }

    // Calcular subtotal y impuestos de los items
    double itemsSubtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    double itemsImpuestos = items.fold<double>(
      0,
      (sum, item) => sum + item.valorImpuesto,
    );
    double itemsDescuentos = items.fold<double>(
      0,
      (sum, item) => sum + item.valorDescuento,
    );

    final Map<String, dynamic> json = {
      'numero': numeroFactura,
      'fecha': fechaFactura.toIso8601String(),
      'fechaVencimiento': fechaVencimiento.toIso8601String(),
      'tipoFactura': 'compra',
      'proveedorNit': proveedorNit,
      'proveedorNombre': proveedorNombre,
      'total': finalTotal, // Usar el total final calculado
      'pagadoDesdeCaja': pagadoDesdeCaja,
      'itemsIngredientes': itemsJsonList,
      // ✅ NO enviar 'items' duplicado - el backend procesa ambos arrays causando doble stock
      'items': [],
      'medioPago': 'Efectivo',
      'formaPago': 'Contado',
      'registradoPor': 'admin',
      'descripcion': descripcion ?? '',
      'observaciones': '',
      // Campos DIAN para impuestos y retenciones - usar valores calculados de items si los originales son 0
      'subtotal': subtotal > 0 ? subtotal : itemsSubtotal,
      'totalDescuentos': totalDescuentos > 0
          ? totalDescuentos
          : itemsDescuentos,
      'baseGravable': baseGravable > 0 ? baseGravable : itemsSubtotal,
      'totalImpuestos': totalImpuestos > 0 ? totalImpuestos : itemsImpuestos,
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
  
  // 📦 DESTINO EN COMPRAS
  final String destino; // "BODEGA", "ALMACÉN" o "PARTE Y PARTE"
  final double
  cantidadAlmacen; // Cantidad para almacén (solo para PARTE Y PARTE)
  final double cantidadBodega; // Cantidad para bodega (solo para PARTE Y PARTE)

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
    this.destino = "ALMACÉN",
    this.cantidadAlmacen = 0.0,
    this.cantidadBodega = 0.0,
  });

  factory ItemFacturaCompra.fromJson(Map<String, dynamic> json) {
    return ItemFacturaCompra(
      // ⚠️ El backend usa dos formatos distintos según el endpoint:
      // - Al CREAR (POST), el controller espera 'ingredienteId'/'ingredienteNombre'
      //   (protocolo propio, ver CompraController.crearItemIngrediente).
      // - Al LEER (GET), Jackson serializa el modelo real ItemFactura/LineaDetalle,
      //   que usa 'productoId'/'productoNombre'/'subtotalItem'. Si solo se busca el
      //   primer nombre, al editar una compra ya guardada el nombre queda vacío y
      //   el subtotal en $0.
      ingredienteId: (json['ingredienteId'] ?? json['productoId'] ?? '').toString(),
      ingredienteNombre:
          (json['ingredienteNombre'] ?? json['productoNombre'] ?? '').toString(),
      cantidad: (json['cantidad'] ?? 0).toDouble(),
      unidad: (json['unidad'] ?? '').toString(),
      precioUnitario: (json['precioUnitario'] ?? 0).toDouble(),
      subtotal: (json['precioTotal'] ??
              json['subtotal'] ??
              json['subtotalItem'] ??
              0)
          .toDouble(),
      porcentajeImpuesto: (json['porcentajeImpuesto'] ?? 0).toDouble(),
      valorImpuesto: (json['valorImpuesto'] ?? 0).toDouble(),
      porcentajeDescuento: (json['porcentajeDescuento'] ?? 0).toDouble(),
      valorDescuento: (json['valorDescuento'] ?? 0).toDouble(),
      // 📦 Inferir destino: si cantidadAlmacen Y cantidadBodega > 0, es PARTE Y PARTE
      destino: _inferirDestino(json),
      cantidadAlmacen: (json['cantidadAlmacen'] ?? 0).toDouble(),
      cantidadBodega: (json['cantidadBodega'] ?? 0).toDouble(),
    );
  }

  // 📦 Método para inferir el destino basado en cantidades
  static String _inferirDestino(Map<String, dynamic> json) {
    final cantAlmacen = (json['cantidadAlmacen'] ?? 0).toDouble();
    final cantBodega = (json['cantidadBodega'] ?? 0).toDouble();
    final destinoGuardado = json['destino']?.toString();

    // Si hay destino guardado y no es el default, usarlo
    if (destinoGuardado != null && destinoGuardado.isNotEmpty) {
      return destinoGuardado;
    }

    // Inferir basado en cantidades
    if (cantAlmacen > 0 && cantBodega > 0) {
      return 'PARTE Y PARTE';
    } else if (cantBodega > 0 && cantAlmacen == 0) {
      return 'BODEGA';
    }
    return 'ALMACÉN';
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
      // 📦 Destino en compras
      'destino': destino,
      'cantidadAlmacen': cantidadAlmacen,
      'cantidadBodega': cantidadBodega,
    };
  }
}
