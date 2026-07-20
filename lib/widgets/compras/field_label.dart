import 'package:flutter/material.dart';

/// Etiqueta de columna usada en la tabla de items de
/// crear_factura_compra_screen.dart (antes _buildFieldLabel). Copiado tal
/// cual, sin cambios de lógica.
class FieldLabel extends StatelessWidget {
  final String label;
  final int flex;

  const FieldLabel(this.label, {super.key, this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
      ),
    );
  }
}