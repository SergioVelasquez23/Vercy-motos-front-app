import 'item_cotizacion.dart';

class Cotizacion {
  String? id;
  DateTime fecha;
  DateTime? fechaVencimiento;
  String
  estado; // "activa" | "aceptada" | "rechazada" | "vencida" | "convertida"

  // Cliente
  String clienteId;
  String? clienteNombre;
  String? clienteTelefono;
  String? clienteEmail;

  // Items
  List<ItemCotizacion> items;

  // Información adicional
  String? descripcion;
  List<String> archivosAdjuntos;
  List<String> soportesPago;

  // Retenciones
  double retencion;
  double valorRetencion;
  double reteIVA;
  double valorReteIVA;
  double reteICA;
  double valorReteICA;

  // Descuentos
  String tipoDescuentoGeneral; // "Valor" | "Porcentaje"
  double descuentoGeneral;
  double descuentoProductos;

  // Totales
  double subtotal;
  double totalImpuestos;
  double totalDescuentos;
  double totalRetenciones;
  double totalFinal;

  // Tracking
  String? numeroCotizacion; // Auto: COT-202601-0001
  String? creadoPor;
  String? facturaRelacionadaId;

  Cotizacion({
    this.id,
    DateTime? fecha,
    this.fechaVencimiento,
    this.estado = 'activa',
    required this.clienteId,
    this.clienteNombre,
    this.clienteTelefono,
    this.clienteEmail,
    List<ItemCotizacion>? items,
    this.descripcion,
    List<String>? archivosAdjuntos,
    List<String>? soportesPago,
    this.retencion = 0.0,
    this.valorRetencion = 0.0,
    this.reteIVA = 0.0,
    this.valorReteIVA = 0.0,
    this.reteICA = 0.0,
    this.valorReteICA = 0.0,
    this.tipoDescuentoGeneral = 'Valor',
    this.descuentoGeneral = 0.0,
    this.descuentoProductos = 0.0,
    this.subtotal = 0.0,
    this.totalImpuestos = 0.0,
    this.totalDescuentos = 0.0,
    this.totalRetenciones = 0.0,
    this.totalFinal = 0.0,
    this.numeroCotizacion,
    this.creadoPor,
    this.facturaRelacionadaId,
  }) : this.fecha = fecha ?? DateTime.now(),
       this.items = items ?? [],
       this.archivosAdjuntos = archivosAdjuntos ?? [],
       this.soportesPago = soportesPago ?? [];

  // Método: calcularTotales
  void calcularTotales() {
    // 1. Calcular valores de impuestos y descuentos de cada item
    for (var item in items) {
      item.calcularValorImpuesto();
      item.calcularValorDescuento();
    }

    // 2. Calcular subtotal
    subtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);

    // 3. Calcular total de impuestos
    totalImpuestos = items.fold(0.0, (sum, item) => sum + item.valorImpuesto);

    // 4. Calcular descuento de productos
    descuentoProductos = items.fold(
      0.0,
      (sum, item) => sum + item.valorDescuento,
    );

    // 5. Calcular descuento general (si es porcentaje, convertirlo a valor)
    double descuentoGeneralCalculado = descuentoGeneral;
    if (tipoDescuentoGeneral == 'Porcentaje') {
      descuentoGeneralCalculado = (subtotal * descuentoGeneral) / 100.0;
    }

    // 6. Calcular total de descuentos
    totalDescuentos = descuentoGeneralCalculado + descuentoProductos;

    // 7. Calcular retenciones
    valorRetencion = (subtotal * retencion) / 100.0;
    valorReteIVA = (totalImpuestos * reteIVA) / 100.0;
    valorReteICA = (subtotal * reteICA) / 100.0;
    totalRetenciones = valorRetencion + valorReteIVA + valorReteICA;

    // 8. Calcular total final
    totalFinal = subtotal + totalImpuestos - totalDescuentos - totalRetenciones;
  }

  // Método: agregar item
  void agregarItem(ItemCotizacion item) {
    items.add(item);
    calcularTotales();
  }

  // Método: eliminar item
  void eliminarItem(int index) {
    if (index >= 0 && index < items.length) {
      items.removeAt(index);
      calcularTotales();
    }
  }

  // Método: actualizar item
  void actualizarItem(int index, ItemCotizacion item) {
    if (index >= 0 && index < items.length) {
      items[index] = item;
      calcularTotales();
    }
  }

  // Getter: está vencida
  bool get estaVencida {
    if (fechaVencimiento == null) return false;
    return DateTime.now().isAfter(fechaVencimiento!) && estado == 'activa';
  }

  // Getter: puede convertirse a factura
  bool get puedeConvertirseAFactura {
    return estado == 'activa' || estado == 'aceptada';
  }

  // fromJson
  factory Cotizacion.fromJson(Map<String, dynamic> json) {
    return Cotizacion(
      id: json['_id'] ?? json['id'],
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'])
          : DateTime.now(),
      fechaVencimiento: json['fechaVencimiento'] != null
          ? DateTime.parse(json['fechaVencimiento'])
          : null,
      estado: json['estado'] ?? 'activa',
      clienteId: json['clienteId'] ?? '',
      clienteNombre: json['clienteNombre'],
      clienteTelefono: json['clienteTelefono'],
      clienteEmail: json['clienteEmail'],
      items:
          (json['items'] as List?)
              ?.map((item) => ItemCotizacion.fromJson(item))
              .toList() ??
          [],
      descripcion: json['descripcion'],
      archivosAdjuntos: json['archivosAdjuntos'] != null
          ? List<String>.from(json['archivosAdjuntos'])
          : [],
      soportesPago: json['soportesPago'] != null
          ? List<String>.from(json['soportesPago'])
          : [],
      retencion: (json['retencion'] ?? 0.0).toDouble(),
      valorRetencion: (json['valorRetencion'] ?? 0.0).toDouble(),
      reteIVA: (json['reteIVA'] ?? 0.0).toDouble(),
      valorReteIVA: (json['valorReteIVA'] ?? 0.0).toDouble(),
      reteICA: (json['reteICA'] ?? 0.0).toDouble(),
      valorReteICA: (json['valorReteICA'] ?? 0.0).toDouble(),
      tipoDescuentoGeneral: json['tipoDescuentoGeneral'] ?? 'Valor',
      descuentoGeneral: (json['descuentoGeneral'] ?? 0.0).toDouble(),
      descuentoProductos: (json['descuentoProductos'] ?? 0.0).toDouble(),
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      totalImpuestos: (json['totalImpuestos'] ?? 0.0).toDouble(),
      totalDescuentos: (json['totalDescuentos'] ?? 0.0).toDouble(),
      totalRetenciones: (json['totalRetenciones'] ?? 0.0).toDouble(),
      totalFinal: (json['totalFinal'] ?? 0.0).toDouble(),
      numeroCotizacion: json['numeroCotizacion'],
      creadoPor: json['creadoPor'],
      facturaRelacionadaId: json['facturaRelacionadaId'],
    );
  }

  // toJson
  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'fecha': fecha.toIso8601String(),
      if (fechaVencimiento != null)
        'fechaVencimiento': fechaVencimiento!.toIso8601String(),
      'estado': estado,
      'clienteId': clienteId,
      if (clienteNombre != null) 'clienteNombre': clienteNombre,
      if (clienteTelefono != null) 'clienteTelefono': clienteTelefono,
      if (clienteEmail != null) 'clienteEmail': clienteEmail,
      'items': items.map((item) => item.toJson()).toList(),
      if (descripcion != null) 'descripcion': descripcion,
      'archivosAdjuntos': archivosAdjuntos,
      'soportesPago': soportesPago,
      'retencion': retencion,
      'valorRetencion': valorRetencion,
      'reteIVA': reteIVA,
      'valorReteIVA': valorReteIVA,
      'reteICA': reteICA,
      'valorReteICA': valorReteICA,
      'tipoDescuentoGeneral': tipoDescuentoGeneral,
      'descuentoGeneral': descuentoGeneral,
      'descuentoProductos': descuentoProductos,
      'subtotal': subtotal,
      'totalImpuestos': totalImpuestos,
      'totalDescuentos': totalDescuentos,
      'totalRetenciones': totalRetenciones,
      'totalFinal': totalFinal,
      if (numeroCotizacion != null) 'numeroCotizacion': numeroCotizacion,
      if (creadoPor != null) 'creadoPor': creadoPor,
      if (facturaRelacionadaId != null)
        'facturaRelacionadaId': facturaRelacionadaId,
    };
  }

  // copyWith
  Cotizacion copyWith({
    String? id,
    DateTime? fecha,
    DateTime? fechaVencimiento,
    String? estado,
    String? clienteId,
    String? clienteNombre,
    String? clienteTelefono,
    String? clienteEmail,
    List<ItemCotizacion>? items,
    String? descripcion,
    List<String>? archivosAdjuntos,
    List<String>? soportesPago,
    double? retencion,
    double? valorRetencion,
    double? reteIVA,
    double? valorReteIVA,
    double? reteICA,
    double? valorReteICA,
    String? tipoDescuentoGeneral,
    double? descuentoGeneral,
    double? descuentoProductos,
    double? subtotal,
    double? totalImpuestos,
    double? totalDescuentos,
    double? totalRetenciones,
    double? totalFinal,
    String? numeroCotizacion,
    String? creadoPor,
    String? facturaRelacionadaId,
  }) {
    return Cotizacion(
      id: id ?? this.id,
      fecha: fecha ?? this.fecha,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      estado: estado ?? this.estado,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      clienteEmail: clienteEmail ?? this.clienteEmail,
      items: items ?? this.items,
      descripcion: descripcion ?? this.descripcion,
      archivosAdjuntos: archivosAdjuntos ?? this.archivosAdjuntos,
      soportesPago: soportesPago ?? this.soportesPago,
      retencion: retencion ?? this.retencion,
      valorRetencion: valorRetencion ?? this.valorRetencion,
      reteIVA: reteIVA ?? this.reteIVA,
      valorReteIVA: valorReteIVA ?? this.valorReteIVA,
      reteICA: reteICA ?? this.reteICA,
      valorReteICA: valorReteICA ?? this.valorReteICA,
      tipoDescuentoGeneral: tipoDescuentoGeneral ?? this.tipoDescuentoGeneral,
      descuentoGeneral: descuentoGeneral ?? this.descuentoGeneral,
      descuentoProductos: descuentoProductos ?? this.descuentoProductos,
      subtotal: subtotal ?? this.subtotal,
      totalImpuestos: totalImpuestos ?? this.totalImpuestos,
      totalDescuentos: totalDescuentos ?? this.totalDescuentos,
      totalRetenciones: totalRetenciones ?? this.totalRetenciones,
      totalFinal: totalFinal ?? this.totalFinal,
      numeroCotizacion: numeroCotizacion ?? this.numeroCotizacion,
      creadoPor: creadoPor ?? this.creadoPor,
      facturaRelacionadaId: facturaRelacionadaId ?? this.facturaRelacionadaId,
    );
  }

  @override
  String toString() =>
      'Cotizacion(id: $id, numero: $numeroCotizacion, cliente: $clienteNombre, estado: $estado, total: ${totalFinal.toStringAsFixed(2)})';
}
