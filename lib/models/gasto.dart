import '../utils/currency_utils.dart';

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
  final bool pagadoDesdeCaja;
  // Desglose cuando formaPago == 'Mixto' (efectivo + transferencia = monto).
  // Solo montoEfectivo afecta el efectivo esperado de caja.
  final double montoEfectivo;
  final double montoTransferencia;

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
    this.pagadoDesdeCaja = false,
    this.montoEfectivo = 0.0,
    this.montoTransferencia = 0.0,
  });

  factory Gasto.fromJson(Map<String, dynamic> json) {
    return Gasto(
      id: json['_id'] ?? json['id'],
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
      pagadoDesdeCaja: json['pagadoDesdeCaja'] ?? false,
      montoEfectivo: (json['montoEfectivo'] ?? 0).toDouble(),
      montoTransferencia: (json['montoTransferencia'] ?? 0).toDouble(),
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
      'pagadoDesdeCaja': pagadoDesdeCaja,
      'montoEfectivo': montoEfectivo,
      'montoTransferencia': montoTransferencia,
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
    bool? pagadoDesdeCaja,
    double? montoEfectivo,
    double? montoTransferencia,
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
      pagadoDesdeCaja: pagadoDesdeCaja ?? this.pagadoDesdeCaja,
      montoEfectivo: montoEfectivo ?? this.montoEfectivo,
      montoTransferencia: montoTransferencia ?? this.montoTransferencia,
    );
  }

  // Getters útiles
  String get montoFormateado => CurrencyUtils.format(monto);
  String get fechaFormateada =>
      '${fechaGasto.day}/${fechaGasto.month}/${fechaGasto.year}';
  bool get tieneFactura => numeroFactura != null && numeroFactura!.isNotEmpty;
  bool get tieneRecibo => numeroRecibo != null && numeroRecibo!.isNotEmpty;
}
