/// Widget para mostrar información de un producto cancelado
///
/// Muestra los detalles del producto cancelado, motivo, usuario
/// y acciones disponibles como confirmar o revertir la cancelación.
library;

import 'package:flutter/material.dart';
import '../models/producto_cancelado.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class ProductoCanceladoCard extends StatelessWidget {
  final ProductoCancelado productoCancelado;
  final VoidCallback? onTap;
  final Function(ProductoCancelado)? onConfirmar;
  final Function(ProductoCancelado)? onRevertir;
  final Function(ProductoCancelado)? onVerDetalle;
  final bool showActions;

  const ProductoCanceladoCard({
    Key? key,
    required this.productoCancelado,
    this.onTap,
    this.onConfirmar,
    this.onRevertir,
    this.onVerDetalle,
    this.showActions = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getEstadoColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap ?? () => onVerDetalle?.call(productoCancelado),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con estado y fecha
              Row(
                children: [
                  // Indicador de estado
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getEstadoColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getEstadoColor().withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      productoCancelado.estado.descripcion.toUpperCase(),
                      style: TextStyle(
                        color: _getEstadoColor(),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  Spacer(),
                  
                  // Fecha de cancelación
                  Text(
                    _formatFecha(productoCancelado.fechaCancelacion),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Información del producto
              Row(
                children: [
                  // Icono del producto
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.remove_shopping_cart,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  
                  SizedBox(width: 12),
                  
                  // Detalles del producto
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${productoCancelado.itemOriginal.cantidad}x ${productoCancelado.itemOriginal.productoNombre ?? 'Producto'}',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.table_restaurant,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              productoCancelado.mesaNombre,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Monto del producto
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency(productoCancelado.montoProducto),
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (productoCancelado.tieneReembolso)
                        Text(
                          'Reembolsado',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Motivo de cancelación
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getMotivoColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getMotivoColor().withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getMotivoIcon(),
                          size: 16,
                          color: _getMotivoColor(),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Motivo: ${productoCancelado.motivo.descripcion}',
                          style: TextStyle(
                            color: _getMotivoColor(),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (productoCancelado.descripcionMotivo != null) ...[
                      SizedBox(height: 6),
                      Text(
                        productoCancelado.descripcionMotivo!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 12),

              // Información del usuario que canceló
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Cancelado por: ',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      productoCancelado.canceladoPor,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    _formatHora(productoCancelado.fechaCancelacion),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              // Información de reembolso si aplica
              if (productoCancelado.tieneReembolso) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 16,
                        color: Colors.green,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Reembolso: ${formatCurrency(productoCancelado.montoReembolsado!)}',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (productoCancelado.metodoPago != null) ...[
                        Text(
                          ' - ${productoCancelado.metodoPago}',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Observaciones adicionales
              if (productoCancelado.observaciones != null) ...[
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Observaciones: ${productoCancelado.observaciones}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],

              // Botones de acción
              if (showActions && productoCancelado.estado == EstadoCancelacion.pendiente) ...[
                SizedBox(height: 16),
                Row(
                  children: [
                    if (onConfirmar != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onConfirmar?.call(productoCancelado),
                          icon: Icon(Icons.check_circle, size: 16),
                          label: Text('Confirmar', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    if (onConfirmar != null && onRevertir != null)
                      SizedBox(width: 8),
                    if (onRevertir != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onRevertir?.call(productoCancelado),
                          icon: Icon(Icons.undo, size: 16),
                          label: Text('Revertir', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: BorderSide(color: Colors.orange),
                            padding: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    if ((onConfirmar != null || onRevertir != null) && onVerDetalle != null)
                      SizedBox(width: 8),
                    if (onVerDetalle != null)
                      IconButton(
                        onPressed: () => onVerDetalle?.call(productoCancelado),
                        icon: Icon(Icons.info_outline),
                        iconSize: 20,
                        color: AppTheme.textSecondary,
                        tooltip: 'Ver detalle',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getEstadoColor() {
    switch (productoCancelado.estado) {
      case EstadoCancelacion.pendiente:
        return Colors.orange;
      case EstadoCancelacion.confirmada:
        return Colors.red;
      case EstadoCancelacion.revertida:
        return Colors.green;
    }
  }

  Color _getMotivoColor() {
    switch (productoCancelado.motivo) {
      case MotivoCancelacion.clienteSolicito:
        return Colors.blue;
      case MotivoCancelacion.errorPedido:
        return Colors.orange;
      case MotivoCancelacion.noDisponible:
        return Colors.red;
      case MotivoCancelacion.cambioMesa:
        return Colors.purple;
      case MotivoCancelacion.errorSistema:
        return Colors.grey;
      case MotivoCancelacion.otro:
        return Colors.brown;
    }
  }

  IconData _getMotivoIcon() {
    switch (productoCancelado.motivo) {
      case MotivoCancelacion.clienteSolicito:
        return Icons.person;
      case MotivoCancelacion.errorPedido:
        return Icons.error_outline;
      case MotivoCancelacion.noDisponible:
        return Icons.inventory_2;
      case MotivoCancelacion.cambioMesa:
        return Icons.swap_horiz;
      case MotivoCancelacion.errorSistema:
        return Icons.computer;
      case MotivoCancelacion.otro:
        return Icons.help_outline;
    }
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  String _formatHora(DateTime fecha) {
    return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }
}