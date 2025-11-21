/// Configuración centralizada para mesas especiales hardcodeadas
///
/// Esta clase mantiene la lista de mesas especiales que necesitan
/// comportamiento especial en la aplicación.
class MesasEspecialesConfig {
  // Lista mutable de mesas especiales hardcodeadas
  static final List<String> _mesasEspeciales = [
    'DOMICILIO',
    'CAJA',
    'MESA AUXILIAR',
    'DEUDAS',
  ];

  /// Obtiene la lista actual de mesas especiales hardcodeadas
  static List<String> get mesasEspeciales =>
      List.unmodifiable(_mesasEspeciales);

  /// Agrega una nueva mesa especial a la lista hardcodeada
  /// [nombreMesa] debe estar en MAYÚSCULAS
  static void agregarMesaEspecial(String nombreMesa) {
    final nombreUpper = nombreMesa.toUpperCase();
    if (!_mesasEspeciales.contains(nombreUpper)) {
      _mesasEspeciales.add(nombreUpper);
      print('✅ Mesa especial "$nombreUpper" agregada a la lista hardcodeada');
    }
  }

  /// Verifica si una mesa está en la lista de mesas especiales hardcodeadas
  static bool esMesaEspecialHardcodeada(String nombreMesa) {
    return _mesasEspeciales.contains(nombreMesa.toUpperCase());
  }

  /// Remueve una mesa especial de la lista hardcodeada (si es necesario)
  static void removerMesaEspecial(String nombreMesa) {
    final nombreUpper = nombreMesa.toUpperCase();
    // No permitir remover las mesas predefinidas del sistema
    final mesasPredefinidas = ['DOMICILIO', 'CAJA', 'MESA AUXILIAR', 'DEUDAS'];
    if (!mesasPredefinidas.contains(nombreUpper)) {
      _mesasEspeciales.remove(nombreUpper);
      print('✅ Mesa especial "$nombreUpper" removida de la lista hardcodeada');
    }
  }
}
