import 'package:test/test.dart';
import 'package:kronos_restbar/models/item_pedido_unified.dart';
import 'dart:convert';

/// Suite completa de pruebas de compatibilidad ItemPedido
///
/// Estas pruebas validan que el modelo Flutter funcione correctamente
/// con datos que podrían venir del backend Java y viceversa.
///
/// COBERTURA:
/// ✅ Serialización/Deserialización JSON
/// ✅ Compatibilidad con múltiples formatos de precio
/// ✅ Validaciones de datos
/// ✅ Cálculos automáticos
/// ✅ Manejo de errores
/// ✅ Casos edge

void main() {
  group('ItemPedidoUnified - Pruebas de Compatibilidad', () {
    // 🧪 DATOS DE PRUEBA
    const sampleItemData = {
      'id': 'item_123',
      'productoId': 'prod_456',
      'productoNombre': 'Hamburguesa Clásica',
      'cantidad': 2,
      'precioUnitario': 15.99,
      'notas': 'Sin cebolla',
      'ingredientesSeleccionados': ['queso', 'tomate'],
    };

    const backendJavaFormat = {
      'id': 'item_789',
      'productoId': 'prod_101',
      'productoNombre': 'Pizza Margherita',
      'cantidad': 1,
      'precioUnitario': 22.50,
      'subtotal': 22.50, // Backend puede enviar subtotal calculado
      'notas': null,
      'ingredientesSeleccionados': [],
    };

    const legacyFormat = {
      'productoId': 'prod_202',
      'productoNombre': 'Ensalada César',
      'cantidad': 3,
      'precio': 12.75, // Formato legacy usa 'precio' en vez de 'precioUnitario'
      'notas': 'Extra pollo',
    };

    group('Creación y Constructores', () {
      test('Constructor principal con parámetros requeridos', () {
        final item = ItemPedidoUnified(
          productoId: 'prod_123',
          cantidad: 2,
          precioUnitario: 10.50,
        );

        expect(item.productoId, 'prod_123');
        expect(item.cantidad, 2);
        expect(item.precioUnitario, 10.50);
        expect(item.subtotal, 21.00);
        expect(item.ingredientesSeleccionados, isEmpty);
        expect(item.isValid, isTrue);
      });

      test('Constructor nombrado .crear()', () {
        final item = ItemPedidoUnified.crear(
          productoId: 'prod_456',
          productoNombre: 'Test Product',
          cantidad: 1,
          precioUnitario: 5.99,
          notas: 'Test notes',
          ingredientesSeleccionados: ['ingredient1'],
        );

        expect(item.productoNombre, 'Test Product');
        expect(item.notas, 'Test notes');
        expect(item.ingredientesSeleccionados, ['ingredient1']);
        expect(item.subtotal, 5.99);
      });

      test('Factory básico desde ItemPedidoUnifiedFactory', () {
        final item = ItemPedidoUnifiedFactory.basico(
          productoId: 'prod_789',
          productoNombre: 'Basic Product',
          precioUnitario: 8.99,
          cantidad: 3,
        );

        expect(item.cantidad, 3);
        expect(item.subtotal, 26.97);
        expect(item.tieneNotas, isFalse);
        expect(item.tieneIngredientesPersonalizados, isFalse);
      });
    });

    group('Serialización JSON', () {
      test('toJson() incluye todos los campos', () {
        final item = ItemPedidoUnified(
          id: 'test_id',
          productoId: 'prod_123',
          productoNombre: 'Test Product',
          cantidad: 2,
          precioUnitario: 15.50,
          notas: 'Test notas',
          ingredientesSeleccionados: ['queso', 'tomate'],
        );

        final json = item.toJson();

        expect(json['id'], 'test_id');
        expect(json['productoId'], 'prod_123');
        expect(json['productoNombre'], 'Test Product');
        expect(json['cantidad'], 2);
        expect(json['precioUnitario'], 15.50);
        expect(json['subtotal'], 31.00);
        expect(json['notas'], 'Test notas');
        expect(json['ingredientesSeleccionados'], ['queso', 'tomate']);
      });

      test('toJson() omite campos nulos opcionales', () {
        final item = ItemPedidoUnified(
          productoId: 'prod_123',
          cantidad: 1,
          precioUnitario: 10.00,
        );

        final json = item.toJson();

        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('productoNombre'), isFalse);
        expect(json.containsKey('notas'), isFalse);
        expect(json['ingredientesSeleccionados'], isEmpty);
      });
    });

    group('Deserialización JSON', () {
      test('fromJson() con datos completos', () {
        final item = ItemPedidoUnified.fromJson(sampleItemData);

        expect(item.id, 'item_123');
        expect(item.productoId, 'prod_456');
        expect(item.productoNombre, 'Hamburguesa Clásica');
        expect(item.cantidad, 2);
        expect(item.precioUnitario, 15.99);
        expect(item.subtotal, 31.98);
        expect(item.notas, 'Sin cebolla');
        expect(item.ingredientesSeleccionados, ['queso', 'tomate']);
      });

      test('fromJson() formato backend Java con subtotal', () {
        final item = ItemPedidoUnified.fromJson(backendJavaFormat);

        expect(item.id, 'item_789');
        expect(item.productoId, 'prod_101');
        expect(item.cantidad, 1);
        expect(item.precioUnitario, 22.50);
        expect(item.subtotal, 22.50); // Calculado automáticamente
        expect(item.notas, isNull);
        expect(item.ingredientesSeleccionados, isEmpty);
      });

      test('fromJson() formato legacy con "precio"', () {
        final item = ItemPedidoUnified.fromJson(legacyFormat);

        expect(item.productoId, 'prod_202');
        expect(item.cantidad, 3);
        expect(item.precioUnitario, 12.75); // Mapeado desde 'precio'
        expect(item.subtotal, 38.25);
        expect(item.notas, 'Extra pollo');
      });

      test('fromJson() con datos mínimos', () {
        final minimalData = {
          'productoId': 'prod_minimal',
          'cantidad': 1,
          'precioUnitario': 5.00,
        };

        final item = ItemPedidoUnified.fromJson(minimalData);

        expect(item.productoId, 'prod_minimal');
        expect(item.cantidad, 1);
        expect(item.precioUnitario, 5.00);
        expect(item.subtotal, 5.00);
        expect(item.id, isNull);
        expect(item.productoNombre, isNull);
        expect(item.notas, isNull);
        expect(item.ingredientesSeleccionados, isEmpty);
        expect(item.isValid, isTrue);
      });
    });

    group('Factory con Manejo de Errores', () {
      test('fromJsonSafe() con JSON válido', () {
        final item = ItemPedidoUnifiedFactory.fromJsonSafe(sampleItemData);

        expect(item, isNotNull);
        expect(item!.productoId, 'prod_456');
        expect(item.subtotal, 31.98);
      });

      test('fromJsonSafe() con JSON nulo', () {
        final item = ItemPedidoUnifiedFactory.fromJsonSafe(null);

        expect(item, isNull);
      });

      test('fromJsonList() con lista válida', () {
        final jsonList = [sampleItemData, backendJavaFormat];
        final items = ItemPedidoUnifiedFactory.fromJsonList(jsonList);

        expect(items, hasLength(2));
        expect(items[0].productoId, 'prod_456');
        expect(items[1].productoId, 'prod_101');
      });

      test('fromJsonList() con lista nula', () {
        final items = ItemPedidoUnifiedFactory.fromJsonList(null);
        expect(items, isEmpty);
      });
    });

    group('Validaciones', () {
      test('isValid retorna true para datos válidos', () {
        final item = ItemPedidoUnified(
          productoId: 'valid_id',
          cantidad: 1,
          precioUnitario: 10.00,
        );

        expect(item.isValid, isTrue);
        expect(item.validationErrors, isEmpty);
      });

      test('isValid retorna false para productoId vacío', () {
        final item = ItemPedidoUnified(
          productoId: '',
          cantidad: 1,
          precioUnitario: 10.00,
        );

        expect(item.isValid, isFalse);
        expect(item.validationErrors, contains('ProductoId es requerido'));
      });

      test('isValid retorna false para cantidad inválida', () {
        final item = ItemPedidoUnified(
          productoId: 'valid_id',
          cantidad: 0,
          precioUnitario: 10.00,
        );

        expect(item.isValid, isFalse);
        expect(item.validationErrors, contains('Cantidad debe ser mayor a 0'));
      });

      test('isValid retorna false para precio negativo', () {
        final item = ItemPedidoUnified(
          productoId: 'valid_id',
          cantidad: 1,
          precioUnitario: -5.00,
        );

        expect(item.isValid, isFalse);
        expect(
          item.validationErrors,
          contains('Precio unitario no puede ser negativo'),
        );
      });

      test('validate() lanza excepción para datos inválidos', () {
        final item = ItemPedidoUnified(
          productoId: '',
          cantidad: -1,
          precioUnitario: -10.00,
        );

        expect(() => item.validate(), throwsArgumentError);
      });
    });

    group('Cálculos Automáticos', () {
      test('subtotal se calcula correctamente', () {
        final item = ItemPedidoUnified(
          productoId: 'prod_123',
          cantidad: 3,
          precioUnitario: 12.50,
        );

        expect(item.subtotal, 37.50);
        expect(item.precioTotal, 37.50); // Alias de subtotal
      });

      test('subtotal con decimales', () {
        final item = ItemPedidoUnified(
          productoId: 'prod_123',
          cantidad: 7,
          precioUnitario: 3.33,
        );

        // Usar closeTo para manejar precisión de punto flotante
        expect(item.subtotal, closeTo(23.31, 0.01));
      });
    });

    group('Métodos Utilitarios', () {
      test('descripcionCorta sin cantidad múltiple', () {
        final item = ItemPedidoUnified(
          productoId: 'prod_123',
          productoNombre: 'Pizza',
          cantidad: 1,
          precioUnitario: 15.00,
        );

        expect(item.descripcionCorta, 'Pizza');
      });

      test('descripcionCorta con cantidad múltiple', () {
        final item = ItemPedidoUnified(
          productoId: 'prod_123',
          productoNombre: 'Pizza',
          cantidad: 3,
          precioUnitario: 15.00,
        );

        expect(item.descripcionCorta, 'Pizza x3');
      });

      test('descripcionDetallada completa', () {
        final item = ItemPedidoUnified(
          productoId: 'prod_123',
          productoNombre: 'Pizza',
          cantidad: 2,
          precioUnitario: 15.50,
        );

        expect(item.descripcionDetallada, 'Pizza x2 - \$15.50 = \$31.00');
      });

      test('tieneIngredientesPersonalizados', () {
        final item1 = ItemPedidoUnified(
          productoId: 'prod_123',
          cantidad: 1,
          precioUnitario: 10.00,
        );

        final item2 = ItemPedidoUnified(
          productoId: 'prod_123',
          cantidad: 1,
          precioUnitario: 10.00,
          ingredientesSeleccionados: ['extra queso'],
        );

        expect(item1.tieneIngredientesPersonalizados, isFalse);
        expect(item2.tieneIngredientesPersonalizados, isTrue);
      });

      test('tieneNotas', () {
        final item1 = ItemPedidoUnified(
          productoId: 'prod_123',
          cantidad: 1,
          precioUnitario: 10.00,
        );

        final item2 = ItemPedidoUnified(
          productoId: 'prod_123',
          cantidad: 1,
          precioUnitario: 10.00,
          notas: 'Sin sal',
        );

        expect(item1.tieneNotas, isFalse);
        expect(item2.tieneNotas, isTrue);
      });
    });

    group('Métodos de Copia', () {
      test('copyWith() cambia campos especificados', () {
        final original = ItemPedidoUnified(
          productoId: 'prod_123',
          productoNombre: 'Original',
          cantidad: 1,
          precioUnitario: 10.00,
        );

        final copy = original.copyWith(cantidad: 3, notas: 'Nueva nota');

        expect(copy.productoId, 'prod_123'); // Sin cambio
        expect(copy.productoNombre, 'Original'); // Sin cambio
        expect(copy.cantidad, 3); // Cambiado
        expect(copy.precioUnitario, 10.00); // Sin cambio
        expect(copy.notas, 'Nueva nota'); // Cambiado
        expect(copy.subtotal, 30.00); // Recalculado
      });
    });

    group('Extensiones de Lista', () {
      test('totalGeneral calcula suma de subtotales', () {
        final items = [
          ItemPedidoUnified(
            productoId: '1',
            cantidad: 2,
            precioUnitario: 10.00,
          ),
          ItemPedidoUnified(
            productoId: '2',
            cantidad: 1,
            precioUnitario: 15.50,
          ),
          ItemPedidoUnified(productoId: '3', cantidad: 3, precioUnitario: 8.75),
        ];

        expect(items.totalGeneral, 61.75); // 20.00 + 15.50 + 26.25
      });

      test('cantidadTotal suma todas las cantidades', () {
        final items = [
          ItemPedidoUnified(
            productoId: '1',
            cantidad: 2,
            precioUnitario: 10.00,
          ),
          ItemPedidoUnified(
            productoId: '2',
            cantidad: 1,
            precioUnitario: 15.50,
          ),
          ItemPedidoUnified(productoId: '3', cantidad: 3, precioUnitario: 8.75),
        ];

        expect(items.cantidadTotal, 6); // 2 + 1 + 3
      });

      test('porProducto filtra por ID de producto', () {
        final items = [
          ItemPedidoUnified(
            productoId: 'A',
            cantidad: 1,
            precioUnitario: 10.00,
          ),
          ItemPedidoUnified(
            productoId: 'B',
            cantidad: 2,
            precioUnitario: 15.00,
          ),
          ItemPedidoUnified(
            productoId: 'A',
            cantidad: 1,
            precioUnitario: 12.00,
          ),
        ];

        final itemsA = items.porProducto('A');
        expect(itemsA, hasLength(2));
        expect(itemsA.every((item) => item.productoId == 'A'), isTrue);
      });

      test('conIngredientesPersonalizados filtra correctamente', () {
        final items = [
          ItemPedidoUnified(
            productoId: '1',
            cantidad: 1,
            precioUnitario: 10.00,
            ingredientesSeleccionados: ['queso'],
          ),
          ItemPedidoUnified(
            productoId: '2',
            cantidad: 1,
            precioUnitario: 15.00,
          ),
          ItemPedidoUnified(
            productoId: '3',
            cantidad: 1,
            precioUnitario: 8.00,
            ingredientesSeleccionados: ['tomate', 'lechuga'],
          ),
        ];

        final conIngredientes = items.conIngredientesPersonalizados;
        expect(conIngredientes, hasLength(2));
        expect(
          conIngredientes.every((item) => item.tieneIngredientesPersonalizados),
          isTrue,
        );
      });
    });

    group('Compatibilidad con Tipos de Datos', () {
      test('maneja números enteros como double', () {
        final jsonData = {
          'productoId': 'prod_123',
          'cantidad': 2,
          'precioUnitario': 15, // Entero en lugar de double
        };

        final item = ItemPedidoUnified.fromJson(jsonData);
        expect(item.precioUnitario, 15.0);
        expect(item.subtotal, 30.0);
      });

      test('maneja strings que representan números', () {
        final jsonData = {
          'productoId': 'prod_123',
          'cantidad': '2', // String que representa número
          'precioUnitario': '15.99',
        };

        final item = ItemPedidoUnified.fromJson(jsonData);
        expect(item.cantidad, 2);
        expect(item.precioUnitario, 15.99);
      });
    });

    group('Casos Edge', () {
      test('maneja lista de ingredientes nula', () {
        final jsonData = {
          'productoId': 'prod_123',
          'cantidad': 1,
          'precioUnitario': 10.00,
          'ingredientesSeleccionados': null,
        };

        final item = ItemPedidoUnified.fromJson(jsonData);
        expect(item.ingredientesSeleccionados, isEmpty);
      });

      test('maneja precio unitario cero', () {
        final item = ItemPedidoUnified(
          productoId: 'free_item',
          cantidad: 1,
          precioUnitario: 0.0,
        );

        expect(item.isValid, isTrue);
        expect(item.subtotal, 0.0);
      });

      test('toString() proporciona información útil', () {
        final item = ItemPedidoUnified(
          id: 'test_id',
          productoId: 'prod_123',
          productoNombre: 'Test Product',
          cantidad: 2,
          precioUnitario: 15.99,
        );

        final str = item.toString();
        expect(str, contains('test_id'));
        expect(str, contains('prod_123'));
        expect(str, contains('Test Product'));
        expect(str, contains('2'));
        expect(str, contains('15.99'));
        expect(str, contains('31.98')); // subtotal
      });
    });
  });

  group('Pruebas de Rendimiento', () {
    test('creación masiva de items', () {
      final stopwatch = Stopwatch()..start();

      final items = List.generate(
        1000,
        (index) => ItemPedidoUnified(
          productoId: 'prod_$index',
          cantidad: index % 5 + 1,
          precioUnitario: (index % 50) + 0.99,
        ),
      );

      stopwatch.stop();

      expect(items, hasLength(1000));
      expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Menos de 100ms

      // Verificar que todos los cálculos son correctos
      final total = items.totalGeneral;
      expect(total, greaterThan(0));
    });

    test('serialización masiva JSON', () {
      final items = List.generate(
        100,
        (index) => ItemPedidoUnified(
          id: 'item_$index',
          productoId: 'prod_$index',
          productoNombre: 'Producto $index',
          cantidad: index % 3 + 1,
          precioUnitario: index * 1.5 + 5.99,
          notas: 'Notas $index',
          ingredientesSeleccionados: [
            'ingrediente_${index}_1',
            'ingrediente_${index}_2',
          ],
        ),
      );

      final stopwatch = Stopwatch()..start();
      final jsonList = items.map((item) => item.toJson()).toList();
      stopwatch.stop();

      expect(jsonList, hasLength(100));
      expect(stopwatch.elapsedMilliseconds, lessThan(50)); // Menos de 50ms
    });
  });
}
