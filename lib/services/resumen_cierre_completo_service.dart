import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/resumen_cierre_completo.dart';
import '../config/api_config.dart';

class ResumenCierreCompletoService {
  final String baseUrl = ApiConfig.instance.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    return {
      'Content-Type': 'application/json',
      // TODO: Add authentication token if needed
      // 'Authorization': 'Bearer $token',
    };
  }

  /// Obtiene el resumen completo de cierre para un cuadre específico
  Future<ResumenCierreCompleto> getResumenCierre(String cuadreId) async {
    try {
      print('� Obteniendo resumen de cierre para cuadre: $cuadreId');

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/cuadres-caja/$cuadreId/resumen-cierre'),
            headers: await _getHeaders(),
          )
          .timeout(Duration(seconds: 30)); // Agregar timeout

      print('� Response status: ${response.statusCode}');
      print(
        '� Response body (primeros 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body}',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Verificar que la respuesta sea exitosa
        if (jsonData['success'] == true && jsonData['data'] != null) {
          print('📊 Parseando datos del resumen...');

          // Debug the sales data from API response
          var data = jsonData['data'];
          if (data != null && data is Map) {
            // 🔍 Debug: Verificar estructura de cuadre
            print('🔍 Estado del cuadre: ${data['cuadreInfo']?['estado']}');
            print('🔍 Cerrada: ${data['cuadreInfo']?['cerrada']}');
            
            var movimientos = data['movimientosEfectivo'];
            if (movimientos != null && movimientos is Map) {
              print('💰 Datos de ventas en API response:');
              print('  - ventasEfectivo: ${movimientos['ventasEfectivo']}');
              print(
                '  - ventasTransferencia: ${movimientos['ventasTransferencia']}',
              );
              print('  - efectivo (alternativo): ${movimientos['efectivo']}');
              print(
                '  - transferencia (alternativo): ${movimientos['transferencia']}',
              );
            }
            
            // 🔍 Debug: Verificar estructura de gastos
            if (data['resumenGastos'] != null) {
              print(
                '💰 Estructura resumenGastos: ${data['resumenGastos'].keys}',
              );
              if (data['resumenGastos']['detallesGastos'] != null) {
                final detalles = data['resumenGastos']['detallesGastos'];
                print('📋 Tipo detallesGastos: ${detalles.runtimeType}');
                if (detalles is List && detalles.isNotEmpty) {
                  print('🧾 Primer elemento: ${detalles.first}');
                  print(
                    '🧾 Tipo primer elemento: ${detalles.first.runtimeType}',
                  );
                }
              }
            }
          }

          ResumenCierreCompleto resumen;
          try {
            resumen = ResumenCierreCompleto.fromJson(jsonData['data']);
            print('✅ Resumen parseado correctamente');
          } catch (parseError) {
            print('❌ Error parseando resumen: $parseError');
            print('📊 Datos que causaron el error: ${jsonData['data']}');
            rethrow;
          }

          // Obtener datos complementarios del cuadre completo
          print('🔍 Obteniendo información completa del cuadre...');
          try {
            final cuadreCompleto = await _obtenerCuadreCompleto(cuadreId);
            if (cuadreCompleto != null) {
              print(
                '📊 Datos del cuadre completo obtenidos, integrando información...',
              );
              print('🔍 Estructura de cuadreCompleto: ${cuadreCompleto.keys}');
              if (cuadreCompleto['resumenGastos'] != null) {
                print(
                  '💰 resumenGastos keys: ${cuadreCompleto['resumenGastos'].keys}',
                );
                if (cuadreCompleto['resumenGastos']['detallesGastos'] != null) {
                  final detalles =
                      cuadreCompleto['resumenGastos']['detallesGastos'] as List;
                  print('📋 Cantidad de gastos: ${detalles.length}');
                  if (detalles.isNotEmpty) {
                    print('🧾 Primer gasto: ${detalles.first}');
                    print(
                      '🧾 Tipo del primer gasto: ${detalles.first.runtimeType}',
                    );
                  }
                }
              }
              return _integrarDatosCuadreCompleto(resumen, cuadreCompleto);
            }
          } catch (e, stackTrace) {
            print('⚠️ Error obteniendo cuadre completo: $e');
            print('📚 Stack trace: $stackTrace');
          }

          print(
            '💰 Ingresos reales cargados: ${resumen.movimientosEfectivo.totalIngresosCaja}',
          );
          return resumen;
        } else {
          throw Exception(
            'Error en la respuesta del servidor: ${jsonData['message'] ?? 'Respuesta inválida'}',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException catch (e) {
      print('⏰ Timeout al obtener resumen de cierre: $e');
      throw Exception(
        'La solicitud tardó demasiado tiempo. Por favor, intenta nuevamente.',
      );
    } catch (e) {
      print('❌ Error obteniendo resumen de cierre: $e');
      rethrow;
    }
  }

  /// Obtiene el cuadre completo con datos complementarios
  Future<Map<String, dynamic>?> _obtenerCuadreCompleto(String cuadreId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/cuadres-caja/$cuadreId/resumen-cierre'),
            headers: await _getHeaders(),
          )
          .timeout(Duration(seconds: 30));

      print('📡 Respuesta cuadre completo - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          print(
            '✅ Información completa del cuadre recibida: ${jsonData['data']}',
          );
          return jsonData['data'];
        }
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo cuadre completo: $e');
      return null;
    }
  }

  /// Integra los datos del cuadre completo con el resumen de cierre
  ResumenCierreCompleto _integrarDatosCuadreCompleto(
    ResumenCierreCompleto resumen,
    Map<String, dynamic> cuadreCompleto,
  ) {
    try {
      // Extraer datos relevantes del cuadre completo
      final ventasEfectivo = _safeToDouble(cuadreCompleto['ventasEfectivo']);
      final totalVentas = _safeToDouble(cuadreCompleto['totalVentas']);
      final ventasTransferencias = _safeToDouble(
        cuadreCompleto['ventasTransferencias'],
      );

      print(
        '🔄 Integrando datos: ventasEfectivo=$ventasEfectivo, totalVentas=$totalVentas',
      );

      // Crear nuevos objetos con los datos corregidos
      final resumenFinalCorregido = ResumenFinalCompleto(
        totalGastos: resumen.resumenFinal.totalGastos,
        efectivoEsperado: _safeToDouble(cuadreCompleto['debeTener']) > 0
            ? _safeToDouble(cuadreCompleto['debeTener'])
            : resumen.resumenFinal.efectivoEsperado,
        fondoInicial: resumen.resumenFinal.fondoInicial,
        gastosDirectos: resumen.resumenFinal.gastosDirectos,
        ventasEfectivo: ventasEfectivo, // Usar datos del cuadre completo
        totalVentas: totalVentas, // Usar datos del cuadre completo
        gastosEfectivo: resumen.resumenFinal.gastosEfectivo,
        utilidadBruta: resumen.resumenFinal.utilidadBruta,
        totalCompras: resumen.resumenFinal.totalCompras,
        comprasEfectivo: resumen.resumenFinal.comprasEfectivo,
        facturasPagadasDesdeCaja: resumen.resumenFinal.facturasPagadasDesdeCaja,
      );

      final movimientosCorregidos = MovimientosEfectivoCompleto(
        ingresosTransferencia:
            resumen.movimientosEfectivo.ingresosTransferencia,
        ingresosEfectivo: resumen.movimientosEfectivo.ingresosEfectivo,
        ingresosPorFormaPago: resumen.movimientosEfectivo.ingresosPorFormaPago,
        gastosTransferencia: resumen.movimientosEfectivo.gastosTransferencia,
        transferenciaEsperada:
            ventasTransferencias, // Usar datos del cuadre completo
        efectivoEsperado: resumen.movimientosEfectivo.efectivoEsperado,
        totalIngresosCaja: resumen.movimientosEfectivo.totalIngresosCaja,
        fondoInicial: resumen.movimientosEfectivo.fondoInicial,
        comprasTransferencia: resumen.movimientosEfectivo.comprasTransferencia,
        ventasEfectivo: ventasEfectivo, // Usar datos del cuadre completo
        ventasTransferencia:
            ventasTransferencias, // Usar datos del cuadre completo
        gastosEfectivo: resumen.movimientosEfectivo.gastosEfectivo,
        comprasEfectivo: resumen.movimientosEfectivo.comprasEfectivo,
      );

      return ResumenCierreCompleto(
        resumenFinal: resumenFinalCorregido,
        movimientosEfectivo: movimientosCorregidos,
        resumenGastos: resumen.resumenGastos,
        resumenCompras: resumen.resumenCompras,
        cuadreInfo: resumen.cuadreInfo,
        resumenVentas: resumen.resumenVentas,
      );
    } catch (e) {
      print('❌ Error integrando datos del cuadre completo: $e');
      return resumen; // Devolver el resumen original si hay error
    }
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Obtiene el resumen completo de cierre con manejo de errores mejorado
  Future<ResumenCierreCompleto?> getResumenCierreSafe(String cuadreId) async {
    try {
      return await getResumenCierre(cuadreId);
    } catch (e) {
      print('⚠️ Error al obtener resumen de cierre (modo seguro): $e');
      return null;
    }
  }
}
