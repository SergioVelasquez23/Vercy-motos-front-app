import 'dart:convert';

class JwtUtils {
  static Map<String, dynamic> decodeToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid JWT');
    }

    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    return jsonDecode(payload);
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
}
