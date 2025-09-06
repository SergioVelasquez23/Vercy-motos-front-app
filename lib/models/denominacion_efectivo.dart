class DenominacionEfectivo {
  final int valor;
  final String tipo; // 'billete' o 'moneda'
  int cantidad;
  final String imagen; // Path para la imagen si se quiere agregar después

  DenominacionEfectivo({
    required this.valor,
    required this.tipo,
    this.cantidad = 0,
    this.imagen = '',
  });

  double get total => valor * cantidad.toDouble();

  // Formatear el valor para mostrar (ej: $100.000)
  String get valorFormateado {
    if (valor >= 1000) {
      // Para valores >= 1000, formatear con puntos
      String formatted = valor.toString();
      if (valor >= 10000) {
        // Para valores >= 10000, usar formato con puntos
        int thousands = valor ~/ 1000;
        int remainder = valor % 1000;
        formatted = '$thousands.${remainder.toString().padLeft(3, '0')}';
      } else if (valor >= 1000) {
        // Para valores entre 1000-9999
        formatted = '${valor ~/ 1000}.${(valor % 1000).toString().padLeft(3, '0')}';
      }
      return '\$$formatted';
    }
    return '\$$valor';
  }

  // Copiar con nuevos valores
  DenominacionEfectivo copyWith({
    int? valor,
    String? tipo,
    int? cantidad,
    String? imagen,
  }) {
    return DenominacionEfectivo(
      valor: valor ?? this.valor,
      tipo: tipo ?? this.tipo,
      cantidad: cantidad ?? this.cantidad,
      imagen: imagen ?? this.imagen,
    );
  }

  // Convertir a Map para serialización
  Map<String, dynamic> toMap() {
    return {
      'valor': valor,
      'tipo': tipo,
      'cantidad': cantidad,
      'imagen': imagen,
    };
  }

  // Crear desde Map
  factory DenominacionEfectivo.fromMap(Map<String, dynamic> map) {
    return DenominacionEfectivo(
      valor: map['valor']?.toInt() ?? 0,
      tipo: map['tipo'] ?? '',
      cantidad: map['cantidad']?.toInt() ?? 0,
      imagen: map['imagen'] ?? '',
    );
  }

  @override
  String toString() {
    return 'DenominacionEfectivo(valor: $valor, tipo: $tipo, cantidad: $cantidad)';
  }
}

class ContadorEfectivo {
  static List<DenominacionEfectivo> obtenerDenominacionesStandard() {
    return [
      // Billetes (ordenados de mayor a menor)
      DenominacionEfectivo(valor: 100000, tipo: 'billete'),
      DenominacionEfectivo(valor: 50000, tipo: 'billete'),
      DenominacionEfectivo(valor: 20000, tipo: 'billete'),
      DenominacionEfectivo(valor: 10000, tipo: 'billete'),
      DenominacionEfectivo(valor: 5000, tipo: 'billete'),
      DenominacionEfectivo(valor: 2000, tipo: 'billete'),
      DenominacionEfectivo(valor: 1000, tipo: 'billete'),
      
      // Monedas (ordenadas de mayor a menor)
      DenominacionEfectivo(valor: 1000, tipo: 'moneda'),
      DenominacionEfectivo(valor: 500, tipo: 'moneda'),
      DenominacionEfectivo(valor: 200, tipo: 'moneda'),
      DenominacionEfectivo(valor: 100, tipo: 'moneda'),
      DenominacionEfectivo(valor: 50, tipo: 'moneda'),
    ];
  }

  static double calcularTotal(List<DenominacionEfectivo> denominaciones) {
    return denominaciones.fold(0.0, (sum, denominacion) => sum + denominacion.total);
  }

  static Map<String, double> obtenerTotalesPorTipo(List<DenominacionEfectivo> denominaciones) {
    double totalBilletes = 0.0;
    double totalMonedas = 0.0;

    for (var denominacion in denominaciones) {
      if (denominacion.tipo == 'billete') {
        totalBilletes += denominacion.total;
      } else if (denominacion.tipo == 'moneda') {
        totalMonedas += denominacion.total;
      }
    }

    return {
      'billetes': totalBilletes,
      'monedas': totalMonedas,
      'total': totalBilletes + totalMonedas,
    };
  }

  static void resetearCantidades(List<DenominacionEfectivo> denominaciones) {
    for (var denominacion in denominaciones) {
      denominacion.cantidad = 0;
    }
  }
}
