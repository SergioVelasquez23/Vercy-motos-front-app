import 'producto.dart';
import 'pedido.dart';

/// Modelo de datos para una Mesa en el sistema de pedidos
class Mesa {
  final String _id;
  final String _nombre;
  bool _ocupada;
  double _total;
  List<Producto> _productos;
  Pedido? _pedidoActual;

  // Getters
  String get id => _id;
  String get mongoId => _id;
  String get nombre => _nombre;
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
    bool ocupada = false,
    double total = 0.0,
    List<Producto>? productos,
    Pedido? pedidoActual,
  }) : _id = id,
       _nombre = nombre,
       _ocupada = ocupada,
       _total = total,
       _productos = productos ?? [],
       _pedidoActual = pedidoActual {}

  Mesa copyWith({
    String? id,
    String? nombre,
    bool? ocupada,
    double? total,
    List<Producto>? productos,
    Pedido? pedidoActual,
  }) {
    return Mesa(
      id: id ?? this._id,
      nombre: nombre ?? this._nombre,
      ocupada: ocupada ?? this._ocupada,
      total: total ?? this._total,
      productos: productos ?? List.from(this._productos),
      pedidoActual: pedidoActual ?? this._pedidoActual,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': _id,
    'nombre': _nombre,
    'ocupada': _ocupada,
    'total': _total,
    'productos': _productos.map((p) => p.toJson()).toList(),
    'pedidoActual': _pedidoActual?.toJson(),
  };

  factory Mesa.fromJson(Map<String, dynamic> json) {
    return Mesa(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
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
