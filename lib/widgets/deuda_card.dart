/// Widget para mostrar información de una deuda en formato de tarjeta
///
/// Muestra el estado, cliente, monto y acciones disponibles para cada deuda
library;

import 'package:flutter/material.dart';
import '../models/deuda.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class DeudaCard extends StatelessWidget {
  final Deuda deuda;
  final VoidCallback? onTap;
  final Function(Deuda deuda)? onPagar;
  final Function(Deuda deuda)? onCancelar;
  final Function(Deuda deuda)? onVerDetalle;

  const DeudaCard({
    Key? key,
    required this.deuda,
    this.onTap,
    this.onPagar,
    this.onCancelar,
    this.onVerDetalle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _getEstadoColor().withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: onTap ?? () => onVerDetalle?.call(deuda),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con estado y cliente
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
                      _getEstadoTexto(),
                      style: TextStyle(
                        color: _getEstadoColor(),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  if (deuda.estaVencida) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'VENCIDA',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  Spacer(),

                  // ID de la deuda
                  if (deuda.id != null)
                    Text(
                      '#${deuda.id}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),

              SizedBox(height: 12),

              // Información del cliente
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      deuda.cliente,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (deuda.telefono != null) ...[
                    Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      deuda.telefono!,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),

              SizedBox(height: 8),

              // Descripción
              Text(
                deuda.descripcion,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: 12),

              // Información monetaria
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monto Original',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          formatCurrency(deuda.montoOriginal),
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pendiente',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          formatCurrency(deuda.montoPendiente),
                          style: TextStyle(
                            color: deuda.montoPendiente > 0
                                ? Colors.red
                                : Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (deuda.montoPagado > 0)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pagado',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            formatCurrency(deuda.montoPagado),
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              SizedBox(height: 12),

              // Fechas importantes
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Creada: ${_formatFecha(deuda.fechaCreacion)}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (deuda.fechaVencimiento != null) ...[
                    Spacer(),
                    Icon(
                      Icons.event_outlined,
                      size: 16,
                      color: deuda.estaVencida
                          ? Colors.red
                          : AppTheme.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Vence: ${_formatFecha(deuda.fechaVencimiento!)}',
                      style: TextStyle(
                        color: deuda.estaVencida
                            ? Colors.red
                            : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: deuda.estaVencida
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),

              // Barra de progreso de pago
              if (deuda.montoPagado > 0 &&
                  deuda.estado != EstadoDeuda.pagada) ...[
                SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progreso: ${deuda.porcentajePagado.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: deuda.porcentajePagado / 100,
                      backgroundColor: Colors.grey.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        deuda.porcentajePagado < 50
                            ? Colors.red
                            : deuda.porcentajePagado < 80
                            ? Colors.orange
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],

              // Botones de acción
              if (deuda.estado == EstadoDeuda.pendiente ||
                  deuda.estado == EstadoDeuda.parcial) ...[
                SizedBox(height: 16),
                Row(
                  children: [
                    if (onPagar != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onPagar?.call(deuda),
                          icon: Icon(Icons.payment, size: 16),
                          label: Text('Pagar', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    if (onPagar != null && onCancelar != null)
                      SizedBox(width: 8),
                    if (onCancelar != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onCancelar?.call(deuda),
                          icon: Icon(Icons.cancel_outlined, size: 16),
                          label: Text(
                            'Cancelar',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    if ((onPagar != null || onCancelar != null) &&
                        onVerDetalle != null)
                      SizedBox(width: 8),
                    if (onVerDetalle != null)
                      IconButton(
                        onPressed: () => onVerDetalle?.call(deuda),
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
    switch (deuda.estado) {
      case EstadoDeuda.pendiente:
        return deuda.estaVencida ? Colors.red : Colors.orange;
      case EstadoDeuda.parcial:
        return Colors.blue;
      case EstadoDeuda.pagada:
        return Colors.green;
      case EstadoDeuda.cancelada:
        return Colors.grey;
    }
  }

  String _getEstadoTexto() {
    switch (deuda.estado) {
      case EstadoDeuda.pendiente:
        return 'PENDIENTE';
      case EstadoDeuda.parcial:
        return 'PARCIAL';
      case EstadoDeuda.pagada:
        return 'PAGADA';
      case EstadoDeuda.cancelada:
        return 'CANCELADA';
    }
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}
