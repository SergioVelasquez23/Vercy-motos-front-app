import 'package:flutter/material.dart';
import '../../models/item_pedido.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

class TotalesSection extends StatelessWidget {
  final List<ItemPedido> items;
  final TextEditingController retencionController;
  final TextEditingController reteIVAController;
  final TextEditingController reteICAController;
  final TextEditingController aiuController;
  final TextEditingController dctoGeneralController;

  const TotalesSection({
    super.key,
    required this.items,
    required this.retencionController,
    required this.reteIVAController,
    required this.reteICAController,
    required this.aiuController,
    required this.dctoGeneralController,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);
    final totalDctoProductos = items.fold(0.0, (sum, item) => sum + item.valorDescuento);

    // Calcular retenciones
    final retencionPct = double.tryParse(retencionController.text) ?? 0;
    final reteIVAPct = double.tryParse(reteIVAController.text) ?? 0;
    final reteICAPct = double.tryParse(reteICAController.text) ?? 0;
    final aiuPct = double.tryParse(aiuController.text) ?? 0;
    final dctoGeneral = double.tryParse(dctoGeneralController.text) ?? 0;

    final retencionValor = subtotal * (retencionPct / 100);
    final reteIVAValor = subtotal * (reteIVAPct / 100);
    final reteICAValor = subtotal * (reteICAPct / 100);
    final aiuValor = subtotal * (aiuPct / 100);

    final totalImpuestos = items.fold(0.0, (sum, item) => sum + item.valorImpuesto);
    final totalRetenciones = retencionValor + reteIVAValor + reteICAValor;
    final total =
        subtotal +
        totalImpuestos +
        aiuValor -
        totalDctoProductos -
        dctoGeneral -
        totalRetenciones;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _buildTotalRow(context, 'Subtotal', subtotal),
          if (totalDctoProductos > 0)
            _buildTotalRow(context, 'Dcto Producto', -totalDctoProductos),
          _buildTotalRow(context, 'Impuesto', totalImpuestos),
          if (dctoGeneral > 0)
            _buildTotalRow(context, 'Dcto General', -dctoGeneral),
          if (retencionValor > 0)
            _buildTotalRow(
              context,
              'Retención (${retencionPct.toStringAsFixed(1)}%)',
              -retencionValor,
            ),
          if (reteIVAValor > 0)
            _buildTotalRow(
              context,
              'ReteIVA (${reteIVAPct.toStringAsFixed(1)}%)',
              -reteIVAValor,
            ),
          if (reteICAValor > 0)
            _buildTotalRow(
              context,
              'ReteICA (${reteICAPct.toStringAsFixed(1)}%)',
              -reteICAValor,
            ),
          if (aiuValor > 0)
            _buildTotalRow(context, 'AIU (${aiuPct.toStringAsFixed(1)}%)', aiuValor),
          Divider(thickness: 2, color: Colors.grey.shade700),
          _buildTotalRow(context, 'TOTAL', total, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    BuildContext context,
    String label,
    double valor, {
    bool isTotal = false,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
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
              color: onSurface,
            ),
          ),
          Text(
            CurrencyUtils.format(valor),
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppTheme.primary : onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
