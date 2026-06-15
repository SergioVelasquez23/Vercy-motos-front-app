import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_error.dart';

/// Modelo para Departamento de Colombia
class Departamento {
  final int id;
  final String name;

  Departamento({required this.id, required this.name});

  factory Departamento.fromJson(Map<String, dynamic> json) {
    return Departamento(id: json['id'] ?? 0, name: json['name'] ?? '');
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Departamento &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Modelo para Municipio/Ciudad de Colombia
class Municipio {
  final int id;
  final String name;
  final int departmentId;

  Municipio({required this.id, required this.name, required this.departmentId});

  factory Municipio.fromJson(Map<String, dynamic> json) {
    return Municipio(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      departmentId: json['departmentId'] ?? 0,
    );
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Municipio && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Servicio para obtener departamentos y municipios de Colombia
/// usando la API pública: https://api-colombia.com
class ColombiaLocationService {
  static const String _baseUrl = 'https://api-colombia.com/api/v1';

  // Cache para evitar llamadas repetidas
  static List<Departamento>? _cachedDepartamentos;
  static final Map<int, List<Municipio>> _cachedMunicipios = {};

  /// Obtener todos los departamentos de Colombia
  Future<List<Departamento>> getDepartamentos() async {
    // Retornar cache si existe
    if (_cachedDepartamentos != null) {
      return _cachedDepartamentos!;
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/Department'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _cachedDepartamentos =
            data.map((json) => Departamento.fromJson(json)).toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        return _cachedDepartamentos!;
      } else {
        throw Exception(
          'Error al obtener departamentos: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Si falla la API, retornar lista hardcodeada como fallback
      return _departamentosFallback();
    }
  }

  /// Obtener municipios/ciudades de un departamento específico
  Future<List<Municipio>> getMunicipios(int departamentoId) async {
    // Retornar cache si existe
    if (_cachedMunicipios.containsKey(departamentoId)) {
      return _cachedMunicipios[departamentoId]!;
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/Department/$departamentoId/cities'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final municipios = data.map((json) => Municipio.fromJson(json)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _cachedMunicipios[departamentoId] = municipios;
        return municipios;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener municipios');
      }
    } catch (e) {
      return [];
    }
  }

  /// Limpiar cache
  static void clearCache() {
    _cachedDepartamentos = null;
    _cachedMunicipios.clear();
  }

  /// Departamentos de fallback en caso de que la API falle
  List<Departamento> _departamentosFallback() {
    final nombres = [
      'Amazonas',
      'Antioquia',
      'Arauca',
      'Atlántico',
      'Bolívar',
      'Boyacá',
      'Caldas',
      'Caquetá',
      'Casanare',
      'Cauca',
      'Cesar',
      'Chocó',
      'Córdoba',
      'Cundinamarca',
      'Guainía',
      'Guaviare',
      'Huila',
      'La Guajira',
      'Magdalena',
      'Meta',
      'Nariño',
      'Norte de Santander',
      'Putumayo',
      'Quindío',
      'Risaralda',
      'San Andrés y Providencia',
      'Santander',
      'Sucre',
      'Tolima',
      'Valle del Cauca',
      'Vaupés',
      'Vichada',
      'Bogotá D.C.',
    ];
    return nombres
        .asMap()
        .entries
        .map((e) => Departamento(id: e.key + 1, name: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
