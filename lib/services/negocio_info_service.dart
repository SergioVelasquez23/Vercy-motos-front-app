import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../models/negocio_info.dart';
import 'image_service.dart';

class NegocioInfoService {
  final ApiConfig _apiConfig = ApiConfig();
  final ImageService _imageService = ImageService();

  /// Obtener información del negocio
  Future<NegocioInfo?> getNegocioInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${_apiConfig.baseUrl}/api/negocio'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

        

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'] ?? body;
          
        return NegocioInfo.fromJson(data);
      } else if (response.statusCode == 404) {
          
        return null;
      } else {
        print(
          '❌ Error al obtener información del negocio: ${response.statusCode}',
        );
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
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });

      // Actualizar fecha de modificación
      final negocioToSave = negocioInfo.copyWith(
        fechaActualizacion: DateTime.now(),
      );

      request.body = json.encode(negocioToSave.toJson());

        

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
          
        return NegocioInfo.fromJson(data);
      } else {
        print(
          '❌ Error al guardar información del negocio: ${response.statusCode}',
        );
          
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
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

        

      if (response.statusCode == 200 || response.statusCode == 204) {
          
      } else {
        print(
          '❌ Error al eliminar información del negocio: ${response.statusCode}',
        );
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
