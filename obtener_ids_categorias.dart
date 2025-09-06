// 📋 Script rápido para obtener IDs de categorías
// Ejecuta esto en tu app para obtener los IDs reales

import '../controllers/carga_masiva_controller.dart';

void main() async {
  final controller = CargaMasivaController();
  
  print('🗂️ OBTENIENDO IDs DE CATEGORÍAS...\n');
  
  // Obtener IDs
  final ids = await controller.obtenerIdsCategorias();
  
  print('\n📋 COPIA ESTE MAPEO PARA USAR CON FOTOS:');
  print('=' * 50);
  
  ids.forEach((nombre, id) {
    print('"$nombre": "$id",');
  });
  
  print('=' * 50);
  print('\n💡 Uso: Dime la categoría de la foto y usaré el ID correspondiente');
}

// También puedes ejecutar esto desde la consola de Flutter:
/*
void obtenerIDsCategorias() async {
  final controller = CargaMasivaController();
  final ids = await controller.obtenerIdsCategorias();
  
  print('📋 IDs para usar en JSON:');
  ids.forEach((nombre, id) {
    print('"$nombre": "$id"');
  });
}
*/
