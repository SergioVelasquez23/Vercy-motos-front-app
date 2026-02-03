import 'dart:io';
import 'network_discovery_service.dart';
import '../config/api_config_new.dart';

/// Suite de pruebas para validar la detección automática de red
/// y configuración inteligente de la aplicación
class NetworkTestSuite {
  /// Ejecuta todas las pruebas de red y configuración
  static Future<void> runAllTests() async {
      

    await _testLocalIpDetection();
    await _testNetworkDiscovery();
    await _testApiConfigInitialization();
    await _testEnvironmentConfiguration();
    await _testFallbackMechanisms();
    await _testCacheValidation();

      
  }

  /// Test 1: Detección de IP local del dispositivo
  static Future<void> _testLocalIpDetection() async {
      

    try {
      final networkService = NetworkDiscoveryService();

      // Obtener interfaces de red
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      if (interfaces.isNotEmpty) {
          

        for (final interface in interfaces) {
             
          // Identificar IPs privadas
          for (final addr in interface.addresses) {
            if (addr.address.startsWith('192.168.') ||
                addr.address.startsWith('10.') ||
                addr.address.startsWith('172.')) {
                
            }
          }
        }
      } else {
          
      }
    } catch (e) {
        
    }
  }

  /// Test 2: Descubrimiento de servidor en la red
  static Future<void> _testNetworkDiscovery() async {
      

    try {
      final networkService = NetworkDiscoveryService();

        
      final serverIp = await networkService.discoverServerIp();

      if (serverIp != null) {
          

        // Obtener URL completa
        final baseUrl = await networkService.getServerBaseUrl();
        if (baseUrl != null) {
            
        }

        // Verificar cache
        if (networkService.hasValidCache) {
            
        }
      } else {
          
          
      }
    } catch (e) {
        
    }
  }

  /// Test 3: Inicialización de ApiConfig
  static Future<void> _testApiConfigInitialization() async {
      

    try {
      final apiConfig = ApiConfig();

        
      await apiConfig.initialize();

        
        
        
         
      // Mostrar información de debug
      final debugInfo = apiConfig.getDebugInfo();
        
      debugInfo.forEach((key, value) {
          
      });
    } catch (e) {
        
    }
  }

  /// Test 4: Configuración por ambiente
  static Future<void> _testEnvironmentConfiguration() async {
      

    try {
        

      // Simular diferentes ambientes
      final ambientes = ['development', 'staging', 'production'];

      for (final env in ambientes) {
          

        // Crear configuración temporal
        final tempApiConfig = ApiConfig();

        // Simular configuración del ambiente
        final environment = tempApiConfig.currentEnvironment;
          
          
          
      }
    } catch (e) {
        
    }
  }

  /// Test 5: Mecanismos de fallback
  static Future<void> _testFallbackMechanisms() async {
      

    try {
      final networkService = NetworkDiscoveryService();

      // Limpiar cache para forzar nueva detección
      networkService.clearCache();
        

      // Intentar detección forzada
        
      final newIp = await networkService.forceRediscover();

      if (newIp != null) {
          
      } else {
          
          
      }
    } catch (e) {
        
    }
  }

  /// Test 6: Validación de cache
  static Future<void> _testCacheValidation() async {
      

    try {
      final networkService = NetworkDiscoveryService();

      // Verificar estado inicial del cache
        

      if (networkService.lastKnownServerIp != null) {
          
      }

      // Realizar una detección para poblar el cache
        
      await networkService.discoverServerIp();

      // Verificar cache después de la detección
         
      if (networkService.hasValidCache) {
          

        // Hacer otra llamada (debería usar cache)
          
        final cachedIp = await networkService.discoverServerIp();
          
      }
    } catch (e) {
        
    }
  }

  /// Test completo de integración
  static Future<void> testFullIntegration() async {
      

    try {
      // 1. Inicializar configuración
        
      final apiConfig = ApiConfig();
      await apiConfig.initialize();

      // 2. Mostrar configuración final
        
        
        
        

      // 3. Probar endpoints
        
        
        
        

      // 4. Información de debug
        
      final debugInfo = apiConfig.getDebugInfo();
      debugInfo.forEach((key, value) {
          
      });

        
    } catch (e) {
        
    }
  }
}

/// Función principal para ejecutar todas las pruebas
Future<void> testNetworkConfiguration() async {
    
    
    

  await NetworkTestSuite.runAllTests();

    
    
    

  await NetworkTestSuite.testFullIntegration();

    
    
    
    
    
    
    
    
    
}

/// Función de debug rápida para mostrar configuración actual
Future<void> debugCurrentConfig() async {
    
    

  try {
    final apiConfig = ApiConfig();
    await apiConfig.initialize();

      
      
      
      

    final debugInfo = apiConfig.getDebugInfo();
      
    debugInfo.forEach((key, value) {
        
    });
  } catch (e) {
      
  }
}
