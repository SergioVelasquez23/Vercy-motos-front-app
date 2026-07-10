import 'package:flutter/material.dart';
import '../../models/item_pedido.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

class BotonesAccionFacturacion extends StatelessWidget {
  final List<ItemPedido> items;
  final bool isLoading;
  final VoidCallback onGuardarBorrador;
  final VoidCallback onGuardarYPagar;
  final VoidCallback onGuardarComoDeuda;
  final VoidCallback? onVistaPrevia;
  final TextEditingController? dctoGeneralController;

  const BotonesAccionFacturacion({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onGuardarBorrador,
    required this.onGuardarYPagar,
    required this.onGuardarComoDeuda,
    this.onVistaPrevia,
    this.dctoGeneralController,
  });

  @override
  Widget build(BuildContext context) {
    final baseSubtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);
    final totalImpuestos = items.fold(0.0, (sum, item) => sum + item.valorImpuesto);
    final totalDctoProductos = items.fold(0.0, (sum, item) => sum + item.valorDescuento);
    final dctoGeneral = double.tryParse(dctoGeneralController?.text ?? '') ?? 0;
    final subtotal = baseSubtotal + totalImpuestos - totalDctoProductos - dctoGeneral;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Resumen rápido
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total a Pagar:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  CurrencyUtils.format(subtotal),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Botones de acción
          Column(
            children: [
              if (onVistaPrevia != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: (isLoading || items.isEmpty) ? null : onVistaPrevia,
                    icon: Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text('Vista previa del PDF (sin guardar)'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                SizedBox(height: 8),
              ],
              // Primera fila: Borrador y Pagar
              Row(
                children: [
                  // Guardar como borrador
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : onGuardarBorrador,
                      icon: Icon(Icons.drafts),
                      label: Text('Guardar Borrador'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Guardar y Pagar
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : onGuardarYPagar,
                      icon: isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.check_circle),
                      label: Text(
                        'Guardar y Pagar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
