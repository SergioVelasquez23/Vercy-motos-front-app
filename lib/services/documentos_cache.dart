import 'dart:async';

import '../models/factura.dart';
import '../models/pedido.dart';
import '../utils/logger.dart';
import 'factura_service.dart';
import 'pedido_service.dart';

/// Caché en memoria para la pantalla "Lista documentos" (FacturasListScreen).
///
/// El problema: cada vez que se abría la pantalla se descargaban TODAS las
/// facturas + TODOS los pedidos pagados y se parseaban de golpe, tardando
/// varios segundos. La paginación de esa pantalla es solo visual (corta la
/// lista que ya está en memoria), no reduce la descarga.
///
/// Esta caché guarda el resultado y lo reutiliza mientras esté fresco:
///  - Se invalida explícitamente ([invalidar]) al cobrar / emitir un
///    documento, para que la lista muestre lo nuevo de inmediato.
///  - Tiene un TTL de respaldo ([_ttl]) para reflejar cambios hechos desde
///    otro dispositivo aunque nadie invalide.
///  - El botón "Actualizar" de la pantalla fuerza la recarga ([forzar]).
class DocumentosCache {
  DocumentosCache._();
  static final DocumentosCache instance = DocumentosCache._();

  /// Máximo tiempo que se considera válida la caché sin volver a la red.
  static const Duration _ttl = Duration(minutes: 5);

  final FacturaService _facturaService = FacturaService();
  final PedidoService _pedidoService = PedidoService();

  List<Factura>? _facturas;
  List<Pedido>? _pedidosPagados;
  DateTime? _cargadoEn;
  Future<void>? _cargaEnCurso;

  bool get tieneDatosFrescos =>
      _facturas != null &&
      _pedidosPagados != null &&
      _cargadoEn != null &&
      DateTime.now().difference(_cargadoEn!) < _ttl;

  List<Factura> get facturas => _facturas ?? const [];
  List<Pedido> get pedidosPagados => _pedidosPagados ?? const [];

  /// Marca la caché como obsoleta: la próxima [cargar] irá a la red.
  void invalidar() {
    _facturas = null;
    _pedidosPagados = null;
    _cargadoEn = null;
    appLog('🗑️ DocumentosCache invalidada');
  }

  /// Asegura que [facturas] y [pedidosPagados] estén disponibles.
  ///
  /// Devuelve de inmediato si la caché está fresca y [forzar] es false.
  /// Deduplica llamadas concurrentes (si ya hay una carga en curso, la
  /// reutiliza en vez de disparar otra).
  Future<void> cargar({bool forzar = false}) {
    if (!forzar && tieneDatosFrescos) return Future.value();
    final enCurso = _cargaEnCurso;
    if (enCurso != null) return enCurso;
    final future = _cargarDesdeRed();
    _cargaEnCurso = future;
    return future.whenComplete(() => _cargaEnCurso = null);
  }

  Future<void> _cargarDesdeRed() async {
    // Las dos llamadas en paralelo (antes eran secuenciales) y cada una
    // tolerante a su propio fallo: si los pedidos pagados fallan, al menos
    // se muestran las facturas, y viceversa.
    final facturasFuture = _facturaService.getFacturas();
    final pedidosFuture = _pedidoService
        .getTodosDocumentosPagados()
        .catchError((Object e) {
      appLog('⚠️ DocumentosCache: fallo al cargar pedidos pagados: $e');
      return <Pedido>[];
    });

    final resultados = await Future.wait([facturasFuture, pedidosFuture]);
    _facturas = resultados[0] as List<Factura>;
    _pedidosPagados = resultados[1] as List<Pedido>;
    _cargadoEn = DateTime.now();
    appLog(
      '📦 DocumentosCache actualizada: ${_facturas!.length} facturas, '
      '${_pedidosPagados!.length} pedidos pagados',
    );
  }
}
