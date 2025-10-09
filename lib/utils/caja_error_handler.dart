import 'dart:convert';
import 'package:http/http.dart';

/// Servicio para manejar errores específicos de operaciones de caja
class CajaErrorHandler {
  /// Procesa la respuesta HTTP y maneja errores específicos de caja
  ///
  /// Retorna un mapa con el resultado:
  /// - success: true si la operación fue exitosa, false si hubo un error
  /// - message: mensaje descriptivo del error o éxito
  /// - data: datos adicionales (opcional)
  /// - errorType: tipo de error (opcional)
  static Map<String, dynamic> procesarRespuesta(Response response) {
    // Respuesta exitosa
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final jsonData = json.decode(response.body);
        if (jsonData is Map<String, dynamic>) {
          // Si ya viene en formato de respuesta estándar
          if (jsonData.containsKey('success')) {
            return jsonData;
          }
          // Convertir a formato estándar
          return {
            'success': true,
            'message': 'Operación exitosa',
            'data': jsonData,
          };
        }
        return {
          'success': true,
          'message': 'Operación exitosa',
          'data': jsonData,
        };
      } catch (e) {
        return {'success': true, 'message': 'Operación exitosa'};
      }
    }

    // Procesar errores
    try {
      final jsonError = json.decode(response.body);
      if (jsonError is Map<String, dynamic>) {
        final errorMessage = jsonError['message'] ?? 'Error desconocido';
        final errorType = _identificarTipoError(
          errorMessage,
          response.statusCode,
        );

        // Log para debugging
        print('❌ Error de caja: $errorMessage');
        print('🔍 Tipo de error: $errorType');

        return {
          'success': false,
          'message': errorMessage,
          'errorType': errorType,
          'statusCode': response.statusCode,
          'details': jsonError['details'],
        };
      }
    } catch (e) {
      // Error al parsear el JSON
    }

    // Error genérico
    return {
      'success': false,
      'message': 'Error: ${response.statusCode}',
      'errorType': 'unknown',
      'statusCode': response.statusCode,
    };
  }

  /// Identifica el tipo de error basado en el mensaje y código de estado
  static String _identificarTipoError(String message, int statusCode) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('efectivo') ||
        lowerMessage.contains('caja') && lowerMessage.contains('suficiente')) {
      return 'insufficient_cash';
    }

    if (lowerMessage.contains('cuadre') && lowerMessage.contains('cerrado')) {
      return 'closed_register';
    }

    if (lowerMessage.contains('no existe') || statusCode == 404) {
      return 'not_found';
    }

    if (statusCode == 401 || statusCode == 403) {
      return 'unauthorized';
    }

    if (lowerMessage.contains('validación') || statusCode == 400) {
      return 'validation';
    }

    return 'general';
  }

  /// Muestra un mensaje de error al usuario según el tipo
  static void mostrarError(Map<String, dynamic> error) {
    final mensaje = error['message'] ?? 'Error desconocido';
    final tipo = error['errorType'] ?? 'unknown';

    switch (tipo) {
      case 'insufficient_cash':
        print('ALERTA: Efectivo insuficiente en caja');
        print('INFO: $mensaje');
        print('INFO: Verifica el saldo de caja o utiliza otro medio de pago.');
        break;
      case 'closed_register':
        print('ALERTA: Operación no permitida en caja cerrada');
        print('INFO: $mensaje');
        print('INFO: Debes abrir un nuevo cuadre de caja para continuar.');
        break;
      case 'not_found':
        print('ALERTA: Recurso no encontrado');
        print('INFO: $mensaje');
        break;
      case 'unauthorized':
        print('ALERTA: No autorizado');
        print('INFO: $mensaje');
        print('INFO: Verifica tus credenciales o permisos.');
        break;
      case 'validation':
        print('ALERTA: Error de validación');
        print('INFO: $mensaje');
        break;
      default:
        print('ALERTA: Error en la operación');
        print('INFO: $mensaje');
        break;
    }
  }
}
