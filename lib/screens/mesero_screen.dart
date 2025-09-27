import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/pedido.dart';
import '../models/item_pedido.dart';
import '../services/pedido_service.dart';
import '../utils/format_utils.dart';
import '../theme/app_theme.dart';

// Clase auxiliar para combinar ItemPedido con información del pedido
class ProductoConInfo {
  final ItemPedido item;
  final String mesa;
  final EstadoPedido estadoPedido;

  ProductoConInfo({
    required this.item,
    required this.mesa,
    required this.estadoPedido,
  });
}

class MeseroScreen extends StatefulWidget {
  const MeseroScreen({super.key});

  @override
  _MeseroScreenState createState() => _MeseroScreenState();
}

class _MeseroScreenState extends State<MeseroScreen> {
  // Services
  final PedidoService _pedidoService = PedidoService();

  // Data
  List<Pedido> _misPedidos = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPedidos();
  }

  Future<void> _loadPedidos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final nombreMesero = userProvider.userName ?? 'Usuario';

      // Obtener pedidos del mesero
      _misPedidos = await _pedidoService.obtenerPedidosPorMesero(nombreMesero);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar pedidos: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Mis Pedidos', style: AppTheme.headlineMedium),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPedidos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _loadPedidos, child: Text('Reintentar')),
          ],
        ),
      );
    }

    if (_misPedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tienes pedidos registrados',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Los pedidos que crees aparecerán aquí',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPedidos,
      child: _buildPedidosList(),
    );
  }

  Widget _buildPedidosList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _misPedidos.length,
      itemBuilder: (context, index) {
        return _buildPedidoCard(_misPedidos[index]);
      },
    );
  }

  Widget _buildPedidoCard(Pedido pedido) {
    Color estadoColor = _getEstadoColor(pedido.estado);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: estadoColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del pedido
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusMedium),
                topRight: Radius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: estadoColor, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mesa ${pedido.mesa}',
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: estadoColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${_getEstadoText(pedido.estado)}',
                            style: TextStyle(
                              color: estadoColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            '${pedido.items.length} productos',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  formatCurrency(pedido.total),
                  style: AppTheme.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: estadoColor,
                  ),
                ),
              ],
            ),
          ),

          // Lista de productos
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Productos:',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                ...pedido.items
                    .map((item) => _buildProductoItem(item))
                    .toList(),
                SizedBox(height: 8),
                Divider(color: AppTheme.textSecondary.withOpacity(0.2)),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Atendido por: ${pedido.mesero}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      '${pedido.fecha.day}/${pedido.fecha.month}/${pedido.fecha.year} ${pedido.fecha.hour}:${pedido.fecha.minute.toString().padLeft(2, '0')}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoItem(ItemPedido item) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          // Icono del producto
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(Icons.restaurant, color: AppTheme.primary, size: 16),
          ),
          SizedBox(width: 12),

          // Información del producto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productoNombre ?? 'Producto',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.notas != null && item.notas!.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    'Notas: ${item.notas}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.warning,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Cantidad y precio
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'x${item.cantidad}',
                style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 2),
              Text(
                formatCurrency(item.subtotal),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(EstadoPedido estado) {
    switch (estado) {
      case EstadoPedido.activo:
        return AppTheme.warning;
      case EstadoPedido.pagado:
        return AppTheme.success;
      case EstadoPedido.cancelado:
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getEstadoText(EstadoPedido estado) {
    switch (estado) {
      case EstadoPedido.activo:
        return 'ACTIVO';
      case EstadoPedido.pagado:
        return 'PAGADO';
      case EstadoPedido.cancelado:
        return 'CANCELADO';
      default:
        return estado.toString().toUpperCase();
    }
  }
}
