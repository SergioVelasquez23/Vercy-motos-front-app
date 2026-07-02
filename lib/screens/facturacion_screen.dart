import '../utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/pedido.dart';
import '../models/item_pedido.dart';
import '../models/producto.dart';
import '../models/pedido_asesor.dart';
import '../models/movimiento_inventario.dart';
import '../services/pedido_service.dart';
import '../services/producto_service.dart';
import '../services/pedido_asesor_service.dart';
import '../services/pdf_service.dart';
import '../services/negocio_info_service.dart';
import '../services/impresion_service.dart';
import '../services/inventario_service.dart';
import '../services/cliente_service.dart';
import '../services/matias_service.dart';
import '../services/traslado_service.dart';
import '../models/cliente.dart';
import '../models/negocio_info.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/datos_cache_provider.dart';
import '../providers/facturacion_draft_provider.dart';
import '../widgets/facturacion/observaciones_section.dart';
import '../widgets/facturacion/totales_section.dart';
import '../widgets/facturacion/botones_accion_facturacion.dart';

import '../utils/busqueda_productos_utils.dart';
import '../utils/datetime_utils.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/dialogs_helper.dart';
import '../utils/api_error.dart' show errorMessage;
import '../widgets/facturizacion/confirmacion_dian_dialog.dart';
import '../services/documento_service.dart';
import '../utils/base64_file_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

// Cache de clientes compartido entre instancias de FacturacionScreen
List<Cliente> _clientesCached = [];
DateTime? _clientesCacheTime;
const _clientesCacheTTL = Duration(minutes: 5);

class FacturacionScreen extends StatefulWidget {
  final PedidoAsesor? pedidoAsesor;
  // Si viene de un traslado, su ID para eliminarlo tras el pago
  final String? trasladoId;

  const FacturacionScreen({super.key, this.pedidoAsesor, this.trasladoId});
  
  @override
  _FacturacionScreenState createState() => _FacturacionScreenState();
}

class _FacturacionScreenState extends State<FacturacionScreen> {
  FacturacionDraftProvider? _draftProvider; // cacheado para dispose() seguro
  final PedidoService _pedidoService = PedidoService();
  final ProductoService _productoService = ProductoService();
  final PedidoAsesorService _pedidoAsesorService = PedidoAsesorService();
  final TrasladoService _trasladoService = TrasladoService();
  final PDFService _pdfService = PDFService();
  final NegocioInfoService _negocioInfoService = NegocioInfoService();
  final ImpresionService _impresionService = ImpresionService();
  final InventarioService _inventarioService = InventarioService();
  final ClienteService _clienteService = ClienteService();
  final MatiasService _matiasService = MatiasService();

  // Controladores de formulario
  final TextEditingController _clienteController = TextEditingController(
    text: 'CONSUMIDOR FINAL',
  );
  final TextEditingController _codigoBarrasController = TextEditingController();
  
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _nombreProductoController =
      TextEditingController();
  final TextEditingController _cantidadController = TextEditingController(
    text: '1',
  );
  final TextEditingController _valorUnitController = TextEditingController();
  final TextEditingController _porcentajeImpuestoController =
      TextEditingController(text: '19');
  final TextEditingController _porcentajeDescuentoController =
      TextEditingController(text: '0');

  // Controladores de Datos Extras
  final TextEditingController _ordenCompraController = TextEditingController();
  final TextEditingController _ordenServicioController =
      TextEditingController();
  final TextEditingController _ordenPedidoController = TextEditingController();
  final TextEditingController _vendedorController = TextEditingController();
  final TextEditingController _porcentajeDctoPagoController =
      TextEditingController();
  final TextEditingController _guiaController = TextEditingController();

  // Controladores adicionales para Autocomplete



  // Variables de estado
  String _tipoFactura = 'LOCAL';
  DateTime _fechaFactura = DateTime.now();
  DateTime _fechaVencimiento = DateTime.now().add(Duration(days: 30));
  String _tipoImpuesto = 'IVA';
  String _porcentajeTipoDescuento = 'Porcentaje';
  bool _datosProductoExpanded = true;
  bool _datosExtrasExpanded = false;

  // Datos Extras
  DateTime? _fechaCompra;
  DateTime? _fechaDctoPago;
  String _listaPrecios = 'Detal';

  // Método de pago
  String _metodoPago = 'efectivo';
  final List<Map<String, dynamic>> _metodosPago = [
    {'value': 'efectivo', 'label': 'Efectivo', 'icon': Icons.attach_money},
    {
      'value': 'transferencia',
      'label': 'Transferencia',
      'icon': Icons.account_balance,
    },
    {'value': 'tarjeta', 'label': 'Tarjeta débito', 'icon': Icons.credit_card},
    {'value': 'tarjeta_credito', 'label': 'Tarjeta crédito', 'icon': Icons.credit_score},
    {'value': 'addi', 'label': 'Addi', 'icon': Icons.shopping_bag_outlined},
    {'value': 'sistecredito', 'label': 'Sistecredito', 'icon': Icons.card_giftcard},
    {'value': 'credito', 'label': 'A Crédito', 'icon': Icons.account_balance_wallet},
    {'value': 'multiple', 'label': 'Múltiple', 'icon': Icons.payments},
  ];

  // Mapeo de método de pago UI → medioPago DIAN
  static const Map<String, String> _medioPagoMap = {
    'efectivo': 'efectivo',
    'transferencia': 'transferencia',
    'tarjeta': 'tarjeta debito',
    'tarjeta_credito': 'tarjeta credito',
    // Addi (BNPL) no tiene código DIAN propio; se reporta como 'efectivo',
    // mismo criterio ya usado para 'credito' en esta tabla.
    'addi': 'efectivo',
    'sistecredito': 'sistecredito',
    'credito': 'efectivo',
    'multiple': 'efectivo',
  };

  // Mapeo de método UI → formaPago backend
  String _mapFormaPagoBackend(String metodo) {
    if (metodo == 'credito') return 'Crédito';
    return metodo; // El backend acepta los valores directos para el resto
  }

  // Controladores para pago múltiple
  final TextEditingController _montoEfectivoController = TextEditingController(
    text: '0',
  );
  final TextEditingController _montoTransferenciaController =
      TextEditingController(text: '0');
  final TextEditingController _montoTarjetaController = TextEditingController(
    text: '0',
  );
  final TextEditingController _montoSistereditoController =
      TextEditingController(text: '0');
  final TextEditingController _montoDatafonoController = TextEditingController(
    text: '0',
  );

  // Controladores de retenciones y AIU
  final TextEditingController _retencionController = TextEditingController(
    text: '0',
  );
  final TextEditingController _reteIVAController = TextEditingController(
    text: '0',
  );
  final TextEditingController _reteICAController = TextEditingController(
    text: '0',
  );
  final TextEditingController _aiuController = TextEditingController(text: '0');
  final TextEditingController _dctoGeneralController = TextEditingController(
    text: '0',
  );
  bool _retencionesExpanded = false;
  
  // Controlador de observaciones
  final TextEditingController _observacionesController =
      TextEditingController();

  Cliente? _clienteSeleccionado;
  Producto? _productoSeleccionado;
  String _origenSeleccionado = 'ALMACÉN'; // 📦 BODEGA o ALMACÉN
  List<ItemPedido> _items = [];
  // Mapea productoId (código) → id MongoDB real del producto, para notificar traslados tras la venta
  final Map<String, String> _productoMongoIds = {};
  List<Producto> _productosDisponibles = [];
  List<Cliente> _clientesDisponibles = [];

  bool _isLoading = false;

  // 🔴 Escuchar creación de productos desde otras pestañas
  html.BroadcastChannel? _productosChannel;
  
  // ✅ Key para forzar reconstrucción de Autocompletes al limpiar formulario
  int _autocompleteResetKey = 0;

  @override
  void initState() {
    super.initState();
    _cargarProductos();

    // 🔴 Escuchar actualizaciones de productos desde otras pestañas
    _productosChannel = html.BroadcastChannel('productos_actualizados');
    _productosChannel!.onMessage.listen((_) async {
      if (mounted) {
        appLog(
          '📡 Producto actualizado desde otra pestaña — recargando desde API',
        );
        // Forzar recarga desde API invalidando la caché
        final cacheProvider = Provider.of<DatosCacheProvider>(
          context,
          listen: false,
        );
        await cacheProvider.recargarDatos();
        if (mounted) await _cargarProductos();
      }
    });
    
    // 🔥 Pre-warm: despertar backend de Render y pre-cachear cuadreId
    _preCalentarBackend();
    
    // 🔄 Iniciar sincronización automática de inventario
    Future.microtask(() {
      _draftProvider = Provider.of<FacturacionDraftProvider>(
        context,
        listen: false,
      );
      _draftProvider!.startSync();
    });
    
    // Si se pasó un pedido de asesor, cargar clientes primero
    if (widget.pedidoAsesor != null) {
      _inicializarConPedidoAsesor();
    } else {
      _cargarClientes().then((_) {
        // Asignar cliente por defecto si no hay ninguno seleccionado
        _asignarClientePorDefecto();
      });
      // 📝 Restaurar borrador existente (si no es pedido asesor)
      Future.microtask(() => _restaurarBorrador());
    }
  }

  /// 🔥 Pre-calentar el backend: hacer un GET liviano para despertar Render
  /// y pre-cachear el cuadreId activo para que createPedido no tenga que esperar
  Future<void> _preCalentarBackend() async {
    try {
      // Esto pre-cachea el cuadreId en PedidoService (evita llamada extra al crear pedido)
      _pedidoService.preCachearCuadreId();
    } catch (_) {}
  }

  // Inicializar con pedido asesor - cargar clientes primero
  Future<void> _inicializarConPedidoAsesor() async {
    await _cargarClientes(); // Esperar a que se carguen los clientes
    if (mounted) {
      await _precargarDatosPedidoAsesor(); // Luego precargar datos del pedido
      // Asignar cliente por defecto si después de precargar no hay cliente válido
      Future.delayed(Duration(milliseconds: 100), () {
        _asignarClientePorDefecto();
      });
    }
  }

  Future<void> _precargarDatosPedidoAsesor() async {
    final pedido = widget.pedidoAsesor!;

    // Precargar nombre del cliente
    _clienteController.text = pedido.clienteNombre;

    Cliente? clienteEncontrado;
    if (pedido.clienteId != null) {
      clienteEncontrado = _clientesDisponibles
          .cast<Cliente?>()
          .firstWhere((cliente) => cliente?.id == pedido.clienteId, orElse: () => null);

      // Si el cliente no está en la lista precargada (ej. lista paginada/limitada),
      // buscarlo directamente por ID en vez de usar un placeholder sin numeroIdentificacion,
      // que dejaba la factura electrónica sin la cédula/NIT real del cliente.
      if (clienteEncontrado == null) {
        appLog('⚠️ Cliente ${pedido.clienteId} no está en la lista precargada, buscando por ID...');
        try {
          clienteEncontrado = await _clienteService.obtenerClientePorId(pedido.clienteId!);
        } catch (e) {
          appLog('⚠️ Error obteniendo cliente por ID: $e');
        }
      }
    }

    if (!mounted) return;
    setState(() {
      if (clienteEncontrado != null) {
        _clienteSeleccionado = clienteEncontrado;
        appLog('✅ Cliente seleccionado: ${_clienteSeleccionado?.nombreCompleto}');
      } else {
        appLog(
          '⚠️ No se pudo encontrar el cliente - clienteId: ${pedido.clienteId}',
        );
      }
    });

    // Mostrar diálogo para que el cajero edite IVA y descuento antes de cargar los items
    _mostrarDialogoEditarItemsPedidoAsesor(pedido);
  }

  Future<void> _mostrarDialogoEditarItemsPedidoAsesor(PedidoAsesor pedido) async {
    if (!mounted) return;

    final ivaCtrs = pedido.items
        .map((i) => TextEditingController(text: i.porcentajeImpuesto.toStringAsFixed(0)))
        .toList();
    final dctoCtrs = pedido.items
        .map((i) => TextEditingController(text: i.porcentajeDescuento.toStringAsFixed(0)))
        .toList();

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(context);
        final textStyle = TextStyle(fontSize: 12, color: theme.colorScheme.onSurface);
        final headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface);
        final inputDec = InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: const OutlineInputBorder(),
          suffixText: '%',
          suffixStyle: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        );

        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Pedido de ${pedido.asesorNombre}', style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface)),
                    Text('Edita IVA y descuento antes de cargar', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 740,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cabecera de columnas
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: Text('Producto', style: headerStyle)),
                      SizedBox(width: 44, child: Text('Cant.', style: headerStyle, textAlign: TextAlign.center)),
                      SizedBox(width: 78, child: Text('Precio c/IVA', style: headerStyle, textAlign: TextAlign.right)),
                      const SizedBox(width: 8),
                      SizedBox(width: 64, child: Text('IVA %', style: headerStyle, textAlign: TextAlign.center)),
                      const SizedBox(width: 8),
                      SizedBox(width: 64, child: Text('Dcto %', style: headerStyle, textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 4),
                // Lista de items con scroll
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: pedido.items.length,
                    itemBuilder: (_, idx) {
                      final item = pedido.items[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                item.productoNombre ?? '-',
                                style: textStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text('${item.cantidad}', style: textStyle, textAlign: TextAlign.center),
                            ),
                            SizedBox(
                              width: 78,
                              child: Text(
                                '\$${item.precioUnitario.toStringAsFixed(0)}',
                                style: textStyle.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: TextField(
                                controller: ivaCtrs[idx],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                                decoration: inputDec,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: TextField(
                                controller: dctoCtrs[idx],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                                decoration: inputDec,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Sin cambios'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Aplicar y cargar'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );

    // Leer valores antes de hacer dispose
    final ivaValues = ivaCtrs.map((c) => double.tryParse(c.text) ?? 0.0).toList();
    final dctoValues = dctoCtrs.map((c) => double.tryParse(c.text) ?? 0.0).toList();
    for (final c in ivaCtrs) { c.dispose(); }
    for (final c in dctoCtrs) { c.dispose(); }

    if (!mounted) return;

    final List<ItemPedido> itemsCargados;
    if (confirmar == true) {
      // Aplicar IVA y descuento editados.
      // precioUnitario del asesor es siempre el precio FINAL con IVA incluido;
      // se extrae la base neta dividiendo por (1 + iva/100).
      itemsCargados = pedido.items.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final ivaPct = ivaValues[idx];
        final dctoPct = dctoValues[idx];
        final precioBase = ivaPct > 0 && ivaPct < 100
            ? item.precioUnitario / (1 + ivaPct / 100)
            : item.precioUnitario;
        final subtotal = precioBase * item.cantidad;
        final valorDescuento = subtotal * (dctoPct / 100);
        final baseGravable = subtotal - valorDescuento;
        // base ya es el precio neto (sin IVA), así que IVA = base × rate/100
        final valorImpuesto = ivaPct > 0 && ivaPct < 100
            ? baseGravable * (ivaPct / 100)
            : 0.0;
        return ItemPedido(
          productoId: item.productoId,
          productoNombre: item.productoNombre,
          cantidad: item.cantidad,
          precioUnitario: precioBase,
          porcentajeImpuesto: ivaPct,
          valorImpuesto: valorImpuesto,
          porcentajeDescuento: dctoPct,
          valorDescuento: valorDescuento,
          origen: item.origen,
          trasladoId: item.trasladoId,
        );
      }).toList();
    } else {
      // Sin cambios: extraer precio base neto del precio asesor (IVA incluido)
      itemsCargados = pedido.items.map((item) {
        final ivaPct = item.porcentajeImpuesto;
        final precioBase = ivaPct > 0 && ivaPct < 100
            ? item.precioUnitario / (1 + ivaPct / 100)
            : item.precioUnitario;
        final subtotal = precioBase * item.cantidad;
        final valorDescuento = subtotal * (item.porcentajeDescuento / 100);
        final baseGravable = subtotal - valorDescuento;
        final valorImpuesto = ivaPct > 0 && ivaPct < 100
            ? baseGravable * (ivaPct / 100)
            : 0.0;
        return ItemPedido(
          productoId: item.productoId,
          productoNombre: item.productoNombre,
          cantidad: item.cantidad,
          precioUnitario: precioBase,
          porcentajeImpuesto: ivaPct,
          valorImpuesto: valorImpuesto,
          porcentajeDescuento: item.porcentajeDescuento,
          valorDescuento: valorDescuento,
          origen: item.origen,
          trasladoId: item.trasladoId,
        );
      }).toList();
    }

    setState(() {
      _items = itemsCargados;
      for (final item in _items) {
        appLog('📦 Item cargado: ${item.productoNombre} - IVA: ${item.porcentajeImpuesto}% - Dcto: ${item.porcentajeDescuento}%');
      }
    });

    showSuccessSnackBar(context, 'Pedido de ${pedido.asesorNombre} cargado correctamente');
  }


  Future<void> _cargarProductos() async {
    appLog('🔄 _cargarProductos() iniciado');
    // Obtener productos desde el provider en lugar de cargarlos nuevamente
    final cacheProvider = Provider.of<DatosCacheProvider>(
      context,
      listen: false,
    );

    appLog('🔍 Cache provider productos: ${cacheProvider.productos?.length ?? 0}');

    if (cacheProvider.productos != null &&
        cacheProvider.productos!.isNotEmpty) {
      setState(() {
        _productosDisponibles = cacheProvider.productos!;
      });
      
      // 🔍 DEBUG: Verificar productos con código
      final conCodigo = _productosDisponibles
          .where((p) => p.codigo != null && p.codigo!.isNotEmpty)
          .length;
      appLog(
        '📦 Productos cargados desde cache: ${_productosDisponibles.length}, con código: $conCodigo',
      );
    } else {
      // Si no hay productos en cache, cargarlos
      appLog('⚠️ No hay productos en cache, cargando desde API...');
      try {
        final productos = await _productoService.getProductos();
        setState(() {
          _productosDisponibles = productos;
        });
        
        // 🔍 DEBUG: Verificar productos con código
        final conCodigo = _productosDisponibles
            .where((p) => p.codigo != null && p.codigo!.isNotEmpty)
            .length;
        appLog(
          '📦 Productos cargados desde API: ${_productosDisponibles.length}, con código: $conCodigo',
        );
      } catch (e) {
        appLog('❌ Error cargando productos: $e');  
      }
    }
  }

  Future<void> _cargarClientes() async {
    // Usar cache si tiene menos de 5 minutos
    if (_clientesCacheTime != null &&
        DateTime.now().difference(_clientesCacheTime!) < _clientesCacheTTL &&
        _clientesCached.isNotEmpty) {
      setState(() => _clientesDisponibles = _clientesCached);
      return;
    }
    try {
      final clientes = await _clienteService.obtenerClientes();
      _clientesCached = clientes;
      _clientesCacheTime = DateTime.now();
      if (mounted) setState(() => _clientesDisponibles = clientes);
    } catch (e) {
      if (_clientesCached.isNotEmpty && mounted) {
        setState(() => _clientesDisponibles = _clientesCached);
      }
    }
  }

  /// Asignar cliente por defecto si no hay ninguno seleccionado
  void _asignarClientePorDefecto() {
    if (_clienteSeleccionado == null && _clienteController.text.trim().isEmpty) {
      setState(() {
        _clienteController.text = 'CONSUMIDOR FINAL';
        _clienteSeleccionado = null; // Mantener como null ya que no es un cliente de la base de datos
      });
    }
  }

  @override
  void dispose() {
    // ⏸️ Detener sincronización automática
    // NO limpiar el borrador aquí - se mantiene para cuando regresen
    _draftProvider?.stopSync();
    
    _clienteController.dispose();
    _codigoBarrasController.dispose();
    _codigoController.dispose();
    _nombreProductoController.dispose();
    _cantidadController.dispose();
    _valorUnitController.dispose();
    _porcentajeImpuestoController.dispose();
    _porcentajeDescuentoController.dispose();
    _montoEfectivoController.dispose();
    _montoTransferenciaController.dispose();
    _montoTarjetaController.dispose();
    _montoSistereditoController.dispose();
    _montoDatafonoController.dispose();
    _ordenCompraController.dispose();
    _ordenServicioController.dispose();
    _ordenPedidoController.dispose();
    _vendedorController.dispose();
    _porcentajeDctoPagoController.dispose();
    _guiaController.dispose();
    _retencionController.dispose();
    _reteIVAController.dispose();
    _reteICAController.dispose();
    _aiuController.dispose();
    _dctoGeneralController.dispose();
    _observacionesController.dispose();


    // 🔴 Cerrar canal de sincronización entre pestañas
    _productosChannel?.close();

    super.dispose();
  }

  /// Normaliza ítems guardados con el formato antiguo (precioUnitario = precio
  /// con IVA incluido) al nuevo formato (precioUnitario = base sin IVA).
  /// Detecta el formato antiguo cuando valorImpuesto ≈ precioUnitario × rate/100.
  List<ItemPedido> _normalizarItemsIVA(List<ItemPedido> items) {
    return items.map((item) {
      final r = item.porcentajeImpuesto;
      if (r <= 0 || r >= 100) return item;
      final ivaAntiguo = item.precioUnitario * r / 100;
      final esFormatoAntiguo = (item.valorImpuesto - ivaAntiguo).abs() < 1.0;
      if (!esFormatoAntiguo) return item;
      final precioBase = item.precioUnitario / (1 + r / 100);
      final subtotal = precioBase * item.cantidad;
      final baseGravable = subtotal - item.valorDescuento;
      final nuevoImpuesto = baseGravable * r / 100;
      return ItemPedido(
        productoId: item.productoId,
        productoNombre: item.productoNombre,
        cantidad: item.cantidad,
        precioUnitario: precioBase,
        porcentajeImpuesto: r,
        valorImpuesto: nuevoImpuesto,
        porcentajeDescuento: item.porcentajeDescuento,
        valorDescuento: item.valorDescuento,
        origen: item.origen,
        trasladoId: item.trasladoId,
      );
    }).toList();
  }

  /// 📝 Restaurar borrador existente del provider
  void _restaurarBorrador() {
    try {
      final draftProvider = Provider.of<FacturacionDraftProvider>(
        context,
        listen: false,
      );

      // Solo restaurar si hay un borrador guardado
      if (!draftProvider.hasDraft) {
        appLog('ℹ️  No hay borrador para restaurar');
        return;
      }

      appLog('📝 Restaurando borrador - ${draftProvider.itemsCount} items');

      setState(() {
        // Restaurar items tal cual: el draft es en memoria y siempre fue
        // guardado por esta misma pantalla ya en formato nuevo (precioUnitario
        // = base sin IVA), así que no debe volver a normalizarse/recalcularse.
        _items = List.from(draftProvider.items);

        // Restaurar cliente
        _clienteSeleccionado = draftProvider.clienteSeleccionado;
        _clienteController.text = draftProvider.clienteNombre;

        // Restaurar método de pago
        _metodoPago = draftProvider.metodoPago;
        _tipoFactura = draftProvider.tipoFactura;
        _origenSeleccionado = draftProvider.origenSeleccionado;
        _fechaFactura = draftProvider.fechaFactura;
        _fechaVencimiento = draftProvider.fechaVencimiento;

        // Restaurar datos extras
        if (draftProvider.ordenCompra != null) {
          _ordenCompraController.text = draftProvider.ordenCompra!;
        }
        if (draftProvider.ordenServicio != null) {
          _ordenServicioController.text = draftProvider.ordenServicio!;
        }
        if (draftProvider.ordenPedido != null) {
          _ordenPedidoController.text = draftProvider.ordenPedido!;
        }
        if (draftProvider.vendedor != null) {
          _vendedorController.text = draftProvider.vendedor!;
        }
        if (draftProvider.guia != null) {
          _guiaController.text = draftProvider.guia!;
        }
        if (draftProvider.observaciones != null) {
          _observacionesController.text = draftProvider.observaciones!;
        }

        // Restaurar montos de pago múltiple
        final montos = draftProvider.montosPago;
        _montoEfectivoController.text = montos['efectivo']?.toString() ?? '0';
        _montoTransferenciaController.text =
            montos['transferencia']?.toString() ?? '0';
        _montoTarjetaController.text = montos['tarjeta']?.toString() ?? '0';
        _montoSistereditoController.text =
            montos['sistecredito']?.toString() ?? '0';
        _montoDatafonoController.text = montos['datafono']?.toString() ?? '0';

        // Restaurar retenciones
        _retencionController.text = draftProvider.retencion.toString();
        _reteIVAController.text = draftProvider.reteIVA.toString();
        _reteICAController.text = draftProvider.reteICA.toString();
        _aiuController.text = draftProvider.aiu.toString();
        _dctoGeneralController.text = draftProvider.dctoGeneral.toString();
      });

      // Mostrar notificación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✨ Borrador restaurado - ${draftProvider.itemsCount} productos',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      appLog('✅ Borrador restaurado exitosamente');
    } catch (e) {
      appLog('⚠️ Error restaurando borrador: $e');
      showWarningSnackBar(context, '⚠️ Error restaurando borrador anterior');
    }
  }

  /// 💾 Guardar TODO el estado actual al provider
  void _guardarEstadoCompleto() {
    try {
      final draftProvider = Provider.of<FacturacionDraftProvider>(
        context,
        listen: false,
      );

      // Guardar items
      draftProvider.setItems(_items);

      // Guardar cliente
      draftProvider.setCliente(_clienteSeleccionado, _clienteController.text);

      // Guardar método de pago y tipo de factura
      draftProvider.setMetodoPago(_metodoPago);
      draftProvider.setTipoFactura(_tipoFactura);
      draftProvider.setOrigenSeleccionado(_origenSeleccionado);
      draftProvider.setFechaFactura(_fechaFactura);
      draftProvider.setFechaVencimiento(_fechaVencimiento);

      // Guardar datos extras si tienen contenido
      if (_ordenCompraController.text.isNotEmpty) {
        draftProvider.setOrdenCompra(_ordenCompraController.text);
      }
      if (_ordenServicioController.text.isNotEmpty) {
        draftProvider.setOrdenServicio(_ordenServicioController.text);
      }
      if (_ordenPedidoController.text.isNotEmpty) {
        draftProvider.setOrdenPedido(_ordenPedidoController.text);
      }
      if (_vendedorController.text.isNotEmpty) {
        draftProvider.setVendedor(_vendedorController.text);
      }
      if (_guiaController.text.isNotEmpty) {
        draftProvider.setGuia(_guiaController.text);
      }
      if (_observacionesController.text.isNotEmpty) {
        draftProvider.setObservaciones(_observacionesController.text);
      }

      // Guardar montos de pago múltiple
      final montos = {
        'efectivo': double.tryParse(_montoEfectivoController.text) ?? 0,
        'transferencia':
            double.tryParse(_montoTransferenciaController.text) ?? 0,
        'tarjeta': double.tryParse(_montoTarjetaController.text) ?? 0,
        'sistecredito': double.tryParse(_montoSistereditoController.text) ?? 0,
        'datafono': double.tryParse(_montoDatafonoController.text) ?? 0,
      };
      draftProvider.setMontosPago(montos);

      // Guardar retenciones
      draftProvider.setRetencion(
        double.tryParse(_retencionController.text) ?? 0,
      );
      draftProvider.setReteIVA(double.tryParse(_reteIVAController.text) ?? 0);
      draftProvider.setReteICA(double.tryParse(_reteICAController.text) ?? 0);
      draftProvider.setAiu(double.tryParse(_aiuController.text) ?? 0);
      draftProvider.setDctoGeneral(
        double.tryParse(_dctoGeneralController.text) ?? 0,
      );

      appLog(
        '💾 Estado completo guardado - ${_items.length} items, cliente: ${_clienteController.text}',
      );
    } catch (e) {
      appLog('⚠️ Error guardando estado completo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final padding = isMobile ? 12.0 : 24.0;
            final spacing = isMobile ? 16.0 : 24.0;

            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainForm(),
                        SizedBox(height: spacing),
                        _buildDatosExtras(),
                        SizedBox(height: spacing),
                        _buildDatosProducto(),
                        SizedBox(height: spacing),
                        _buildItemsList(),
                        SizedBox(height: spacing),
                        ObservacionesSection(
                          observacionesController: _observacionesController,
                        ),
                        SizedBox(height: spacing),
                        _buildRetencionesYAIU(),
                        SizedBox(height: spacing),
                        _buildDescuentoGeneral(),
                        SizedBox(height: spacing),
                        _buildMetodoPago(),
                        SizedBox(height: spacing),
                        TotalesSection(
                          items: _items,
                          retencionController: _retencionController,
                          reteIVAController: _reteIVAController,
                          reteICAController: _reteICAController,
                          aiuController: _aiuController,
                          dctoGeneralController: _dctoGeneralController,
                        ),
                        SizedBox(height: spacing),
                        BotonesAccionFacturacion(
                          items: _items,
                          isLoading: _isLoading,
                          onGuardarBorrador: _guardarComoBorrador,
                          onGuardarYPagar: _guardarYPagar,
                          onGuardarComoDeuda: _guardarComoDeuda,
                          dctoGeneralController: _dctoGeneralController,
                        ),
                        SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 500;
        
        return Container(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Crear factura',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _mostrarBorradores,
                        icon: Icon(Icons.drafts, size: 18),
                        label: Text(
                          'Facturas en borrador',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(Icons.receipt_long, color: AppTheme.primary, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'Crear factura',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Spacer(),
                    ElevatedButton.icon(
                      onPressed: _mostrarBorradores,
                      icon: Icon(Icons.drafts),
                      label: Text(
                        'Facturas en borrador',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMainForm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        return Container(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (isMobile) ...[
                // Diseño móvil - campos apilados verticalmente
                _buildFormField('Tipo', _buildTipoDropdown()),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormField(
                        'F. Factura',
                        _buildFechaFacturaPicker(),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildFormField(
                        'F. Vencimiento',
                        _buildFechaVencimientoPicker(),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _buildFormField('Cliente', _buildClienteField()),
              ] else ...[
                // Diseño desktop - original
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildFormField('Tipo', _buildTipoDropdown()),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildFormField(
                        'F. Factura',
                        _buildFechaFacturaPicker(),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildFormField(
                        'F. Vencimiento',
                        _buildFechaVencimientoPicker(),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildFormField('Cliente', _buildClienteField()),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        field,
      ],
    );
  }

  Widget _buildTipoDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _tipoFactura,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          items: const [
            DropdownMenuItem(
              value: 'LOCAL',
              child: Text(''),
            ),
            DropdownMenuItem(
              value: 'POS',
              child: Text('Documento POS'),
            ),
            DropdownMenuItem(
              value: 'FACTURA',
              child: Text('Factura Electrónica'),
            ),
          ],
          onChanged: (value) => setState(() => _tipoFactura = value!),
        ),
        const SizedBox(height: 4),
        if (_tipoFactura == 'FACTURA')
          Text(
            'Se enviará a la DIAN como Factura Electrónica',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        if (_tipoFactura == 'POS')
          Text(
            'Se puede enviar a la DIAN como documento POS',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildFechaFacturaPicker() {
    return InkWell(
      onTap: () async {
        final fecha = await showDatePicker(
          context: context,
          initialDate: _fechaFactura,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (fecha != null) setState(() => _fechaFactura = fecha);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          suffixIcon: Icon(
            Icons.calendar_today,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            size: 18,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        child: Text(
          '${_fechaFactura.year}-${_fechaFactura.month.toString().padLeft(2, '0')}-${_fechaFactura.day.toString().padLeft(2, '0')}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildFechaVencimientoPicker() {
    return InkWell(
      onTap: () async {
        final fecha = await showDatePicker(
          context: context,
          initialDate: _fechaVencimiento,
          firstDate: _fechaFactura,
          lastDate: DateTime(2030),
        );
        if (fecha != null) setState(() => _fechaVencimiento = fecha);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          suffixIcon: Icon(
            Icons.calendar_today,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            size: 18,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        child: Text(
          '${_fechaVencimiento.year}-${_fechaVencimiento.month.toString().padLeft(2, '0')}-${_fechaVencimiento.day.toString().padLeft(2, '0')}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildClienteField() {
    return Row(
      children: [
        Expanded(
          child: Autocomplete<Cliente>(
            key: ValueKey(
              'cliente_$_autocompleteResetKey',
            ), // ✅ Fuerza reconstrucción al limpiar
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return _clientesDisponibles.take(10);
              }
              return _clientesDisponibles
                  .where((Cliente cliente) {
                    final nombreCompleto = cliente.nombreCompleto.toLowerCase();
                    final documento = cliente.numeroIdentificacion
                        .toLowerCase();
                    final query = textEditingValue.text.toLowerCase();
                    return nombreCompleto.contains(query) ||
                        documento.contains(query);
                  })
                  .take(15);
            },
            displayStringForOption: (Cliente cliente) => cliente.nombreCompleto,
            onSelected: (Cliente cliente) {
              setState(() {
                _clienteSeleccionado = cliente;
                _clienteController.text = cliente.nombreCompleto;
              });
              // 💾 Guardar estado completo al cambiar cliente
              _guardarEstadoCompleto();
            },
            fieldViewBuilder:
                (
                  BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  // Si hay cliente seleccionado, mostrar su nombre
                  if (_clienteSeleccionado != null &&
                      textEditingController.text.isEmpty) {
                    textEditingController.text =
                        _clienteSeleccionado!.nombreCompleto;
                  }
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                    onChanged: (value) {
                      // ✅ Si el usuario borra todo el texto, asignar CONSUMIDOR FINAL
                      if (value.trim().isEmpty) {
                        Future.delayed(Duration(milliseconds: 300), () {
                          if (mounted &&
                              textEditingController.text.trim().isEmpty) {
                            setState(() {
                              _clienteSeleccionado = null;
                              _clienteController.text = 'CONSUMIDOR FINAL';
                            });
                            textEditingController.text = 'CONSUMIDOR FINAL';
                          }
                        });
                      } else {
                        // Actualizar el controlador principal con el texto actual
                        _clienteController.text = value;
                      }
                    },
                    onEditingComplete: () {
                      // ✅ Al terminar de editar, verificar si está vacío
                      if (textEditingController.text.trim().isEmpty) {
                        setState(() {
                          _clienteSeleccionado = null;
                          _clienteController.text = 'CONSUMIDOR FINAL';
                        });
                        textEditingController.text = 'CONSUMIDOR FINAL';
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      hintText: 'Buscar cliente...',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        size: 20,
                      ),
                      suffixIcon: Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  );
                },
            optionsViewBuilder:
                (
                  BuildContext context,
                  AutocompleteOnSelected<Cliente> onSelected,
                  Iterable<Cliente> options,
                ) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: 300,
                          maxWidth: 400,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.all(8.0),
                          itemCount: options.length,
                          shrinkWrap: true,
                          itemBuilder: (BuildContext context, int index) {
                            final Cliente cliente = options.elementAt(index);
                            final onSurface = Theme.of(context).colorScheme.onSurface;
                            return InkWell(
                              onTap: () => onSelected(cliente),
                              child: Container(
                                padding: EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: onSurface.withOpacity(0.12),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppTheme.primary
                                          .withOpacity(0.2),
                                      radius: 18,
                                      child: Text(
                                        cliente.nombreCompleto.isNotEmpty
                                            ? cliente.nombreCompleto[0]
                                                  .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cliente.nombreCompleto,
                                            style: TextStyle(
                                              color: onSurface,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (cliente
                                              .numeroIdentificacion
                                              .isNotEmpty)
                                            Text(
                                              'Doc: ${cliente.numeroIdentificacion}',
                                              style: TextStyle(
                                                color: onSurface.withOpacity(0.7),
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
          ),
        ),
        SizedBox(width: 8),
        // Botón crear cliente
        Tooltip(
          message: 'Crear cliente',
          child: InkWell(
            onTap: _crearCliente,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_add, color: Colors.white, size: 20),
            ),
          ),
        ),
        SizedBox(width: 4),
        // Botón limpiar cliente
        if (_clienteSeleccionado != null)
          Tooltip(
            message: 'Quitar cliente',
            child: InkWell(
              onTap: () {
                setState(() {
                  _clienteSeleccionado = null;
                  _clienteController.text = 'CONSUMIDOR FINAL';
                });
              },
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDatosExtras() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _datosExtrasExpanded = !_datosExtrasExpanded),
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Datos extras',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Spacer(),
                      Icon(
                        _datosExtrasExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                    ],
                  ),
                ),
              ),
              if (_datosExtrasExpanded) ...[
                Divider(height: 1),
                Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: isMobile
                      ? _buildDatosExtrasMobile()
                      : _buildDatosExtrasDesktop(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExtraField(String label, Widget input) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(height: 8),
        input,
      ],
    );
  }

  InputDecoration get _extraInputDecoration => InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      );

  Widget _buildDatosExtrasMobile() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildExtraField('ORDEN COMPRA', TextField(
              controller: _ordenCompraController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: _extraInputDecoration,
            ))),
            SizedBox(width: 12),
            Expanded(child: _buildExtraField('ORDEN SERVICIO', TextField(
              controller: _ordenServicioController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: _extraInputDecoration,
            ))),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildExtraField('ORDEN PEDIDO', TextField(
              controller: _ordenPedidoController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: _extraInputDecoration,
            ))),
            SizedBox(width: 12),
            Expanded(child: _buildExtraField('VENDEDOR', TextField(
              controller: _vendedorController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: _extraInputDecoration,
            ))),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildExtraField('FECHA COMPRA', InkWell(
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _fechaCompra ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (fecha != null) setState(() => _fechaCompra = fecha);
              },
              child: InputDecorator(
                decoration: _extraInputDecoration.copyWith(
                  suffixIcon: Icon(Icons.calendar_today, size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
                child: Text(
                  _fechaCompra != null
                      ? '${_fechaCompra!.day.toString().padLeft(2,'0')}/${_fechaCompra!.month.toString().padLeft(2,'0')}/${_fechaCompra!.year}'
                      : 'Seleccionar',
                  style: TextStyle(
                    fontSize: 13,
                    color: _fechaCompra != null
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ))),
            SizedBox(width: 12),
            Expanded(child: _buildExtraField('FECHA DCTO PAGO', InkWell(
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _fechaDctoPago ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (fecha != null) setState(() => _fechaDctoPago = fecha);
              },
              child: InputDecorator(
                decoration: _extraInputDecoration.copyWith(
                  suffixIcon: Icon(Icons.calendar_today, size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
                child: Text(
                  _fechaDctoPago != null
                      ? '${_fechaDctoPago!.year}-${_fechaDctoPago!.month.toString().padLeft(2,'0')}-${_fechaDctoPago!.day.toString().padLeft(2,'0')}'
                      : 'Seleccionar',
                  style: TextStyle(
                    fontSize: 13,
                    color: _fechaDctoPago != null
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ))),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildExtraField('% DCTO PAGO', TextField(
              controller: _porcentajeDctoPagoController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: _extraInputDecoration,
            ))),
            SizedBox(width: 12),
            Expanded(child: _buildExtraField('LISTA DE PRECIO', DropdownButtonFormField<String>(
              value: _listaPrecios,
              decoration: _extraInputDecoration,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              items: ['Detal', 'Mayor', 'Distribuidor']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => _listaPrecios = v!),
            ))),
          ],
        ),
        SizedBox(height: 12),
        _buildExtraField('# GUIA', TextField(
          controller: _guiaController,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
          decoration: _extraInputDecoration,
        )),
      ],
    );
  }

  Widget _buildDatosExtrasDesktop() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildExtraField('ORDEN COMPRA', TextField(
              controller: _ordenCompraController,
              style: TextStyle(color: onSurface, fontSize: 14),
              decoration: _extraInputDecoration,
            ))),
            SizedBox(width: 16),
            Expanded(child: _buildExtraField('FECHA COMPRA', InkWell(
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _fechaCompra ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (fecha != null) setState(() => _fechaCompra = fecha);
              },
              child: InputDecorator(
                decoration: _extraInputDecoration.copyWith(
                  suffixIcon: Icon(Icons.calendar_today, color: onSurface.withOpacity(0.6)),
                ),
                child: Text(
                  _fechaCompra != null
                      ? '${_fechaCompra!.day.toString().padLeft(2,'0')}/${_fechaCompra!.month.toString().padLeft(2,'0')}/${_fechaCompra!.year}'
                      : 'mm/dd/yyyy',
                  style: TextStyle(
                    color: _fechaCompra != null ? onSurface : onSurface.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            ))),
            SizedBox(width: 16),
            Expanded(child: _buildExtraField('ORDEN SERVICIO', TextField(
              controller: _ordenServicioController,
              style: TextStyle(color: onSurface, fontSize: 14),
              decoration: _extraInputDecoration,
            ))),
            SizedBox(width: 16),
            Expanded(child: _buildExtraField('ORDEN PEDIDO', TextField(
              controller: _ordenPedidoController,
              style: TextStyle(color: onSurface, fontSize: 14),
              decoration: _extraInputDecoration,
            ))),
            SizedBox(width: 16),
            Expanded(child: _buildExtraField('VENDEDOR', TextField(
              controller: _vendedorController,
              style: TextStyle(color: onSurface, fontSize: 14),
              decoration: _extraInputDecoration,
            ))),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildExtraField('% DCTO PAGO', TextField(
              controller: _porcentajeDctoPagoController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: onSurface, fontSize: 14),
              decoration: _extraInputDecoration,
            ))),
            SizedBox(width: 16),
            Expanded(child: _buildExtraField('LISTA DE PRECIO', DropdownButtonFormField<String>(
              value: _listaPrecios,
              decoration: _extraInputDecoration,
              style: TextStyle(color: onSurface, fontSize: 14),
              items: ['Detal', 'Mayor', 'Distribuidor']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => _listaPrecios = v!),
            ))),
            SizedBox(width: 16),
            Expanded(child: _buildExtraField('# GUIA', TextField(
              controller: _guiaController,
              style: TextStyle(color: onSurface, fontSize: 14),
              decoration: _extraInputDecoration,
            ))),
            SizedBox(width: 16),
            Expanded(child: _buildExtraField('FECHA DCTO PAGO', InkWell(
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _fechaDctoPago ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (fecha != null) setState(() => _fechaDctoPago = fecha);
              },
              child: InputDecorator(
                decoration: _extraInputDecoration.copyWith(
                  suffixIcon: Icon(Icons.calendar_today, color: onSurface.withOpacity(0.6)),
                ),
                child: Text(
                  _fechaDctoPago != null
                      ? '${_fechaDctoPago!.year}-${_fechaDctoPago!.month.toString().padLeft(2,'0')}-${_fechaDctoPago!.day.toString().padLeft(2,'0')}'
                      : '2026-02-18',
                  style: TextStyle(
                    color: _fechaDctoPago != null ? onSurface : onSurface.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            ))),
            Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildDatosProducto() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(
              () => _datosProductoExpanded = !_datosProductoExpanded,
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Datos Producto',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    _datosProductoExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ],
              ),
            ),
          ),
          if (_datosProductoExpanded) ...[
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  // Código de barras
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'CÓD.\nBARRAS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _codigoBarrasController,
                          autofocus: true,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _codigoBarrasController.text.isNotEmpty
                                    ? AppTheme.primary
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppTheme.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            hintText: 'Escanee o ingrese código',
                            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                            prefixIcon: Icon(
                              Icons.qr_code_scanner,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            suffixIcon: _codigoBarrasController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.search,
                                      color: AppTheme.primary,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _buscarProductoPorCodigoBarras(
                                        _codigoBarrasController.text,
                                      );
                                      _codigoBarrasController.clear();
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(
                              () {},
                            ); // Para actualizar el icono de búsqueda
                          },
                          onSubmitted: (value) async {
                            if (value.isNotEmpty) {
                              // Esperar un momento para que se vea el código escaneado
                              await Future.delayed(Duration(milliseconds: 500));
                              await _buscarProductoPorCodigoBarras(value);
                              // Esperar otro momento para que se vea el resultado
                              await Future.delayed(Duration(milliseconds: 800));
                              // Limpiar y mantener el foco para siguiente escaneo
                              _codigoBarrasController.clear();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Fila de datos del producto
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Autocomplete<Producto>(
                          key: ValueKey(
                            'codigo_$_autocompleteResetKey',
                          ), // ✅ Fuerza reconstrucción al limpiar
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<Producto>.empty();
                            }
                            // Buscar por código - sin requisito de mínimo 2 caracteres
                            final texto = textEditingValue.text.toLowerCase();
                            return _productosDisponibles
                                .where((p) {
                                  final cod = (p.codigo ?? '').toLowerCase();
                                  return cod.contains(texto) || cod.startsWith(texto);
                                })
                                .take(15);
                          },
                          displayStringForOption: (Producto producto) =>
                              producto.codigo ?? '',
                          onSelected: (Producto producto) {
                            setState(() {
                              _productoSeleccionado = producto;
                              _codigoController.text = producto.codigo ?? '';
                              _nombreProductoController.text = producto.nombre;
                              final ivaPct = producto.impuestos > 0 ? producto.impuestos : 19.0;
                              final precioBase = producto.precio / (1 + ivaPct / 100);
                              _valorUnitController.text = precioBase.toStringAsFixed(2);
                              _porcentajeImpuestoController.text = ivaPct.toStringAsFixed(0);
                            });
                          },
                          fieldViewBuilder:
                              (
                                BuildContext context,
                                TextEditingController textEditingController,
                                FocusNode focusNode,
                                VoidCallback onFieldSubmitted,
                              ) {
                                // Sincronizar con el controlador principal
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  textEditingController.text = _codigoController.text;
                                });
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    hintText: 'Código...',
                                    hintStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                );
                              },
                          optionsViewBuilder:
                              (
                                BuildContext context,
                                AutocompleteOnSelected<Producto> onSelected,
                                Iterable<Producto> options,
                              ) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxHeight: 250,
                                        maxWidth: 150,
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.all(8.0),
                                        itemCount: options.length,
                                        shrinkWrap: true,
                                        itemBuilder: (BuildContext context, int index) {
                                          final Producto option = options.elementAt(index);
                                          return InkWell(
                                            onTap: () => onSelected(option),
                                            child: Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Text(
                                                (option.codigo?.isNotEmpty ?? false)
                                                    ? option.codigo!
                                                    : option.id,
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Autocomplete<Producto>(
                          key: ValueKey(
                            'nombre_$_autocompleteResetKey',
                          ), // ✅ Fuerza reconstrucción al limpiar
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<Producto>.empty();
                            }
                            if (textEditingValue.text.length < 2) {
                              return const Iterable<Producto>.empty();
                            }
                            appLog('🔍 Autocomplete nombre - _productosDisponibles.length: ${_productosDisponibles.length}');
                            return filtrarYOrdenarProductos(
                              _productosDisponibles,
                              textEditingValue.text,
                              limite: 15,
                            );
                          },
                          displayStringForOption: (Producto producto) =>
                              producto.nombre,
                          onSelected: (Producto producto) {
                            setState(() {
                              _productoSeleccionado = producto;
                              _codigoController.text = producto.codigo ?? '';
                              _nombreProductoController.text = producto.nombre;
                              final ivaPct = producto.impuestos > 0 ? producto.impuestos : 19.0;
                              final precioBase = producto.precio / (1 + ivaPct / 100);
                              _valorUnitController.text = precioBase.toStringAsFixed(2);
                              _porcentajeImpuestoController.text = ivaPct.toStringAsFixed(0);
                            });
                          },
                          fieldViewBuilder:
                              (
                                BuildContext context,
                                TextEditingController textEditingController,
                                FocusNode focusNode,
                                VoidCallback onFieldSubmitted,
                              ) {
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    hintText: _productosDisponibles.isEmpty
                                        ? 'No hay productos disponibles'
                                        : 'Escribe al menos 2 letras...',
                                    hintStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixIcon: Icon(
                                      Icons.arrow_drop_down,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      size: 20,
                                    ),
                                  ),
                                );
                              },
                          optionsViewBuilder:
                              (
                                BuildContext context,
                                AutocompleteOnSelected<Producto> onSelected,
                                Iterable<Producto> options,
                              ) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxHeight: 300,
                                        maxWidth: 400,
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.all(8.0),
                                        itemCount: options.length,
                                        shrinkWrap: true,
                                        itemBuilder: (BuildContext context, int index) {
                                          final Producto option = options.elementAt(
                                            index,
                                          );
                                          return InkWell(
                                            onTap: () => onSelected(option),
                                            child: Container(
                                              padding: EdgeInsets.all(12.0),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                                                        .withOpacity(0.2),
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    option.nombre,
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    (option.codigo?.isNotEmpty ?? false)
                                                        ? 'Código: ${option.codigo}'
                                                        : 'Código: ${option.id}',
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    '\$${option.precio.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      color: AppTheme.primary,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _cantidadController,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Cantidad',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _valorUnitController,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Valor unit',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            prefixText: '\$',
                            prefixStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          enabled: false,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Valor tot',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          controller: TextEditingController(
                            text: _calcularValorTotal(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // 📦 MOSTRAR STOCK DISPONIBLE CON BOTÓN REFRESCAR
                  if (_productoSeleccionado != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Stock disponible: ${_productoSeleccionado!.nombre}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Refrescar stock',
                                icon: Icon(
                                  Icons.refresh,
                                  color: AppTheme.primary,
                                ),
                                onPressed: () async {
                                  if (_productoSeleccionado == null) return;
                                  setState(() => _isLoading = true);
                                  try {
                                    // 🗑️ Invalidar caché para forzar lectura fresca de la API
                                    _productoService.invalidarProducto(
                                      _productoSeleccionado!.id,
                                    );
                                    final productoActualizado =
                                        await _productoService.getProducto(
                                          _productoSeleccionado!.id,
                                        );
                                    if (productoActualizado != null) {
                                      setState(() {
                                        _productoSeleccionado =
                                            productoActualizado;
                                        // También actualiza la lista si es necesario
                                        final idx = _productosDisponibles
                                            .indexWhere(
                                              (p) =>
                                                  p.id ==
                                                  productoActualizado.id,
                                            );
                                        if (idx != -1) {
                                          _productosDisponibles[idx] =
                                              productoActualizado;
                                        }
                                      });
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'No se encontró el producto actualizado',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error al refrescar stock: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } finally {
                                    setState(() => _isLoading = false);
                                  }
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'ALMACÉN',
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${_productoSeleccionado!.almacen ?? 0}',
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'BODEGA',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${_productoSeleccionado!.bodega ?? 0}',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 16),
                  // 📦 Fila de selección de BODEGA/ALMACÉN
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 500;
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _origenSeleccionado,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                              dropdownColor: Theme.of(context).colorScheme.surface,
                              decoration: InputDecoration(
                                labelText: 'Origen',
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                prefixIcon: Icon(Icons.warehouse,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                              ),
                              items: ['BODEGA', 'ALMACÉN']
                                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                                  .toList(),
                              onChanged: (v) => setState(() => _origenSeleccionado = v ?? 'ALMACÉN'),
                            ),
                          ),
                          if (!isMobile) ...[
                            SizedBox(width: 12),
                            Text(
                              'Selecciona de dónde vender',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  // Fila de impuestos, descuentos y botón agregar
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 500;
                      final inputDecBase = InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      );
                      final labelStyle = TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12,
                      );
                      final fieldStyle = TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                      );
                      final tipoImpuestoField = Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: _tipoImpuesto,
                          style: fieldStyle,
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          decoration: inputDecBase.copyWith(
                            labelText: 'Tipo Imp.',
                            labelStyle: labelStyle,
                          ),
                          items: ['IVA', 'IMPOCONSUMO', 'NINGUNO']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(() => _tipoImpuesto = v!),
                        ),
                      );
                      final pctImpField = Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _porcentajeImpuestoController,
                          style: fieldStyle,
                          decoration: inputDecBase.copyWith(
                            labelText: '% Imp.',
                            labelStyle: labelStyle,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      );
                      final tipoDescField = Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: _porcentajeTipoDescuento,
                          style: fieldStyle,
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          decoration: inputDecBase.copyWith(
                            labelText: 'Tipo Dcto.',
                            labelStyle: labelStyle,
                          ),
                          items: ['Porcentaje', 'Valor']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(() => _porcentajeTipoDescuento = v!),
                        ),
                      );
                      final pctDctoField = Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _porcentajeDescuentoController,
                          style: fieldStyle,
                          decoration: inputDecBase.copyWith(
                            labelText: _porcentajeTipoDescuento == 'Porcentaje' ? '% Dcto.' : '\$ Dcto.',
                            labelStyle: labelStyle,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      );
                      final agregarBtn = SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _agregarItem,
                          icon: Icon(Icons.add, size: 18),
                          label: Text('Agregar', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                          ),
                        ),
                      );

                      if (isMobile) {
                        return Column(
                          children: [
                            Row(children: [tipoImpuestoField, SizedBox(width: 8), pctImpField]),
                            SizedBox(height: 8),
                            Row(children: [tipoDescField, SizedBox(width: 8), pctDctoField]),
                            SizedBox(height: 8),
                            SizedBox(width: double.infinity, child: agregarBtn),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          tipoImpuestoField, SizedBox(width: 8),
                          pctImpField, SizedBox(width: 8),
                          tipoDescField, SizedBox(width: 8),
                          pctDctoField, SizedBox(width: 12),
                          agregarBtn,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        padding: EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              SizedBox(height: 16),
              Text(
                'No hay productos agregados',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Producto',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Cantidad',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'P. Unit',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Impuesto',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Descuento',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Origen',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                SizedBox(width: 50),
              ],
            ),
          ),
          // Items
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.2),
            ),
            itemBuilder: (context, index) {
              final item = _items[index];
              return ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.productoNombre ?? 'Producto',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${item.cantidad}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '\$${item.precioUnitario.toStringAsFixed(0)}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        item.valorImpuesto > 0
                            ? '\$${item.valorImpuesto.toStringAsFixed(0)}'
                            : '-',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        item.valorDescuento > 0
                            ? '\$${item.valorDescuento.toStringAsFixed(0)}'
                            : '-',
                        style: TextStyle(
                          color: item.valorDescuento > 0 ? Colors.green : Theme.of(context).colorScheme.onSurface,
                          fontWeight: item.valorDescuento > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: InkWell(
                        onTap: () => _editarTotalItem(index),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '\$${(item.subtotal + item.valorImpuesto - item.valorDescuento).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.edit,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.origen == 'BODEGA'
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.origen,
                          style: TextStyle(
                            color: item.origen == 'BODEGA'
                                ? Colors.blue
                                : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red[400]),
                      onPressed: () => _eliminarItem(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRetencionesYAIU() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _retencionesExpanded = !_retencionesExpanded),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.calculate, color: AppTheme.primary, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Retenciones, AIU y Descuentos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    _retencionesExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
          if (_retencionesExpanded) ...[
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;

                  if (isMobile) {
                    return Column(
                      children: [
                        // Primera fila: Retención y ReteIVA
                        Row(
                          children: [
                            Expanded(
                              child: _buildRetencionField(
                                'Retención',
                                _retencionController,
                                '%',
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildRetencionField(
                                'ReteIVA',
                                _reteIVAController,
                                '%',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        // Segunda fila: ReteICA y AIU
                        Row(
                          children: [
                            Expanded(
                              child: _buildRetencionField(
                                'ReteICA',
                                _reteICAController,
                                '%',
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildRetencionField(
                                'AIU',
                                _aiuController,
                                '%',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildRetencionField(
                            'Retención',
                            _retencionController,
                            '%',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildRetencionField(
                            'ReteIVA',
                            _reteIVAController,
                            '%',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildRetencionField(
                            'ReteICA',
                            _reteICAController,
                            '%',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildRetencionField(
                            'AIU',
                            _aiuController,
                            '%',
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescuentoGeneral() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(Icons.local_offer, color: AppTheme.primary, size: 22),
          SizedBox(width: 12),
          Text(
            'Descuento General',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(width: 16),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _dctoGeneralController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                prefixText: '\$ ',
                prefixStyle: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                hintText: '0',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetencionField(
    String label,
    TextEditingController controller,
    String suffix,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            suffixText: suffix,
            suffixStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
        ),
      ],
    );
  }

  String _calcularValorTotal() {
    final cantidad = int.tryParse(_cantidadController.text) ?? 0;
    final valorUnit = double.tryParse(_valorUnitController.text) ?? 0;
    final porcentajeImp =
        double.tryParse(_porcentajeImpuestoController.text) ?? 0;
    final enteredDesc =
        double.tryParse(_porcentajeDescuentoController.text) ?? 0;

    final subtotal = cantidad * valorUnit;
    final double descuento;
    if (_porcentajeTipoDescuento == 'Porcentaje') {
      descuento = subtotal * (enteredDesc / 100);
    } else {
      descuento = enteredDesc;
    }
    final baseGravable = subtotal - descuento;
    final impuesto = baseGravable * (porcentajeImp / 100);
    final total = baseGravable + impuesto;

    return '\$${total.toStringAsFixed(0)}';
  }

  void _agregarItem() {
    // ✅ VALIDACIÓN 1: Producto seleccionado
    if (_productoSeleccionado == null) {
      showWarningSnackBar(context, '❌ Debe seleccionar un producto');
      return;
    }

    // ✅ VALIDACIÓN 2: Valor unitario
    if (_valorUnitController.text.isEmpty) {
      showWarningSnackBar(context, '❌ Complete el valor del producto');
      return;
    }

    final cantidad = int.tryParse(_cantidadController.text) ?? 1;

    // ✅ VALIDACIÓN 3: Stock disponible para productos (no servicios, con control de inventario)
    final esServicio =
        _productoSeleccionado!.productoOServicio?.toLowerCase().contains(
          'servicio',
        ) ??
        false;
    // Si controlInventario es null o no es explícitamente 'no', se asume que tiene control de inventario
    final tieneControlInventario =
        _productoSeleccionado!.controlInventario?.toLowerCase() != 'no';

    if (!esServicio && tieneControlInventario) {
      int stockDisponible = 0;

      // Obtener stock según el origen seleccionado
      if (_origenSeleccionado == 'ALMACÉN') {
        stockDisponible = _productoSeleccionado!.almacen ?? 0;
      } else if (_origenSeleccionado == 'BODEGA') {
        stockDisponible = _productoSeleccionado!.bodega ?? 0;
      }

      // Bloquear si no hay stock suficiente
      if (stockDisponible <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Sin stock en $_origenSeleccionado (disponible: 0)',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      if (cantidad > stockDisponible) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Stock insuficiente en $_origenSeleccionado\n'
              'Solicitado: $cantidad - Disponible: $stockDisponible',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    final precioUnitario = double.tryParse(_valorUnitController.text) ?? 0;
    final porcentajeImpuesto =
        double.tryParse(_porcentajeImpuestoController.text) ?? 0;
    final enteredDescuento =
        double.tryParse(_porcentajeDescuentoController.text) ?? 0;

    final subtotal = cantidad * precioUnitario;

    // 1. Descuento
    final double valorDescuento;
    final double porcentajeDescuento;
    if (_porcentajeTipoDescuento == 'Porcentaje') {
      valorDescuento = subtotal * (enteredDescuento / 100);
      porcentajeDescuento = enteredDescuento;
    } else { // 'Valor' — monto fijo
      valorDescuento = enteredDescuento;
      porcentajeDescuento = subtotal > 0 ? (enteredDescuento / subtotal) * 100 : 0;
    }

    // 2. IVA calculado sobre la base neta (precioUnitario ya es el valor sin IVA)
    final baseGravable = subtotal - valorDescuento;
    final valorImpuesto = baseGravable * (porcentajeImpuesto / 100);

    final item = ItemPedido(
      productoId: (_productoSeleccionado!.codigo?.isNotEmpty ?? false)
          ? _productoSeleccionado!.codigo!
          : _productoSeleccionado!.id,
      productoNombre: _productoSeleccionado!.nombre,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      porcentajeImpuesto: porcentajeImpuesto,
      valorImpuesto: valorImpuesto,
      porcentajeDescuento: porcentajeDescuento,
      valorDescuento: valorDescuento,
      origen: _origenSeleccionado,
    );

    // Guardar el id MongoDB del producto para poder notificar traslados tras la venta
    _productoMongoIds[item.productoId] = _productoSeleccionado!.id;

    setState(() {
      _items.add(item);
      _limpiarFormularioProducto();
    });

    // 📋 Guardar estado completo en provider
    _guardarEstadoCompleto();
    
    // ✅ Mensaje de confirmación
    showSuccessSnackBar(context, '✅ Producto agregado desde $_origenSeleccionado');
  }

  void _eliminarItem(int index) {
    setState(() {
      _items.removeAt(index);
    });

    // � Guardar estado completo en provider
    _guardarEstadoCompleto();
  }

  /// Reconstruye el ítem a partir de un nuevo valor TOTAL editado manualmente.
  /// Mantiene fijos: cantidad, % impuesto y % descuento. A partir de esos y
  /// del total ingresado, despeja el precio base y el valor del impuesto:
  ///   total = subtotalBase × (1 - %dcto/100) × (1 + %iva/100)
  ///   subtotalBase = total / [(1 - %dcto/100) × (1 + %iva/100)]
  ItemPedido _recalcularItemDesdeTotal(ItemPedido item, double nuevoTotal) {
    final r = item.porcentajeImpuesto;
    final d = item.porcentajeDescuento;
    final factorDescuento = 1 - (d / 100);
    final factorImpuesto = 1 + (r / 100);
    final denominador = factorDescuento * factorImpuesto;

    final nuevoSubtotalBase = denominador > 0 ? nuevoTotal / denominador : nuevoTotal;
    final nuevoPrecioUnitario =
        item.cantidad > 0 ? nuevoSubtotalBase / item.cantidad : nuevoSubtotalBase;
    final nuevoValorDescuento = nuevoSubtotalBase * (d / 100);
    final baseGravable = nuevoSubtotalBase - nuevoValorDescuento;
    final nuevoValorImpuesto = baseGravable * (r / 100);

    return ItemPedido(
      id: item.id,
      productoId: item.productoId,
      productoNombre: item.productoNombre,
      cantidad: item.cantidad,
      precioUnitario: nuevoPrecioUnitario,
      notas: item.notas,
      ingredientesSeleccionados: item.ingredientesSeleccionados,
      ingredientesUsados: item.ingredientesUsados,
      agregadoPor: item.agregadoPor,
      fechaAgregado: item.fechaAgregado,
      porcentajeImpuesto: r,
      valorImpuesto: nuevoValorImpuesto,
      porcentajeDescuento: d,
      valorDescuento: nuevoValorDescuento,
      origen: item.origen,
      trasladoId: item.trasladoId,
    );
  }

  /// Abre un diálogo para editar el valor TOTAL de un ítem ya agregado,
  /// recalculando el precio base y el impuesto a partir de ese total.
  Future<void> _editarTotalItem(int index) async {
    final item = _items[index];
    final totalActual = item.subtotal + item.valorImpuesto - item.valorDescuento;
    final controller = TextEditingController(text: totalActual.toStringAsFixed(0));

    final nuevoTotal = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar total'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: item.productoNombre ?? 'Producto',
            prefixText: '\$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (nuevoTotal == null || nuevoTotal < 0) return;

    setState(() {
      _items[index] = _recalcularItemDesdeTotal(item, nuevoTotal);
    });

    _guardarEstadoCompleto();
  }

  void _limpiarFormularioProducto() {
    _codigoBarrasController.clear();
    _codigoController.clear();
    _nombreProductoController.clear();
    _cantidadController.text = '1';
    _valorUnitController.clear();
    _porcentajeImpuestoController.text = '19';
    _porcentajeDescuentoController.text = '0';
    _origenSeleccionado = 'ALMACÉN';
    _productoSeleccionado = null;
    _autocompleteResetKey++; // fuerza reset visual de los Autocomplete de código y nombre
  }

  Future<void> _buscarProductoPorCodigoBarras(String codigo) async {
    if (codigo.isEmpty) return;

    // 🧹 LIMPIAR el código: eliminar espacios, saltos de línea, retornos de carro
    // y cualquier carácter no visible que el lector pueda agregar
    final codigoLimpio = codigo.trim().replaceAll(RegExp(r'[\r\n\t]'), '');

    if (codigoLimpio.isEmpty) return;

    Producto? producto;
    String codigoUsado = codigoLimpio;

    try {
      // 🚀 INTENTO 1: Buscar con el código completo
      producto = await _productoService.getProductoPorCodigoBarras(
        codigoLimpio,
      );

      // 🔄 INTENTO 2: Si no se encuentra y tiene más de 3 caracteres,
      // intentar quitando el último dígito (el lector puede agregar un carácter extra)
      if (producto == null && codigoLimpio.length > 3) {
        final codigoSinUltimo = codigoLimpio.substring(0, codigoLimpio.length - 1);
        producto = await _productoService.getProductoPorCodigoBarras(
          codigoSinUltimo,
        );
        
        if (producto != null) {
          codigoUsado = codigoSinUltimo;
        }
      }

      if (producto == null) {
        throw Exception('Producto no encontrado');
      }

      setState(() {
        _productoSeleccionado = producto;
        _codigoController.text =
            (producto!.codigo != null && producto.codigo!.isNotEmpty)
            ? producto.codigo!
            : 'SIN CÓDIGO';
        _nombreProductoController.text = producto.nombre;
        final ivaPct = producto.impuestos > 0 ? producto.impuestos : 19.0;
        final precioBase = producto.precio / (1 + ivaPct / 100);
        _valorUnitController.text = precioBase.toStringAsFixed(2);
        _porcentajeImpuestoController.text = ivaPct.toStringAsFixed(0);
      });

      // Mostrar feedback visual de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✓ ${producto!.nombre} - \$${producto.precio.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );

      // Agregar automáticamente el producto si está configurado
      // (comentado por defecto, descomentar si se quiere agregar automáticamente)
      // _agregarItem();
    } catch (e) {
      // Mostrar error con feedback visual
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Producto no encontrado: $codigoLimpio',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 80, left: 16, right: 16),
        ),
      );

      // NO limpiar los campos - dejar el código para que el usuario pueda verlo
      setState(() {
        _productoSeleccionado = null;
        // Mantener el código escaneado visible en el campo
        _codigoController.text = codigoLimpio;
        _nombreProductoController.clear();
        _valorUnitController.clear();
      });
    }
  }

  void _crearCliente() async {
    // Navegar al formulario de crear cliente
    final resultado = await context.push('/clientes/form');

    // Si se creó un cliente, actualizar el campo y la lista
    if (resultado != null && resultado is Cliente) {
      setState(() {
        _clienteSeleccionado = resultado;
        _clienteController.text = resultado.nombreCompleto;
        // Agregar el nuevo cliente a la lista
        _clientesDisponibles.add(resultado);
      });

      showSuccessSnackBar(context, 'Cliente creado exitosamente');
    }
  }

  // Widget para seleccionar método de pago
  Widget _buildMetodoPago() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Método de Pago',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _metodosPago.map((metodo) {
              final isSelected = _metodoPago == metodo['value'];
              return InkWell(
                onTap: () {
                  setState(() => _metodoPago = metodo['value']);
                  // 💾 Guardar estado completo al cambiar método de pago
                  _guardarEstadoCompleto();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withOpacity(0.2)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        metodo['icon'],
                        color: isSelected
                            ? AppTheme.primary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        metodo['label'],
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          // Advertencia de crédito
          if (_metodoPago == 'credito') ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Se creará una deuda automáticamente para este cliente (vence en 30 días). El campo "Cliente" es obligatorio.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Campos para pago múltiple
          if (_metodoPago == 'multiple') ...[
            SizedBox(height: 20),
            Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.3)),
            SizedBox(height: 16),
            Text(
              'Distribución del pago',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Efectivo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _montoEfectivoController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: AppTheme.primary,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transferencia',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _montoTransferenciaController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: Icon(
                            Icons.account_balance,
                            color: AppTheme.primary,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tarjeta',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _montoTarjetaController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: Icon(
                            Icons.credit_card,
                            color: AppTheme.primary,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sistecredito',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _montoSistereditoController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: Icon(
                            Icons.card_giftcard,
                            color: AppTheme.primary,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Cargar facturas en borrador
  Future<void> _mostrarBorradores() async {
    setState(() => _isLoading = true);

    try {
      // ⚡ OPTIMIZADO: Usar endpoint específico para pedidos activos de FACTURACION
      // En lugar de traer TODOS los pedidos históricos
      final borradores = await _pedidoService.getPedidosActivosMesa(
        'FACTURACION',
      );

      setState(() => _isLoading = false);

      if (borradores.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info, color: Colors.white),
                SizedBox(width: 8),
                Text('No hay facturas en borrador'),
              ],
            ),
            backgroundColor: Colors.blue,
          ),
        );
        return;
      }

      // Mostrar diálogo con lista de borradores
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.drafts, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Facturas en borrador',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: borradores.length,
              itemBuilder: (context, index) {
                final borrador = borradores[index];
                return Card(
                  color: Theme.of(context).colorScheme.surface,
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(Icons.receipt, color: AppTheme.primary),
                    title: Text(
                      borrador.cliente ?? 'Sin cliente',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${borrador.items.length} productos - \$${borrador.total.toStringAsFixed(0)}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        Text(
                          '${borrador.fecha.day}/${borrador.fecha.month}/${borrador.fecha.year}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: AppTheme.primary),
                          onPressed: () {
                            Navigator.pop(context);
                            _cargarBorrador(borrador);
                          },
                          tooltip: 'Editar',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirmar = await showConfirmDialog(
                              context,
                              title: '¿Eliminar borrador?',
                              content: '¿Está seguro de eliminar este borrador?',
                              confirmText: 'Eliminar',
                              isDangerous: true,
                            );

                            if (confirmar == true) {
                              try {
                                await _pedidoService.eliminarPedido(
                                  borrador.id,
                                );
                                Navigator.pop(context);
                                _mostrarBorradores();
                              } catch (e) {
                                showErrorSnackBar(context, 'Error al eliminar: $e');
                              }
                            }
                          },
                          tooltip: 'Eliminar',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      showErrorSnackBar(context, 'Error al cargar borradores: $e');
    }
  }

  // Cargar un borrador en el formulario
  void _cargarBorrador(Pedido pedido) {
    setState(() {
      _clienteController.text = pedido.cliente ?? 'CONSUMIDOR FINAL';
      _fechaFactura = pedido.fecha;
      _fechaVencimiento =
          pedido.fechaVencimiento ?? DateTime.now().add(Duration(days: 30));
      _tipoFactura = pedido.tipoFactura ?? 'POS';
    });

    // Mostrar el mismo diálogo de edición de IVA/descuento que se usa
    // al cargar un pedido de asesor, antes de volcar los items a la tabla.
    _mostrarDialogoEditarItemsBorrador(pedido);
  }

  /// Diálogo (idéntico en estructura al de pedidos de asesor) para editar
  /// el % de IVA y el % de descuento de cada ítem de un borrador antes de
  /// cargarlo en la factura. El precio mostrado ya es la base neta (sin IVA)
  /// tal como se guarda en los borradores propios de esta pantalla.
  Future<void> _mostrarDialogoEditarItemsBorrador(Pedido pedido) async {
    if (!mounted) return;

    final items = _normalizarItemsIVA(List.from(pedido.items));

    final ivaCtrs = items
        .map((i) => TextEditingController(text: i.porcentajeImpuesto.toStringAsFixed(0)))
        .toList();
    final dctoCtrs = items
        .map((i) => TextEditingController(text: i.porcentajeDescuento.toStringAsFixed(0)))
        .toList();

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(context);
        final textStyle = TextStyle(fontSize: 12, color: theme.colorScheme.onSurface);
        final headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface);
        final inputDec = InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: const OutlineInputBorder(),
          suffixText: '%',
          suffixStyle: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        );

        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Borrador de ${pedido.cliente ?? "cliente"}', style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface)),
                    Text('Edita IVA y descuento antes de cargar', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 740,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cabecera de columnas
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: Text('Producto', style: headerStyle)),
                      SizedBox(width: 44, child: Text('Cant.', style: headerStyle, textAlign: TextAlign.center)),
                      SizedBox(width: 78, child: Text('Precio base', style: headerStyle, textAlign: TextAlign.right)),
                      const SizedBox(width: 8),
                      SizedBox(width: 64, child: Text('IVA %', style: headerStyle, textAlign: TextAlign.center)),
                      const SizedBox(width: 8),
                      SizedBox(width: 64, child: Text('Dcto %', style: headerStyle, textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 4),
                // Lista de items con scroll
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (_, idx) {
                      final item = items[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                item.productoNombre ?? '-',
                                style: textStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text('${item.cantidad}', style: textStyle, textAlign: TextAlign.center),
                            ),
                            SizedBox(
                              width: 78,
                              child: Text(
                                '\$${item.precioUnitario.toStringAsFixed(0)}',
                                style: textStyle.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: TextField(
                                controller: ivaCtrs[idx],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                                decoration: inputDec,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: TextField(
                                controller: dctoCtrs[idx],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                                decoration: inputDec,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Sin cambios'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Aplicar y cargar'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );

    // Leer valores antes de hacer dispose
    final ivaValues = ivaCtrs.map((c) => double.tryParse(c.text) ?? 0.0).toList();
    final dctoValues = dctoCtrs.map((c) => double.tryParse(c.text) ?? 0.0).toList();
    for (final c in ivaCtrs) { c.dispose(); }
    for (final c in dctoCtrs) { c.dispose(); }

    if (!mounted) return;

    final List<ItemPedido> itemsCargados;
    if (confirmar == true) {
      // El precio base de un borrador propio ya es neto (sin IVA), así que
      // solo se recalculan descuento e impuesto con los % editados.
      itemsCargados = items.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final ivaPct = ivaValues[idx];
        final dctoPct = dctoValues[idx];
        final subtotal = item.precioUnitario * item.cantidad;
        final valorDescuento = subtotal * (dctoPct / 100);
        final baseGravable = subtotal - valorDescuento;
        final valorImpuesto = ivaPct > 0 && ivaPct < 100
            ? baseGravable * (ivaPct / 100)
            : 0.0;
        return ItemPedido(
          productoId: item.productoId,
          productoNombre: item.productoNombre,
          cantidad: item.cantidad,
          precioUnitario: item.precioUnitario,
          porcentajeImpuesto: ivaPct,
          valorImpuesto: valorImpuesto,
          porcentajeDescuento: dctoPct,
          valorDescuento: valorDescuento,
          origen: item.origen,
          trasladoId: item.trasladoId,
        );
      }).toList();
    } else {
      // Sin cambios: usar los items ya normalizados tal cual estaban en el borrador
      itemsCargados = items;
    }

    setState(() {
      _items = itemsCargados;
    });

    showSuccessSnackBar(context, 'Borrador cargado correctamente');
  }

  // Guardar como borrador (pedido activo sin pagar)
  Future<void> _guardarComoBorrador() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Agregue al menos un producto')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final subtotal = _items.fold(0.0, (sum, item) => sum + item.subtotal);
      final totalImpuestosBorrador = _items.fold(0.0, (sum, item) => sum + item.valorImpuesto);
      final totalDctoProductos = _items.fold(0.0, (sum, item) => sum + item.valorDescuento);
      final dctoGeneral = double.tryParse(_dctoGeneralController.text) ?? 0;
      final totalDescuentos = totalDctoProductos + dctoGeneral;
      final total = subtotal + totalImpuestosBorrador - totalDescuentos;

      final pedido = Pedido(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        fecha: _fechaFactura,
        tipo: TipoPedido.normal,
        mesa: 'FACTURACION',
        cliente: _clienteController.text,
        mesero:
            Provider.of<UserProvider>(context, listen: false).userName ??
            'Sistema',
        items: _items,
        total: total,
        estado: EstadoPedido.activo,
        tipoFactura: _tipoFactura,
        fechaVencimiento: _fechaVencimiento,
        subtotal: subtotal,
        totalImpuestos: totalImpuestosBorrador,
        totalDescuentos: totalDescuentos,
        totalFinal: total,
        descuentoGeneral: dctoGeneral,
      );

      await _pedidoService.createPedido(pedido);

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Pedido guardado como borrador'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );

      _limpiarFormulario();
    } catch (e) {
      setState(() => _isLoading = false);
      showErrorSnackBar(context, 'Error al guardar: $e');
    }
  }

  /// Guardar como deuda - crea un pedido activo sin pagar que queda registrado como deuda
  Future<void> _guardarComoDeuda() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Agregue al menos un producto')));
      return;
    }

    // Validar que haya un cliente diferente a CONSUMIDOR FINAL
    if (_clienteController.text.trim().toUpperCase() == 'CONSUMIDOR FINAL' ||
        _clienteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Para dejar como deuda debe seleccionar un cliente específico'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Confirmar con el usuario
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Confirmar Deuda',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Desea registrar esta venta como deuda?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeudaInfoRow('Cliente:', _clienteController.text),
                  SizedBox(height: 8),
                  _buildDeudaInfoRow(
                    'Total:',
                    '\$${_items.fold(0.0, (sum, item) => sum + item.subtotal + item.valorImpuesto - item.valorDescuento).toStringAsFixed(0)}',
                  ),
                  SizedBox(height: 8),
                  _buildDeudaInfoRow(
                    'Productos:',
                    '${_items.length} item(s)',
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Esta deuda quedará pendiente de pago y aparecerá en la sección de Cartera.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(Icons.check),
            label: Text('Confirmar Deuda'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // 🚀 CAPTURAR DATOS ANTES DE LIMPIAR
    final subtotal = _items.fold(0.0, (sum, item) => sum + item.subtotal);
    final totalImpuestosDeuda = _items.fold(0.0, (sum, item) => sum + item.valorImpuesto);
    final totalDctoDeuda = _items.fold(0.0, (sum, item) => sum + item.valorDescuento);
    final total = subtotal + totalImpuestosDeuda - totalDctoDeuda;
    final userName =
        Provider.of<UserProvider>(context, listen: false).userName ?? 'Sistema';
    final itemsOriginales = List<ItemPedido>.from(_items);
    final clienteTexto = _clienteController.text;
    final tipoFacturaCapturado = _tipoFactura;
    final fechaFacturaCapturada = _fechaFactura;
    final fechaVencimientoCapturada = _fechaVencimiento;

    // ✅ LIMPIAR FORMULARIO Y LIBERAR UI INMEDIATAMENTE
    _limpiarFormulario();

    // Mostrar mensaje de éxito inmediato (optimista)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Registrando deuda para $clienteTexto...')),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 10),
      ),
    );

    // 🚀 ENVIAR AL BACKEND EN BACKGROUND - NO BLOQUEAR UI
    Future.microtask(() async {
      try {
        final pedido = Pedido(
          id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
          fecha: fechaFacturaCapturada,
          tipo: TipoPedido.normal,
          mesa: 'DEUDA',
          cliente: clienteTexto,
          mesero: userName,
          items: itemsOriginales,
          total: total,
          estado: EstadoPedido.activo,
          tipoFactura: tipoFacturaCapturado,
          fechaVencimiento: fechaVencimientoCapturada,
          subtotal: subtotal,
          totalImpuestos: totalImpuestosDeuda,
          totalDescuentos: totalDctoDeuda,
          totalFinal: total,
          notas:
              'DEUDA - Registrada el ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        );

        await _pedidoService.createPedido(pedido);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✅ Deuda registrada exitosamente para $clienteTexto',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Ver en Cartera',
                textColor: Colors.white,
                onPressed: () {
                  context.push('/cuentas-por-cobrar');
                },
              ),
            ),
          );
        }
      } catch (e) {
        appLog('⚠️ Error al registrar deuda en background: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Error al registrar deuda: Verifica tu conexión e intenta de nuevo',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
    });
  }

  Widget _buildDeudaInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Guardar y pagar - abre el diálogo de pago
  Future<void> _guardarYPagar() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Agregue al menos un producto')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🚀 GUARDAR TODOS LOS DATOS NECESARIOS ANTES DE LIMPIAR
      final subtotal = _items.fold(0.0, (sum, item) => sum + item.subtotal);
      
      // Calcular retenciones, descuentos e IVA
      final retencionPct = double.tryParse(_retencionController.text) ?? 0;
      final reteIVAPct = double.tryParse(_reteIVAController.text) ?? 0;
      final reteICAPct = double.tryParse(_reteICAController.text) ?? 0;
      final aiuPct = double.tryParse(_aiuController.text) ?? 0;
      final dctoGeneral = double.tryParse(_dctoGeneralController.text) ?? 0;

      final retencionValor = subtotal * (retencionPct / 100);
      final reteIVAValor = subtotal * (reteIVAPct / 100);
      final reteICAValor = subtotal * (reteICAPct / 100);
      final aiuValor = subtotal * (aiuPct / 100);

      final totalImpuestos = _items.fold(0.0, (sum, item) => sum + item.valorImpuesto);
      final totalDctoProductos = _items.fold(0.0, (sum, item) => sum + item.valorDescuento);
      final totalDescuentos = dctoGeneral + totalDctoProductos;
      final totalRetenciones = retencionValor + reteIVAValor + reteICAValor;
      final total =
          subtotal +
          totalImpuestos +
          aiuValor -
          totalDescuentos -
          totalRetenciones;
      
      final userName =
          Provider.of<UserProvider>(context, listen: false).userName ??
          'Sistema';
      final itemsOriginales = List<ItemPedido>.from(
        _items,
      ); // ✅ Copia antes de limpiar
      final metodoPagoUsado = _mapFormaPagoBackend(_metodoPago);
      final medioPagoUsado = _medioPagoMap[_metodoPago] ?? 'efectivo';
      final clienteTexto = _clienteController.text;
      final tipoFacturaCapturado = _tipoFactura;
      final fechaFacturaCapturada = _fechaFactura;
      final fechaVencimientoCapturada = _fechaVencimiento;
      final montoEfectivo = _metodoPago == 'efectivo'
          ? total
          : (_metodoPago == 'multiple'
                ? double.tryParse(_montoEfectivoController.text) ?? 0.0
                : 0.0);
      final montoTransferencia = _metodoPago == 'transferencia'
          ? total
          : (_metodoPago == 'multiple'
                ? double.tryParse(_montoTransferenciaController.text) ?? 0.0
                : 0.0);
      final montoTarjeta = _metodoPago == 'tarjeta'
          ? total
          : (_metodoPago == 'multiple'
                ? double.tryParse(_montoTarjetaController.text) ?? 0.0
                : 0.0);
      final montoSistecredito = _metodoPago == 'sistecredito'
          ? total
          : (_metodoPago == 'multiple'
                ? double.tryParse(_montoSistereditoController.text) ?? 0.0
                : 0.0);
      final montoDatafono = _metodoPago == 'datafono' ? total : 0.0;
      final esPedidoAsesor = widget.pedidoAsesor != null;
      final pedidoAsesorId = widget.pedidoAsesor?.id;

      // ✅ CAPTURAR OBSERVACIONES ANTES DE LIMPIAR (para el PDF)
      final observacionesCapturadas = _observacionesController.text.trim();

      // ✅ CAPTURAR CLIENTE SELECCIONADO ANTES DE LIMPIAR (para el PDF)
      Cliente? clienteCapturado = _clienteSeleccionado;

      // Si no hay cliente seleccionado pero hay texto en el campo, buscar al cliente
      if (clienteCapturado == null &&
          clienteTexto != 'CONSUMIDOR FINAL' &&
          clienteTexto.isNotEmpty) {
        appLog(
          '⚠️ Cliente no seleccionado del dropdown, buscando en API: "$clienteTexto"',
        );
        try {
          final resultados = await _clienteService.buscarClientes(clienteTexto);
          if (resultados.isNotEmpty) {
            // Buscar coincidencia exacta primero
            final exacto = resultados.where(
              (c) =>
                  c.nombreCompleto.toLowerCase() == clienteTexto.toLowerCase(),
            );
            clienteCapturado = exacto.isNotEmpty
                ? exacto.first
                : resultados.first;
            appLog('✅ Cliente encontrado: ${clienteCapturado.nombreCompleto}');
          } else {
            appLog('❌ No se encontró cliente con ese nombre');
          }
        } catch (e) {
          appLog('❌ Error buscando cliente: $e');
        }
      }

      // ✅ LIMPIAR INMEDIATAMENTE Y LIBERAR UI - NO ESPERAR AL BACKEND
      _limpiarFormulario();
      setState(() => _isLoading = false);

      // Mostrar indicador de progreso no bloqueante
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Procesando factura...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 30),
        ),
      );

      // 🚀 TODO EN BACKGROUND - Crear pedido + pagar + inventario
      Future.microtask(() async {
        try {
          // Preparar datos completos del cliente para guardar
          Map<String, dynamic>? datosAdicionales;
          if (clienteCapturado != null) {
            datosAdicionales = {
              'clienteNombreCompleto': clienteCapturado.nombreCompleto,
              'clienteNit':
                  '${clienteCapturado.tipoIdentificacion} ${clienteCapturado.numeroIdentificacion}${clienteCapturado.digitoVerificacion != null ? "-${clienteCapturado.digitoVerificacion}" : ""}',
              'clienteDireccion': clienteCapturado.direccion,
              'clienteTelefono': clienteCapturado.telefono,
              'clienteCorreo': clienteCapturado.correo,
              'clienteDepartamento': clienteCapturado.departamento,
              'clienteCiudad': clienteCapturado.ciudad,
              'clienteTipoId': clienteCapturado.tipoIdentificacion,
            };
          }

          // Crear el pedido
          final pedido = Pedido(
            id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
            fecha: fechaFacturaCapturada,
            tipo: TipoPedido.normal,
            mesa: 'FACTURACION',
            cliente: clienteTexto,
            mesero: userName,
            items: itemsOriginales,
            total: total,
            estado: EstadoPedido.activo,
            tipoFactura: tipoFacturaCapturado,
            fechaVencimiento: fechaVencimientoCapturada,
            subtotal: subtotal,
            totalImpuestos: totalImpuestos,
            totalDescuentos: totalDescuentos,
            totalFinal: total,
            datosAdicionales: datosAdicionales,
            // ✅ Agregar campos de retenciones y descuentos
            retencion: retencionPct,
            valorRetencion: retencionValor,
            reteIVA: reteIVAPct,
            valorReteIVA: reteIVAValor,
            reteICA: reteICAPct,
            valorReteICA: reteICAValor,
            descuentoGeneral: dctoGeneral,
            aiu: {'porcentaje': aiuPct, 'valor': aiuValor},
            // ✅ Agregar observaciones capturadas
            notas: observacionesCapturadas.isNotEmpty
                ? observacionesCapturadas
                : null,
          );

          final pedidoCreado = await _pedidoService.createPedido(pedido);

          // Procesar pago
          final pedidoPagado = await _pedidoService.pagarPedido(
            pedidoCreado.id,
            formaPago: metodoPagoUsado,
            propina: 0.0,
            totalPagado: total,
            procesadoPor: userName,
            notas: esPedidoAsesor
                ? 'Pago de pedido asesor'
                : 'Pago desde facturación',
            descuento: totalDescuentos + totalRetenciones,
            pagoMultiple: metodoPagoUsado == 'multiple',
            medioPago: medioPagoUsado,
            montoEfectivo: montoEfectivo,
            montoTarjeta: montoTarjeta,
            montoTransferencia: montoTransferencia,
            montoSistecredito: montoSistecredito,
            montoDatafono: montoDatafono,
          );

          // 🔧 CRÍTICO: Asegurar que los datos del cliente estén guardados
          // Si el backend no devolvió los datosAdicionales, actualizamos el pedido
          if (datosAdicionales != null &&
              pedidoPagado.datosAdicionales == null) {
            try {
              appLog('⚠️ Actualizando pedido con datos del cliente...');
              pedidoPagado.datosAdicionales = datosAdicionales;
              await _pedidoService.updatePedido(pedidoPagado);
              appLog('✅ Datos del cliente guardados correctamente');
            } catch (e) {
              appLog('❌ Error al actualizar datos del cliente: $e');
            }
          }

          // Registrar movimientos de inventario
          _registrarMovimientosInventarioVentaEnBackground(
            pedidoPagado,
            itemsOriginales: itemsOriginales,
          );

          // Enviar directamente a DIAN para POS y Factura Electrónica
          if (tipoFacturaCapturado == 'POS' || tipoFacturaCapturado == 'FACTURA') {
            _emitirDocumentoEnDIAN(pedidoPagado, tipoFacturaCapturado);
          }

          // Si viene de pedido asesor, marcarlo como facturado
          if (pedidoAsesorId != null) {
            await _pedidoAsesorService.marcarComoFacturado(
              pedidoAsesorId,
              userName,
              facturaId: pedidoPagado.id,
            );
          }

          // Notificar traslados automáticamente: elimina/actualiza los que contengan
          // productos recién facturados (fire-and-forget, no bloquea el flujo)
          {
            final mongoIds = itemsOriginales
                .map((i) => _productoMongoIds[i.productoId] ?? i.productoId)
                .where((id) => id.isNotEmpty)
                .toList();
            _trasladoService.notificarProductosFacturados(mongoIds).catchError((_) {});
          }

          // Refrescar cache
          _refrescarCacheEnBackground();

          // Mostrar diálogo de factura exitosa con opciones de PDF/Imprimir
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();

            // Obtener info del negocio para el PDF
            NegocioInfo? negocioInfo;
            try {
              negocioInfo = await _negocioInfoService.getNegocioInfo();
            } catch (e) {
              // Ignorar error
            }

            // Buscar datos completos del cliente desde la API
            Cliente? clienteCompleto = clienteCapturado;
            if (clienteCompleto == null &&
                clienteTexto != 'CONSUMIDOR FINAL' &&
                clienteTexto.isNotEmpty) {
              try {
                final resultados = await _clienteService.buscarClientes(
                  clienteTexto,
                );
                if (resultados.isNotEmpty) clienteCompleto = resultados.first;
              } catch (e) {
                appLog('⚠️ Error buscando cliente para PDF: $e');
              }
            }

            // Preparar resumen con datos completos del cliente
            // ✅ itemsOverride: usa los items del formulario (con precios editados)
            //    porque el backend puede devolver items con precios del catálogo
            final resumen = _prepararResumenFactura(
              pedidoPagado,
              metodoPagoUsado,
              total,
              totalDescuentos + totalRetenciones,
              0.0,
              negocioInfo,
              clienteData: clienteCompleto,
              retencionPct: retencionPct,
              reteIVAPct: reteIVAPct,
              reteICAPct: reteICAPct,
              aiuPct: aiuPct,
              dctoGeneral: dctoGeneral,
              retencionValor: retencionValor,
              reteIVAValor: reteIVAValor,
              reteICAValor: reteICAValor,
              aiuValor: aiuValor,
              observaciones: observacionesCapturadas,
              itemsOverride: itemsOriginales,
            );

            // Agregar desglose de pagos mixtos si no vino del pedido
            if (metodoPagoUsado == 'multiple' &&
                resumen['pagosParciales'] == null) {
              final desglose = <Map<String, dynamic>>[];
              if (montoEfectivo > 0)
                desglose.add({'formaPago': 'Efectivo', 'monto': montoEfectivo});
              if (montoTarjeta > 0)
                desglose.add({'formaPago': 'Tarjeta', 'monto': montoTarjeta});
              if (montoTransferencia > 0)
                desglose.add({
                  'formaPago': 'Transferencia',
                  'monto': montoTransferencia,
                });
              if (montoSistecredito > 0)
                desglose.add({
                  'formaPago': 'Sistecredito',
                  'monto': montoSistecredito,
                });
              if (montoDatafono > 0)
                desglose.add({'formaPago': 'Datafono', 'monto': montoDatafono});
              if (desglose.isNotEmpty) resumen['pagosParciales'] = desglose;
            }

            // Mostrar diálogo con opciones de PDF/Imprimir
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: AppTheme.success,
                        size: 32,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Factura Pagada!',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            'Total: \$${total.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '¿Qué desea hacer con la factura?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              // NO cerrar el diálogo automáticamente
                              await _mostrarPDFConNombrePersonalizado(
                                resumen: resumen,
                                esFactura: true,
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.red,
                                    size: 28,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Ver PDF',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              // NO cerrar el diálogo automáticamente
                              await _pdfService.mostrarDialogoImpresion(
                                resumen: resumen,
                                esFactura: true,
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.print,
                                    color: AppTheme.primary,
                                    size: 28,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Imprimir',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Cerrar diálogo
                      // Si es pedido asesor, regresar a la pantalla anterior
                      if (esPedidoAsesor && mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      'Cerrar',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
          appLog('⚠️ Error en procesamiento background: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ ${errorMessage(e)}'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 8),
              ),
            );
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      showErrorSnackBar(context, errorMessage(e));
    }
  }

  /// Emite el documento directamente a DIAN en segundo plano tras el pago.
  /// POS → emitirDocumentoPOS  |  FACTURA → emitirFacturaElectronica
  void _emitirDocumentoEnDIAN(Pedido pedido, String tipoFactura) {
    final messenger = ScaffoldMessenger.of(context);
    final token = Provider.of<UserProvider>(context, listen: false).token;
    Future.microtask(() async {
      try {
        final esPOS = tipoFactura == 'POS';
        final nombreDoc = esPOS ? 'POS Electrónico' : 'Factura Electrónica';

        appLog('📋 [DIAN] Emitiendo $nombreDoc para pedido: ${pedido.id}');

        MatiasDocumentoResult resultado;

        if (esPOS) {
          final negocioInfo = await _negocioInfoService.getNegocioInfo();
          final posResolutionNumber = negocioInfo?.posResolutionNumber ?? '';
          if (posResolutionNumber.isEmpty) {
            throw Exception('Número de resolución POS no configurado en NegocioInfo (campo posResolucion)');
          }
          final posPayload = MatiasService.buildCompletePOSDocument(
            pedido: pedido,
            negocioInfo: negocioInfo,
            resolutionNumber: posResolutionNumber,
          );
          resultado = await MatiasService.emitirDocumentoPOS(posPayload, token: token);
        } else {
          resultado = await MatiasService.emitirFacturaElectronica(
            {
              'pedidoId': pedido.id,
              'customer': MatiasService.buildCustomerFromPedido(pedido),
            },
            token: token,
          );
        }

        appLog('📋 [DIAN] Resultado: success=${resultado.success}, message=${resultado.message}');

        if (!mounted) return;
        if (resultado.success) {
          final cufe = resultado.documentKey ?? '';
          final factResult = FacturacionResult(
            success: true,
            message: resultado.message,
            cufe: cufe.isNotEmpty ? cufe : null,
            pdfUrl: (resultado.pdfUrl?.isNotEmpty == true) ? resultado.pdfUrl : null,
            raw: resultado.raw,
          );
          showDialog(
            context: context,
            builder: (_) => ConfirmacionDianDialog(
              resultado: factResult,
              tipoDocumento: nombreDoc,
              onDescargarPDF: cufe.isNotEmpty
                  ? () => _descargarPDFDian(cufe)
                  : null,
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text('⚠️ Error DIAN ($nombreDoc): ${resultado.message}'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      } catch (e) {
        appLog('❌ [DIAN] Error al emitir documento: $e');
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('❌ Error al enviar a DIAN: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    });
  }

  Future<void> _descargarPDFDian(String cufe) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('Descargando PDF de DIAN...'),
      duration: Duration(seconds: 2),
    ));
    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;
      final url = await MatiasService.obtenerURLPDF(cufe, token: token);
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          messenger.showSnackBar(const SnackBar(
            content: Text('No se pudo abrir el PDF.'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }
      final res = await MatiasService.descargarPDF(cufe, token: token);
      if (!mounted) return;
      if (res == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('PDF no disponible. El documento debe estar ACEPTADO por la DIAN.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ));
        return;
      }
      final ok = await Base64FileLauncher.open(
        base64: res['base64']!,
        mimeType: res['mimeType']!,
      );
      if (!ok && mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('No se pudo abrir el PDF.'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Error al descargar PDF: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  // 📦 Registrar movimientos de inventario cuando se factura (venta)
  // itemsOriginales: Si se proveen, usa estos items en lugar de los del pedido (para preservar origen)
  Future<void> _registrarMovimientosInventarioVenta(
    Pedido pedido, {
    List<ItemPedido>? itemsOriginales,
  }) async {
    try {
      final productoService = ProductoService();
      
      // ✅ USAR items originales si se proveen (tienen el campo origen correcto)
      // El backend puede no guardar/devolver el campo origen, así que usamos los originales
      final itemsParaProcesar = itemsOriginales ?? pedido.items;
      
      appLog('📦 Procesando ${itemsParaProcesar.length} items para movimientos de inventario');

      // ⚡ OPTIMIZACIÓN: Procesar todos los productos en paralelo
      await Future.wait(
        itemsParaProcesar.map((item) async {
          try {
            // 🔍 Obtener el producto completo para actualizar stock
            final productoCompleto = await productoService.getProducto(
              item.productoId,
            );

            if (productoCompleto == null) return;

            // 📍 Determinar el origen de la venta (BODEGA o ALMACÉN)
            final origen = item.origen;
            // Si el item tiene trasladoId, el traslado ya movió el stock BODEGA→ALMACÉN.
            // En ese caso billing descuenta de ALMACÉN para no hacer doble descuento de BODEGA.
            final hayTraslado = item.trasladoId != null && item.trasladoId!.isNotEmpty;
            final origenEfectivo = hayTraslado ? 'ALMACÉN' : origen;
            appLog(
              '🏬 Procesando ${item.productoNombre}: origen="$origen" trasladoId=${item.trasladoId} → descuenta de "$origenEfectivo" (B:${productoCompleto.bodega}, A:${productoCompleto.almacen})',
            );

            // 📊 Obtener stock anterior según el origen efectivo
            double stockAnterior = 0;
            double nuevoStock = 0;

            // ✅ Obtener valores actuales de AMBAS ubicaciones
            double almacenActual = (productoCompleto.almacen ?? 0).toDouble();
            double bodegaActual = (productoCompleto.bodega ?? 0).toDouble();

            if (origenEfectivo.toUpperCase() == 'BODEGA') {
              stockAnterior = bodegaActual;
              nuevoStock = (stockAnterior - item.cantidad).clamp(
                0,
                double.infinity,
              );
              bodegaActual = nuevoStock;
            } else {
              stockAnterior = almacenActual;
              nuevoStock = (stockAnterior - item.cantidad).clamp(
                0,
                double.infinity,
              );
              almacenActual = nuevoStock;
            }

            // 📋 Crear movimiento de inventario
            final movimiento = MovimientoInventario(
              inventarioId: item.productoId,
              productoId: item.productoId,
              productoNombre: item.productoNombre ?? 'Producto',
              tipoMovimiento: 'Salida',
              motivo: 'Venta - Factura ${pedido.id} (${origen})',
              cantidadAnterior: stockAnterior,
              cantidadMovimiento: item.cantidad.toDouble(),
              cantidadNueva: nuevoStock,
              responsable: pedido.mesero ?? 'Sistema',
              referencia: 'FV-${pedido.id}',
              observaciones:
                  'Venta a ${pedido.cliente ?? 'CONSUMIDOR FINAL'} desde ${origen}',
              costoUnitario: item.precioUnitario,
              precioTotal: item.subtotal,
              fecha: DateTimeUtils.nowColombia(),
              facturaNo: pedido.id,
              proveedor: null,
            );

            // 📝 Intentar registrar movimiento (no bloqueante)
            _inventarioService.registrarMovimiento(movimiento).catchError((e) {
              appLog('⚠️ Error movimiento: $e');
            });

            // 🔄 ACTUALIZAR STOCK EN EL PRODUCTO
            final productoActualizado = productoCompleto.copyWith(
              almacen: almacenActual.toInt(),
              bodega: bodegaActual.toInt(),
            );

            appLog(
              '💾 Guardando ${item.productoNombre}: B:${bodegaActual.toInt()}, A:${almacenActual.toInt()}',
            );

            // 💾 Guardar producto actualizado (CRÍTICO)
            await _productoService.updateProducto(productoActualizado);
          } catch (e) {
            appLog('⚠️ Error item ${item.productoId}: $e');
          }
        }),
      );
    } catch (e) {
      appLog('⚠️ Error general movimientos: $e');
    }
  }

  // 🧹 Versión no-blocking que se ejecuta en background sin esperar
  void _registrarMovimientosInventarioVentaEnBackground(
    Pedido pedido, {
    List<ItemPedido>? itemsOriginales,
  }) {
    // Ejecutar en microtask para no bloquear la UI
    Future.microtask(() async {
      try {
        final productoService = ProductoService();
        final itemsParaProcesar = itemsOriginales ?? pedido.items;
        
        appLog('📦 [BG] Procesando ${itemsParaProcesar.length} items para inventario');

        // Procesar todos en paralelo sin bloquear
        await Future.wait(
          itemsParaProcesar.map((item) async {
            try {
              final productoCompleto = await productoService.getProducto(
                item.productoId,
              );

              if (productoCompleto == null) return;

              final origen = item.origen;
              double almacenActual = (productoCompleto.almacen ?? 0).toDouble();
              double bodegaActual = (productoCompleto.bodega ?? 0).toDouble();
              double stockAnterior = 0;
              double nuevoStock = 0;

              if (origen.toUpperCase() == 'BODEGA') {
                stockAnterior = bodegaActual;
                nuevoStock = (stockAnterior - item.cantidad).clamp(0, double.infinity);
                bodegaActual = nuevoStock;
              } else {
                stockAnterior = almacenActual;
                nuevoStock = (stockAnterior - item.cantidad).clamp(0, double.infinity);
                almacenActual = nuevoStock;
              }

              // Crear movimiento
              final movimiento = MovimientoInventario(
                inventarioId: item.productoId,
                productoId: item.productoId,
                productoNombre: item.productoNombre ?? 'Producto',
                tipoMovimiento: 'Salida',
                motivo: 'Venta - Factura ${pedido.id} (${origen})',
                cantidadAnterior: stockAnterior,
                cantidadMovimiento: item.cantidad.toDouble(),
                cantidadNueva: nuevoStock,
                responsable: pedido.mesero ?? 'Sistema',
                referencia: 'FV-${pedido.id}',
                observaciones: 'Venta a ${pedido.cliente ?? 'CONSUMIDOR FINAL'} desde ${origen}',
                costoUnitario: item.precioUnitario,
                precioTotal: item.subtotal,
                fecha: DateTimeUtils.nowColombia(),
                facturaNo: pedido.id,
                proveedor: null,
              );

              // Registrar movimiento (no bloquear)
              _inventarioService.registrarMovimiento(movimiento).catchError((e) {
                appLog('⚠️ [BG] Error mov: $e');
              });

              // Actualizar stock
              final productoActualizado = productoCompleto.copyWith(
                almacen: almacenActual.toInt(),
                bodega: bodegaActual.toInt(),
              );

              await _productoService.updateProducto(productoActualizado);
              appLog('✅ [BG] ${item.productoNombre} actualizado');
            } catch (e) {
              appLog('⚠️ [BG] Error item: $e');
            }
          }),
          eagerError: false, // No fallar si alguno falla
        );
        
        appLog('✅ [BG] Inventario actualizado completamente');
      } catch (e) {
        appLog('⚠️ [BG] Error general: $e');
      }
    });
  }

  // 🔄 Refrescar cache en segundo plano
  void _refrescarCacheEnBackground() {
    Future.microtask(() async {
      try {
        final cacheProvider = Provider.of<DatosCacheProvider>(
          context,
          listen: false,
        );
        await cacheProvider.forceRefreshProductos();
        if (mounted) await _cargarProductos();
      } catch (e) {
        // Ignorar errores no críticos
      }
    });
  }

  // Mostrar diálogo de factura exitosa con opciones de impresión
  Future<void> _mostrarDialogoFacturaExitosa(
    Pedido pedido,
    String medioPago,
    double totalPagado,
    double descuento,
    double propina,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle, color: AppTheme.success, size: 32),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Factura Pagada!',
                    style: AppTheme.headlineMedium.copyWith(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ID: ${pedido.id}',
                    style: AppTheme.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen del pago
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResumenItem('Cliente', pedido.cliente ?? 'CONSUMIDOR FINAL'),
                  _buildResumenItem('Forma de pago', _formatearFormaPago(medioPago)),
                  if (descuento > 0) _buildResumenItem('Descuento', '-\$${descuento.toStringAsFixed(0)}'),
                  if (propina > 0) _buildResumenItem('Propina', '+\$${propina.toStringAsFixed(0)}'),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL PAGADO',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '\$${totalPagado.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              '¿Qué desea hacer con la factura?',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
            ),
            SizedBox(height: 12),
            // Opciones de impresión
            Row(
              children: [
                Expanded(
                  child: _buildOpcionFactura(
                    icon: Icons.picture_as_pdf,
                    label: 'Ver PDF',
                    color: Colors.red,
                    onTap: () {
                      Navigator.of(context).pop();
                      _generarYMostrarPDF(pedido, medioPago, totalPagado, descuento, propina);
                    },
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildOpcionFactura(
                    icon: Icons.print,
                    label: 'Imprimir',
                    color: AppTheme.primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      _imprimirFactura(pedido, medioPago, totalPagado, descuento, propina);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Cerrar sin imprimir',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String label, String valor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
          ),
          Text(
            valor,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOpcionFactura({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  String _formatearFormaPago(String formaPago) {
    switch (formaPago.toLowerCase()) {
      case 'efectivo': return 'Efectivo';
      case 'tarjeta': return 'Tarjeta';
      case 'transferencia': return 'Transferencia';
      case 'sistecredito': return 'Sistecredito';
      case 'datafono': return 'Datafono';
      case 'mixto': return 'Pago Mixto';
      case 'multiple': return 'Pago Múltiple';
      default: return formaPago;
    }
  }

  // Generar y mostrar PDF de la factura
  Future<void> _generarYMostrarPDF(
    Pedido pedido,
    String medioPago,
    double totalPagado,
    double descuento,
    double propina,
  ) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(width: 16),
              Text('Generando PDF...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
        ),
      );

      // Obtener información del negocio
      NegocioInfo? negocioInfo;
      try {
        negocioInfo = await _negocioInfoService.getNegocioInfo();
      } catch (e) {
          
      }

      // Preparar el resumen para el PDF
      final resumen = _prepararResumenFactura(
        pedido,
        medioPago,
        totalPagado,
        descuento,
        propina,
        negocioInfo,
        retencionPct: pedido.retencion,
        reteIVAPct: pedido.reteIVA,
        reteICAPct: pedido.reteICA,
        aiuPct: pedido.aiu != null
            ? (pedido.aiu!['porcentaje'] as num?)?.toDouble()
            : null,
        dctoGeneral: pedido.descuentoGeneral,
        retencionValor: pedido.valorRetencion,
        reteIVAValor: pedido.valorReteIVA,
        reteICAValor: pedido.valorReteICA,
        aiuValor: pedido.aiu != null
            ? (pedido.aiu!['valor'] as num?)?.toDouble()
            : null,
        observaciones: pedido.notas,
      );

      Navigator.of(context).pop(); // Cerrar indicador de carga

      // Mostrar el PDF con nombre personalizable
      await _mostrarPDFConNombrePersonalizado(
        resumen: resumen,
        esFactura: true,
      );

      showSuccessSnackBar(context, 'PDF generado correctamente');
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar indicador si está abierto
      showErrorSnackBar(context, 'Error generando PDF: $e');
    }
  }

  // Imprimir factura
  Future<void> _imprimirFactura(
    Pedido pedido,
    String medioPago,
    double totalPagado,
    double descuento,
    double propina,
  ) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(width: 16),
              Text('Preparando impresión...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
        ),
      );

      // Obtener información del negocio
      NegocioInfo? negocioInfo;
      try {
        negocioInfo = await _negocioInfoService.getNegocioInfo();
      } catch (e) {
          
      }

      // Preparar el resumen para el PDF
      final resumen = _prepararResumenFactura(
        pedido,
        medioPago,
        totalPagado,
        descuento,
        propina,
        negocioInfo,
        retencionPct: pedido.retencion,
        reteIVAPct: pedido.reteIVA,
        reteICAPct: pedido.reteICA,
        aiuPct: pedido.aiu != null
            ? (pedido.aiu!['porcentaje'] as num?)?.toDouble()
            : null,
        dctoGeneral: pedido.descuentoGeneral,
        retencionValor: pedido.valorRetencion,
        reteIVAValor: pedido.valorReteIVA,
        reteICAValor: pedido.valorReteICA,
        aiuValor: pedido.aiu != null
            ? (pedido.aiu!['valor'] as num?)?.toDouble()
            : null,
        observaciones: pedido.notas,
      );

      Navigator.of(context).pop(); // Cerrar indicador de carga

      // Mostrar diálogo de impresión
      await _pdfService.mostrarDialogoImpresion(resumen: resumen, esFactura: true);

      showSuccessSnackBar(context, 'Factura enviada a impresión');
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar indicador si está abierto
      showErrorSnackBar(context, 'Error al imprimir: $e');
    }
  }

  // Preparar resumen de factura para PDF/impresión
  Map<String, dynamic> _prepararResumenFactura(
    Pedido pedido,
    String medioPago,
    double totalPagado,
    double descuento,
    double propina,
    NegocioInfo? negocioInfo, {
    Cliente? clienteData,
    double? retencionPct,
    double? reteIVAPct,
    double? reteICAPct,
    double? aiuPct,
    double? dctoGeneral,
    double? retencionValor,
    double? reteIVAValor,
    double? reteICAValor,
    double? aiuValor,
    String? observaciones,
    List<ItemPedido>?
    itemsOverride, // ✅ Override para usar precios del formulario (no del backend)
  }) {
    // Usar clienteData pasado como parámetro, o _clienteSeleccionado como fallback
    final cliente = clienteData ?? _clienteSeleccionado;
    final now = DateTimeUtils.nowColombia();
    final fechaFormateada = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final horaFormateada = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    // ✅ Usar valores pasados como parámetros (ya capturados antes de limpiar el formulario)
    final retencionPctFinal = retencionPct ?? 0;
    final reteIVAPctFinal = reteIVAPct ?? 0;
    final reteICAPctFinal = reteICAPct ?? 0;
    final aiuPctFinal = aiuPct ?? 0;
    final dctoGeneralFinal = dctoGeneral ?? 0;

    // ✅ Recalcular subtotal/IVA desde los items reales que se van a mostrar,
    // en vez de confiar en pedido.subtotal/pedido.totalImpuestos (pueden quedar
    // desactualizados respecto a los items si estos se editaron después).
    final itemsParaResumen = itemsOverride ?? pedido.items;
    final subtotalCalculado = itemsParaResumen.fold<double>(
      0.0,
      (sum, item) => sum + item.subtotal - item.valorDescuento,
    );
    final totalIvaCalculado = itemsParaResumen.fold<double>(
      0.0,
      (sum, item) => sum + item.valorImpuesto,
    );

    final subtotalBase = subtotalCalculado;
    final retencionValorFinal =
        retencionValor ?? (subtotalBase * (retencionPctFinal / 100));
    final reteIVAValorFinal =
        reteIVAValor ?? (subtotalBase * (reteIVAPctFinal / 100));
    final reteICAValorFinal =
        reteICAValor ?? (subtotalBase * (reteICAPctFinal / 100));
    final aiuValorFinal = aiuValor ?? (subtotalBase * (aiuPctFinal / 100));

    return {
      // Información del negocio
      'nombreRestaurante': negocioInfo?.nombre ?? 'VERCY MOTOS',
      'nombreNegocio': negocioInfo?.nombre ?? 'VERCY MOTOS',
      'nit': negocioInfo?.nitDoc ?? negocioInfo?.nit ?? '',
      'direccionRestaurante': negocioInfo?.direccion ?? '',
      'telefonoRestaurante': negocioInfo?.contacto ?? negocioInfo?.telefono ?? '',
      'email': negocioInfo?.email ?? '',
      'ciudad': negocioInfo?.ciudad ?? '',
      'departamento': negocioInfo?.departamento ?? '',

      // Información de la factura
      'pedidoId': pedido.id,
      'numero': pedido.numeroFactura ?? pedido.id,
      'numeroPedido': pedido.numeroFactura ?? pedido.id,
      'tipoDocumento': 'ORDEN DE VENTA',
      'fecha': fechaFormateada,
      'hora': horaFormateada,
      'fechaVencimiento': pedido.fechaVencimiento != null
          ? '${pedido.fechaVencimiento!.year}-${pedido.fechaVencimiento!.month.toString().padLeft(2, '0')}-${pedido.fechaVencimiento!.day.toString().padLeft(2, '0')}'
          : fechaFormateada,

      // Información del cliente
      'cliente': cliente != null
          ? cliente.nombreCompleto
          : (pedido.cliente ?? 'CONSUMIDOR FINAL'),
      'clienteNit': cliente != null
          ? '${cliente.tipoIdentificacion} ${cliente.numeroIdentificacion}${cliente.digitoVerificacion != null ? "-${cliente.digitoVerificacion}" : ""}'
          : '222222222-2',
      'clienteDireccion': cliente?.direccion ?? '',
      'clienteTelefono': cliente?.telefono ?? '',
      'clienteCorreo': cliente?.correo ?? '',
      'clienteDepartamento': cliente?.departamento ?? '',
      'clienteCiudad': cliente?.ciudad ?? '',
      'clienteTipoId': cliente?.tipoIdentificacion ?? 'CC',

      // Información del vendedor
      'mesero': pedido.mesero ?? 'Sistema',
      'vendedor': pedido.mesero ?? 'Sistema',

      // Productos — usar itemsOverride si se provee (preserva precios editados en facturación)
      'productos': itemsParaResumen
          .map(
            (item) => {
        'codigo': item.productoId,
        'nombre': item.productoNombre,
        'producto': item.productoNombre,
        'cantidad': item.cantidad,
        'precio': item.precioUnitario,
        'precioUnitario': item.precioUnitario,
        'subtotal': item.subtotal,
              'iva': item.porcentajeImpuesto,
              'valorIva': item.valorImpuesto,
              'descuento': item.porcentajeDescuento,
              'valorDescuento': item.valorDescuento,
      }).toList(),

      // Totales
      'subtotal': subtotalCalculado,
      'totalSinIva': subtotalCalculado,
      'totalIva': totalIvaCalculado,
      'impuestos': totalIvaCalculado,
      'descuento': descuento,
      'descuentoGeneral': dctoGeneralFinal,
      'propina': propina,
      'total': totalPagado,
      'totalFactura': totalPagado,
      
      // Retenciones y AIU (para mostrar en el PDF)
      'retencion': retencionValorFinal,
      'retencionPct': retencionPctFinal,
      'reteIVA': reteIVAValorFinal,
      'reteIVAPct': reteIVAPctFinal,
      'reteICA': reteICAValorFinal,
      'reteICAPct': reteICAPctFinal,
      'aiu': aiuValorFinal,
      'aiuPct': aiuPctFinal,

      // Observaciones personalizadas (usar parámetro pasado o valor por defecto)
      'observaciones': observaciones?.isNotEmpty == true
          ? observaciones
          : 'Este documento se asimila en todos sus efectos legales a una letra de cambio (Artículo 774 del Código de Comercio)',

      // Forma de pago
      'medioPago': medioPago,
      'formaPago': _formatearFormaPago(medioPago),

      // Desglose de pagos (para pago mixto)
      'pagosParciales': pedido.pagosParciales.isNotEmpty
          ? pedido.pagosParciales
                .map(
                  (p) => {
                    'formaPago': _formatearFormaPago(p.formaPago),
                    'monto': p.monto,
                  },
                )
                .toList()
          : null,

      // Cantidades
      'cantidadArticulos': (itemsOverride ?? pedido.items).length,
      'cantidadProductos': (itemsOverride ?? pedido.items).length,

      // Tipo
      'tipoContado': 'CONTADO',
    };
  }

  // Limpiar formulario después de guardar
  void _limpiarFormulario() {
    _productoMongoIds.clear();
    setState(() {
      // Limpiar items y cliente
      _items.clear();
      _clienteController.text = 'CONSUMIDOR FINAL';
      
      // Limpiar fechas
      _fechaFactura = DateTime.now();
      _fechaVencimiento = DateTime.now().add(Duration(days: 30));
      
      // Limpiar método de pago Y TODOS LOS MONTOS MÚLTIPLES
      _metodoPago = 'efectivo';
      _montoEfectivoController.text = '0';
      _montoTransferenciaController.text = '0';
      _montoTarjetaController.text = '0';
      _montoSistereditoController.text = '0';
      _montoDatafonoController.text = '0';
      
      // Limpiar datos extras
      _ordenCompraController.clear();
      _ordenServicioController.clear();
      _ordenPedidoController.clear();
      _vendedorController.clear();
      _porcentajeDctoPagoController.clear();
      _guiaController.clear();

      // Limpiar retenciones y AIU
      _retencionController.text = '0';
      _reteIVAController.text = '0';
      _reteICAController.text = '0';
      _aiuController.text = '0';
      _dctoGeneralController.text = '0';
      
      // Limpiar observaciones
      _observacionesController.clear();

      // Resetear variables de estado
      _fechaCompra = null;
      _fechaDctoPago = null;
      _listaPrecios = 'Detal';
      _tipoFactura = 'LOCAL';
      _datosProductoExpanded = true;
      _datosExtrasExpanded = false;
      _retencionesExpanded = false;

      // Limpiar producto seleccionado
      _productoSeleccionado = null;
      _clienteSeleccionado = null;

      // Limpiar todos los campos de producto
      _codigoBarrasController.clear();
      _codigoController.clear();
      _nombreProductoController.clear();
      
      _cantidadController.text = '1';
      _valorUnitController.clear();
      _porcentajeImpuestoController.text = '19';
      _porcentajeDescuentoController.text = '0';
      _origenSeleccionado = 'ALMACÉN'; // 📦 Resetear a ALMACÉN por defecto
      
      // ✅ ASEGURAR QUE CLIENTE VUELVA A CONSUMIDOR FINAL
      _clienteController.text = 'CONSUMIDOR FINAL';
      
      // ✅ Incrementar key para forzar reconstrucción de Autocompletes
      _autocompleteResetKey++;
    });
    
    // 🗑️ Limpiar borrador del provider
    try {
      final draftProvider = Provider.of<FacturacionDraftProvider>(
        context,
        listen: false,
      );
      draftProvider.clearDraft();
      appLog('🗑️ Borrador limpiado del provider');
    } catch (e) {
      appLog('⚠️ Error limpiando provider: $e');
    }
  }

  Future<void> _guardarFactura() async {
    // Este método ahora solo se usa para compatibilidad
    // La lógica principal está en _guardarYPagar y _guardarComoBorrador
    await _guardarYPagar();
  }

  // Método para mostrar diálogo de edición de nombre de archivo PDF
  Future<void> _mostrarPDFConNombrePersonalizado({
    required Map<String, dynamic> resumen,
    bool esFactura = true,
  }) async {
    final nombreSugerido =
        'Factura_${resumen['pedidoId'] ?? resumen['numero'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';
    final controladorNombre = TextEditingController(text: nombreSugerido);

    final nombreFinal = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Nombre del archivo',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Personaliza el nombre del archivo PDF:',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
            ),
            SizedBox(height: 12),
            TextField(
              controller: controladorNombre,
              autofocus: true,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Nombre del archivo',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixText: '.pdf',
                suffixStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              var nombre = controladorNombre.text.trim();
              if (nombre.isEmpty) {
                nombre = nombreSugerido;
              }
              if (!nombre.endsWith('.pdf')) {
                nombre = '$nombre.pdf';
              }
              Navigator.of(context).pop(nombre);
            },
            icon: Icon(Icons.download, color: Colors.white),
            label: Text('Guardar', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          ),
        ],
      ),
    );

    if (nombreFinal != null) {
      await _pdfService.mostrarVistaPrevia(
        resumen: resumen,
        esFactura: esFactura,
        nombreArchivo: nombreFinal,
      );
    }
  }
}
