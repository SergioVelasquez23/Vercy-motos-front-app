/// Modelo para el historial de ediciones de pedidos
///
/// Integra con el backend que registra automáticamente los cambios
/// realizados en los pedidos incluyendo quién los hizo.
class HistorialEdicion {
  final String id;
  final String pedidoId;
  final String tipoEdicion; // "producto_agregado", "producto_editado", etc.
  final String usuarioEditor;
  final DateTime fechaEdicion;
  final Map<String, dynamic>? detallesCambio;
  final String? descripcion;

  const HistorialEdicion({
    required this.id,
    required this.pedidoId,
    required this.tipoEdicion,
    required this.usuarioEditor,
    required this.fechaEdicion,
    this.detallesCambio,
    this.descripcion,
  });

  factory HistorialEdicion.fromJson(Map<String, dynamic> json) {
    return HistorialEdicion(
      id: json['id']?.toString() ?? '',
      pedidoId: json['pedidoId']?.toString() ?? '',
      tipoEdicion: json['tipoEdicion']?.toString() ?? '',
      usuarioEditor: json['usuarioEditor']?.toString() ?? '',
      fechaEdicion:
          DateTime.tryParse(json['fechaEdicion']?.toString() ?? '') ??
          DateTime.now(),
      detallesCambio: json['detallesCambio'] as Map<String, dynamic>?,
      descripcion: json['descripcion']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pedidoId': pedidoId,
      'tipoEdicion': tipoEdicion,
      'usuarioEditor': usuarioEditor,
      'fechaEdicion': fechaEdicion.toIso8601String(),
      if (detallesCambio != null) 'detallesCambio': detallesCambio,
      if (descripcion != null) 'descripcion': descripcion,
    };
  }

  /// Descripción legible del tipo de edición
  String get descripcionTipo {
    switch (tipoEdicion) {
      case 'producto_agregado':
        return 'Producto agregado';
      case 'producto_editado':
        return 'Producto modificado';
      case 'producto_eliminado':
        return 'Producto eliminado';
      case 'pedido_editado':
        return 'Pedido editado';
      default:
        return 'Cambio realizado';
    }
  }

  /// Icono representativo para el tipo de edición
  String get icono {
    switch (tipoEdicion) {
      case 'producto_agregado':
        return '➕';
      case 'producto_editado':
        return '✏️';
      case 'producto_eliminado':
        return '❌';
      case 'pedido_editado':
        return '📝';
      default:
        return '📋';
    }
  }
}
