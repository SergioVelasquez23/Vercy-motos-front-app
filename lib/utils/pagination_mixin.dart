import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Sentinel que representa un "…" dentro de la lista de slots de paginación.
const int _kEllipsis = -1;

/// Mixin de paginación reutilizable.
///
/// Aporta a cualquier State: [paginaActual], [itemsPorPagina], [paginarLista]
/// (para paginación cliente-side) y [buildPaginacion] (la barra de controles).
///
/// La barra de controles:
///  - Tiene **ancho estable**: para un mismo `sibling` el número de slots NO
///    cambia al navegar, así no "salta" ni se desplaza entre página y página.
///  - Nunca desborda: los controles van dentro de un scroll horizontal, así
///    que si no caben se scrollean en vez de recortarse.
///  - Es responsive al **ancho real disponible** (vía LayoutBuilder), no al
///    ancho de la ventana — responde a colapsar/expandir el menú lateral.
mixin PaginacionMixin<T extends StatefulWidget> on State<T> {
  int _paginaActual = 0;
  // null = usar [itemsPorPaginaPorDefecto]; se fija al elegir en el dropdown.
  int? _itemsPorPaginaSel;
  Timer? _navDebounce;

  /// Tamaño de página inicial. Sobrescribir en la pantalla para arrancar con
  /// más filas por página (p. ej. 50 en listas donde "caben muchas").
  @protected
  int get itemsPorPaginaPorDefecto => 20;

  int get paginaActual => _paginaActual;
  int get itemsPorPagina => _itemsPorPaginaSel ?? itemsPorPaginaPorDefecto;

  /// Devuelve el subconjunto de [lista] para la página actual (cliente-side).
  List<E> paginarLista<E>(List<E> lista) {
    if (lista.isEmpty) return [];
    final inicio = _paginaActual * itemsPorPagina;
    if (inicio >= lista.length) {
      // La página actual ya no existe (un filtro redujo los resultados): al 0.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _paginaActual != 0) setState(() => _paginaActual = 0);
      });
      return lista.take(itemsPorPagina).toList();
    }
    final fin = (inicio + itemsPorPagina).clamp(0, lista.length);
    return lista.sublist(inicio, fin);
  }

  int totalPaginas(int totalItems) =>
      (totalItems / itemsPorPagina).ceil().clamp(1, 99999);

  /// Se invoca (con debounce) al cambiar de página o de tamaño de página.
  /// Cliente-side no necesita hacer nada; las pantallas que paginan contra el
  /// servidor lo sobrescriben para volver a pedir la página.
  void onCambioPagina() {}

  /// Cambia la página resaltada de inmediato pero agenda [onCambioPagina] una
  /// sola vez ~280 ms después del último cambio. Así varios clics rápidos en
  /// "siguiente" = una única recarga (la de la página final), sin carreras
  /// entre respuestas de páginas intermedias.
  void _agendarCambioPagina() {
    _navDebounce?.cancel();
    _navDebounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) onCambioPagina();
    });
  }

  void irPagina(int pagina) {
    if (pagina == _paginaActual || pagina < 0) return;
    setState(() => _paginaActual = pagina);
    _agendarCambioPagina();
  }

  void paginaSiguiente(int totalItems) {
    final ultima = totalPaginas(totalItems) - 1;
    if (_paginaActual >= ultima) return;
    setState(() => _paginaActual++);
    _agendarCambioPagina();
  }

  void paginaAnterior() {
    if (_paginaActual <= 0) return;
    setState(() => _paginaActual--);
    _agendarCambioPagina();
  }

  void resetPagina() {
    if (_paginaActual == 0) return;
    setState(() => _paginaActual = 0);
    _agendarCambioPagina();
  }

  @override
  void dispose() {
    _navDebounce?.cancel();
    super.dispose();
  }

  // ─────────────────────────── UI ───────────────────────────

  /// Barra de paginación lista para usar.
  ///
  /// [totalItems] es el total de registros (del servidor si la pantalla pagina
  /// contra el servidor, o `lista.length` si es cliente-side).
  Widget buildPaginacion({
    required int totalItems,
    Color? accentColor,
  }) {
    if (totalItems <= 0) return const SizedBox.shrink();

    final color = accentColor ?? AppTheme.primary;
    final total = totalPaginas(totalItems);

    // Si la página quedó fuera de rango (un refresh redujo el total), corregir
    // tras el frame en vez de pintar "Mostrando 401–3 de 3".
    if (_paginaActual >= total) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final t = totalPaginas(totalItems);
        if (mounted && _paginaActual >= t) {
          setState(() => _paginaActual = t - 1);
          _agendarCambioPagina();
        }
      });
    }

    final pagina = _paginaActual.clamp(0, total - 1);
    final inicio = pagina * itemsPorPagina + 1;
    final fin = ((pagina + 1) * itemsPorPagina).clamp(0, totalItems);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          // Páginas a cada lado de la actual, según el ANCHO REAL disponible.
          // Cada slot ~34px; se reservan ~200px para dropdown + flechas.
          final double stripAncho = w - 200;
          final int sibling = stripAncho >= 340
              ? 3
              : stripAncho >= 270
                  ? 2
                  : stripAncho >= 200
                      ? 1
                      : 0;

          final info = Text(
            'Mostrando $inicio–$fin de $totalItems',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          );

          final children = <Widget>[
            DropdownButton<int>(
              value: itemsPorPagina,
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(color: onSurface, fontSize: 13),
              underline: const SizedBox.shrink(),
              isDense: true,
              // Incluye el valor actual aunque no sea una de las opciones fijas
              // (una pantalla puede arrancar en 50 vía itemsPorPaginaPorDefecto).
              // 200 es el tope: el backend limita `size` a 200 en
              // /documentos/todos/pagados (Math.min(size, 200)), así que pedir
              // más descuadraría la paginación (traería 200 pero contaría 500).
              items: (<int>{10, 20, 50, 100, 200, itemsPorPagina}.toList()..sort())
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v / pág')))
                  .toList(),
              onChanged: (v) {
                if (v == null || v == itemsPorPagina) return;
                setState(() {
                  _itemsPorPaginaSel = v;
                  _paginaActual = 0;
                });
                _agendarCambioPagina();
              },
            ),
            const SizedBox(width: 8),
            _navBtn(Icons.chevron_left, pagina > 0 ? paginaAnterior : null,
                color, 'Página anterior'),
            for (final slot in slotsPaginacion(total, sibling))
              slot == _kEllipsis ? _ellipsis(onSurface) : _pageBtn(slot - 1, color),
            _navBtn(
                Icons.chevron_right,
                pagina < total - 1 ? () => paginaSiguiente(totalItems) : null,
                color,
                'Página siguiente'),
          ];

          // Controles SIEMPRE dentro de un scroll horizontal: si caben quedan
          // centrados; si no, se scrollean — nunca se recortan ni desbordan.
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              info,
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    // Si los controles caben, ocupan todo el ancho y quedan
                    // centrados; si no, el Row crece y el scroll se activa.
                    constraints: BoxConstraints(minWidth: w.isFinite ? w : 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: children,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Lista **estable** de slots a pintar: números de página (1-indexed) e
  /// [_kEllipsis]. Reglas fijas:
  ///  - Siempre se muestran la primera y la última página.
  ///  - Siempre se muestran la actual y [sibling] páginas a cada lado.
  ///  - Se usa "…" solo cuando entre dos números mostrados hay un salto > 1.
  ///  - Si un "…" taparía **una sola** página, se pinta esa página en su
  ///    lugar → el número de slots no cambia al navegar (ancho estable).
  ///
  /// `-1` (== [_kEllipsis]) representa un "…".
  @visibleForTesting
  List<int> slotsPaginacion(int total, int sibling) {
    if (total <= 1) return const [];
    final current = (_paginaActual + 1).clamp(1, total);
    const boundary = 1; // páginas fijas al principio y al final

    // ¿Caben todas sin ningún "…"? (first + hueco + ventana + hueco + last)
    final maxSinElipsis = boundary * 2 + sibling * 2 + 3;
    if (total <= maxSinElipsis) {
      return [for (var i = 1; i <= total; i++) i];
    }

    // Ventana de (2*sibling + 1) páginas centrada en la actual, sin pisar los
    // bordes ni dejar huecos de tamaño 1 contra ellos.
    final int siblingsStart = (current - sibling)
        .clamp(boundary + 2, total - boundary - sibling * 2 - 1);
    final int siblingsEnd = (current + sibling)
        .clamp(boundary + sibling * 2 + 2, total - boundary - 1);

    return [
      for (var i = 1; i <= boundary; i++) i,
      if (siblingsStart > boundary + 2)
        _kEllipsis
      else if (boundary + 1 < total - boundary)
        boundary + 1,
      for (var i = siblingsStart; i <= siblingsEnd; i++) i,
      if (siblingsEnd < total - boundary - 1)
        _kEllipsis
      else if (total - boundary > boundary)
        total - boundary,
      for (var i = total - boundary + 1; i <= total; i++) i,
    ];
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap, Color color, String tip) {
    return IconButton(
      icon: Icon(icon, size: 22, color: onTap != null ? color : Colors.grey),
      onPressed: onTap,
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _ellipsis(Color onSurface) {
    return Container(
      width: 26,
      height: 32,
      alignment: Alignment.center,
      child: Text('…',
          style: TextStyle(color: onSurface.withValues(alpha: 0.5), fontSize: 15)),
    );
  }

  Widget _pageBtn(int page, Color color) {
    final isActive = page == _paginaActual;
    return GestureDetector(
      onTap: isActive ? null : () => irPagina(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? color : Colors.white24),
        ),
        child: Text(
          '${page + 1}',
          style: TextStyle(
            color: isActive
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
