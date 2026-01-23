class ItemGasto {
  final String? concepto; // Descripción del concepto
  final double valor; // Valor base
  final double porcentajeDescuento; // % descuento
  final double valorDescuento; // Calculado
  final String tipoImpuesto; // "IVA", etc.
  final double porcentajeImpuesto; // Tasa %
  final double valorImpuesto; // Calculado
  final double total; // Total del item

  ItemGasto({
    this.concepto,
    this.valor = 0,
    this.porcentajeDescuento = 0,
    this.valorDescuento = 0,
    this.tipoImpuesto = "IVA",
    this.porcentajeImpuesto = 0,
    this.valorImpuesto = 0,
    this.total = 0,
  });

  factory ItemGasto.fromJson(Map<String, dynamic> json) {
    return ItemGasto(
      concepto: json['concepto'],
      valor: (json['valor'] ?? 0).toDouble(),
      porcentajeDescuento: (json['porcentajeDescuento'] ?? 0).toDouble(),
      valorDescuento: (json['valorDescuento'] ?? 0).toDouble(),
      tipoImpuesto: json['tipoImpuesto'] ?? 'IVA',
      porcentajeImpuesto: (json['porcentajeImpuesto'] ?? 0).toDouble(),
      valorImpuesto: (json['valorImpuesto'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'concepto': concepto,
      'valor': valor,
      'porcentajeDescuento': porcentajeDescuento,
      'valorDescuento': valorDescuento,
      'tipoImpuesto': tipoImpuesto,
      'porcentajeImpuesto': porcentajeImpuesto,
      'valorImpuesto': valorImpuesto,
      'total': total,
    };
  }
}
