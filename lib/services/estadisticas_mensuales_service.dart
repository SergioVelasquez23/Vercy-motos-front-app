import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'base_api_service.dart';

class EstadisticasMensualesService {
  final String _baseUrl = ApiConfig.instance.baseUrl;
  final BaseApiService _baseService = BaseApiService();

  /// Exportar todas las estadísticas de un mes específico
  Future<Map<String, dynamic>> exportarEstadisticasMensuales(
    int anio,
    int mes,
  ) async {
    try {
      final token = await _baseService.getToken();
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final url = Uri.parse(
        '$_baseUrl/reportes/exportar-mes?año=$anio&mes=$mes',
      );

      print('INFO: Exportando estadísticas mensuales - $mes/$anio');
      print('INFO: URL completa: $url');

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 120), // Aumentado de 30 a 120 segundos
            onTimeout: () {
              print('ERROR: Timeout al exportar estadísticas mensuales');
              throw Exception(
                'El servidor tardó demasiado en responder. Intenta con un mes con menos datos.',
              );
            },
          );

      print('INFO: Respuesta del servidor: ${response.statusCode}');
      print('INFO: Longitud de respuesta: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          return jsonData['data'] as Map<String, dynamic>;
        } else {
          throw Exception(jsonData['message'] ?? 'Error desconocido');
        }
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Verifica tus credenciales.');
      } else if (response.statusCode == 403) {
        throw Exception(
          'No tienes permisos para exportar estadísticas mensuales.',
        );
      } else if (response.statusCode == 404) {
        throw Exception(
          'Endpoint no encontrado. Verifica la configuración del servidor.',
        );
      } else {
        final errorBody = response.body.isNotEmpty
            ? response.body
            : 'Sin detalles del error';
        throw Exception(
          'Error del servidor (${response.statusCode}): $errorBody',
        );
      }
    } on SocketException {
      throw Exception('Sin conexión a internet. Verifica tu conectividad.');
    } on http.ClientException {
      throw Exception('Error de conexión con el servidor.');
    } on FormatException {
      throw Exception('Error en el formato de respuesta del servidor.');
    } catch (e) {
      print('ERROR: Error en exportarEstadisticasMensuales: $e');
      rethrow;
    }
  }
}
