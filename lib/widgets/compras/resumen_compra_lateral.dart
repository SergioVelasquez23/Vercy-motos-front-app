import 'package:flutter/material.dart';
import '../../models/factura_compra.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

/// Panel lateral con el resumen de totales de la factura de compra
/// (subtotal, descuentos, impuestos, retenciones y total), usado en
/// crear_factura_compra_screen.dart (antes _buildResumenLateral +
/// _buildResumenRowCompacto). Copiado tal cual, sin cambios de lógica.
class ResumenCompraLateral extends StatelessWidget {
  final List<ItemFacturaCompra> items;
  final TextEditingController descuentoGeneralValorController;
  final String tipoDescuentoGeneral;
  final ValueChanged<String> onTipoDescuentoGeneralChanged;
  final VoidCallback onDescuentoGeneralChanged;
  final TextEditingController porcentajeRetencionController;
  final TextEditingController porcentajeReteIvaController;
  final TextEditingController porcentajeReteIcaController;

  const ResumenCompraLateral({
    super.key,
    required this.items,
    required this.descuentoGeneralValorController,
    required this.tipoDescuentoGeneral,
    required this.onTipoDescuentoGeneralChanged,
    required this.onDescuentoGeneralChanged,
    required this.porcentajeRetencionController,
    required this.porcentajeReteIvaController,
    required this.porcentajeReteIcaController,
  });

  @override
  Widget build(BuildContext context) {
    // Calcular totales
    final subtotalItems = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final totalDescuentosItems = items.fold<double>(0, (sum, item) => sum + item.valorDescuento);

    final descuentoGeneralValor = double.tryParse(descuentoGeneralValorController.text) ?? 0;
    double descuentoGeneralAplicado = 0;
    if (tipoDescuentoGeneral == 'Porcentaje') {
      descuentoGeneralAplicado = subtotalItems * (descuentoGeneralValor / 100);
    } else {
      descuentoGeneralAplicado = descuentoGeneralValor;
    }

    final baseGravable = subtotalItems - totalDescuentosItems - descuentoGeneralAplicado;
    final totalImpuestosItems = items.fold<double>(0, (sum, item) => sum + item.valorImpuesto);

    final porcRetencion = double.tryParse(porcentajeRetencionController.text) ?? 0;
    final porcReteIva = double.tryParse(porcentajeReteIvaController.text) ?? 0;
    final porcReteIca = double.tryParse(porcentajeReteIcaController.text) ?? 0;

    final valorRetencion = baseGravable * (porcRetencion / 100);
    final valorReteIva = totalImpuestosItems * (porcReteIva / 100);
    final valorReteIca = baseGravable * (porcReteIca / 100);

    final totalFinal =
        baseGravable + totalImpuestosItems - valorRetencion - valorReteIva - valorReteIca;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(context, 'Subtotal', subtotalItems),
        _row(context, 'Dcto Producto', totalDescuentosItems, isNegative: true),
        // Dcto General con dropdown — label arriba, controles abajo para
        // evitar overflow en el panel lateral angosto.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dcto General',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 36,
                  child: DropdownButtonFormField<String>(
                    initialValue: tipoDescuentoGeneral == 'Porcentaje' ? '%' : 'Valor',
                    isExpanded: true,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    items: const [
                      DropdownMenuItem(value: 'Valor', child: Text('Valor')),
                      DropdownMenuItem(value: '%', child: Text('%')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      onTipoDescuentoGeneralChanged(v == '%' ? 'Porcentaje' : 'Valor');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: descuentoGeneralValorController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        prefixText: tipoDescuentoGeneral == 'Porcentaje' ? null : '\$',
                        suffixText: tipoDescuentoGeneral == 'Porcentaje' ? '%' : null,
                        prefixStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        suffixStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => onDescuentoGeneralChanged(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        _row(context, 'Impuesto', totalImpuestosItems),
        _row(context, 'Retención', valorRetencion, isNegative: true),
        _row(context, 'Reteiva', valorReteIva, isNegative: true),
        _row(context, 'Reteica', valorReteIca, isNegative: true),
        const SizedBox(height: 8),
        Divider(color: AppTheme.primary.withOpacity(0.3)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TOTAL',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                CurrencyUtils.format(totalFinal),
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, double valor, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
          ),
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${isNegative && valor > 0 ? "-" : ""}${CurrencyUtils.format(valor.abs())}',
              style: TextStyle(
                color: isNegative && valor > 0 ? Colors.red[300] : Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}