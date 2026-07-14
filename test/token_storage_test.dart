import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/token_storage.dart';

void main() {
  group('pickPreferredToken', () {
    test('prefiere el token en memoria cuando existe', () {
      final token = pickPreferredToken(
        memoryToken: 'token-en-memoria',
        storageToken: 'token-en-storage',
      );

      expect(token, 'token-en-memoria');
    });

    test('usa el token del storage cuando no hay token en memoria', () {
      final token = pickPreferredToken(
        memoryToken: null,
        storageToken: 'token-en-storage',
      );

      expect(token, 'token-en-storage');
    });

    test('devuelve null cuando ambos están vacíos', () {
      final token = pickPreferredToken(memoryToken: '', storageToken: '   ');

      expect(token, isNull);
    });
  });
}
