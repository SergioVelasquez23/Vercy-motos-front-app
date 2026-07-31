import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Encabezado de la pantalla de facturación: título + botón "Facturas en
/// borrador". Puramente visual — copiado tal cual de
/// facturacion_screen.dart, sin ningún cambio de lógica.
class FacturacionHeaderSection extends StatelessWidget {
  final VoidCallback onMostrarBorradores;
  final VoidCallback? onVerBorradoresLocales;
  final int borradoresLocalesCount;

  const FacturacionHeaderSection({
    super.key,
    required this.onMostrarBorradores,
    this.onVerBorradoresLocales,
    this.borradoresLocalesCount = 0,
  });

  /// Ícono de "borradores locales" (guardados en este dispositivo por un
  /// fallo al guardar y pagar, ej. caja cerrada) con contador. Solo se
  /// muestra si hay al menos uno, para no saturar la barra en el caso normal.
  Widget _buildBotonBorradoresLocales() {
    if (onVerBorradoresLocales == null || borradoresLocalesCount == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton.filledTonal(
            onPressed: onVerBorradoresLocales,
            icon: const Icon(Icons.warning_amber_rounded),
            color: AppTheme.warning,
            tooltip: 'Borradores locales sin guardar por un error',
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$borradoresLocalesCount',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 500;

        return Container(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Crear factura',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onMostrarBorradores,
                            icon: Icon(Icons.drafts, size: 18),
                            label: Text(
                              'Facturas en borrador',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        _buildBotonBorradoresLocales(),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(Icons.receipt_long, color: AppTheme.primary, size: 32),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Crear factura',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Spacer(),
                    ElevatedButton.icon(
                      onPressed: onMostrarBorradores,
                      icon: Icon(Icons.drafts),
                      label: Text(
                        'Facturas en borrador',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                    _buildBotonBorradoresLocales(),
                  ],
                ),
        );
      },
    );
  }
}
