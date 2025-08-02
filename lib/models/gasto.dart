class Gasto {
  final String? id;
  final String cuadreCajaId;
  final String tipoGastoId;
  final String tipoGastoNombre;
  final String concepto;
  final double monto;
  final String responsable;
  final DateTime fechaGasto;
  final String? numeroRecibo;
  final String? numeroFactura;
  final String? proveedor;
  final String? formaPago;
  final double subtotal;
  final double impuestos;

  Gasto({
    this.id,
    required this.cuadreCajaId,
    required this.tipoGastoId,
    required this.tipoGastoNombre,
    required this.concepto,
    required this.monto,
    required this.responsable,
    required this.fechaGasto,
    this.numeroRecibo,
    this.numeroFactura,
    this.proveedor,
    this.formaPago,
    this.subtotal = 0.0,
    this.impuestos = 0.0,
  });

  factory Gasto.fromJson(Map<String, dynamic> json) {
    return Gasto(
      id: json['_id'],
      cuadreCajaId: json['cuadreCajaId'] ?? '',
      tipoGastoId: json['tipoGastoId'] ?? '',
      tipoGastoNombre: json['tipoGastoNombre'] ?? '',
      concepto: json['concepto'] ?? '',
      monto: (json['monto'] ?? 0).toDouble(),
      responsable: json['responsable'] ?? '',
      fechaGasto: DateTime.parse(
        json['fechaGasto'] ?? DateTime.now().toIso8601String(),
      ),
      numeroRecibo: json['numeroRecibo'],
      numeroFactura: json['numeroFactura'],
      proveedor: json['proveedor'],
      formaPago: json['formaPago'],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      impuestos: (json['impuestos'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'cuadreCajaId': cuadreCajaId,
      'tipoGastoId': tipoGastoId,
      'tipoGastoNombre': tipoGastoNombre,
      'concepto': concepto,
      'monto': monto,
      'responsable': responsable,
      'fechaGasto': fechaGasto.toIso8601String(),
      if (numeroRecibo != null) 'numeroRecibo': numeroRecibo,
      if (numeroFactura != null) 'numeroFactura': numeroFactura,
      if (proveedor != null) 'proveedor': proveedor,
      if (formaPago != null) 'formaPago': formaPago,
      'subtotal': subtotal,
      'impuestos': impuestos,
    };
  }

  Gasto copyWith({
    String? id,
    String? cuadreCajaId,
    String? tipoGastoId,
    String? tipoGastoNombre,
    String? concepto,
    double? monto,
    String? responsable,
    DateTime? fechaGasto,
    String? numeroRecibo,
    String? numeroFactura,
    String? proveedor,
    String? formaPago,
    double? subtotal,
    double? impuestos,
  }) {
    return Gasto(
      id: id ?? this.id,
      cuadreCajaId: cuadreCajaId ?? this.cuadreCajaId,
      tipoGastoId: tipoGastoId ?? this.tipoGastoId,
      tipoGastoNombre: tipoGastoNombre ?? this.tipoGastoNombre,
      concepto: concepto ?? this.concepto,
      monto: monto ?? this.monto,
      responsable: responsable ?? this.responsable,
      fechaGasto: fechaGasto ?? this.fechaGasto,
      numeroRecibo: numeroRecibo ?? this.numeroRecibo,
      numeroFactura: numeroFactura ?? this.numeroFactura,
      proveedor: proveedor ?? this.proveedor,
      formaPago: formaPago ?? this.formaPago,
      subtotal: subtotal ?? this.subtotal,
      impuestos: impuestos ?? this.impuestos,
    );
  }

  // Getters útiles
  String get montoFormateado => '\$ ${monto.toStringAsFixed(0)}';
  String get fechaFormateada =>
      '${fechaGasto.day}/${fechaGasto.month}/${fechaGasto.year}';
  bool get tieneFactura => numeroFactura != null && numeroFactura!.isNotEmpty;
  bool get tieneRecibo => numeroRecibo != null && numeroRecibo!.isNotEmpty;
}
