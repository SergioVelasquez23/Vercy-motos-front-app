class ItemCotizacion {
  String? id;
  String productoId;
  String? productoNombre;
  int cantidad;
  double precioUnitario;

  // Facturación
  String? codigoProducto;
  String? codigoBarras;
  String? tipoImpuesto; // "IVA" | "INC" | "Exento"
  double porcentajeImpuesto;
  double valorImpuesto;
  double porcentajeDescuento;
  double valorDescuento;
  String? notas;

  ItemCotizacion({
    this.id,
    required this.productoId,
    this.productoNombre,
    this.cantidad = 1,
    this.precioUnitario = 0.0,
    this.codigoProducto,
    this.codigoBarras,
    this.tipoImpuesto,
    this.porcentajeImpuesto = 0.0,
    this.valorImpuesto = 0.0,
    this.porcentajeDescuento = 0.0,
    this.valorDescuento = 0.0,
    this.notas,
  });

  // Getters calculados
  double get subtotal => cantidad * precioUnitario;
  double get valorTotal => subtotal + valorImpuesto - valorDescuento;

  // Métodos de cálculo
  void calcularValorImpuesto() {
    valorImpuesto = (subtotal * porcentajeImpuesto) / 100.0;
  }

  void calcularValorDescuento() {
    if (porcentajeDescuento > 0) {
      valorDescuento = (subtotal * porcentajeDescuento) / 100.0;
    }
  }

  // Actualizar cantidad y recalcular
  void actualizarCantidad(int nuevaCantidad) {
    cantidad = nuevaCantidad;
    calcularValorImpuesto();
    calcularValorDescuento();
  }

  // Actualizar precio y recalcular
  void actualizarPrecio(double nuevoPrecio) {
    precioUnitario = nuevoPrecio;
    calcularValorImpuesto();
    calcularValorDescuento();
  }

  // Actualizar porcentaje de impuesto y recalcular
  void actualizarPorcentajeImpuesto(double nuevoPorcentaje) {
    porcentajeImpuesto = nuevoPorcentaje;
    calcularValorImpuesto();
  }

  // Actualizar porcentaje de descuento y recalcular
  void actualizarPorcentajeDescuento(double nuevoPorcentaje) {
    porcentajeDescuento = nuevoPorcentaje;
    calcularValorDescuento();
  }

  // fromJson
  factory ItemCotizacion.fromJson(Map<String, dynamic> json) {
    return ItemCotizacion(
      id: json['id'],
      productoId: json['productoId'] ?? '',
      productoNombre: json['productoNombre'],
      cantidad: (json['cantidad'] ?? 1) is int
          ? json['cantidad']
          : (json['cantidad'] as num).toInt(),
      precioUnitario: (json['precioUnitario'] ?? 0.0).toDouble(),
      codigoProducto: json['codigoProducto'],
      codigoBarras: json['codigoBarras'],
      tipoImpuesto: json['tipoImpuesto'],
      porcentajeImpuesto: (json['porcentajeImpuesto'] ?? 0.0).toDouble(),
      valorImpuesto: (json['valorImpuesto'] ?? 0.0).toDouble(),
      porcentajeDescuento: (json['porcentajeDescuento'] ?? 0.0).toDouble(),
      valorDescuento: (json['valorDescuento'] ?? 0.0).toDouble(),
      notas: json['notas'],
    );
  }

  // toJson
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'productoId': productoId,
      if (productoNombre != null) 'productoNombre': productoNombre,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'subtotal': subtotal,
      if (codigoProducto != null) 'codigoProducto': codigoProducto,
      if (codigoBarras != null) 'codigoBarras': codigoBarras,
      if (tipoImpuesto != null) 'tipoImpuesto': tipoImpuesto,
      'porcentajeImpuesto': porcentajeImpuesto,
      'valorImpuesto': valorImpuesto,
      'porcentajeDescuento': porcentajeDescuento,
      'valorDescuento': valorDescuento,
      'valorTotal': valorTotal,
      if (notas != null) 'notas': notas,
    };
  }

  // copyWith
  ItemCotizacion copyWith({
    String? id,
    String? productoId,
    String? productoNombre,
    int? cantidad,
    double? precioUnitario,
    String? codigoProducto,
    String? codigoBarras,
    String? tipoImpuesto,
    double? porcentajeImpuesto,
    double? valorImpuesto,
    double? porcentajeDescuento,
    double? valorDescuento,
    String? notas,
  }) {
    return ItemCotizacion(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      productoNombre: productoNombre ?? this.productoNombre,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      codigoProducto: codigoProducto ?? this.codigoProducto,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      tipoImpuesto: tipoImpuesto ?? this.tipoImpuesto,
      porcentajeImpuesto: porcentajeImpuesto ?? this.porcentajeImpuesto,
      valorImpuesto: valorImpuesto ?? this.valorImpuesto,
      porcentajeDescuento: porcentajeDescuento ?? this.porcentajeDescuento,
      valorDescuento: valorDescuento ?? this.valorDescuento,
      notas: notas ?? this.notas,
    );
  }

  @override
  String toString() =>
      'ItemCotizacion(id: $id, producto: $productoNombre, cantidad: $cantidad, total: ${valorTotal.toStringAsFixed(2)})';
}
