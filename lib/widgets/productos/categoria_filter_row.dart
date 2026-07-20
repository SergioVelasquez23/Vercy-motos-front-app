import 'package:flutter/material.dart';
import '../../models/categoria.dart';
import '../../theme/app_theme.dart';

/// Fila de chips para filtrar productos por categoría, con "Todas" siempre
/// primero. Copiado tal cual de productos_screen.dart
/// (_buildCategoriaCompactRowProductos), sin cambios de lógica.
class CategoriaFilterRow extends StatelessWidget {
  final List<Categoria> categorias;
  final String? selectedCategoriaId;
  final ValueChanged<String?> onCategoriaSelected;

  const CategoriaFilterRow({
    super.key,
    required this.categorias,
    required this.selectedCategoriaId,
    required this.onCategoriaSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _chip(context, label: 'Todas', isSelected: selectedCategoriaId == null, onTap: () => onCategoriaSelected(null)),
        const SizedBox(width: 8),
        for (final categoria in categorias) ...[
          _chip(
            context,
            label: categoria.nombre,
            isSelected: selectedCategoriaId == categoria.id,
            onTap: () => onCategoriaSelected(categoria.id),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
