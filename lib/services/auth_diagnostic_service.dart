import 'base_api_service.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

class AuthDiagnosticService {
  static final AuthDiagnosticService _instance =
      AuthDiagnosticService._internal();
  factory AuthDiagnosticService() => _instance;
  AuthDiagnosticService._internal();

  final BaseApiService _apiService = BaseApiService();

  // Verificar la información del usuario actual
  Future<Map<String, dynamic>?> verificarUsuarioActual() async {
    try {
      print('🔍 Verificando información del usuario actual');

      final response = await _apiService.get<Map<String, dynamic>>(
        '/user-info/current',
        (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        print('✅ Información del usuario obtenida correctamente');
        print('🔍 Datos del usuario: ${response.data}');

        // Mostrar roles
        if (response.data!.containsKey('roles')) {
          final roles = response.data!['roles'];
          print('👤 Roles del usuario: $roles');
          print('👤 ¿Es admin? ${response.data!['isAdmin']}');
          print('👤 ¿Es superadmin? ${response.data!['isSuperAdmin']}');
        } else {
          print('⚠️ No se encontraron roles en la respuesta');
        }

        return response.data;
      } else {
        print('⚠️ Error al verificar usuario: ${response.errorMessage}');
        print('⚠️ Mensaje: ${response.message}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción en verificarUsuarioActual: $e');
      return null;
    }
  }

  // Actualizar el UserProvider con los roles del backend
  Future<bool> actualizarRoles(BuildContext context) async {
    try {
      print('🔄 Iniciando actualización de roles desde el backend...');
      final userInfo = await verificarUsuarioActual();

      if (userInfo != null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        // Mostrar información completa del usuario
        print('👤 Información del usuario: $userInfo');

        // Procesar roles
        if (userInfo.containsKey('roles')) {
          final rolesData = userInfo['roles'];
          print(
            '🔍 Datos de roles recibidos: $rolesData (tipo: ${rolesData.runtimeType})',
          );

          List<String> roles = [];

          if (rolesData is List) {
            // Asegurarnos que cada elemento sea string
            roles = rolesData.map((r) => r.toString()).toList();
            print('👤 Roles convertidos desde lista: $roles');
          } else if (rolesData is String) {
            roles = [rolesData];
            print('👤 Roles como cadena única: $roles');
          } else if (rolesData != null) {
            // Intentar convertir a string como último recurso
            roles = [rolesData.toString()];
            print('👤 Roles convertidos a string: $roles');
          }

          // Actualizar roles en el provider
          await userProvider.actualizarRoles(roles);
          print('✅ Roles actualizados en UserProvider: ${userProvider.roles}');
          print(
            '👤 Es Admin: ${userProvider.isAdmin}, Es Mesero: ${userProvider.isMesero}',
          );
          return true;
        } else {
          print('⚠️ No se encontraron roles en la respuesta del backend');
          return false;
        }
      }
      print('⚠️ No se pudo obtener información del usuario');
      return false;
    } catch (e) {
      print('❌ Error actualizando roles: $e');
      return false;
    }
  }
}
