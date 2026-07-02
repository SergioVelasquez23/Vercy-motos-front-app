import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';

/// Servicio para backups de inventario y conciliación al cerrar caja.
class BackupInventarioService {
  static final BackupInventarioService _instance =
      BackupInventarioService._internal();
  factory BackupInventarioService() => _instance;
  BackupInventarioService._internal();

  String get baseUrl => ApiConfig.instance.baseUrl;
  final _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _getBinaryHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Lista todos los backups de inventario (más reciente primero).
  Future<List<Map<String, dynamic>>> getHistorial() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventario/backup/historial'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Error ${response.statusCode} al obtener historial de backups');
    } catch (e) {
      appLog('❌ [BackupInventario] Error historial: $e');
      rethrow;
    }
  }

  /// Obtiene el backup de un cuadre de caja específico.
  Future<Map<String, dynamic>?> getBackupByCaja(String cajaId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventario/backup/caja/$cajaId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>?;
      }
      if (response.statusCode == 404) return null;
      throw Exception('Error ${response.statusCode} al obtener backup');
    } catch (e) {
      appLog('❌ [BackupInventario] Error getBackup: $e');
      rethrow;
    }
  }

  /// Calcula y devuelve la conciliación de inventario para un cierre de caja.
  Future<List<Map<String, dynamic>>> getConciliacion(String cajaId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventario/backup/caja/$cajaId/conciliacion'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception('Error ${response.statusCode} al obtener conciliación');
    } catch (e) {
      appLog('❌ [BackupInventario] Error conciliación: $e');
      rethrow;
    }
  }

  /// Descarga el Excel de conciliación para un cierre de caja.
  /// Retorna los bytes del archivo.
  Future<List<int>> descargarExcelConciliacion(String cajaId) async {
    try {
      final headers = await _getBinaryHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventario/backup/caja/$cajaId/excel'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        appLog('✅ [BackupInventario] Excel descargado (${response.bodyBytes.length} bytes)');
        return response.bodyBytes.toList();
      }
      throw Exception('Error ${response.statusCode} al descargar Excel');
    } catch (e) {
      appLog('❌ [BackupInventario] Error descargar Excel: $e');
      rethrow;
    }
  }

  /// Descarga el Excel del último cierre registrado.
  Future<List<int>> descargarExcelUltimoCierre() async {
    try {
      final headers = await _getBinaryHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventario/backup/ultimo/excel'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.bodyBytes.toList();
      }
      throw Exception('Error ${response.statusCode} al descargar Excel del último cierre');
    } catch (e) {
      appLog('❌ [BackupInventario] Error ultimo excel: $e');
      rethrow;
    }
  }

  /// Cuenta cuántos productos tienen discrepancias en la conciliación.
  int contarDiscrepancias(List<Map<String, dynamic>> conciliacion) {
    return conciliacion
        .where((f) => f['estado'] == 'FALTANTE' || f['estado'] == 'SOBRANTE')
        .length;
  }
}
