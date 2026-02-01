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
    // Limpiar cualquier formato existente que pueda venir del backend
    final cleanValue = value
        .replaceAll(',', '.') // Comas por puntos
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
    print(
      '⚠️ ALERTA: Valor no numérico recibido: $value (${value.runtimeType})',
    );
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

    // Convertir a entero para formateo (truncar decimales)
    final bool isNegative = value < 0;
    int intValue = value.truncate().abs();

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
      return value.truncate().abs().toString();
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
        
      print(
        '  - Valor original: $originalValue (${originalValue.runtimeType})',
      );
        
        
        
      return '\$0';
    }
  } catch (e, stackTrace) {
      
      
      
      
    return '\$0'; // Fallback absoluto
  }
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

/// Formatea una fecha en formato legible dd/MM/yyyy HH:mm
/// Ejemplo: 2025-09-30T14:30:00.000Z -> 30/09/2025 14:30
String formatDate(DateTime dateTime) {
  try {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  } catch (e) {
      
    return 'Fecha inválida';
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
