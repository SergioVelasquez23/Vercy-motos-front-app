import 'package:flutter/material.dart';

/// Guarda el último Resumen del Libro Contable generado para que sobreviva a
/// la navegación: si el usuario sale de la pantalla (p. ej. a revisar algo
/// mientras analiza el resumen) y vuelve, encuentra el mismo resumen como un
/// borrador — sin tener que reelegir el rango y esperar a que cargue de
/// nuevo. Se reemplaza solo cuando el usuario genera un resumen nuevo.
class LibroContableResumenDraftProvider extends ChangeNotifier {
  DateTimeRange? _rango;
  Map<String, dynamic>? _libroContable;
  Map<String, dynamic>? _rentabilidadProductos;
  List<dynamic>? _recomendaciones;

  DateTimeRange? get rango => _rango;
  Map<String, dynamic>? get libroContable => _libroContable;
  Map<String, dynamic>? get rentabilidadProductos => _rentabilidadProductos;
  List<dynamic>? get recomendaciones => _recomendaciones;

  bool get hasDraft => _libroContable != null;

  void guardar({
    required DateTimeRange rango,
    required Map<String, dynamic> libroContable,
    required Map<String, dynamic> rentabilidadProductos,
    required List<dynamic> recomendaciones,
  }) {
    _rango = rango;
    _libroContable = libroContable;
    _rentabilidadProductos = rentabilidadProductos;
    _recomendaciones = recomendaciones;
    notifyListeners();
  }

  void limpiar() {
    _rango = null;
    _libroContable = null;
    _rentabilidadProductos = null;
    _recomendaciones = null;
    notifyListeners();
  }
}
