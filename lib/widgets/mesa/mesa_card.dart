import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/mesa.dart';
import '../../models/pedido.dart';
import '../../providers/user_provider.dart';
import '../../utils/format_utils.dart';
import '../../screens/pedido_screen.dart';

class MesaCard extends StatelessWidget {
  final Mesa mesa;
  final int widgetRebuildKey;
  final VoidCallback onRecargarMesas;
  final Function(Mesa) onMostrarMenuMesa;
  final Function(Mesa, Pedido) onMostrarDialogoPago;
  final Future<Pedido?> Function(Mesa) onObtenerPedidoActivo;
  final Function(Mesa) onVerificarEstadoReal;

  const MesaCard({
    super.key,
    required this.mesa,
    required this.widgetRebuildKey,
    required this.onRecargarMesas,
    required this.onMostrarMenuMesa,
    required this.onMostrarDialogoPago,
    required this.onObtenerPedidoActivo,
    required this.onVerificarEstadoReal,
  });

  @override
  Widget build(BuildContext context) {
    bool isOcupada = mesa.ocupada || mesa.total > 0;

    // ✅ OPTIMIZACIÓN: Logs de debug comentados para mejorar rendimiento
    // final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    // print('🏗️ [$timestamp] ===== CONSTRUYENDO CARD ${mesa.nombre} =====');
    // print('🔍 Mesa ID: ${mesa.id}');
    // print('🔍 Mesa.ocupada: ${mesa.ocupada}');
    // print('🔍 Mesa.total: ${mesa.total}');
    // print('🔍 isOcupada calculado: $isOcupada');
    // print('🔍 Widget key: mesa_card_${mesa.id}_$widgetRebuildKey');
    // print('🔍 Rebuild key actual: $widgetRebuildKey');

    // VERIFICACIÓN ADICIONAL: obtener pedidos en tiempo real para comparar
    onVerificarEstadoReal(mesa);

    Color statusColor = isOcupada ? AppTheme.error : AppTheme.success;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    bool canProcessPayment =
        userProvider.isAdmin && isOcupada && mesa.total > 0;

    return LayoutBuilder(
      key: ValueKey('mesa_card_${mesa.id}_$widgetRebuildKey'),
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PedidoScreen(mesa: mesa)),
            );
            // Si se creó o actualizó un pedido, recargar las mesas
            if (result == true) {
              onRecargarMesas();
            }
          },
          onLongPress: userProvider.isAdmin
              ? () => onMostrarMenuMesa(mesa)
              : null,
          child: Container(
            decoration: BoxDecoration(
              gradient: isOcupada ? AppTheme.cardGradient : null,
              color: isOcupada ? null : AppTheme.cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: isOcupada
                    ? AppTheme.primary.withOpacity(0.6)
                    : statusColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                ...AppTheme.cardShadow,
                if (isOcupada) ...AppTheme.primaryShadow,
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(constraints.maxWidth * 0.08),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Indicador de estado superior
                  Container(
                    width: double.infinity,
                    height: 3,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusSmall / 2,
                      ),
                    ),
                  ),

                  // Icono de mesa
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.all(constraints.maxWidth * 0.08),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: FittedBox(
                        child: Icon(
                          Icons.table_restaurant,
                          color: AppTheme.primary,
                          size: constraints.maxWidth * 0.15,
                        ),
                      ),
                    ),
                  ),

                  // Nombre de la mesa
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingSmall,
                            vertical: AppTheme.spacingXSmall,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: Text(
                            mesa.nombre,
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: constraints.maxWidth * 0.13,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Espacio extra si está disponible y es mesa especial
                        if (!isOcupada &&
                            mesa.tipo != null &&
                            mesa.tipo != 'NORMAL')
                          SizedBox(height: constraints.maxHeight * 0.03),
                      ],
                    ),
                  ),

                  // Estado
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingXSmall,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        border: Border.all(
                          color: statusColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: AppTheme.spacingXSmall),
                          Flexible(
                            child: Text(
                              isOcupada ? 'Ocupada' : 'Disponible',
                              style: AppTheme.labelMedium.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: constraints.maxWidth * 0.09,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Total si existe
                  if (mesa.total > 0)
                    _buildTotalSection(context, constraints, canProcessPayment),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTotalSection(
    BuildContext context,
    BoxConstraints constraints,
    bool canProcessPayment,
  ) {
    return Flexible(
      child: canProcessPayment
          ? GestureDetector(
              onTap: () async {
                final pedido = await onObtenerPedidoActivo(mesa);
                if (pedido != null) {
                  onMostrarDialogoPago(mesa, pedido);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'No se encontró un pedido activo para esta mesa',
                      ),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.all(4),
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSmall,
                  vertical: AppTheme.spacingXSmall,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.payment,
                      size: constraints.maxWidth * 0.08,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Expanded(child: _buildTotalText(constraints, Colors.white)),
                  ],
                ),
              ),
            )
          : Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSmall,
                vertical: AppTheme.spacingXSmall,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: _buildTotalText(constraints, AppTheme.primary),
            ),
    );
  }

  Widget _buildTotalText(BoxConstraints constraints, Color color) {
    return Builder(
      builder: (context) {
        final valorOriginal = mesa.total;
        final valorFormateado = formatCurrency(valorOriginal);

        // Detectar si hay caracteres raros
        if (valorFormateado.contains(RegExp(r'[^\d\.\$\-]'))) {
          print('🔴 CORRUPCIÓN DETECTADA EN MESA ${mesa.nombre}:');
          print(
            '  - Valor original: $valorOriginal (${valorOriginal.runtimeType})',
          );
          print('  - Valor formateado: "$valorFormateado"');
          print(
            '  - Caracteres: ${valorFormateado.runes.map((c) => '${String.fromCharCode(c)} ($c)').join(', ')}',
          );

          final fallback = formatCurrency(valorOriginal);
          print('  - Usando fallback: "$fallback"');

          return Text(
            fallback,
            style: AppTheme.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: constraints.maxWidth * 0.09,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        return Text(
          valorFormateado,
          style: AppTheme.labelMedium.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: constraints.maxWidth * 0.08,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
