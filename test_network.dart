#!/usr/bin/env dart

import 'dart:io';
import 'lib/services/network_test.dart';

/// Script principal para probar la configuración de red
/// 
/// Uso:
///   dart test_network.dart           # Ejecutar todas las pruebas
///   dart test_network.dart --debug   # Solo mostrar configuración actual
///   dart test_network.dart --help    # Mostrar ayuda
///
Future<void> main(List<String> arguments) async {
  // Procesar argumentos
  if (arguments.contains('--help') || arguments.contains('-h')) {
    _showHelp();
    return;
  }
  
  if (arguments.contains('--debug') || arguments.contains('-d')) {
    await debugCurrentConfig();
    return;
  }
  
  print('🚀 Ejecutando pruebas de configuración de red automática...\n');
  
  try {
    // Verificar que estamos en el directorio correcto
    final currentDir = Directory.current.path;
    print('📂 Directorio actual: $currentDir');
    
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      print('❌ Error: No se encontró pubspec.yaml');
      print('💡 Asegúrate de ejecutar este script desde el directorio raíz del proyecto Flutter');
      exit(1);
    }
    
    print('✅ Proyecto Flutter detectado\n');
    
    // Ejecutar todas las pruebas
    await testNetworkConfiguration();
    
    print('\n🎉 ¡Todas las pruebas completadas exitosamente!');
    print('💡 Si alguna prueba falló, verifica que el servidor Spring Boot esté ejecutándose');
    
  } catch (e, stackTrace) {
    print('\n❌ Error durante la ejecución de pruebas:');
    print('   $e');
    
    if (arguments.contains('--verbose') || arguments.contains('-v')) {
      print('\n📋 Stack trace:');
      print('   $stackTrace');
    }
    
    print('\n💡 Consejos para solucionar problemas:');
    print('   • Verifica que el servidor Spring Boot esté ejecutándose');
    print('   • Confirma que estás en la misma red que el servidor');
    print('   • Revisa el archivo .env si existe');
    print('   • Usa --verbose para más detalles del error');
    
    exit(1);
  }
}

/// Mostrar ayuda del comando
void _showHelp() {
  print('''
🌐 Test de Configuración de Red Automática - Sopa y Carbón

DESCRIPCIÓN:
  Este script prueba la detección automática de la IP del servidor backend
  y valida la configuración de endpoints de la aplicación Flutter.

USO:
  dart test_network.dart [OPCIONES]

OPCIONES:
  --help, -h      Mostrar esta ayuda
  --debug, -d     Solo mostrar la configuración actual
  --verbose, -v   Mostrar información detallada de errores

EJEMPLOS:
  dart test_network.dart                    # Ejecutar todas las pruebas
  dart test_network.dart --debug            # Ver configuración actual
  dart test_network.dart --verbose          # Pruebas con información detallada

PRERREQUISITOS:
  • Servidor Spring Boot ejecutándose en la red local
  • Proyecto Flutter configurado correctamente
  • Archivo .env opcional para configuraciones personalizadas

PRUEBAS INCLUIDAS:
  ✅ Detección de IP local del dispositivo
  ✅ Descubrimiento automático de servidor
  ✅ Inicialización de ApiConfig
  ✅ Configuración por ambiente (dev/staging/prod)
  ✅ Mecanismos de fallback
  ✅ Validación de cache inteligente
  ✅ Integración completa

Para más información, consulta la documentación del proyecto.
''');
}
