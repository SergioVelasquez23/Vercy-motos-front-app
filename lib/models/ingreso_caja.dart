class IngresoCaja {
  final String? id;
  final String? cuadreCajaId;  // ID del cuadre de caja al que pertenece
  final String concepto;
  final double monto;
  final String formaPago;
  final DateTime fechaIngreso;
  final String responsable;
  final String observaciones;

  IngresoCaja({
    this.id,
    this.cuadreCajaId,
    required this.concepto,
    required this.monto,
    required this.formaPago,
    required this.fechaIngreso,
    required this.responsable,
    required this.observaciones,
  });

  factory IngresoCaja.fromJson(Map<String, dynamic> json) => IngresoCaja(
        id: json['_id'] ?? json['id'],
        cuadreCajaId: json['cuadreCajaId'],
        concepto: json['concepto'],
        monto: (json['monto'] as num).toDouble(),
        formaPago: json['formaPago'],
        fechaIngreso: DateTime.parse(json['fechaIngreso']),
        responsable: json['responsable'],
        observaciones: json['observaciones'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (cuadreCajaId != null) 'cuadreCajaId': cuadreCajaId,
        'concepto': concepto,
        'monto': monto,
        'formaPago': formaPago,
        'fechaIngreso': fechaIngreso.toIso8601String(),
        'responsable': responsable,
        'observaciones': observaciones,
      };
}
