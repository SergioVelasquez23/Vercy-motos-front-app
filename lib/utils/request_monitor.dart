import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RequestMonitor {
  static final RequestMonitor _instance = RequestMonitor._internal();
  factory RequestMonitor() => _instance;
  RequestMonitor._internal();

  static const String _requestCountKey = 'daily_request_count';
  static const String _lastResetDateKey = 'last_reset_date';

  int _requestCount = 0;
  DateTime _lastResetDate = DateTime.now();

  // Inicializar el monitor
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar contador actual
    _requestCount = prefs.getInt(_requestCountKey) ?? 0;

    // Cargar fecha del último reset
    final lastResetString = prefs.getString(_lastResetDateKey);
    if (lastResetString != null) {
      _lastResetDate = DateTime.parse(lastResetString);
    }

    // Resetear si es un nuevo día
    final now = DateTime.now();
    if (!_isSameDay(now, _lastResetDate)) {
      await _resetDailyCount();
    }
  }

  // Registrar una nueva request
  Future<void> logRequest(String endpoint, String method) async {
    _requestCount++;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_requestCountKey, _requestCount);

    // Log detallado (opcional, solo para debugging)
      

    // Mostrar resumen cada 100 requests
    if (_requestCount % 100 == 0) {
        
    }
  }

  // Obtener estadísticas
  RequestStats getStats() {
    final now = DateTime.now();
    final hoursElapsed = now.difference(_getStartOfDay(now)).inHours + 1;
    final avgPerHour = _requestCount / hoursElapsed;

    return RequestStats(
      totalToday: _requestCount,
      averagePerHour: avgPerHour.round(),
      projectedDaily: (avgPerHour * 24).round(),
      projectedMonthly: (avgPerHour * 24 * 30).round(),
    );
  }

  // Resetear contador diario
  Future<void> _resetDailyCount() async {
      

    _requestCount = 0;
    _lastResetDate = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_requestCountKey, 0);
    await prefs.setString(_lastResetDateKey, _lastResetDate.toIso8601String());
  }

  // Verificar si dos fechas son el mismo día
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Obtener inicio del día
  DateTime _getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Exportar estadísticas para análisis
  Future<Map<String, dynamic>> exportStats() async {
    final stats = getStats();
    return {
      'date': DateTime.now().toIso8601String(),
      'total_today': stats.totalToday,
      'avg_per_hour': stats.averagePerHour,
      'projected_daily': stats.projectedDaily,
      'projected_monthly': stats.projectedMonthly,
      'netlify_limit_usage':
          (stats.projectedMonthly / 125000 * 100).toStringAsFixed(2) + '%',
    };
  }
}

class RequestStats {
  final int totalToday;
  final int averagePerHour;
  final int projectedDaily;
  final int projectedMonthly;

  RequestStats({
    required this.totalToday,
    required this.averagePerHour,
    required this.projectedDaily,
    required this.projectedMonthly,
  });

  @override
  String toString() {
    return '''
📊 Estadísticas de Requests:
├── Hoy: $totalToday requests
├── Promedio/hora: $averagePerHour requests  
├── Proyección diaria: $projectedDaily requests
├── Proyección mensual: $projectedMonthly requests
└── Uso de límite Netlify: ${(projectedMonthly / 125000 * 100).toStringAsFixed(1)}%
''';
  }
}
