import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import '../models/ingreso_caja.dart';
import '../config/api_config.dart';
import '../utils/api_error.dart';
import '../utils/token_storage.dart';
import 'cuadre_caja_service.dart';

/// Servicio para gestionar ingresos adicionales de caja
///
/// Integra con el backend que automáticamente incluye ingresos
/// en el resumen de cierre cuando se cierra la caja
class IngresoCajaService {
  static final IngresoCajaService _instance = IngresoCajaService._internal();
  factory IngresoCajaService() => _instance;
  IngresoCajaService._internal();

  String get _baseUrl => ApiConfig.instance.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await readJwtToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<IngresoCaja>> obtenerTodos() async {
    try {
      final headers = await _getHeaders();
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/ingresos-caja'),
        headers: headers,
      );

        

      if (resp.statusCode == 200) {
        final responseData = json.decode(resp.body);

        // Manejar respuesta con wrapper de éxito
        List<dynamic> ingresosData;
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true &&
            responseData['data'] != null) {
          ingresosData = responseData['data'] as List<dynamic>;
        } else if (responseData is List<dynamic>) {
          ingresosData = responseData;
        } else {
          throw Exception('Formato de respuesta inválido');
        }

        return ingresosData.map((e) => IngresoCaja.fromJson(e)).toList();
      }
      throwBackendError(resp.body, resp.statusCode, prefix: 'Error al obtener ingresos');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener ingresos');
    }
  }

  Future<IngresoCaja> registrarIngreso(IngresoCaja ingreso) async {
    try {
      // OBTENER CUADRE ACTIVO AUTOMÁTICAMENTE
      final cuadreService = CuadreCajaService();
      final cuadres = await cuadreService.getAllCuadres();
      final cuadreActivo = cuadres
          .where((c) => c.estado == 'pendiente')
          .firstOrNull;

      // Crear una copia del ingreso con el cuadreCajaId asignado
      final ingresoConCuadre = IngresoCaja(
        id: ingreso.id,
        cuadreCajaId: cuadreActivo?.id, // Asignar cuadre activo
        concepto: ingreso.concepto,
        monto: ingreso.monto,
        formaPago: ingreso.formaPago,
        fechaIngreso: ingreso.fechaIngreso,
        responsable: ingreso.responsable,
        observaciones: ingreso.observaciones,
      );

        

      final headers = await _getHeaders();
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/ingresos-caja'),
        headers: headers,
        body: json.encode(ingresoConCuadre.toJson()),
      );

        
        

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final responseData = json.decode(resp.body);

        // Manejar respuesta con wrapper de éxito
        Map<String, dynamic> ingresoData;
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true &&
            responseData['data'] != null) {
          ingresoData = responseData['data'] as Map<String, dynamic>;
        } else if (responseData is Map<String, dynamic>) {
          ingresoData = responseData;
        } else {
          throw Exception('Formato de respuesta inválido');
        }

          
        return IngresoCaja.fromJson(ingresoData);
      }
      throwBackendError(resp.body, resp.statusCode, prefix: 'Error al registrar ingreso');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al registrar ingreso');
    }
  }

  Future<void> eliminarIngreso(String id) async {
    try {
      final headers = await _getHeaders();
      final resp = await http.delete(
        Uri.parse('$_baseUrl/api/ingresos-caja/$id'),
        headers: headers,
      );

        

      if (resp.statusCode != 200 && resp.statusCode != 204) {
        throwBackendError(resp.body, resp.statusCode, prefix: 'Error al eliminar ingreso');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al eliminar ingreso');
    }
  }

  // Obtener ingresos por cuadre de caja - MÉTODO PRINCIPAL PARA LA NUEVA FUNCIONALIDAD
  Future<List<IngresoCaja>> obtenerPorCuadreCaja(String cuadreId) async {
    try {
        
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/ingresos-caja/por-caja/$cuadreId'),
      );

        

      if (resp.statusCode == 200) {
        final List data = json.decode(resp.body);
        final ingresos = data.map((e) => IngresoCaja.fromJson(e)).toList();

        // Ordenar por fecha descendente (más recientes primero)
        ingresos.sort((a, b) => b.fechaIngreso.compareTo(a.fechaIngreso));

          
        return ingresos;
      } else {
        throwBackendError(resp.body, resp.statusCode, prefix: 'Error al obtener ingresos del cuadre');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener ingresos del cuadre');
    }
  }
}
