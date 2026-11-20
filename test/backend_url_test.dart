import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/config/constants.dart';

void main() {
  // Cada negocio compila con SU URL (tool/build_web.sh la toma de negocio.env). Sin --dart-define el
  // front apunta al backend local, nunca a producción de un negocio concreto.
  test('sin --dart-define=BACKEND_URL el backend es el local', () {
    expect(kBackendUrl, 'http://localhost:8081');
  });
}
