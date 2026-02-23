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

class FacturasListScreen extends StatefulWidget {
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
  String _filtroTipo = 'POS';
  String _filtroNumero = '';
  String _filtroCliente = '';
  String _filtroOrden = '';

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
  }

  Future<void> _cargarDocumentos() async {
    setState(() => _isLoading = true);
    try {
      // Cargar facturas tradicionales
      final facturas = await _facturaService.getFacturas();
      
      // ⚡ OPTIMIZADO: Cargar solo pedidos pagados en lugar de todos los pedidos
      final pedidosPagados = await _pedidoService.getPedidosByEstado(
        EstadoPedido.pagado,
      );

      // Filtrar solo los de tipo POS o mesa FACTURACION
      final pedidosFacturacion = pedidosPagados
          .where(
            (p) => p.tipoFactura == 'POS' || p.mesa == 'FACTURACION',
          )
          .toList();

      // Ordenar por fecha descendente
      pedidosFacturacion.sort((a, b) => b.fecha.compareTo(a.fecha));
      
      setState(() {
        _facturas = facturas;
        _pedidosPagados = pedidosFacturacion;
        _aplicarFiltros();
      });
    } catch (e) {
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

    _documentosFiltrados = documentos;
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
              style: TextStyle(color: Colors.white),
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
              style: TextStyle(color: Colors.white),
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
              style: TextStyle(color: Colors.white),
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
              style: TextStyle(color: Colors.white),
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
            child: Text('Otros', style: TextStyle(color: Colors.white)),
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
                      return _buildTableRow(documento, index);
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
                    style: TextStyle(color: Colors.white, fontSize: 13),
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
              style: TextStyle(color: Colors.white, fontSize: 13),
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
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),

          // Total
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${total.toStringAsFixed(0)}',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Abono
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${abono.toStringAsFixed(0)}',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Saldo
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${saldo.toStringAsFixed(0)}',
              style: TextStyle(color: Colors.white, fontSize: 13),
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
          Container(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Botón ver/imprimir PDF
                IconButton(
                  icon: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  onPressed: () => _verPDF(documento),
                  tooltip: 'Ver PDF',
                ),
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
                'iva': 0,
                'descuento': 0,
              },
            )
            .toList(),
        'subtotal': documento.total / 1.19,
        'iva': documento.total - (documento.total / 1.19),
        'total': documento.total,
        'metodoPago': documento.formaPago ?? 'EFECTIVO',
        'formaPago': documento.formaPago ?? 'EFECTIVO',
        'vendedor': documento.mesero ?? 'Sin Vendedor',
        'mesero': documento.mesero ?? 'Sin Vendedor',
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
                    'iva': 0,
                    'descuento': 0,
                  },
                )
                .toList() ??
            [],
        'subtotal': subtotalCalc,
        'iva': ivaCalc,
        'total': documento.total,
        'metodoPago': documento.metodoPago ?? 'EFECTIVO',
        'formaPago': documento.metodoPago ?? 'EFECTIVO',
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
      await _pdfService.mostrarVistaPrevia(resumen: resumen, esFactura: true);
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
}
