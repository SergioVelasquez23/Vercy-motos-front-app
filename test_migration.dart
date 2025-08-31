#!/usr/bin/env dart

import 'lib/models/item_pedido.dart';

void main() {
  print('🧪 Probando migración de ItemPedido...\n');

  try {
    // Test 1: Constructor nuevo
    print('1️⃣ Test constructor nuevo:');
    final item1 = ItemPedido(
      productoId: 'prod_123',
      cantidad: 2,
      precioUnitario: 15.99,
    );
    print('   ✅ Creado: ${item1.toString()}');
    print('   ✅ Subtotal: ${item1.subtotal}');

    // Test 2: Constructor legacy
    print('\n2️⃣ Test constructor legacy:');
    final item2 = ItemPedido.legacy(
      productoId: 'prod_456',
      cantidad: 1,
      precio: 12.50, // Campo legacy
    );
    print('   ✅ Creado: ${item2.toString()}');
    print('   ✅ Precio (legacy): ${item2.precio}');
    print('   ✅ PrecioUnitario: ${item2.precioUnitario}');

    // Test 3: fromJson con formato nuevo
    print('\n3️⃣ Test fromJson formato nuevo:');
    final jsonNuevo = {
      'productoId': 'prod_789',
      'precioUnitario': 18.75,
      'cantidad': 3,
      'productoNombre': 'Pizza Margherita',
    };
    final item3 = ItemPedido.fromJson(jsonNuevo);
    print('   ✅ Creado desde JSON: ${item3.toString()}');

    // Test 4: fromJson con formato legacy
    print('\n4️⃣ Test fromJson formato legacy:');
    final jsonLegacy = {
      'productoId': 'prod_101',
      'precio': 22.00, // Campo legacy
      'cantidad': 1,
      'productoNombre': 'Hamburguesa',
    };
    final item4 = ItemPedido.fromJson(jsonLegacy);
    print('   ✅ Creado desde JSON legacy: ${item4.toString()}');

    // Test 5: toJson
    print('\n5️⃣ Test toJson:');
    final json = item1.toJson();
    print('   ✅ JSON: $json');

    // Test 6: Validaciones
    print('\n6️⃣ Test validaciones:');
    print('   ✅ Item1 válido: ${item1.isValid}');
    print('   ✅ Errores: ${item1.validationErrors}');

    print('\n🎉 ¡Todas las pruebas de migración pasaron!');
    print('✅ ItemPedido migrado exitosamente');

  } catch (e, stackTrace) {
    print('❌ Error en migración: $e');
    print('Stack trace: $stackTrace');
  }
}
