import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../config/performance_config.dart';

/// Widget de loading optimizado con mejor UX
class OptimizedLoadingWidget extends StatefulWidget {
  final String? message;
  final String? subtitle;
  final bool showProgress;
  final double? progress;
  final VoidCallback? onCancel;
  final IconData? icon;
  final Color? color;

  const OptimizedLoadingWidget({
    Key? key,
    this.message,
    this.subtitle,
    this.showProgress = false,
    this.progress,
    this.onCancel,
    this.icon,
    this.color,
  }) : super(key: key);

  @override
  State<OptimizedLoadingWidget> createState() => _OptimizedLoadingWidgetState();
}

class _OptimizedLoadingWidgetState extends State<OptimizedLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: Duration(
        milliseconds: PerformanceConfig.animationDurationMs * 4,
      ),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: Duration(milliseconds: PerformanceConfig.animationDurationMs),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.primary;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Card(
          color: AppTheme.cardBg,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicador de carga
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Círculo de fondo
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.1),
                      ),
                    ),

                    // Indicador rotatorio o de progreso
                    if (widget.showProgress && widget.progress != null)
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: widget.progress,
                          strokeWidth: 4,
                          color: color,
                          backgroundColor: color.withOpacity(0.2),
                        ),
                      )
                    else
                      RotationTransition(
                        turns: _rotationController,
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: color,
                            backgroundColor: color.withOpacity(0.2),
                          ),
                        ),
                      ),

                    // Icono central
                    if (widget.icon != null)
                      Icon(widget.icon, color: color, size: 24),
                  ],
                ),

                const SizedBox(height: 16),

                // Mensaje principal
                if (widget.message != null)
                  Text(
                    widget.message!,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),

                // Subtítulo
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                // Progreso como texto
                if (widget.showProgress && widget.progress != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${(widget.progress! * 100).toInt()}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],

                // Botón de cancelar
                if (widget.onCancel != null) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: widget.onCancel,
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading específico para carga de ingredientes
class IngredientesLoadingWidget extends StatelessWidget {
  final int? totalIngredientes;
  final int? cargados;

  const IngredientesLoadingWidget({
    Key? key,
    this.totalIngredientes,
    this.cargados,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = (totalIngredientes != null && cargados != null)
        ? cargados! / totalIngredientes!
        : null;

    return OptimizedLoadingWidget(
      message: 'Cargando ingredientes...',
      subtitle: totalIngredientes != null
          ? 'Procesando $totalIngredientes elementos'
          : 'Por favor espere',
      icon: Icons.restaurant_menu,
      showProgress: progress != null,
      progress: progress,
    );
  }
}

/// Loading específico para carga de productos
class ProductosLoadingWidget extends StatelessWidget {
  final bool isEditing;

  const ProductosLoadingWidget({Key? key, this.isEditing = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OptimizedLoadingWidget(
      message: isEditing ? 'Preparando edición...' : 'Cargando productos...',
      subtitle: isEditing
          ? 'Cargando datos del producto'
          : 'Obteniendo catálogo actualizado',
      icon: Icons.inventory_2,
    );
  }
}

/// Loading para diálogos con cancelación
class DialogLoadingWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onCancel;

  const DialogLoadingWidget({
    Key? key,
    required this.title,
    this.subtitle,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OptimizedLoadingWidget(
      message: title,
      subtitle: subtitle ?? 'Procesando solicitud...',
      onCancel: onCancel,
      icon: Icons.hourglass_empty,
    );
  }
}

/// Loading minimalista para uso en AppBars
class CompactLoadingWidget extends StatelessWidget {
  final Color? color;

  const CompactLoadingWidget({Key? key, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? AppTheme.primary,
      ),
    );
  }
}
