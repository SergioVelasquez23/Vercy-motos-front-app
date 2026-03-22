import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/factura.dart';
import '../models/pedido.dart';
import '../models/negocio_info.dart';
import '../services/cliente_service.dart';
import '../services/factura_service.dart';
import '../services/pedido_service.dart';
import '../services/pdf_service.dart';
import '../services/negocio_info_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vercy_sidebar_layout.dart';
import '../widgets/facturizacion/facturizador_matias_button.dart';

class FacturasListScreen extends StatefulWidget {
  final String? filtroInicial;
  const FacturasListScreen({super.key, this.filtroInicial});

  @override
  _FacturasListScreenState createState() => _FacturasListScreenState();
}

class _FacturasListScreenState extends State<FacturasListScreen> {
  final FacturaService _facturaService = FacturaService();
  final PedidoService _pedidoService = PedidoService();
  final PDFService _pdfService = PDFService();
  final NegocioInfoService _negocioInfoService = NegocioInfoService();
  final ClienteService _clienteService = ClienteService();

  List<Factura> _facturas = [];
  List<Pedido> _pedidosPagados = [];
  List<dynamic> _documentosFiltrados = []; // Puede ser Factura o Pedido
  bool _isLoading = false;

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
    }
    _cargarDocumentos();
  }

  Future<void> _cargarDocumentos() async {
    setState(() => _isLoading = true);
    try {
      // Cargar facturas tradicionales
      final facturas = await _facturaService.getFacturas();
      print('📄 Facturas cargadas: ${facturas.length}');
      
      // ⚡ Obtener TODOS los pedidos pagados (sin filtrar por fecha)
      List<Pedido> pedidosPagados = [];

      try {
        // Intentar primero con el endpoint más completo
        pedidosPagados = await _pedidoService.getTodosDocumentosPagados();
        print(
          '📋 Documentos pagados (endpoint completo): ${pedidosPagados.length}',
        );
      } catch (e) {
        print('⚠️ Error con getTodosDocumentosPagados, usando fallback: $e');
        // Fallback: obtener por estado (no filtra por fecha)
        pedidosPagados = await _pedidoService.getPedidosByEstado(
          EstadoPedido.pagado,
        );
        print(
          '💳 Pedidos pagados (fallback por estado): ${pedidosPagados.length}',
        );
      }

      // 🔥 Mostrar TODOS los pedidos pagados, sin filtrar por tipoFactura ni mesa ni fecha
      final pedidosFacturacion = pedidosPagados;

      print('🎯 Pedidos pagados para tabla: ${pedidosFacturacion.length}');

      // Debug: mostrar algunos IDs de pedidos para verificar
      if (pedidosFacturacion.isNotEmpty) {
        print(
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
      print('❌ Error cargando documentos: $e');
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
    
    print(
      '🔍 Filtros actuales - Tipo: "$_filtroTipo", Número: "$_filtroNumero", Cliente: "$_filtroCliente"',
    );
    
    // Agregar pedidos pagados filtrados (solo para tipo POS o vacío)
    if (_filtroTipo.isEmpty || _filtroTipo == 'POS') {
      for (var pedido in _pedidosPagados) {
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

    print('📋 Documentos finales después de filtros: ${documentos.length}');

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

    print(
      '✅ _documentosFiltrados actualizado con ${_documentosFiltrados.length} elementos',
    );
  }

  @override
  Widget build(BuildContext context) {
    return VercySidebarLayout(
      title: 'Documentos',
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
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
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: AppTheme.primary, size: 32),
              SizedBox(width: 12),
              Text(
                'Lista documentos',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  await _cargarDocumentos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lista actualizada'),
                      backgroundColor: AppTheme.success,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  'Actualizar',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _filtroTipo = ''; // 🔥 Resetear a TODOS
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
                icon: Icon(Icons.clear, color: Colors.white),
                label: Text(
                  'Limpiar filtros',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: EdgeInsets.all(24),
      color: AppTheme.backgroundDark,
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
                fillColor: AppTheme.cardBg,
              ),
              dropdownColor: AppTheme.cardBg,
              style: TextStyle(color: AppTheme.textPrimary),
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
              decoration: InputDecoration(
                labelText: 'N. Pos',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: AppTheme.cardBg,
              ),
              style: TextStyle(color: AppTheme.textPrimary),
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
              decoration: InputDecoration(
                labelText: 'Nombre cliente',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: AppTheme.cardBg,
              ),
              style: TextStyle(color: AppTheme.textPrimary),
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
              decoration: InputDecoration(
                labelText: 'Orden',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: AppTheme.cardBg,
              ),
              style: TextStyle(color: AppTheme.textPrimary),
              onChanged: (value) {
                setState(() {
                  _filtroOrden = value;
                });
              },
            ),
          ),
          SizedBox(width: 16),

          // Botón otros
          ElevatedButton(
            onPressed: () {
              // TODO: Implementar opciones adicionales
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cardBg,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            child: Text('Otros', style: TextStyle(color: AppTheme.textPrimary)),
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

    return Container(
      margin: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Encabezado de la tabla
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'N. Factura',
                    style: TextStyle(
                      color: Colors.white,
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
                      color: Colors.white,
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
                      color: Colors.white,
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
                      color: Colors.white,
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
                      color: Colors.white,
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
                      color: Colors.white,
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
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 80), // Espacio para acciones
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
                : ListView.builder(
                    itemCount: _documentosFiltrados.length,
                    itemBuilder: (context, index) {
                      final documento = _documentosFiltrados[index];
                      try {
                        return _buildTableRow(documento, index);
                      } catch (e) {
                        print('❌ Error renderizando fila $index: $e');
                        return Container(); // Evitar que un error rompa toda la lista
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(dynamic documento, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? AppTheme.cardBg : AppTheme.surfaceDark;
    
    // Extraer datos según el tipo de documento
    String numero;
    String clienteNombre;
    DateTime? fecha;
    double total;
    double abono;
    double saldo;
    bool isPagado;
    bool esPedido = documento is Pedido;

    if (documento is Factura) {
      numero = documento.numero ?? 'N/A';
      clienteNombre = documento.clienteNombre;
      fecha = documento.fechaCreacion;
      total = documento.total;
      isPagado = documento.estadoPago == 'PAGADO';
      abono = isPagado ? total : 0;
      saldo = isPagado ? 0 : total - (documento.descuento ?? 0);
    } else if (documento is Pedido) {
      numero = 'POS-${documento.id.substring(0, 8).toUpperCase()}';
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                if (esPedido)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    margin: EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'POS',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    numero,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
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
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
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
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),

          // Total
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${total.toStringAsFixed(0)}',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Abono
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${abono.toStringAsFixed(0)}',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Saldo
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${saldo.toStringAsFixed(0)}',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
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
                    ? AppTheme.success.withOpacity(0.2)
                    : AppTheme.warning.withOpacity(0.2),
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
          SizedBox(
            width: 250,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Botón facturar (solo para pedidos pagados)
                if (esPedido && isPagado)
                  SizedBox(
                    height: 40,
                    child: FacturizarMatiasButton(
                      pedidoId: (documento as Pedido).id,
                      onSuccess: () {
                        _cargarDocumentos();
                      },
                    ),
                  ),
                SizedBox(width: 4),
                // Botón ver PDF
                IconButton(
                  icon: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  onPressed: () => _verPDF(documento),
                  tooltip: 'Ver PDF',
                ),
                // Botón imprimir
                IconButton(
                  icon: Icon(
                    Icons.print,
                    color: AppTheme.primary,
                    size: 20,
                  ),
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
      print('🔍 Buscando cliente: "$nombreCliente" | NIT: "$nit"');

      // 1) Intentar buscar por NIT/documento si está disponible
      if (nit != null && nit.isNotEmpty && nit != '222222222-2') {
        String docLimpio = nit
            .replaceAll(RegExp(r'^(CC|NIT|CE|TI|Pasaporte)\s*'), '')
            .trim();
        if (docLimpio.contains('-')) {
          docLimpio = docLimpio.split('-').first.trim();
        }
        print('📋 Buscando por documento: "$docLimpio"');
        final clientePorDoc = await _clienteService.obtenerClientePorDocumento(
          docLimpio,
        );
        if (clientePorDoc != null) {
          print(
            '✅ Cliente encontrado por documento: ${clientePorDoc.nombreCompleto}',
          );
          return clientePorDoc;
        }
        print('⚠️ No se encontró cliente por documento');
      }

      // 2) Buscar por nombre completo
      final nombreLimpio = nombreCliente.trim().replaceAll(RegExp(r'\s+'), ' ');
      print('📝 Buscando por nombre: "$nombreLimpio"');
      var resultados = await _clienteService.buscarClientes(nombreLimpio);
      print('📊 Resultados encontrados: ${resultados.length}');
      if (resultados.isNotEmpty) {
        // Buscar coincidencia exacta primero
        final exacto = resultados.where(
          (c) => c.nombreCompleto.toLowerCase() == nombreLimpio.toLowerCase(),
        );
        if (exacto.isNotEmpty) {
          print(
            '✅ Cliente encontrado (coincidencia exacta): ${exacto.first.nombreCompleto}',
          );
          return exacto.first;
        }
        print(
          '✅ Cliente encontrado (primer resultado): ${resultados.first.nombreCompleto}',
        );
        return resultados.first;
      }

      // 3) Si no encontró, buscar por partes del nombre (primer palabra)
      final partes = nombreLimpio.split(' ');
      if (partes.length > 1) {
        print(
          '🔄 Intentando búsqueda por partes del nombre: "${partes.first}"',
        );
        // Intentar con el primer nombre
        resultados = await _clienteService.buscarClientes(partes.first);
        print('📊 Resultados por primer nombre: ${resultados.length}');
        if (resultados.isNotEmpty) {
          // Buscar el que mejor coincida con el nombre completo
          final coincidencia = resultados.where(
            (c) => c.nombreCompleto.toLowerCase() == nombreLimpio.toLowerCase(),
          );
          if (coincidencia.isNotEmpty) {
            print(
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
            print(
              '✅ Cliente encontrado (coincidencia parcial): ${parcial.first.nombreCompleto}',
            );
            return parcial.first;
          }
        }
      }

      print('❌ No se encontró el cliente: "$nombreCliente"');
    } catch (e) {
      print('⚠️ Error buscando cliente completo: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> _crearResumenDocumento(dynamic documento) async {
    // Intentar obtener info del negocio, pero no fallar si no existe
    NegocioInfo? negocioInfo;
    try {
      negocioInfo = await _negocioInfoService.getNegocioInfo();
    } catch (e) {
      print('⚠️ No se pudo obtener info del negocio: $e');
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

      print('📋 DEBUG - Datos guardados en pedido: $datosGuardados');
      print('📋 DEBUG - Cliente en pedido: ${documento.cliente}');

      if (datosGuardados == null ||
          datosGuardados['clienteDepartamento'] == null ||
          datosGuardados['clienteCiudad'] == null) {
        print('⚠️ Datos incompletos, buscando cliente en API...');
        clienteCompleto = await _buscarClienteCompleto(documento.cliente);
      } else {
        print('✅ Usando datos guardados del cliente');
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
                'codigo': item.productoId ?? '',
                'nombre': item.productoNombre ?? 'Producto',
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
        // ✅ Calcular totales desde los ítems reales, no desde documento.total
        'subtotal': documento.subtotal > 0
            ? documento.subtotal
            : documento.items.fold<double>(
                0.0,
                (sum, item) => sum + (item.cantidad * item.precioUnitario),
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
                      (sum, item) =>
                          sum + (item.cantidad * item.precioUnitario),
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
        'vendedor': documento.mesero ?? 'Sin Vendedor',
        'mesero': documento.mesero ?? 'Sin Vendedor',
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
                    'codigo': item.productoId ?? '',
                    'nombre': item.productoNombre ?? 'Producto',
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
        backgroundColor: AppTheme.cardBg,
        title: Text(
          'Nombre del archivo',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Personaliza el nombre del archivo PDF:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            SizedBox(height: 12),
            TextField(
              controller: controladorNombre,
              autofocus: true,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nombre del archivo',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixText: '.pdf',
                suffixStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
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
