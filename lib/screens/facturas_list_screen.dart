import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '../models/cliente.dart';
import '../models/factura.dart';
import '../models/pedido.dart';
import '../models/item_pedido.dart';
import '../models/negocio_info.dart';
import '../providers/datos_cache_provider.dart';
import '../services/cliente_service.dart';
import '../services/factura_service.dart';
import '../services/pedido_service.dart';
import '../services/pdf_service.dart';
import '../services/negocio_info_service.dart';
import '../services/matias_service.dart';
import '../theme/app_theme.dart';
import '../utils/logger.dart';
import '../utils/pagination_mixin.dart';
import '../widgets/common/screen_header.dart';

class FacturasListScreen extends StatefulWidget {
  final String? filtroInicial;
  const FacturasListScreen({super.key, this.filtroInicial});

  @override
  _FacturasListScreenState createState() => _FacturasListScreenState();
}

class _FacturasListScreenState extends State<FacturasListScreen> with PaginacionMixin<FacturasListScreen> {
  final FacturaService _facturaService = FacturaService();
  final PedidoService _pedidoService = PedidoService();
  final PDFService _pdfService = PDFService();
  final NegocioInfoService _negocioInfoService = NegocioInfoService();
  final ClienteService _clienteService = ClienteService();

  final TextEditingController _filtroNumeroController = TextEditingController();
  final TextEditingController _filtroClienteController = TextEditingController();
  final TextEditingController _filtroOrdenController = TextEditingController();

  List<Factura> _facturas = [];
  List<Pedido> _pedidosPagados = [];
  List<dynamic> _documentosFiltrados = []; // Puede ser Factura o Pedido
  bool _isLoading = false;

  // Contador de documentos consumidos en Matias (-1 = no cargado / error)
  int _cantidadDocumentosMatias = -1;
  bool _cargandoCantidadMatias = false;

  // Filtros
  String _filtroTipo = ''; // 🔥 Mostrar TODOS los documentos por defecto
  String _filtroNumero = '';
  String _filtroCliente = '';
  String _filtroOrden = '';

  @override
  void initState() {
    super.initState();
    // Si viene con filtro desde informes, pre-aplicarlo
    if (widget.filtroInicial != null && widget.filtroInicial!.isNotEmpty) {
      _filtroNumero = widget.filtroInicial!;
      _filtroNumeroController.text = _filtroNumero;
    }
    _cargarDocumentos();
    _cargarCantidadMatias();
  }

  Future<void> _cargarCantidadMatias() async {
    if (!mounted) return;
    setState(() => _cargandoCantidadMatias = true);
    try {
      final total = await MatiasService.obtenerCantidadDocumentos();
      if (!mounted) return;
      setState(() {
        _cantidadDocumentosMatias = total;
        _cargandoCantidadMatias = false;
      });
    } catch (e) {
      appLog('❌ _cargarCantidadMatias: $e');
      if (mounted) setState(() => _cargandoCantidadMatias = false);
    }
  }

  @override
  void dispose() {
    _filtroNumeroController.dispose();
    _filtroClienteController.dispose();
    _filtroOrdenController.dispose();
    super.dispose();
  }

  Future<void> _cargarDocumentos() async {
    setState(() => _isLoading = true);
    try {
      // Cargar facturas tradicionales
      final facturas = await _facturaService.getFacturas();
      appLog('📄 Facturas cargadas: ${facturas.length}');
      
      // ⚡ Obtener TODOS los pedidos pagados (sin filtrar por fecha)
      List<Pedido> pedidosPagados = [];

      try {
        // Intentar primero con el endpoint más completo
        pedidosPagados = await _pedidoService.getTodosDocumentosPagados();
        appLog(
          '📋 Documentos pagados (endpoint completo): ${pedidosPagados.length}',
        );
      } catch (e) {
        appLog('⚠️ Error con getTodosDocumentosPagados, usando fallback: $e');
        // Fallback: obtener por estado (no filtra por fecha)
        pedidosPagados = await _pedidoService.getPedidosByEstado(
          EstadoPedido.pagado,
        );
        appLog(
          '💳 Pedidos pagados (fallback por estado): ${pedidosPagados.length}',
        );
      }

      // 🔥 Mostrar TODOS los pedidos pagados, sin filtrar por tipoFactura ni mesa ni fecha
      final pedidosFacturacion = pedidosPagados;

      appLog('🎯 Pedidos pagados para tabla: ${pedidosFacturacion.length}');

      // Debug: mostrar algunos IDs de pedidos para verificar
      if (pedidosFacturacion.isNotEmpty) {
        appLog(
          '📝 Primeros 5 IDs: ${pedidosFacturacion.take(5).map((p) => p.id).join(", ")}',
        );
      }

      // Ordenar por fecha descendente
      pedidosFacturacion.sort((a, b) {
        final fechaA = a.fechaPago ?? a.fecha;
        final fechaB = b.fechaPago ?? b.fecha;
        return fechaB.compareTo(fechaA);
      });
      
      setState(() {
        _facturas = facturas;
        _pedidosPagados = pedidosFacturacion;
        _aplicarFiltros();
      });
    } catch (e) {
      appLog('❌ Error cargando documentos: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar documentos: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    List<dynamic> documentos = [];

    // Agregar facturas filtradas
    for (var factura in _facturas) {
      if (_filtroTipo.isNotEmpty && factura.numero != null) {
        if (!factura.numero!.toUpperCase().startsWith(_filtroTipo)) {
          continue;
        }
      }
      if (_filtroNumero.isNotEmpty && factura.numero != null) {
        if (!factura.numero!.toLowerCase().contains(
          _filtroNumero.toLowerCase(),
        )) {
          continue;
        }
      }
      if (_filtroCliente.isNotEmpty) {
        if (!factura.clienteNombre.toLowerCase().contains(
          _filtroCliente.toLowerCase(),
        )) {
          continue;
        }
      }
      documentos.add(factura);
    }
    
    appLog(
      '🔍 Filtros actuales - Tipo: "$_filtroTipo", Número: "$_filtroNumero", Cliente: "$_filtroCliente"',
    );
    
    // Agregar pedidos pagados filtrados (POS, FE, o todos)
    if (_filtroTipo.isEmpty || _filtroTipo == 'POS' || _filtroTipo == 'FE') {
      for (var pedido in _pedidosPagados) {
        final esFEPedido = pedido.tipoFactura == 'FACTURA';
        if (_filtroTipo == 'POS' && esFEPedido) continue;
        if (_filtroTipo == 'FE' && !esFEPedido) continue;
        if (_filtroNumero.isNotEmpty) {
          if (!pedido.id.toLowerCase().contains(_filtroNumero.toLowerCase())) {
            continue;
          }
        }
        if (_filtroCliente.isNotEmpty) {
          final cliente = pedido.cliente ?? 'CONSUMIDOR FINAL';
          if (!cliente.toLowerCase().contains(_filtroCliente.toLowerCase())) {
            continue;
          }
        }
        documentos.add(pedido);
      }
    }

    appLog('📋 Documentos finales después de filtros: ${documentos.length}');

    // Ordenar por fecha descendente
    documentos.sort((a, b) {
      DateTime fechaA;
      DateTime fechaB;

      if (a is Factura) {
        fechaA = a.fechaCreacion ?? DateTime(1970);
      } else if (a is Pedido) {
        fechaA = a.fechaPago ?? a.fecha;
      } else {
        fechaA = DateTime(1970);
      }

      if (b is Factura) {
        fechaB = b.fechaCreacion ?? DateTime(1970);
      } else if (b is Pedido) {
        fechaB = b.fechaPago ?? b.fecha;
      } else {
        fechaB = DateTime(1970);
      }

      return fechaB.compareTo(fechaA);
    });

    setState(() {
      _documentosFiltrados = documentos;
    });

    appLog(
      '✅ _documentosFiltrados actualizado con ${_documentosFiltrados.length} elementos',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          _buildFiltros(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _buildTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ScreenHeader(
      icon: Icons.description,
      title: 'Lista documentos',
      actions: [
        _buildContadorMatiasChip(),
        ScreenHeaderAction.primary(
          icon: Icons.refresh,
          label: 'Actualizar',
          mobileLabel: 'Actualizar',
          onPressed: () async {
            await _cargarDocumentos();
            await _cargarCantidadMatias();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lista actualizada'),
                backgroundColor: AppTheme.success,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        ScreenHeaderAction.warning(
          icon: Icons.clear,
          label: 'Limpiar filtros',
          mobileLabel: 'Limpiar',
          onPressed: () {
            setState(() {
              _filtroTipo = '';
              _filtroNumero = '';
              _filtroCliente = '';
              _aplicarFiltros();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Filtros limpiados'),
                backgroundColor: AppTheme.success,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildContadorMatiasChip() {
    Widget contenido;
    if (_cargandoCantidadMatias) {
      contenido = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else if (_cantidadDocumentosMatias < 0) {
      contenido = Icon(Icons.error_outline, color: Colors.white, size: 16);
    } else {
      contenido = Text(
        '$_cantidadDocumentosMatias',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    }

    return Tooltip(
      message: _cantidadDocumentosMatias < 0
          ? 'No se pudo consultar Matias'
          : 'Documentos usados en Matias',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _cargandoCantidadMatias ? null : _cargarCantidadMatias,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.secondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Matias:',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 6),
              contenido,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: EdgeInsets.all(24),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          // Filtro por tipo
          Container(
            width: 120,
            child: DropdownButtonFormField<String>(
              value: _filtroTipo,
              decoration: InputDecoration(
                labelText: 'Tipo',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              items: [
                DropdownMenuItem(value: 'POS', child: Text('POS')),
                DropdownMenuItem(value: 'FE', child: Text('FE')),
                DropdownMenuItem(value: '', child: Text('Todos')),
              ],
              onChanged: (value) {
                setState(() {
                  _filtroTipo = value ?? '';
                  _aplicarFiltros();
                });
              },
            ),
          ),
          SizedBox(width: 16),

          // Filtro por número
          Expanded(
            child: TextField(
              controller: _filtroNumeroController,
              decoration: InputDecoration(
                labelText: 'N. Pos',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              onChanged: (value) {
                setState(() {
                  _filtroNumero = value;
                  _aplicarFiltros();
                });
              },
            ),
          ),
          SizedBox(width: 16),

          // Filtro por cliente
          Expanded(
            child: TextField(
              controller: _filtroClienteController,
              decoration: InputDecoration(
                labelText: 'Nombre cliente',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              onChanged: (value) {
                setState(() {
                  _filtroCliente = value;
                  _aplicarFiltros();
                });
              },
            ),
          ),
          SizedBox(width: 16),

          // Filtro por orden
          Expanded(
            child: TextField(
              controller: _filtroOrdenController,
              decoration: InputDecoration(
                labelText: 'Orden',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              onChanged: (value) {
                setState(() {
                  _filtroOrden = value;
                });
              },
            ),
          ),
          SizedBox(width: 16),

          // Botón otros
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'exportar_csv') {
                _exportarCSV();
              } else if (value == 'limpiar_filtros') {
                setState(() {
                  _filtroNumeroController.clear();
                  _filtroClienteController.clear();
                  _filtroOrdenController.clear();
                  
                  _filtroNumero = '';
                  _filtroCliente = '';
                  _filtroOrden = '';
                  _filtroTipo = '';
                });
                _cargarDocumentos(); // Recargar si es necesario o _aplicarFiltros()
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'exportar_csv', child: Row(children: [Icon(Icons.download, size: 18, color: Theme.of(context).colorScheme.onSurface), SizedBox(width: 8), Text('Exportar CSV', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))])),
              PopupMenuItem(value: 'limpiar_filtros', child: Row(children: [Icon(Icons.clear_all, size: 18, color: Theme.of(context).colorScheme.onSurface), SizedBox(width: 8), Text('Limpiar filtros', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))])),
            ],
            color: Theme.of(context).colorScheme.surface,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [Text('Otros', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)), SizedBox(width: 4), Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurface)]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_documentosFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay documentos para mostrar',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    final isMobile = context.isMobile;
    const double minTableWidth = 1150;
    return Container(
      margin: EdgeInsets.all(isMobile ? 4 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final available = constraints.maxWidth;
        final needScroll = available < minTableWidth;
        final tableContent = SizedBox(
          width: needScroll ? minTableWidth : available,
          child: _buildTableContent(),
        );
        return needScroll
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: tableContent,
              )
            : tableContent;
      }),
    );
  }

  Widget _buildTableContent() {
    return Column(
        children: [
          // Encabezado de la tabla
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'N. Factura',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Cliente',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Expedición',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Abono',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Saldo',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Estado',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 8,
                  child: Text(
                    'Acciones',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Filas de la tabla
          Expanded(
            child: _documentosFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay documentos registrados',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: paginarLista(_documentosFiltrados).length,
                          itemBuilder: (context, index) {
                            final documento = paginarLista(_documentosFiltrados)[index];
                            try {
                              return _buildTableRow(documento, index);
                            } catch (e) {
                              appLog('❌ Error renderizando fila $index: $e');
                              return Container();
                            }
                          },
                        ),
                      ),
                      buildPaginacion(
                        totalItems: _documentosFiltrados.length,
                        accentColor: AppTheme.primary,
                      ),
                    ],
                  ),
          ),
        ],
      );
  }

  Widget _buildTableRow(dynamic documento, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surface;
    
    // Extraer datos según el tipo de documento
    String numero;
    String clienteNombre;
    DateTime? fecha;
    double total;
    double abono;
    double saldo;
    bool isPagado;
    bool esPedido = documento is Pedido;
    bool esFEDoc = false;

    if (documento is Factura) {
      numero = documento.numero ?? 'N/A';
      clienteNombre = documento.clienteNombre;
      fecha = documento.fechaCreacion;
      total = documento.total;
      isPagado = documento.estadoPago == 'PAGADO';
      abono = isPagado ? total : 0;
      saldo = isPagado ? 0 : total - (documento.descuento ?? 0);
    } else if (documento is Pedido) {
      final safeId = documento.id.length >= 8
          ? documento.id.substring(0, 8).toUpperCase()
          : documento.id.toUpperCase();
      esFEDoc = documento.tipoFactura == 'FACTURA';
      numero = esFEDoc ? 'FE-$safeId' : 'POS-$safeId';
      clienteNombre = documento.cliente ?? 'CONSUMIDOR FINAL';
      fecha = documento.fechaPago ?? documento.fecha;
      total = documento.total;
      isPagado = documento.estado == EstadoPedido.pagado;
      abono = total;
      saldo = 0;
    } else {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Número de factura
          Expanded(
            flex: 2,
            child: Row(
              children: [
                if (esPedido) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    margin: EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: (esFEDoc ? AppTheme.success : AppTheme.primary).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      esFEDoc ? 'FE' : 'POS',
                      style: TextStyle(
                        color: esFEDoc ? AppTheme.success : AppTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    numero,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Cliente
          Expanded(
            flex: 3,
            child: Text(
              clienteNombre,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Fecha de expedición
          Expanded(
            flex: 2,
            child: Text(
              fecha != null
                  ? '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}'
                  : 'N/A',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
            ),
          ),

          // Total
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${total.toStringAsFixed(0)}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Abono
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${abono.toStringAsFixed(0)}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Saldo
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${saldo.toStringAsFixed(0)}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Estado
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPagado
                    ? AppTheme.success.withValues(alpha:0.2)
                    : AppTheme.warning.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPagado ? Icons.check : Icons.pending,
                    color: isPagado ? AppTheme.success : AppTheme.warning,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    isPagado ? 'PAGADO' : 'PENDIENTE',
                    style: TextStyle(
                      color: isPagado ? AppTheme.success : AppTheme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Acciones
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  icon: Icon(Icons.picture_as_pdf, color: Colors.red.shade400, size: 18),
                  onPressed: () => _verPDF(documento),
                  tooltip: 'Ver PDF',
                ),
                IconButton(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  icon: Icon(Icons.print, color: AppTheme.primary, size: 18),
                  onPressed: () => _imprimirDocumento(documento),
                  tooltip: 'Imprimir',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Buscar el cliente completo desde la API por nombre o documento
  Future<Cliente?> _buscarClienteCompleto(
    String? nombreCliente, {
    String? nit,
  }) async {
    if (nombreCliente == null ||
        nombreCliente.isEmpty ||
        nombreCliente == 'CONSUMIDOR FINAL') {
      return null;
    }
    try {
      appLog('🔍 Buscando cliente: "$nombreCliente" | NIT: "$nit"');

      // 1) Intentar buscar por NIT/documento si está disponible
      if (nit != null && nit.isNotEmpty && nit != '222222222-2') {
        String docLimpio = nit
            .replaceAll(RegExp(r'^(CC|NIT|CE|TI|Pasaporte)\s*'), '')
            .trim();
        if (docLimpio.contains('-')) {
          docLimpio = docLimpio.split('-').first.trim();
        }
        appLog('📋 Buscando por documento: "$docLimpio"');
        final clientePorDoc = await _clienteService.obtenerClientePorDocumento(
          docLimpio,
        );
        if (clientePorDoc != null) {
          appLog(
            '✅ Cliente encontrado por documento: ${clientePorDoc.nombreCompleto}',
          );
          return clientePorDoc;
        }
        appLog('⚠️ No se encontró cliente por documento');
      }

      // 2) Buscar por nombre completo
      final nombreLimpio = nombreCliente.trim().replaceAll(RegExp(r'\s+'), ' ');
      appLog('📝 Buscando por nombre: "$nombreLimpio"');
      var resultados = await _clienteService.buscarClientes(nombreLimpio);
      appLog('📊 Resultados encontrados: ${resultados.length}');
      if (resultados.isNotEmpty) {
        // Buscar coincidencia exacta primero
        final exacto = resultados.where(
          (c) => c.nombreCompleto.toLowerCase() == nombreLimpio.toLowerCase(),
        );
        if (exacto.isNotEmpty) {
          appLog(
            '✅ Cliente encontrado (coincidencia exacta): ${exacto.first.nombreCompleto}',
          );
          return exacto.first;
        }
        appLog(
          '✅ Cliente encontrado (primer resultado): ${resultados.first.nombreCompleto}',
        );
        return resultados.first;
      }

      // 3) Si no encontró, buscar por partes del nombre (primer palabra)
      final partes = nombreLimpio.split(' ');
      if (partes.length > 1) {
        appLog(
          '🔄 Intentando búsqueda por partes del nombre: "${partes.first}"',
        );
        // Intentar con el primer nombre
        resultados = await _clienteService.buscarClientes(partes.first);
        appLog('📊 Resultados por primer nombre: ${resultados.length}');
        if (resultados.isNotEmpty) {
          // Buscar el que mejor coincida con el nombre completo
          final coincidencia = resultados.where(
            (c) => c.nombreCompleto.toLowerCase() == nombreLimpio.toLowerCase(),
          );
          if (coincidencia.isNotEmpty) {
            appLog(
              '✅ Cliente encontrado (coincidencia exacta en búsqueda parcial): ${coincidencia.first.nombreCompleto}',
            );
            return coincidencia.first;
          }
          // Si no hay exacta, buscar que contenga el nombre
          final parcial = resultados.where(
            (c) =>
                c.nombreCompleto.toLowerCase().contains(
                  partes.first.toLowerCase(),
                ) &&
                c.nombreCompleto.toLowerCase().contains(
                  partes.last.toLowerCase(),
                ),
          );
          if (parcial.isNotEmpty) {
            appLog(
              '✅ Cliente encontrado (coincidencia parcial): ${parcial.first.nombreCompleto}',
            );
            return parcial.first;
          }
        }
      }

      appLog('❌ No se encontró el cliente: "$nombreCliente"');
    } catch (e) {
      appLog('⚠️ Error buscando cliente completo: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> _crearResumenDocumento(dynamic documento) async {
    // Mapa productoId → código interno para mostrar en PDF
    final codigoPorId = <String, String>{};
    try {
      final cache = Provider.of<DatosCacheProvider>(context, listen: false);
      for (final p in cache.productos ?? []) {
        if (p.codigo != null && p.codigo!.isNotEmpty) {
          codigoPorId[p.id] = p.codigo!;
        }
      }
    } catch (_) {}

    // Intentar obtener info del negocio, pero no fallar si no existe
    NegocioInfo? negocioInfo;
    try {
      negocioInfo = await _negocioInfoService.getNegocioInfo();
    } catch (e) {
      appLog('⚠️ No se pudo obtener info del negocio: $e');
      // Continuar sin negocioInfo, usar valores por defecto
    }

    // Helper para formatear fecha (formato YYYY-MM-DD)
    String formatearFecha(DateTime? fecha) {
      if (fecha == null) return '';
      return '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    }

    String formatearHora(DateTime? fecha) {
      if (fecha == null) return '';
      return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}:${fecha.second.toString().padLeft(2, '0')}';
    }

    Map<String, dynamic> resumen;

    if (documento is Pedido) {
      final fechaDoc = documento.fechaPago ?? documento.fecha;

      // Buscar datos completos del cliente SOLO si no están guardados en datosAdicionales
      Cliente? clienteCompleto;
      final datosGuardados = documento.datosAdicionales;

      appLog('📋 DEBUG - Datos guardados en pedido: $datosGuardados');
      appLog('📋 DEBUG - Cliente en pedido: ${documento.cliente}');

      if (datosGuardados == null ||
          datosGuardados['clienteDepartamento'] == null ||
          datosGuardados['clienteCiudad'] == null) {
        appLog('⚠️ Datos incompletos, buscando cliente en API...');
        clienteCompleto = await _buscarClienteCompleto(documento.cliente);
      } else {
        appLog('✅ Usando datos guardados del cliente');
      }

      resumen = {
        // Datos del negocio
        'nombreNegocio': negocioInfo?.nombre ?? 'VERCY MOTOS',
        'nombreRestaurante': negocioInfo?.nombre ?? 'VERCY MOTOS',
        'nit': negocioInfo?.nit ?? '',
        'email': negocioInfo?.email ?? '',
        'telefonoRestaurante': negocioInfo?.telefono ?? '',
        'direccionRestaurante': negocioInfo?.direccion ?? '',
        'ciudad': negocioInfo?.ciudad ?? 'MANIZALES',
        'departamento': negocioInfo?.departamento ?? 'CALDAS',
        // Datos del documento
        'numeroPedido': documento.id.toString(),
        'numero': documento.id.toString(),
        'fecha': formatearFecha(fechaDoc),
        'hora': formatearHora(fechaDoc),
        'fechaVencimiento': formatearFecha(fechaDoc),
        'cliente':
            datosGuardados?['clienteNombreCompleto'] ??
            documento.cliente ??
            'CONSUMIDOR FINAL',
        'clienteNit':
            datosGuardados?['clienteNit'] ??
            (clienteCompleto != null
                ? '${clienteCompleto.tipoIdentificacion} ${clienteCompleto.numeroIdentificacion}${clienteCompleto.digitoVerificacion != null ? "-${clienteCompleto.digitoVerificacion}" : ""}'
                : ''),
        'clienteDireccion':
            datosGuardados?['clienteDireccion'] ??
            clienteCompleto?.direccion ??
            '',
        'clienteTelefono':
            datosGuardados?['clienteTelefono'] ??
            clienteCompleto?.telefono ??
            '',
        'clienteCorreo':
            datosGuardados?['clienteCorreo'] ?? clienteCompleto?.correo ?? '',
        'clienteDepartamento':
            datosGuardados?['clienteDepartamento'] ??
            clienteCompleto?.departamento ??
            '',
        'clienteCiudad':
            datosGuardados?['clienteCiudad'] ?? clienteCompleto?.ciudad ?? '',
        'clienteTipoId':
            datosGuardados?['clienteTipoId'] ??
            clienteCompleto?.tipoIdentificacion ??
            'CC',
        'productos': documento.items
            .map(
              (item) => {
                'codigo': codigoPorId[item.productoId] ?? '',
                'nombre': item.productoNombre,
                'cantidad': item.cantidad,
                'precio': item.precioUnitario,
                'precioUnitario': item.precioUnitario,
                'subtotal': item.cantidad * item.precioUnitario,
                'iva': item.porcentajeImpuesto,
                'valorIva': item.valorImpuesto,
                'descuento': item.porcentajeDescuento,
                'valorDescuento': item.valorDescuento,
              },
            )
            .toList(),
        // ✅ Calcular totales desde los ítems reales, no desde documento.total.
        // Tipado explícito porque en web dart2js a veces pierde la inferencia
        // del fold<double> y falla en runtime con TypeError.
        'subtotal': documento.subtotal > 0
            ? documento.subtotal
            : documento.items.fold<double>(
                0.0,
                (double sum, ItemPedido item) =>
                    sum + (item.cantidad * item.precioUnitario).toDouble(),
              ),
        'iva': documento.totalImpuestos,
        'descuento': documento.totalDescuentos > 0
            ? documento.totalDescuentos
            : documento.descuento,
        'descuentoGeneral': documento.descuentoGeneral,
        'total': documento.totalFinal > 0
            ? documento.totalFinal
            : (documento.total > 0
                  ? documento.total
                  : documento.items.fold<double>(
                      0.0,
                      (double sum, ItemPedido item) =>
                          sum + (item.cantidad * item.precioUnitario).toDouble(),
                    )),
        // 💰 Retenciones
        'retencion': documento.valorRetencion,
        'retencionPct': documento.retencion,
        'reteIVA': documento.valorReteIVA,
        'reteIVAPct': documento.reteIVA,
        'reteICA': documento.valorReteICA,
        'reteICAPct': documento.reteICA,
        // 📊 Conteos
        'cantidadArticulos': documento.items.length,
        'cantidadProductos': documento.items.length,
        'metodoPago': documento.formaPago ?? 'EFECTIVO',
        'formaPago': _formatearFormaPagoPdf(documento.formaPago ?? 'EFECTIVO'),
        'vendedor': documento.mesero,
        'mesero': documento.mesero,
        // Desglose de pagos mixtos
        if (documento.pagosParciales.isNotEmpty)
          'pagosParciales': documento.pagosParciales
              .map(
                (p) => {
                  'formaPago': _formatearFormaPagoPdf(p.formaPago),
                  'monto': p.monto,
                },
              )
              .toList(),
      };
    } else if (documento is Factura) {
      final subtotalCalc = documento.subtotal;
      final ivaCalc = documento.total - documento.subtotal;
      final fechaDoc = documento.fechaCreacion ?? DateTime.now();

      // Buscar datos completos del cliente SOLO si no están guardados en la factura
      Cliente? clienteCompleto;
      if (documento.clienteDepartamento == null ||
          documento.clienteCiudad == null ||
          documento.clienteCorreo == null) {
        clienteCompleto = await _buscarClienteCompleto(
          documento.clienteNombre.isNotEmpty ? documento.clienteNombre : null,
          nit: documento.clienteNit,
        );
      }

      resumen = {
        // Datos del negocio
        'nombreNegocio': negocioInfo?.nombre ?? 'VERCY MOTOS',
        'nombreRestaurante': negocioInfo?.nombre ?? 'VERCY MOTOS',
        'nit': negocioInfo?.nit ?? '',
        'email': negocioInfo?.email ?? '',
        'telefonoRestaurante': negocioInfo?.telefono ?? '',
        'direccionRestaurante': negocioInfo?.direccion ?? '',
        'ciudad': negocioInfo?.ciudad ?? 'MANIZALES',
        'departamento': negocioInfo?.departamento ?? 'CALDAS',
        // Datos del documento
        'numeroPedido': documento.numero ?? documento.id?.toString() ?? '',
        'numero': documento.numero ?? documento.id?.toString() ?? '',
        'fecha': formatearFecha(fechaDoc),
        'hora': formatearHora(fechaDoc),
        'fechaVencimiento': formatearFecha(fechaDoc),
        'cliente': documento.clienteNombre.isNotEmpty
            ? documento.clienteNombre
            : 'CONSUMIDOR FINAL',
        'clienteNit':
            documento.clienteNit ??
            (clienteCompleto != null
                ? '${clienteCompleto.tipoIdentificacion} ${clienteCompleto.numeroIdentificacion}${clienteCompleto.digitoVerificacion != null ? "-${clienteCompleto.digitoVerificacion}" : ""}'
                : ''),
        'clienteDireccion':
            documento.clienteDireccion ?? clienteCompleto?.direccion ?? '',
        'clienteTelefono':
            documento.clienteTelefono ?? clienteCompleto?.telefono ?? '',
        'clienteCorreo':
            documento.clienteCorreo ?? clienteCompleto?.correo ?? '',
        'clienteDepartamento':
            documento.clienteDepartamento ??
            clienteCompleto?.departamento ??
            '',
        'clienteCiudad':
            documento.clienteCiudad ?? clienteCompleto?.ciudad ?? '',
        'clienteTipoId': clienteCompleto?.tipoIdentificacion ?? 'CC',
        'productos':
            documento.items
                ?.map(
                  (item) => {
                    'codigo': codigoPorId[item.productoId] ?? '',
                    'nombre': item.productoNombre,
                    'cantidad': item.cantidad,
                    'precio': item.precioUnitario,
                    'precioUnitario': item.precioUnitario,
                    'subtotal': item.cantidad * item.precioUnitario,
                    'iva': item.porcentajeImpuesto,
                    'valorIva': item.valorImpuesto,
                    'descuento': item.porcentajeDescuento,
                    'valorDescuento': item.valorDescuento,
                  },
                )
                .toList() ??
            [],
        'subtotal': subtotalCalc,
        'iva': ivaCalc,
        'total': documento.total,
        'metodoPago': documento.metodoPago ?? 'EFECTIVO',
        'formaPago': _formatearFormaPagoPdf(documento.metodoPago ?? 'EFECTIVO'),
        'vendedor': 'Sin Vendedor',
        'mesero': 'Sin Vendedor',
      };
    } else {
      throw Exception('Tipo de documento no soportado');
    }

    return resumen;
  }

  Future<void> _verPDF(dynamic documento) async {
    try {
      final resumen = await _crearResumenDocumento(documento);
      await _mostrarPDFConNombrePersonalizado(
        resumen: resumen,
        esFactura: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _imprimirDocumento(dynamic documento) async {
    try {
      final resumen = await _crearResumenDocumento(documento);
      await _pdfService.imprimirFactura(resumen);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al imprimir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatearFormaPagoPdf(String formaPago) {
    switch (formaPago.toLowerCase()) {
      case 'efectivo':
        return 'Efectivo';
      case 'tarjeta':
        return 'Tarjeta';
      case 'transferencia':
        return 'Transferencia';
      case 'sistecredito':
        return 'Sistecredito';
      case 'datafono':
        return 'Datafono';
      case 'mixto':
        return 'Pago Mixto';
      case 'multiple':
        return 'Pago Múltiple';
      default:
        return formaPago;
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
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7), fontSize: 13),
            ),
            SizedBox(height: 12),
            TextField(
              controller: controladorNombre,
              autofocus: true,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Nombre del archivo',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixText: '.pdf',
                suffixStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7)),
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
  void _exportarCSV() {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Número,Cliente,Fecha,Total,Estado,Medio de Pago');
      for (final doc in _documentosFiltrados) {
        if (doc is Factura) {
          buffer.writeln(
            '\${doc.numero ?? ""},"\${doc.clienteNombre}",\${doc.fechaCreacion?.toIso8601String() ?? ""},\${doc.total},\${doc.estadoPago ?? ""},\${doc.medioPago ?? ""}',
          );
        }
      }
      final csv = buffer.toString();
      // En web: descargar como blob
      if (kIsWeb) {
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        (html.document.createElement('a') as html.AnchorElement)
          ..href = url
          ..download = 'facturas_\${DateTime.now().millisecondsSinceEpoch}.csv'
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV generado: \${_documentosFiltrados.length} registros')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: \$e'), backgroundColor: Colors.red),
      );
    }
  }

}