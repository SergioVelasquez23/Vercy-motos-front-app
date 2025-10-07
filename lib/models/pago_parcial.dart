/// Modelo para representar pagos parciales o mixtos de un pedido
///
/// De acuerdo con la guía de integración, este modelo permite
/// manejar múltiples formas de pago para un solo pedido.
class PagoParcial {
  final double monto;
  final String formaPago; // "efectivo", "transferencia", "tarjeta"
  final DateTime fecha;
  final String procesadoPor;

  const PagoParcial({
    required this.monto,
    required this.formaPago,
    required this.fecha,
    required this.procesadoPor,
  });

  /// Factory constructor desde JSON
  factory PagoParcial.fromJson(Map<String, dynamic> json) {
    return PagoParcial(
      monto: (json['monto'] as num).toDouble(),
      formaPago: json['formaPago'] as String,
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'])
          : DateTime.now(),
      procesadoPor: json['procesadoPor'] as String? ?? '',
    );
  }

  /// Serialización a JSON
  Map<String, dynamic> toJson() {
    return {
      'monto': monto,
      'formaPago': formaPago,
      'fecha': fecha.toIso8601String(),
      'procesadoPor': procesadoPor,
    };
  }

  @override
  String toString() =>
      'PagoParcial(monto: $monto, formaPago: $formaPago, fecha: $fecha, procesadoPor: $procesadoPor)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PagoParcial &&
        other.monto == monto &&
        other.formaPago == formaPago &&
        other.fecha == fecha &&
        other.procesadoPor == procesadoPor;
  }

  @override
  int get hashCode =>
      monto.hashCode ^
      formaPago.hashCode ^
      fecha.hashCode ^
      procesadoPor.hashCode;
}
