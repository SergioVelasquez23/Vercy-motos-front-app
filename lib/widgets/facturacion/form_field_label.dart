import 'package:flutter/material.dart';

/// Envuelve un campo con una etiqueta arriba (mismo patrón repetido en todo
/// el formulario principal de facturacion_screen.dart). Copiado tal cual,
/// sin ningún cambio de estilo ni de lógica.
class FormFieldLabel extends StatelessWidget {
  final String label;
  final Widget field;

  const FormFieldLabel({super.key, required this.label, required this.field});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        field,
      ],
    );
  }
}
