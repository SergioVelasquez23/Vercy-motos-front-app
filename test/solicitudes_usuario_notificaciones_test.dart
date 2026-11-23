import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/models/solicitud_usuario.dart';
import 'package:vercy_motos/providers/notificaciones_provider.dart';
import 'package:vercy_motos/services/solicitud_usuario_service.dart';

class _FakeSolicitudes implements ISolicitudUsuarioService {
  List<SolicitudUsuario> lista;
  final List<String> autorizadas = [];
  final List<String> rechazadas = [];
  int consultas = 0;
  Object? errorAlAutorizar;

  _FakeSolicitudes(this.lista);

  @override
  Future<List<SolicitudUsuario>> pendientes() async {
    consultas++;
    return List.of(lista);
  }

  @override
  Future<void> autorizar(String id) async {
    if (errorAlAutorizar != null) throw errorAlAutorizar!;
    autorizadas.add(id);
  }

  @override
  Future<void> rechazar(String id) async => rechazadas.add(id);
}

List<NotificacionItem> _usuarios(NotificacionesProvider p) =>
    p.items.where((i) => i.tipo == TipoNotificacion.usuarioPendiente).toList();

void main() {
  const ana = SolicitudUsuario(id: 's1', nombre: 'Ana', email: 'ana@vercy.com', solicitadoPor: 'admin@vercy.com');
  const luis = SolicitudUsuario(id: 's2', nombre: 'Luis', email: 'luis@vercy.com');

  test('un SUPERADMIN ve una notificación por cada solicitud pendiente', () async {
    final fake = _FakeSolicitudes([ana, luis]);
    final provider = NotificacionesProvider(solicitudUsuarioService: fake)
      ..configurarUsuario(email: 'super@vercy.com', nombre: 'super', esSuperadmin: true);

    await provider.refresh();

    final items = _usuarios(provider);
    expect(items.length, 2);
    expect(items.first.titulo, 'Nuevo usuario por autorizar');
    expect(items.first.descripcion, 'Ana · ana@vercy.com');
    expect(items.first.solicitudUsuario?.id, 's1');
  });

  test('quien NO es SUPERADMIN no ve las solicitudes ni las consulta', () async {
    final fake = _FakeSolicitudes([ana]);
    final provider = NotificacionesProvider(solicitudUsuarioService: fake)
      ..configurarUsuario(email: 'asesor@vercy.com', nombre: 'asesor');

    await provider.refresh();

    expect(_usuarios(provider), isEmpty);
    expect(fake.consultas, 0);
  });

  test('autorizar llama al servicio y quita la solicitud de la campana', () async {
    final fake = _FakeSolicitudes([ana, luis]);
    final provider = NotificacionesProvider(solicitudUsuarioService: fake)
      ..configurarUsuario(esSuperadmin: true);
    await provider.refresh();

    await provider.autorizarSolicitudUsuario('s1');

    expect(fake.autorizadas, ['s1']);
    expect(_usuarios(provider).map((i) => i.solicitudUsuario?.id), ['s2']);
  });

  test('rechazar llama al servicio y quita la solicitud de la campana', () async {
    final fake = _FakeSolicitudes([ana]);
    final provider = NotificacionesProvider(solicitudUsuarioService: fake)
      ..configurarUsuario(esSuperadmin: true);
    await provider.refresh();

    await provider.rechazarSolicitudUsuario('s1');

    expect(fake.rechazadas, ['s1']);
    expect(_usuarios(provider), isEmpty);
  });

  test('si autorizar falla, el error sube y la solicitud sigue en la campana', () async {
    final fake = _FakeSolicitudes([ana])..errorAlAutorizar = Exception('El email ya existe');
    final provider = NotificacionesProvider(solicitudUsuarioService: fake)
      ..configurarUsuario(esSuperadmin: true);
    await provider.refresh();

    await expectLater(provider.autorizarSolicitudUsuario('s1'), throwsException);

    expect(_usuarios(provider).length, 1);
  });
}
