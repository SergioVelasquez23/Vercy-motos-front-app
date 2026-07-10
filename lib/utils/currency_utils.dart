import 'package:flutter/services.dart';
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

  /// Formatea un valor con puntos de miles y, si tiene parte decimal, un
  /// último punto como separador decimal — el mismo formato que produce
  /// [MilesInputFormatter] mientras el usuario escribe. Pensado para
  /// pre-cargar un TextEditingController que usa ese formatter (así el
  /// valor ya se ve con puntos desde que aparece, no solo cuando el
  /// usuario empieza a teclear). Ejemplo: 42016.81 -> "42.016.81".
  static String formatForMilesInput(double value, {int decimalDigits = 2}) {
    final texto = value.toStringAsFixed(decimalDigits);
    final partes = texto.split('.');
    final entero = partes[0].replaceFirst('-', '');
    final esNegativo = partes[0].startsWith('-');
    final decimal = decimalDigits > 0 && partes.length > 1 ? partes[1] : null;

    final buffer = StringBuffer();
    final n = entero.length;
    for (int i = 0; i < n; i++) {
      if (i > 0 && (n - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(entero[i]);
    }

    final agrupado = buffer.toString();
    final signo = esNegativo ? '-' : '';
    return decimal != null ? '$signo$agrupado.$decimal' : '$signo$agrupado';
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

  /// Convierte texto ya producido por [MilesInputFormatter] (con puntos de
  /// miles y, si tiene, un último punto como separador decimal) de vuelta a
  /// double. Ejemplo: "1.234.567" -> 1234567.0, "42.016.81" -> 42016.81.
  static double parseDecimal(String text) {
    if (text.isEmpty) return 0.0;
    final lastDot = text.lastIndexOf('.');
    if (lastDot == -1) {
      return double.tryParse(text) ?? 0.0;
    }
    final parteEntera = text.substring(0, lastDot).replaceAll('.', '');
    final parteDecimal = text.substring(lastDot + 1);
    final normalizado = parteDecimal.isEmpty ? parteEntera : '$parteEntera.$parteDecimal';
    return double.tryParse(normalizado) ?? 0.0;
  }

  /// Formatea un valor como porcentaje del total
  /// Ejemplo: formatPercentageOf(250, 1000) -> "25.0%"
  static String formatPercentageOf(double value, double total) {
    return formatPercentage(calculatePercentage(value, total) / 100);
  }
}

/// [TextInputFormatter] que agrega puntos de miles en vivo mientras el
/// usuario escribe en un campo de precio/monto (ej. escribir "1000000"
/// se ve "1.000.000" a medida que se teclea).
///
/// Si [decimalDigits] > 0, el ÚLTIMO punto que el usuario escriba se trata
/// como separador decimal (ej. "42016.81"); los puntos anteriores a ese se
/// interpretan como agrupación de miles y se descartan antes de reagrupar.
/// Si [decimalDigits] es 0 (default), todo punto es de miles.
///
/// El cursor siempre queda al final del texto tras cada tecla — es una
/// simplificación deliberada: la alternativa (recalcular la posición exacta
/// del cursor cuando se insertan/quitan puntos) es mucho más propensa a
/// errores, y para campos de precio casi siempre se escribe de corrido.
///
/// IMPORTANTE: al usar este formatter, el valor numérico real ya NO se
/// puede leer con `double.tryParse(controller.text)` directo, porque el
/// texto ahora trae puntos. Usar `CurrencyUtils.parse(controller.text)`
/// (solo miles, decimalDigits=0) o `CurrencyUtils.parseDecimal(controller.text)`
/// (con decimal, decimalDigits>0) para recuperarlo.
class MilesInputFormatter extends TextInputFormatter {
  final int decimalDigits;

  const MilesInputFormatter({this.decimalDigits = 0});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    String digitsOnly;
    String? decimalPart;

    if (decimalDigits > 0 && text.contains('.')) {
      final lastDot = text.lastIndexOf('.');
      final afterLastDot = text.substring(lastDot + 1);
      final decimalValido = RegExp('^\\d{0,$decimalDigits}\$').hasMatch(afterLastDot);
      if (decimalValido) {
        digitsOnly = text.substring(0, lastDot).replaceAll(RegExp(r'[^\d]'), '');
        decimalPart = afterLastDot;
      } else {
        digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
      }
    } else {
      digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    }

    if (digitsOnly.isEmpty && (decimalPart == null || decimalPart.isEmpty)) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final grupoMiles = _agruparMiles(digitsOnly);
    final formatted = decimalPart != null ? '$grupoMiles.$decimalPart' : grupoMiles;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _agruparMiles(String digits) {
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    final n = digits.length;
    for (int i = 0; i < n; i++) {
      if (i > 0 && (n - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
