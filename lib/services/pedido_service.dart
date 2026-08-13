import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async'; // Importar para usar StreamController
import 'package:flutter/foundation.dart';
import '../utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '../models/pedido.dart';
import '../utils/pedido_helper.dart'; // Añadido import
import '../services/producto_service.dart';
import '../services/inventario_service.dart'; // Para manejar descuento de ingredientes
import '../models/producto.dart';
import '../models/item_pedido.dart';
import '../models/cancelar_producto_request.dart'; // Para cancelaciones selectivas
import '../config/api_config.dart';
import '../services/cuadre_caja_service.dart'; // Para validar caja abierta
import '../utils/logger.dart';
import '../utils/api_error.dart';
import '../utils/datetime_utils.dart';

class PedidoService {
  static final PedidoService _instance = PedidoService._internal();
  factory PedidoService() => _instance;

  final _pedidoCompletadoController = StreamController<bool>.broadcast();
  Stream<bool> get onPedidoCompletado => _pedidoCompletadoController.stream;

  final _pedidoPagadoController = StreamController<bool>.broadcast();
  Stream<bool> get onPedidoPagado => _pedidoPagadoController.stream;

  // Mantener un caché local de pedidos para actualizaciones rápidas
  final Map<String, Pedido> _pedidosCache = {};

  // ✅ NUEVO: Cache para evitar correcciones de estado en bucle
  final Map<String, DateTime> _estadoCorregidoCache = {};
  
  String? _cuadreIdActivo;

  final InventarioService _inventarioService = InventarioService();
  final CuadreCajaService _cuadreCajaService = CuadreCajaService();

  PedidoService._internal() {
    // PedidoService: Inicializando servicio y StreamControllers
  }

  void dispose() {
    // PedidoService: Cerrando StreamControllers
    _pedidoCompletadoController.close();
    _pedidoPagadoController.close();
  }

  /// Actualiza el estado de un pedido en la caché local
  /// Útil para asegurar que el estado se refleje correctamente en la UI
  /// independientemente de la respuesta del servidor
  Future<void> updateEstadoPedidoLocal(
    String pedidoId,
    EstadoPedido nuevoEstado,
  ) async {
    try {
         
      // Buscar el pedido en caché si existe
      Pedido? pedido = _pedidosCache[pedidoId];

      // Si no está en caché, intentar obtenerlo del servidor
      if (pedido == null) {
        final pedidoActualizado = await getPedidoById(pedidoId);
        if (pedidoActualizado != null) {
          // Actualizar el estado y guardar en caché
          pedidoActualizado.estado = nuevoEstado;
          _pedidosCache[pedidoId] = pedidoActualizado;
            
        }
      } else {
        // Actualizar el pedido existente en caché
        pedido.estado = nuevoEstado;
        _pedidosCache[pedidoId] = pedido;
          
      }

      // Notificar el cambio para actualizar la UI
      _pedidoPagadoController.add(true);
    } catch (e) {
        
    }
  }

  /// Helper para formatear fechas de manera consistente con el backend
  /// ULTRA-ROBUSTO: Nunca falla el formateo de fecha
  String _formatearFechaParaBackend(DateTime fecha) {
    try {
      // Asegurar que sea hora local y válida
      final fechaLocal = fecha.toLocal();

      // Validar que la fecha esté en un rango razonable
      if (fechaLocal.year < 1900 || fechaLocal.year > 2100) {
                   final fechaActual = DateTime.now().toLocal();
        return _formatoManualFecha(fechaActual);
      }

      // Formateo manual SIEMPRE para evitar problemas de locale
      return _formatoManualFecha(fechaLocal);
    } catch (e) {
        
        
      // Fallback absoluto: usar fecha actual con formateo manual
      try {
        final fechaActual = DateTime.now().toLocal();
        return _formatoManualFecha(fechaActual);
      } catch (e2) {
          
        // Último recurso: formato ISO básico hardcodeado
        final now = DateTime.now();
        return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      }
    }
  }

  /// Formateo manual de fecha ULTRA-SEGURO
  String _formatoManualFecha(DateTime fecha) {
    try {
      // Formato: yyyy-MM-ddTHH:mm:ss
      final year = fecha.year.toString().padLeft(4, '0');
      final month = fecha.month.toString().padLeft(2, '0');
      final day = fecha.day.toString().padLeft(2, '0');
      final hour = fecha.hour.toString().padLeft(2, '0');
      final minute = fecha.minute.toString().padLeft(2, '0');
      final second = fecha.second.toString().padLeft(2, '0');

      final resultado = '$year-$month-${day}T$hour:$minute:$second';

      // Validar que el resultado tenga el formato correcto
      if (!RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$',
      ).hasMatch(resultado)) {
          
        // Fallback con valores predeterminados si algo salió mal
        return '${DateTime.now().year}-01-01T00:00:00';
      }

      return resultado;
    } catch (e) {
        
      return '${DateTime.now().year}-01-01T00:00:00';
    }
  }

  String get baseUrl => ApiConfig.instance.baseUrl;
  final storage = FlutterSecureStorage();
  final ProductoService _productoService = ProductoService();

  // Obtener token del storage
  Future<String?> _getToken() async {
    try {
      if (kIsWeb) {
        return html.window.localStorage['jwt_token'];
      } else {
        return await storage.read(key: 'jwt_token');
      }
    } catch (e) {
        
      return null;
    }
  }

  /// Obtener cuadreId activo — siempre consulta el backend (sin cache)
  /// para evitar que un cuadreId de caja cerrada sea enviado en pedidos.
  ///
  /// A propósito NO atrapa errores acá: null solo debe significar "se
  /// confirmó que no hay caja abierta", nunca "no se pudo verificar". Antes
  /// esto atrapaba cualquier excepción (red, timeout, backend caído) y
  /// devolvía null igual, así que un simple error de conexión terminaba
  /// mostrando "Debe abrir caja" con la caja abierta y todo. Quien llama a
  /// este método decide cómo mostrar el error real si la consulta falla.
  Future<String?> _getCuadreIdActivo() async {
    final cajaActiva = await _cuadreCajaService.getCajaActiva();
    appLog('[PedidoService] cajaActiva.id = ${cajaActiva?.id}');
    _cuadreIdActivo = cajaActiva?.id;
    return _cuadreIdActivo;
  }

  /// Resuelve el cuadreId activo distinguiendo "no hay caja abierta"
  /// (confirmado) de "no se pudo verificar" (error real) — ver
  /// _getCuadreIdActivo. Lanza el mensaje correcto para cada caso.
  Future<String> _requerirCuadreIdActivo() async {
    String? cuadreIdActivo;
    try {
      cuadreIdActivo = await _getCuadreIdActivo();
    } catch (e) {
      throw Exception(
        'No se pudo verificar si hay caja abierta (revisa tu conexión e '
        'intenta de nuevo). Detalle: ${errorMessage(e)}',
      );
    }

    if (cuadreIdActivo == null) {
      throw Exception(
        'Debe abrir caja para continuar. Para registrar pedidos primero debe abrir la caja del día.',
      );
    }
    return cuadreIdActivo;
  }

  void limpiarCacheCuadreId() {
    _cuadreIdActivo = null;
  }

  /// 🔥 Pre-calentar: obtener cuadreId activo anticipadamente para que
  /// createPedido no tenga que esperar al backend cuando el usuario facture.
  /// También sirve para despertar a Render del cold start.
  void preCachearCuadreId() {
    _getCuadreIdActivo()
        .then((_) {
          appLog('🔥 Pre-warm: cuadreId cacheado exitosamente');
        })
        .catchError((e) {
          appLog('⚠️ Pre-warm: error obteniendo cuadreId (no crítico): $e');
        });
  }

  // Función auxiliar para parsear respuestas de lista de pedidos
  List<Pedido> _parseListResponse(dynamic responseData) {
    try {
      List<Pedido> pedidos = [];
      List<dynamic> jsonList;

      if (responseData is Map<String, dynamic>) {
        // Si el backend indica error explícito, salir limpiamente
        if (responseData['success'] == false) return [];

        // Extraer la lista desde el wrapper ApiResponse o directamente
        dynamic rawList = responseData['pedidos'] ??
                          responseData['data'] ??
                          responseData['results'];

        if (rawList == null) return [];

        if (rawList is List) {
          jsonList = rawList;
        } else if (rawList is Map) {
          // Formato anidado: data: {pedidos: [...], count: N}
          final nested = rawList['pedidos'] ?? rawList['items'] ?? rawList['data'];
          if (nested is List) {
            jsonList = nested;
          } else {
            return [];
          }
        } else {
          return [];
        }
      } else if (responseData is List) {
        jsonList = responseData;
      } else {
        return [];
      }

      // Log detallado para depuración de reportes
               int pedidosFiltrados = 0;

      // Convertir JSON a objetos Pedido
      pedidos = jsonList.map((json) {
        final pedido = Pedido.fromJson(json);
        final estadoOriginal = pedido.estado;
        final bool teoriaPagado = pedido.estaPagado;

        // Corregir estados inconsistentes
        if (pedido.estado == EstadoPedido.activo &&
            pedido.pagadoPor != null &&
            pedido.pagadoPor!.isNotEmpty) {
                         
          pedido.estado = EstadoPedido.pagado;
          pedidosFiltrados++;
        }

        // Verificar si el tipo es cortesía pero el estado no lo refleja
        if (pedido.tipo == TipoPedido.cortesia &&
            pedido.estado != EstadoPedido.cortesia) {
                         
          pedido.estado = EstadoPedido.cortesia;
        }

        // Si estado es "pendiente", convertirlo a activo o pagado según otros campos
        if (pedido.estado.toString().toLowerCase() == "pendiente") {
          if (pedido.pagadoPor != null && pedido.pagadoPor!.isNotEmpty) {
                             
            pedido.estado = EstadoPedido.pagado;
            pedidosFiltrados++;
          } else {
              
              
            pedido.estado = EstadoPedido.activo;
            pedidosFiltrados++;
          }
        }

        // Verificar inconsistencias adicionales para diagnóstico
        if (estadoOriginal != pedido.estado) {
            
            
            
            
            
            
                     }

        // Guardar en caché para acceso rápido
        if (pedido.id.isNotEmpty) {
          _pedidosCache[pedido.id] = pedido;
        }

        return pedido;
      }).toList();

      // Ordenar pedidos por fecha descendente (más recientes primero)
      pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));

      // Análisis de pedidos pagados para diagnóstico de ventas
      int pedidosPagados = 0;
      int pedidosActivos = 0;
      int pedidosCortesia = 0;
      int pedidosCancelados = 0;
      int pedidosConEstadoPagado = 0;
      int pedidosConPagadoPorSinEstadoPagado = 0;

      for (var pedido in pedidos) {
        final bool realmentePagado = pedido.estaPagado;

        if (realmentePagado) {
          pedidosPagados++;
        }

        if (pedido.estado == EstadoPedido.activo) {
          pedidosActivos++;
          // Verificar si tiene pagadoPor pero no está marcado como pagado
          if (pedido.pagadoPor != null && pedido.pagadoPor!.isNotEmpty) {
            pedidosConPagadoPorSinEstadoPagado++;
          }
        } else if (pedido.estado == EstadoPedido.pagado) {
          pedidosConEstadoPagado++;
        } else if (pedido.estado == EstadoPedido.cortesia) {
          pedidosCortesia++;
        } else if (pedido.estado == EstadoPedido.cancelado) {
          pedidosCancelados++;
        }
      }

      // Imprimir resumen para diagnóstico
        
        
        
                 
        
        
        

      // Cargar productos para cada pedido se ha removido para evitar llamadas masivas
      // El detalle del producto se obtendrá sólo cuando se desee imprimir o ver detalle.
      /*
      for (var pedido in pedidos) {
        cargarProductosParaPedido(pedido);
      }
      */

      return pedidos;
    } catch (e) {
        
      return [];
    }
  }

  // Headers con autenticación
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Obtener todos los pedidos (últimos 7 días por defecto - optimizado backend)
  // Para traer TODOS los pedidos históricos, usar getAllPedidosHistoricos()
  Future<List<Pedido>> getAllPedidos() async {
    try {
      final headers = await _getHeaders();
      // Por defecto el backend ahora solo trae pedidos de los últimos 7 días
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/pedidos/consultas'),
            headers: headers,
          )
          .timeout(const Duration(seconds: ApiConfig.requestTimeout));




      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener pedidos');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener pedidos');
    }
  }

  /// Obtener todos los pedidos históricos (sin filtro de fecha)
  /// ⚠️ ADVERTENCIA: Puede ser muy lento si hay miles de pedidos
  /// Solo usar cuando realmente se necesite todo el historial
  Future<List<Pedido>> getAllPedidosHistoricos() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/consultas'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener pedidos históricos');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener pedidos históricos');
    }
  }

  /// Obtener pedidos de los últimos N días
  Future<List<Pedido>> getPedidosUltimosDias(int dias) async {
    try {
      final headers = await _getHeaders();
      // El backend no soporta filtro por días; trae todos y filtra client-side
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/consultas'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener pedidos');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener pedidos');
    }
  }

  // Método estático para compatibilidad
  static Future<List<Pedido>> getPedidos() async {
    return await PedidoService().getAllPedidos();
  }

  // Obtener pedidos de hoy para analizar ventas
  Future<List<Pedido>> getPedidosHoy() async {
    try {
      final headers = await _getHeaders();
      final hoy = DateTime.now();
      final String fechaHoy =
          "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";

        

      // Intentar primero con el endpoint específico
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/pedidos/consultas/fecha/$fechaHoy'),
            headers: headers,
          )
          .timeout(const Duration(seconds: ApiConfig.requestTimeout));

        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
          

        // FALLBACK: Obtener todos los pedidos y filtrar por fecha
           
        final todosPedidos = await getAllPedidos();
        final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
        final finHoy = inicioHoy.add(Duration(days: 1));

        final pedidosDeHoy = todosPedidos.where((pedido) {
          return pedido.fecha.isAfter(inicioHoy) &&
              pedido.fecha.isBefore(finHoy);
        }).toList();

          
        return pedidosDeHoy;
      }
    } catch (e) {
        

      // FALLBACK DE EMERGENCIA: Filtrar todos los pedidos
      try {
          
        final hoy = DateTime.now();
        final todosPedidos = await getAllPedidos();
        final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
        final finHoy = inicioHoy.add(Duration(days: 1));

        final pedidosDeHoy = todosPedidos.where((pedido) {
          return pedido.fecha.isAfter(inicioHoy) &&
              pedido.fecha.isBefore(finHoy);
        }).toList();

          
        return pedidosDeHoy;
      } catch (fallbackError) {
          
        return [];
      }
    }
  }

  // Obtener pedidos por tipo
  Future<List<Pedido>> getPedidosByTipo(TipoPedido tipo) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/pedidos/consultas/tipo/${tipo.toString().split('.').last}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener pedidos por tipo');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener pedidos por tipo');
    }
  }

  // Obtener pedidos por estado
  Future<List<Pedido>> getPedidosByEstado(EstadoPedido estado) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/pedidos/consultas/estado/${estado.toString().split('.').last}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener pedidos por estado');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener pedidos por estado');
    }
  }

  /// 🆕 Obtener TODOS los documentos/pedidos pagados (incluye documentos sintéticos)
  /// Usa el nuevo endpoint mejorado del backend que incluye pedidos pagados que
  /// no estén asociados a ningún documento pagado
  /// GET /api/documentos/todos/pagados
  Future<List<Pedido>> getTodosDocumentosPagados() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/documentos/todos/pagados'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else if (response.statusCode == 404) {
        // Fallback: usar método anterior si el endpoint no existe
        return await getPedidosByEstado(EstadoPedido.pagado);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener documentos pagados');
      }
    } catch (e) {
      appLog('⚠️ Error en getTodosDocumentosPagados: $e');
      // Fallback: intentar con el método anterior
      try {
        return await getPedidosByEstado(EstadoPedido.pagado);
      } catch (fallbackError) {
        wrapOrThrow(e, context: 'Error al obtener documentos pagados');
      }
    }
  }

  /// Obtener pedidos activos de una mesa específica (optimizado)
  /// Usa el endpoint /api/pedidos/mesa/{mesa}/activos para mayor eficiencia
  Future<List<Pedido>> getPedidosActivosMesa(String mesa) async {
    try {
      final headers = await _getHeaders();

      // Intentar primero con el endpoint específico optimizado
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/pedidos/mesas/$mesa/activos'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else if (response.statusCode == 404) {
        // Si el endpoint no existe, usar filtro por estado activo
        final pedidosActivos = await getPedidosByEstado(EstadoPedido.activo);
        return pedidosActivos.where((p) => p.mesa == mesa).toList();
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener pedidos activos de mesa');
      }
    } catch (e) {
      // Fallback: obtener pedidos activos y filtrar
      try {
        final pedidosActivos = await getPedidosByEstado(EstadoPedido.activo);
        return pedidosActivos.where((p) => p.mesa == mesa).toList();
      } catch (fallbackError) {
        wrapOrThrow(e, context: 'Error al obtener pedidos activos de mesa');
      }
    }
  }

  /// Obtiene todos los pedidos marcados como DEUDA (mesa='DEUDA' y estado=activo)
  /// Estos son pedidos creados desde facturación que quedaron sin pagar
  Future<List<Pedido>> getPedidosDeuda() async {
    try {
      // Obtener todos los pedidos activos
      final pedidosActivos = await getPedidosByEstado(EstadoPedido.activo);
      
      // Filtrar solo los que tienen mesa='DEUDA'
      final deudas = pedidosActivos.where((p) => p.mesa == 'DEUDA').toList();
      
      // Ordenar por fecha (más recientes primero)
      deudas.sort((a, b) => b.fecha.compareTo(a.fecha));
      
      return deudas;
    } catch (e) {
      if (e is BackendException) rethrow;
      wrapOrThrow(e, context: 'Error al obtener deudas');
    }
  }

  // Crear nuevo pedido (método legacy - ahora usa validación de caja)
  Future<Pedido> crearPedido(Pedido pedido) async {
    try {
      // Asignar cuadreId al pedido automáticamente
      pedido.cuadreId = await _requerirCuadreIdActivo();
         
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/pedidos'),
        headers: headers,
        body: json.encode(pedido.toJson()),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 201) {
        return Pedido.fromJson(json.decode(response.body));
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al crear pedido');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al crear pedido');
    }
  }

  // Crear un nuevo pedido
  Future<Pedido> createPedido(Pedido pedido) async {
    try {
      // Asignar cuadreId al pedido automáticamente
      pedido.cuadreId = await _requerirCuadreIdActivo();
         
      // Validar que los items del pedido sean válidos
      if (pedido.items.isEmpty) {
        throw Exception('El pedido debe tener al menos un item');
      }

      if (!PedidoHelper.validatePedidoItems(pedido.items)) {
        throw Exception(
          'Los items del pedido no son válidos. Verifica que cada item tenga un ID de producto y cantidad mayor a 0.',
        );
      }

      final headers = await _getHeaders();

      // Debug: Imprimir el JSON que se va a enviar
      final pedidoJson = pedido.toJson();
        

      final response = await http.post(
        Uri.parse('$baseUrl/api/pedidos'),
        headers: headers,
        body: json.encode(pedidoJson),
          )
          .timeout(const Duration(seconds: 90));

        
        

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final pedidoCreado = Pedido.fromJson(responseData['data']);

          // Construir el Map<String, List<String>> de ingredientes seleccionados por producto
          final Map<String, List<String>> ingredientesPorItem = {
            for (var item in pedidoCreado.items)
              item.productoId: item.ingredientesSeleccionados,
          };

          // ✅ COMENTADO: Las validaciones de stock ahora se hacen en UI
          // verificando directamente los atributos almacen y bodega del producto
          // Por lo tanto estos endpoints ya no se necesitan
          // final Map<String, int> cantidadPorProducto = {
          //   for (var item in pedidoCreado.items) item.productoId: item.cantidad,
          // };
          // final validacion = await _inventarioService.validarStockAntesDePedido(...)
          // await _inventarioService.procesarPedidoParaInventario(...)

          // Notificar a la aplicación que se creó un pedido (listeners pueden recargar UI)
          try {
            _pedidoCompletadoController.add(true);
              
          } catch (e) {
              
          }

          return pedidoCreado;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al crear pedido');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al crear pedido');
    }
  }

  // Actualizar pedido existente
  Future<Pedido> updatePedido(Pedido pedido) async {
    try {
      // Validar que los items del pedido sean válidos
      if (pedido.items.isEmpty) {
        throw Exception('El pedido debe tener al menos un item');
      }

      if (!PedidoHelper.validatePedidoItems(pedido.items)) {
        throw Exception(
          'Los items del pedido no son válidos. Verifica que cada item tenga un ID de producto y cantidad mayor a 0.',
        );
      }

      final headers = await _getHeaders();

      // Debug: Imprimir el JSON que se va a enviar
      final pedidoJson = pedido.toJson();

      // Asegurar que el campo notas nunca sea nulo para evitar error en el backend
      if (pedidoJson['notas'] == null) {
        pedidoJson['notas'] = "";
      }

         
      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/${pedido.id}'),
        headers: headers,
        body: json.encode(pedidoJson),
          )
          .timeout(const Duration(seconds: 90));

        
        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final pedidoActualizado = Pedido.fromJson(responseData['data']);

          // Construir el Map<String, List<String>> de ingredientes seleccionados por producto
          final Map<String, List<String>> ingredientesPorItem = {
            for (var item in pedidoActualizado.items)
              item.productoId: item.ingredientesSeleccionados,
          };

          // ✅ COMENTADO: Las validaciones de stock ahora se hacen en UI
          // try {
          //   await _inventarioService.procesarPedidoParaInventario(
          //     pedidoActualizado.id,
          //     ingredientesPorItem,
          //   );
          // } catch (e) {
          //   // No fallar la actualización del pedido, solo loggear el error
          // }

          // Notificar a la aplicación que se actualizó un pedido
          try {
            _pedidoCompletadoController.add(true);
              
          } catch (e) {
              
          }

          return pedidoActualizado;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al actualizar pedido');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al actualizar pedido');
    }
  }

  /// Registra (o limpia, pasando null/vacío) el último error al intentar
  /// emitir este pedido pagado como documento electrónico ante Matias/DIAN.
  /// Endpoint dedicado y liviano — a diferencia de [updatePedido] no recalcula
  /// totales ni toca inventario, solo deja visible por qué falló para poder
  /// revisarlo después en la lista de facturas.
  Future<Pedido> setErrorFacturacionElectronica(
    String pedidoId,
    String? mensaje,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/$pedidoId/error-facturacion-electronica'),
        headers: headers,
        body: json.encode({'mensaje': mensaje ?? ''}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return Pedido.fromJson(responseData['data']);
      }
      throwBackendError(response.body, response.statusCode,
          prefix: 'Error al registrar el error de facturación');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al registrar el error de facturación');
    }
  }

  // Método estático para compatibilidad
  static Future<Pedido> actualizarEstado(
    String pedidoId,
    EstadoPedido nuevoEstado,
  ) async {
    return await PedidoService().actualizarEstadoPedido(pedidoId, nuevoEstado);
  }

  // Eliminar pedido (con reversión automática de dinero en caja)
  Future<void> eliminarPedido(String id, {String? motivoEliminacion}) async {
    try {
      // El backend ya restaura el inventario al eliminar (PedidoService.
      // restaurarInventarioPedido) — hacerlo también aquí duplicaba la
      // escritura del stock (lectura-cálculo-escritura no atómica, competía
      // con la del backend) y a veces terminaba sin sumar nada.
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/pedidos/$id'),
        headers: headers,
        body: motivoEliminacion != null
            ? json.encode({'motivoEliminacion': motivoEliminacion})
            : null,
      );

        
        

      if (response.statusCode == 204 || response.statusCode == 200) {
        // El backend maneja automáticamente:
        // - Reversión de dinero en caja si el pedido estaba pagado
        // - Limpieza de cache
        // - Registro en historial de ediciones
          
        return;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al eliminar pedido');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al eliminar pedido');
    }
  }

  // Eliminar pedido forzadamente (para administradores)
  // Esta función específicamente maneja pedidos pagados o con estado especial
  Future<void> eliminarPedidoForzado(
    String id, {
    String? motivoEliminacion,
  }) async {
    try {
      // El backend ya restaura el inventario (mismo endpoint que eliminarPedido,
      // los query params force/admin no cambian eso) — ver comentario en
      // eliminarPedido().
      final headers = await _getHeaders();

      // Intentar eliminación forzada con parámetro admin
      final response = await http.delete(
        Uri.parse('$baseUrl/api/pedidos/$id?force=true&admin=true'),
        headers: headers,
        body: motivoEliminacion != null
            ? json.encode({'motivoEliminacion': motivoEliminacion})
            : null,
      );

        
        

      if (response.statusCode == 204 || response.statusCode == 200) {
          
        return;
      }

      // Si el endpoint normal falla, intentar con endpoint específico de admin
      if (response.statusCode != 204) {
          

        final adminResponse = await http.delete(
          Uri.parse('$baseUrl/api/admin/pedidos/$id'),
          headers: headers,
        );

                     

        if (adminResponse.statusCode == 204 ||
            adminResponse.statusCode == 200) {
            
          return;
        }

        // Si ambos fallan, mostrar información detallada
        throwBackendError(response.body, response.statusCode, prefix: 'Error al eliminar pedido');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al eliminar pedido');
    }
  }

  /// Eliminar pedido pagado - Revierte automáticamente el dinero de las ventas
  /// Este método utiliza el endpoint especial que maneja la reversión de pagos
  Future<void> eliminarPedidoPagado(
    String id, {
    String? motivoEliminacion,
  }) async {
    try {
      // El backend ya restaura el inventario (PedidoService.eliminarPedidoPagado
      // -> restaurarInventarioPedido) — ver comentario en eliminarPedido().
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/pedidos/$id/pagado'),
        headers: headers,
        body: motivoEliminacion != null
            ? json.encode({'motivoEliminacion': motivoEliminacion})
            : null,
      );

        
      if (response.body.isNotEmpty) {
          
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
          
        return;
      }

      // Manejar errores específicos
      throwBackendError(response.body, response.statusCode, prefix: 'Error al eliminar pedido pagado');
    } catch (e) {
      wrapOrThrow(e, context: 'Error al eliminar pedido pagado');
    }
  }

  // Filtrar pedidos por múltiples criterios
  Future<List<Pedido>> filtrarPedidos({
    TipoPedido? tipo,
    EstadoPedido? estado,
    String? mesa,
    String? cliente,
    String? mesero,
    String? plataforma,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? busqueda,
  }) async {
    try {
      final headers = await _getHeaders();

      // Construir query parameters
      Map<String, String> queryParams = {};
      if (tipo != null) queryParams['tipo'] = tipo.toString().split('.').last;
      if (estado != null) {
        queryParams['estado'] = estado.toString().split('.').last;
      }
      if (mesa != null) queryParams['mesa'] = mesa;
      if (cliente != null) queryParams['cliente'] = cliente;
      if (mesero != null) queryParams['mesero'] = mesero;
      if (plataforma != null) queryParams['plataforma'] = plataforma;
      if (fechaInicio != null) {
        queryParams['fechaInicio'] = fechaInicio.toIso8601String();
      }
      if (fechaFin != null) {
        queryParams['fechaFin'] = fechaFin.toIso8601String();
      }
      if (busqueda != null && busqueda.isNotEmpty) {
        queryParams['busqueda'] = busqueda;
      }

      final uri = Uri.parse(
        '$baseUrl/api/pedidos/filtrar',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al filtrar pedidos');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al filtrar pedidos');
    }
  }

  // Obtener pedidos por mesero (para el módulo de meseros)
  Future<List<Pedido>> obtenerPedidosPorMesero(String nombreMesero) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/consultas/mesero/$nombreMesero'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _parseListResponse(responseData);
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener pedidos del mesero');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener pedidos del mesero');
    }
  }

  // Obtener estadísticas
  Future<Map<String, int>> getEstadisticas() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/estadisticas'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        // Backend envuelve en ApiResponse: {success, data: {...}, message}
        final raw = jsonData is Map && jsonData['success'] == true
            ? (jsonData['data'] ?? jsonData)
            : jsonData;
        if (raw is Map) {
          return Map<String, int>.from(
            raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)),
          );
        }
        return {};
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener estadísticas');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al obtener estadísticas');
    }
  }

  // Obtener total de ventas por período
  Future<double> getTotalVentas({
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      final headers = await _getHeaders();

      Map<String, String> queryParams = {};
      if (fechaInicio != null) {
        queryParams['fechaInicio'] = fechaInicio.toIso8601String();
      }
      if (fechaFin != null) {
        queryParams['fechaFin'] = fechaFin.toIso8601String();
      }

      final uri = Uri.parse(
        '$baseUrl/api/pedidos/total-ventas',
      ).replace(queryParameters: queryParams);

                 

      final response = await http.get(uri, headers: headers);

        
        

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
          

        if (jsonData['success'] == true) {
          if (jsonData['data'] == null) {
              
            return 0.0;
          }

          if (jsonData['data'] is! Map) {
                           return 0.0;
          }

          final total = jsonData['data']['total'];
            

          if (total == null) {
              
            return 0.0;
          }

          if (total is! num) {
                           return 0.0;
          }

            
          return total.toDouble();
        } else {
            
          return 0.0;
        }
      } else {
        return 0.0;
      }
    } catch (e, stackTrace) {
        
        
      // En caso de error, retornamos 0 en lugar de propagar la excepción
      return 0.0;
    }
  }

  // Obtener un pedido por su ID
  Future<Pedido?> getPedidoById(String pedidoId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/consultas/$pedidoId'),
        headers: headers,
      );

        
        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        Pedido? pedido;

        // Manejar respuesta con wrapper de éxito
        if (responseData is Map<String, dynamic>) {
          if (responseData['success'] == true && responseData['data'] != null) {
            pedido = Pedido.fromJson(responseData['data']);
          } else if (responseData.containsKey('_id') ||
              responseData.containsKey('id')) {
            // Respuesta directa sin wrapper
            pedido = Pedido.fromJson(responseData);
          }

          // Corregir estados inconsistentes
          if (pedido != null) {
            // Si el pedido está inconsistente (estado=pendiente pero pagadoPor existe)
            if (pedido.estado == EstadoPedido.activo &&
                pedido.pagadoPor != null &&
                pedido.pagadoPor!.isNotEmpty) {
                                 
              pedido.estado = EstadoPedido.pagado;
            }

            // ✅ MEJORADO: Verificar inconsistencias sin crear bucles
            if (pedido.tipo == TipoPedido.cortesia &&
                pedido.estado != EstadoPedido.cortesia) {
              // Solo corregir si no se ha corregido recientemente
              final cacheKey = '${pedido.id}_estado_corregido';
              final lastCorrection = _estadoCorregidoCache[cacheKey];
              final now = DateTime.now();

              if (lastCorrection == null ||
                  now.difference(lastCorrection).inSeconds > 30) {
                                     
                pedido.estado = EstadoPedido.cortesia;
                _estadoCorregidoCache[cacheKey] = now;
              }
            }

            // Guardar en caché para acceso rápido
            _pedidosCache[pedidoId] = pedido;
          }

          return pedido;
        }

          
        return null;
      } else {
          
        return null;
      }
    } catch (e) {
        
      return null;
    }
  }

  // Obtener pedidos por mesa
  Future<List<Pedido>> getPedidosByMesa(String nombreMesa) async {
    try {
      final headers = await _getHeaders();
      // Limpiar el nombre de la mesa de cualquier carácter de salto de línea o espacios extra
      final nombreLimpio = nombreMesa
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      // 🔧 VALIDACIÓN: Verificar que el nombre no esté vacío
      if (nombreLimpio.isEmpty) {
          
        throw Exception('El nombre de la mesa no puede estar vacío');
      }
      
      // Usar Uri.encodeComponent para manejar correctamente los espacios y caracteres especiales
      final encodedNombreMesa = Uri.encodeComponent(nombreLimpio);
        
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/consultas/mesa/$encodedNombreMesa'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Manejar tanto respuesta directa como respuesta con wrapper
        final List<dynamic> jsonList;
        if (responseData is List) {
          jsonList = responseData;
        } else if (responseData['data'] != null) {
          jsonList = responseData['data'];
        } else {
          jsonList = [];
        }

        final pedidos = jsonList
            .map((json) {
              try {
                final pedido = Pedido.fromJson(json);

                // Corregir estados inconsistentes
                if (pedido.estado == EstadoPedido.activo &&
                    pedido.pagadoPor != null &&
                    pedido.pagadoPor!.isNotEmpty) {
                                         
                  pedido.estado = EstadoPedido.pagado;
                }

                // ✅ MEJORADO: Verificar inconsistencias sin crear bucles (mesa específica)
                if (pedido.tipo == TipoPedido.cortesia &&
                    pedido.estado != EstadoPedido.cortesia) {
                  // Solo corregir si no se ha corregido recientemente
                  final cacheKey = '${pedido.id}_mesa_estado_corregido';
                  final lastCorrection = _estadoCorregidoCache[cacheKey];
                  final now = DateTime.now();

                  if (lastCorrection == null ||
                      now.difference(lastCorrection).inSeconds > 30) {
                                             
                    pedido.estado = EstadoPedido.cortesia;
                    _estadoCorregidoCache[cacheKey] = now;
                  }
                }

                // Si estado es "pendiente", convertirlo a activo o pagado según otros campos
                if (pedido.estado.toString().toLowerCase() == "pendiente") {
                  if (pedido.pagadoPor != null &&
                      pedido.pagadoPor!.isNotEmpty) {
                                             
                    pedido.estado = EstadoPedido.pagado;
                  } else {
                      
                      
                    pedido.estado = EstadoPedido.activo;
                  }
                }

                // Guardar en caché para acceso rápido
                if (pedido.id.isNotEmpty) {
                  _pedidosCache[pedido.id] = pedido;
                }

                return pedido;
              } catch (e) {
                  
                  
                return null;
              }
            })
            .where((pedido) => pedido != null)
            .cast<Pedido>()
            .toList();

        return pedidos;
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al obtener pedidos de mesa');
      }
    } catch (e) {
      // Si ya es un error estructurado del backend, respetar su mensaje real
      if (e is BackendException) rethrow;
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('connection')) {
        throw Exception(
          'Error de conexión a internet. Verifica tu conectividad WiFi.',
        );
      }
      throw Exception('Error al cargar pedidos. Intenta nuevamente.');
    }
  }

  // Actualizar estado de un pedido
  Future<Pedido> actualizarEstadoPedido(
    String pedidoId,
    EstadoPedido nuevoEstado,
  ) async {
    try {
         
      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse(
              '$baseUrl/api/pedidos/$pedidoId/estado/${nuevoEstado.toString().split('.').last}',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

                  
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final pedidoActualizado = Pedido.fromJson(responseData['data']);

          // Emitir evento cuando se paga el pedido
          if (nuevoEstado == EstadoPedido.pagado) {
              
            _pedidoCompletadoController.add(true);
              
          }

             
          return pedidoActualizado;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al pagar pedido');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al actualizar estado del pedido');
    }
  }

  // Cargar productos para un pedido
  Future<void> cargarProductosParaPedido(Pedido pedido) async {
    try {
      // Crear un mapa de productos por ID
      Map<String, Producto> productosMap = {};

      // Primero intentamos cargar todos los productos
      for (final item in pedido.items) {
        if (!productosMap.containsKey(item.productoId)) {
          // Validar que el ID del producto no sea vacío
          if (item.productoId.isEmpty) {
            continue;
          }

          try {
            final producto = await _productoService.getProducto(
              item.productoId,
            );
            if (producto != null) {
              productosMap[item.productoId] = producto;
            } else {
              // Crear un producto ficticio para evitar errores en la UI
              productosMap[item.productoId] = Producto(
                id: item.productoId,
                nombre: "Producto no disponible",
                precio: item.precio,
                costo: 0,
                utilidad: 0,
                descripcion: "Este producto ya no está disponible",
              );
            }
          } catch (e) {
              
          }
        }
      }

      // Actualizar los items con sus productos
      for (var i = 0; i < pedido.items.length; i++) {
        final item = pedido.items[i];
        final producto = productosMap[item.productoId];

        if (producto != null) {
          // ✅ Solo actualizamos el nombre del producto (por si cambió en el catálogo)
          // NUNCA sobreescribir precioUnitario con el precio del catálogo:
          // el precio guardado en el pedido es el precio real de la transacción
          pedido.items[i] = ItemPedido(
            productoId: item.productoId,
            productoNombre: producto.nombre,
            cantidad: item.cantidad,
            notas: item.notas,
            precioUnitario: item.precioUnitario, // ✅ Precio original del pedido
            agregadoPor: item.agregadoPor,
            porcentajeImpuesto: item.porcentajeImpuesto, // ✅ Preservar
            valorImpuesto: item.valorImpuesto, // ✅ Preservar
            porcentajeDescuento: item.porcentajeDescuento, // ✅ Preservar
            valorDescuento: item.valorDescuento, // ✅ Preservar
            origen: item.origen, // ✅ Preservar
          );
        } else if (item.producto == null) {
          // Si no tenemos el producto, pero tenemos nombre en el JSON, creamos un producto básico
          String nombreProducto = "Producto desconocido";

          // Intentar obtener nombre del producto desde el servicio de productos
          try {
            final nombreInfo = await _productoService.getProductoNombre(
              item.productoId,
            );
            if (nombreInfo != null && nombreInfo.isNotEmpty) {
              nombreProducto = nombreInfo;
            }
          } catch (e) {
              
          }

          // Crear un producto básico con la información disponible
          final productoBasico = Producto(
            id: item.productoId,
            nombre: nombreProducto,
            precio: item.precio,
            costo: 0.0,
            utilidad: 0.0,
            cantidad: 0,
          );

          pedido.items[i] = ItemPedido(
            productoId: item.productoId,
            productoNombre: productoBasico.nombre,
            cantidad: item.cantidad,
            notas: item.notas,
            precioUnitario: item.precioUnitario,
            agregadoPor: item.agregadoPor,
            porcentajeImpuesto: item.porcentajeImpuesto, // ✅ Preservar
            valorImpuesto: item.valorImpuesto, // ✅ Preservar
            porcentajeDescuento: item.porcentajeDescuento, // ✅ Preservar
            valorDescuento: item.valorDescuento, // ✅ Preservar
            origen: item.origen, // ✅ Preservar
          );
        }
      }
    } catch (e) {
        
    }
  }

  // Método legacy para cancelar pedidos (mantener por compatibilidad)
  Future<void> cancelarPedido(String pedidoId, String motivo) async {
    final url = '$baseUrl/api/pedidos/cancelar';
    final token = await _getToken();

    if (token == null) {
      throw Exception('No se encontró el token de autenticación');
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'pedidoId': pedidoId, 'motivo': motivo}),
    );

    if (response.statusCode != 200) {
      throwBackendError(response.body, response.statusCode, prefix: 'Error al cancelar pedido');
    }

    _pedidoCompletadoController.add(true);
  }

  // Nuevo método para cancelar pedidos usando el DTO PagarPedidoRequest
  Future<Pedido> cancelarPedidoConDTO(
    String pedidoId, {
    String procesadoPor = '',
    String notas = '',
  }) async {
    try {
      final headers = await _getHeaders();

      final Map<String, dynamic> cancelarData = {
        'tipoPago': 'cancelado', // Usar el nuevo DTO
        'procesadoPor': procesadoPor,
        'notas': notas,
      };

        
        
        

      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/pagos/$pedidoId'),
        headers: headers,
        body: json.encode(cancelarData),
      );

        
        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final pedidoCancelado = Pedido.fromJson(responseData['data']);

          // Notificar que se canceló un pedido
          _pedidoCompletadoController.add(true);
            

          return pedidoCancelado;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al cancelar pedido');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al cancelar pedido');
    }
  }

  // Actualizar tipo de un pedido (cortesía, consumo interno, etc.)
  Future<Pedido> actualizarTipoPedido(
    String pedidoId,
    TipoPedido nuevoTipo,
  ) async {
    try {
      final headers = await _getHeaders();

        
        
        

      // PASO 1: Obtener el pedido actual completo
      final getPedidoResponse = await http.get(
        Uri.parse('$baseUrl/api/pedidos/consultas/$pedidoId'),
        headers: headers,
      );

      if (getPedidoResponse.statusCode != 200) {
        throwBackendError(getPedidoResponse.body, getPedidoResponse.statusCode, prefix: 'No se pudo obtener el pedido');
      }

      final getPedidoData = json.decode(getPedidoResponse.body);
      if (getPedidoData['success'] != true || getPedidoData['data'] == null) {
        throw Exception('Formato de respuesta inválido al obtener pedido');
      }

      // PASO 2: Modificar solo el tipo en el pedido completo
      final pedidoCompleto = getPedidoData['data'] as Map<String, dynamic>;
      // El backend espera el tipo en mayúsculas (NORMAL, CORTESIA, INTERNO, etc.)
      pedidoCompleto['tipo'] = nuevoTipo.toJson().toUpperCase();

        

      // PASO 3: Actualizar el pedido completo con el nuevo tipo
      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/$pedidoId'),
        headers: headers,
        body: json.encode(pedidoCompleto),
      );

        
        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return Pedido.fromJson(responseData['data']);
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al actualizar tipo de pedido');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'No se pudo actualizar el tipo del pedido');
    }
  }

  // Pagar un pedido - Actualizado para coincidir con PagarPedidoRequest del backend
  Future<Pedido> pagarPedido(
    String pedidoId, {
    String formaPago = 'efectivo',
    double propina = 0.0,
    double totalPagado = 0.0,
    String procesadoPor = '',
    String notas = '',
    TipoPedido? tipoPedido,
    bool esCortesia = false,
    bool esConsumoInterno = false,
    String? motivoCortesia,
    String? tipoConsumoInterno,
    double descuento = 0.0, // ✅ NUEVO: Parámetro para descuento
    List<Map<String, dynamic>>?
    pagosParciales, // ✅ NUEVO: Soporte para pagos mixtos
    // Campos adicionales para el pago múltiple
    bool pagoMultiple = false,
    double montoEfectivo = 0.0,
    double montoTarjeta = 0.0,
    double montoTransferencia = 0.0,
    double montoSistecredito = 0.0, // ✅ AGREGADO: Soporte para Sistecredito
    double montoDatafono = 0.0, // ✅ AGREGADO: Soporte para Datafono
    double montoBold = 0.0, // Sub-línea de pago múltiple: Bold (datafono/pasarela)
    double montoAddi = 0.0, // Sub-línea de pago múltiple: Addi (BNPL)
    double montoCredilondon = 0.0, // Sub-línea de pago múltiple: Credilondon (BNPL)
    double montoNequi = 0.0, // Sub-línea de pago múltiple: Nequi (transferencia)
    double montoDaviplata = 0.0, // Sub-línea de pago múltiple: DaviPlata (transferencia)
    double montoBancolombia = 0.0, // Sub-línea de pago múltiple: Bancolombia (transferencia)
    String? medioPago, // Medio de pago para DIAN (efectivo, transferencia, etc.)
    String? detallePago, // Sub-categoría visual (nequi/daviplata/bancolombia/bold/...) para el libro contable
  }) async {
    // Declarar tipoPago aquí para que sea accesible tanto en el try como en el catch
    String tipoPago = 'pagado';

    try {
      final headers = await _getHeaders();
      // Determinar el tipoPago según las opciones
      if (esCortesia) {
        tipoPago = 'cortesia';
      } else if (esConsumoInterno) {
        tipoPago = 'consumo_interno';
      } else {
        tipoPago = 'pagado'; // Por defecto es pagado normal
      }

      // Construir el objeto según el DTO PagarPedidoRequest
      final Map<String, dynamic> pagarData = {
        'tipoPago': tipoPago,
        'procesadoPor': procesadoPor,
        'notas': notas,
        'descuento': descuento,
        if (medioPago != null && medioPago.isNotEmpty) 'medioPago': medioPago,
        if (detallePago != null && detallePago.isNotEmpty) 'detallePago': detallePago,
      };

      // Solo incluir campos específicos para pagos normales
      if (tipoPago == 'pagado') {
        // Validar forma de pago principal - Nueva lógica para pagos múltiples
        if (pagoMultiple || formaPago == 'mixto' || formaPago == 'multiple') {
          // Para pagos mixtos o múltiples, mantener 'mixto' que es el esperado por el backend
          pagarData['formaPago'] = 'mixto';
            

          // Nueva implementación para el nuevo tipo de pago múltiple
          if (pagoMultiple) {
            List<Map<String, dynamic>> pagosMixtos = [];

            // Agregar cada método de pago solo si tiene un monto mayor a cero
            if (montoEfectivo > 0) {
              pagosMixtos.add({
                'formaPago': 'efectivo',
                'monto': montoEfectivo,
              });
            }

            if (montoTarjeta > 0) {
              pagosMixtos.add({'formaPago': 'tarjeta', 'monto': montoTarjeta});
            }

            if (montoTransferencia > 0) {
              pagosMixtos.add({
                'formaPago': 'transferencia',
                'monto': montoTransferencia,
              });
            }

            // Nequi, DaviPlata y Bancolombia son sub-líneas independientes de
            // "transferencia": pueden combinarse entre sí y con la línea genérica
            // de arriba en la misma venta, cada una con su propio detallePago.
            if (montoNequi > 0) {
              pagosMixtos.add({
                'formaPago': 'transferencia',
                'monto': montoNequi,
                'detallePago': 'nequi',
              });
            }

            if (montoDaviplata > 0) {
              pagosMixtos.add({
                'formaPago': 'transferencia',
                'monto': montoDaviplata,
                'detallePago': 'daviplata',
              });
            }

            if (montoBancolombia > 0) {
              pagosMixtos.add({
                'formaPago': 'transferencia',
                'monto': montoBancolombia,
                'detallePago': 'bancolombia',
              });
            }

            // ✅ AGREGADO: Soporte para Sistecredito
            if (montoSistecredito > 0) {
              pagosMixtos.add({
                'formaPago': 'sistecredito',
                'monto': montoSistecredito,
              });
            }

            // ✅ AGREGADO: Soporte para Datafono
            if (montoDatafono > 0) {
              pagosMixtos.add({
                'formaPago': 'datafono',
                'monto': montoDatafono,
              });
            }

            // Bold es una sub-categoría visual de datafono. Addi y Credilondon son
            // plataformas de crédito (BNPL): NO deben contarse como efectivo (ese
            // dinero nunca llega como efectivo físico a la caja), se reportan como
            // 'sistecredito' — el bucket de crédito más cercano ya existente — y
            // quedan identificadas aparte por su propio detallePago.
            if (montoBold > 0) {
              pagosMixtos.add({
                'formaPago': 'datafono',
                'monto': montoBold,
                'detallePago': 'bold',
              });
            }

            if (montoAddi > 0) {
              pagosMixtos.add({
                'formaPago': 'sistecredito',
                'monto': montoAddi,
                'detallePago': 'addi',
              });
            }

            if (montoCredilondon > 0) {
              pagosMixtos.add({
                'formaPago': 'sistecredito',
                'monto': montoCredilondon,
                'detallePago': 'credilondon',
              });
            }

            if (pagosMixtos.isNotEmpty) {
              pagarData['pagosMixtos'] = pagosMixtos;
                
                
                
                
            }
          }
          // Compatibilidad con el método anterior (pagos parciales)
          else if (pagosParciales != null && pagosParciales.isNotEmpty) {
            List<Map<String, dynamic>> pagosMixtos = [];

            for (var pago in pagosParciales) {
              // Convertir el formato interno al formato esperado por la API
              Map<String, dynamic> pagoMixto = {
                'formaPago': pago['formaPago'],
                'monto': pago['monto'],
              };
              pagosMixtos.add(pagoMixto);
            }

            pagarData['pagosMixtos'] = pagosMixtos;
                         }
        } else if (formaPago != 'efectivo' &&
            formaPago != 'transferencia' &&
            formaPago != 'tarjeta' &&
            formaPago != 'tarjeta_credito' && // ✅ AGREGADO: Validar tarjeta crédito
            formaPago != 'sistecredito' && // ✅ AGREGADO: Validar sistecredito
            formaPago != 'datafono' && // ✅ AGREGADO: Validar datafono
            formaPago != 'Crédito' && // ✅ AGREGADO: Validar venta a crédito
            formaPago != 'otro') {
                       formaPago = 'efectivo'; // Solo convierte a efectivo si no es ninguno de los válidos
          pagarData['formaPago'] = formaPago;
        } else {
          pagarData['formaPago'] = formaPago; // ✅ Usa el método de pago tal cual
        }

        pagarData['propina'] = propina;
        // ✅ DESCUENTO YA INCLUIDO ARRIBA: pagarData['descuento'] = descuento;
        pagarData['pagado'] = true;
        pagarData['estado'] = 'Pagado'; // Asegurar que el estado sea explícito
        pagarData['fechaPago'] = _formatearFechaParaBackend(DateTimeUtils.nowColombia());
        pagarData['totalPagado'] = totalPagado > 0
            ? totalPagado
            : null; // Enviar solo si es diferente de 0

        // Log adicional para forma de pago
          
      }

      // Campos específicos para cortesías - Estructura simplificada
      if (tipoPago == 'cortesia') {
        // Solo los campos esenciales para cortesías
        pagarData['motivoCortesia'] =
            motivoCortesia ?? 'Pedido procesado como cortesía';
        pagarData['estado'] = 'Cortesia';
        // No incluir campos de pago para cortesías, EXCEPTO descuento
        pagarData.remove('formaPago');
        pagarData.remove('propina');
        // ✅ MANTENER DESCUENTO: pagarData.remove('descuento');
        pagarData.remove('totalPagado');
        pagarData.remove('pagado');
      }

      // Campos específicos para consumo interno - Estructura simplificada
      if (tipoPago == 'consumo_interno') {
        // Solo los campos esenciales para consumo interno
        pagarData['tipoConsumoInterno'] = tipoConsumoInterno ?? 'empleado';
        pagarData['estado'] = 'Pagado';
        // No incluir campos de pago para consumo interno, EXCEPTO descuento
        pagarData.remove('formaPago');
        pagarData.remove('propina');
        // ✅ MANTENER DESCUENTO: pagarData.remove('descuento');
        pagarData.remove('totalPagado');
        pagarData.remove('pagado');
      }

      // Validaciones adicionales para cortesías
      if (tipoPago == 'cortesia') {
        // Asegurar que todos los campos requeridos estén presentes
        if (!pagarData.containsKey('motivoCortesia')) {
          pagarData['motivoCortesia'] = 'Pedido procesado como cortesía';
        }
        if (!pagarData.containsKey('estado')) {
          pagarData['estado'] = 'Cortesia';
        }
      }

      // Validaciones adicionales para consumo interno
      if (tipoPago == 'consumo_interno') {
        // Asegurar que todos los campos requeridos estén presentes
        if (!pagarData.containsKey('tipoConsumoInterno')) {
          pagarData['tipoConsumoInterno'] = 'empleado';
        }
        if (!pagarData.containsKey('estado')) {
          pagarData['estado'] = 'Pagado';
        }
        
        // 🔧 VALIDACIÓN CRÍTICA: Verificar estructura del payload
          
          
          
          
          
          

        // Verificar que no hay campos nulos críticos
        final camposCriticos = [
          'tipoConsumoInterno',
          'estado',
          'tipoPago',
          'procesadoPor',
        ];
        for (String campo in camposCriticos) {
          if (!pagarData.containsKey(campo) || pagarData[campo] == null) {
              
            throw Exception(
              'Datos de consumo interno incompletos: falta $campo',
            );
          }
        }

          
      }

        
        
        
        
        
         
      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/pagos/$pedidoId'),
        headers: headers,
        body: json.encode(pagarData),
          )
          .timeout(const Duration(seconds: 90));

        
        
      
      // 🔍 BACKEND RESPONSE DEBUG
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['data'] != null) {
            
                         
            
                                      
        }
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final pedidoPagado = Pedido.fromJson(responseData['data']);

          // Asegurarse de que el pedido tenga el estado correcto
          if (tipoPago == 'pagado' &&
              pedidoPagado.estado != EstadoPedido.pagado) {
            pedidoPagado.estado = EstadoPedido.pagado;
              
          } else if (tipoPago == 'cortesia' &&
              pedidoPagado.estado != EstadoPedido.cortesia) {
            pedidoPagado.estado = EstadoPedido.cortesia;
              
          }

          // Actualizar la caché con el pedido pagado
          _pedidosCache[pedidoId] = pedidoPagado;

          // Notificar que se pagó un pedido para actualizar el dashboard
          _pedidoPagadoController.add(true);
            
            

          return pedidoPagado;
        } else {
          throwBackendError(response.body, response.statusCode, prefix: 'Error al pagar pedido');
        }
      } else {
        // Caso especial: mensaje de configuración interna de Spring, no accionable por el usuario
        if (response.body.contains('ListableBeanFactory must not be null')) {
          throw Exception(
            'Error interno del servidor (configuración Spring). Este es un problema del backend que debe ser corregido por el desarrollador del servidor.',
          );
        }
        throwBackendError(response.body, response.statusCode, prefix: 'Error al pagar pedido');
      }
    } catch (e) {
        

      // Intento de reconciliación: tal vez el backend procesó el pago pero devolvió 500
      try {
          
        final pedidoVerificado = await getPedidoById(pedidoId);
        if (pedidoVerificado != null) {
            

          // Considerar éxito si el estado coincide con lo esperado
          final bool esExitoPorEstado =
              (tipoPago == 'cortesia' &&
                  pedidoVerificado.estado == EstadoPedido.cortesia) ||
              (tipoPago == 'consumo_interno' &&
                  pedidoVerificado.estado == EstadoPedido.pagado) ||
              (pedidoVerificado.estado == EstadoPedido.pagado);

          if (esExitoPorEstado) {
               
            // Actualizar caché y notificar listeners
            _pedidosCache[pedidoId] = pedidoVerificado;
            try {
              _pedidoPagadoController.add(true);
            } catch (_) {}

            return pedidoVerificado;
          }
        }
      } catch (verifyErr) {
          
      }

      wrapOrThrow(e, context: 'Error al pagar pedido');
    }
  }

  // Pagar productos específicos de un pedido (pago parcial)
  Future<Map<String, dynamic>> pagarProductosParciales(
    String pedidoId, {
    required List<ItemPedido> itemsSeleccionados,
    String formaPago = 'efectivo',
    double propina = 0.0,
    String procesadoPor = '',
    String notas = '',
    // Nuevos parámetros para pago múltiple
    bool pagoMultiple = false,
    double montoEfectivo = 0.0,
    double montoTarjeta = 0.0,
    double montoTransferencia = 0.0,
  }) async {
    try {
      final headers = await _getHeaders();

      // ✅ CORRECCIÓN: Calcular desde item.subtotal que incluye descuentos
      double totalSeleccionado = itemsSeleccionados.fold<double>(
        0.0,
        (sum, item) => sum + item.subtotal,
      );

      // ✅ CORRECCIÓN: Para pagos parciales de productos recién agregados, usar productoId
      // porque los items aún no tienen ID asignado por el backend
      List<String> itemIds = itemsSeleccionados
          .map((item) => item.productoId) // Usar productoId en lugar de item.id
          .where((id) => id.isNotEmpty)
          .toList();

        
      for (int i = 0; i < itemsSeleccionados.length; i++) {
        final item = itemsSeleccionados[i];
                 }
        

      final Map<String, dynamic> pagoData = {
        'itemIds': itemIds,
        'formaPago': formaPago,
        'procesadoPor': procesadoPor,
        'notas': notas,
        'totalCalculado': totalSeleccionado + propina,
        // Campos adicionales para pagos múltiples
        'pagoMultiple': pagoMultiple,
        'montoEfectivo': montoEfectivo,
        'montoTarjeta': montoTarjeta,
        'montoTransferencia': montoTransferencia,
      };

        
        
        
        
        

      final response = await http.post(
        Uri.parse('$baseUrl/api/pedidos/pagos/$pedidoId/parcial'),
        headers: headers,
        body: json.encode(pagoData),
      );

        
        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Notificar que se procesó un pago
          _pedidoPagadoController.add(true);
            
            
          return {
            'success': true,
            'pedidoActualizado': responseData['data']['pedidoActualizado'],
            'documentoCreado': responseData['data']['documentoCreado'],
            'itemsPagados': itemsSeleccionados.length,
            'totalPagado': totalSeleccionado + propina,
            'cambio': responseData['data']['cambio'] ?? 0.0,
          };
        } else {
          throwBackendError(response.body, response.statusCode, prefix: 'Error al procesar pago parcial');
        }
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al procesar pago parcial');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error al procesar pago parcial');
    }
  }

  // ✅ COMENTADO: Este método no se usa porque getIngredientesDescontadosParaProducto está obsoleto
  // Future<List<IngredienteDevolucion>> obtenerIngredientesParaDevolucion(
  //   String pedidoId,
  //   String productoId,
  // ) async {
  //   try {
  //     final ingredientes = await _inventarioService
  //         .getIngredientesDescontadosParaProducto(pedidoId, productoId);
  //     return ingredientes
  //         .map((ingrediente) => IngredienteDevolucion.fromJson(ingrediente))
  //         .toList();
  //   } catch (e) {
  //     throw Exception('Error al obtener ingredientes para devolución: $e');
  //   }
  // }

  // ✅ COMENTADO: Este método no se usa porque devolverIngredientesAlInventario está obsoleto
  // Future<void> cancelarProductoConIngredientes(
  //   CancelarProductoRequest request,
  // ) async {
  //   try {
  //     final ingredientesADevolver = request.ingredientes
  //         .where((ingrediente) => ingrediente.devolver)
  //         .map((ingrediente) => ingrediente.toJson())
  //         .toList();
  //     await _inventarioService.devolverIngredientesAlInventario(
  //       request.pedidoId,
  //       request.productoId,
  //       ingredientesADevolver,
  //       request.motivo,
  //       request.responsable,
  //     );
  //   } catch (e) {
  //     throw Exception('Error al cancelar producto con ingredientes: $e');
  //   }
  // }

  // Mover un pedido de una mesa a otra
  Future<Pedido> moverPedidoAMesa(
    String pedidoId,
    String nuevaMesa, {
    String? nombrePedido,
  }) async {
    try {
      final headers = await _getHeaders();

      final Map<String, dynamic> requestData = {'nuevaMesa': nuevaMesa};

      if (nombrePedido != null && nombrePedido.isNotEmpty) {
        requestData['nombrePedido'] = nombrePedido;
      }

        
      if (nombrePedido != null) {
          
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/pedidos/mesas/$pedidoId/mover'),
        headers: headers,
        body: json.encode(requestData),
      );

        
        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final pedidoMovido = Pedido.fromJson(responseData['data']);
            
          return pedidoMovido;
        } else {
          throw Exception('Formato de respuesta inválido');
        }
      } else {
        throwBackendError(response.body, response.statusCode, prefix: 'Error al mover pedido');
      }
    } catch (e) {
      wrapOrThrow(e, context: 'Error moviendo pedido');
    }
  }

  /// Mueve productos específicos de un pedido a otra mesa
  /// Crea automáticamente una nueva orden en la mesa destino si está libre
  Future<Map<String, dynamic>> moverProductosEspecificos({
    required String pedidoOrigenId,
    required String mesaDestinoNombre,
    required List<ItemPedido> itemsParaMover,
    required String usuarioId,
    required String usuarioNombre,
  }) async {
    try {
        
        
        
        

      final token = await _getToken();
      if (token == null) {
        throw Exception('Token de autenticación no encontrado');
      }

      // Preparar datos de los productos a mover según formato del backend
      final productosData = itemsParaMover.map((item) {
        // Asegurar que cantidad siempre sea un entero
        int cantidad;
        if (item.cantidad is String) {
          cantidad = int.tryParse(item.cantidad.toString()) ?? 1;
        } else if (item.cantidad is double) {
          cantidad = item.cantidad.toInt();
        } else {
          cantidad = item.cantidad;
        }

        return {'productoId': item.productoId, 'cantidad': cantidad};
      }).toList();

      final requestData = {
        'pedidoId': pedidoOrigenId, // Backend espera 'pedidoId'
        'mesaDestino':
            mesaDestinoNombre, // Enviar nombre completo de mesa (A1, B6, C1)
        'productos': productosData, // Backend espera 'productos'
      };

        
        
        
        
        
        

      final response = await http.post(
        Uri.parse('$baseUrl/api/pedidos/mesas/mover-productos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestData),
      );

        
        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final data = responseData['data'] ?? {};

            
            
            
            
             
          // Retornar la respuesta completa del backend con información adicional
          return {
            'success': true,
            'data': data, // Datos completos del backend
            'message':
                responseData['message'] ??
                'Productos movidos exitosamente a $mesaDestinoNombre',
            // Mantener compatibilidad con código existente
            'nuevaOrdenCreada': data['nuevoPedidoId'] != null,
            'itemsMovidos': data['productosMovidos'] ?? itemsParaMover.length,
            'pedidoDestinoId': data['nuevoPedidoId'],
            'mesaDestino': data['mesaDestino'],
            'pedidoOriginalEliminado': data['pedidoOriginalEliminado'] ?? false,
          };
        } else {
          throw Exception(
            responseData['message'] ?? 'Error procesando el movimiento',
          );
        }
      } else {
        final backendException = parseBackendException(response.body, response.statusCode, prefix: 'Error al mover productos');
        return {'success': false, 'message': backendException.displayMessage};
      }
    } catch (e) {
      return {'success': false, 'message': errorMessage(e)};
    }
  }

  /// Elimina todos los pedidos activos (solo para administradores)
  ///
  /// Hace una solicitud DELETE al endpoint de administrador para eliminar todos los pedidos activos.
  /// Devuelve un mapa con 'success' (bool) y 'message' (String) indicando el resultado.
  Future<Map<String, dynamic>> eliminarTodosPedidosActivos() async {
    try {
      // El backend ya restaura el inventario de cada pedido activo/pendiente
      // antes de borrarlo (AdminController.eliminarTodosPedidosActivos ->
      // PedidoService.restaurarInventarioPedido) — ver comentario en
      // eliminarPedido().
      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/eliminar-todos-pedidos-activos'),
        headers: headers,
      );

        
        

      if (response.statusCode == 200 || response.statusCode == 204) {
          

        // Notificar que se han actualizado los pedidos
        _pedidoCompletadoController.add(true);

        return {
          'success': true,
          'message':
              'Todos los pedidos activos han sido eliminados correctamente',
        };
      }

      // Manejo de errores
      final backendException = parseBackendException(
        response.body,
        response.statusCode,
        prefix: 'Error al eliminar pedidos activos',
      );
      return {
        'success': false,
        'message': backendException.displayMessage,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': errorMessage(e),
      };
    }
  }
}
