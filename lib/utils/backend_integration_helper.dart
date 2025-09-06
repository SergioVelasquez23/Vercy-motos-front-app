import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/endpoints_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Helper para verificar la integración con el backend y validar endpoints
class BackendIntegrationHelper {
  static final BackendIntegrationHelper _instance = BackendIntegrationHelper._internal();
  factory BackendIntegrationHelper() => _instance;
  BackendIntegrationHelper._internal();

  final EndpointsConfig _endpoints = EndpointsConfig();
  final storage = FlutterSecureStorage();

  /// Obtener headers con autenticación
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Verificar si el backend tiene soporte para generación automática de documentos
  Future<BackendDocumentCapabilities> verificarCapacidadesDocumentos() async {
    print('🔍 Verificando capacidades del backend para documentos automáticos...');
    
    final capabilities = BackendDocumentCapabilities();
    
    try {
      // Verificar endpoint básico de documentos
      capabilities.documentosMesaDisponible = await _verificarEndpoint(
        _endpoints.documentosMesa.base,
        'Documentos Mesa'
      );
      
      // Verificar endpoint de creación
      capabilities.crearDocumentoDisponible = await _verificarEndpoint(
        _endpoints.documentosMesa.crear,
        'Crear Documento'
      );
      
      // Verificar endpoint de pago
      capabilities.pagarDocumentoDisponible = await _verificarEndpoint(
        _endpoints.documentosMesa.pagar('test-id'),
        'Pagar Documento'
      );
      
      // Verificar endpoints de facturas si están disponibles
      capabilities.facturasDisponible = await _verificarEndpoint(
        _endpoints.facturas.base,
        'Facturas'
      );
      
      // Verificar endpoint específico de generar factura desde pedido
      capabilities.facturasDesdePedidoDisponible = await _verificarEndpoint(
        _endpoints.facturas.desdePedido('test-pedido-id'),
        'Factura desde Pedido'
      );
      
      print('📊 Resumen de capacidades del backend:');
      print('  - Documentos Mesa: ${capabilities.documentosMesaDisponible ? "✅" : "❌"}');
      print('  - Crear Documento: ${capabilities.crearDocumentoDisponible ? "✅" : "❌"}');
      print('  - Pagar Documento: ${capabilities.pagarDocumentoDisponible ? "✅" : "❌"}');
      print('  - Facturas: ${capabilities.facturasDisponible ? "✅" : "❌"}');
      print('  - Facturas desde Pedido: ${capabilities.facturasDesdePedidoDisponible ? "✅" : "❌"}');
      
      return capabilities;
      
    } catch (e) {
      print('❌ Error verificando capacidades del backend: $e');
      return capabilities; // Devolver con valores por defecto (false)
    }
  }

  /// Verificar si un endpoint específico está disponible
  Future<bool> _verificarEndpoint(String url, String nombre, {String method = 'GET'}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(url);
      
      // Simplificado: solo usamos GET para verificar disponibilidad
      final response = await http.get(uri, headers: headers).timeout(Duration(seconds: 5));
      
      // Considerar disponible si no es 404 o 405 (método no permitido)
      final disponible = response.statusCode != 404 && response.statusCode != 405;
      
      print('🔗 Endpoint $nombre: ${disponible ? "✅ Disponible" : "❌ No disponible"} (${response.statusCode})');
      
      return disponible;
      
    } catch (e) {
      print('⚠️ Error verificando endpoint $nombre: $e');
      return false;
    }
  }

  /// Detectar el mejor método de generación de documentos según capacidades del backend
  Future<DocumentGenerationStrategy> detectarEstrategiaGeneracion() async {
    final capabilities = await verificarCapacidadesDocumentos();
    
    if (capabilities.facturasDesdePedidoDisponible && capabilities.facturasDisponible) {
      print('🎯 Estrategia recomendada: Usar endpoints de facturas especializados');
      return DocumentGenerationStrategy.facturasDedicadas;
    }
    
    if (capabilities.crearDocumentoDisponible && capabilities.documentosMesaDisponible) {
      print('🎯 Estrategia recomendada: Usar endpoints de documentos mesa');
      return DocumentGenerationStrategy.documentosMesa;
    }
    
    print('🎯 Estrategia de fallback: Generación manual');
    return DocumentGenerationStrategy.manual;
  }

  /// Verificar conectividad básica con el backend
  Future<bool> verificarConectividad() async {
    try {
      print('🌐 Verificando conectividad con el backend...');
      
      final response = await http.get(
        Uri.parse(_endpoints.currentBaseUrl),
        headers: await _getHeaders(),
      ).timeout(Duration(seconds: 10));
      
      final conectado = response.statusCode >= 200 && response.statusCode < 500;
      
      print('🌐 Conectividad: ${conectado ? "✅ Conectado" : "❌ Sin conexión"} (${response.statusCode})');
      
      return conectado;
      
    } catch (e) {
      print('❌ Error de conectividad: $e');
      return false;
    }
  }

  /// Generar reporte completo de integración
  Future<Map<String, dynamic>> generarReporteIntegracion() async {
    print('📋 Generando reporte completo de integración con backend...');
    
    final conectividad = await verificarConectividad();
    final capabilities = await verificarCapacidadesDocumentos();
    final estrategia = await detectarEstrategiaGeneracion();
    
    final reporte = {
      'timestamp': DateTime.now().toIso8601String(),
      'baseUrl': _endpoints.currentBaseUrl,
      'conectividad': conectividad,
      'capacidades': capabilities.toMap(),
      'estrategiaRecomendada': estrategia.toString(),
      'recomendaciones': _generarRecomendaciones(capabilities, estrategia),
    };
    
    print('📋 Reporte de integración generado:');
    print(json.encode(reporte, indent: 2));
    
    return reporte;
  }

  /// Generar recomendaciones basadas en las capacidades detectadas
  List<String> _generarRecomendaciones(BackendDocumentCapabilities capabilities, DocumentGenerationStrategy strategy) {
    final recomendaciones = <String>[];
    
    if (!capabilities.documentosMesaDisponible) {
      recomendaciones.add('Implementar endpoint base de documentos mesa');
    }
    
    if (!capabilities.crearDocumentoDisponible) {
      recomendaciones.add('Implementar endpoint para crear documentos automáticamente');
    }
    
    if (!capabilities.facturasDesdePedidoDisponible && strategy == DocumentGenerationStrategy.facturasDedicadas) {
      recomendaciones.add('Implementar endpoint para generar facturas desde pedido');
    }
    
    if (strategy == DocumentGenerationStrategy.manual) {
      recomendaciones.add('Mejorar endpoints del backend para generación automática');
    }
    
    return recomendaciones;
  }
}

/// Capacidades del backend para manejar documentos
class BackendDocumentCapabilities {
  bool documentosMesaDisponible = false;
  bool crearDocumentoDisponible = false;
  bool pagarDocumentoDisponible = false;
  bool facturasDisponible = false;
  bool facturasDesdePedidoDisponible = false;
  
  Map<String, dynamic> toMap() {
    return {
      'documentosMesa': documentosMesaDisponible,
      'crearDocumento': crearDocumentoDisponible,
      'pagarDocumento': pagarDocumentoDisponible,
      'facturas': facturasDisponible,
      'facturasDesdePedido': facturasDesdePedidoDisponible,
    };
  }
}

/// Estrategias de generación de documentos
enum DocumentGenerationStrategy {
  facturasDedicadas,
  documentosMesa,
  manual,
}
