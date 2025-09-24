import 'producto.dart';
import 'pedido.dart';
import 'tipo_mesa.dart';

/// Modelo de datos para una Mesa en el sistema de pedidos
class Mesa {
  final String _id;
  final String _nombre;
  final TipoMesa _tipo;
  bool _ocupada;
  double _total;
  List<Producto> _productos;
  Pedido? _pedidoActual;

  // Getters
  String get id => _id;
  String get mongoId => _id;
  String get nombre => _nombre;
  TipoMesa get tipo => _tipo;
  bool get ocupada => _ocupada;
  double get total => _total;
  List<Producto> get productos => _productos;
  Pedido? get pedidoActual => _pedidoActual;

  // Setters
  set ocupada(bool value) => _ocupada = value;
  set total(double value) => _total = value;
  set productos(List<Producto> value) => _productos = value;
  set pedidoActual(Pedido? value) => _pedidoActual = value;

  Mesa({
    required String id,
    required String nombre,
    TipoMesa tipo = TipoMesa.normal,
    bool ocupada = false,
    double total = 0.0,
    List<Producto>? productos,
    Pedido? pedidoActual,
  }) : _id = id,
       _nombre = nombre,
       _tipo = tipo,
       _ocupada = ocupada,
       _total = total,
       _productos = productos ?? [],
       _pedidoActual = pedidoActual;

  Mesa copyWith({
    String? id,
    String? nombre,
    TipoMesa? tipo,
    bool? ocupada,
    double? total,
    List<Producto>? productos,
    Pedido? pedidoActual,
  }) {
    return Mesa(
      id: id ?? _id,
      nombre: nombre ?? _nombre,
      tipo: tipo ?? _tipo,
      ocupada: ocupada ?? _ocupada,
      total: total ?? _total,
      productos: productos ?? List.from(_productos),
      pedidoActual: pedidoActual ?? _pedidoActual,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': _id,
    'nombre': _nombre,
    'tipo': _tipo.name,
    'ocupada': _ocupada,
    'total': _total,
    'productos': _productos.map((p) => p.toJson()).toList(),
    'pedidoActual': _pedidoActual?.toJson(),
  };

  factory Mesa.fromJson(Map<String, dynamic> json) {
    return Mesa(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      tipo: TipoMesa.values.firstWhere(
        (tipo) => tipo.name == json['tipo'],
        orElse: () => TipoMesa.normal,
      ),
      ocupada: json['ocupada'] ?? false,
      total: (json['total'] ?? 0.0).toDouble(),
      productos:
          (json['productos'] as List<dynamic>?)
              ?.map((p) => Producto.fromJson(p))
              .toList() ??
          [],
      pedidoActual: json['pedidoActual'] != null
          ? Pedido.fromJson(json['pedidoActual'])
          : null,
    );
  }
}
