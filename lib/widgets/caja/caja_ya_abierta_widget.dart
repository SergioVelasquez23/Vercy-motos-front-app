import 'package:flutter/material.dart';
import '../../models/cuadre_caja.dart';
import '../../theme/app_theme.dart';
import 'caja_ui_helpers.dart';

class CajaYaAbiertaWidget extends StatelessWidget {
  final CuadreCaja? cajaActual;
  final VoidCallback onIrCerrarCaja;

  const CajaYaAbiertaWidget({
    Key? key,
    required this.cajaActual,
    required this.onIrCerrarCaja,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.error.withOpacity(0.5)),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 24),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'CAJA YA ABIERTA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (cajaActual != null) ...[
                  CajaUiHelpers.buildInfoRow(context, Icons.point_of_sale, 'Caja', cajaActual!.nombre),
                  SizedBox(height: 8),
                  CajaUiHelpers.buildInfoRow(context, Icons.person, 'Responsable', cajaActual!.responsable),
                  SizedBox(height: 8),
                  CajaUiHelpers.buildInfoRow(
                    context,
                    Icons.access_time,
                    'Apertura',
                    '${cajaActual!.fechaApertura.day}/${cajaActual!.fechaApertura.month}/${cajaActual!.fechaApertura.year} ${cajaActual!.fechaApertura.hour}:${cajaActual!.fechaApertura.minute.toString().padLeft(2, '0')}',
                  ),
                  SizedBox(height: 8),
                  CajaUiHelpers.buildInfoRow(
                    context,
                    Icons.attach_money,
                    'Monto inicial',
                    '\$${cajaActual!.fondoInicial.toStringAsFixed(0)}',
                  ),
                ],
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Debe cerrar la caja actual antes de abrir una nueva.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 24),
        Center(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.warning, AppTheme.warning.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.warning.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: Icon(Icons.lock_clock, size: 22),
              label: Text(
                'Ir a Cerrar Caja',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              onPressed: onIrCerrarCaja,
            ),
          ),
        ),
      ],
    );
  }
}
