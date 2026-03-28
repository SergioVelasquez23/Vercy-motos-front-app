import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Mixin de paginación cliente-side.
/// Agrega a cualquier State: _paginaActual, _itemsPorPagina,
/// paginarLista() y los controles de navegación.
mixin PaginacionMixin<T extends StatefulWidget> on State<T> {
  int _paginaActual = 0;
  int _itemsPorPagina = 20;

  int get paginaActual => _paginaActual;
  int get itemsPorPagina => _itemsPorPagina;

  /// Devuelve el subconjunto de [lista] para la página actual.
  List<E> paginarLista<E>(List<E> lista) {
    if (lista.isEmpty) return [];
    final inicio = _paginaActual * _itemsPorPagina;
    if (inicio >= lista.length) {
      // Si la página actual ya no existe (filtro redujo resultados), ir a la 0
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _paginaActual = 0);
      });
      return lista.take(_itemsPorPagina).toList();
    }
    final fin = (inicio + _itemsPorPagina).clamp(0, lista.length);
    return lista.sublist(inicio, fin);
  }

  int totalPaginas(int totalItems) =>
      (totalItems / _itemsPorPagina).ceil().clamp(1, 99999);

  void irPagina(int pagina) => setState(() => _paginaActual = pagina);
  void paginaSiguiente(int total) {
    if (_paginaActual < totalPaginas(total) - 1) {
      setState(() => _paginaActual++);
    }
  }
  void paginaAnterior() {
    if (_paginaActual > 0) setState(() => _paginaActual--);
  }
  void resetPagina() => setState(() => _paginaActual = 0);

  /// Widget de controles de paginación listo para usar.
  Widget buildPaginacion({
    required int totalItems,
    Color? accentColor,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();
    final total = totalPaginas(totalItems);
    final inicio = _paginaActual * _itemsPorPagina + 1;
    final fin = ((_paginaActual + 1) * _itemsPorPagina).clamp(0, totalItems);
    final color = accentColor ?? AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Info
          Text(
            'Mostrando $inicio–$fin de $totalItems',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          // Controles
          Row(
            children: [
              // Items por página
              DropdownButton<int>(
                value: _itemsPorPagina,
                dropdownColor: AppTheme.cardBg,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                underline: const SizedBox.shrink(),
                items: [10, 20, 50, 100].map((v) => DropdownMenuItem(
                  value: v,
                  child: Text('$v / pág'),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setState(() { _itemsPorPagina = v; _paginaActual = 0; });
                },
              ),
              const SizedBox(width: 16),
              // Anterior
              IconButton(
                icon: Icon(Icons.chevron_left,
                    color: _paginaActual > 0 ? color : Colors.grey),
                onPressed: _paginaActual > 0 ? paginaAnterior : null,
                tooltip: 'Página anterior',
              ),
              // Páginas numéricas
              ..._buildPaginasNumericas(total, color),
              // Siguiente
              IconButton(
                icon: Icon(Icons.chevron_right,
                    color: _paginaActual < total - 1 ? color : Colors.grey),
                onPressed:
                    _paginaActual < total - 1 ? () => paginaSiguiente(totalItems) : null,
                tooltip: 'Página siguiente',
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPaginasNumericas(int total, Color color) {
    if (total <= 1) return [];
    final widgets = <Widget>[];
    // Mostrar máx 5 botones centrados en la página actual
    int start = (_paginaActual - 2).clamp(0, (total - 5).clamp(0, total));
    int end = (start + 5).clamp(0, total);

    if (start > 0) {
      widgets.add(_pageBtn(0, color));
      if (start > 1) widgets.add(Text(' … ', style: TextStyle(color: AppTheme.textSecondary)));
    }
    for (int i = start; i < end; i++) {
      widgets.add(_pageBtn(i, color));
    }
    if (end < total) {
      if (end < total - 1) widgets.add(Text(' … ', style: TextStyle(color: AppTheme.textSecondary)));
      widgets.add(_pageBtn(total - 1, color));
    }
    return widgets;
  }

  Widget _pageBtn(int page, Color color) {
    final isActive = page == _paginaActual;
    return GestureDetector(
      onTap: () => irPagina(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 32, height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? color : Colors.white24),
        ),
        child: Text(
          '${page + 1}',
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
