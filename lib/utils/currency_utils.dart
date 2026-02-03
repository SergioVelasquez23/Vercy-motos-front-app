import 'package:intl/intl.dart';

/// Utilidades específicas para formateo de moneda en el sistema de cartera
class CurrencyUtils {
  static final NumberFormat _formatter = NumberFormat('#,##0', 'es_CO');

  /// Formatea un valor como moneda con símbolo de peso
  /// Ejemplo: 55500 -> $55.500
  static String format(double value) {
    return '\$${_formatter.format(value)}';
  }

  /// Formatea un valor como moneda sin símbolo
  /// Ejemplo: 55500 -> 55.500
  static String formatPlain(double value) {
    return _formatter.format(value);
  }

  /// Formatea un valor de manera abreviada para espacios pequeños
  /// Ejemplo: 55500 -> $55.5K, 1500000 -> $1.5M
  static String formatShort(double value) {
    if (value == 0) return '\$0';

    final absValue = value.abs();
    final isNegative = value < 0;

    String formatted;

    if (absValue >= 1000000000) {
      formatted = '${(absValue / 1000000000).toStringAsFixed(1)}B';
    } else if (absValue >= 1000000) {
      formatted = '${(absValue / 1000000).toStringAsFixed(1)}M';
    } else if (absValue >= 1000) {
      formatted = '${(absValue / 1000).toStringAsFixed(1)}K';
    } else {
      formatted = absValue.toStringAsFixed(0);
    }

    // Limpiar .0 innecesarios
    formatted = formatted.replaceAll('.0', '');

    return '${isNegative ? '-' : ''}\$$formatted';
  }

  /// Convierte un string de moneda a double
  /// Ejemplo: "$55.500" -> 55500.0
  static double parse(String value) {
    if (value.isEmpty) return 0.0;

    // Limpiar el string
    String clean = value
        .replaceAll('\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();

    return double.tryParse(clean) ?? 0.0;
  }

  /// Valida si un string representa una moneda válida
  static bool isValidCurrency(String value) {
    try {
      parse(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Formatea un porcentaje
  /// Ejemplo: 0.05 -> 5.0%
  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  /// Calcula el porcentaje de un valor sobre un total
  /// Ejemplo: calculatePercentage(250, 1000) -> 25.0
  static double calculatePercentage(double value, double total) {
    if (total == 0) return 0.0;
    return (value / total) * 100;
  }

  /// Formatea un valor como porcentaje del total
  /// Ejemplo: formatPercentageOf(250, 1000) -> "25.0%"
  static String formatPercentageOf(double value, double total) {
    return formatPercentage(calculatePercentage(value, total) / 100);
  }
}
