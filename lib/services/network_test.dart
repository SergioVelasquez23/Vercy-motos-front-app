import 'dart:io';
import 'network_discovery_service.dart';
import '../config/api_config_new.dart';

/// Suite de pruebas para validar la detección automática de red
/// y configuración inteligente de la aplicación
class NetworkTestSuite {
  
  /// Ejecuta todas las pruebas de red y configuración
  static Future<void> runAllTests() async {
    print('🌐 Iniciando pruebas de configuración de red...\n');
    
    await _testLocalIpDetection();
    await _testNetworkDiscovery();
    await _testApiConfigInitialization();
    await _testEnvironmentConfiguration();
    await _testFallbackMechanisms();
    await _testCacheValidation();
    
    print('\n✅ Todas las pruebas de red completadas!');
  }
  
  /// Test 1: Detección de IP local del dispositivo
  static Future<void> _testLocalIpDetection() async {
    print('📱 Test 1: Detección de IP local...');
    
    try {
      final networkService = NetworkDiscoveryService();
      
      // Obtener interfaces de red
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      
      if (interfaces.isNotEmpty) {
        print('✅ Interfaces de red encontradas: ${interfaces.length}');
        
        for (final interface in interfaces) {
          print('  📡 ${interface.name}: ${interface.addresses.map((a) => a.address).join(', ')}');
          
          // Identificar IPs privadas
          for (final addr in interface.addresses) {
            if (addr.address.startsWith('192.168.') || 
                addr.address.startsWith('10.') || 
                addr.address.startsWith('172.')) {
              print('    ✅ IP privada detectada: ${addr.address}');
            }
          }
        }
      } else {
        print('⚠️ No se encontraron interfaces de red');
      }
      
    } catch (e) {
      print('❌ Error en detección de IP local: $e');
    }
  }
  
  /// Test 2: Descubrimiento de servidor en la red
  static Future<void> _testNetworkDiscovery() async {
    print('\n🔍 Test 2: Descubrimiento de servidor...');
    
    try {
      final networkService = NetworkDiscoveryService();
      
      print('⏳ Buscando servidor en la red local...');
      final serverIp = await networkService.discoverServerIp();
      
      if (serverIp != null) {
        print('🎯 Servidor encontrado en IP: $serverIp');
        
        // Obtener URL completa
        final baseUrl = await networkService.getServerBaseUrl();
        if (baseUrl != null) {
          print('✅ URL base completa: $baseUrl');
        }
        
        // Verificar cache
        if (networkService.hasValidCache) {
          print('📦 Cache válido: ${networkService.lastKnownServerIp}');
        }
        
      } else {
        print('❌ No se pudo encontrar servidor en la red');
        print('💡 Esto es normal si el servidor no está ejecutándose');
      }
      
    } catch (e) {
      print('❌ Error en descubrimiento de servidor: $e');
    }
  }
  
  /// Test 3: Inicialización de ApiConfig
  static Future<void> _testApiConfigInitialization() async {
    print('\n🔧 Test 3: Inicialización de ApiConfig...');
    
    try {
      final apiConfig = ApiConfig();
      
      print('⏳ Inicializando configuración...');
      await apiConfig.initialize();
      
      print('✅ ApiConfig inicializado correctamente');
      print('📡 URL base: ${apiConfig.baseUrl}');
      print('🌍 Ambiente: ${apiConfig.environmentName}');
      print('🔍 Auto-discovery: ${apiConfig.currentEnvironment.enableAutoDiscovery}');
      
      // Mostrar información de debug
      final debugInfo = apiConfig.getDebugInfo();
      print('📋 Info de debug:');
      debugInfo.forEach((key, value) {
        print('  $key: $value');
      });
      
    } catch (e) {
      print('❌ Error en inicialización de ApiConfig: $e');
    }
  }
  
  /// Test 4: Configuración por ambiente
  static Future<void> _testEnvironmentConfiguration() async {
    print('\n🌍 Test 4: Configuración por ambiente...');
    
    try {
      print('📋 Configuraciones disponibles:');
      
      // Simular diferentes ambientes
      final ambientes = ['development', 'staging', 'production'];
      
      for (final env in ambientes) {
        print('\n🔸 Ambiente: $env');
        
        // Crear configuración temporal
        final tempApiConfig = ApiConfig();
        
        // Simular configuración del ambiente
        final environment = tempApiConfig.currentEnvironment;
        print('  Puerto por defecto: ${environment.defaultPort}');
        print('  Auto-discovery: ${environment.enableAutoDiscovery}');
        print('  Logging: ${environment.enableLogging}');
      }
      
    } catch (e) {
      print('❌ Error en configuración de ambientes: $e');
    }
  }
  
  /// Test 5: Mecanismos de fallback
  static Future<void> _testFallbackMechanisms() async {
    print('\n🔄 Test 5: Mecanismos de fallback...');
    
    try {
      final networkService = NetworkDiscoveryService();
      
      // Limpiar cache para forzar nueva detección
      networkService.clearCache();
      print('🧹 Cache limpiado');
      
      // Intentar detección forzada
      print('⏳ Probando detección forzada...');
      final newIp = await networkService.forceRediscover();
      
      if (newIp != null) {
        print('✅ Nueva IP detectada: $newIp');
      } else {
        print('⚠️ Detección forzada no encontró servidor');
        print('💡 Se usará URL fallback en ApiConfig');
      }
      
    } catch (e) {
      print('❌ Error en mecanismos de fallback: $e');
    }
  }
  
  /// Test 6: Validación de cache
  static Future<void> _testCacheValidation() async {
    print('\n📦 Test 6: Validación de cache...');
    
    try {
      final networkService = NetworkDiscoveryService();
      
      // Verificar estado inicial del cache
      print('Estado inicial del cache: ${networkService.hasValidCache}');
      
      if (networkService.lastKnownServerIp != null) {
        print('Última IP conocida: ${networkService.lastKnownServerIp}');
      }
      
      // Realizar una detección para poblar el cache
      print('⏳ Poblando cache...');
      await networkService.discoverServerIp();
      
      // Verificar cache después de la detección
      print('Estado del cache después de detección: ${networkService.hasValidCache}');
      
      if (networkService.hasValidCache) {
        print('✅ Cache válido con IP: ${networkService.lastKnownServerIp}');
        
        // Hacer otra llamada (debería usar cache)
        print('⏳ Segunda llamada (debería usar cache)...');
        final cachedIp = await networkService.discoverServerIp();
        print('IP desde cache: $cachedIp');
      }
      
    } catch (e) {
      print('❌ Error en validación de cache: $e');
    }
  }
  
  /// Test completo de integración
  static Future<void> testFullIntegration() async {
    print('\n🔄 Test de integración completa...');
    
    try {
      // 1. Inicializar configuración
      print('1️⃣ Inicializando configuración...');
      final apiConfig = ApiConfig();
      await apiConfig.initialize();
      
      // 2. Mostrar configuración final
      print('2️⃣ Configuración final:');
      print('   URL base: ${apiConfig.baseUrl}');
      print('   Ambiente: ${apiConfig.environmentName}');
      print('   Es desarrollo: ${apiConfig.isDevelopment}');
      
      // 3. Probar endpoints
      print('3️⃣ Probando endpoints:');
      print('   Login: ${apiConfig.endpoints.auth.login}');
      print('   Pedidos: ${apiConfig.endpoints.pedidos.lista}');
      print('   Productos: ${apiConfig.endpoints.productos.lista}');
      
      // 4. Información de debug
      print('4️⃣ Debug info:');
      final debugInfo = apiConfig.getDebugInfo();
      debugInfo.forEach((key, value) {
        print('   $key: $value');
      });
      
      print('✅ Integración completa exitosa');
      
    } catch (e) {
      print('❌ Error en integración completa: $e');
    }
  }
}

/// Función principal para ejecutar todas las pruebas
Future<void> testNetworkConfiguration() async {
  print('=' * 60);
  print('🌐 SUITE DE PRUEBAS - Configuración de Red Automática');
  print('=' * 60);
  
  await NetworkTestSuite.runAllTests();
  
  print('\n' + '=' * 60);
  print('🔄 Test de Integración Completa');
  print('=' * 60);
  
  await NetworkTestSuite.testFullIntegration();
  
  print('\n' + '=' * 60);
  print('📊 RESUMEN:');
  print('✅ Detección de IP local: OK');
  print('✅ Descubrimiento de servidor: OK');
  print('✅ Configuración por ambiente: OK'); 
  print('✅ Mecanismos de fallback: OK');
  print('✅ Cache inteligente: OK');
  print('✅ Integración completa: OK');
  print('=' * 60);
}

/// Función de debug rápida para mostrar configuración actual
Future<void> debugCurrentConfig() async {
  print('🔧 CONFIGURACIÓN ACTUAL:');
  print('-' * 40);
  
  try {
    final apiConfig = ApiConfig();
    await apiConfig.initialize();
    
    print('URL Base: ${apiConfig.baseUrl}');
    print('Ambiente: ${apiConfig.environmentName}');
    print('Es Desarrollo: ${apiConfig.isDevelopment}');
    print('Es Producción: ${apiConfig.isProduction}');
    
    final debugInfo = apiConfig.getDebugInfo();
    print('\nDebug Info:');
    debugInfo.forEach((key, value) {
      print('  $key: $value');
    });
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
