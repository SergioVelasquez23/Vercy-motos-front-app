import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/producto_service.dart';
import '../services/ingrediente_service.dart';
import '../models/producto.dart';
import '../models/ingrediente.dart';
import '../models/categoria.dart';

class CargaMasivaController {
  final ProductoService _productoService = ProductoService();
  final IngredienteService _ingredienteService = IngredienteService();

  /// Obtener todos los IDs de categorías para facilitar la carga
  Future<Map<String, String>> obtenerIdsCategorias() async {
    try {
      final categorias = await _productoService.getCategorias();
      Map<String, String> idsMap = {};
      
      for (var categoria in categorias) {
        idsMap[categoria.nombre] = categoria.id;
      }
      
      print('📋 IDs de Categorías:');
      idsMap.forEach((nombre, id) {
        print('  "$nombre": "$id"');
      });
      
      return idsMap;
    } catch (e) {
      print('❌ Error obteniendo IDs de categorías: $e');
      return {};
    }
  }

  /// Obtener todos los IDs de ingredientes para facilitar la asignación
  Future<Map<String, String>> obtenerIdsIngredientes() async {
    try {
      final ingredientes = await _ingredienteService.getAllIngredientes();
      Map<String, String> idsMap = {};
      
      for (var ingrediente in ingredientes) {
        idsMap[ingrediente.nombre] = ingrediente.id;
      }
      
      print('🥕 IDs de Ingredientes:');
      idsMap.forEach((nombre, id) {
        print('  "$nombre": "$id"');
      });
      
      return idsMap;
    } catch (e) {
      print('❌ Error obteniendo IDs de ingredientes: $e');
      return {};
    }
  }

  /// Crear categorías básicas si no existen
  Future<void> crearCategoriasBasicas() async {
    final categoriasBasicas = [
      {'nombre': 'Platos Principales', 'descripcion': 'Platos fuertes del menú'},
      {'nombre': 'Aperitivos', 'descripcion': 'Entradas y aperitivos'},
      {'nombre': 'Bebidas', 'descripcion': 'Bebidas frías y calientes'},
      {'nombre': 'Postres', 'descripcion': 'Dulces y postres'},
      {'nombre': 'Sopas', 'descripcion': 'Sopas y caldos'},
      {'nombre': 'Carnes', 'descripcion': 'Platos de carne'},
      {'nombre': 'Pollo', 'descripcion': 'Platos de pollo'},
      {'nombre': 'Pescados', 'descripcion': 'Platos de pescado y mariscos'},
      {'nombre': 'Vegetariano', 'descripcion': 'Platos vegetarianos'},
      {'nombre': 'Acompañamientos', 'descripcion': 'Guarniciones y acompañamientos'},
    ];

    print('🗂️ Creando categorías básicas...');
    
    for (var catData in categoriasBasicas) {
      try {
        final categoria = Categoria(
          id: '', // Se generará automáticamente
          nombre: catData['nombre']!,
          descripcion: catData['descripcion']!,
        );
        
        await _productoService.createCategoria(categoria);
        print('✅ Categoría creada: ${categoria.nombre}');
        
        // Pequeño delay para evitar sobrecarga
        await Future.delayed(Duration(milliseconds: 100));
        
      } catch (e) {
        print('⚠️ Error creando categoría ${catData['nombre']}: $e');
      }
    }
  }

  /// Carga masiva de productos desde una lista
  Future<void> cargarProductosMasivamente(List<Map<String, dynamic>> productosData) async {
    // Obtener IDs de categorías
    final idsCategorias = await obtenerIdsCategorias();
    
    print('📦 Iniciando carga masiva de ${productosData.length} productos...');
    
    int exitosos = 0;
    int errores = 0;
    
    for (var prodData in productosData) {
      try {
        final categoriaId = idsCategorias[prodData['categoria']] ?? '';
        
        final producto = Producto(
          id: '', // Se generará automáticamente
          nombre: prodData['nombre'],
          descripcion: prodData['descripcion'] ?? '',
          precio: (prodData['precio'] as num).toDouble(),
          categoria: categoriaId,
          disponible: prodData['disponible'] ?? true,
          imagen: prodData['imagen'] ?? '',
          ingredientes: [], // Se pueden agregar después
          tiempoPreparacion: prodData['tiempoPreparacion'] ?? 15,
        );
        
        await _productoService.createProducto(producto);
        exitosos++;
        print('✅ Producto $exitosos creado: ${producto.nombre}');
        
        // Pequeño delay para evitar sobrecarga del servidor
        await Future.delayed(Duration(milliseconds: 100));
        
      } catch (e) {
        errores++;
        print('❌ Error creando producto ${prodData['nombre']}: $e');
      }
    }
    
    print('\n📊 Resumen de carga masiva:');
    print('  ✅ Exitosos: $exitosos');
    print('  ❌ Errores: $errores');
    print('  📈 Total: ${productosData.length}');
  }

  /// Método de utilidad para mostrar todas las opciones disponibles
  void mostrarOpcionesCargaMasiva() {
    print('\n🚀 OPCIONES DE CARGA MASIVA DISPONIBLES:');
    print('=' * 50);
    print('1. 🗂️  crearCategoriasBasicas() - Crear categorías predefinidas');
    print('2. 📋  obtenerIdsCategorias() - Ver IDs de categorías');
    print('3. 🔍  obtenerIdsIngredientes() - Ver IDs de ingredientes');
    print('4. 📦  cargarProductosMasivamente(data) - Cargar lista de productos');
    print('=' * 50);
  }
}
