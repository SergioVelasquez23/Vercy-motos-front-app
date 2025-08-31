// Utilidades para formatear valores en la aplicación
import 'package:intl/intl.dart';

/// Formatea un número añadiendo puntos como separadores de miles y millones
///
/// Ejemplos:
/// - 55500 -> 55.500
/// - 1234567 -> 1.234.567
String formatNumberWithDots(dynamic value) {
  if (value == null) return '0';

  // Convertir a número si es string
  num numValue;
  if (value is String) {
    numValue = double.tryParse(value) ?? 0;
  } else if (value is num) {
    numValue = value;
  } else {
    return value.toString();
  }

  // Usar NumberFormat para formatear correctamente con puntos como separadores de miles
  final formatter = NumberFormat('#,###', 'es_ES');
  String result = formatter.format(numValue);

  // Reemplazar las comas por puntos para el formato deseado
  result = result.replaceAll(',', '.');

  return result;
}

/// Formatea un precio como string con el símbolo de peso y separadores de miles
///
/// Ejemplo: 55500 -> $55.500
String formatCurrency(dynamic value) {
  return '\$${formatNumberWithDots(value)}';
}
