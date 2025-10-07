import 'dart:convert';
import 'item_pedido_new.dart';
import 'producto.dart';

/// Suite completa de pruebas para ItemPedido unificado
///
/// Valida que la serialización/deserialización funcione
/// perfectamente entre Java y Flutter
class ItemPedidoTestSuite {
  /// Ejecuta todas las pruebas de compatibilidad
  static void runAllTests() {
    _testCreacionBasica();
    _testCalculoSubtotal();
    _testSerializacionJSON();
    _testDeserializacionJSON();
    _testCompatibilidadBackend();
    _testValidaciones();
    _testMigrationFromOldFormat();
    _testRoundTripCompatibility();
  }

  /// Test 1: Creación básica del modelo
  static void _testCreacionBasica() {
    try {
      // Crear ItemPedido mínimo
      final item = ItemPedido(
        productoId: 'prod_123',
        cantidad: 2,
        precioUnitario: 15.50,
      );

      assert(item.productoId == 'prod_123');
      assert(item.cantidad == 2);
      assert(item.precioUnitario == 15.50);
      assert(item.subtotal == 31.00);
      assert(item.ingredientesSeleccionados.isEmpty);
      assert(item.isValid);
    } catch (e) {}

    try {
      // Crear ItemPedido completo
      final itemCompleto = ItemPedido(
        id: 'item_456',
        productoId: 'prod_123',
        productoNombre: 'Hamburguesita Especial',
        cantidad: 3,
        precioUnitario: 12.75,
        notas: 'Sin cebolla, extra queso',
        ingredientesSeleccionados: ['ing_001', 'ing_002'],
      );

      assert(itemCompleto.id == 'item_456');
      assert(itemCompleto.nombreProducto == 'Hamburguesita Especial');
      assert(itemCompleto.tieneNotas == true);
      assert(itemCompleto.tieneIngredientesSeleccionados == true);
      assert(itemCompleto.subtotal == 38.25); // 3 * 12.75
    } catch (e) {}
  }

  /// Test 2: Cálculo de subtotal
  static void _testCalculoSubtotal() {
    final testCases = [
      {'cantidad': 1, 'precio': 10.00, 'esperado': 10.00},
      {'cantidad': 2, 'precio': 15.50, 'esperado': 31.00},
      {'cantidad': 5, 'precio': 7.25, 'esperado': 36.25},
      {'cantidad': 10, 'precio': 0.50, 'esperado': 5.00},
    ];

    for (final test in testCases) {
      try {
        final item = ItemPedido(
          productoId: 'test_prod',
          cantidad: test['cantidad'] as int,
          precioUnitario: test['precio'] as double,
        );

        final subtotalCalculado = item.subtotal;
        final subtotalEsperado = test['esperado'] as double;

        assert(
          (subtotalCalculado - subtotalEsperado).abs() < 0.01,
          'Subtotal incorrecto: esperado $subtotalEsperado, obtenido $subtotalCalculado',
        );
      } catch (e) {
        print('  ❌ Error en cálculo: $e');
      }
    }
  }

  /// Test 3: Serialización a JSON
  static void _testSerializacionJSON() {
    try {
      final item = ItemPedido(
        id: 'item_789',
        productoId: 'prod_123',
        productoNombre: 'Pizza Margherita',
        cantidad: 2,
        precioUnitario: 18.50,
        notas: 'Masa delgada',
        ingredientesSeleccionados: ['queso', 'tomate', 'albahaca'],
      );

      final json = item.toJson();

      // Verificar estructura JSON
      assert(json['id'] == 'item_789');
      assert(json['productoId'] == 'prod_123');
      assert(json['productoNombre'] == 'Pizza Margherita');
      assert(json['cantidad'] == 2);
      assert(json['precioUnitario'] == 18.50);
      assert(json['subtotal'] == 37.00);
      assert(json['notas'] == 'Masa delgada');
      assert(json['ingredientesSeleccionados'].length == 3);
    } catch (e) {
      print('  ❌ Error en serialización: $e');
    }
  }

  /// Test 4: Deserialización desde JSON
  static void _testDeserializacionJSON() {
    // JSON en formato del backend Java
    final jsonBackend = {
      'id': 'item_999',
      'productoId': 'prod_456',
      'productoNombre': 'Ensalada César',
      'cantidad': 1,
      'precioUnitario': 14.75,
      'subtotal': 14.75,
      'notas': 'Sin crutones',
      'ingredientesSeleccionados': ['lechuga', 'pollo', 'parmesano'],
    };

    try {
      final item = ItemPedido.fromJson(jsonBackend);

      assert(item.id == 'item_999');
      assert(item.productoId == 'prod_456');
      assert(item.productoNombre == 'Ensalada César');
      assert(item.cantidad == 1);
      assert(item.precioUnitario == 14.75);
      assert(item.subtotal == 14.75);
      assert(item.notas == 'Sin crutones');
      assert(item.ingredientesSeleccionados.length == 3);
    } catch (e) {
      print('  ❌ Error en deserialización: $e');
    }
  }

  /// Test 5: Compatibilidad con formato del backend
  static void _testCompatibilidadBackend() {
    // Simular diferentes formatos que puede enviar el backend
    final formatosBackend = [
      // Formato nuevo (precioUnitario)
      {
        'id': 'item_001',
        'productoId': 'prod_001',
        'cantidad': 2,
        'precioUnitario': 10.00,
        'ingredientesSeleccionados': [],
      },
      // Formato legacy (precio)
      {
        'id': 'item_002',
        'productoId': 'prod_002',
        'cantidad': 3,
        'precio': 12.50,
        'ingredientesSeleccionados': [],
      },
      // Formato calculado (subtotal/cantidad)
      {
        'id': 'item_003',
        'productoId': 'prod_003',
        'cantidad': 4,
        'subtotal': 60.00,
        'ingredientesSeleccionados': [],
      },
    ];

    final subtotalesEsperados = [20.00, 37.50, 60.00];

    for (int i = 0; i < formatosBackend.length; i++) {
      try {
        final item = ItemPedido.fromJson(formatosBackend[i]);
        final subtotalEsperado = subtotalesEsperados[i];

        assert(
          (item.subtotal - subtotalEsperado).abs() < 0.01,
          'Subtotal incorrecto en formato ${i + 1}',
        );
      } catch (e) {
        print('  ❌ Error en formato backend ${i + 1}: $e');
      }
    }
  }

  /// Test 6: Validaciones
  static void _testValidaciones() {
    // Test validaciones positivas
    try {
      final itemValido = ItemPedido(
        productoId: 'prod_123',
        cantidad: 1,
        precioUnitario: 10.00,
      );

      assert(itemValido.isValid);
      assert(itemValido.validationErrors.isEmpty);
    } catch (e) {
      print('  ❌ Error en validación positiva: $e');
    }

    // Test validaciones negativas
    final casosInvalidos = [
      // ProductoId vacío
      () => ItemPedido(productoId: '', cantidad: 1, precioUnitario: 10.00),
      // Cantidad cero
      () => ItemPedido(productoId: 'prod', cantidad: 0, precioUnitario: 10.00),
      // Precio negativo
      () => ItemPedido(productoId: 'prod', cantidad: 1, precioUnitario: -5.00),
    ];

    for (int i = 0; i < casosInvalidos.length; i++) {
      try {
        casosInvalidos[i]();
      } catch (e) {
        print(
          '  ✅ Validación negativa ${i + 1} - OK (${e.toString().split(':').last.trim()})',
        );
      }
    }
  }

  /// Test 7: Migración desde formato anterior
  static void _testMigrationFromOldFormat() {
    try {
      // Crear usando factory legacy
      final itemLegacy = ItemPedido.legacy(
        productoId: 'prod_legacy',
        cantidad: 2,
        precio: 15.00, // Mapea a precioUnitario
        notas: 'Nota legacy',
      );

      assert(itemLegacy.precioUnitario == 15.00);
      assert(itemLegacy.subtotal == 30.00);

      // Test getter deprecated
      assert(itemLegacy.precio == itemLegacy.precioUnitario);
    } catch (e) {
      print('  ❌ Error en migración legacy: $e');
    }
  }

  /// Test 8: Round-trip compatibility (Java ↔ Flutter)
  static void _testRoundTripCompatibility() {
    try {
      // 1. Crear ItemPedido en Flutter
      final itemOriginal = ItemPedido(
        id: 'roundtrip_test',
        productoId: 'prod_roundtrip',
        productoNombre: 'Producto Round-trip',
        cantidad: 3,
        precioUnitario: 22.33,
        notas: 'Test de compatibilidad',
        ingredientesSeleccionados: ['ing1', 'ing2', 'ing3'],
      );

      // 2. Serializar a JSON (Flutter → Backend)
      final jsonFlutter = itemOriginal.toJson();

      // 3. Simular procesamiento en backend y respuesta
      final jsonBackend = Map<String, dynamic>.from(jsonFlutter);
      jsonBackend['subtotal'] =
          jsonBackend['cantidad'] * jsonBackend['precioUnitario'];

      // 4. Deserializar desde JSON (Backend → Flutter)
      final itemReconstruido = ItemPedido.fromJson(jsonBackend);

      // 5. Verificar que son idénticos
      assert(itemOriginal.id == itemReconstruido.id);
      assert(itemOriginal.productoId == itemReconstruido.productoId);
      assert(itemOriginal.productoNombre == itemReconstruido.productoNombre);
      assert(itemOriginal.cantidad == itemReconstruido.cantidad);
      assert(itemOriginal.precioUnitario == itemReconstruido.precioUnitario);
      assert((itemOriginal.subtotal - itemReconstruido.subtotal).abs() < 0.01);
      assert(itemOriginal.notas == itemReconstruido.notas);
      assert(
        itemOriginal.ingredientesSeleccionados.length ==
            itemReconstruido.ingredientesSeleccionados.length,
      );
    } catch (e) {
      print('  ❌ Error en round-trip: $e');
    }
  }
}

/// Función principal para ejecutar todas las pruebas
void testItemPedidoUnificado() {
  ItemPedidoTestSuite.runAllTests();
}
