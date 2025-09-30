import 'dart:convert';

class JwtUtils {
  static Map<String, dynamic> decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid JWT - Partes: ${parts.length}');
      }

      final normalized = base64Url.normalize(parts[1]);
      final decoded = base64Url.decode(normalized);
      final payload = utf8.decode(decoded);
      final decodedPayload = jsonDecode(payload);

      return decodedPayload;
    } catch (e) {
      rethrow;
    }
  }

  static bool isTokenExpired(String token) {
    final payload = decodeToken(token);
    final exp = payload['exp'];
    if (exp == null) {
      throw Exception('Token does not contain expiration');
    }

    final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().isAfter(expirationDate);
  }

  static List<String> getRoles(String token) {
    try {
      final payload = decodeToken(token);
      final roles = payload['roles'];

      if (roles == null) {
        return [];
      }

      return List<String>.from(roles);
    } catch (e) {
      return [];
    }
  }

  static bool hasRole(String token, String role) {
    final roles = getRoles(token);
    return roles.contains(role);
  }

  static bool hasAnyRole(String token, List<String> requiredRoles) {
    final roles = getRoles(token);
    for (var role in requiredRoles) {
      if (roles.contains(role)) {
        return true;
      }
    }
    return false;
  }
}
