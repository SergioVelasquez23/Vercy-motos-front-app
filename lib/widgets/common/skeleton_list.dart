import 'package:flutter/material.dart';

/// Marcador de posición para listados mientras cargan: filas grises que laten
/// suavemente. Se siente más rápido que un spinner centrado y evita que la
/// pantalla "salte" cuando llegan los datos.
///
/// No usa paquetes externos. Respeta el tema (claro/oscuro) y no anima si el
/// sistema pide reducir movimiento.
class SkeletonList extends StatefulWidget {
  /// Cantidad de filas a dibujar.
  final int itemCount;

  /// Alto de cada fila.
  final double itemHeight;

  /// Padding exterior de la lista.
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.itemCount = 8,
    this.itemHeight = 56,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: 'Cargando',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final opacity = 0.06 + 0.07 * _controller.value;
          final color = onSurface.withValues(alpha: opacity);
          return ListView.separated(
            padding: widget.padding,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.itemCount,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _fila(color, i),
          );
        },
      ),
    );
  }

  Widget _fila(Color color, int i) {
    // Anchos que varían por fila para que no parezca una rejilla artificial.
    final factor = 0.45 + 0.35 * ((i * 37) % 10) / 10;
    return SizedBox(
      height: widget.itemHeight,
      child: Row(
        children: [
          Container(
            width: widget.itemHeight * 0.8,
            height: widget.itemHeight * 0.8,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: factor,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: factor * 0.6,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
