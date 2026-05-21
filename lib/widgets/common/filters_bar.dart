import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Barra de filtros estandarizada: una sola card con los filtros en `Wrap`.
/// Si se pasa `secondaryFilters`, se agregan dentro de la misma card separados
/// por un `Divider` (en lugar de crear una segunda card aparte).
class FiltersBar extends StatelessWidget {
  final List<Widget> filters;
  final List<Widget>? secondaryFilters;
  final EdgeInsetsGeometry? margin;

  const FiltersBar({
    super.key,
    required this.filters,
    this.secondaryFilters,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: filters,
          ),
          if (secondaryFilters != null && secondaryFilters!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: color.onSurface.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: secondaryFilters!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Helpers para construir filtros consistentes dentro de [FiltersBar].
class FilterField {
  /// Campo de búsqueda con ícono lupa. Por defecto ocupa 320px en desktop
  /// y full-width en móvil.
  static Widget search({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    double desktopWidth = 320,
  }) {
    return _SearchField(
      controller: controller,
      hint: hint,
      onChanged: onChanged,
      desktopWidth: desktopWidth,
    );
  }

  /// Dropdown estandarizado con label flotante correctamente posicionado.
  static Widget dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? label,
    String? hint,
    double width = 200,
  }) {
    return _DropdownField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      label: label,
      hint: hint,
      width: width,
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final double desktopWidth;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.desktopWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: isMobile ? double.infinity : desktopWidth,
      child: TextField(
        controller: controller,
        style: TextStyle(color: onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.6)),
          prefixIcon: Icon(
            Icons.search,
            color: onSurface.withValues(alpha: 0.7),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final String? hint;
  final double width;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.width,
    this.label,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return SizedBox(
      width: isMobile ? double.infinity : width,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          floatingLabelBehavior: label != null
              ? FloatingLabelBehavior.auto
              : FloatingLabelBehavior.never,
        ),
      ),
    );
  }
}

/// Botón cuadrado para acciones secundarias en la barra de filtros
/// (descargar, refrescar, etc.).
class FilterIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const FilterIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
