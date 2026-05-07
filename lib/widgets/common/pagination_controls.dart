import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PaginationControls extends StatelessWidget {
  final int totalElementos;
  final int paginaActual;
  final int itemsPorPagina;
  final VoidCallback onPaginaAnterior;
  final VoidCallback onSiguientePagina;
  final void Function(int) onItemsPorPaginaChanged;

  const PaginationControls({
    super.key,
    required this.totalElementos,
    required this.paginaActual,
    required this.itemsPorPagina,
    required this.onPaginaAnterior,
    required this.onSiguientePagina,
    required this.onItemsPorPaginaChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalPaginas = (totalElementos / itemsPorPagina).ceil();

    if (totalPaginas <= 1) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          top: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 18),
            color: paginaActual > 0 ? AppTheme.primary : AppTheme.textMuted,
            onPressed: paginaActual > 0 ? onPaginaAnterior : null,
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Página ${paginaActual + 1} de $totalPaginas',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$totalElementos productos',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, size: 18),
            color: paginaActual < totalPaginas - 1
                ? AppTheme.primary
                : AppTheme.textMuted,
            onPressed: paginaActual < totalPaginas - 1
                ? onSiguientePagina
                : null,
          ),
          Container(
            margin: EdgeInsets.only(left: 16),
            padding: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: itemsPorPagina,
                dropdownColor: AppTheme.cardBg,
                icon: Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                style: TextStyle(color: AppTheme.textPrimary),
                items: [5, 10, 20, 50, 100].map<DropdownMenuItem<int>>((
                  int value,
                ) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value por página'),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    onItemsPorPaginaChanged(newValue);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
