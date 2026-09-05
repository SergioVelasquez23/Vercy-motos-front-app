import 'package:flutter/material.dart';
import '../models/factura_compra.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';

class DetalleFacturaCompraScreen extends StatelessWidget {
  final FacturaCompra factura;

  const DetalleFacturaCompraScreen({super.key, required this.factura});

  // Método auxiliar para determinar si una factura debe considerarse como
  // pagada. Una compra a crédito nunca se considera pagada desde acá — su
  // saldo real vive en la cuenta por pagar de Cartera, no en la compra.
  bool _estaFacturaPagada(FacturaCompra factura) {
    if (factura.esCreditoPendiente) return false;
    return factura.estado.toUpperCase() == 'PAGADA' || factura.pagadoDesdeCaja;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Detalle de Factura',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoGeneral(context),
            SizedBox(height: 16),
            _buildItems(context),
            SizedBox(height: 16),
            _buildResumen(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGeneral(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información General',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow(context, 'Número de Factura:', factura.numeroFactura),
            _buildInfoRow(context, 'Proveedor:', factura.proveedorNombre),
            if (factura.proveedorNit != null)
              _buildInfoRow(context, 'NIT:', factura.proveedorNit!),
            _buildInfoRow(
              context,
              'Fecha de Factura:',
              _formatearFecha(factura.fechaFactura),
            ),
            _buildInfoRow(
              context,
              'Fecha de Creación:',
              _formatearFechaConHora(factura.fechaCreacion),
            ),
            _buildInfoRow(
              context,
              'Fecha de Vencimiento:',
              _formatearFecha(factura.fechaVencimiento),
            ),
            if (factura.origenCompraEfectivo != null)
              _buildInfoRow(context, 'Origen de la compra:', factura.origenCompraEfectivo!),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estado:',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
                // Si está pagado desde caja, mostrar PAGADA independientemente del estado en la base de datos
                // Usar el método auxiliar para determinar el estado visual
                _buildEstadoChip(
                  _estaFacturaPagada(factura) ? 'PAGADA' : factura.estado,
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pagado desde caja:',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
                Row(
                  children: [
                    Icon(
                      factura.pagadoDesdeCaja
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: factura.pagadoDesdeCaja
                          ? Colors.green
                          : Colors.grey,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      factura.pagadoDesdeCaja ? 'Sí' : 'No',
                      style: TextStyle(
                        color: factura.pagadoDesdeCaja
                            ? Colors.green
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItems(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items de la Factura',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ...factura.items.map(
              (item) => Card(
                color: Theme.of(context).scaffoldBackgroundColor,
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    item.ingredienteNombre,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    '${item.cantidad} ${item.unidad} x ${CurrencyUtils.format(item.precioUnitario)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                  trailing: Text(
                    CurrencyUtils.format(item.subtotal),
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  CurrencyUtils.format(factura.total),
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Nota: El IVA ya está incluido en los precios',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
          Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
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

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  // Añadir método para formatear fecha con hora (formato 12h con AM/PM)
  String _formatearFechaConHora(DateTime fecha) {
    final hour24 = fecha.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} ${hour12.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')} $period';
  }
}
