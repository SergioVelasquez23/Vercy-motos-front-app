/// Modelo ItemPedido unificado para Flutter
///
/// Versión 2.0 - Completamente compatible con backend Java
///
/// CARACTERÍSTICAS PRINCIPALES:
/// ✅ Un solo campo de precio: precioUnitario
/// ✅ Subtotal siempre calculado automáticamente
/// ✅ Validaciones incorporadas
/// ✅ Serialización/deserialización robusta
/// ✅ Compatibilidad total con ItemPedido.java
///
/// CAMPOS ELIMINADOS DE VERSIONES ANTERIORES:
/// ❌ precio (ambiguo) -> ahora precioUnitario
/// ❌ subtotal almacenado -> ahora calculado
/// ❌ dependencia del objeto Producto completo -> ahora solo IDs
///
/// AUTOR: Sistema de Mejoras Arquitectónicas
/// FECHA: Agosto 2025
library;

class ItemPedidoUnified {
  // 🏷️ IDENTIFICACIÓN
  final String? id; // Opcional, generado por backend

  // 🔗 REFERENCIA A PRODUCTO
  final String productoId; // ID del producto (requerido)
  final String? productoNombre; // Cache del nombre (opcional)

  // 📊 CANTIDADES Y PRECIOS
  final int cantidad; // Cantidad pedida (requerido)
  final double precioUnitario; // ÚNICO campo precio (requerido)

  // 📝 INFORMACIÓN ADICIONAL
  final String? notas; // Notas especiales (opcional)
  final List<String> ingredientesSeleccionados; // Ingredientes customizados
  final List<String> ingredientesUsados; // IDs de ingredientes usados en este producto (para inventario)

  // 👤 INFORMACIÓN DE USUARIO (Para rastreo de quien agregó el producto)
  final String? agregadoPor; // Usuario que agregó el producto
  final DateTime? fechaAgregado; // Fecha cuando se agregó

  // 🏗️ CONSTRUCTOR PRINCIPAL
  const ItemPedidoUnified({
    this.id,
    required this.productoId,
    this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
    this.notas,
    this.ingredientesSeleccionados = const [],
    this.ingredientesUsados = const [],
    this.agregadoPor,
    this.fechaAgregado,
  });

  // 🏗️ CONSTRUCTOR NOMBRADO PARA CREACIÓN RÁPIDA
  ItemPedidoUnified.crear({
    required String productoId,
    required String productoNombre,
    required int cantidad,
    required double precioUnitario,
    String? notas,
    List<String> ingredientesSeleccionados = const [],
    List<String> ingredientesUsados = const [],
    String? agregadoPor,
    DateTime? fechaAgregado,
  }) : this(
         productoId: productoId,
         productoNombre: productoNombre,
         cantidad: cantidad,
         precioUnitario: precioUnitario,
         notas: notas,
         ingredientesSeleccionados: ingredientesSeleccionados,
         ingredientesUsados: ingredientesUsados,
         agregadoPor: agregadoPor,
         fechaAgregado: fechaAgregado,
       );

  // 🧮 CÁLCULOS AUTOMÁTICOS
  /// Subtotal calculado automáticamente
  /// No se almacena - siempre se calcula en tiempo real
  double get subtotal => precioUnitario * cantidad;

  // 🔄 MÉTODOS DE COPIA INMUTABLE
  ItemPedidoUnified copyWith({
    String? id,
    String? productoId,
    String? productoNombre,
    int? cantidad,
    double? precioUnitario,
    String? notas,
    List<String>? ingredientesSeleccionados,
    List<String>? ingredientesUsados,
    String? agregadoPor,
    DateTime? fechaAgregado,
  }) {
    return ItemPedidoUnified(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      productoNombre: productoNombre ?? this.productoNombre,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      notas: notas ?? this.notas,
      ingredientesSeleccionados:
          ingredientesSeleccionados ?? this.ingredientesSeleccionados,
      ingredientesUsados:
          ingredientesUsados ?? this.ingredientesUsados,
      agregadoPor: agregadoPor ?? this.agregadoPor,
      fechaAgregado: fechaAgregado ?? this.fechaAgregado,
    );
  }

  // 🔄 SERIALIZACIÓN A JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'productoId': productoId,
      if (productoNombre != null) 'productoNombre': productoNombre,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      // subtotal se calcula automáticamente en backend y frontend
      'subtotal': subtotal,
      if (notas != null && notas!.isNotEmpty) 'notas': notas,
      'ingredientesSeleccionados': ingredientesSeleccionados,
      'ingredientesUsados': ingredientesUsados,
      if (agregadoPor != null) 'agregadoPor': agregadoPor,
      if (fechaAgregado != null)
        'fechaAgregado': fechaAgregado!.toIso8601String(),
    };
  }

  // 🔄 DESERIALIZACIÓN DESDE JSON
  factory ItemPedidoUnified.fromJson(Map<String, dynamic> json) {
    // Manejar múltiples formatos de precio por compatibilidad
    double precio = 0.0;
    if (json.containsKey('precioUnitario')) {
      final precioValue = json['precioUnitario'];
      precio = _parseToDouble(precioValue);
    } else if (json.containsKey('precio')) {
      final precioValue = json['precio'];
      precio = _parseToDouble(precioValue);
    }

    // Manejar múltiples formatos de cantidad
    int cantidad = 1;
    if (json.containsKey('cantidad')) {
      final cantidadValue = json['cantidad'];
      cantidad = _parseToInt(cantidadValue);
    }

    // Parsear fecha si está presente
    DateTime? fechaAgregado;
    if (json['fechaAgregado'] != null) {
      try {
        fechaAgregado = DateTime.parse(json['fechaAgregado'].toString());
      } catch (_) {
        // Si no se puede parsear la fecha, ignorarla
      }
    }

    return ItemPedidoUnified(
      id: json['id']?.toString(),
      productoId: json['productoId']?.toString() ?? '',
      productoNombre: json['productoNombre']?.toString(),
      cantidad: cantidad,
      precioUnitario: precio,
      notas: json['notas']?.toString(),
      ingredientesSeleccionados: json['ingredientesSeleccionados'] != null
          ? List<String>.from(json['ingredientesSeleccionados'])
          : const [],
      ingredientesUsados: json['ingredientesUsados'] != null
          ? List<String>.from(json['ingredientesUsados'])
          : const [],
      agregadoPor: json['agregadoPor']?.toString(),
      fechaAgregado: fechaAgregado,
    );
  }

  // Utilitario para convertir diferentes tipos a double
  static double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // Utilitario para convertir diferentes tipos a int
  static int _parseToInt(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (_) {
        try {
          return double.parse(value).round();
        } catch (_) {
          return 1;
        }
      }
    }
    return 1;
  }

  // 🔄 CONVERSIÓN A MAPA PARA BASE DE DATOS
  Map<String, dynamic> toMap() => toJson();

  // 🔄 DESDE MAPA DE BASE DE DATOS
  factory ItemPedidoUnified.fromMap(Map<String, dynamic> map) =>
      ItemPedidoUnified.fromJson(map);

  // 🧪 VALIDACIONES
  /// Verifica si el item es válido
  bool get isValid {
    return productoId.isNotEmpty && cantidad > 0 && precioUnitario >= 0;
  }

  /// Lista de errores de validación
  List<String> get validationErrors {
    final List<String> errors = [];

    if (productoId.isEmpty) {
      errors.add('ProductoId es requerido');
    }

    if (cantidad <= 0) {
      errors.add('Cantidad debe ser mayor a 0');
    }

    if (precioUnitario < 0) {
      errors.add('Precio unitario no puede ser negativo');
    }

    return errors;
  }

  /// Lanza excepción si el item no es válido
  void validate() {
    final errors = validationErrors;
    if (errors.isNotEmpty) {
      throw ArgumentError('ItemPedido inválido: ${errors.join(', ')}');
    }
  }

  // 🔍 MÉTODOS UTILITARIOS
  @override
  String toString() {
    return 'ItemPedidoUnified{'
        'id: $id, '
        'productoId: $productoId, '
        'productoNombre: $productoNombre, '
        'cantidad: $cantidad, '
        'precioUnitario: $precioUnitario, '
        'subtotal: ${subtotal.toStringAsFixed(2)}, '
        'notas: $notas, '
        'ingredientesSeleccionados: $ingredientesSeleccionados'
        '}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ItemPedidoUnified &&
        other.id == id &&
        other.productoId == productoId &&
        other.cantidad == cantidad &&
        other.precioUnitario == precioUnitario;
  }

  @override
  int get hashCode {
    return Object.hash(id, productoId, cantidad, precioUnitario);
  }

  // 📊 MÉTODOS DE ANÁLISIS
  /// Precio total de este item (subtotal)
  double get precioTotal => subtotal;

  /// Verifica si este item tiene ingredientes personalizados
  bool get tieneIngredientesPersonalizados =>
      ingredientesSeleccionados.isNotEmpty;

  /// Verifica si tiene notas especiales
  bool get tieneNotas => notas != null && notas!.isNotEmpty;

  /// Descripción corta para mostrar en listas
  String get descripcionCorta {
    String desc = productoNombre ?? 'Producto $productoId';
    if (cantidad > 1) desc += ' x$cantidad';
    return desc;
  }

  /// Descripción detallada incluyendo precio
  String get descripcionDetallada {
    String desc = descripcionCorta;
    desc += ' - \$${precioUnitario.toStringAsFixed(2)}';
    if (cantidad > 1) {
      desc += ' = \$${subtotal.toStringAsFixed(2)}';
    }
    return desc;
  }
}

// 🔧 EXTENSIONES ÚTILES
extension ItemPedidoUnifiedExtensions on List<ItemPedidoUnified> {
  /// Calcula el total de todos los items
  double get totalGeneral => fold(0.0, (sum, item) => sum + item.subtotal);

  /// Cuenta la cantidad total de items
  int get cantidadTotal => fold(0, (sum, item) => sum + item.cantidad);

  /// Filtra items por producto ID
  List<ItemPedidoUnified> porProducto(String productoId) {
    return where((item) => item.productoId == productoId).toList();
  }

  /// Filtra items con ingredientes personalizados
  List<ItemPedidoUnified> get conIngredientesPersonalizados {
    return where((item) => item.tieneIngredientesPersonalizados).toList();
  }

  /// Filtra items con notas
  List<ItemPedidoUnified> get conNotas {
    return where((item) => item.tieneNotas).toList();
  }
}

// 🏭 FACTORY PARA CASOS COMUNES
class ItemPedidoUnifiedFactory {
  /// Crear item básico con solo los campos esenciales
  static ItemPedidoUnified basico({
    required String productoId,
    required String productoNombre,
    required double precioUnitario,
    int cantidad = 1,
  }) {
    return ItemPedidoUnified.crear(
      productoId: productoId,
      productoNombre: productoNombre,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
    );
  }

  /// Crear item con personalización completa
  static ItemPedidoUnified personalizado({
    required String productoId,
    required String productoNombre,
    required double precioUnitario,
    int cantidad = 1,
    String? notas,
    List<String> ingredientesSeleccionados = const [],
  }) {
    return ItemPedidoUnified.crear(
      productoId: productoId,
      productoNombre: productoNombre,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      notas: notas,
      ingredientesSeleccionados: ingredientesSeleccionados,
    );
  }

  /// Crear desde JSON con manejo robusto de errores
  static ItemPedidoUnified? fromJsonSafe(Map<String, dynamic>? json) {
    if (json == null) return null;

    try {
      return ItemPedidoUnified.fromJson(json);
    } catch (e) {
        
      return null;
    }
  }

  /// Crear lista desde JSON array con manejo de errores
  static List<ItemPedidoUnified> fromJsonList(List<dynamic>? jsonList) {
    if (jsonList == null) return [];

    return jsonList
        .cast<Map<String, dynamic>>()
        .map(fromJsonSafe)
        .where((item) => item != null)
        .cast<ItemPedidoUnified>()
        .toList();
  }
}
