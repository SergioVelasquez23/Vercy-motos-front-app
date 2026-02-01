import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/endpoints_config.dart';
import '../models/factura_electronica_dian.dart';
import '../models/configuracion_dian.dart';

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
  ConfiguracionDian? _configuracionDianCache;

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

        

      final response = await http.post(
        Uri.parse(
          '${_endpoints.currentBaseUrl}/api/configuracion/facturacion/emisor',
        ),
        headers: headers,
        body: json.encode(emisor.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
          
        _emisorCache = emisor;
        return true;
      } else {
          
          
        return false;
      }
    } catch (e) {
        
      return false;
    }
  }

  /// Obtiene la configuración del emisor desde MongoDB
  Future<EmisorDian?> obtenerEmisor() async {
    // Devolver cache si existe
    if (_emisorCache != null) {
        
      return _emisorCache;
    }

    try {
      final headers = await _getHeaders();

        

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
            
          return _emisorCache;
        }
      } else if (response.statusCode == 404) {
          
        return null;
      } else {
          
        return null;
      }
    } catch (e) {
        
    }

    return null;
  }

  /// Guarda la configuración de autorización DIAN en MongoDB
  Future<bool> guardarAutorizacion(Map<String, dynamic> autorizacion) async {
    try {
      final headers = await _getHeaders();

        

      final response = await http.post(
        Uri.parse(
          '${_endpoints.currentBaseUrl}/api/configuracion/facturacion/autorizacion',
        ),
        headers: headers,
        body: json.encode(autorizacion),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
          
        _autorizacionCache = autorizacion;
        return true;
      } else {
          
          
        return false;
      }
    } catch (e) {
        
      return false;
    }
  }

  /// Obtiene la configuración de autorización DIAN desde MongoDB
  Future<Map<String, dynamic>?> obtenerAutorizacion() async {
    // Devolver cache si existe
    if (_autorizacionCache != null) {
        
      return _autorizacionCache;
    }

    try {
      final headers = await _getHeaders();

        

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
            
          return _autorizacionCache;
        }
      } else if (response.statusCode == 404) {
          
        return null;
      } else {
          
        return null;
      }
    } catch (e) {
        
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

        

      final response = await http.get(
        Uri.parse('${_endpoints.currentBaseUrl}/api/facturacion/consecutivo'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final consecutivo = responseData['numeroFactura'];
          
        return consecutivo;
      } else {
          
        return null;
      }
    } catch (e) {
        
    }

    return null;
  }

  /// Incrementa el contador de consecutivos después de generar una factura
  Future<bool> incrementarConsecutivo({String? prefijo}) async {
    try {
      final headers = await _getHeaders();

        

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
          
        return true;
      } else {
          
        return false;
      }
    } catch (e) {
        
      return false;
    }
  }

  /// Guarda una factura electrónica generada en MongoDB
  Future<Map<String, dynamic>?> guardarFactura(
    Map<String, dynamic> facturaData,
  ) async {
    try {
      final headers = await _getHeaders();

        

      final response = await http.post(
        Uri.parse('${_endpoints.currentBaseUrl}/api/facturas-electronicas'),
        headers: headers,
        body: json.encode(facturaData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
          
        final responseData = json.decode(response.body);
        return responseData['factura'];
      } else {
          
          
        return null;
      }
    } catch (e) {
        
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

        

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final facturas = List<Map<String, dynamic>>.from(
          json.decode(response.body),
        );
          
        return facturas;
      } else {
          
        return [];
      }
    } catch (e) {
        
    }

    return [];
  }

  /// Limpia el cache en memoria
  void limpiarCache() {
    _emisorCache = null;
    _autorizacionCache = null;
    _configuracionDianCache = null;
      
  }

  // ===== MÉTODOS PARA CONFIGURACIÓN DIAN COMPLETA =====

  /// Guarda la configuración completa de DIAN en MongoDB
  Future<bool> guardarConfiguracionDian(ConfiguracionDian config) async {
    try {
      final headers = await _getHeaders();

        

      final response = await http.post(
        Uri.parse(
          '${_endpoints.currentBaseUrl}/api/configuracion/facturacion/dian',
        ),
        headers: headers,
        body: json.encode(config.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
          
        _configuracionDianCache = config;
        return true;
      } else {
          
          
        return false;
      }
    } catch (e) {
        
      return false;
    }
  }

  /// Obtiene la configuración completa de DIAN desde MongoDB
  Future<ConfiguracionDian?> obtenerConfiguracionDian() async {
    // Devolver cache si existe
    if (_configuracionDianCache != null) {
        
      return _configuracionDianCache;
    }

    try {
      final headers = await _getHeaders();

        

      final response = await http.get(
        Uri.parse(
          '${_endpoints.currentBaseUrl}/api/configuracion/facturacion/dian',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final configData =
              responseData['data']['data'] ?? responseData['data'];
          _configuracionDianCache = ConfiguracionDian.fromJson(configData);
            
          return _configuracionDianCache;
        }
      } else if (response.statusCode == 404) {
          
        return null;
      } else {
          
        return null;
      }
    } catch (e) {
        
    }

    return null;
  }

  /// Actualiza solo el consecutivo actual de facturación
  Future<bool> actualizarConsecutivoActual(String nuevoConsecutivo) async {
    try {
      final headers = await _getHeaders();

        

      final response = await http.patch(
        Uri.parse(
          '${_endpoints.currentBaseUrl}/api/configuracion/facturacion/dian/consecutivo',
        ),
        headers: headers,
        body: json.encode({'iniciarNumeroFacturaDesde': nuevoConsecutivo}),
      );

      if (response.statusCode == 200) {
          

        // Actualizar el cache si existe
        if (_configuracionDianCache != null) {
          _configuracionDianCache = _configuracionDianCache!.copyWith(
            iniciarNumeroFacturaDesde: nuevoConsecutivo,
          );
        }

        return true;
      } else {
          
        return false;
      }
    } catch (e) {
        
      return false;
    }
  }
}

