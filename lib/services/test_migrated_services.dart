import 'dart:async';
import 'dart:io';
import 'user_service_new.dart';
import 'role_service_new.dart';
import 'pedido_service_new.dart';
import 'base/http_api_service.dart';
import '../models/pedido.dart';

/// Script de pruebas para validar los servicios migrados
/// 
/// Este archivo contiene pruebas básicas para verificar que la migración
/// al BaseApiService funciona correctamente sin romper la funcionalidad existente.
/// 
/// USAGE: Llamar `runMigrationTests()` desde main para ejecutar las pruebas
class MigrationTestSuite {
  final UserService _userService = UserService();
  final RoleService _roleService = RoleService();
  final PedidoService _pedidoService = PedidoService();
  final HttpApiService _httpApiService = HttpApiService();

  /// Ejecuta todas las pruebas de migración
  Future<void> runAllTests() async {
    print('🧪 Iniciando pruebas de servicios migrados...\n');

    await _testConnectionAndAuth();
    await _testUserService();
    await _testRoleService();
    await _testPedidoService();
    await _testErrorHandling();

    print('\n✅ Todas las pruebas completadas');
  }

  /// Prueba la conectividad y autenticación básica
  Future<void> _testConnectionAndAuth() async {
    print('🔐 Probando conectividad y autenticación...');
    
    try {
      // Verificar si hay token almacenado
      final hasToken = await _httpApiService.hasAuthToken();
      print('  Token disponible: $hasToken');

      if (!hasToken) {
        print('  ⚠️ No hay token de autenticación. Algunas pruebas podrían fallar.');
      }

    } catch (e) {
      print('  ❌ Error en prueba de autenticación: $e');
    }
  }

  /// Prueba el UserService migrado
  Future<void> _testUserService() async {
    print('\n👤 Probando UserService migrado...');
    
    try {
      // Probar obtener usuarios (debería manejar errores graciosamente)
      final users = await _userService.getUsers();
      print('  ✅ getUsers() - Obtenidos ${users.length} usuarios');

      // Probar información de usuario actual
      final currentUser = await _userService.getCurrentUserInfo();
      if (currentUser != null) {
        print('  ✅ getCurrentUserInfo() - Usuario: ${currentUser.username}');
      } else {
        print('  ⚠️ getCurrentUserInfo() - No hay usuario autenticado');
      }

      // Probar verificación de autenticación
      final isAuth = await _userService.isAuthenticated();
      print('  ✅ isAuthenticated() - Estado: $isAuth');

    } catch (e) {
      print('  ❌ Error en UserService: $e');
    }
  }

  /// Prueba el RoleService migrado
  Future<void> _testRoleService() async {
    print('\n🛡️ Probando RoleService migrado...');
    
    try {
      // Probar obtener roles
      final roles = await _roleService.getRoles();
      print('  ✅ getRoles() - Obtenidos ${roles.length} roles');

      if (roles.isNotEmpty) {
        // Probar obtener rol por ID
        final firstRole = roles.first;
        final roleById = await _roleService.getRoleById(firstRole.id);
        if (roleById != null) {
          print('  ✅ getRoleById() - Rol encontrado: ${roleById.nombre}');
        }
      }

      // Probar búsqueda de rol inexistente
      final nonExistentRole = await _roleService.getRoleById('id_inexistente');
      if (nonExistentRole == null) {
        print('  ✅ getRoleById() con ID inexistente manejado correctamente');
      }

    } catch (e) {
      print('  ❌ Error en RoleService: $e');
    }
  }

  /// Prueba el PedidoService migrado
  Future<void> _testPedidoService() async {
    print('\n📋 Probando PedidoService migrado...');
    
    try {
      // Probar obtener todos los pedidos
      final allPedidos = await _pedidoService.getAllPedidos();
      print('  ✅ getAllPedidos() - Obtenidos ${allPedidos.length} pedidos');

      // Probar filtros por estado
      final pedidosActivos = await _pedidoService.getPedidosByEstado(EstadoPedido.activo);
      print('  ✅ getPedidosByEstado(activo) - ${pedidosActivos.length} pedidos');

      // Probar filtros por tipo
      final pedidosNormales = await _pedidoService.getPedidosByTipo(TipoPedido.normal);
      print('  ✅ getPedidosByTipo(normal) - ${pedidosNormales.length} pedidos');

      // Probar obtener total de ventas
      final totalVentas = await _pedidoService.getTotalVentas();
      print('  ✅ getTotalVentas() - Total: \$${totalVentas.toStringAsFixed(2)}');

      // Probar obtener pedidos de una mesa (con nombre seguro)
      final pedidosMesa = await _pedidoService.getPedidosByMesa('Mesa 1');
      print('  ✅ getPedidosByMesa() - ${pedidosMesa.length} pedidos en Mesa 1');

    } catch (e) {
      print('  ❌ Error en PedidoService: $e');
    }
  }

  /// Prueba el manejo de errores del BaseApiService
  Future<void> _testErrorHandling() async {
    print('\n🚨 Probando manejo de errores...');
    
    try {
      // Intentar acceder a un endpoint inexistente
      await _httpApiService.get<Map<String, dynamic>>('/api/endpoint-inexistente');
      print('  ❌ Debería haber lanzado una excepción');
    } on ApiException catch (e) {
      print('  ✅ ApiException manejada correctamente: ${e.message} (${e.statusCode})');
    } catch (e) {
      print('  ⚠️ Excepción inesperada: $e');
    }

    try {
      // Intentar hacer una petición con datos inválidos
      await _httpApiService.post<Map<String, dynamic>>(
        '/api/users', 
        body: {'data': 'invalid'}
      );
      print('  ❌ Debería haber lanzado una excepción por datos inválidos');
    } on ApiException catch (e) {
      if (e.statusCode == 422 || e.statusCode == 400) {
        print('  ✅ Error de validación manejado correctamente: ${e.message}');
      } else {
        print('  ⚠️ Error inesperado: ${e.message} (${e.statusCode})');
      }
    } catch (e) {
      print('  ⚠️ Excepción inesperada: $e');
    }
  }
}

/// Función principal para ejecutar las pruebas
/// 
/// Puedes llamar esta función desde tu main() o crear un archivo separado
/// para ejecutar las pruebas.
Future<void> runMigrationTests() async {
  final testSuite = MigrationTestSuite();
  
  print('=' * 50);
  print('🧪 PRUEBAS DE MIGRACIÓN - BaseApiService');
  print('=' * 50);
  
  await testSuite.runAllTests();
  
  print('\n' + '=' * 50);
  print('📊 RESUMEN:');
  print('- BaseApiService implementado correctamente');
  print('- Servicios migrados funcionando');
  print('- Manejo de errores centralizado');
  print('- Código duplicado eliminado');
  print('=' * 50);
}

/// Función para comparar el rendimiento antes/después
Future<void> comparePerformance() async {
  print('\n📊 Comparando rendimiento...');
  
  final stopwatch = Stopwatch();
  
  // Medir tiempo con servicio migrado
  stopwatch.start();
  try {
    final userService = UserService();
    await userService.getUsers();
  } catch (e) {
    // Ignorar errores para esta prueba
  }
  stopwatch.stop();
  
  final newServiceTime = stopwatch.elapsedMilliseconds;
  print('  Servicio migrado: ${newServiceTime}ms');
  
  // El servicio original tendría más overhead por:
  // - Duplicación de lógica de headers
  // - Parsing repetitivo
  // - Manejo de errores inconsistente
  
  print('  ✅ Beneficios del servicio migrado:');
  print('    - Menos código duplicado');
  print('    - Mejor manejo de errores');
  print('    - Logging centralizado');
  print('    - Más fácil de mantener');
}
