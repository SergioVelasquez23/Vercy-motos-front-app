/// Borrador de una compra guardado en el servidor, ligado al usuario que lo
/// creó (ver `/api/borradores-compra`).
///
/// [datos] es el formulario tal cual lo serializa `_formularioAJson()` de
/// `crear_factura_compra_screen.dart`: el servidor no lo interpreta.
class BorradorCompra {
  final String? id;
  final String? usuarioNombre;
  final String? proveedorNombre;
  final int cantidadItems;
  final DateTime? fechaCreacion;
  final Map<String, dynamic> datos;

  const BorradorCompra({
    this.id,
    this.usuarioNombre,
    this.proveedorNombre,
    this.cantidadItems = 0,
    this.fechaCreacion,
    this.datos = const {},
  });

  factory BorradorCompra.fromJson(Map<String, dynamic> json) {
    final datos = json['datos'];
    return BorradorCompra(
      id: (json['_id'] ?? json['id'])?.toString(),
      usuarioNombre: json['usuarioNombre']?.toString(),
      proveedorNombre: json['proveedorNombre']?.toString(),
      cantidadItems: (json['cantidadItems'] as num?)?.toInt() ?? 0,
      fechaCreacion: DateTime.tryParse(json['fechaCreacion']?.toString() ?? ''),
      datos: datos is Map ? Map<String, dynamic>.from(datos) : const {},
    );
  }
}
