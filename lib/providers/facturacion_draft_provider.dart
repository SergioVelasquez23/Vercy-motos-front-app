import 'dart:async';
import 'package:flutter/material.dart';
import '../models/item_pedido.dart';
import '../models/cliente.dart';

/// Provider para mantener el estado del borrador de facturación
///
/// Características:
/// - Persiste items del pedido al navegar entre pantallas
/// - Mantiene cliente seleccionado
/// - Permite restaurar el estado al regresar a facturación
class FacturacionDraftProvider extends ChangeNotifier {
  static final FacturacionDraftProvider _instance =
      FacturacionDraftProvider._internal();
  factory FacturacionDraftProvider() => _instance;
  FacturacionDraftProvider._internal();

  // 📝 ESTADO DEL BORRADOR
  List<ItemPedido> _items = [];
  Cliente? _clienteSeleccionado;
  String _clienteNombre = 'CONSUMIDOR FINAL';
  String _metodoPago = 'efectivo';
  String _tipoFactura = 'POS';
  String _origenSeleccionado = 'ALMACÉN';
  DateTime _fechaFactura = DateTime.now();
  DateTime _fechaVencimiento = DateTime.now().add(Duration(days: 30));

  // 📝 DATOS EXTRAS
  String? _ordenCompra;
  String? _ordenServicio;
  String? _ordenPedido;
  String? _vendedor;
  String? _guia;
  String? _observaciones;

  // 📝 PAGOS MÚLTIPLES
  Map<String, double> _montosPago = {
    'efectivo': 0,
    'transferencia': 0,
    'tarjeta': 0,
    'sistecredito': 0,
    'datafono': 0,
  };

  // 📝 RETENCIONES
  double _retencion = 0;
  double _reteIVA = 0;
  double _reteICA = 0;
  double _aiu = 0;
  double _dctoGeneral = 0;

  // 🔄 SINCRONIZACIÓN
  Timer? _syncTimer;
  bool _enableSync = false; // Deshabilitado por ahora

  // GETTERS
  List<ItemPedido> get items => List.unmodifiable(_items);
  Cliente? get clienteSeleccionado => _clienteSeleccionado;
  String get clienteNombre => _clienteNombre;
  String get metodoPago => _metodoPago;
  String get tipoFactura => _tipoFactura;
  String get origenSeleccionado => _origenSeleccionado;
  DateTime get fechaFactura => _fechaFactura;
  DateTime get fechaVencimiento => _fechaVencimiento;

  String? get ordenCompra => _ordenCompra;
  String? get ordenServicio => _ordenServicio;
  String? get ordenPedido => _ordenPedido;
  String? get vendedor => _vendedor;
  String? get guia => _guia;
  String? get observaciones => _observaciones;

  Map<String, double> get montosPago => Map.unmodifiable(_montosPago);

  double get retencion => _retencion;
  double get reteIVA => _reteIVA;
  double get reteICA => _reteICA;
  double get aiu => _aiu;
  double get dctoGeneral => _dctoGeneral;

  bool get hasDraft => _items.isNotEmpty || _clienteSeleccionado != null;
  int get itemsCount => _items.length;

  // SETTERS
  void setMetodoPago(String metodo) {
    _metodoPago = metodo;
    notifyListeners();
  }

  void setTipoFactura(String tipo) {
    _tipoFactura = tipo;
    notifyListeners();
  }

  void setOrigenSeleccionado(String origen) {
    _origenSeleccionado = origen;
    notifyListeners();
  }

  void setFechaFactura(DateTime fecha) {
    _fechaFactura = fecha;
    notifyListeners();
  }

  void setFechaVencimiento(DateTime fecha) {
    _fechaVencimiento = fecha;
    notifyListeners();
  }

  void setCliente(Cliente? cliente, String nombre) {
    _clienteSeleccionado = cliente;
    _clienteNombre = nombre;
    notifyListeners();
  }

  // DATOS EXTRAS
  void setOrdenCompra(String? valor) {
    _ordenCompra = valor;
    notifyListeners();
  }

  void setOrdenServicio(String? valor) {
    _ordenServicio = valor;
    notifyListeners();
  }

  void setOrdenPedido(String? valor) {
    _ordenPedido = valor;
    notifyListeners();
  }

  void setVendedor(String? valor) {
    _vendedor = valor;
    notifyListeners();
  }

  void setGuia(String? valor) {
    _guia = valor;
    notifyListeners();
  }

  void setObservaciones(String? valor) {
    _observaciones = valor;
    notifyListeners();
  }

  // MONTOS DE PAGO
  void setMontoPago(String metodo, double monto) {
    _montosPago[metodo] = monto;
    notifyListeners();
  }

  void setMontosPago(Map<String, double> montos) {
    _montosPago = Map.from(montos);
    notifyListeners();
  }

  // RETENCIONES
  void setRetencion(double valor) {
    _retencion = valor;
    notifyListeners();
  }

  void setReteIVA(double valor) {
    _reteIVA = valor;
    notifyListeners();
  }

  void setReteICA(double valor) {
    _reteICA = valor;
    notifyListeners();
  }

  void setAiu(double valor) {
    _aiu = valor;
    notifyListeners();
  }

  void setDctoGeneral(double valor) {
    _dctoGeneral = valor;
    notifyListeners();
  }

  // 📦 GESTIÓN DE ITEMS
  void addItem(ItemPedido item) {
    _items.add(item);
    notifyListeners();
    print(
      '✅ Item agregado al borrador: ${item.productoNombre} x${item.cantidad}',
    );
  }

  void updateItem(int index, ItemPedido item) {
    if (index >= 0 && index < _items.length) {
      _items[index] = item;
      notifyListeners();
      print('✅ Item actualizado en borrador: ${item.productoNombre}');
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      final item = _items[index];
      _items.removeAt(index);
      notifyListeners();
      print('❌ Item eliminado del borrador: ${item.productoNombre}');
    }
  }

  void clearItems() {
    _items.clear();
    notifyListeners();
    print('🗑️ Items del borrador limpiados');
  }

  void setItems(List<ItemPedido> items) {
    _items = List.from(items);
    notifyListeners();
    print('📝 Borrador actualizado: ${_items.length} items');
  }

  // 🔄 SINCRONIZACIÓN (simplificada - solo control de timer)
  void startSync() {
    if (!_enableSync) {
      print('ℹ️  Sincronización automática deshabilitada');
      return;
    }

    _syncTimer?.cancel();
    print('🔄 Sincronización iniciada');

    // Por ahora solo un placeholder
    _syncTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      print('🔄 Tick de sincronización (no implementado)');
    });
  }

  void stopSync() {
    _syncTimer?.cancel();
    print('⏸️ Sincronización detenida');
  }

  /// Forzar sincronización manual (placeholder)
  Future<void> forceSync() async {
    print('🔄 Sincronización manual (no implementado)');
  }

  // 🗑️ LIMPIAR TODO EL BORRADOR
  void clearDraft() {
    _items.clear();
    _clienteSeleccionado = null;
    _clienteNombre = 'CONSUMIDOR FINAL';
    _metodoPago = 'efectivo';
    _tipoFactura = 'POS';
    _origenSeleccionado = 'ALMACÉN';
    _fechaFactura = DateTime.now();
    _fechaVencimiento = DateTime.now().add(Duration(days: 30));

    _ordenCompra = null;
    _ordenServicio = null;
    _ordenPedido = null;
    _vendedor = null;
    _guia = null;
    _observaciones = null;

    _montosPago = {
      'efectivo': 0,
      'transferencia': 0,
      'tarjeta': 0,
      'sistecredito': 0,
      'datafono': 0,
    };

    _retencion = 0;
    _reteIVA = 0;
    _reteICA = 0;
    _aiu = 0;
    _dctoGeneral = 0;

    notifyListeners();
    print('🗑️ Borrador limpiado completamente');
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
