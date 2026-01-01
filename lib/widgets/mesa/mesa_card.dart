import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/mesa.dart';
import '../../models/pedido.dart';
import '../../providers/user_provider.dart';
import '../../utils/format_utils.dart';
import '../../screens/pedido_screen.dart';

class MesaCard extends StatefulWidget {
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
  State<MesaCard> createState() => _MesaCardState();
}

class _MesaCardState extends State<MesaCard> {
  bool _isProcessing = false; // ✅ SOLUCIÓN: Flag para prevenir doble click

  @override
  Widget build(BuildContext context) {
    bool isOcupada = widget.mesa.ocupada || widget.mesa.total > 0;

    // ✅ OPTIMIZACIÓN: Verificación en tiempo real deshabilitada
    // Esta llamada hacía una petición a la API por cada mesa en cada build
    // causando lentitud extrema. Ahora se confía en los datos del modelo Mesa
    // que se actualizan vía WebSocket y recargas después de operaciones.

    Color statusColor = isOcupada ? AppTheme.error : AppTheme.success;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    bool canProcessPayment =
        userProvider.isAdmin && isOcupada && widget.mesa.total > 0;

    return LayoutBuilder(
      key: ValueKey('mesa_card_${widget.mesa.id}_${widget.widgetRebuildKey}'),
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () async {
            // ✅ SOLUCIÓN MEJORADA: Prevenir doble click con timeout corto
            if (_isProcessing) {
              print(
                '⚠️ [DOBLE_CLICK] Mesa ${widget.mesa.nombre} ya está siendo procesada',
              );
              return;
            }

            // Activar flag para prevenir doble click (500ms de bloqueo optimizado)
            setState(() {
              _isProcessing = true;
            });

            // Liberar el flag después de 500ms para evitar doble clicks accidentales
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                });
              }
            });

            try {
              // ✅ SOLUCIÓN: Verificar si existe un pedido activo antes de navegar
              print('🔍 [CONCURRENCIA] Click en mesa ${widget.mesa.nombre}');
              print('   • Estado ocupada: ${widget.mesa.ocupada}');
              print('   • Total: ${widget.mesa.total}');

              Pedido? pedidoExistente;

              // Solo buscar pedido existente si la mesa parece ocupada
              if (widget.mesa.ocupada || widget.mesa.total > 0) {
                print('   • Buscando pedido activo existente...');
                try {
                  pedidoExistente = await widget.onObtenerPedidoActivo(
                    widget.mesa,
                  );
                  if (pedidoExistente != null) {
                    print(
                      '   ✅ Pedido existente encontrado: ${pedidoExistente.id}',
                    );
                    print(
                      '   • Items en pedido: ${pedidoExistente.items.length}',
                    );
                    print('   • Total del pedido: ${pedidoExistente.total}');
                  } else {
                    print(
                      '   ⚠️ No se encontró pedido activo (posible inconsistencia)',
                    );
                  }
                } catch (e) {
                  print('   ❌ Error al obtener pedido activo: $e');
                }
              } else {
                print('   • Mesa libre, creando nuevo pedido');
              }

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PedidoScreen(
                    mesa: widget.mesa,
                    pedidoExistente:
                        pedidoExistente, // ✅ Pasar el pedido existente si lo hay
                  ),
                ),
              );

              // Si se creó o actualizó un pedido, recargar las mesas
              if (result == true) {
                widget.onRecargarMesas();
              }
              
              // Liberar el flag inmediatamente después de navegar
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                });
              }
            } catch (e) {
              print('❌ Error al navegar a pedido: $e');
              // Asegurar que el flag se libere en caso de error
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                });
              }
            }
          },
          onLongPress: userProvider.isAdmin
              ? () => widget.onMostrarMenuMesa(widget.mesa)
              : null,
          child: Container(
            decoration: BoxDecoration(
              gradient: isOcupada ? AppTheme.cardGradient : null,
              color: isOcupada ? null : AppTheme.cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: _isProcessing
                    ? Colors
                          .orange // Color especial cuando está procesando
                    : isOcupada
                    ? AppTheme.primary.withOpacity(0.6)
                    : statusColor.withOpacity(0.3),
                width: _isProcessing ? 3 : 2, // Borde más grueso cuando procesa
              ),
              boxShadow: [
                ...AppTheme.cardShadow,
                if (isOcupada) ...AppTheme.primaryShadow,
                if (_isProcessing)
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(constraints.maxWidth * 0.08),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Indicador de estado superior
                      Container(
                        width: double.infinity,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _isProcessing ? Colors.orange : statusColor,
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
                                widget.mesa.nombre,
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
                                [
                                  'CAJA',
                                  'DOMICILIO',
                                  'MESA AUXILIAR',
                                ].contains(widget.mesa.nombre.toUpperCase()))
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
                      if (widget.mesa.total > 0)
                    _buildTotalSection(context, constraints, canProcessPayment),
                    ],
                  ),
                ),

                // Indicador de procesamiento
                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Procesando...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
                // ✅ SOLUCIÓN MEJORADA: Prevenir doble click con timeout optimizado
                if (_isProcessing) {
                  print('⚠️ [DOBLE_CLICK] Botón de pago ya procesándose');
                  return;
                }

                setState(() {
                  _isProcessing = true;
                });

                // Liberar el flag después de 800ms (optimizado para rapidez)
                Future.delayed(Duration(milliseconds: 800), () {
                  if (mounted) {
                    setState(() {
                      _isProcessing = false;
                    });
                  }
                });

                try {
                  // Solo mostrar menú de pago si hay pedido activo
                  if (widget.mesa.ocupada && widget.mesa.total > 0) {
                    print(
                      '💳 [PAGO] Iniciando proceso de pago para mesa ${widget.mesa.nombre}',
                    );
                    final pedido = await widget.onObtenerPedidoActivo(
                      widget.mesa,
                    );
                    if (pedido != null) {
                      print('💳 [PAGO] Pedido activo encontrado: ${pedido.id}');
                      widget.onMostrarDialogoPago(widget.mesa, pedido);
                    } else {
                      print('❌ [PAGO] No se encontró pedido activo para pagar');
                    }
                  }
                } catch (e) {
                  print('❌ [PAGO] Error al procesar pago: $e');
                  // Asegurar que el flag se libere en caso de error
                  if (mounted) {
                    setState(() {
                      _isProcessing = false;
                    });
                  }
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
    return FutureBuilder<Pedido?>(
      future: widget.onObtenerPedidoActivo(widget.mesa),
      builder: (context, snapshot) {
        // ✅ CORRECCIÓN: Calcular total desde items del pedido en tiempo real
        double totalReal = widget.mesa.total;

        if (snapshot.hasData && snapshot.data != null) {
          final pedido = snapshot.data!;
          // Calcular desde item.subtotal que incluye descuentos
          totalReal = pedido.items.fold<double>(
            0,
            (sum, item) => sum + item.subtotal,
          );
        }

        final valorFormateado = formatCurrency(totalReal);

        // Detectar si hay caracteres raros
        if (valorFormateado.contains(RegExp(r'[^\d\.\$\-]'))) {
          print('🔴 CORRUPCIÓN DETECTADA EN MESA ${widget.mesa.nombre}:');
          print(
            '  - Valor original: $totalReal (${totalReal.runtimeType})',
          );
          print('  - Valor formateado: "$valorFormateado"');
          print(
            '  - Caracteres: ${valorFormateado.runes.map((c) => '${String.fromCharCode(c)} ($c)').join(', ')}',
          );

          final fallback = formatCurrency(totalReal);
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
