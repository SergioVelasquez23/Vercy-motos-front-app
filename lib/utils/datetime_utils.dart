/// Utilidades para manejo seguro de fechas
///
/// Esta clase proporciona métodos para parsear fechas de forma segura,
/// evitando errores de formato que pueden causar crashes en producción.
library;

class DateTimeUtils {
  /// Hora actual de Colombia (UTC-5 todo el año, sin horario de verano).
  ///
  /// Usar en vez de `DateTime.now()` para fechas que se guardan o se muestran
  /// al usuario (ej. fecha/hora de un pedido o factura), ya que `DateTime.now()`
  /// depende de la zona horaria configurada en el dispositivo/navegador, que a
  /// veces queda en UTC en vez de la hora real de Bogotá.
  ///
  /// El resultado se devuelve SIN marcar como UTC (isUtc = false) aunque el
  /// cálculo interno pase por `.toUtc()`. Si quedara marcado como UTC,
  /// `toIso8601String()` le agregaría una 'Z' (mintiendo que es UTC real) y
  /// cualquier `.toLocal()` posterior le restaría OTRAS 5 horas al valor,
  /// duplicando el corrimiento y dañando la hora guardada/mostrada.
  static DateTime nowColombia() {
    final colombia = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    return DateTime(
      colombia.year,
      colombia.month,
      colombia.day,
      colombia.hour,
      colombia.minute,
      colombia.second,
      colombia.millisecond,
      colombia.microsecond,
    );
  }

  /// Parsea una fecha de forma segura desde diferentes tipos de datos
  ///
  /// Parámetros:
  /// - [value]: Valor a parsear (String, DateTime, int timestamp, etc.)
  /// - [fallback]: Valor por defecto si el parsing falla (default: DateTime.now())
  ///
  /// Retorna:
  /// - DateTime parseado exitosamente o [fallback] si hay error
  static DateTime safeParse(dynamic value, {DateTime? fallback}) {
    fallback ??= DateTime.now();

    if (value == null) return fallback;

    // Si ya es DateTime, retornarlo
    if (value is DateTime) return value;

    // Si es timestamp (int o double)
    if (value is num) {
      try {
        // Determinar si es timestamp en segundos o milisegundos
        int timestamp = value.toInt();
        if (timestamp < 10000000000) {
          // Timestamp en segundos (menor a 10^10)
          return DateTime.fromMillisecondsSinceEpoch(
            timestamp * 1000,
          ).toLocal();
        } else {
          // Timestamp en milisegundos
          return DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
        }
      } catch (e) {
          
        return fallback;
      }
    }

    // Si es String
    if (value is String) {
      if (value.isEmpty) return fallback;

      try {
        // Intentar parse directo y convertir a local
        return DateTime.parse(value).toLocal();
      } catch (e) {
        try {
          // Intentar con formato ISO extendido
          final cleanedValue = value.replaceAll('Z', '').replaceAll('T', ' ');
          return DateTime.parse(cleanedValue).toLocal();
        } catch (e2) {
          try {
            // Intentar formato de fecha simple (yyyy-MM-dd)
            if (value.contains('-') && value.length >= 10) {
              final datePart = value.substring(0, 10);
              return DateTime.parse('${datePart}T00:00:00.000');
            }
          } catch (e3) {
              
          }
        }
      }
    }

      
    return fallback;
  }

  /// Parsea una fecha de JSON de forma segura
  ///
  /// Parámetros:
  /// - [json]: Map con los datos JSON
  /// - [key]: Clave del campo de fecha
  /// - [fallback]: Valor por defecto si no existe o hay error
  ///
  /// Retorna:
  /// - DateTime? parseado o null si no existe y no hay fallback
  static DateTime? safeParseFromJson(
    Map<String, dynamic> json,
    String key, {
    DateTime? fallback,
  }) {
    if (!json.containsKey(key)) return fallback;

    final value = json[key];
    if (value == null) return fallback;

    return safeParse(value, fallback: fallback);
  }

  /// Convierte DateTime a string ISO seguro para JSON
  ///
  /// Parámetros:
  /// - [dateTime]: Fecha a convertir
  ///
  /// Retorna:
  /// - String en formato ISO8601 o null si dateTime es null
  static String? toIsoString(DateTime? dateTime) {
    if (dateTime == null) return null;

    try {
      return dateTime.toIso8601String();
    } catch (e) {
        
      return DateTime.now().toIso8601String();
    }
  }

  /// Formatea fecha para mostrar al usuario
  ///
  /// Parámetros:
  /// - [dateTime]: Fecha a formatear
  /// - [format]: Formato deseado ('date', 'time', 'datetime', 'short')
  ///
  /// Retorna:
  /// - String formateado o 'N/A' si hay error
  static String formatForDisplay(
    DateTime? dateTime, {
    String format = 'datetime',
  }) {
    if (dateTime == null) return 'N/A';

    try {
      // Convertir a zona horaria local
      final localDateTime = dateTime.toLocal();
      
      // Helper para formato 12 horas
      String formatTime12h(DateTime dt) {
        final hour24 = dt.hour;
        final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
        final period = hour24 >= 12 ? 'PM' : 'AM';
        return '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
      }

      switch (format) {
        case 'date':
          return '${localDateTime.day.toString().padLeft(2, '0')}/${localDateTime.month.toString().padLeft(2, '0')}/${localDateTime.year}';
        case 'time':
          return formatTime12h(localDateTime);
        case 'time24': // Formato 24h para casos específicos
          return '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';
        case 'short':
          final hour24 = localDateTime.hour;
          final hour12 = hour24 == 0
              ? 12
              : (hour24 > 12 ? hour24 - 12 : hour24);
          final period = hour24 >= 12 ? 'PM' : 'AM';
          return '${localDateTime.day}/${localDateTime.month} $hour12:${localDateTime.minute.toString().padLeft(2, '0')} $period';
        case 'datetime':
        default:
          return '${localDateTime.day.toString().padLeft(2, '0')}/${localDateTime.month.toString().padLeft(2, '0')}/${localDateTime.year} ${formatTime12h(localDateTime)}';
      }
    } catch (e) {
        
      return 'Error formato';
    }
  }

  /// Valida si una fecha está en un rango válido
  ///
  /// Parámetros:
  /// - [dateTime]: Fecha a validar
  /// - [minYear]: Año mínimo válido (default: 2000)
  /// - [maxYear]: Año máximo válido (default: año actual + 10)
  ///
  /// Retorna:
  /// - true si la fecha está en el rango válido
  static bool isValidDate(
    DateTime? dateTime, {
    int minYear = 2000,
    int? maxYear,
  }) {
    if (dateTime == null) return false;

    maxYear ??= DateTime.now().year + 10;

    return dateTime.year >= minYear && dateTime.year <= maxYear;
  }
}
