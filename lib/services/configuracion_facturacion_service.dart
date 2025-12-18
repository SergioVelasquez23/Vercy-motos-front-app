import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/endpoints_config.dart';
import '../models/factura_electronica_dian.dart';

/// Servicio para gestionar la persistencia de configuración de facturación electrónica
///
/// Este servicio maneja la comunicación con el backend para guardar y recuperar
/// la configuración de facturación electrónica DIAN desde MongoDB.
class ConfiguracionFacturacionService {
  static final ConfiguracionFacturacionService _instance =
      ConfiguracionFacturacionService._internal();
  factory ConfiguracionFacturacionService() => _instance;
  ConfiguracionFacturacionService._internal();

  final EndpointsConfig _endpoints = EndpointsConfig();
  final storage = const FlutterSecureStorage();

  // Cache en memoria
  EmisorDian? _emisorCache;
  Map<String, dynamic>? _autorizacionCache;

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Guarda la configuración del emisor en MongoDB
  Future<bool> guardarEmisor(EmisorDian emisor) async {
    try {
      final headers = await _getHeaders();

      print('📝 Guardando configuración de emisor...');

      final response = await http.post(
        Uri.parse(
          '${_endpoints.currentBaseUrl}/api/configuracion/facturacion/emisor',
        ),
        headers: headers,
        body: json.encode(emisor.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Configuración de emisor guardada exitosamente');
        _emisorCache = emisor;
        return true;
      } else {
        print('❌ Error guardando emisor: ${response.statusCode}');
        print('   Respuesta: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error de conexión guardando emisor: $e');
      return false;
    }
  }

  /// Obtiene la configuración del emisor desde MongoDB
  Future<EmisorDian?> obtenerEmisor() async {
    // Devolver cache si existe
    if (_emisorCache != null) {
      print('📦 Devolviendo emisor desde cache');
      return _emisorCache;
    }

    try {
      final headers = await _getHeaders();

      print('🔍 Obteniendo configuración de emisor...');

      final response = await http.get(
        Uri.parse(
          '${_endpoints.currentBaseUrl}/api/configuracion/facturacion/emisor',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final emisorData = responseData['data']['data'];
          _emisorCache = EmisorDian.fromJson(emisorData);
          print('✅ Configuración de emisor obtenida');
          return _emisorCache;
        }
      } else if (response.statusCode == 404) {
        print('ℹ️ No hay configuración de emisor guardada');
        return null;
      } else {
        print('❌ Error obteniendo emisor: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión obteniendo emisor: $e');
    }

    return null;
  }

  /// Guarda la configuración de autorización DIAN en MongoDB
  Future<bool> guardarAutorizacion(Map<String, dynamic> autorizacion) async {
    try {
      final headers = await _getHeaders();

      print('📝 Guardando autorización DIAN...');

      final response = await http.post(
        Uri.parse(
          '${_endpoints.currentBaseUrl}/api/configuracion/facturacion/autorizacion',
        ),
        headers: headers,
        body: json.encode(autorizacion),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Autorización DIAN guardada exitosamente');
        _autorizacionCache = autorizacion;
        return true;
      } else {
        print('❌ Error guardando autorización: ${response.statusCode}');
        print('   Respuesta: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error de conexión guardando autorización: $e');
      return false;
    }
  }

  /// Obtiene la configuración de autorización DIAN desde MongoDB
  Future<Map<String, dynamic>?> obtenerAutorizacion() async {
    // Devolver cache si existe
    if (_autorizacionCache != null) {
      print('📦 Devolviendo autorización desde cache');
      return _autorizacionCache;
    }

    try {
      final headers = await _getHeaders();

      print('🔍 Obteniendo autorización DIAN...');

      final response = await http.get(
        Uri.parse(
          '${_endpoints.currentBaseUrl}/api/configuracion/facturacion/autorizacion',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          _autorizacionCache = responseData['data']['data'];
          print('✅ Autorización DIAN obtenida');
          return _autorizacionCache;
        }
      } else if (response.statusCode == 404) {
        print('ℹ️ No hay autorización DIAN guardada');
        return null;
      } else {
        print('❌ Error obteniendo autorización: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión obteniendo autorización: $e');
    }

    return null;
  }

  /// Obtiene el siguiente número consecutivo disponible
  ///
  /// Este método consulta el backend para obtener el siguiente número
  /// consecutivo que debe usarse para una nueva factura.
  Future<String?> obtenerSiguienteConsecutivo() async {
    try {
      final headers = await _getHeaders();

      print('🔢 Obteniendo siguiente consecutivo...');

      final response = await http.get(
        Uri.parse('${_endpoints.currentBaseUrl}/api/facturacion/consecutivo'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final consecutivo = responseData['numeroFactura'];
        print('✅ Siguiente consecutivo: $consecutivo');
        return consecutivo;
      } else {
        print('❌ Error obteniendo consecutivo: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión obteniendo consecutivo: $e');
    }

    return null;
  }

  /// Incrementa el contador de consecutivos después de generar una factura
  Future<bool> incrementarConsecutivo({String? prefijo}) async {
    try {
      final headers = await _getHeaders();

      print('🔢 Incrementando consecutivo...');

      // Obtener prefijo si no se proporciona
      String prefijoFinal = prefijo ?? 'SETP';
      final autorizacion = await obtenerAutorizacion();
      if (autorizacion != null && autorizacion['prefijo'] != null) {
        prefijoFinal = autorizacion['prefijo'];
      }

      final response = await http.post(
        Uri.parse(
          '${_endpoints.currentBaseUrl}/api/facturacion/consecutivo/incrementar',
        ),
        headers: headers,
        body: json.encode({'prefijo': prefijoFinal}),
      );

      if (response.statusCode == 200) {
        print('✅ Consecutivo incrementado');
        return true;
      } else {
        print('❌ Error incrementando consecutivo: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error de conexión incrementando consecutivo: $e');
      return false;
    }
  }

  /// Guarda una factura electrónica generada en MongoDB
  Future<Map<String, dynamic>?> guardarFactura(
    Map<String, dynamic> facturaData,
  ) async {
    try {
      final headers = await _getHeaders();

      print('💾 Guardando factura electrónica...');

      final response = await http.post(
        Uri.parse('${_endpoints.currentBaseUrl}/api/facturas-electronicas'),
        headers: headers,
        body: json.encode(facturaData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Factura guardada exitosamente');
        final responseData = json.decode(response.body);
        return responseData['factura'];
      } else {
        print('❌ Error guardando factura: ${response.statusCode}');
        print('   Respuesta: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión guardando factura: $e');
      return null;
    }
  }

  /// Obtiene todas las facturas electrónicas
  Future<List<Map<String, dynamic>>> obtenerFacturas({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? estado,
  }) async {
    try {
      final headers = await _getHeaders();

      String url = '${_endpoints.currentBaseUrl}/api/facturas-electronicas';
      final queryParams = <String>[];

      if (fechaInicio != null) {
        queryParams.add('fechaInicio=${fechaInicio.toIso8601String()}');
      }
      if (fechaFin != null) {
        queryParams.add('fechaFin=${fechaFin.toIso8601String()}');
      }
      if (estado != null) {
        queryParams.add('estado=$estado');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      print('📋 Obteniendo facturas electrónicas...');

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final facturas = List<Map<String, dynamic>>.from(
          json.decode(response.body),
        );
        print('✅ ${facturas.length} facturas obtenidas');
        return facturas;
      } else {
        print('❌ Error obteniendo facturas: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error de conexión obteniendo facturas: $e');
    }

    return [];
  }

  /// Limpia el cache en memoria
  void limpiarCache() {
    _emisorCache = null;
    _autorizacionCache = null;
    print('🧹 Cache de configuración limpiado');
  }
}
