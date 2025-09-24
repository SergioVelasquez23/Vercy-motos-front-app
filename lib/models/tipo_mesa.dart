/// Enumeración para los tipos de mesa disponibles en el sistema
///
/// Define los diferentes tipos de mesa que pueden existir
/// con comportamientos y características específicas.
library;

enum TipoMesa {
  normal('Mesa Normal', 'Mesa estándar para servicio regular'),
  especial('Mesa Especial', 'Mesa con características o precios especiales'),
  auxiliar('Mesa Auxiliar', 'Mesa auxiliar para pedidos especiales'),
  terraza('Mesa Terraza', 'Mesa ubicada en terraza o área exterior'),
  vip('Mesa VIP', 'Mesa para clientes VIP con servicio premium'),
  privada('Mesa Privada', 'Mesa en área privada o reservada');

  const TipoMesa(this.nombre, this.descripcion);

  final String nombre;
  final String descripcion;

  /// Obtiene el icono asociado al tipo de mesa
  String get icono {
    switch (this) {
      case TipoMesa.normal:
        return 'table_restaurant';
      case TipoMesa.especial:
        return 'star';
      case TipoMesa.auxiliar:
        return 'help_outline';
      case TipoMesa.terraza:
        return 'deck';
      case TipoMesa.vip:
        return 'workspace_premium';
      case TipoMesa.privada:
        return 'meeting_room';
    }
  }

  /// Obtiene el color asociado al tipo de mesa
  int get colorValue {
    switch (this) {
      case TipoMesa.normal:
        return 0xFF2196F3; // Azul
      case TipoMesa.especial:
        return 0xFFFF9800; // Naranja
      case TipoMesa.auxiliar:
        return 0xFF9C27B0; // Púrpura
      case TipoMesa.terraza:
        return 0xFF4CAF50; // Verde
      case TipoMesa.vip:
        return 0xFFE91E63; // Rosa
      case TipoMesa.privada:
        return 0xFF795548; // Marrón
    }
  }

  /// Indica si este tipo de mesa tiene recargo adicional
  bool get tieneRecargo {
    switch (this) {
      case TipoMesa.especial:
      case TipoMesa.vip:
      case TipoMesa.privada:
        return true;
      case TipoMesa.normal:
      case TipoMesa.auxiliar:
      case TipoMesa.terraza:
        return false;
    }
  }

  /// Obtiene el porcentaje de recargo para este tipo de mesa
  double get porcentajeRecargo {
    switch (this) {
      case TipoMesa.especial:
        return 0.05; // 5%
      case TipoMesa.vip:
        return 0.15; // 15%
      case TipoMesa.privada:
        return 0.10; // 10%
      case TipoMesa.normal:
      case TipoMesa.auxiliar:
      case TipoMesa.terraza:
        return 0.0; // Sin recargo
    }
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'tipo': name,
      'nombre': nombre,
      'descripcion': descripcion,
      'icono': icono,
      'colorValue': colorValue,
      'tieneRecargo': tieneRecargo,
      'porcentajeRecargo': porcentajeRecargo,
    };
  }

  /// Crea desde JSON
  static TipoMesa fromJson(Map<String, dynamic> json) {
    final tipo = json['tipo'] as String?;
    return TipoMesa.values.firstWhere(
      (t) => t.name == tipo,
      orElse: () => TipoMesa.normal,
    );
  }

  /// Obtiene todos los tipos de mesa disponibles para selección
  static List<TipoMesa> get tiposDisponibles => [
    TipoMesa.normal,
    TipoMesa.especial,
    TipoMesa.terraza,
    TipoMesa.vip,
    TipoMesa.privada,
  ];
}