import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Selector de método de pago + campos de "Pago Múltiple" de
/// facturacion_screen.dart, extraído tal cual (mismo layout, mismos
/// controllers) para reducir el tamaño de la pantalla. El estado
/// (método seleccionado, valor de cada monto) lo sigue dueño la pantalla:
/// este widget solo dibuja y avisa por callback cuando algo cambia.
class MetodoPagoSection extends StatelessWidget {
  final String metodoPago;
  final List<Map<String, dynamic>> metodosPago;
  final ValueChanged<String> onMetodoPagoChanged;

  /// Se dispara en cada tecla de cualquier campo de monto — la pantalla
  /// solo necesita un setState() vacío porque los totales se leen
  /// directamente de los controllers en el próximo build.
  final VoidCallback onMontoChanged;

  final TextEditingController montoEfectivoController;
  final TextEditingController montoTransferenciaController;
  final TextEditingController montoNequiController;
  final TextEditingController montoDaviplataController;
  final TextEditingController montoBancolombiaController;
  final TextEditingController montoTarjetaController;
  final TextEditingController montoSistereditoController;
  final TextEditingController montoBoldController;
  final TextEditingController montoAddiController;
  final TextEditingController montoCredilondonController;

  const MetodoPagoSection({
    super.key,
    required this.metodoPago,
    required this.metodosPago,
    required this.onMetodoPagoChanged,
    required this.onMontoChanged,
    required this.montoEfectivoController,
    required this.montoTransferenciaController,
    required this.montoNequiController,
    required this.montoDaviplataController,
    required this.montoBancolombiaController,
    required this.montoTarjetaController,
    required this.montoSistereditoController,
    required this.montoBoldController,
    required this.montoAddiController,
    required this.montoCredilondonController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Método de Pago',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: metodosPago.map((metodo) {
              final isSelected = metodoPago == metodo['value'];
              return InkWell(
                onTap: () => onMetodoPagoChanged(metodo['value']),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withOpacity(0.2)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        metodo['icon'],
                        color: isSelected
                            ? AppTheme.primary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        metodo['label'],
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          // Advertencia de crédito
          if (metodoPago == 'credito') ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Se creará una deuda automáticamente para este cliente (vence en 30 días). El campo "Cliente" es obligatorio.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Campos para pago múltiple
          if (metodoPago == 'multiple') ...[
            SizedBox(height: 20),
            Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.3)),
            SizedBox(height: 16),
            Text(
              'Distribución del pago',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Efectivo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: montoEfectivoController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: AppTheme.primary,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        onChanged: (value) => onMontoChanged(),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildCampoMontoMixto(
                    context,
                    'Transferencia (otro banco)',
                    montoTransferenciaController,
                    Icons.account_balance,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCampoMontoMixto(
                    context,
                    'Nequi',
                    montoNequiController,
                    Icons.account_balance,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildCampoMontoMixto(
                    context,
                    'DaviPlata',
                    montoDaviplataController,
                    Icons.account_balance,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCampoMontoMixto(
                    context,
                    'Bancolombia',
                    montoBancolombiaController,
                    Icons.account_balance,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(child: SizedBox()),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tarjeta',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: montoTarjetaController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: Icon(
                            Icons.credit_card,
                            color: AppTheme.primary,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        onChanged: (value) => onMontoChanged(),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sistecredito',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: montoSistereditoController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: Icon(
                            Icons.card_giftcard,
                            color: AppTheme.primary,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        onChanged: (value) => onMontoChanged(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCampoMontoMixto(
                    context,
                    'Bold',
                    montoBoldController,
                    Icons.point_of_sale,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildCampoMontoMixto(
                    context,
                    'Addi',
                    montoAddiController,
                    Icons.shopping_bag_outlined,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCampoMontoMixto(
                    context,
                    'Credilondon',
                    montoCredilondonController,
                    Icons.shopping_bag_outlined,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Campo de monto para una línea de "Pago Múltiple" (Bold/Addi/Credilondon).
  /// Sigue el mismo patrón visual que los campos Efectivo/Transferencia/Tarjeta/
  /// Sistecredito de esta misma sección, extraído para no repetir el bloque.
  Widget _buildCampoMontoMixto(
    BuildContext context,
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: Icon(icon, color: AppTheme.primary),
            hintText: '0.00',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
          onChanged: (value) => onMontoChanged(),
        ),
      ],
    );
  }
}
