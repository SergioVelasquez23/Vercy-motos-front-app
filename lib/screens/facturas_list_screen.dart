import 'package:flutter/material.dart';
import '../models/factura.dart';
import '../services/factura_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vercy_sidebar_layout.dart';

class FacturasListScreen extends StatefulWidget {
  @override
  _FacturasListScreenState createState() => _FacturasListScreenState();
}

class _FacturasListScreenState extends State<FacturasListScreen> {
  final FacturaService _facturaService = FacturaService();

  List<Factura> _facturas = [];
  List<Factura> _facturasFiltradas = [];
  bool _isLoading = false;

  // Filtros
  String _filtroTipo = 'POS';
  String _filtroNumero = '';
  String _filtroCliente = '';
  String _filtroOrden = '';

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
  }

  Future<void> _cargarFacturas() async {
    setState(() => _isLoading = true);
    try {
      final facturas = await _facturaService.getFacturas();
      setState(() {
        _facturas = facturas;
        _aplicarFiltros();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar facturas: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    _facturasFiltradas = _facturas.where((factura) {
      // Filtro por tipo (POS, etc.)
      if (_filtroTipo.isNotEmpty && factura.numero != null) {
        if (!factura.numero!.toUpperCase().startsWith(_filtroTipo)) {
          return false;
        }
      }

      // Filtro por número
      if (_filtroNumero.isNotEmpty && factura.numero != null) {
        if (!factura.numero!.toLowerCase().contains(
          _filtroNumero.toLowerCase(),
        )) {
          return false;
        }
      }

      // Filtro por cliente
      if (_filtroCliente.isNotEmpty) {
        if (!factura.clienteNombre.toLowerCase().contains(
          _filtroCliente.toLowerCase(),
        )) {
          return false;
        }
      }

      return true;
    }).toList();
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
    if (_facturasFiltradas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay facturas para mostrar',
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
            child: ListView.builder(
              itemCount: _facturasFiltradas.length,
              itemBuilder: (context, index) {
                final factura = _facturasFiltradas[index];
                return _buildTableRow(factura, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Factura factura, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? AppTheme.cardBg : AppTheme.surfaceDark;
    final saldo = factura.total - (factura.descuento ?? 0);
    final isPagado = factura.estadoPago == 'PAGADO';

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
            child: Text(
              factura.numero ?? 'N/A',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),

          // Cliente
          Expanded(
            flex: 3,
            child: Text(
              factura.clienteNombre,
              style: TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Fecha de expedición
          Expanded(
            flex: 2,
            child: Text(
              factura.fechaCreacion != null
                  ? '${factura.fechaCreacion!.year}-${factura.fechaCreacion!.month.toString().padLeft(2, '0')}-${factura.fechaCreacion!.day.toString().padLeft(2, '0')}'
                  : 'N/A',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),

          // Total
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${factura.total.toStringAsFixed(0)}',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Abono (mismo que total si está pagado)
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${isPagado ? factura.total.toStringAsFixed(0) : '0'}',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Saldo
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${isPagado ? '0' : saldo.toStringAsFixed(0)}',
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
                    isPagado ? 'VIGENTE' : 'PENDIENTE',
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
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.receipt_long,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  onPressed: () {
                    // TODO: Ver detalle de factura
                  },
                  tooltip: 'Ver factura',
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  onPressed: () {
                    // TODO: Más opciones
                  },
                  tooltip: 'Más opciones',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
