import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/gasto.dart';
import '../models/tipo_gasto.dart';
import '../config/api_config.dart';
import '../utils/api_error.dart';
import '../utils/caja_error_handler.dart';
import 'alertas_service.dart';
import '../utils/logger.dart';

class GastoService {
  static final GastoService _instance = GastoService._internal();
  factory GastoService() => _instance;
  GastoService._internal();

  String get baseUrl => ApiConfig.instance.baseUrl;
  final storage = FlutterSecureStorage();
  final AlertasService _alertasService = AlertasService();

  // Headers con autenticación
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Obtener todos los gastos
  Future<List<Gasto>> getAllGastos() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/gastos'),
        headers: headers,
      );

        
        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final gastos = jsonList.map((json) => Gasto.fromJson(json)).toList();

        // Ordenar gastos por fecha descendente (más recientes primero)
        gastos.sort((a, b) => b.fechaGasto.compareTo(a.fechaGasto));

        return gastos;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener gastos');
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener gasto por ID
  Future<Gasto?> getGastoById(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/gastos/$id'),
        headers: headers,
      );

        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return Gasto.fromJson(responseData['data']);
      } else {
        return null;
      }
    } catch (e) {
        
      return null;
    }
  }

  // Obtener gastos por cuadre de caja
  Future<List<Gasto>> getGastosByCuadre(String cuadreId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/gastos/cuadre/$cuadreId'),
        headers: headers,
      );

         
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final gastos = jsonList.map((json) => Gasto.fromJson(json)).toList();

        // Ordenar gastos por fecha descendente (más recientes primero)
        gastos.sort((a, b) => b.fechaGasto.compareTo(a.fechaGasto));

        return gastos;
      } else {
        throw Exception(
          'Error al obtener gastos del cuadre: ${response.statusCode}',
        );
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  /// Crear nuevo gasto
  ///
  /// Retorna el gasto creado o lanza una excepción si hay algún error.
  Future<Gasto> createGasto({
    required String cuadreCajaId,
    required String tipoGastoId,
    required String concepto,
    required double monto,
    required String responsable,
    DateTime? fechaGasto,
    String? numeroRecibo,
    String? numeroFactura,
    String? proveedor,
    String? formaPago,
    double? subtotal,
    double? impuestos,
    bool? pagadoDesdeCaja,
  }) async {
    try {

      final headers = await _getHeaders();
      final body = {
        'cuadreCajaId': cuadreCajaId,
        'tipoGastoId': tipoGastoId,
        'concepto': concepto,
        'monto': monto,
        'responsable': responsable,
        'fechaGasto': (fechaGasto ?? DateTime.now()).toIso8601String(),
        if (numeroRecibo != null) 'numeroRecibo': numeroRecibo,
        if (numeroFactura != null) 'numeroFactura': numeroFactura,
        if (proveedor != null) 'proveedor': proveedor,
        if (formaPago != null) 'formaPago': formaPago,
        if (subtotal != null) 'subtotal': subtotal,
        if (impuestos != null) 'impuestos': impuestos,
        if (pagadoDesdeCaja != null) 'pagadoDesdeCaja': pagadoDesdeCaja,
      };

        

      final response = await http.post(
        Uri.parse('$baseUrl/api/gastos'),
        headers: headers,
        body: json.encode(body),
      );

        
        

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final gasto = Gasto.fromJson(responseData['data']);

        // ⛔ ALERTAS DE TELEGRAM DESHABILITADAS
        // Enviar alerta de Telegram en segundo plano
        // _enviarAlertaGastoTelegram(gasto);

        return gasto;
      } else {
        final error = CajaErrorHandler.procesarRespuesta(response);
        CajaErrorHandler.mostrarError(error);
        throw Exception(error['message'] ?? 'Error al crear gasto');
      }
    } catch (e) {
        
      throw Exception('Error al crear gasto: ${e.toString()}');
    }
  }

  /// Envía alerta de gasto por Telegram en segundo plano
  void _enviarAlertaGastoTelegram(Gasto gasto) {
    // Ejecutar en segundo plano sin bloquear la aplicación
    Future.delayed(Duration.zero, () async {
      try {
        await _alertasService.enviarAlertaGasto(
          tipoGasto: gasto.tipoGastoNombre,
          concepto: gasto.concepto,
          monto: gasto.monto,
          responsable: gasto.responsable,
          formaPago: gasto.formaPago,
          numeroRecibo: gasto.numeroRecibo,
          numeroFactura: gasto.numeroFactura,
          proveedor: gasto.proveedor,
        );
      } catch (e) {
        // Ignorar error de alerta para no afectar la creación del gasto
        appLog('Error al enviar alerta de gasto por Telegram: $e');
      }
    });
  }

  // Actualizar gasto
  Future<Gasto> updateGasto(
    String id, {
    String? cuadreCajaId,
    String? tipoGastoId,
    String? concepto,
    double? monto,
    String? responsable,
    DateTime? fechaGasto,
    String? numeroRecibo,
    String? numeroFactura,
    String? proveedor,
    String? formaPago,
    double? subtotal,
    double? impuestos,
    bool? pagadoDesdeCaja,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        if (cuadreCajaId != null) 'cuadreCajaId': cuadreCajaId,
        if (tipoGastoId != null) 'tipoGastoId': tipoGastoId,
        if (concepto != null) 'concepto': concepto,
        if (monto != null) 'monto': monto,
        if (responsable != null) 'responsable': responsable,
        if (fechaGasto != null) 'fechaGasto': fechaGasto.toIso8601String(),
        if (numeroRecibo != null) 'numeroRecibo': numeroRecibo,
        if (numeroFactura != null) 'numeroFactura': numeroFactura,
        if (proveedor != null) 'proveedor': proveedor,
        if (formaPago != null) 'formaPago': formaPago,
        if (subtotal != null) 'subtotal': subtotal,
        if (impuestos != null) 'impuestos': impuestos,
        if (pagadoDesdeCaja != null) 'pagadoDesdeCaja': pagadoDesdeCaja,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/gastos/$id'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return Gasto.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al actualizar gasto');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Eliminar gasto con reversión automática de dinero
  ///
  /// Si el gasto fue pagado desde caja, el backend automáticamente:
  /// - Revertirá el dinero al cuadre de caja
  /// - Actualizará los totales
  /// - Registrará la acción en el historial
  ///
  /// Retorna un mapa con información sobre la eliminación:
  /// - success: true si fue exitoso, false en caso contrario
  /// - message: mensaje descriptivo
  /// - dineroRevertido: true si se revertió dinero a la caja
  Future<Map<String, dynamic>> deleteGasto(String id) async {
    try {
      final headers = await _getHeaders();

      // Obtener información del gasto antes de eliminarlo
      final gastoInfo = await getGastoById(id);
      final pagadoDesdeCaja = gastoInfo?.pagadoDesdeCaja ?? false;
      final monto = gastoInfo?.monto ?? 0.0;

        
        
      if (pagadoDesdeCaja) {
          
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/gastos/$id'),
        headers: headers,
      );

        
        

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Preparar respuesta exitosa
        Map<String, dynamic> result = {
          'success': true,
          'message': 'Gasto eliminado correctamente',
          'dineroRevertido': pagadoDesdeCaja,
          'montoRevertido': pagadoDesdeCaja ? monto : 0.0,
        };

        // Intentar obtener más información de la respuesta si está disponible
        try {
          if (response.body.isNotEmpty) {
            final responseData = json.decode(response.body);
            if (responseData is Map<String, dynamic>) {
              if (responseData['message'] != null) {
                result['message'] = responseData['message'];
              }
              if (responseData['dineroRevertido'] != null) {
                result['dineroRevertido'] = responseData['dineroRevertido'];
              }
              if (responseData['detalles'] != null) {
                result['detalles'] = responseData['detalles'];
              }
            }
          }
        } catch (_) {
          // Si no se puede parsear la respuesta, usar los valores por defecto
        }

        if (result['dineroRevertido'] == true) {
            
        }

        return result;
      } else {
        final error = CajaErrorHandler.procesarRespuesta(response);
        CajaErrorHandler.mostrarError(error);
        return {
          'success': false,
          'message': error['message'] ?? 'Error al eliminar gasto',
          'errorType': error['errorType'] ?? 'unknown',
          'dineroRevertido': false,
        };
      }
    } catch (e) {
        
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'errorType': 'connection',
        'dineroRevertido': false,
      };
    }
  }

  // Obtener gastos por fechas
  Future<List<Gasto>> getGastosByDateRange(
    DateTime inicio,
    DateTime fin,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/gastos/fechas?inicio=${inicio.toIso8601String()}&fin=${fin.toIso8601String()}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        return jsonList.map((json) => Gasto.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener gastos por fechas: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener todos los tipos de gasto
  Future<List<TipoGasto>> getAllTiposGasto() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/tipos-gasto'),
        headers: headers,
      );

        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
          
        List<dynamic> jsonList = responseData['data'] ?? [];
          
        final tipos = jsonList.map((json) => TipoGasto.fromJson(json)).toList();
        return tipos;
      } else {
        throw Exception(
          'Error al obtener tipos de gasto: ${response.statusCode}',
        );
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  // Crear nuevo tipo de gasto
  Future<TipoGasto> createTipoGasto({
    required String nombre,
    String? descripcion,
    bool activo = true,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'nombre': nombre,
        if (descripcion != null) 'descripcion': descripcion,
        'activo': activo,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/tipos-gasto'),
        headers: headers,
        body: json.encode(body),
      );

        

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return TipoGasto.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al crear tipo de gasto');
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  // Actualizar tipo de gasto
  Future<TipoGasto> updateTipoGasto(
    String id, {
    String? nombre,
    String? descripcion,
    bool? activo,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};

      if (nombre != null) body['nombre'] = nombre;
      if (descripcion != null) body['descripcion'] = descripcion;
      if (activo != null) body['activo'] = activo;

      final response = await http.put(
        Uri.parse('$baseUrl/api/tipos-gasto/$id'),
        headers: headers,
        body: json.encode(body),
      );

        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return TipoGasto.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Error al actualizar tipo de gasto',
        );
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  // Eliminar tipo de gasto
  Future<bool> deleteTipoGasto(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/tipos-gasto/$id'),
        headers: headers,
      );

        

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Error al eliminar tipo de gasto',
        );
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }
}
