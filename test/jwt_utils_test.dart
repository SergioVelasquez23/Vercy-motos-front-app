import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/jwt_utils.dart';

String _base64UrlNoPadding(Map<String, dynamic> data) {
  return base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
}

String _buildToken(Map<String, dynamic> payload) {
  final header = _base64UrlNoPadding({'alg': 'HS256', 'typ': 'JWT'});
  final body = _base64UrlNoPadding(payload);
  return '$header.$body.fake-signature';
}

void main() {
  group('JwtUtils.decodeToken', () {
    test('decodifica el payload de un token válido', () {
      final token = _buildToken({'_id': 'u1', 'email': 'a@b.com'});

      final payload = JwtUtils.decodeToken(token);

      expect(payload['_id'], 'u1');
      expect(payload['email'], 'a@b.com');
    });

    test('lanza si el token no tiene 3 partes separadas por punto', () {
      expect(() => JwtUtils.decodeToken('solo-una-parte'), throwsException);
      expect(() => JwtUtils.decodeToken('dos.partes'), throwsException);
    });
  });

  group('JwtUtils.isTokenExpired', () {
    test('false si exp está en el futuro', () {
      final expFuturo = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final token = _buildToken({'exp': expFuturo});

      expect(JwtUtils.isTokenExpired(token), isFalse);
    });

    test('true si exp está en el pasado', () {
      final expPasado = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final token = _buildToken({'exp': expPasado});

      expect(JwtUtils.isTokenExpired(token), isTrue);
    });

    test('lanza si el payload no tiene exp', () {
      final token = _buildToken({'_id': 'u1'});

      expect(() => JwtUtils.isTokenExpired(token), throwsException);
    });
  });

  group('JwtUtils.getRoles / hasRole / hasAnyRole', () {
    test('getRoles retorna la lista de roles del payload', () {
      final token = _buildToken({'roles': ['ADMIN', 'CAJA']});

      expect(JwtUtils.getRoles(token), ['ADMIN', 'CAJA']);
    });

    test('getRoles retorna lista vacía si el payload no tiene roles', () {
      final token = _buildToken({'_id': 'u1'});

      expect(JwtUtils.getRoles(token), isEmpty);
    });

    test('getRoles retorna lista vacía (no lanza) con un token malformado', () {
      expect(JwtUtils.getRoles('token-invalido'), isEmpty);
    });

    test('hasRole es true solo si el rol está en la lista', () {
      final token = _buildToken({'roles': ['ADMIN']});

      expect(JwtUtils.hasRole(token, 'ADMIN'), isTrue);
      expect(JwtUtils.hasRole(token, 'CAJA'), isFalse);
    });

    test('hasAnyRole es true si al menos uno de los roles requeridos está presente', () {
      final token = _buildToken({'roles': ['CAJA']});

      expect(JwtUtils.hasAnyRole(token, ['ADMIN', 'CAJA']), isTrue);
      expect(JwtUtils.hasAnyRole(token, ['ADMIN', 'SUPERADMIN']), isFalse);
    });

    test('hasAnyRole con lista de roles requeridos vacía es false', () {
      final token = _buildToken({'roles': ['CAJA']});

      expect(JwtUtils.hasAnyRole(token, []), isFalse);
    });
  });
}