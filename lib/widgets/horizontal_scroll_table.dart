import 'package:flutter/material.dart';

/// Envuelve una tabla armada a mano (encabezado + filas con columnas de
/// ancho fijo en píxeles) en un scroll horizontal con barra visible, para
/// que en pantallas angostas (celular) las columnas no se compriman ni
/// trunquen el contenido — el usuario desliza lateralmente en vez de perder
/// texto.
///
/// El [child] debe ser una `Column` cuyo encabezado y filas usen `SizedBox`
/// de ancho fijo (no `Expanded`/`flex`) para cada columna, y la suma de esos
/// anchos (+ padding) debe coincidir con [contentWidth].
class HorizontalScrollTable extends StatefulWidget {
  final double contentWidth;
  final Widget child;

  const HorizontalScrollTable({
    super.key,
    required this.contentWidth,
    required this.child,
  });

  @override
  State<HorizontalScrollTable> createState() => _HorizontalScrollTableState();
}

class _HorizontalScrollTableState extends State<HorizontalScrollTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoFinal = widget.contentWidth > constraints.maxWidth
            ? widget.contentWidth
            : constraints.maxWidth;
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: anchoFinal, child: widget.child),
          ),
        );
      },
    );
  }
}

/// Columna de encabezado de ancho fijo (reemplaza `Expanded(flex: ...)` en
/// tablas dentro de un [HorizontalScrollTable]).
Widget buildEncabezadoColumnaFija(
  BuildContext context,
  String texto, {
  required double width,
  TextAlign align = TextAlign.left,
}) {
  return SizedBox(
    width: width,
    child: Text(
      texto,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      textAlign: align,
    ),
  );
}
