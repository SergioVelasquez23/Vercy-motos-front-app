import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../models/negocio_info.dart';
import 'base_api_service.dart';
import 'image_service.dart';

class NegocioInfoService {
  final ApiConfig _apiConfig = ApiConfig();
  final ImageService _imageService = ImageService();

  /// Headers con Authorization (Bearer) desde BaseApiService
  Future<Map<String, String>> get _headers async {
    final h = await BaseApiService().getHeaders();
    h['Accept'] = 'application/json';
    return h;
  }

  /// Obtener información del negocio
  Future<NegocioInfo?> getNegocioInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${_apiConfig.baseUrl}/api/negocio'),
        headers: await _headers,
      );

        

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'] ?? body;
        debugPrint('=== GET /api/negocio RESPUESTA ===\n${json.encode(data)}\n==================================');
        return NegocioInfo.fromJson(data);
      } else if (response.statusCode == 404) {
          
        return null;
      } else {
                   throw Exception(
          'Error al obtener información del negocio: ${response.statusCode}',
        );
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  /// Crear o actualizar información del negocio
  Future<NegocioInfo> saveNegocioInfo(NegocioInfo negocioInfo) async {
    try {
      final uri = negocioInfo.id != null
          ? Uri.parse('${_apiConfig.baseUrl}/api/negocio/${negocioInfo.id}')
          : Uri.parse('${_apiConfig.baseUrl}/api/negocio');

      final method = negocioInfo.id != null ? 'PUT' : 'POST';

      final request = http.Request(method, uri);
      request.headers.addAll(await _headers);

      // Actualizar fecha de actualización
      final negocioToSave = negocioInfo.copyWith(
        fechaActualizacion: DateTime.now(),
      );

      // Remove null values so PUT doesn't overwrite existing backend data
      final rawMap = negocioToSave.toJson();
      rawMap.removeWhere((_, v) => v == null);
      final bodyJson = json.encode(rawMap);
      print(
        '=== DATOS ENVIADOS AL BACKEND ===\n$bodyJson\n=================================',
      );
      request.body = bodyJson;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = json.decode(response.body);
        // Handle both {"data": {...}} and plain {...} responses
        final data = body is Map && body.containsKey('data') ? body['data'] : body;
        return NegocioInfo.fromJson(data as Map<String, dynamic>);
      } else {
                     
        throw Exception(
          'Error al guardar información del negocio: ${response.statusCode}',
        );
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  /// Subir logo del negocio usando ImageService
  Future<String> uploadLogo(XFile logoFile) async {
    try {
        

      // Usar el ImageService para subir el logo
      final logoUrl = await _imageService.uploadNegocioLogo(logoFile);

        
      return logoUrl;
    } catch (e) {
        
      throw Exception('Error al subir el logo: $e');
    }
  }

  /// Eliminar información del negocio
  Future<void> deleteNegocioInfo(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${_apiConfig.baseUrl}/api/negocio/$id'),
        headers: await _headers,
      );

        

      if (response.statusCode == 200 || response.statusCode == 204) {
          
      } else {
                   throw Exception(
          'Error al eliminar información del negocio: ${response.statusCode}',
        );
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener lista de países (datos estáticos por ahora)
  List<String> getPaises() {
    return [
      'Colombia',
      'Argentina',
      'Brasil',
      'Chile',
      'Ecuador',
      'México',
      'Perú',
      'Uruguay',
      'Venezuela',
    ];
  }

  /// Obtener lista de departamentos colombianos
  List<String> getDepartamentos() {
    return [
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
    ];
  }

  /// Obtener tipos de documento
  List<String> getTiposDocumento() {
    return ['Factura', 'Recibo', 'Nota de Venta', 'Comprobante', 'Ticket'];
  }
}
