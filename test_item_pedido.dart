#!/usr/bin/env dart

import 'dart:io';

/// Script para ejecutar las pruebas de compatibilidad del modelo ItemPedido
///
/// Este script valida que el modelo unificado funcione correctamente
/// entre Flutter y el backend Java.
///
/// Uso:
///   dart test_item_pedido.dart           # Ejecutar todas las pruebas
///   dart test_item_pedido.dart --quick   # Solo pruebas esenciales
///   dart test_item_pedido.dart --help    # Mostrar ayuda

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    _showHelp();
    return;
  }

  final isQuickMode = arguments.contains('--quick') || arguments.contains('-q');

  print('=' * 60);
  print('🧪 PRUEBAS DE COMPATIBILIDAD - ItemPedido Unificado');
  print('=' * 60);

  if (isQuickMode) {
    print('⚡ Modo rápido activado - Solo pruebas esenciales\n');
  }

  try {
    // Verificar que estamos en el directorio correcto
    final currentDir = Directory.current.path;
    print('📂 Directorio: $currentDir');

    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      print('❌ Error: No se encontró pubspec.yaml');
      print(
        '💡 Ejecuta este script desde el directorio raíz del proyecto Flutter',
      );
      exit(1);
    }

    // Verificar que existe el archivo de pruebas
    final testFile = File('test/item_pedido_compatibility_test.dart');
    if (!testFile.existsSync()) {
      print('❌ Error: No se encontró el archivo de pruebas');
      print(
        '💡 Asegúrate de que existe test/item_pedido_compatibility_test.dart',
      );
      exit(1);
    }

    print('✅ Proyecto Flutter detectado');
    print('✅ Archivo de pruebas encontrado\n');

    // Ejecutar las pruebas usando dart test
    await _runTests(isQuickMode);

    print('\n${'=' * 60}');
    print('🎉 ¡Pruebas completadas exitosamente!');
    print('✅ El modelo ItemPedido unificado está listo para usar');
    print('=' * 60);
  } catch (e) {
    print('\n❌ Error durante la ejecución de pruebas:');
    print('   $e');

    print('\n💡 Consejos para solucionar problemas:');
    print('   • Ejecuta "flutter pub get" para instalar dependencias');
    print('   • Verifica que el directorio test/ exista');
    print('   • Asegúrate de tener la dependencia "test" en pubspec.yaml');

    exit(1);
  }
}

Future<void> _runTests(bool isQuickMode) async {
  print('🚀 Ejecutando pruebas de compatibilidad...\n');

  // Comando base para ejecutar las pruebas
  List<String> args = ['test', 'test/item_pedido_compatibility_test.dart'];

  if (isQuickMode) {
    // En modo rápido, ejecutar solo pruebas esenciales
    args.addAll([
      '--name',
      'Creación y Constructores|Serialización JSON|Validaciones',
    ]);
  }

  // Ejecutar las pruebas
  final result = await Process.run('dart', args);

  // Mostrar la salida
  if (result.stdout.isNotEmpty) {
    print(result.stdout);
  }

  if (result.stderr.isNotEmpty) {
    print('⚠️ Advertencias/Errores:');
    print(result.stderr);
  }

  // Verificar el resultado
  if (result.exitCode == 0) {
    print('✅ Todas las pruebas pasaron correctamente');
  } else {
    print('❌ Algunas pruebas fallaron (código de salida: ${result.exitCode})');
    exit(result.exitCode);
  }
}

void _showHelp() {
  print('''
🧪 Test de Compatibilidad ItemPedido - Sopa y Carbón

DESCRIPCIÓN:
  Este script ejecuta pruebas exhaustivas para validar que el modelo
  ItemPedido unificado funcione correctamente entre Flutter y Java.

USO:
  dart test_item_pedido.dart [OPCIONES]

OPCIONES:
  --help, -h      Mostrar esta ayuda
  --quick, -q     Ejecutar solo pruebas esenciales (más rápido)

EJEMPLOS:
  dart test_item_pedido.dart              # Todas las pruebas
  dart test_item_pedido.dart --quick      # Pruebas rápidas
  dart test_item_pedido.dart -q           # Pruebas rápidas (forma corta)

PRUEBAS INCLUIDAS:
  ✅ Creación y constructores
  ✅ Serialización/deserialización JSON
  ✅ Compatibilidad con formatos legacy
  ✅ Validaciones de datos
  ✅ Cálculos automáticos
  ✅ Manejo de errores
  ✅ Casos edge y rendimiento

PREREQUISITOS:
  • Proyecto Flutter configurado correctamente
  • Dependencia "test" en pubspec.yaml
  • Archivo test/item_pedido_compatibility_test.dart

Para más información, consulta PROYECTO_ESTADO_COMPLETO.md
''');
}
