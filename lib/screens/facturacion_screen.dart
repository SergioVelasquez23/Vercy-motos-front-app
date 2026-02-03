import 'package:flutter/material.dart';
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
import '../models/cliente.dart';
import '../models/negocio_info.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/datos_cache_provider.dart';
import '../widgets/vercy_sidebar_layout.dart';
import '../dialogs/dialogo_pago.dart';

class FacturacionScreen extends StatefulWidget {
  final PedidoAsesor? pedidoAsesor;

  const FacturacionScreen({super.key, this.pedidoAsesor});
  
  @override
  _FacturacionScreenState createState() => _FacturacionScreenState();
}

class _FacturacionScreenState extends State<FacturacionScreen> {
  final PedidoService _pedidoService = PedidoService();
  final ProductoService _productoService = ProductoService();
  final PedidoAsesorService _pedidoAsesorService = PedidoAsesorService();
  final PDFService _pdfService = PDFService();
  final NegocioInfoService _negocioInfoService = NegocioInfoService();
  final ImpresionService _impresionService = ImpresionService();
  final InventarioService _inventarioService = InventarioService();
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
      TextEditingController(text: '0');
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

  // Variables de estado
  String _tipoFactura = 'POS';
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
    {'value': 'multiple', 'label': 'Múltiple', 'icon': Icons.payments},
  ];

  // Controladores para pago múltiple
  final TextEditingController _montoEfectivoController = TextEditingController(
    text: '0',
  );
  final TextEditingController _montoTransferenciaController =
      TextEditingController(text: '0');

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

  Cliente? _clienteSeleccionado;
  Producto? _productoSeleccionado;
  List<ItemPedido> _items = [];
  List<Producto> _productosDisponibles = [];
  List<Cliente> _clientesDisponibles = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _cargarClientes();
    
    // Si se pasó un pedido de asesor, precargar los datos
    if (widget.pedidoAsesor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _precargarDatosPedidoAsesor();
      });
    }
  }

  void _precargarDatosPedidoAsesor() {
    final pedido = widget.pedidoAsesor!;

    setState(() {
      // Precargar nombre del cliente
      _clienteController.text = pedido.clienteNombre;

      // Precargar items
      _items = List.from(pedido.items);

      // Recalcular totales
      _calcularTotal();
    });

    // Mostrar notificación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pedido de ${pedido.asesorNombre} cargado correctamente'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _calcularTotal() {
    // Este método se usa para recalcular totales cuando se cargan items
    // En facturacion_screen, los cálculos de totales se hacen en _guardarFactura
    // Este método está aquí para mantener compatibilidad
    setState(() {});
  }

  Future<void> _cargarProductos() async {
    // Obtener productos desde el provider en lugar de cargarlos nuevamente
    final cacheProvider = Provider.of<DatosCacheProvider>(
      context,
      listen: false,
    );

    if (cacheProvider.productos != null &&
        cacheProvider.productos!.isNotEmpty) {
      setState(() {
        _productosDisponibles = cacheProvider.productos!;
      });
    } else {
      // Si no hay productos en cache, cargarlos
      try {
        final productos = await _productoService.getProductos();
        setState(() {
          _productosDisponibles = productos;
        });
      } catch (e) {
          
      }
    }
  }

  Future<void> _cargarClientes() async {
    try {
      final clientes = await _clienteService.obtenerClientes();
      setState(() {
        _clientesDisponibles = clientes;
      });
    } catch (e) {
        
    }
  }

  @override
  void dispose() {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return VercySidebarLayout(
      title: 'Facturación',
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
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
                        _buildMetodoPago(),
                        SizedBox(height: spacing),
                        _buildDatosExtras(),
                        SizedBox(height: spacing),
                        _buildDatosProducto(),
                        SizedBox(height: spacing),
                        _buildItemsList(),
                        SizedBox(height: spacing),
                        _buildRetencionesYAIU(),
                        SizedBox(height: spacing),
                        _buildTotales(),
                        SizedBox(height: spacing),
                        _buildBotonesAccion(),
                        SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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
            color: AppTheme.cardBg,
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
                            color: AppTheme.textPrimary,
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
                          foregroundColor: Colors.black87,
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
                        color: AppTheme.textPrimary,
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
                        foregroundColor: Colors.black87,
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
            color: AppTheme.cardBg,
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
            color: AppTheme.textPrimary,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        field,
      ],
    );
  }

  Widget _buildTipoDropdown() {
    return DropdownButtonFormField<String>(
      value: _tipoFactura,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        filled: true,
        fillColor: AppTheme.surfaceDark,
      ),
      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      items: ['POS', 'FACTURA']
          .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
          .toList(),
      onChanged: (value) => setState(() => _tipoFactura = value!),
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
            color: AppTheme.textSecondary,
            size: 18,
          ),
          filled: true,
          fillColor: AppTheme.surfaceDark,
        ),
        child: Text(
          '${_fechaFactura.year}-${_fechaFactura.month.toString().padLeft(2, '0')}-${_fechaFactura.day.toString().padLeft(2, '0')}',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
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
            color: AppTheme.textSecondary,
            size: 18,
          ),
          filled: true,
          fillColor: AppTheme.surfaceDark,
        ),
        child: Text(
          '${_fechaVencimiento.year}-${_fechaVencimiento.month.toString().padLeft(2, '0')}-${_fechaVencimiento.day.toString().padLeft(2, '0')}',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildClienteField() {
    return Row(
      children: [
        Expanded(
          child: Autocomplete<Cliente>(
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
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      hintText: 'Buscar cliente...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: Icon(
                        Icons.arrow_drop_down,
                        color: AppTheme.textSecondary,
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
                      color: AppTheme.surfaceDark,
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
                            return InkWell(
                              onTap: () => onSelected(cliente),
                              child: Container(
                                padding: EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppTheme.textSecondary.withOpacity(
                                        0.2,
                                      ),
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
                                              color: AppTheme.textPrimary,
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
                                                color: AppTheme.textSecondary,
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
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
                      color: AppTheme.textPrimary,
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
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  // Primera fila
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                'ORDEN COMPRA',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _ordenCompraController,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                'FECHA COMPRA',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final fecha = await showDatePicker(
                                  context: context,
                                  initialDate: _fechaCompra ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (fecha != null) {
                                  setState(() => _fechaCompra = fecha);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  suffixIcon: Icon(
                                    Icons.calendar_today,
                                    color: AppTheme.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.surfaceDark,
                                ),
                                child: Text(
                                  _fechaCompra != null
                                      ? '${_fechaCompra!.day.toString().padLeft(2, '0')}/${_fechaCompra!.month.toString().padLeft(2, '0')}/${_fechaCompra!.year}'
                                      : 'mm/dd/yyyy',
                                  style: TextStyle(
                                    color: _fechaCompra != null
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                'ORDEN SERVICIO',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _ordenServicioController,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                'ORDEN PEDIDO',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _ordenPedidoController,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                'VENDEDOR',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _vendedorController,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Segunda fila
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                '% DCTO PAGO',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _porcentajeDctoPagoController,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                'LISTA DE PRECIO',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _listaPrecios,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                              items: ['Detal', 'Mayor', 'Distribuidor']
                                  .map(
                                    (lista) => DropdownMenuItem(
                                      value: lista,
                                      child: Text(lista),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _listaPrecios = value!),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                '# GUIA',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _guiaController,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                'FECHA DCTO PAGO',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final fecha = await showDatePicker(
                                  context: context,
                                  initialDate: _fechaDctoPago ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (fecha != null) {
                                  setState(() => _fechaDctoPago = fecha);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  suffixIcon: Icon(
                                    Icons.calendar_today,
                                    color: AppTheme.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.surfaceDark,
                                ),
                                child: Text(
                                  _fechaDctoPago != null
                                      ? '${_fechaDctoPago!.year}-${_fechaDctoPago!.month.toString().padLeft(2, '0')}-${_fechaDctoPago!.day.toString().padLeft(2, '0')}'
                                      : '2026-02-18',
                                  style: TextStyle(
                                    color: _fechaDctoPago != null
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: SizedBox()), // Espaciador para balance
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDatosProducto() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
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
                      color: AppTheme.textPrimary,
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
                            color: AppTheme.textPrimary,
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
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _codigoBarrasController.text.isNotEmpty
                                    ? AppTheme.primary
                                    : AppTheme.textMuted.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppTheme.textMuted.withOpacity(0.3),
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
                            fillColor: AppTheme.surfaceDark,
                            hintText: 'Escanee o ingrese código',
                            hintStyle: TextStyle(color: AppTheme.textSecondary),
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
                        child: TextField(
                          controller: _codigoController,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Código',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Autocomplete<Producto>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<Producto>.empty();
                            }
                            if (textEditingValue.text.length < 2) {
                              return const Iterable<Producto>.empty();
                            }
                            return _productosDisponibles
                                .where((Producto producto) {
                                  return producto.nombre.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      ) ||
                                      producto.id.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      );
                                })
                                .take(15);
                          },
                          displayStringForOption: (Producto producto) =>
                              producto.nombre,
                          onSelected: (Producto producto) {
                            setState(() {
                              _productoSeleccionado = producto;
                              _nombreProductoController.text = producto.nombre;
                              _codigoController.text = producto.id;
                              _valorUnitController.text = producto.precio
                                  .toString();
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
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Nombre producto',
                                    labelStyle: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.surfaceDark,
                                    suffixIcon: Icon(
                                      Icons.arrow_drop_down,
                                      color: AppTheme.textSecondary,
                                    ),
                                    hintText: 'Escribe al menos 2 letras...',
                                    hintStyle: TextStyle(
                                      color: AppTheme.textSecondary,
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
                                    color: AppTheme.surfaceDark,
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
                                          final Producto option = options
                                              .elementAt(index);
                                          return InkWell(
                                            onTap: () {
                                              onSelected(option);
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(12.0),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: AppTheme
                                                        .textSecondary
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
                                                      color:
                                                          AppTheme.textPrimary,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'Código: ${option.id}',
                                                        style: TextStyle(
                                                          color: AppTheme
                                                              .textSecondary,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      Spacer(),
                                                      Text(
                                                        '\$${option.precio.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          color:
                                                              AppTheme.primary,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
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
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Cantidad',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
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
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Valor unit',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            prefixText: '\$',
                            prefixStyle: TextStyle(color: AppTheme.textPrimary),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
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
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Valor tot',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark.withOpacity(0.5),
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
                  // Fila de impuestos y descuentos
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _tipoImpuesto,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          dropdownColor: AppTheme.surfaceDark,
                          decoration: InputDecoration(
                            labelText: 'Tipo Impuesto',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                          ),
                          items: ['IVA', 'IMPOCONSUMO', 'NINGUNO']
                              .map(
                                (tipo) => DropdownMenuItem(
                                  value: tipo,
                                  child: Text(tipo),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _tipoImpuesto = value!),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _porcentajeImpuestoController,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: '% Imp.',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _porcentajeTipoDescuento,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          dropdownColor: AppTheme.surfaceDark,
                          decoration: InputDecoration(
                            labelText: 'Porcer',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                          ),
                          items: ['Porcentaje', 'Valor']
                              .map(
                                (tipo) => DropdownMenuItem(
                                  value: tipo,
                                  child: Text(tipo),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _porcentajeTipoDescuento = value!),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _porcentajeDescuentoController,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: '% Descue',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _agregarItem,
                        icon: Icon(Icons.add),
                        label: Text(
                          'Agregar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black87,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                        ),
                      ),
                    ],
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
          color: AppTheme.cardBg,
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
                color: AppTheme.textSecondary,
              ),
              SizedBox(height: 16),
              Text(
                'No hay productos agregados',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
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
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Cantidad',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'P. Unit',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Impuesto',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Descuento',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
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
              color: AppTheme.textSecondary.withOpacity(0.2),
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
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${item.cantidad}',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '\$${item.precioUnitario.toStringAsFixed(0)}',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '\$${item.subtotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
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
        color: AppTheme.cardBg,
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
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    _retencionesExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
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
                        SizedBox(height: 16),
                        // Tercera fila: Descuento General
                        _buildRetencionField(
                          'Dcto. General',
                          _dctoGeneralController,
                          'Valor',
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
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildRetencionField(
                            'Dcto. General',
                            _dctoGeneralController,
                            'Valor',
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
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: AppTheme.surfaceDark,
            suffixText: suffix,
            suffixStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildTotales() {
    final subtotal = _items.fold(0.0, (sum, item) => sum + item.subtotal);
    
    // Calcular retenciones
    final retencionPct = double.tryParse(_retencionController.text) ?? 0;
    final reteIVAPct = double.tryParse(_reteIVAController.text) ?? 0;
    final reteICAPct = double.tryParse(_reteICAController.text) ?? 0;
    final aiuPct = double.tryParse(_aiuController.text) ?? 0;
    final dctoGeneral = double.tryParse(_dctoGeneralController.text) ?? 0;

    final retencionValor = subtotal * (retencionPct / 100);
    final reteIVAValor = subtotal * (reteIVAPct / 100);
    final reteICAValor = subtotal * (reteICAPct / 100);
    final aiuValor = subtotal * (aiuPct / 100);
    
    final totalImpuestos = 0.0;
    final totalDescuentos = dctoGeneral;
    final totalRetenciones = retencionValor + reteIVAValor + reteICAValor;
    final total =
        subtotal +
        totalImpuestos +
        aiuValor -
        totalDescuentos -
        totalRetenciones;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', subtotal),
          _buildTotalRow('Dcto Producto', 0),
          _buildTotalRow('Impuesto', totalImpuestos),
          _buildTotalRow('Dcto General', -totalDescuentos),
          if (retencionValor > 0)
            _buildTotalRow(
              'Retención (${retencionPct.toStringAsFixed(1)}%)',
              -retencionValor,
            ),
          if (reteIVAValor > 0)
            _buildTotalRow(
              'ReteIVA (${reteIVAPct.toStringAsFixed(1)}%)',
              -reteIVAValor,
            ),
          if (reteICAValor > 0)
            _buildTotalRow(
              'ReteICA (${reteICAPct.toStringAsFixed(1)}%)',
              -reteICAValor,
            ),
          if (aiuValor > 0)
            _buildTotalRow('AIU (${aiuPct.toStringAsFixed(1)}%)', aiuValor),
          Divider(thickness: 2, color: Colors.grey.shade700),
          _buildTotalRow('TOTAL', total, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double valor, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.white,
            ),
          ),
          Text(
            '\$${valor.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppTheme.primary : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _calcularValorTotal() {
    final cantidad = int.tryParse(_cantidadController.text) ?? 0;
    final valorUnit = double.tryParse(_valorUnitController.text) ?? 0;
    final porcentajeImp =
        double.tryParse(_porcentajeImpuestoController.text) ?? 0;
    final porcentajeDesc =
        double.tryParse(_porcentajeDescuentoController.text) ?? 0;

    final subtotal = cantidad * valorUnit;
    final impuesto = subtotal * (porcentajeImp / 100);
    final descuento = subtotal * (porcentajeDesc / 100);
    final total = subtotal + impuesto - descuento;

    return '\$${total.toStringAsFixed(0)}';
  }

  void _agregarItem() {
    if (_nombreProductoController.text.isEmpty ||
        _valorUnitController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complete los datos del producto')),
      );
      return;
    }

    final cantidad = int.tryParse(_cantidadController.text) ?? 1;
    final precioUnitario = double.tryParse(_valorUnitController.text) ?? 0;
    final porcentajeImpuesto =
        double.tryParse(_porcentajeImpuestoController.text) ?? 0;
    final porcentajeDescuento =
        double.tryParse(_porcentajeDescuentoController.text) ?? 0;

    final subtotal = cantidad * precioUnitario;
    final valorImpuesto = subtotal * (porcentajeImpuesto / 100);
    final valorDescuento = subtotal * (porcentajeDescuento / 100);

    final item = ItemPedido(
      productoId:
          _productoSeleccionado?.id ??
          'temp-${DateTime.now().millisecondsSinceEpoch}',
      productoNombre: _nombreProductoController.text,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
    );

    setState(() {
      _items.add(item);
      _limpiarFormularioProducto();
    });
  }

  void _eliminarItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _limpiarFormularioProducto() {
    _codigoBarrasController.clear();
    _codigoController.clear();
    _nombreProductoController.clear();
    _cantidadController.text = '1';
    _valorUnitController.clear();
    _porcentajeImpuestoController.text = '0';
    _porcentajeDescuentoController.text = '0';
    _productoSeleccionado = null;
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
        _codigoController.text = producto!.codigo ?? '';
        _nombreProductoController.text = producto.nombre;
        _valorUnitController.text = producto.precio.toString();
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
    final resultado = await Navigator.pushNamed(context, '/clientes/form');

    // Si se creó un cliente, actualizar el campo y la lista
    if (resultado != null && resultado is Cliente) {
      setState(() {
        _clienteSeleccionado = resultado;
        _clienteController.text = resultado.nombreCompleto;
        // Agregar el nuevo cliente a la lista
        _clientesDisponibles.add(resultado);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cliente creado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Widget para seleccionar método de pago
  Widget _buildMetodoPago() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
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
                  color: AppTheme.textPrimary,
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
                onTap: () => setState(() => _metodoPago = metodo['value']),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withOpacity(0.2)
                        : AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textMuted.withOpacity(0.3),
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
                            : AppTheme.textSecondary,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        metodo['label'],
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
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
          // Campos para pago múltiple
          if (_metodoPago == 'multiple') ...[
            SizedBox(height: 20),
            Divider(color: AppTheme.textMuted.withOpacity(0.3)),
            SizedBox(height: 16),
            Text(
              'Distribución del pago',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
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
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _montoEfectivoController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: AppTheme.primary,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
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
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _montoTransferenciaController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
                          prefixIcon: Icon(
                            Icons.account_balance,
                            color: AppTheme.primary,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
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

  // Widget con botones de acción
  Widget _buildBotonesAccion() {
    final subtotal = _items.fold(0.0, (sum, item) => sum + item.subtotal);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Resumen rápido
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total a Pagar:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '\$${subtotal.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Botones de acción
          Row(
            children: [
              // Guardar como borrador
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _guardarComoBorrador,
                  icon: Icon(Icons.drafts),
                  label: Text('Guardar Borrador'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.textMuted),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),

              // Guardar y Pagar
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _guardarYPagar,
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.check_circle),
                  label: Text(
                    'Guardar y Pagar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Cargar facturas en borrador
  Future<void> _mostrarBorradores() async {
    setState(() => _isLoading = true);

    try {
      // Obtener todos los pedidos activos de facturación
      final pedidos = await PedidoService.getPedidos();
      final borradores = pedidos
          .where(
            (p) => p.estado == EstadoPedido.activo && p.mesa == 'FACTURACION',
          )
          .toList();

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
          backgroundColor: AppTheme.cardBg,
          title: Row(
            children: [
              Icon(Icons.drafts, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Facturas en borrador',
                style: TextStyle(color: AppTheme.textPrimary),
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
                  color: AppTheme.surfaceDark,
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(Icons.receipt, color: AppTheme.primary),
                    title: Text(
                      borrador.cliente ?? 'Sin cliente',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${borrador.items.length} productos - \$${borrador.total.toStringAsFixed(0)}',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        Text(
                          '${borrador.fecha.day}/${borrador.fecha.month}/${borrador.fecha.year}',
                          style: TextStyle(
                            color: AppTheme.textMuted,
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
                            final confirmar = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: AppTheme.cardBg,
                                title: Text(
                                  '¿Eliminar borrador?',
                                  style: TextStyle(color: AppTheme.textPrimary),
                                ),
                                content: Text(
                                  '¿Está seguro de eliminar este borrador?',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirmar == true) {
                              try {
                                await _pedidoService.eliminarPedido(
                                  borrador.id,
                                );
                                Navigator.pop(context);
                                _mostrarBorradores();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al eliminar: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar borradores: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Cargar un borrador en el formulario
  void _cargarBorrador(Pedido pedido) {
    setState(() {
      _items = List.from(pedido.items);
      _clienteController.text = pedido.cliente ?? 'CONSUMIDOR FINAL';
      _fechaFactura = pedido.fecha;
      _fechaVencimiento =
          pedido.fechaVencimiento ?? DateTime.now().add(Duration(days: 30));
      _tipoFactura = pedido.tipoFactura ?? 'POS';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Borrador cargado'),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
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
      final total = subtotal;

      final pedido = Pedido(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        fecha: _fechaFactura,
        tipo: TipoPedido.normal,
        mesa:
            'FACTURACION', // Identificador especial para pedidos de facturación
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
        totalImpuestos: 0.0,
        totalDescuentos: 0.0,
        totalFinal: total,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      final subtotal = _items.fold(0.0, (sum, item) => sum + item.subtotal);
      final total = subtotal;
      final userName =
          Provider.of<UserProvider>(context, listen: false).userName ??
          'Sistema';

      // Crear el pedido primero
      final pedido = Pedido(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        fecha: _fechaFactura,
        tipo: TipoPedido.normal,
        mesa: 'FACTURACION',
        cliente: _clienteController.text,
        mesero: userName,
        items: _items,
        total: total,
        estado: EstadoPedido.activo,
        tipoFactura: _tipoFactura,
        fechaVencimiento: _fechaVencimiento,
        subtotal: subtotal,
        totalImpuestos: 0.0,
        totalDescuentos: 0.0,
        totalFinal: total,
      );

      // Guardar el pedido
      final pedidoCreado = await _pedidoService.createPedido(pedido);

      // Si viene de pedido asesor, procesar pago directamente sin diálogo
      if (widget.pedidoAsesor != null) {
        try {
          // Calcular montos según método de pago
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
          
          // Procesar pago directo con método de pago seleccionado
          await _pedidoService.pagarPedido(
            pedidoCreado.id,
            formaPago: _metodoPago,
            propina: 0.0,
            totalPagado: total,
            procesadoPor: userName,
            notas: 'Pago de pedido asesor',
            descuento: 0.0,
            pagoMultiple: _metodoPago == 'multiple',
            montoEfectivo: montoEfectivo,
            montoTarjeta: 0.0,
            montoTransferencia: montoTransferencia,
          );

          // 📦 Registrar movimientos de inventario (salida de stock)
          await _registrarMovimientosInventarioVenta(pedidoCreado);

          // Marcar pedido asesor como facturado
          if (widget.pedidoAsesor!.id != null) {
            try {
              await _pedidoAsesorService.marcarComoFacturado(
                widget.pedidoAsesor!.id!,
                userName,
              );
            } catch (e) {
                
            }
          }

          setState(() => _isLoading = false);

          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pedido procesado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );

          _limpiarFormulario();
          Navigator.of(context).pop(); // Regresar a lista de pedidos
        } catch (e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al procesar pago: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Para facturación normal, procesar pago directamente sin diálogo
        try {
          // Calcular montos según método de pago
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
          
          // Procesar pago directo con método de pago seleccionado
          await _pedidoService.pagarPedido(
            pedidoCreado.id,
            formaPago: _metodoPago,
            propina: 0.0,
            totalPagado: total,
            procesadoPor: userName,
            notas: 'Pago desde facturación',
            descuento: 0.0,
            pagoMultiple: _metodoPago == 'multiple',
            montoEfectivo: montoEfectivo,
            montoTarjeta: 0.0,
            montoTransferencia: montoTransferencia,
          );

          // 📦 Registrar movimientos de inventario (salida de stock)
          await _registrarMovimientosInventarioVenta(pedidoCreado);

          setState(() => _isLoading = false);

          // Mostrar diálogo de éxito con opciones de impresión
          await _mostrarDialogoFacturaExitosa(
            pedidoCreado,
            _metodoPago,
            total,
            0.0,
            0.0,
          );

          _limpiarFormulario();
        } catch (e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al procesar pago: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear pedido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 📦 Registrar movimientos de inventario cuando se factura (venta)
  Future<void> _registrarMovimientosInventarioVenta(Pedido pedido) async {
    try {
        

      for (var item in pedido.items) {
        try {
          final movimiento = MovimientoInventario(
            inventarioId: item.productoId,
            productoId: item.productoId,
            productoNombre: item.productoNombre ?? 'Producto',
            tipoMovimiento: 'Salida',
            motivo: 'Venta - Factura ${pedido.id}',
            cantidadAnterior: 0, // El backend calculará el stock anterior
            cantidadMovimiento: item.cantidad.toDouble(),
            cantidadNueva: 0, // El backend calculará el stock nuevo
            responsable: pedido.mesero ?? 'Sistema',
            referencia: 'FV-${pedido.id}',
            observaciones: 'Venta a ${pedido.cliente ?? 'CONSUMIDOR FINAL'}',
            costoUnitario: item.precioUnitario,
            precioTotal: item.subtotal,
            fecha: DateTime.now(),
            facturaNo: pedido.id,
            proveedor: null,
          );

          await _inventarioService.registrarMovimiento(movimiento);
        } catch (e) {
          // Continuar con el siguiente item aunque haya error
        }
      }

        
    } catch (e) {
        
      // No lanzar excepción para no interrumpir el flujo de la factura
    }
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
        backgroundColor: AppTheme.cardBg,
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
                      color: AppTheme.textSecondary,
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
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResumenItem('Cliente', pedido.cliente ?? 'CONSUMIDOR FINAL'),
                  _buildResumenItem('Forma de pago', _formatearFormaPago(medioPago)),
                  if (descuento > 0) _buildResumenItem('Descuento', '-\$${descuento.toStringAsFixed(0)}'),
                  if (propina > 0) _buildResumenItem('Propina', '+\$${propina.toStringAsFixed(0)}'),
                  Divider(color: AppTheme.textSecondary.withOpacity(0.3)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL PAGADO',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
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
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
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
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cerrar sin imprimir',
              style: TextStyle(color: AppTheme.textSecondary),
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
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          Text(
            valor,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
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
          backgroundColor: AppTheme.cardBg,
          content: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(width: 16),
              Text('Generando PDF...', style: TextStyle(color: AppTheme.textPrimary)),
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
      final resumen = _prepararResumenFactura(pedido, medioPago, totalPagado, descuento, propina, negocioInfo);

      Navigator.of(context).pop(); // Cerrar indicador de carga

      // Mostrar el PDF
      await _pdfService.mostrarVistaPrevia(resumen: resumen, esFactura: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF generado correctamente'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar indicador si está abierto
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          backgroundColor: AppTheme.cardBg,
          content: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(width: 16),
              Text('Preparando impresión...', style: TextStyle(color: AppTheme.textPrimary)),
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
      final resumen = _prepararResumenFactura(pedido, medioPago, totalPagado, descuento, propina, negocioInfo);

      Navigator.of(context).pop(); // Cerrar indicador de carga

      // Mostrar diálogo de impresión
      await _pdfService.mostrarDialogoImpresion(resumen: resumen, esFactura: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Factura enviada a impresión'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar indicador si está abierto
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al imprimir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Preparar resumen de factura para PDF/impresión
  Map<String, dynamic> _prepararResumenFactura(
    Pedido pedido,
    String medioPago,
    double totalPagado,
    double descuento,
    double propina,
    NegocioInfo? negocioInfo,
  ) {
    final now = DateTime.now();
    final fechaFormateada = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final horaFormateada = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return {
      // Información del negocio
      'nombreRestaurante': negocioInfo?.nombre ?? 'VERCY MOTOS',
      'nombreNegocio': negocioInfo?.nombre ?? 'VERCY MOTOS',
      'nit': negocioInfo?.nit ?? '',
      'direccionRestaurante': negocioInfo?.direccion ?? '',
      'telefonoRestaurante': negocioInfo?.telefono ?? '',
      'email': negocioInfo?.email ?? '',
      'ciudad': negocioInfo?.ciudad ?? '',
      'departamento': negocioInfo?.departamento ?? '',

      // Información de la factura
      'pedidoId': pedido.id,
      'numero': pedido.id,
      'tipoDocumento': 'FACTURA POS',
      'fecha': fechaFormateada,
      'hora': horaFormateada,
      'fechaVencimiento': pedido.fechaVencimiento != null
          ? '${pedido.fechaVencimiento!.year}-${pedido.fechaVencimiento!.month.toString().padLeft(2, '0')}-${pedido.fechaVencimiento!.day.toString().padLeft(2, '0')}'
          : fechaFormateada,

      // Información del cliente
      'cliente': pedido.cliente ?? 'CONSUMIDOR FINAL',
      'clienteNit': '222222222-2', // Default para consumidor final
      'clienteDireccion': '',
      'clienteTelefono': '',

      // Información del vendedor
      'mesero': pedido.mesero ?? 'Sistema',
      'vendedor': pedido.mesero ?? 'Sistema',

      // Productos
      'productos': pedido.items.map((item) => {
        'codigo': item.productoId,
        'nombre': item.productoNombre,
        'producto': item.productoNombre,
        'cantidad': item.cantidad,
        'precio': item.precioUnitario,
        'precioUnitario': item.precioUnitario,
        'subtotal': item.subtotal,
        'iva': 0,
        'descuento': 0,
      }).toList(),

      // Totales
      'subtotal': pedido.subtotal,
      'totalSinIva': pedido.total,
      'totalIva': 0.0,
      'impuestos': 0.0,
      'descuento': descuento,
      'propina': propina,
      'total': totalPagado,
      'totalFactura': totalPagado,

      // Forma de pago
      'medioPago': medioPago,
      'formaPago': _formatearFormaPago(medioPago),

      // Cantidades
      'cantidadArticulos': pedido.items.fold(0, (sum, item) => sum + item.cantidad),
      'cantidadProductos': pedido.items.length,

      // Tipo
      'tipoContado': 'CONTADO',
    };
  }

  // Limpiar formulario después de guardar
  void _limpiarFormulario() {
    setState(() {
      _items.clear();
      _clienteController.text = 'CONSUMIDOR FINAL';
      _fechaFactura = DateTime.now();
      _fechaVencimiento = DateTime.now().add(Duration(days: 30));
      _metodoPago = 'efectivo';
      _montoEfectivoController.text = '0';
      _montoTransferenciaController.text = '0';
      _productoSeleccionado = null;
      _limpiarFormularioProducto();
    });
  }

  Future<void> _guardarFactura() async {
    // Este método ahora solo se usa para compatibilidad
    // La lógica principal está en _guardarYPagar y _guardarComoBorrador
    await _guardarYPagar();
  }
}
