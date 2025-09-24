/// Modelo ItemPedido unificado - Versión 2.0
///
/// MIGRADO A ARQUITECTURA UNIFICADA
/// ✅ Compatible con backend Java
/// ✅ Un solo campo precio: precioUnitario
/// ✅ Subtotal calculado automáticamente
/// ✅ Validaciones integradas
///
/// CAMBIOS PRINCIPALES:
/// - Eliminado: dependencia del objeto Producto completo
/// - Unificado: campo "precio" -> "precioUnitario"
/// - Mejorado: cálculos automáticos y validaciones
/// - Agregado: compatibilidad total con formato Java
library;

// Import del modelo unificado base
import 'item_pedido_unified.dart';

/// ItemPedido - Versión unificada compatible
///
/// Esta versión extiende ItemPedidoUnified para mantener compatibilidad
/// con código existente mientras usa la nueva arquitectura unificada.
class ItemPedido extends ItemPedidoUnified {
  // 🏗️ CONSTRUCTOR PRINCIPAL (Compatible con versión anterior)
  const ItemPedido({
    super.id,
    required super.productoId,
    super.productoNombre,
    required super.cantidad,
    required super.precioUnitario,
    super.notas,
    super.ingredientesSeleccionados = const [],
    super.agregadoPor,
    super.fechaAgregado,
  });

  // 🏗️ CONSTRUCTOR DE COMPATIBILIDAD (para código legacy)
  ItemPedido.legacy({
    required super.productoId,
    required super.cantidad,
    required double precio, // Campo legacy
    super.notas,
    super.ingredientesSeleccionados,
    super.productoNombre,
    super.agregadoPor,
    super.fechaAgregado,
  }) : super(precioUnitario: precio);

  // 🔄 FACTORY FROM JSON (Compatible con múltiples formatos)
  factory ItemPedido.fromJson(Map<String, dynamic> json, {dynamic producto}) {
    // Extraer precio de múltiples formatos posibles
    double precio = _extractPrice(json);

    // Manejar nombre del producto desde diferentes fuentes
    String? productoNombre = _extractProductName(json, producto);

    return ItemPedido(
      id: json['id']?.toString(),
      productoId: json['productoId']?.toString() ?? '',
      productoNombre: productoNombre,
      cantidad: _parseToInt(json['cantidad']),
      precioUnitario: precio,
      notas: json['notas']?.toString(),
      ingredientesSeleccionados: json['ingredientesSeleccionados'] != null
          ? List<String>.from(json['ingredientesSeleccionados'])
          : const [],
      agregadoPor: json['agregadoPor']?.toString(),
      fechaAgregado: json['fechaAgregado'] != null
          ? DateTime.tryParse(json['fechaAgregado'].toString())
          : null,
    );
  }

  // 🔄 SERIALIZACIÓN COMPATIBLE (incluye campos legacy si necesario)
  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();

    // Agregar campos adicionales para compatibilidad legacy
    baseJson.addAll({
      'precio': precioUnitario, // Alias para compatibilidad
    });

    return baseJson;
  }

  // 🔧 GETTERS DE COMPATIBILIDAD

  /// Getter de compatibilidad: precio -> precioUnitario
  double get precio => precioUnitario;

  /// Información de producto (simplificada)
  Map<String, dynamic>? get producto => productoNombre != null
      ? {'id': productoId, 'nombre': productoNombre, 'precio': precioUnitario}
      : null;

  // 🛠️ MÉTODOS UTILITARIOS INTERNOS

  /// Extrae precio de diferentes formatos JSON
  static double _extractPrice(Map<String, dynamic> json) {
    if (json.containsKey('precioUnitario')) {
      return _parseToDouble(json['precioUnitario']);
    } else if (json.containsKey('precio')) {
      return _parseToDouble(json['precio']);
    }
    return 0.0;
  }

  /// Extrae nombre del producto desde diferentes fuentes
  static String? _extractProductName(
    Map<String, dynamic> json,
    dynamic producto,
  ) {
    // Prioridad 1: JSON directo
    if (json.containsKey('productoNombre') && json['productoNombre'] != null) {
      return json['productoNombre'].toString();
    }

    // Prioridad 2: Objeto producto pasado como parámetro
    if (producto != null) {
      if (producto is Map<String, dynamic> && producto.containsKey('nombre')) {
        return producto['nombre']?.toString();
      }
      // Si es un objeto con getter nombre
      try {
        return producto.nombre?.toString();
      } catch (_) {
        // Ignorar si no tiene la propiedad nombre
      }
    }

    return null;
  }

  /// Convierte valor dinámico a double de forma segura
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

  /// Convierte valor dinámico a int de forma segura
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

  // 🔍 MÉTODOS DE COMPATIBILIDAD CON VERSIÓN ANTERIOR

  /// toString personalizado para ItemPedido
  @override
  String toString() {
    return 'ItemPedido(productoId: $productoId, cantidad: $cantidad, notas: $notas, precio: ${precioUnitario.toStringAsFixed(2)})';
  }

  /// Crear copia con nuevos valores (compatible con versión anterior)
  ItemPedido copyWithLegacy({
    String? productoId,
    int? cantidad,
    double? precio, // Campo legacy
    String? notas,
    List<String>? ingredientesSeleccionados,
    String? productoNombre,
    String? agregadoPor,
    DateTime? fechaAgregado,
  }) {
    return ItemPedido(
      productoId: productoId ?? this.productoId,
      productoNombre: productoNombre ?? this.productoNombre,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precio ?? precioUnitario,
      notas: notas ?? this.notas,
      ingredientesSeleccionados:
          ingredientesSeleccionados ?? this.ingredientesSeleccionados,
      agregadoPor: agregadoPor ?? this.agregadoPor,
      fechaAgregado: fechaAgregado ?? this.fechaAgregado,
    );
  }
}

// 🏭 FACTORY HELPERS PARA MIGRACIÓN
class ItemPedidoMigrationHelper {
  /// Convierte de formato legacy a nuevo formato
  static ItemPedido fromLegacyFormat({
    required String productoId,
    required int cantidad,
    required double precio,
    String? notas,
    List<String> ingredientesSeleccionados = const [],
    String? productoNombre,
    Map<String, dynamic>? productoData,
  }) {
    return ItemPedido(
      productoId: productoId,
      productoNombre: productoNombre ?? productoData?['nombre']?.toString(),
      cantidad: cantidad,
      precioUnitario: precio,
      notas: notas,
      ingredientesSeleccionados: ingredientesSeleccionados,
    );
  }

  /// Convierte lista de items legacy a nuevo formato
  static List<ItemPedido> fromLegacyList(List<dynamic> legacyItems) {
    return legacyItems
        .cast<Map<String, dynamic>>()
        .map((json) => ItemPedido.fromJson(json))
        .toList();
  }
}
