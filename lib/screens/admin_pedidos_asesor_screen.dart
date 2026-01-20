import 'package:flutter/material.dart';
import '../models/pedido_asesor.dart';
import '../services/pedido_asesor_service.dart';
import '../theme/app_theme.dart';
import 'facturacion_screen.dart';

class AdminPedidosAsesorScreen extends StatefulWidget {
  const AdminPedidosAsesorScreen({super.key});

  @override
  _AdminPedidosAsesorScreenState createState() =>
      _AdminPedidosAsesorScreenState();
}

class _AdminPedidosAsesorScreenState extends State<AdminPedidosAsesorScreen> {
  final PedidoAsesorService _pedidoService = PedidoAsesorService();

  List<PedidoAsesor> _pedidos = [];
  List<PedidoAsesor> _pedidosFiltrados = [];
  bool _isLoading = false;
  String _filtroEstado = 'TODOS';

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    setState(() => _isLoading = true);
    try {
      final pedidos = await _pedidoService.listarPedidos();
      setState(() {
        _pedidos = pedidos;
        _aplicarFiltros();
      });
    } catch (e) {
      _mostrarError('Error al cargar pedidos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    setState(() {
      if (_filtroEstado == 'TODOS') {
        _pedidosFiltrados = List.from(_pedidos);
      } else {
        _pedidosFiltrados = _pedidos
            .where((p) => p.estado == _filtroEstado)
            .toList();
      }
      // Ordenar por fecha, más reciente primero
      _pedidosFiltrados.sort(
        (a, b) => b.fechaCreacion.compareTo(a.fechaCreacion),
      );
    });
  }

  void _seleccionarPedido(PedidoAsesor pedido) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacturacionScreen(pedidoAsesor: pedido),
      ),
    );
  }

  Future<void> _cancelarPedido(String pedidoId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(
          'Cancelar Pedido',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          '¿Estás seguro de que deseas cancelar este pedido?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sí, Cancelar',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _pedidoService.cancelarPedido(pedidoId);
        _mostrarExito('Pedido cancelado');
        _cargarPedidos();
      } catch (e) {
        _mostrarError('Error al cancelar pedido: $e');
      }
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'PENDIENTE':
        return Colors.orange;
      case 'FACTURADO':
        return Colors.green;
      case 'CANCELADO':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Pedidos de Asesores',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarPedidos,
            tooltip: 'Recargar',
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
                : _pedidosFiltrados.isEmpty
                ? _buildEmptyState()
                : _buildPedidosList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          bottom: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Estado:',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 12),
          _buildFiltroChip('TODOS'),
          _buildFiltroChip('PENDIENTE'),
          _buildFiltroChip('FACTURADO'),
          _buildFiltroChip('CANCELADO'),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String estado) {
    final isSelected = _filtroEstado == estado;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(estado),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filtroEstado = estado;
            _aplicarFiltros();
          });
        },
        selectedColor: AppTheme.primary,
        backgroundColor: AppTheme.cardBg,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 80, color: AppTheme.textSecondary),
          SizedBox(height: 16),
          Text(
            'No hay pedidos ${_filtroEstado == "TODOS" ? "" : _filtroEstado.toLowerCase() + "s"}',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPedidosList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _pedidosFiltrados.length,
      itemBuilder: (context, index) {
        final pedido = _pedidosFiltrados[index];
        return _buildPedidoCard(pedido);
      },
    );
  }

  Widget _buildPedidoCard(PedidoAsesor pedido) {
    return Card(
      color: AppTheme.cardBg,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getEstadoColor(pedido.estado).withOpacity(0.5),
        ),
      ),
      child: InkWell(
        onTap: pedido.estado == 'PENDIENTE'
            ? () => _seleccionarPedido(pedido)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pedido.clienteNombre,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.badge,
                              color: AppTheme.textSecondary,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Asesor: ${pedido.asesorNombre}',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getEstadoColor(pedido.estado).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getEstadoColor(pedido.estado)),
                    ),
                    child: Text(
                      pedido.estado,
                      style: TextStyle(
                        color: _getEstadoColor(pedido.estado),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Divider(color: AppTheme.primary.withOpacity(0.3)),
              SizedBox(height: 8),
              // Items
              Text(
                'Productos (${pedido.items.length}):',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              ...pedido.items
                  .take(3)
                  .map(
                    (item) => Padding(
                      padding: EdgeInsets.only(left: 8, top: 2),
                      child: Text(
                        '• ${item.productoNombre} x${item.cantidad} - \$${item.subtotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              if (pedido.items.length > 3)
                Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: Text(
                    '... y ${pedido.items.length - 3} más',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (pedido.observaciones != null &&
                  pedido.observaciones!.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Observaciones:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  pedido.observaciones!,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              SizedBox(height: 12),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: \$${pedido.total.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatearFecha(pedido.fechaCreacion),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (pedido.estado == 'PENDIENTE') ...[
                        IconButton(
                          icon: Icon(Icons.cancel, color: AppTheme.error),
                          onPressed: () => _cancelarPedido(pedido.id!),
                          tooltip: 'Cancelar pedido',
                        ),
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _seleccionarPedido(pedido),
                          icon: Icon(Icons.arrow_forward, color: Colors.white),
                          label: Text(
                            'Facturar',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                      if (pedido.estado == 'FACTURADO' &&
                          pedido.fechaFacturacion != null)
                        Text(
                          'Facturado ${_formatearFecha(pedido.fechaFacturacion!)}',
                          style: TextStyle(color: Colors.green, fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }
}
