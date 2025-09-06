import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ingreso_caja.dart';
import '../config/api_config.dart';

class IngresoCajaService {
  String get _baseUrl => ApiConfig.instance.baseUrl;

  Future<List<IngresoCaja>> obtenerTodos() async {
    final resp = await http.get(Uri.parse('$_baseUrl/api/ingresos-caja'));
    if (resp.statusCode == 200) {
      final List data = json.decode(resp.body);
      return data.map((e) => IngresoCaja.fromJson(e)).toList();
    }
    throw Exception('Error al obtener ingresos');
  }

  Future<IngresoCaja> registrarIngreso(IngresoCaja ingreso) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/ingresos-caja'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(ingreso.toJson()),
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return IngresoCaja.fromJson(json.decode(resp.body));
    }
    throw Exception('Error al registrar ingreso');
  }

  Future<void> eliminarIngreso(String id) async {
    final resp = await http.delete(Uri.parse('$_baseUrl/api/ingresos-caja/$id'));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('Error al eliminar ingreso');
    }
  }

  // Obtener ingresos por cuadre de caja - MÉTODO PRINCIPAL PARA LA NUEVA FUNCIONALIDAD
  Future<List<IngresoCaja>> obtenerPorCuadreCaja(String cuadreId) async {
    try {
      print('IngresoCajaService - Obteniendo ingresos para cuadre: $cuadreId');
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/ingresos-caja/por-caja/$cuadreId'),
      );
      
      print('IngresoCajaService - Response status: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        final List data = json.decode(resp.body);
        final ingresos = data.map((e) => IngresoCaja.fromJson(e)).toList();
        
        // Ordenar por fecha descendente (más recientes primero)
        ingresos.sort((a, b) => b.fechaIngreso.compareTo(a.fechaIngreso));
        
        print('IngresoCajaService - Ingresos encontrados: ${ingresos.length}');
        return ingresos;
      } else {
        print('IngresoCajaService - Error: ${resp.statusCode} - ${resp.body}');
        throw Exception('Error al obtener ingresos del cuadre: ${resp.statusCode}');
      }
    } catch (e) {
      print('IngresoCajaService - Exception: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
