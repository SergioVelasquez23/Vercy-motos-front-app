import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/resumen_cierre.dart';
import 'cuadre_caja_service.dart';

class ResumenCierreService {
  final ApiConfig _apiConfig = ApiConfig.instance;

  String get baseUrl => '${_apiConfig.baseUrl}/api/cuadres-caja';

  Map<String, String> get headers => _apiConfig.getSecureHeaders();

  Future<ResumenCierre> getResumenCierre(String cuadreId) async {
    try {
      print('📊 Obteniendo resumen de cierre para cuadre: $cuadreId');

      final response = await http
          .get(Uri.parse('$baseUrl/$cuadreId/resumen-cierre'), headers: headers)
          .timeout(Duration(seconds: 30));

      print('📊 Response status: ${response.statusCode}');
      print('📊 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Verificar si la respuesta tiene la estructura esperada
        if (jsonResponse.containsKey('success') &&
            jsonResponse['success'] == false) {
          String errorMessage =
              jsonResponse['message'] ?? 'Error desconocido del servidor';

          // Si es el error específico de Java null pointer, intentar generar resumen manual
          if (errorMessage.contains(
            'Cannot invoke "java.lang.Double.doubleValue()" because the return value of "java.util.Map.get(Object)" is null',
          )) {
            print(
              '🔄 Error de Java detectado, intentando generar resumen manual...',
            );
            return await _generarResumenManual(cuadreId);
          }

          throw Exception(errorMessage);
        }

        if (!jsonResponse.containsKey('data') || jsonResponse['data'] == null) {
          throw Exception(
            'No se encontraron datos en la respuesta del servidor',
          );
        }

        print('📊 Parseando datos del resumen...');
        return ResumenCierre.fromJson(jsonResponse['data']);
      } else {
        // Tratar de obtener el mensaje de error del response body
        String errorMessage = 'Error ${response.statusCode}';
        try {
          final errorBody = json.decode(response.body);
          if (errorBody is Map<String, dynamic> &&
              errorBody.containsKey('message')) {
            String serverMessage = errorBody['message'];

            // Si es el error específico de Java null pointer, intentar generar resumen manual
            if (serverMessage.contains(
              'Cannot invoke "java.lang.Double.doubleValue()" because the return value of "java.util.Map.get(Object)" is null',
            )) {
              print(
                '🔄 Error de Java detectado, intentando generar resumen manual...',
              );
              return await _generarResumenManual(cuadreId);
            }

            errorMessage = serverMessage;
          }
        } catch (e) {
          // Si no se puede parsear el error, usar el mensaje genérico
        }

        throw Exception('Error al obtener resumen de cierre: $errorMessage');
      }
    } on TimeoutException catch (e) {
      print('⏰ Timeout al obtener resumen de cierre: $e');
      throw Exception(
        'La solicitud tardó demasiado tiempo. Por favor, intenta nuevamente.',
      );
    } catch (e) {
      print('❌ Error en getResumenCierre: $e');

      // Si es el error específico de Java, intentar resumen manual
      if (e.toString().contains(
        'Cannot invoke "java.lang.Double.doubleValue()"',
      )) {
        print(
          '🔄 Detectado error Java en catch, intentando generar resumen manual...',
        );
        try {
          return await _generarResumenManual(cuadreId);
        } catch (manualError) {
          print('❌ Error en resumen manual: $manualError');
          // Si también falla el manual, lanzar el error original con mejor mensaje
          throw Exception(
            'Error del servidor: El sistema no puede generar el resumen debido a datos faltantes en la base de datos. '
            'Esto puede ocurrir si no hay transacciones suficientes registradas durante el período del cuadre. '
            'Verifique que se hayan registrado ventas, gastos o movimientos durante la operación de la caja.',
          );
        }
      }

      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error de conexión: $e');
    }
  }

  // Método auxiliar para validar que el cuadre existe antes de generar resumen
  Future<bool> validarCuadreExiste(String cuadreId) async {
    try {
      final response = await http.get(
        Uri.parse('${_apiConfig.baseUrl}/api/cuadres-caja/$cuadreId'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error validando cuadre: $e');
      return false;
    }
  }

  // Método para obtener información básica del cuadre para debugging
  Future<Map<String, dynamic>?> getCuadreInfo(String cuadreId) async {
    try {
      final response = await http.get(
        Uri.parse('${_apiConfig.baseUrl}/api/cuadres-caja/$cuadreId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse;
      }
    } catch (e) {
      print('❌ Error obteniendo info del cuadre: $e');
    }
    return null;
  }

  // Método alternativo para obtener datos básicos sin el resumen complejo
  Future<Map<String, dynamic>?> getResumenBasico(String cuadreId) async {
    try {
      print('📊 Intentando obtener resumen básico para cuadre: $cuadreId');

      // Primero verificar que el cuadre existe
      final cuadreInfo = await getCuadreInfo(cuadreId);
      if (cuadreInfo == null) {
        throw Exception('No se pudo obtener información del cuadre');
      }

      print('📊 Información del cuadre obtenida exitosamente');
      return cuadreInfo;
    } catch (e) {
      print('❌ Error en getResumenBasico: $e');
      rethrow;
    }
  }

  // Método para generar un resumen manual cuando el backend falla
  Future<ResumenCierre> _generarResumenManual(String cuadreId) async {
    try {
      print('🔧 Generando resumen manual para cuadre: $cuadreId');

      // Obtener información básica del cuadre
      final cuadreInfo = await getCuadreInfo(cuadreId);
      if (cuadreInfo == null || cuadreInfo['data'] == null) {
        throw Exception('No se pudo obtener información del cuadre');
      }

      final cuadreData = cuadreInfo['data'] as Map<String, dynamic>;

      // Intentar obtener datos de transferencias del servicio cuadre caja
      double transferenciasEsperadas = 0.0;
      try {
        // Importar el servicio de cuadre caja para obtener transferencias
        final cuadreCajaService = CuadreCajaService();
        final efectivoData = await cuadreCajaService.getEfectivoEsperado();

        transferenciasEsperadas =
            (efectivoData['transferenciasEsperadas'] ??
                    efectivoData['transferenciaEsperada'] ??
                    0)
                .toDouble();

        print(
          '💳 Transferencias obtenidas del servicio: \$${transferenciasEsperadas.toStringAsFixed(2)}',
        );
      } catch (e) {
        print('⚠️ Error al obtener transferencias, usando 0.0: $e');
      }

      // Crear un resumen básico con los datos disponibles
      final resumenData = {
        'cuadreInfo': {
          'id': cuadreData['id'] ?? cuadreId,
          'nombre': cuadreData['nombre'] ?? 'Caja Principal',
          'responsable': cuadreData['responsable'] ?? 'Sistema',
          'fechaApertura':
              cuadreData['fechaApertura'] ?? DateTime.now().toIso8601String(),
          'fechaCierre': cuadreData['fechaCierre'],
          'fondoInicial': cuadreData['fondoInicial'] ?? 0.0,
          'efectivoEsperado': cuadreData['efectivoEsperado'] ?? 0.0,
          'efectivoDeclarado': cuadreData['efectivoDeclarado'] ?? 0.0,
          'estado': cuadreData['cerrada'] == true ? 'cerrada' : 'abierta',
        },
        'resumenVentas': {
          'totalPedidos': 0,
          'detallesPedidos': [],
          'ventasPorFormaPago': {
            'efectivo': cuadreData['efectivoEsperado'] ?? 0.0,
            'transferencia': transferenciasEsperadas,
          },
          'totalVentas':
              (cuadreData['efectivoEsperado'] ?? 0.0) + transferenciasEsperadas,
          'cantidadPorFormaPago': {'efectivo': 0, 'transferencia': 0},
        },
        'movimientosEfectivo': {
          'fondoInicial': cuadreData['fondoInicial'] ?? 0.0,
          'ventasEfectivo': cuadreData['efectivoEsperado'] ?? 0.0,
          'ventasTransferencias': transferenciasEsperadas,
          'totalVentas':
              (cuadreData['efectivoEsperado'] ?? 0.0) + transferenciasEsperadas,
          'totalGastos': 0.0,
          'totalFacturas': 0.0,
          'efectivoFinal':
              (cuadreData['fondoInicial'] ?? 0.0) +
              (cuadreData['efectivoEsperado'] ?? 0.0),
          'diferencia':
              (cuadreData['efectivoDeclarado'] ?? 0.0) -
              (cuadreData['efectivoEsperado'] ?? 0.0),
        },
        'resumenGastos': {
          'totalGastos': 0.0,
          'gastosPorTipo': {},
          'detalleGastos': [],
        },
        'resumenCompras': {
          'totalCompras': 0.0,
          'totalPagado': 0.0,
          'totalPendiente': 0.0,
          'comprasDetalle': [],
        },
        'resumenFinal': {
          'fondoInicial': cuadreData['fondoInicial'] ?? 0.0,
          'totalVentas':
              (cuadreData['efectivoEsperado'] ?? 0.0) + transferenciasEsperadas,
          'totalVentasEfectivo': cuadreData['efectivoEsperado'] ?? 0.0,
          'totalVentasTransferencias': transferenciasEsperadas,
          'totalGastos': 0.0,
          'totalCompras': 0.0,
          'efectivoEsperado': cuadreData['efectivoEsperado'] ?? 0.0,
          'efectivoDeclarado': cuadreData['efectivoDeclarado'] ?? 0.0,
          'diferencia':
              (cuadreData['efectivoDeclarado'] ?? 0.0) -
              (cuadreData['efectivoEsperado'] ?? 0.0),
          'cuadrado':
              ((cuadreData['efectivoDeclarado'] ?? 0.0) -
                      (cuadreData['efectivoEsperado'] ?? 0.0))
                  .abs() <=
              5000,
          'utilidadBruta':
              (cuadreData['efectivoEsperado'] ?? 0.0) + transferenciasEsperadas,
        },
        'observaciones':
            cuadreData['observaciones'] ??
            'Resumen generado manualmente debido a error del servidor',
        'metadata': {
          'generadoManualmente': true,
          'razon': 'Error en backend - datos financieros faltantes',
          'timestamp': DateTime.now().toIso8601String(),
          'transferenciasIncluidas': transferenciasEsperadas > 0,
        },
      };

      print(
        '✅ Resumen manual generado exitosamente con transferencias: \$${transferenciasEsperadas.toStringAsFixed(2)}',
      );
      return ResumenCierre.fromJson(resumenData);
    } catch (e) {
      print('❌ Error en generación manual: $e');
      rethrow;
    }
  }
}
