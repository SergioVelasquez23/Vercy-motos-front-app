import 'package:flutter/material.dart';
import '../../models/item_pedido.dart';
import '../../theme/app_theme.dart';

class BotonesAccionFacturacion extends StatelessWidget {
  final List<ItemPedido> items;
  final bool isLoading;
  final VoidCallback onGuardarBorrador;
  final VoidCallback onGuardarYPagar;
  final VoidCallback onGuardarComoDeuda;

  const BotonesAccionFacturacion({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onGuardarBorrador,
    required this.onGuardarYPagar,
    required this.onGuardarComoDeuda, // kept for API compatibility
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);

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
                  '\$${subtotal.toStringAsFixed(0)}',
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
