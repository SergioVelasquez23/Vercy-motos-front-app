import 'package:flutter/material.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import 'caja_ui_helpers.dart';

class FormularioAbrirCajaWidget extends StatelessWidget {
  final UserProvider userProvider;
  final TextEditingController montoInicialController;
  final TextEditingController idMaquinaController;
  final TextEditingController observacionesController;
  final String? selectedCaja;
  final ValueChanged<String?> onCajaChanged;
  final VoidCallback onAbrirCaja;

  const FormularioAbrirCajaWidget({
    Key? key,
    required this.userProvider,
    required this.montoInicialController,
    required this.idMaquinaController,
    required this.observacionesController,
    required this.selectedCaja,
    required this.onCajaChanged,
    required this.onAbrirCaja,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Información del usuario
        CajaUiHelpers.buildCard(
          icon: Icons.person_outline,
          title: 'Información del Turno',
          child: Column(
            children: [
              CajaUiHelpers.buildInfoTile(
                'Responsable',
                userProvider.userName ?? 'Usuario no identificado',
                Icons.badge,
              ),
              Divider(color: AppTheme.textMuted.withOpacity(0.2)),
              CajaUiHelpers.buildInfoTile(
                'Fecha y Hora',
                '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                Icons.schedule,
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // Selección de caja
        CajaUiHelpers.buildCard(
          icon: Icons.point_of_sale,
          title: 'Seleccionar Caja',
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: AppTheme.textMuted),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: AppTheme.textMuted),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            dropdownColor: AppTheme.cardBg,
            style: TextStyle(color: AppTheme.textPrimary),
            value: selectedCaja,
            items: ['Caja Principal', 'Caja Secundaria']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: onCajaChanged,
          ),
        ),
        SizedBox(height: 16),

        // Monto inicial
        CajaUiHelpers.buildCard(
          icon: Icons.attach_money,
          title: 'Monto Inicial *',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: montoInicialController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Ingrese el monto inicial',
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    borderSide: BorderSide(color: AppTheme.textMuted),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    borderSide: BorderSide(color: AppTheme.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
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
                  Icon(Icons.info_outline, size: 14, color: AppTheme.textMuted),
                  SizedBox(width: 6),
                  Text(
                    'Este será el dinero con el que inicia la caja',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
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
          icon: Icons.computer,
          title: 'Identificación de Máquina',
          child: TextFormField(
            controller: idMaquinaController,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'ID o nombre de la máquina',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: AppTheme.textMuted),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
              filled: true,
              fillColor: AppTheme.surfaceDark,
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
          icon: Icons.notes,
          title: 'Observaciones',
          child: TextFormField(
            controller: observacionesController,
            maxLines: 3,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Observaciones adicionales (opcional)',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: AppTheme.textMuted),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
              filled: true,
              fillColor: AppTheme.surfaceDark,
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
