import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/factura_compra.dart';
import '../services/factura_compra_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../utils/snackbar_helper.dart';
import '../utils/dialogs_helper.dart';
import '../widgets/facturizacion/documento_soporte_dialog.dart';
import '../utils/api_error.dart';
import '../utils/submit_guard.dart';
class FacturasComprasScreen extends StatefulWidget {
  /// Inyectable solo para tests de secuencia (doble-tap, etc.) - en la app
  /// real siempre se usa el FacturaCompraService real.
  @visibleForTesting
  final FacturaCompraService? facturaCompraService;

  const FacturasComprasScreen({super.key, this.facturaCompraService});

  @override
  _FacturasComprasScreenState createState() => _FacturasComprasScreenState();
}

class _FacturasComprasScreenState extends State<FacturasComprasScreen> with SubmitGuard {
  late final FacturaCompraService _facturaCompraService =
      widget.facturaCompraService ?? FacturaCompraService();
  final TextEditingController _searchController = TextEditingController();

  List<FacturaCompra> _facturas = [];
  List<FacturaCompra> _facturasFiltradas = [];
  bool _isLoading = false;
  String _filtroEstado = 'TODOS';
  String? _filtroProveedor;
  String _filtroPagoCaja = 'TODOS'; // TODOS, PAGADAS_CAJA, NO_PAGADAS_CAJA

  // Variable para controlar el timeout del botón guardar factura
  bool _guardandoFactura = false;

  // Los Scrollbar de los filtros de Estado/Pago no traian su propio
  // ScrollController: sin uno compartido con su SingleChildScrollView,
  // intentaban usar el PrimaryScrollController (que no aplica a un scroll
  // horizontal sin controller explicito), y el Scrollbar quedaba sin
  // ScrollPosition a la que pintarse - un assert que flutter_test sí hace
  // fallar en cada frame.
  final ScrollController _filtroEstadoScrollController = ScrollController();
  final ScrollController _filtroPagoScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filtroEstadoScrollController.dispose();
    _filtroPagoScrollController.dispose();
    super.dispose();
  }

  // Método auxiliar para determinar si una factura debe considerarse como pagada
  bool _estaFacturaPagada(FacturaCompra factura) {
    return factura.estado.toUpperCase() == 'PAGADA' || factura.pagadoDesdeCaja;
  }

  // Método para obtener el estado real a mostrar para una factura
  String _obtenerEstadoVisual(FacturaCompra factura) {
    if (_estaFacturaPagada(factura)) {
      return 'PAGADA';
    }
    return factura.estado.toUpperCase();
  }

  Future<void> _cargarFacturas() async {
    setState(() => _isLoading = true);
    try {
      final facturas = await _facturaCompraService.getFacturasCompras();

      // Verificar las fechas de creación de las facturas
      for (var i = 0; i < facturas.length && i < 5; i++) {
        var factura = facturas[i];
      }

      setState(() {
        _facturas = facturas;
        _aplicarFiltros();
      });
    } catch (e) {
      showErrorSnackBar(context, 'Error al cargar facturas: ${errorMessage(e)}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _facturasFiltradas = _facturas.where((factura) {
        final cumpleBusqueda =
            _searchController.text.isEmpty ||
            factura.numeroFactura.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ) ||
            factura.proveedorNombre.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ) ||
            (factura.proveedorNit?.toLowerCase().contains(
                  _searchController.text.toLowerCase(),
                ) ??
                false);

        // Mejorar la lógica de filtrado por estado usando el método auxiliar
        bool cumpleEstado;
        if (_filtroEstado == 'TODOS') {
          cumpleEstado = true;
        } else if (_filtroEstado == 'PAGADA') {
          // Una factura se considera pagada si su estado es PAGADA o si pagadoDesdeCaja es true
          cumpleEstado = _estaFacturaPagada(factura);
        } else {
          // Para otros estados como PENDIENTE o CANCELADA, usar la comparación directa
          // Si la factura está pagada desde caja, no debe aparecer como pendiente
          if (_filtroEstado == 'PENDIENTE') {
            cumpleEstado =
                factura.estado == _filtroEstado && !_estaFacturaPagada(factura);
          } else {
            cumpleEstado = factura.estado == _filtroEstado;
          }
        }

        final cumpleProveedor =
            _filtroProveedor == null ||
            factura.proveedorNit == _filtroProveedor;

        final cumplePagoCaja =
            _filtroPagoCaja == 'TODOS' ||
            (_filtroPagoCaja == 'PAGADAS_CAJA' && factura.pagadoDesdeCaja) ||
            (_filtroPagoCaja == 'NO_PAGADAS_CAJA' && !factura.pagadoDesdeCaja);

        return cumpleBusqueda &&
            cumpleEstado &&
            cumpleProveedor &&
            cumplePagoCaja;
      }).toList();

      // Imprimir fechas antes de ordenar
      for (var i = 0; i < _facturasFiltradas.length && i < 5; i++) {
        final factura = _facturasFiltradas[i];
      }

      // Ordenar por fecha de creación primero, luego por fecha de factura si hay empate
      _facturasFiltradas.sort((a, b) {
        // Primero intentar ordenar por fechaCreacion
        final dateCompare = b.fechaCreacion.compareTo(a.fechaCreacion);

        // Si las fechas son iguales (posible para facturas creadas en el mismo momento)
        // usar la fecha de factura como criterio secundario
        if (dateCompare == 0) {
          return b.fechaFactura.compareTo(a.fechaFactura);
        }

        return dateCompare;
      });

      // Imprimir logs para debug después de ordenar
      for (var i = 0; i < _facturasFiltradas.length && i < 5; i++) {
        final factura = _facturasFiltradas[i];
        final fechaStr =
            "${factura.fechaCreacion.day}/${factura.fechaCreacion.month}/${factura.fechaCreacion.year} ${factura.fechaCreacion.hour}:${factura.fechaCreacion.minute}";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Facturas de Compras', style: AppTheme.headlineMedium),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () =>
              context.go('/dashboard'),
        ),
        actions: [
          context.isMobile
              ? IconButton(
                  icon: Icon(Icons.verified_outlined, color: AppTheme.secondary),
                  tooltip: 'Documento Soporte DIAN (compra a no obligado)',
                  onPressed: _abrirDocumentoSoporte,
                )
              : Tooltip(
                  message: 'Documento Soporte DIAN\n(compra a no obligado a facturar)',
                  child: TextButton.icon(
                    onPressed: _abrirDocumentoSoporte,
                    icon: Icon(Icons.verified_outlined, color: AppTheme.secondary, size: 18),
                    label: Text(
                      'Doc. Soporte',
                      style: TextStyle(color: AppTheme.secondary, fontSize: 12),
                    ),
                  ),
                ),
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _cargarFacturas,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _facturasFiltradas.isEmpty
                ? _buildEmptyState()
                : _buildListaFacturas(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () => _navegarACrearFactura(),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Buscar por número, proveedor...',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      onPressed: () {
                        _searchController.clear();
                        _aplicarFiltros();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.primary),
              ),
            ),
            onChanged: (value) => _aplicarFiltros(),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Text('Estado: ', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              SizedBox(width: 8),
              Expanded(
                child: Scrollbar(
                  controller: _filtroEstadoScrollController,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _filtroEstadoScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['TODOS', 'PENDIENTE', 'PAGADA', 'CANCELADA']
                          .map(
                            (estado) => Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(estado),
                                selected: _filtroEstado == estado,
                                onSelected: (selected) {
                                  setState(() {
                                    _filtroEstado = estado;
                                    _aplicarFiltros();
                                  });
                                },
                                selectedColor: AppTheme.primary.withOpacity(
                                  0.2,
                                ),
                                checkmarkColor: AppTheme.primary,
                                labelStyle: TextStyle(
                                  color: _filtroEstado == estado
                                      ? AppTheme.primary
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Text('Pago: ', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              SizedBox(width: 8),
              Expanded(
                child: Scrollbar(
                  controller: _filtroPagoScrollController,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _filtroPagoScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [
                                {'value': 'TODOS', 'label': 'Todos'},
                                {
                                  'value': 'PAGADAS_CAJA',
                                  'label': 'Desde caja',
                                },
                                {
                                  'value': 'NO_PAGADAS_CAJA',
                                  'label': 'Fuera de caja',
                                },
                              ]
                              .map(
                                (filtro) => Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(filtro['label']!),
                                    selected:
                                        _filtroPagoCaja == filtro['value'],
                                    onSelected: (selected) {
                                      setState(() {
                                        _filtroPagoCaja = filtro['value']!;
                                        _aplicarFiltros();
                                      });
                                    },
                                    selectedColor: Colors.blue.withOpacity(0.2),
                                    checkmarkColor: Colors.blue,
                                    labelStyle: TextStyle(
                                      color: _filtroPagoCaja == filtro['value']
                                          ? Colors.blue
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          SizedBox(height: 16),
          Text(
            'No hay facturas de compras',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Crea tu primera factura de compras',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navegarACrearFactura(),
            icon: Icon(Icons.add),
            label: Text('Crear Factura'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaFacturas() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _facturasFiltradas.length,
      itemBuilder: (context, index) {
        final factura = _facturasFiltradas[index];
        return Card(
          color: Theme.of(context).colorScheme.surface,
          margin: EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              InkWell(
                onTap: () => _mostrarDetalleFactura(factura),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icono a la izquierda
                      CircleAvatar(
                        backgroundColor: AppTheme.primary,
                        child: Icon(Icons.receipt, color: Colors.white),
                      ),
                      SizedBox(width: 12),

                      // Columna con información principal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              factura.numeroFactura,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              factura.proveedorNombre,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'NIT: ${factura.proveedorNit ?? 'No especificado'}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Mostrar fecha de creación en lugar de fecha de factura para facilitar la verificación del orden
                            Text(
                              'Creado: ${_formatearFechaConHora(factura.fechaCreacion)} - Factura: ${_formatearFecha(factura.fechaFactura)}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 12),

                      // Columna de estado y precio
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Si la factura está pagada desde caja, mostrar el indicador
                              if (_estaFacturaPagada(factura))
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet,
                                    size: 12,
                                    color: Colors.green,
                                  ),
                                ),
                              // Si está pagado desde caja, mostrar como PAGADA independientemente del estado
                              _buildEstadoChip(
                                factura.pagadoDesdeCaja
                                    ? 'PAGADA'
                                    : factura.estado,
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            CurrencyUtils.format(factura.total),
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Botones de acción
              Container(height: 1, color: Colors.grey.shade200),
              Row(
                children: [
                  // Botón Emitir DS
                  Expanded(
                    child: InkWell(
                      onTap: () => _abrirDocumentoSoporteParaFactura(factura),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_outlined,
                                size: 15, color: AppTheme.secondary),
                            SizedBox(width: 5),
                            Text(
                              'Doc. Soporte',
                              style: TextStyle(
                                  color: AppTheme.secondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 32, color: Colors.grey.shade200),
                  // Botón Eliminar
                  Expanded(
                    child: InkWell(
                      // runGuarded evita que un doble-tap (o doble-confirmacion
                      // en el dialogo) dispare dos veces revertirInventarioCompra
                      // para la misma factura - sin esto, el stock se devolvia
                      // dos veces aunque el segundo eliminarFacturaCompra fallara.
                      onTap: _isLoading
                          ? null
                          : () => runGuarded(
                              () => _confirmarEliminarFactura(factura),
                            ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete, size: 15, color: Colors.red),
                            SizedBox(width: 5),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red, fontSize: 12),
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
        );
      },
    );
  }

  Widget _buildEstadoChip(String estado) {
    Color color;
    switch (estado.toUpperCase()) {
      case 'PENDIENTE':
        color = Colors.orange;
        break;
      case 'PAGADA':
        color = Colors.green;
        break;
      case 'CANCELADA':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _navegarACrearFactura() {
    context.push('/facturas-compras').then((_) => _cargarFacturas());
  }

  /// Abre el diálogo de Documento Soporte sin datos pre-llenados (botón global)
  void _abrirDocumentoSoporte() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DocumentoSoporteDialog(),
    );
  }

  /// Abre el diálogo de Documento Soporte pasando la compra completa para auto-fill
  void _abrirDocumentoSoporteParaFactura(FacturaCompra factura) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DocumentoSoporteDialog(compra: factura),
    );
  }

  void _mostrarDetalleFactura(FacturaCompra factura) {
    context.push('/facturas-compras/detalle', extra: factura).then((_) => _cargarFacturas());
  }

  // Método para editar una factura
  void _editarFactura(FacturaCompra factura) {
    // Edición no implementada aún
    showInfoSnackBar(context, 'La edición de facturas no está disponible aún');
    /* 
    Para implementar cuando se agregue el parámetro facturaParaEditar en CrearFacturaCompraScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearFacturaCompraScreen(),
      ),
    ).then((_) => _cargarFacturas());
    */
  }

  // Método para confirmar la eliminación de una factura
  Future<void> _confirmarEliminarFactura(FacturaCompra factura) async {
    final motivoController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Eliminar Factura',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas eliminar la factura ${factura.numeroFactura}?\n\n'
                'Se revertirá el inventario asociado a esta compra.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
              SizedBox(height: 16),
              TextField(
                controller: motivoController,
                maxLines: 3,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Razón de la eliminación (opcional)',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  hintText: 'Ej: Factura duplicada, error de digitación...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(motivoController.text.trim());
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        // Revertir inventario ANTES de eliminar la factura
        await _facturaCompraService.revertirInventarioCompra(factura);

        final resultado = await _facturaCompraService.eliminarFacturaCompra(
          factura.id!,
          motivoEliminacion: result.isNotEmpty ? result : null,
        );

        if (resultado['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Factura eliminada correctamente. Stock revertido.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          await _cargarFacturas();
        } else {
          showErrorDialog(context, resultado['message'] ?? 'No se pudo eliminar la factura');
        }
      } catch (e) {
        showErrorSnackBar(context, 'Error al eliminar factura: ${errorMessage(e)}');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  // Nuevo método para formatear fecha con hora (formato 12h con AM/PM)
  String _formatearFechaConHora(DateTime fecha) {
    final hour24 = fecha.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} ${hour12.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')} $period';
  }
}
