import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cliente.dart';
import '../config/endpoints_config.dart';

class ClienteService {
  final EndpointsConfig _config = EndpointsConfig();

  String get baseUrl => '${_config.currentBaseUrl}/api/clientes';

  // CRUD

  /// Obtener todos los clientes
  Future<List<Cliente>> obtenerClientes() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cliente.fromJson(json)).toList();
      }

      throw Exception('Error al obtener clientes: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en obtenerClientes: $e');
      throw Exception('Error al obtener clientes: $e');
    }
  }

  /// Obtener cliente por ID
  Future<Cliente?> obtenerClientePorId(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$id'));

      if (response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      if (response.statusCode == 404) {
        return null;
      }

      throw Exception('Error al obtener cliente: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en obtenerClientePorId: $e');
      return null;
    }
  }

  /// Obtener cliente por documento
  Future<Cliente?> obtenerClientePorDocumento(String doc) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/documento/$doc'));

      if (response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      if (response.statusCode == 404) {
        return null;
      }

      throw Exception(
        'Error al obtener cliente por documento: ${response.statusCode}',
      );
    } catch (e) {
      print('❌ Error en obtenerClientePorDocumento: $e');
      return null;
    }
  }

  /// Crear cliente
  Future<Cliente> crearCliente(Cliente cliente) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cliente.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      throw Exception('Error al crear cliente: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en crearCliente: $e');
      throw Exception('Error al crear cliente: $e');
    }
  }

  /// Actualizar cliente
  Future<Cliente> actualizarCliente(String id, Cliente cliente) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cliente.toJson()),
      );

      if (response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      throw Exception('Error al actualizar cliente: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en actualizarCliente: $e');
      throw Exception('Error al actualizar cliente: $e');
    }
  }

  /// Eliminar cliente (soft delete)
  Future<bool> eliminarCliente(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/$id'));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('❌ Error en eliminarCliente: $e');
      return false;
    }
  }

  // Búsquedas

  /// Buscar clientes por término
  Future<List<Cliente>> buscarClientes(String q) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/buscar?q=${Uri.encodeComponent(q)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cliente.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('❌ Error en buscarClientes: $e');
      return [];
    }
  }

  /// Obtener clientes activos
  Future<List<Cliente>> obtenerClientesActivos() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/estado/activos'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cliente.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('❌ Error en obtenerClientesActivos: $e');
      return [];
    }
  }

  /// Obtener clientes con saldo pendiente
  Future<List<Cliente>> obtenerClientesConSaldo() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/con-saldo'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Cliente.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('❌ Error en obtenerClientesConSaldo: $e');
      return [];
    }
  }

  // Acciones

  /// Bloquear cliente
  Future<Cliente> bloquearCliente(String id, String motivo) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id/bloquear'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'motivo': motivo}),
      );

      if (response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      throw Exception('Error al bloquear cliente: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en bloquearCliente: $e');
      throw Exception('Error al bloquear cliente: $e');
    }
  }

  /// Activar cliente
  Future<Cliente> activarCliente(String id) async {
    try {
      final response = await http.put(Uri.parse('$baseUrl/$id/activar'));

      if (response.statusCode == 200) {
        return Cliente.fromJson(json.decode(response.body));
      }

      throw Exception('Error al activar cliente: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en activarCliente: $e');
      throw Exception('Error al activar cliente: $e');
    }
  }

  /// Verificar cupo de crédito
  Future<Map<String, dynamic>> verificarCupoCredito(
    String id,
    double monto,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$id/verificar-cupo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'montoFactura': monto}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Error al verificar cupo: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en verificarCupoCredito: $e');
      throw Exception('Error al verificar cupo: $e');
    }
  }

  /// Obtener estadísticas de clientes
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/estadisticas'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Error al obtener estadísticas: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en obtenerEstadisticas: $e');
      throw Exception('Error al obtener estadísticas: $e');
    }
  }
}
