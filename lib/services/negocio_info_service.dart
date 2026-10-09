import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../models/negocio_info.dart';
import '../utils/api_error.dart';
import 'base_api_service.dart';
import 'image_service.dart';

class NegocioInfoService {
  final ApiConfig _apiConfig = ApiConfig();
  final ImageService _imageService = ImageService();

  // Caché en memoria de getNegocioInfo() — datos casi estáticos (nombre, NIT,
  // logo, resolución DIAN): no hay una pantalla de "editar negocio" que se
  // use seguido, así que un TTL largo es seguro. 9 lugares distintos
  // (Facturación, Facturas, Cotizaciones, impresión, FE/POS, documento
  // soporte...) pedían esto cada uno por su cuenta en cada factura/PDF/
  // impresión — existía un NegocioInfoCache en utils/ con esta misma idea,
  // pero ningún llamador lo usaba (confirmado: todos llaman al service
  // directo). Cachearlo acá, adentro del service, beneficia a los 9 sin
  // tocarlos uno por uno.
  static NegocioInfo? _cache;
  static DateTime? _cacheEn;
  static const _cacheTtl = Duration(minutes: 30);
  static Future<NegocioInfo?>? _cargaEnCurso;

  /// Olvida el caché — llamado tras guardar/borrar la info del negocio.
  static void invalidarCache() {
    _cache = null;
    _cacheEn = null;
  }

  /// Headers con Authorization (Bearer) desde BaseApiService
  Future<Map<String, String>> get _headers async {
    final h = await BaseApiService().getHeaders();
    h['Accept'] = 'application/json';
    return h;
  }

  /// Obtener información del negocio. Cacheada en memoria (ver [_cache]);
  /// pasar [forzar] para saltarse el caché.
  Future<NegocioInfo?> getNegocioInfo({bool forzar = false}) async {
    if (!forzar &&
        _cache != null &&
        _cacheEn != null &&
        DateTime.now().difference(_cacheEn!) < _cacheTtl) {
      return _cache;
    }
    if (!forzar && _cargaEnCurso != null) return _cargaEnCurso;

    final future = _obtenerNegocioInfoDesdeRed();
    _cargaEnCurso = future;
    try {
      return await future;
    } finally {
      _cargaEnCurso = null;
    }
  }

  Future<NegocioInfo?> _obtenerNegocioInfoDesdeRed() async {
    try {
      final response = await http.get(
        Uri.parse('${_apiConfig.baseUrl}/api/negocio'),
        headers: await _headers,
      );



      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'] ?? body;
        debugPrint('=== GET /api/negocio RESPUESTA ===\n${json.encode(data)}\n==================================');
        final info = NegocioInfo.fromJson(data);
        _cache = info;
        _cacheEn = DateTime.now();
        return info;
      } else if (response.statusCode == 404) {

        return null;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener información del negocio');
      }
    } catch (e) {
      // Si falló pero hay un caché vencido, devolver eso antes que nada.
      if (_cache != null) return _cache;
      wrapOrThrow(e, context: 'Error al obtener información del negocio');
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
        invalidarCache();
        return NegocioInfo.fromJson(data as Map<String, dynamic>);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al guardar información del negocio');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al guardar información del negocio');
    }
  }

  /// Subir logo del negocio usando ImageService
  Future<String> uploadLogo(XFile logoFile) async {
    try {
        

      // Usar el ImageService para subir el logo
      final logoUrl = await _imageService.uploadNegocioLogo(logoFile);

        
      return logoUrl;
    } catch (e) {
      wrapOrThrow(e, context: 'Error al subir el logo');
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
        invalidarCache();
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al eliminar información del negocio');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al eliminar información del negocio');
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
