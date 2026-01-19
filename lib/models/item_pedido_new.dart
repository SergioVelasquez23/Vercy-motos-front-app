import '../models/producto.dart';

/// Modelo ItemPedido unificado con backend Java + Facturación Electrónica
///
/// Esta versión elimina la ambigüedad en precios y mantiene
/// consistencia total con el modelo Java.
///
/// CAMBIOS PRINCIPALES:
/// - precio → precioUnitario (consistencia con Java)
/// - Agregado id y productoNombre para compatibilidad
/// - Subtotal siempre calculado automáticamente
/// - Mejor validación y manejo de errores
/// - Compatibilidad con formato JSON del backend
/// - NUEVOS campos para facturación electrónica DIAN
class ItemPedido {
  // 🏷️ IDENTIFICACIÓN
  final String? id; // Opcional, generado por BD

  // 🔗 REFERENCIA A PRODUCTO
  final String productoId; // ID del producto (requerido)
  final String? productoNombre; // Cache del nombre (opcional)
  final String? codigoProducto; // Código interno del producto
  final String? codigoBarras; // Código de barras del producto
  final Producto? producto; // Referencia completa (opcional, para UI)

  // 📊 CANTIDADES Y PRECIOS
  final int cantidad; // Cantidad pedida (requerido)
  final double precioUnitario; // ÚNICO precio (requerido)

  // 💰 IMPUESTOS (Facturación Electrónica)
  final String? tipoImpuesto; // "IVA", "INC", "Exento", etc.
  final double porcentajeImpuesto; // % del impuesto (19%, 8%, etc.)
  final double valorImpuesto; // Valor calculado del impuesto

  // 🎯 DESCUENTOS (Por Item)
  final double porcentajeDescuento; // % de descuento en este item
  final double valorDescuento; // Valor del descuento

  // 📝 INFORMACIÓN ADICIONAL
  final String? notas; // Notas especiales (opcional)
  final List<String> ingredientesSeleccionados; // Ingredientes customizados

  // 🏗️ CONSTRUCTOR
  const ItemPedido({
    this.id,
    required this.productoId,
    this.productoNombre,
    this.codigoProducto,
    this.codigoBarras,
    this.producto,
    required this.cantidad,
    required this.precioUnitario,
    this.tipoImpuesto,
    this.porcentajeImpuesto = 0.0,
    this.valorImpuesto = 0.0,
    this.porcentajeDescuento = 0.0,
    this.valorDescuento = 0.0,
    this.notas,
    this.ingredientesSeleccionados = const [],
  }) : assert(cantidad > 0, 'La cantidad debe ser mayor a 0'),
       assert(precioUnitario >= 0, 'El precio unitario no puede ser negativo'),
       assert(
         porcentajeImpuesto >= 0,
         'El porcentaje de impuesto no puede ser negativo',
       ),
       assert(
         valorImpuesto >= 0,
         'El valor del impuesto no puede ser negativo',
       ),
       assert(
         porcentajeDescuento >= 0,
         'El porcentaje de descuento no puede ser negativo',
       ),
       assert(
         valorDescuento >= 0,
         'El valor del descuento no puede ser negativo',
       );

  // 🧮 CÁLCULOS AUTOMÁTICOS
  double get subtotal => cantidad * precioUnitario;
  
  // Valor total del item = subtotal + impuesto - descuento
  double get valorTotal => subtotal + valorImpuesto - valorDescuento;

  // 📄 SERIALIZACIÓN JSON
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'productoId': productoId,
    if (productoNombre != null) 'productoNombre': productoNombre,
    if (codigoProducto != null) 'codigoProducto': codigoProducto,
    if (codigoBarras != null) 'codigoBarras': codigoBarras,
    'cantidad': cantidad,
    'precioUnitario': precioUnitario,
    'subtotal': subtotal, // Incluido para compatibilidad, pero calculado
    if (tipoImpuesto != null) 'tipoImpuesto': tipoImpuesto,
    'porcentajeImpuesto': porcentajeImpuesto,
    'valorImpuesto': valorImpuesto,
    'porcentajeDescuento': porcentajeDescuento,
    'valorDescuento': valorDescuento,
    'valorTotal': valorTotal,
    if (notas != null && notas!.isNotEmpty) 'notas': notas,
    'ingredientesSeleccionados': ingredientesSeleccionados,
  };

  // 📥 DESERIALIZACIÓN JSON
  factory ItemPedido.fromJson(Map<String, dynamic> json, {Producto? producto}) {
    // Manejar diferentes formatos de precio por compatibilidad con datos existentes
    double precio = 0.0;

    // Prioridad: precioUnitario > precio > subtotal/cantidad
    if (json.containsKey('precioUnitario')) {
      precio = (json['precioUnitario'] as num).toDouble();
    } else if (json.containsKey('precio')) {
      precio = (json['precio'] as num).toDouble();
    } else if (json.containsKey('subtotal') && json.containsKey('cantidad')) {
      final subtotal = (json['subtotal'] as num).toDouble();
      final cantidad = (json['cantidad'] as num).toInt();
      precio = cantidad > 0 ? subtotal / cantidad : 0.0;
    }

    return ItemPedido(
      id: json['id'],
      productoId: json['productoId'] ?? '',
      productoNombre: json['productoNombre'],
      codigoProducto: json['codigoProducto'],
      codigoBarras: json['codigoBarras'],
      producto: producto,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
      precioUnitario: precio,
      tipoImpuesto: json['tipoImpuesto'],
      porcentajeImpuesto:
          (json['porcentajeImpuesto'] as num?)?.toDouble() ?? 0.0,
      valorImpuesto: (json['valorImpuesto'] as num?)?.toDouble() ?? 0.0,
      porcentajeDescuento:
          (json['porcentajeDescuento'] as num?)?.toDouble() ?? 0.0,
      valorDescuento: (json['valorDescuento'] as num?)?.toDouble() ?? 0.0,
      notas: json['notas'],
      ingredientesSeleccionados: json['ingredientesSeleccionados'] != null
          ? List<String>.from(json['ingredientesSeleccionados'])
          : [],
    );
  }

  // 🔄 COMPATIBILIDAD CON CÓDIGO EXISTENTE
  /// Getter de compatibilidad - usar precioUnitario en su lugar
  @Deprecated('Usar precioUnitario en su lugar')
  double get precio => precioUnitario;

  /// Factory de compatibilidad para crear ItemPedido con la API anterior
  factory ItemPedido.legacy({
    required String productoId,
    Producto? producto,
    required int cantidad,
    String? notas,
    required double precio, // Mapea a precioUnitario
    List<String> ingredientesSeleccionados = const [],
  }) {
    return ItemPedido(
      productoId: productoId,
      producto: producto,
      productoNombre: producto?.nombre,
      cantidad: cantidad,
      precioUnitario: precio,
      notas: notas,
      ingredientesSeleccionados: ingredientesSeleccionados,
    );
  }

  // 🔄 MÉTODOS DE COPIA
  ItemPedido copyWith({
    String? id,
    String? productoId,
    String? productoNombre,
    String? codigoProducto,
    String? codigoBarras,
    Producto? producto,
    int? cantidad,
    double? precioUnitario,
    String? tipoImpuesto,
    double? porcentajeImpuesto,
    double? valorImpuesto,
    double? porcentajeDescuento,
    double? valorDescuento,
    String? notas,
    List<String>? ingredientesSeleccionados,
  }) {
    return ItemPedido(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      productoNombre: productoNombre ?? this.productoNombre,
      codigoProducto: codigoProducto ?? this.codigoProducto,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      tipoImpuesto: tipoImpuesto ?? this.tipoImpuesto,
      porcentajeImpuesto: porcentajeImpuesto ?? this.porcentajeImpuesto,
      valorImpuesto: valorImpuesto ?? this.valorImpuesto,
      porcentajeDescuento: porcentajeDescuento ?? this.porcentajeDescuento,
      valorDescuento: valorDescuento ?? this.valorDescuento,
      notas: notas ?? this.notas,
      ingredientesSeleccionados:
          ingredientesSeleccionados ?? this.ingredientesSeleccionados,
    );
  }

  /// Copia con precio (compatibilidad)
  @Deprecated('Usar copyWith con precioUnitario')
  ItemPedido copyWithPrecio({
    String? productoId,
    Producto? producto,
    int? cantidad,
    double? precio,
    String? notas,
    List<String>? ingredientesSeleccionados,
  }) {
    return copyWith(
      productoId: productoId,
      producto: producto,
      cantidad: cantidad,
      precioUnitario: precio,
      notas: notas,
      ingredientesSeleccionados: ingredientesSeleccionados,
    );
  }

  // 🔍 MÉTODOS UTILITARIOS
  @override
  String toString() =>
      'ItemPedido(id: $id, productoId: $productoId, cantidad: $cantidad, precioUnitario: $precioUnitario, subtotal: ${subtotal.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemPedido &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productoId == other.productoId;

  @override
  int get hashCode => id.hashCode ^ productoId.hashCode;

  // 🧪 MÉTODOS DE VALIDACIÓN
  bool get isValid =>
      productoId.isNotEmpty && cantidad > 0 && precioUnitario >= 0;

  List<String> get validationErrors {
    final errors = <String>[];
    if (productoId.isEmpty) errors.add('ProductoId es requerido');
    if (cantidad <= 0) errors.add('Cantidad debe ser mayor a 0');
    if (precioUnitario < 0) errors.add('Precio unitario no puede ser negativo');
    return errors;
  }

  // 🔧 MÉTODOS DE UTILIDAD
  /// Obtiene el nombre del producto, ya sea del cache o del objeto producto
  String get nombreProducto {
    if (productoNombre != null && productoNombre!.isNotEmpty) {
      return productoNombre!;
    }
    if (producto != null && producto!.nombre.isNotEmpty) {
      return producto!.nombre;
    }
    return 'Producto sin nombre';
  }

  /// Indica si tiene ingredientes seleccionados
  bool get tieneIngredientesSeleccionados =>
      ingredientesSeleccionados.isNotEmpty;

  /// Indica si tiene notas especiales
  bool get tieneNotas => notas != null && notas!.isNotEmpty;

  /// Obtiene un resumen del item para mostrar en listas
  String get resumen {
    final buffer = StringBuffer();
    buffer.write('${cantidad}x $nombreProducto');

    if (tieneNotas) {
      buffer.write(' ($notas)');
    }

    if (tieneIngredientesSeleccionados) {
      buffer.write(' +${ingredientesSeleccionados.length} ing.');
    }

    return buffer.toString();
  }
}
