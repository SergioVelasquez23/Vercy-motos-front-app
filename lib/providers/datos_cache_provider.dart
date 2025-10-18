import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/ingrediente.dart';
import '../services/producto_service.dart';
import '../services/ingrediente_service.dart';
import '../config/api_config.dart';

class DatosCacheProvider extends ChangeNotifier {
  static final DatosCacheProvider _instance = DatosCacheProvider._internal();
  factory DatosCacheProvider() => _instance;
  DatosCacheProvider._internal();

  // Datos en caché
  List<Producto>? _productos;
  List<Categoria>? _categorias;
  List<Ingrediente>? _ingredientes;

  // Estados de carga
  bool _isLoadingProductos = false;
  bool _isLoadingCategorias = false;
  bool _isLoadingIngredientes = false;

  // WebSocket
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;

  // Servicios
  final ProductoService _productoService = ProductoService();
  final IngredienteService _ingredienteService = IngredienteService();

  // Getters
  List<Producto>? get productos => _productos;
  List<Categoria>? get categorias => _categorias;
  List<Ingrediente>? get ingredientes => _ingredientes;

  bool get isLoadingProductos => _isLoadingProductos;
  bool get isLoadingCategorias => _isLoadingCategorias;
  bool get isLoadingIngredientes => _isLoadingIngredientes;
  bool get isConnected => _isConnected;

  bool get hasData =>
      _productos != null && _categorias != null && _ingredientes != null;

  // Inicializar el provider
  Future<void> initialize() async {
    print('🚀 Inicializando DatosCacheProvider...');
    await _cargarTodosLosDatos();
    _connectWebSocket();
  }

  // Cargar todos los datos en paralelo
  Future<void> _cargarTodosLosDatos() async {
    print('📊 Cargando datos frescos en caché...');

    try {
      await Future.wait([
        _cargarProductos(),
        _cargarCategorias(),
        _cargarIngredientes(),
      ]);

      print('✅ Todos los datos cargados en caché exitosamente');
      print('   - Productos: ${_productos?.length ?? 0}');
      print('   - Categorías: ${_categorias?.length ?? 0}');
      print('   - Ingredientes: ${_ingredientes?.length ?? 0}');
    } catch (e) {
      print('❌ Error cargando datos: $e');
    }
  }

  // Cargar productos
  Future<void> _cargarProductos() async {
    if (_isLoadingProductos) return;

    _isLoadingProductos = true;
    notifyListeners();

    try {
      final productos = await _productoService.getProductos();
      _productos = productos;
      print('📦 Productos cargados: ${productos.length}');
    } catch (e) {
      print('❌ Error cargando productos: $e');
    } finally {
      _isLoadingProductos = false;
      notifyListeners();
    }
  }

  // Cargar categorías
  Future<void> _cargarCategorias() async {
    if (_isLoadingCategorias) return;

    _isLoadingCategorias = true;
    notifyListeners();

    try {
      final categorias = await _productoService.getCategorias();
      _categorias = categorias;
      print('🏷️ Categorías cargadas: ${categorias.length}');
    } catch (e) {
      print('❌ Error cargando categorías: $e');
    } finally {
      _isLoadingCategorias = false;
      notifyListeners();
    }
  }

  // Cargar ingredientes
  Future<void> _cargarIngredientes() async {
    if (_isLoadingIngredientes) return;

    _isLoadingIngredientes = true;
    notifyListeners();

    try {
      final ingredientes = await _ingredienteService.getAllIngredientes();
      _ingredientes = ingredientes;
      print('🥬 Ingredientes cargados: ${ingredientes.length}');
    } catch (e) {
      print('❌ Error cargando ingredientes: $e');
    } finally {
      _isLoadingIngredientes = false;
      notifyListeners();
    }
  }

  // Conectar WebSocket
  void _connectWebSocket() {
    try {
      final baseUrl = ApiConfig.instance.baseUrl;
      final wsUrl = baseUrl.replaceFirst('http', 'ws') + '/ws/updates';

      print('🔌 Conectando WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      notifyListeners();

      _channel!.stream.listen(
        (message) {
          print('📡 WebSocket mensaje recibido: $message');
          _handleWebSocketMessage(message);
        },
        onDone: () {
          print('🔌 WebSocket desconectado');
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _isConnected = false;

          // ✅ MEJORADO: Manejo más robusto de errores
          try {
            notifyListeners();
          } catch (e) {
            print('⚠️ Error notificando listeners: $e');
          }

          // No reconectar inmediatamente si hay muchos errores
          if (_reconnectAttempts < 10) {
            _scheduleReconnect();
          } else {
            print('🛑 Demasiados intentos de reconexión, pausando...');
            Future.delayed(Duration(minutes: 1), () {
              _reconnectAttempts = 0;
              _scheduleReconnect();
            });
          }
        },
      );

      print('✅ WebSocket conectado exitosamente');
      _reconnectAttempts = 0; // ✅ Resetear contador al conectar exitosamente
    } catch (e) {
      print('❌ Error conectando WebSocket: $e');
      _scheduleReconnect();
    }
  }

  // Manejar mensajes del WebSocket
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = json.decode(message);
      final type = data['type'];

      print('📨 Procesando actualización: $type');

      switch (type) {
        case 'productos_updated':
          print('🔄 Recargando productos por actualización...');
          _cargarProductos();
          break;
        case 'categorias_updated':
          print('🔄 Recargando categorías por actualización...');
          _cargarCategorias();
          break;
        case 'ingredientes_updated':
          print('🔄 Recargando ingredientes por actualización...');
          _cargarIngredientes();
          break;
        case 'full_reload':
          print('🔄 Recargando todos los datos por actualización completa...');
          _cargarTodosLosDatos();
          break;
        default:
          print('⚠️ Tipo de mensaje desconocido: $type');
      }
    } catch (e) {
      print('❌ Error procesando mensaje WebSocket: $e');
    }
  }

  // Programar reconexión
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    _reconnectAttempts++;

    if (_reconnectAttempts > 10) {
      print(
        '⚠️ Máximo número de intentos de reconexión alcanzado. Pausando por 1 minuto...',
      );
      _reconnectTimer = Timer(Duration(minutes: 1), () {
        _reconnectAttempts = 0;
        _scheduleReconnect();
      });
      return;
    }

    final delay = Duration(seconds: 5 * _reconnectAttempts);
    print(
      '🔄 Programando reconexión WebSocket (intento $_reconnectAttempts) en ${delay.inSeconds} segundos...',
    );

    _reconnectTimer = Timer(delay, () {
      print(
        '🔄 Intentando reconectar WebSocket (intento $_reconnectAttempts)...',
      );
      _connectWebSocket();
    });
  }

  // Recargar datos manualmente
  Future<void> recargarDatos() async {
    print('🔄 Recarga manual solicitada...');
    await _cargarTodosLosDatos();
  }

  // Limpiar caché
  void limpiarCache() {
    print('🗑️ Limpiando caché...');
    _productos = null;
    _categorias = null;
    _ingredientes = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
