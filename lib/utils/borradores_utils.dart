import '../models/pedido.dart';

/// Quién creó un borrador de facturación.
///
/// Los borradores nuevos guardan al usuario en `guardadoPor`. Los antiguos no
/// lo tienen y solo traen `mesero` (el usuario, o el facturador elegido en la
/// caja de ENVÍOS), que se usa como respaldo.
String? autorDeBorrador(Pedido borrador) {
  final guardadoPor = borrador.guardadoPor?.trim();
  if (guardadoPor != null && guardadoPor.isNotEmpty) return guardadoPor;
  return borrador.mesero.trim().isEmpty ? null : borrador.mesero.trim();
}

/// Deja solo los borradores del [usuario]. La comparación ignora mayúsculas y
/// espacios. Si no se conoce al usuario no se puede filtrar y se devuelven
/// todos, antes que esconder borradores por error.
List<Pedido> filtrarBorradoresDelUsuario(List<Pedido> borradores, String? usuario) {
  final yo = usuario?.trim().toLowerCase();
  if (yo == null || yo.isEmpty) return borradores;
  return borradores.where((b) => autorDeBorrador(b)?.toLowerCase() == yo).toList();
}
