import 'dart:convert';
import '../utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pedido.dart';
import '../models/item_pedido.dart';
import '../models/producto.dart';
import '../models/pedido_asesor.dart';
import '../models/cotizacion.dart';
import '../services/pedido_service.dart';
import '../services/producto_service.dart';
import '../services/pedido_asesor_service.dart';
import '../services/cotizacion_service.dart';
import '../services/pdf_service.dart';
import '../services/negocio_info_service.dart';
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
import '../widgets/facturacion/dialogo_editar_iva_descuento.dart';
import '../widgets/facturacion/metodo_pago_section.dart';
import '../widgets/facturacion/facturacion_header_section.dart';
import '../widgets/facturacion/form_field_label.dart';
import '../widgets/facturacion/fecha_picker_field.dart';
import '../widgets/facturacion/tipo_factura_dropdown.dart';

import '../utils/busqueda_productos_utils.dart';
import '../utils/datetime_utils.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/dialogs_helper.dart';
import '../utils/api_error.dart' show errorMessage;
import '../widgets/facturizacion/confirmacion_dian_dialog.dart';
import '../services/documento_service.dart';
import '../utils/base64_file_launcher.dart';
import '../utils/currency_utils.dart';
import '../utils/payment_mapping.dart' as payment_mapping;
import '../utils/facturacion_calculos.dart' as calculos;
import 'package:url_launcher/url_launcher.dart';

// Cache de clientes compartido entre instancias de FacturacionScreen
List<Cliente> _clientesCached = [];
DateTime? _clientesCacheTime;
const _clientesCacheTTL = Duration(minutes: 5);

class FacturacionScreen extends StatefulWidget {
  final PedidoAsesor? pedidoAsesor;
  // Si viene de un traslado, su ID para eliminarlo tras el pago
  final String? trasladoId;
  // Si viene de convertir una cotización a factura
  final Cotizacion? cotizacion;
  // 'LOCAL' o 'ENVIOS' — a qué caja se asignan los pedidos creados en esta
  // pantalla. No confundir con _tipoFactura (tipo de factura DIAN: POS/
  // Electrónica), que es un campo completamente distinto y coincide en usar
  // el string 'LOCAL' como uno de sus valores.
  final String tipoCaja;

  const FacturacionScreen({
    super.key,
    this.pedidoAsesor,
    this.trasladoId,
    this.cotizacion,
    this.tipoCaja = 'LOCAL',
  });

  @override
  _FacturacionScreenState createState() => _FacturacionScreenState();
}

class _FacturacionScreenState extends State<FacturacionScreen> {
  FacturacionDraftProvider? _draftProvider; // cacheado para dispose() seguro
  // Borradores guardados solo en este dispositivo por un fallo al guardar y
  // pagar (ej. caja cerrada) — ver _guardarBorradorLocalPorFallo.
  int _borradoresLocalesCount = 0;
  final PedidoService _pedidoService = PedidoService();
  final ProductoService _productoService = ProductoService();
  final PedidoAsesorService _pedidoAsesorService = PedidoAsesorService();
  final CotizacionService _cotizacionService = CotizacionService();
  final TrasladoService _trasladoService = TrasladoService();
  final PDFService _pdfService = PDFService();
  final NegocioInfoService _negocioInfoService = NegocioInfoService();
  final ClienteService _clienteService = ClienteService();

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
  // Sub-categoría visual del medio de pago para el libro contable (nequi/daviplata/
  // bancolombia/bold/credilondon/...). No cambia el formaPago contable enviado al
  // backend, solo permite agrupar/filtrar ventas por plataforma específica.
  String? _detallePago = 'efectivo';
  final List<Map<String, dynamic>> _metodosPago = [
    {'value': 'efectivo', 'label': 'Efectivo', 'icon': Icons.attach_money},
    {
      'value': 'transferencia',
      'label': 'Transferencia',
      'icon': Icons.account_balance,
    },
    {'value': 'nequi', 'label': 'Nequi', 'icon': Icons.account_balance},
    {'value': 'daviplata', 'label': 'DaviPlata', 'icon': Icons.account_balance},
    {'value': 'bancolombia', 'label': 'Bancolombia', 'icon': Icons.account_balance},
    {'value': 'tarjeta', 'label': 'Tarjeta débito', 'icon': Icons.credit_card},
    {'value': 'tarjeta_credito', 'label': 'Tarjeta crédito', 'icon': Icons.credit_score},
    {'value': 'bold', 'label': 'Bold', 'icon': Icons.point_of_sale},
    {'value': 'addi', 'label': 'Addi', 'icon': Icons.shopping_bag_outlined},
    {'value': 'credilondon', 'label': 'Credilondon', 'icon': Icons.shopping_bag_outlined},
    {'value': 'sistecredito', 'label': 'Sistecredito', 'icon': Icons.card_giftcard},
    {'value': 'credito', 'label': 'A Crédito', 'icon': Icons.account_balance_wallet},
    {'value': 'multiple', 'label': 'Múltiple', 'icon': Icons.payments},
  ];

  // Mapeo de forma de pago: ver lib/utils/payment_mapping.dart (compartido
  // con matias_service.dart para que ambos caminos hacia Matías — Factura
  // vía backend y Documento POS vía frontend — coincidan).
  String _mapFormaPagoBackend(String metodo) =>
      payment_mapping.mapFormaPagoBackend(metodo);

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
  final TextEditingController _montoBoldController = TextEditingController(
    text: '0',
  );
  final TextEditingController _montoAddiController = TextEditingController(
    text: '0',
  );
  final TextEditingController _montoCredilondonController =
      TextEditingController(text: '0');
  // Sub-líneas de "Transferencia" en pago múltiple: cada plataforma tiene su
  // propio monto para poder combinarlas entre sí (ej. parte por Nequi, parte
  // por Bancolombia, en la misma venta). Todas resuelven a formaPago='transferencia'.
  final TextEditingController _montoNequiController = TextEditingController(
    text: '0',
  );
  final TextEditingController _montoDaviplataController = TextEditingController(
    text: '0',
  );
  final TextEditingController _montoBancolombiaController = TextEditingController(
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

  DatosCacheProvider? _cacheProvider;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _actualizarContadorBorradoresLocales();

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
    
    // Si se pasó un pedido de asesor o una cotización, cargar clientes primero
    if (widget.pedidoAsesor != null) {
      _inicializarConPedidoAsesor();
    } else if (widget.cotizacion != null) {
      _inicializarConCotizacion();
    } else {
      _cargarClientes().then((_) {
        // Asignar cliente por defecto si no hay ninguno seleccionado
        _asignarClientePorDefecto();
      });
      // 📝 Restaurar borrador existente (si no es pedido asesor)
      Future.microtask(() => _restaurarBorrador());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sin esto, un producto creado/editado en otro dispositivo mientras esta
    // pantalla está abierta nunca se reflejaba: _cargarProductos() solo lee
    // el caché una vez al entrar (el BroadcastChannel de arriba solo cubre
    // otra pestaña del mismo navegador, no otro dispositivo).
    final newProvider = Provider.of<DatosCacheProvider>(context, listen: false);
    if (_cacheProvider != newProvider) {
      _cacheProvider?.removeListener(_onCacheActualizado);
      _cacheProvider = newProvider;
      _cacheProvider!.addListener(_onCacheActualizado);
    }
  }

  void _onCacheActualizado() {
    if (!mounted) return;
    final productosCache = _cacheProvider?.productos;
    if (productosCache != null && productosCache.isNotEmpty) {
      setState(() => _productosDisponibles = List.from(productosCache));
    }
  }

  /// 🔥 Pre-calentar el backend: hacer un GET liviano para despertar Render
  /// y pre-cachear el cuadreId activo para que createPedido no tenga que esperar
  Future<void> _preCalentarBackend() async {
    try {
      // Esto pre-cachea el cuadreId en PedidoService (evita llamada extra al crear pedido)
      _pedidoService.preCachearCuadreId(tipoCaja: widget.tipoCaja);
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

    // Precargar las observaciones que el asesor dejó al crear el pedido, para
    // que caja las vea sin tener que volver a preguntarle al cliente/asesor.
    if (pedido.observaciones != null && pedido.observaciones!.isNotEmpty) {
      _observacionesController.text = pedido.observaciones!;
    }

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

  // Inicializar con cotización - cargar clientes primero
  Future<void> _inicializarConCotizacion() async {
    await _cargarClientes(); // Esperar a que se carguen los clientes
    if (mounted) {
      await _precargarDatosCotizacion(); // Luego precargar datos de la cotización
      // Asignar cliente por defecto si después de precargar no hay cliente válido
      Future.delayed(Duration(milliseconds: 100), () {
        _asignarClientePorDefecto();
      });
    }
  }

  Future<void> _precargarDatosCotizacion() async {
    final cotizacion = widget.cotizacion!;

    // Precargar nombre del cliente
    _clienteController.text = cotizacion.clienteNombre ?? '';

    Cliente? clienteEncontrado = _clientesDisponibles
        .cast<Cliente?>()
        .firstWhere((cliente) => cliente?.id == cotizacion.clienteId, orElse: () => null);

    // Si el cliente no está en la lista precargada (ej. lista paginada/limitada),
    // buscarlo directamente por ID para no perder la cédula/NIT real del cliente.
    if (clienteEncontrado == null) {
      appLog('⚠️ Cliente ${cotizacion.clienteId} no está en la lista precargada, buscando por ID...');
      try {
        clienteEncontrado = await _clienteService.obtenerClientePorId(cotizacion.clienteId);
      } catch (e) {
        appLog('⚠️ Error obteniendo cliente por ID: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      if (clienteEncontrado != null) {
        _clienteSeleccionado = clienteEncontrado;
        appLog('✅ Cliente seleccionado: ${_clienteSeleccionado?.nombreCompleto}');
      } else {
        appLog('⚠️ No se pudo encontrar el cliente - clienteId: ${cotizacion.clienteId}');
      }

      // Los items de la cotización ya guardan precio neto + IVA/descuento por
      // separado (a diferencia del pedido de asesor, que guarda el precio con
      // IVA incluido), así que se cargan directamente sin necesidad de recalcular.
      _items = cotizacion.items.map((item) {
        return ItemPedido(
          productoId: item.productoId,
          productoNombre: item.productoNombre,
          cantidad: item.cantidad,
          precioUnitario: item.precioUnitario,
          porcentajeImpuesto: item.porcentajeImpuesto,
          valorImpuesto: item.valorImpuesto,
          porcentajeDescuento: item.porcentajeDescuento,
          valorDescuento: item.valorDescuento,
        );
      }).toList();
    });

    showSuccessSnackBar(context, 'Cotización ${cotizacion.numeroCotizacion ?? ''} cargada correctamente');
  }

  Future<void> _mostrarDialogoEditarItemsPedidoAsesor(PedidoAsesor pedido) async {
    if (!mounted) return;

    final resultado = await mostrarDialogoEditarIvaDescuento(
      context: context,
      titulo: 'Pedido de ${pedido.asesorNombre}',
      items: pedido.items,
      columnaPrecioLabel: 'Precio c/IVA',
    );
    final ivaValues = resultado.ivaValues;
    final dctoValues = resultado.dctoValues;

    if (!mounted) return;

    final List<ItemPedido> itemsCargados;
    if (resultado.confirmado) {
      // Aplicar IVA y descuento editados.
      // precioUnitario del asesor es siempre el precio FINAL con IVA incluido;
      // se extrae la base neta dividiendo por (1 + iva/100).
      itemsCargados = pedido.items.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final ivaPct = ivaValues[idx];
        final dctoPct = dctoValues[idx];
        final precioBase = calculos.extraerPrecioBaseDeGravado(item.precioUnitario, ivaPct);
        final calculo = calculos.calcularItemFactura(
          cantidad: item.cantidad.toDouble(),
          precioUnitario: precioBase,
          porcentajeImpuesto: ivaPct,
          descuentoIngresado: dctoPct,
        );
        return ItemPedido(
          productoId: item.productoId,
          productoNombre: item.productoNombre,
          cantidad: item.cantidad,
          precioUnitario: precioBase,
          porcentajeImpuesto: ivaPct,
          valorImpuesto: calculo.valorImpuesto,
          porcentajeDescuento: dctoPct,
          valorDescuento: calculo.valorDescuento,
          origen: item.origen,
          trasladoId: item.trasladoId,
        );
      }).toList();
    } else {
      // Sin cambios: extraer precio base neto del precio asesor (IVA incluido)
      itemsCargados = pedido.items.map((item) {
        final ivaPct = item.porcentajeImpuesto;
        final precioBase = calculos.extraerPrecioBaseDeGravado(item.precioUnitario, ivaPct);
        final calculo = calculos.calcularItemFactura(
          cantidad: item.cantidad.toDouble(),
          precioUnitario: precioBase,
          porcentajeImpuesto: ivaPct,
          descuentoIngresado: item.porcentajeDescuento,
        );
        return ItemPedido(
          productoId: item.productoId,
          productoNombre: item.productoNombre,
          cantidad: item.cantidad,
          precioUnitario: precioBase,
          porcentajeImpuesto: ivaPct,
          valorImpuesto: calculo.valorImpuesto,
          porcentajeDescuento: item.porcentajeDescuento,
          valorDescuento: calculo.valorDescuento,
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
      // Si no hay productos en cache, cargarlos vía el provider (queda
      // cacheado ahí para el resto de la app).
      appLog('⚠️ No hay productos en cache, cargando desde API...');
      try {
        final productos = await cacheProvider.obtenerProductos();
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
    _montoBoldController.dispose();
    _montoAddiController.dispose();
    _montoCredilondonController.dispose();
    _montoNequiController.dispose();
    _montoDaviplataController.dispose();
    _montoBancolombiaController.dispose();
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
    _cacheProvider?.removeListener(_onCacheActualizado);

    super.dispose();
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
        _montoBoldController.text = montos['bold']?.toString() ?? '0';
        _montoAddiController.text = montos['addi']?.toString() ?? '0';
        _montoCredilondonController.text =
            montos['credilondon']?.toString() ?? '0';
        _montoNequiController.text = montos['nequi']?.toString() ?? '0';
        _montoDaviplataController.text = montos['daviplata']?.toString() ?? '0';
        _montoBancolombiaController.text =
            montos['bancolombia']?.toString() ?? '0';

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
        'bold': double.tryParse(_montoBoldController.text) ?? 0,
        'addi': double.tryParse(_montoAddiController.text) ?? 0,
        'credilondon': double.tryParse(_montoCredilondonController.text) ?? 0,
        'nequi': double.tryParse(_montoNequiController.text) ?? 0,
        'daviplata': double.tryParse(_montoDaviplataController.text) ?? 0,
        'bancolombia': double.tryParse(_montoBancolombiaController.text) ?? 0,
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
                FacturacionHeaderSection(
                  onMostrarBorradores: _mostrarBorradores,
                  onVerBorradoresLocales: _verBorradoresLocalesFallidos,
                  borradoresLocalesCount: _borradoresLocalesCount,
                ),
                if (widget.tipoCaja == 'ENVIOS')
                  Container(
                    width: double.infinity,
                    color: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_shipping, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'FACTURACIÓN ENVÍOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        MetodoPagoSection(
                          metodoPago: _metodoPago,
                          metodosPago: _metodosPago,
                          onMetodoPagoChanged: (value) {
                            setState(() {
                              _metodoPago = value;
                              _detallePago = payment_mapping.detalleParaMetodo(value);
                            });
                            _guardarEstadoCompleto();
                          },
                          onMontoChanged: () => setState(() {}),
                          montoEfectivoController: _montoEfectivoController,
                          montoTransferenciaController: _montoTransferenciaController,
                          montoNequiController: _montoNequiController,
                          montoDaviplataController: _montoDaviplataController,
                          montoBancolombiaController: _montoBancolombiaController,
                          montoTarjetaController: _montoTarjetaController,
                          montoSistereditoController: _montoSistereditoController,
                          montoBoldController: _montoBoldController,
                          montoAddiController: _montoAddiController,
                          montoCredilondonController: _montoCredilondonController,
                        ),
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
                          onVistaPrevia: _mostrarVistaPreviaFactura,
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
                FormFieldLabel(
                  label: 'Tipo',
                  field: TipoFacturaDropdown(
                    tipoFactura: _tipoFactura,
                    onChanged: (value) => setState(() => _tipoFactura = value),
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FormFieldLabel(
                        label: 'F. Factura',
                        field: FechaPickerField(
                          fecha: _fechaFactura,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          onFechaSeleccionada: (fecha) => setState(() => _fechaFactura = fecha),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: FormFieldLabel(
                        label: 'F. Vencimiento',
                        field: FechaPickerField(
                          fecha: _fechaVencimiento,
                          firstDate: _fechaFactura,
                          lastDate: DateTime(2030),
                          onFechaSeleccionada: (fecha) => setState(() => _fechaVencimiento = fecha),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                FormFieldLabel(label: 'Cliente', field: _buildClienteField()),
              ] else ...[
                // Diseño desktop - original
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FormFieldLabel(
                  label: 'Tipo',
                  field: TipoFacturaDropdown(
                    tipoFactura: _tipoFactura,
                    onChanged: (value) => setState(() => _tipoFactura = value),
                  ),
                ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FormFieldLabel(
                        label: 'F. Factura',
                        field: FechaPickerField(
                          fecha: _fechaFactura,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          onFechaSeleccionada: (fecha) => setState(() => _fechaFactura = fecha),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FormFieldLabel(
                        label: 'F. Vencimiento',
                        field: FechaPickerField(
                          fecha: _fechaVencimiento,
                          firstDate: _fechaFactura,
                          lastDate: DateTime(2030),
                          onFechaSeleccionada: (fecha) => setState(() => _fechaVencimiento = fecha),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                FormFieldLabel(label: 'Cliente', field: _buildClienteField()),
              ],
            ],
          ),
        );
      },
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
                  // 📱 código/nombre/cantidad/valor unit/valor total eran 5
                  // Expanded en una sola Row (flex 1:3:1:1:1) — en mobile
                  // cada uno recibía tan poco ancho que ni el hint cabía
                  // ("C...", "$", "$"), sin forma de distinguirlos. Se
                  // extraen a variables para reordenarlos: en mobile,
                  // "Producto" a todo el ancho y el resto en parejas; en
                  // desktop, la misma fila de siempre.
                  Builder(builder: (context) {
                      final campoCodigo = Expanded(
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
                              _valorUnitController.text = CurrencyUtils.formatForMilesInput(precioBase);
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
                      );

                      final campoNombre = Expanded(
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
                              _valorUnitController.text = CurrencyUtils.formatForMilesInput(precioBase);
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
                                                    CurrencyUtils.format(option.precio),
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
                      );

                      final campoCantidad = Expanded(
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
                      );

                      final campoValorUnit = Expanded(
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
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [MilesInputFormatter(decimalDigits: 2)],
                        ),
                      );

                      final campoValorTotal = Expanded(
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
                      );

                      return context.isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [campoNombre]),
                                SizedBox(height: 12),
                                Row(children: [campoCodigo, SizedBox(width: 12), campoCantidad]),
                                SizedBox(height: 12),
                                Row(children: [campoValorUnit, SizedBox(width: 12), campoValorTotal]),
                              ],
                            )
                          : Row(
                              children: [
                                campoCodigo,
                                SizedBox(width: 12),
                                campoNombre,
                                SizedBox(width: 12),
                                campoCantidad,
                                SizedBox(width: 12),
                                campoValorUnit,
                                SizedBox(width: 12),
                                campoValorTotal,
                              ],
                            );
                    }),
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
                                    showErrorDialog(context, 'Error al refrescar stock: ${errorMessage(e)}');
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Producto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
                      child: SelectableText(
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
                        CurrencyUtils.format(item.precioUnitario),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        item.valorImpuesto > 0
                            ? CurrencyUtils.format(item.valorImpuesto)
                            : '-',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        item.valorDescuento > 0
                            ? CurrencyUtils.format(item.valorDescuento)
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
                                  CurrencyUtils.format(item.subtotal + item.valorImpuesto - item.valorDescuento),
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
    final icono = Icon(Icons.local_offer, color: AppTheme.primary, size: 22);
    final etiqueta = Text(
      'Descuento General',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
    final campo = TextField(
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
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.isMobile ? 16 : 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      // 📱 Ícono + etiqueta + campo de $180px fijo en una sola Row no cabía en
      // un teléfono (se desbordaba a la derecha) — en mobile el campo baja
      // debajo de la etiqueta, a ancho completo.
      child: context.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [icono, SizedBox(width: 12), etiqueta]),
                SizedBox(height: 12),
                campo,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                icono,
                SizedBox(width: 12),
                etiqueta,
                SizedBox(width: 16),
                SizedBox(width: 180, child: campo),
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
    final valorUnit = CurrencyUtils.parseDecimal(_valorUnitController.text);
    final porcentajeImp =
        double.tryParse(_porcentajeImpuestoController.text) ?? 0;
    final enteredDesc =
        double.tryParse(_porcentajeDescuentoController.text) ?? 0;

    final calculo = calculos.calcularItemFactura(
      cantidad: cantidad.toDouble(),
      precioUnitario: valorUnit,
      porcentajeImpuesto: porcentajeImp,
      descuentoIngresado: enteredDesc,
      descuentoEsPorcentaje: _porcentajeTipoDescuento == 'Porcentaje',
    );

    return CurrencyUtils.format(calculo.total);
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
        showErrorDialog(context, 'Sin stock en $_origenSeleccionado (disponible: 0)');
        return;
      }

      if (cantidad > stockDisponible) {
        showErrorDialog(
          context,
          'Stock insuficiente en $_origenSeleccionado\n'
          'Solicitado: $cantidad - Disponible: $stockDisponible',
        );
        return;
      }
    }

    final precioUnitario = CurrencyUtils.parseDecimal(_valorUnitController.text);
    final porcentajeImpuesto =
        double.tryParse(_porcentajeImpuestoController.text) ?? 0;
    final enteredDescuento =
        double.tryParse(_porcentajeDescuentoController.text) ?? 0;

    final calculo = calculos.calcularItemFactura(
      cantidad: cantidad.toDouble(),
      precioUnitario: precioUnitario,
      porcentajeImpuesto: porcentajeImpuesto,
      descuentoIngresado: enteredDescuento,
      descuentoEsPorcentaje: _porcentajeTipoDescuento == 'Porcentaje',
    );
    final valorDescuento = calculo.valorDescuento;
    final porcentajeDescuento = calculo.porcentajeDescuento;
    final valorImpuesto = calculo.valorImpuesto;

    final item = ItemPedido(
      // productoId DEBE ser el _id real de Mongo: el backend descuenta
      // inventario buscando el producto por ese id (ProductoRepository.findById).
      // Antes se usaba el código/SKU cuando existía, lo que hacía que la
      // búsqueda fallara en silencio y el stock nunca se descontara para
      // cualquier producto con código (ej. todos los cargados por Excel).
      productoId: _productoSeleccionado!.id,
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
    final recalculo = calculos.recalcularBaseDesdeTotal(
      nuevoTotal: nuevoTotal,
      cantidad: item.cantidad.toDouble(),
      porcentajeImpuesto: r,
      porcentajeDescuento: d,
    );

    return ItemPedido(
      id: item.id,
      productoId: item.productoId,
      productoNombre: item.productoNombre,
      cantidad: item.cantidad,
      precioUnitario: recalculo.precioUnitario,
      notas: item.notas,
      ingredientesSeleccionados: item.ingredientesSeleccionados,
      ingredientesUsados: item.ingredientesUsados,
      agregadoPor: item.agregadoPor,
      fechaAgregado: item.fechaAgregado,
      porcentajeImpuesto: r,
      valorImpuesto: recalculo.valorImpuesto,
      porcentajeDescuento: d,
      valorDescuento: recalculo.valorDescuento,
      origen: item.origen,
      trasladoId: item.trasladoId,
    );
  }

  /// Abre un diálogo para editar el valor TOTAL de un ítem ya agregado,
  /// recalculando el precio base y el impuesto a partir de ese total.
  Future<void> _editarTotalItem(int index) async {
    final item = _items[index];
    final totalActual = item.subtotal + item.valorImpuesto - item.valorDescuento;
    final controller = TextEditingController(text: CurrencyUtils.formatPlain(totalActual));

    final nuevoTotal = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar total'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [MilesInputFormatter()],
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
              final texto = controller.text.trim();
              final v = texto.isEmpty ? null : CurrencyUtils.parse(texto);
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
        _valorUnitController.text = CurrencyUtils.formatForMilesInput(precioBase);
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
                  '✓ ${producto!.nombre} - ${CurrencyUtils.format(producto.precio)}',
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
                          '${borrador.items.length} productos - ${CurrencyUtils.format(borrador.total)}',
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
                                // El backend ya devuelve el stock, pero el
                                // caché local de productos no se entera solo.
                                if (mounted) {
                                  Provider.of<DatosCacheProvider>(context, listen: false)
                                      .limpiarProductos();
                                }
                                Navigator.pop(context);
                                _mostrarBorradores();
                              } catch (e) {
                                showErrorSnackBar(context, 'Error al eliminar: ${errorMessage(e)}');
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
      showErrorSnackBar(context, 'Error al cargar borradores: ${errorMessage(e)}');
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

    final items = List<ItemPedido>.from(pedido.items);

    final resultado = await mostrarDialogoEditarIvaDescuento(
      context: context,
      titulo: 'Borrador de ${pedido.cliente ?? "cliente"}',
      items: items,
      columnaPrecioLabel: 'Precio base',
    );
    final ivaValues = resultado.ivaValues;
    final dctoValues = resultado.dctoValues;

    if (!mounted) return;

    final List<ItemPedido> itemsCargados;
    if (resultado.confirmado) {
      // El precio base de un borrador propio ya es neto (sin IVA), así que
      // solo se recalculan descuento e impuesto con los % editados.
      itemsCargados = items.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final ivaPct = ivaValues[idx];
        final dctoPct = dctoValues[idx];
        final calculo = calculos.calcularItemFactura(
          cantidad: item.cantidad.toDouble(),
          precioUnitario: item.precioUnitario,
          porcentajeImpuesto: ivaPct,
          descuentoIngresado: dctoPct,
        );
        return ItemPedido(
          productoId: item.productoId,
          productoNombre: item.productoNombre,
          cantidad: item.cantidad,
          precioUnitario: item.precioUnitario,
          porcentajeImpuesto: ivaPct,
          valorImpuesto: calculo.valorImpuesto,
          porcentajeDescuento: dctoPct,
          valorDescuento: calculo.valorDescuento,
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

  // ─── Borradores locales por fallo (caja cerrada u otro error al pagar) ────
  // A diferencia de "Guardar como borrador" (abajo), este NO llama al backend
  // — el pedido nunca se creó porque falló antes de eso. Se guarda solo en
  // este dispositivo (SharedPreferences) para no perder lo que el usuario ya
  // había armado, y se puede recuperar después desde "Ver borradores locales".
  static const String _kDraftKeyFallido = 'facturacion_borradores_fallidos';

  Future<void> _guardarBorradorLocalPorFallo({
    required List<ItemPedido> items,
    required String cliente,
    String? clienteId,
    required String tipoFactura,
    required DateTime fechaFactura,
    required DateTime? fechaVencimiento,
    required String metodoPago,
    required Map<String, double> montosPago,
    required double dctoGeneral,
    required double retencionPct,
    required double reteIVAPct,
    required double reteICAPct,
    required double aiuPct,
    required String observaciones,
    required String motivo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDraftKeyFallido);
      final List<dynamic> borradores = raw != null ? jsonDecode(raw) : [];
      borradores.add({
        'timestamp': DateTime.now().toIso8601String(),
        'motivo': motivo,
        'items': items.map((i) => i.toJson()).toList(),
        'cliente': cliente,
        'clienteId': clienteId,
        'tipoFactura': tipoFactura,
        'fechaFactura': fechaFactura.toIso8601String(),
        'fechaVencimiento': fechaVencimiento?.toIso8601String(),
        'metodoPago': metodoPago,
        'montosPago': montosPago,
        'dctoGeneral': dctoGeneral,
        'retencionPct': retencionPct,
        'reteIVAPct': reteIVAPct,
        'reteICAPct': reteICAPct,
        'aiuPct': aiuPct,
        'observaciones': observaciones,
      });
      // Mantener máximo 10 borradores fallidos
      if (borradores.length > 10) borradores.removeAt(0);
      await prefs.setString(_kDraftKeyFallido, jsonEncode(borradores));
      appLog('💾 Borrador local guardado por fallo: $motivo');
    } catch (e) {
      appLog('❌ No se pudo guardar el borrador local: $e', level: LogLevel.error);
    }
  }

  /// Cuenta cuántos borradores locales por fallo hay guardados (para avisar al entrar).
  Future<int> _contarBorradoresLocalesFallidos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDraftKeyFallido);
      if (raw == null) return 0;
      return (jsonDecode(raw) as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _actualizarContadorBorradoresLocales() async {
    final n = await _contarBorradoresLocalesFallidos();
    if (mounted) setState(() => _borradoresLocalesCount = n);
  }

  /// Muestra la lista de borradores locales guardados por un fallo al guardar y
  /// pagar (ej. caja cerrada), y permite cargar uno de vuelta al formulario.
  Future<void> _verBorradoresLocalesFallidos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDraftKeyFallido);
      if (raw == null || raw == '[]') {
        if (mounted) showInfoSnackBar(context, 'No hay borradores locales guardados');
        return;
      }

      final List<dynamic> borradores = jsonDecode(raw);
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Borradores locales sin guardar (${borradores.length})',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: dialogWidth(context, 520),
            height: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Quedaron guardados solo en este dispositivo porque no se pudieron procesar. Cargalos cuando el problema esté resuelto (ej. abrir caja) y volvé a intentar "Guardar y Pagar".',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: borradores.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white12),
                    itemBuilder: (_, i) {
                      final b = borradores[borradores.length - 1 - i] as Map<String, dynamic>;
                      final fecha = DateTime.tryParse(b['timestamp'] ?? '')?.toLocal();
                      final fechaStr = fecha != null
                          ? '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}'
                          : 'Fecha desconocida';
                      final cliente = b['cliente'] ?? 'CONSUMIDOR FINAL';
                      final nItems = (b['items'] as List?)?.length ?? 0;
                      final motivo = b['motivo'] ?? 'Error desconocido';

                      return ListTile(
                        leading: Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
                        title: Text(cliente, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$fechaStr · $nItems ítem(s)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
                            ),
                            Text(
                              motivo,
                              style: TextStyle(color: AppTheme.error, fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              child: const Text('Cargar', style: TextStyle(color: Colors.greenAccent)),
                              onPressed: () async {
                                // Se quita de la lista guardada al cargarlo: si vuelve a
                                // fallar, se vuelve a guardar como una entrada nueva.
                                borradores.removeAt(borradores.length - 1 - i);
                                await prefs.setString(_kDraftKeyFallido, jsonEncode(borradores));
                                if (ctx.mounted) Navigator.pop(ctx, b);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: 'Eliminar borrador',
                              onPressed: () async {
                                borradores.removeAt(borradores.length - 1 - i);
                                await prefs.setString(_kDraftKeyFallido, jsonEncode(borradores));
                                if (ctx.mounted) Navigator.pop(ctx);
                                _verBorradoresLocalesFallidos();
                              },
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
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cerrar', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
            ),
          ],
        ),
      ).then((borrador) {
        if (borrador is Map<String, dynamic>) {
          _cargarBorradorLocalFallido(borrador);
        }
      });
      await _actualizarContadorBorradoresLocales();
    } catch (e) {
      appLog('Error mostrando borradores locales: $e', level: LogLevel.error);
    }
  }

  /// Carga un borrador local (guardado por un fallo previo) de vuelta al formulario.
  void _cargarBorradorLocalFallido(Map<String, dynamic> b) {
    setState(() {
      _items.clear();
      if (b['items'] != null) {
        for (final item in b['items'] as List) {
          try {
            _items.add(ItemPedido.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      }
      _clienteController.text = b['cliente'] ?? 'CONSUMIDOR FINAL';
      _tipoFactura = b['tipoFactura'] ?? 'LOCAL';
      if (b['fechaFactura'] != null) {
        _fechaFactura = DateTime.tryParse(b['fechaFactura']) ?? DateTime.now();
      }
      if (b['fechaVencimiento'] != null) {
        _fechaVencimiento = DateTime.tryParse(b['fechaVencimiento']) ?? DateTime.now().add(Duration(days: 30));
      }
      _metodoPago = b['metodoPago'] ?? 'efectivo';
      final montos = (b['montosPago'] as Map?)?.cast<String, dynamic>() ?? {};
      _montoEfectivoController.text = '${montos['efectivo'] ?? 0}';
      _montoTransferenciaController.text = '${montos['transferencia'] ?? 0}';
      _montoTarjetaController.text = '${montos['tarjeta'] ?? 0}';
      _montoSistereditoController.text = '${montos['sistecredito'] ?? 0}';
      _montoDatafonoController.text = '${montos['datafono'] ?? 0}';
      _montoBoldController.text = '${montos['bold'] ?? 0}';
      _montoAddiController.text = '${montos['addi'] ?? 0}';
      _montoCredilondonController.text = '${montos['credilondon'] ?? 0}';
      _montoNequiController.text = '${montos['nequi'] ?? 0}';
      _montoDaviplataController.text = '${montos['daviplata'] ?? 0}';
      _montoBancolombiaController.text = '${montos['bancolombia'] ?? 0}';
      _dctoGeneralController.text = '${b['dctoGeneral'] ?? 0}';
      _retencionController.text = '${b['retencionPct'] ?? 0}';
      _reteIVAController.text = '${b['reteIVAPct'] ?? 0}';
      _reteICAController.text = '${b['reteICAPct'] ?? 0}';
      _aiuController.text = '${b['aiuPct'] ?? 0}';
      _observacionesController.text = b['observaciones'] ?? '';
    });

    // Si el borrador trae un clienteId, buscar el cliente completo (dirección,
    // NIT, etc.) para que quede seleccionado igual que si se hubiera elegido
    // del autocompletar, no solo el nombre en texto.
    final clienteId = b['clienteId'] as String?;
    if (clienteId != null && clienteId.isNotEmpty) {
      _clienteService.buscarClientes(b['cliente'] ?? '').then((resultados) {
        final match = resultados.where((c) => c.id == clienteId).firstOrNull;
        if (match != null && mounted) {
          setState(() => _clienteSeleccionado = match);
        }
      }).catchError((_) {});
    }

    showSuccessSnackBar(context, 'Borrador local cargado — revisá los datos antes de guardar');
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
        tipoCaja: widget.tipoCaja,
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
      showErrorSnackBar(context, 'Error al guardar: ${errorMessage(e)}');
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
                    CurrencyUtils.format(_items.fold(0.0, (sum, item) => sum + item.subtotal + item.valorImpuesto - item.valorDescuento)),
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
          tipoCaja: widget.tipoCaja,
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
          showErrorDialog(context, 'Error al registrar deuda: verifica tu conexión e intenta de nuevo');
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
      final metodoPagoOriginal = _metodoPago; // para reconstruir el borrador local si falla
      final metodoPagoUsado = _mapFormaPagoBackend(_metodoPago);
      final medioPagoUsado =
          payment_mapping.medioPagoDianMap[_metodoPago] ?? 'efectivo';
      final detallePagoUsado = _detallePago;
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
      final montoBold = _metodoPago == 'bold'
          ? total
          : (_metodoPago == 'multiple'
                ? double.tryParse(_montoBoldController.text) ?? 0.0
                : 0.0);
      final montoAddi = _metodoPago == 'addi'
          ? total
          : (_metodoPago == 'multiple'
                ? double.tryParse(_montoAddiController.text) ?? 0.0
                : 0.0);
      final montoCredilondon = _metodoPago == 'credilondon'
          ? total
          : (_metodoPago == 'multiple'
                ? double.tryParse(_montoCredilondonController.text) ?? 0.0
                : 0.0);
      final montoNequi = _metodoPago == 'nequi'
          ? total
          : (_metodoPago == 'multiple'
                ? double.tryParse(_montoNequiController.text) ?? 0.0
                : 0.0);
      final montoDaviplata = _metodoPago == 'daviplata'
          ? total
          : (_metodoPago == 'multiple'
                ? double.tryParse(_montoDaviplataController.text) ?? 0.0
                : 0.0);
      final montoBancolombia = _metodoPago == 'bancolombia'
          ? total
          : (_metodoPago == 'multiple'
                ? double.tryParse(_montoBancolombiaController.text) ?? 0.0
                : 0.0);
      final esPedidoAsesor = widget.pedidoAsesor != null;
      final pedidoAsesorId = widget.pedidoAsesor?.id;
      final cotizacionId = widget.cotizacion?.id;

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
            tipoCaja: widget.tipoCaja,
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
            detallePago: detallePagoUsado,
            montoEfectivo: montoEfectivo,
            montoTarjeta: montoTarjeta,
            montoTransferencia: montoTransferencia,
            montoSistecredito: montoSistecredito,
            montoDatafono: montoDatafono,
            montoBold: montoBold,
            montoAddi: montoAddi,
            montoCredilondon: montoCredilondon,
            montoNequi: montoNequi,
            montoDaviplata: montoDaviplata,
            montoBancolombia: montoBancolombia,
            tipoCaja: pedidoCreado.tipoCaja ?? widget.tipoCaja,
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

          // El inventario ya se descontó en el backend al crear el pedido
          // (InventarioService.procesarPedidoParaInventario, disparado desde
          // PedidosController.create()) — ver por qué se quitó la llamada a
          // _registrarMovimientosInventarioVentaEnBackground que estaba acá:
          // volvía a restar la misma cantidad sobre el stock que el backend
          // ya había descontado, duplicando la salida en cada venta.

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

          // Si viene de una cotización, marcarla como convertida
          if (cotizacionId != null) {
            try {
              await _cotizacionService.convertirAFactura(cotizacionId, pedidoPagado.id);
            } catch (e) {
              appLog('⚠️ Error al marcar cotización como convertida: $e');
            }
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
            // ⚠️ Se usa metodoPagoOriginal (lo que el usuario eligió, ej. "addi")
            //    y NO metodoPagoUsado (el bucket contable al que se mapea para
            //    el cuadre de caja, ej. "sistecredito" — ver mapFormaPagoBackend
            //    en payment_mapping.dart). La factura impresa debe mostrar el
            //    método de pago real, no la categoría contable interna.
            final resumen = _prepararResumenFactura(
              pedidoPagado,
              metodoPagoOriginal,
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
              if (montoNequi > 0)
                desglose.add({'formaPago': 'Nequi', 'monto': montoNequi});
              if (montoDaviplata > 0)
                desglose.add({'formaPago': 'DaviPlata', 'monto': montoDaviplata});
              if (montoBancolombia > 0)
                desglose.add({
                  'formaPago': 'Bancolombia',
                  'monto': montoBancolombia,
                });
              if (montoBold > 0)
                desglose.add({'formaPago': 'Bold', 'monto': montoBold});
              if (montoAddi > 0)
                desglose.add({'formaPago': 'Addi', 'monto': montoAddi});
              if (montoCredilondon > 0)
                desglose.add({
                  'formaPago': 'Credilondon',
                  'monto': montoCredilondon,
                });
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
                            'Total: ${CurrencyUtils.format(total)}',
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
          final motivo = errorMessage(e);
          // No se pudo crear/pagar el pedido (ej. caja cerrada): nada quedó
          // guardado en el backend, así que se guarda localmente para no
          // perder lo que ya se había armado.
          await _guardarBorradorLocalPorFallo(
            items: itemsOriginales,
            cliente: clienteTexto,
            clienteId: clienteCapturado?.id,
            tipoFactura: tipoFacturaCapturado,
            fechaFactura: fechaFacturaCapturada,
            fechaVencimiento: fechaVencimientoCapturada,
            metodoPago: metodoPagoOriginal,
            montosPago: {
              'efectivo': montoEfectivo,
              'transferencia': montoTransferencia,
              'tarjeta': montoTarjeta,
              'sistecredito': montoSistecredito,
              'datafono': montoDatafono,
              'bold': montoBold,
              'addi': montoAddi,
              'credilondon': montoCredilondon,
              'nequi': montoNequi,
              'daviplata': montoDaviplata,
              'bancolombia': montoBancolombia,
            },
            dctoGeneral: dctoGeneral,
            retencionPct: retencionPct,
            reteIVAPct: reteIVAPct,
            reteICAPct: reteICAPct,
            aiuPct: aiuPct,
            observaciones: observacionesCapturadas,
            motivo: motivo,
          );
          await _actualizarContadorBorradoresLocales();
          if (mounted) {
            showErrorDialog(
              context,
              '$motivo\n\nEl pedido se guardó como borrador local en este dispositivo — tocá el ícono de borradores para recuperarlo.',
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

        if (resultado.success) {
          // Éxito (posiblemente en un reintento): limpiar cualquier error
          // previo guardado para este pedido.
          _pedidoService.setErrorFacturacionElectronica(pedido.id, null).catchError((e) {
            appLog('⚠️ No se pudo limpiar el error de facturación guardado: $e');
            return pedido;
          });

          if (!mounted) return;
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
          // No lanzó excepción, pero Matias/DIAN rechazó el documento: guardar
          // el motivo para poder revisarlo después desde Facturas Electrónicas.
          _pedidoService
              .setErrorFacturacionElectronica(pedido.id, resultado.message)
              .catchError((e) {
            appLog('⚠️ No se pudo guardar el error de facturación: $e');
            return pedido;
          });

          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text('⚠️ Error DIAN ($nombreDoc): ${resultado.message}'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      } catch (e) {
        final motivo = errorMessage(e);
        appLog('❌ [DIAN] Error al emitir documento: $e');
        _pedidoService.setErrorFacturacionElectronica(pedido.id, motivo).catchError((e2) {
          appLog('⚠️ No se pudo guardar el error de facturación: $e2');
          return pedido;
        });
        if (!mounted) return;
        showErrorDialog(context, 'Error al enviar a DIAN: $motivo');
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
      if (res != null) {
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
        return;
      }

      messenger.showSnackBar(const SnackBar(
        content: Text('PDF no disponible. El documento debe estar ACEPTADO por la DIAN.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 5),
      ));
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Error al descargar PDF: ${errorMessage(e)}');
      }
    }
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

  String _formatearFormaPago(String formaPago) {
    switch (formaPago.toLowerCase()) {
      case 'efectivo': return 'Efectivo';
      case 'tarjeta': return 'Tarjeta';
      case 'tarjeta_credito': return 'Tarjeta Crédito';
      case 'transferencia': return 'Transferencia';
      case 'nequi': return 'Nequi';
      case 'daviplata': return 'DaviPlata';
      case 'bancolombia': return 'Bancolombia';
      case 'bold': return 'Bold';
      case 'addi': return 'Addi';
      case 'credilondon': return 'Credilondon';
      case 'sistecredito': return 'Sistecredito';
      case 'datafono': return 'Datafono';
      case 'credito': return 'A Crédito';
      case 'mixto': return 'Pago Mixto';
      case 'multiple': return 'Pago Múltiple';
      default: return formaPago;
    }
  }

  /// Muestra una vista previa del PDF con los items/cliente/descuentos
  /// actuales del formulario, SIN guardar ni pagar nada — no toca el
  /// backend en absoluto. Útil para revisar cómo va a quedar la factura
  /// antes de confirmar la venta. El documento se marca explícitamente
  /// como "VISTA PREVIA" para que no se confunda con la factura real
  /// (que solo obtiene su número definitivo al guardar).
  Future<void> _mostrarVistaPreviaFactura() async {
    if (_items.isEmpty) {
      showWarningSnackBar(context, 'Agregue al menos un producto para ver la vista previa');
      return;
    }

    bool dialogoCargaAbierto = false;
    try {
      dialogoCargaAbierto = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(width: 16),
              Text('Generando vista previa...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
        ),
      );

      // Mismos cálculos que _guardarYPagar, pero sin persistir nada.
      final subtotal = _items.fold(0.0, (sum, item) => sum + item.subtotal);
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
      final total = subtotal + totalImpuestos + aiuValor - totalDescuentos - totalRetenciones;

      final userName = Provider.of<UserProvider>(context, listen: false).userName ?? 'Sistema';

      // Pedido temporal solo en memoria — nunca se envía al backend.
      final pedidoPreview = Pedido(
        id: '',
        fecha: _fechaFactura,
        tipo: TipoPedido.normal,
        mesa: 'FACTURACION',
        mesero: userName,
        items: _items,
        total: total,
        estado: EstadoPedido.activo,
        cliente: _clienteController.text,
        fechaVencimiento: _fechaVencimiento,
        notas: _observacionesController.text.trim(),
      );

      NegocioInfo? negocioInfo;
      try {
        negocioInfo = await _negocioInfoService.getNegocioInfo();
      } catch (e) {

      }

      final resumen = _prepararResumenFactura(
        pedidoPreview,
        _metodoPago,
        total,
        totalDescuentos,
        0.0,
        negocioInfo,
        clienteData: _clienteSeleccionado,
        retencionPct: retencionPct,
        reteIVAPct: reteIVAPct,
        reteICAPct: reteICAPct,
        aiuPct: aiuPct,
        dctoGeneral: dctoGeneral,
        retencionValor: retencionValor,
        reteIVAValor: reteIVAValor,
        reteICAValor: reteICAValor,
        aiuValor: aiuValor,
        observaciones: _observacionesController.text.trim(),
      );

      // Marca clara de que esto NO es un documento numerado real todavía.
      resumen['numero'] = 'VISTA PREVIA';
      resumen['numeroPedido'] = 'VISTA PREVIA';
      resumen['tipoDocumento'] = 'VISTA PREVIA - SIN GUARDAR';

      // rootNavigator: true es imprescindible aquí: showDialog() por defecto
      // empuja el diálogo al Navigator RAÍZ de la app, pero esta pantalla
      // vive dentro del Navigator anidado de la ShellRoute (sidebar+topbar
      // persistentes). Un Navigator.of(context).pop() sin esa bandera busca
      // el Navigator anidado más cercano — que no tiene el diálogo de carga
      // para cerrar — y en vez de eso hace pop() de la propia pantalla de
      // Facturación (te saca al Dashboard) o revienta con "_debugLocked" si
      // hay una transición de ruta en curso en ese momento.
      Navigator.of(context, rootNavigator: true).pop(); // Cerrar indicador de carga
      dialogoCargaAbierto = false;

      await _pdfService.mostrarDialogoImpresion(resumen: resumen, esFactura: true);
    } catch (e) {
      if (dialogoCargaAbierto && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        showErrorSnackBar(context, 'Error generando vista previa: ${errorMessage(e)}');
      }
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
      // No caer al pedido.id (ObjectId de Mongo) cuando no hay numeroFactura
      // todavía: se veía como un "código" sin sentido debajo del encabezado
      // del PDF. Mejor dejarlo vacío que mostrar un ID interno.
      'pedidoId': pedido.id,
      'numero': pedido.numeroFactura ?? '',
      'numeroPedido': pedido.numeroFactura ?? '',
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
      _montoBoldController.text = '0';
      _montoAddiController.text = '0';
      _montoCredilondonController.text = '0';
      _montoNequiController.text = '0';
      _montoDaviplataController.text = '0';
      _montoBancolombiaController.text = '0';

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
