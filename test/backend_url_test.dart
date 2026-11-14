import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/config/constants.dart';

void main() {
  test('sin --dart-define=BACKEND_URL el backend es producción', () {
    expect(kBackendUrl, 'https://204-168-190-85.nip.io');
  });
}
