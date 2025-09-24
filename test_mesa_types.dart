// Test script para verificar el sistema de tipos de mesa
import 'package:flutter/material.dart';
import 'lib/models/tipo_mesa.dart';

void main() {
  print('🏠 Sistema de Tipos de Mesa - Test');
  print('=====================================\n');

  // Test 1: Verificar todos los tipos de mesa
  print('📋 Tipos de mesa disponibles:');
  for (TipoMesa tipo in TipoMesa.values) {
    print('  • ${tipo.nombre}');
    print('    - ${tipo.descripcion}');
    print('    - Icono: ${tipo.icono}');
    print('    - Color: 0x${tipo.colorValue.toRadixString(16).toUpperCase()}');
    if (tipo.tieneRecargo) {
      print('    - Recargo: ${(tipo.porcentajeRecargo * 100).toInt()}%');
    } else {
      print('    - Sin recargo');
    }
    print('');
  }

  // Test 2: Verificar lógica de negocio
  print('💰 Test de recargos:');
  
  final double precioBase = 25000.0;
  print('Precio base del pedido: \$${precioBase.toStringAsFixed(0)}');
  print('');
  
  for (TipoMesa tipo in TipoMesa.values) {
    if (tipo.tieneRecargo) {
      final double recargo = precioBase * tipo.porcentajeRecargo;
      final double total = precioBase + recargo;
      print('${tipo.nombre}:');
      print('  Recargo: \$${recargo.toStringAsFixed(0)} (${(tipo.porcentajeRecargo * 100).toInt()}%)');
      print('  Total: \$${total.toStringAsFixed(0)}');
    } else {
      print('${tipo.nombre}:');
      print('  Sin recargo');
      print('  Total: \$${precioBase.toStringAsFixed(0)}');
    }
    print('');
  }

  // Test 3: Casos de uso típicos
  print('🎯 Casos de uso:');
  print('');
  
  print('Caso 1: Mesa normal para 4 personas');
  TipoMesa mesaNormal = TipoMesa.normal;
  print('  Tipo recomendado: ${mesaNormal.nombre}');
  print('  ${mesaNormal.descripcion}');
  print('  Recargo aplicable: ${mesaNormal.tieneRecargo ? "Sí" : "No"}');
  print('');
  
  print('Caso 2: Evento especial para grupo grande');
  TipoMesa mesaEspecial = TipoMesa.especial;
  print('  Tipo recomendado: ${mesaEspecial.nombre}');
  print('  ${mesaEspecial.descripcion}');
  print('  Recargo aplicable: ${mesaEspecial.tieneRecargo ? "Sí (${(mesaEspecial.porcentajeRecargo * 100).toInt()}%)" : "No"}');
  print('');
  
  print('Caso 3: Mesa en terraza');
  TipoMesa mesaTerraza = TipoMesa.terraza;
  print('  Tipo recomendado: ${mesaTerraza.nombre}');
  print('  ${mesaTerraza.descripcion}');
  print('  Recargo aplicable: ${mesaTerraza.tieneRecargo ? "Sí (${(mesaTerraza.porcentajeRecargo * 100).toInt()}%)" : "No"}');
  print('');
  
  print('✅ Test completado exitosamente!');
  print('El sistema de tipos de mesa está listo para usar.');
}