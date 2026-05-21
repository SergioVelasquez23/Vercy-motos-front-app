import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Header estandarizado para pantallas (full-width, mismo alto y estilo).
///
/// Uso:
/// ```dart
/// ScreenHeader(
///   icon: Icons.people,
///   title: 'Lista de Clientes',
///   badge: '${_clientes.length}',
///   actions: [
///     ScreenHeaderAction.primary(
///       icon: Icons.person_add,
///       label: 'Nuevo Cliente',
///       onPressed: _crear,
///     ),
///   ],
/// )
/// ```
class ScreenHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final Color? badgeColor;
  final List<Widget> actions;

  const ScreenHeader({
    super.key,
    required this.icon,
    required this.title,
    this.badge,
    this.badgeColor,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final color = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: color.surface,
        border: Border(
          bottom: BorderSide(color: color.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.primary, size: isMobile ? 22 : 26),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.w700,
                  color: color.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (badge != null) ...[
                const SizedBox(width: 10),
                _Badge(text: badge!, color: badgeColor ?? AppTheme.primary),
              ],
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Constructor de acciones consistentes para [ScreenHeader].
class ScreenHeaderAction {
  /// Botón principal (azul primario).
  static Widget primary({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    String? mobileLabel,
  }) {
    return _ActionButton(
      icon: icon,
      label: label,
      mobileLabel: mobileLabel,
      onPressed: onPressed,
      color: AppTheme.primary,
    );
  }

  /// Botón verde (acciones positivas como cargas masivas).
  static Widget success({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    String? mobileLabel,
  }) {
    return _ActionButton(
      icon: icon,
      label: label,
      mobileLabel: mobileLabel,
      onPressed: onPressed,
      color: AppTheme.success,
    );
  }

  /// Botón naranja (acciones de utilidad como limpiar filtros).
  static Widget warning({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    String? mobileLabel,
  }) {
    return _ActionButton(
      icon: icon,
      label: label,
      mobileLabel: mobileLabel,
      onPressed: onPressed,
      color: AppTheme.warning,
    );
  }

  /// Botón secundario (morado).
  static Widget secondary({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    String? mobileLabel,
  }) {
    return _ActionButton(
      icon: icon,
      label: label,
      mobileLabel: mobileLabel,
      onPressed: onPressed,
      color: AppTheme.secondary,
    );
  }

  /// Botón sólo de ícono con tooltip (refrescar, descargar, etc.).
  static Widget iconOnly({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return _IconOnlyButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      color: color ?? AppTheme.primary,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? mobileLabel;
  final VoidCallback onPressed;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
    this.mobileLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(
        isMobile ? (mobileLabel ?? label) : label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 10 : 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _IconOnlyButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  const _IconOnlyButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
