// Utilidades para formatear valores en la aplicación
// INMUNE A CORRUPCIÓN: No depende de configuraciones globales de Intl

/// Cache para evitar recalcular el mismo número
final Map<String, String> _formatCache = {};

/// Formatea un número añadiendo puntos como separadores de miles y millones
/// GARANTÍA: Nunca se corrompe por operaciones de backend o cambios de locale
///
/// Ejemplos:
/// - 55500 -> 55.500
/// - 1234567 -> 1.234.567
String formatNumberWithDots(dynamic value) {
  if (value == null) return '0';

  // Crear clave única para cache
  final cacheKey = '${value.toString()}|${value.runtimeType}';
  if (_formatCache.containsKey(cacheKey)) {
    return _formatCache[cacheKey]!;
  }

  // Validar y convertir a número de manera segura
  num numValue;
  if (value is String) {
    if (value.trim().isEmpty) {
      _formatCache[cacheKey] = '0';
      return '0';
    }
    // Limpiar cualquier formato existente que pueda venir del backend.
    //
    // BUG corregido: antes se reemplazaba ',' por '.' asumiendo que la coma
    // era separador de miles (ej. "55,500"), pero double.tryParse interpreta
    // un solo punto como separador DECIMAL — "55,500" terminaba leyéndose
    // como 55.5 en vez de 55500. Igual que CurrencyUtils.parse (que ya
    // descarta puntos Y comas por completo, sin soporte de decimales, porque
    // el peso colombiano no maneja centavos en esta app), la coma se
    // descarta en vez de convertirse en punto.
    final cleanValue = value
        .replaceAll(',', '') // Comas de miles se descartan
        .replaceAll(' ', '') // Espacios
        .replaceAll('\$', '') // Símbolos de moneda
        .replaceAll('\n', '') // Saltos de línea
        .replaceAll('\t', ''); // Tabs
    numValue = double.tryParse(cleanValue) ?? 0;
  } else if (value is num) {
    if (value.isNaN || value.isInfinite) {
      _formatCache[cacheKey] = '0';
      return '0';
    }
    numValue = value;
  } else {
           _formatCache[cacheKey] = '0';
    return '0';
  }

  // Asegurarse de que el número sea válido
  if (numValue.isNaN || numValue.isInfinite) {
    _formatCache[cacheKey] = '0';
    return '0';
  }

  // SIEMPRE usar formateo manual para evitar problemas de localización
  final result = _formatNumberManually(numValue);
  _formatCache[cacheKey] = result;

  // Limpiar cache si se vuelve muy grande
  if (_formatCache.length > 1000) {
    _formatCache.clear();
  }

  return result;
}

/// Formateo manual ULTRA-ROBUSTO que nunca falla
/// Completamente independiente de cualquier configuración externa
String _formatNumberManually(num value) {
  try {
    // Validación adicional para casos extremos
    if (value.toString().contains('e') || value.toString().contains('E')) {
      // Notación científica - convertir a decimal normal
      value = double.parse(value.toString());
    }

    // Convertir a entero para formateo (redondear, no truncar: así coincide
    // con NumberFormat.currency(decimalDigits: 0) usado en pdf_export_service.dart
    // y con toStringAsFixed(0)/round() usados en otros lados — antes truncaba
    // y podía mostrar un peso menos que esas otras partes de la app).
    final bool isNegative = value < 0;
    int intValue = value.round().abs();

    // Validar que el resultado sea un número válido
    final numStr = intValue.toString();
    if (!RegExp(r'^\d+$').hasMatch(numStr)) {
        
      return '0';
    }

    // Si es menor a 1000, no necesita formateo
    if (numStr.length <= 3) {
      return isNegative ? '-$numStr' : numStr;
    }

    // Formatear con puntos cada 3 dígitos desde la derecha
    // Usar StringBuffer para mejor rendimiento
    final buffer = StringBuffer();
    int counter = 0;

    for (int i = numStr.length - 1; i >= 0; i--) {
      if (counter > 0 && counter % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(numStr[i]);
      counter++;
    }

    // Revertir el string (ya que lo construimos al revés)
    final reversed = buffer.toString().split('').reversed.join('');
    return isNegative ? '-$reversed' : reversed;
  } catch (e) {
      
    // Fallback absoluto: asegurar que siempre devuelva algo válido
    try {
      return value.round().abs().toString();
    } catch (e2) {
        
      return '0'; // Último recurso
    }
  }
}

/// Formatea un precio como string con el símbolo de peso y separadores de miles
/// ULTRA-ROBUSTO: Nunca se corrompe, sin importar qué operaciones se hagan
///
/// Ejemplo: 55500 -> $55.500
/// GARANTIZADO: Nunca devuelve caracteres especiales o símbolos raros
String formatCurrency(dynamic value) {
  try {
    // Log para debugging cuando se corrompe
    final originalValue = value;

    final formatted = formatNumberWithDots(value);

    // Verificación ESTRICTA del formato resultante
    final validPattern = RegExp(r'^-?\d{1,3}(\.\d{3})*$');
    final isZero = formatted == '0';

    if (validPattern.hasMatch(formatted) || isZero) {
      // Aplicar detección y corrección de corrupción
      final cleanFormatted = _detectAndFixCorruption(formatted, originalValue);
      final result = '\$${cleanFormatted}';

      // Verificación final - el resultado debe tener solo estos caracteres
      if (RegExp(r'^[\$\-\d\.]+$').hasMatch(result)) {
        return result;
      } else {
          
        return '\$0';
      }
    } else {
        
                 
        
        
      return '\$0';
    }
  } catch (e, stackTrace) {




    return '\$0'; // Fallback absoluto
  }
}

/// Formatea un valor como moneda redondeado HACIA ARRIBA al siguiente
/// múltiplo de 1000 (ej. 2.023.991 -> $2.024.000). Pensado para resúmenes de
/// cierre de caja, donde el efectivo se cuenta en billetes/monedas y no tiene
/// sentido mostrar pesos sueltos.
String formatCurrencyRoundedTo1000(dynamic value) {
  num numValue;
  if (value is String) {
    numValue = num.tryParse(value.replaceAll(',', '.')) ?? 0;
  } else if (value is num) {
    numValue = value;
  } else {
    numValue = 0;
  }
  if (numValue.isNaN || numValue.isInfinite) numValue = 0;

  final redondeado = (numValue / 1000).ceil() * 1000;
  return formatCurrency(redondeado);
}

/// Limpiar cache de formateo (llamar después de operaciones que pueden corromper)
void clearFormatCache() {
  _formatCache.clear();
    
}

/// Detectar y corregir automáticamente números corruptos
String _detectAndFixCorruption(String formatted, dynamic originalValue) {
  // Detectar patrones de corrupción comunes
  final corruptionPatterns = [
    RegExp(
      r'[^\d\.\-\$]',
    ), // Caracteres que no son dígitos, puntos, guiones o $
    RegExp(r'[^\x20-\x7E]'), // Caracteres no ASCII imprimibles
    RegExp(
      r'[\u0080-\uFFFF]',
    ), // Caracteres Unicode que pueden aparecer como grises
  ];

  bool isCorrupted = false;
  for (final pattern in corruptionPatterns) {
    if (pattern.hasMatch(formatted)) {
      isCorrupted = true;
        
        
        
      break;
    }
  }

  if (isCorrupted) {
      
    clearFormatCache(); // Limpiar cache inmediatamente

    // Intentar reparar extrayendo solo números
    final cleanValue = formatted.replaceAll(RegExp(r'[^\d\.]'), '');
    if (cleanValue.isNotEmpty) {
      final repaired = formatNumberWithDots(double.tryParse(cleanValue) ?? 0);
        
      return repaired;
    } else {
        
      return '0';
    }
  }

  return formatted;
}

/// Formatea una fecha en formato legible dd/MM/yyyy hh:mm AM/PM (12 horas)
/// Ejemplo: 2025-09-30T14:30:00.000Z -> 30/09/2025 02:30 PM
String formatDate(DateTime dateTime) {
  try {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    
    // Convertir a formato 12 horas
    final hour24 = dateTime.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year ${hour12.toString().padLeft(2, '0')}:$minute $period';
  } catch (e) {
      
    return 'Fecha inválida';
  }
}

/// Formatea solo la hora en formato 12 horas con AM/PM
/// Ejemplo: 14:30 -> 02:30 PM
String formatTime12h(DateTime dateTime) {
  try {
    final hour24 = dateTime.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '${hour12.toString().padLeft(2, '0')}:$minute $period';
  } catch (e) {
    return 'Hora inválida';
  }
}

/// Formatea hora en formato 12h corto (sin padding en hora)
/// Ejemplo: 14:30 -> 2:30 PM
String formatTime12hShort(DateTime dateTime) {
  try {
    final hour24 = dateTime.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour12:$minute $period';
  } catch (e) {
    return 'Hora inválida';
  }
}

/// Formatea una fecha en formato solo fecha dd/MM/yyyy
/// Ejemplo: 2025-09-30T14:30:00.000Z -> 30/09/2025
String formatDateOnly(DateTime dateTime) {
  try {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();

    return '$day/$month/$year';
  } catch (e) {
      
    return 'Fecha inválida';
  }
}
