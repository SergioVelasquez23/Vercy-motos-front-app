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
        

      final response = await _apiService.get<Map<String, dynamic>>(
        '/user-info/current',
        (json) => json,
      );

      if (response.isSuccess && response.data != null) {
          
          

        // Mostrar roles
        if (response.data!.containsKey('roles')) {
          final roles = response.data!['roles'];
            
            
            
        } else {
            
        }

        return response.data;
      } else {
          
          
        return null;
      }
    } catch (e) {
        
      return null;
    }
  }

  // Actualizar el UserProvider con los roles del backend
  Future<bool> actualizarRoles(BuildContext context) async {
    try {
        
      final userInfo = await verificarUsuarioActual();

      if (userInfo != null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        // Mostrar información completa del usuario
          

        // Procesar roles
        if (userInfo.containsKey('roles')) {
          final rolesData = userInfo['roles'];
             
          List<String> roles = [];

          if (rolesData is List) {
            // Asegurarnos que cada elemento sea string
            roles = rolesData.map((r) => r.toString()).toList();
              
          } else if (rolesData is String) {
            roles = [rolesData];
              
          } else if (rolesData != null) {
            // Intentar convertir a string como último recurso
            roles = [rolesData.toString()];
              
          }

          // Actualizar roles en el provider
          await userProvider.actualizarRoles(roles);
            
          return true;
        } else {
            
          return false;
        }
      }
        
      return false;
    } catch (e) {
        
      return false;
    }
  }
}
