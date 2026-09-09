import 'dart:async';

import '../models/factura.dart';
import '../models/pedido.dart';
import '../utils/logger.dart';
import 'factura_service.dart';
import 'pedido_service.dart';

/// Caché en memoria para la pantalla "Lista documentos" (FacturasListScreen).
///
/// Historia: abrir la pantalla descargaba TODAS las facturas + TODOS los
/// pedidos pagados y los parseaba de golpe, tardando varios segundos.
///
/// Ahora:
///  - Los pedidos pagados se piden **por página** al backend
///    (`GET /api/documentos/todos/pagados?page=&size=`). Si el backend aún no
///    pagina, [esPaginado] queda en `false` y la pantalla sigue paginando en
///    cliente sobre la lista completa (comportamiento anterior).
///  - Las facturas tradicionales (`GET /api/facturas`) se traen una sola vez
///    y se reutilizan; solo se muestran en la primera página.
///  - La última página cargada queda cacheada: volver a entrar a la pantalla
///    la muestra al instante.
///  - Se invalida ([invalidar]) al cobrar o emitir un documento, y tiene un
///    TTL de respaldo por si algo cambia desde otro dispositivo.
class DocumentosCache {
  DocumentosCache._();
  static final DocumentosCache instance = DocumentosCache._();

  static const Duration _ttl = Duration(minutes: 5);

  final FacturaService _facturaService = FacturaService();
  final PedidoService _pedidoService = PedidoService();

  // --- Facturas tradicionales (lista completa, se trae una vez) ---
  List<Factura>? _facturas;
  DateTime? _facturasCargadasEn;

  // --- Página actual de pedidos pagados ---
  List<Pedido> _pedidosPagados = const [];
  int _totalPedidos = 0;
  bool _esPaginado = false;
  int? _paginaCargada;
  int? _sizeCargado;
  DateTime? _paginaCargadaEn;

  bool _incluirLocalesCargado = false;

  Future<void>? _cargaEnCurso;
  String? _cargaEnCursoClave;

  List<Factura> get facturas => _facturas ?? const [];
  List<Pedido> get pedidosPagados => _pedidosPagados;

  /// Total de pedidos pagados en el servidor (para los controles de
  /// paginación). Solo es fiable cuando [esPaginado] es `true`.
  int get totalPedidos => _totalPedidos;

  /// `true` si el backend respetó `page`/`size` en la última carga.
  bool get esPaginado => _esPaginado;

  bool _paginaFresca(int page, int size, bool incluirLocales) =>
      _paginaCargada == page &&
      _sizeCargado == size &&
      _incluirLocalesCargado == incluirLocales &&
      _paginaCargadaEn != null &&
      DateTime.now().difference(_paginaCargadaEn!) < _ttl;

  bool get _facturasFrescas =>
      _facturas != null &&
      _facturasCargadasEn != null &&
      DateTime.now().difference(_facturasCargadasEn!) < _ttl;

  /// Marca todo como obsoleto: la próxima [cargar] vuelve a la red.
  void invalidar() {
    _facturas = null;
    _facturasCargadasEn = null;
    _pedidosPagados = const [];
    _totalPedidos = 0;
    _paginaCargada = null;
    _sizeCargado = null;
    _incluirLocalesCargado = false;
    _paginaCargadaEn = null;
    appLog('🗑️ DocumentosCache invalidada');
  }

  /// Asegura que [facturas] y [pedidosPagados] correspondan a la página
  /// [page] (tamaño [size]). Devuelve de inmediato si ya está en caché y
  /// fresca, salvo [forzar]. Deduplica llamadas concurrentes a la misma
  /// página.
  Future<void> cargar({
    required int page,
    required int size,
    DateTime? desde,
    bool incluirLocales = false,
    bool forzar = false,
  }) {
    final clave = '$page/$size/$incluirLocales';
    if (!forzar &&
        _paginaFresca(page, size, incluirLocales) &&
        (_facturasFrescas || page != 0)) {
      return Future.value();
    }
    if (_cargaEnCursoClave == clave && _cargaEnCurso != null) {
      return _cargaEnCurso!;
    }
    final future = _cargarDesdeRed(
      page: page,
      size: size,
      desde: desde,
      incluirLocales: incluirLocales,
      forzar: forzar,
    );
    _cargaEnCurso = future;
    _cargaEnCursoClave = clave;
    return future.whenComplete(() {
      if (_cargaEnCursoClave == clave) {
        _cargaEnCurso = null;
        _cargaEnCursoClave = null;
      }
    });
  }

  Future<void> _cargarDesdeRed({
    required int page,
    required int size,
    required DateTime? desde,
    required bool incluirLocales,
    required bool forzar,
  }) async {
    // Las facturas solo importan en la primera página. Se traen si no están
    // frescas o si el usuario forzó la recarga ("Actualizar"). Fuera de la
    // página 0 se conserva lo que ya hubiera en caché.
    final necesitaFacturas = page == 0 && (forzar || !_facturasFrescas);
    final Future<List<Factura>> facturasFuture = necesitaFacturas
        ? _facturaService.getFacturas()
        : Future.value(_facturas ?? const []);

    final pedidosFuture = _pedidoService
        .getTodosDocumentosPagadosPagina(
          page: page,
          size: size,
          desde: desde,
          incluirLocales: incluirLocales,
        )
        .catchError((Object e) {
      appLog('⚠️ DocumentosCache: fallo al cargar pedidos pagados: $e');
      return const PaginaDocumentos([], 0, false);
    });

    final resultados = await Future.wait([facturasFuture, pedidosFuture]);

    if (necesitaFacturas) {
      _facturas = resultados[0] as List<Factura>;
      _facturasCargadasEn = DateTime.now();
    }

    final pagina = resultados[1] as PaginaDocumentos;
    _pedidosPagados = pagina.items;
    _totalPedidos = pagina.total;
    _esPaginado = pagina.esPaginado;
    _paginaCargada = page;
    _sizeCargado = size;
    _incluirLocalesCargado = incluirLocales;
    _paginaCargadaEn = DateTime.now();

    appLog(
      '📦 DocumentosCache: página $page ($size) → ${_pedidosPagados.length} pedidos'
      '${_esPaginado ? " de $_totalPedidos" : " (sin paginar)"}, '
      '${facturas.length} facturas',
    );
  }
}
