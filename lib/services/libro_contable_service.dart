import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'base_api_service.dart';

class LibroContableService {
  final String _baseUrl = ApiConfig.instance.baseUrl;
  final BaseApiService _baseService = BaseApiService();

  /// Obtiene el libro contable de un mes: ventas de Facturación Electrónica + POS
  /// separadas de ventas Locales (desglosadas por medio de pago detallado), más
  /// totales de Compras y Gastos del mes.
  Future<Map<String, dynamic>> getLibroContableMensual(int anio, int mes) async {
    try {
      final token = await _baseService.getToken();
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final url = Uri.parse(
        '$_baseUrl/api/reportes/libro-contable?anio=$anio&mes=$mes',
      );

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 120),
            onTimeout: () {
              throw Exception(
                'El servidor tardó demasiado en responder. Intenta con un mes con menos datos.',
              );
            },
          );

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
          'No tienes permisos para ver el libro contable.',
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
      rethrow;
    }
  }
}
