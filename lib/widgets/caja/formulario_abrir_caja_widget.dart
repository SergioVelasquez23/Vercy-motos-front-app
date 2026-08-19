import 'package:flutter/material.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import 'caja_ui_helpers.dart';

class FormularioAbrirCajaWidget extends StatelessWidget {
  final UserProvider userProvider;
  final TextEditingController montoInicialController;
  final TextEditingController idMaquinaController;
  final TextEditingController observacionesController;
  final VoidCallback onAbrirCaja;

  const FormularioAbrirCajaWidget({
    Key? key,
    required this.userProvider,
    required this.montoInicialController,
    required this.idMaquinaController,
    required this.observacionesController,
    required this.onAbrirCaja,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Información del usuario
        CajaUiHelpers.buildCard(
          context: context,
          icon: Icons.person_outline,
          title: 'Información del Turno',
          child: Column(
            children: [
              CajaUiHelpers.buildInfoTile(
                context,
                'Responsable',
                userProvider.userName ?? 'Usuario no identificado',
                Icons.badge,
              ),
              Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2)),
              CajaUiHelpers.buildInfoTile(
                context,
                'Fecha y Hora',
                '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                Icons.schedule,
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // Monto inicial
        CajaUiHelpers.buildCard(
          context: context,
          icon: Icons.attach_money,
          title: 'Monto Inicial *',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: montoInicialController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Ingrese el monto inicial',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    borderSide: BorderSide(color: AppTheme.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  prefixIcon: Container(
                    margin: EdgeInsets.all(8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.attach_money, color: AppTheme.primary),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  SizedBox(width: 6),
                  Text(
                    'Este será el dinero con el que inicia la caja',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // Identificación máquina
        CajaUiHelpers.buildCard(
          context: context,
          icon: Icons.computer,
          title: 'Identificación de Máquina',
          child: TextFormField(
            controller: idMaquinaController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'ID o nombre de la máquina',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              prefixIcon: Container(
                margin: EdgeInsets.all(8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.computer, color: AppTheme.secondary),
              ),
            ),
          ),
        ),
        SizedBox(height: 16),

        // Observaciones
        CajaUiHelpers.buildCard(
          context: context,
          icon: Icons.notes,
          title: 'Observaciones',
          child: TextFormField(
            controller: observacionesController,
            maxLines: 3,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Observaciones adicionales (opcional)',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              alignLabelWithHint: true,
            ),
          ),
        ),
        SizedBox(height: 32),

        // Botón para abrir caja
        Center(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppTheme.primaryShadow,
            ),
            child: ElevatedButton.icon(
              icon: Icon(Icons.lock_open, size: 24),
              label: Text(
                'ABRIR CAJA',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              onPressed: onAbrirCaja,
            ),
          ),
        ),
      ],
    );
  }
}
