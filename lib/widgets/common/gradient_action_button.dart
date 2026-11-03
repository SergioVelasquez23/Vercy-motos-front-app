import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Botón de acción primaria con fondo en degradado (Container con gradiente
/// + ElevatedButton.icon transparente encima) — el mismo bloque que antes se
/// repetía casi igual en varias pantallas (abrir caja, cerrar caja,
/// traslados). Pensado para CTAs grandes, no para botones compactos de
/// barra de acciones (para eso sigue siendo razonable un InkWell a medida).
///
/// Por defecto usa [AppTheme.primaryGradient] / [AppTheme.primaryShadow];
/// pasar [gradient]/[boxShadow] para variantes de otro color (ej. warning).
class GradientActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final bool isLoading;
  final bool expand;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double fontSize;
  final double iconSize;
  final double? letterSpacing;

  const GradientActionButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.gradient,
    this.boxShadow,
    this.isLoading = false,
    this.expand = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.borderRadius = AppTheme.radiusMedium,
    this.fontSize = 16,
    this.iconSize = 24,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expand ? double.infinity : null,
      decoration: BoxDecoration(
        gradient: gradient ?? AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ?? AppTheme.primaryShadow,
      ),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : (icon != null ? Icon(icon, size: iconSize) : const SizedBox.shrink()),
        label: Text(
          label,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, letterSpacing: letterSpacing),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        ),
      ),
    );
  }
}
