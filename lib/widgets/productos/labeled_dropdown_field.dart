import 'package:flutter/material.dart';

/// Dropdown con label arriba, usado en el diálogo de imprimir código de
/// barras de productos_screen.dart (_buildDropdownField). Copiado tal cual,
/// sin cambios de lógica.
class LabeledDropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final double width;

  const LabeledDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: value,
            items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: onChanged,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
            dropdownColor: Theme.of(context).colorScheme.surface,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}