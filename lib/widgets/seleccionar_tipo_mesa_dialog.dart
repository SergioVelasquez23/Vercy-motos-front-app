/// Diálogo para seleccionar el tipo de mesa al crear una nueva mesa
///
/// Permite al usuario elegir entre diferentes tipos de mesa
/// con información sobre características y recargos.
library;

import 'package:flutter/material.dart';
import '../models/tipo_mesa.dart';
import '../theme/app_theme.dart';

class SeleccionarTipoMesaDialog extends StatefulWidget {
  final String nombreMesa;
  final Function(TipoMesa tipoSeleccionado) onTipoSeleccionado;

  const SeleccionarTipoMesaDialog({
    Key? key,
    required this.nombreMesa,
    required this.onTipoSeleccionado,
  }) : super(key: key);

  @override
  State<SeleccionarTipoMesaDialog> createState() => _SeleccionarTipoMesaDialogState();
}

class _SeleccionarTipoMesaDialogState extends State<SeleccionarTipoMesaDialog> {
  TipoMesa? _tipoSeleccionado;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.table_restaurant,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar Tipo de Mesa',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          widget.nombreMesa,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close),
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),

            // Contenido
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elige el tipo de mesa que mejor se adapte a tus necesidades:',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    // Lista de tipos de mesa
                    ...TipoMesa.tiposDisponibles.map((tipo) => 
                      _buildTipoMesaCard(tipo)
                    ).toList(),
                  ],
                ),
              ),
            ),

            // Botones de acción
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Cancelar'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _tipoSeleccionado != null 
                        ? () {
                            widget.onTipoSeleccionado(_tipoSeleccionado!);
                            Navigator.of(context).pop();
                          } 
                        : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoMesaCard(TipoMesa tipo) {
    final isSelected = _tipoSeleccionado == tipo;
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _tipoSeleccionado = tipo;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected 
                ? AppTheme.primary 
                : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected 
              ? AppTheme.primary.withOpacity(0.1) 
              : Colors.transparent,
          ),
          child: Row(
            children: [
              // Indicador de selección
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : Colors.grey,
                    width: 2,
                  ),
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                ),
                child: isSelected
                  ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
              ),
              
              SizedBox(width: 16),
              
              // Icono del tipo de mesa
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(tipo.colorValue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconData(tipo.icono),
                  color: Color(tipo.colorValue),
                  size: 24,
                ),
              ),
              
              SizedBox(width: 16),
              
              // Información del tipo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tipo.nombre,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (tipo.tieneRecargo) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${(tipo.porcentajeRecargo * 100).toInt()}%',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      tipo.descripcion,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (tipo.tieneRecargo) ...[
                      SizedBox(height: 4),
                      Text(
                        'Incluye recargo del ${(tipo.porcentajeRecargo * 100).toInt()}% sobre el total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'table_restaurant':
        return Icons.table_restaurant;
      case 'star':
        return Icons.star;
      case 'help_outline':
        return Icons.help_outline;
      case 'deck':
        return Icons.deck;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'meeting_room':
        return Icons.meeting_room;
      default:
        return Icons.table_restaurant;
    }
  }
}