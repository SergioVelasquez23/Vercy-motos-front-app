import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/mesa.dart';
import '../models/pedido.dart';
import '../services/pedido_service.dart';
import '../services/mesa_service.dart';
import '../services/notification_service.dart';
import '../providers/user_provider.dart';
import 'pedido_screen.dart';

class MesasScreen extends StatefulWidget {
  const MesasScreen({Key? key}) : super(key: key);

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  final MesaService _mesaService = MesaService();
  final PedidoService _pedidoService = PedidoService();
  List<Mesa> mesas = [];
  bool isLoading = true;
  String? errorMessage;

  // Subscripciones para actualizaciones en tiempo real
  late StreamSubscription<bool> _pedidoCompletadoSubscription;
  late StreamSubscription<bool> _pedidoPagadoSubscription;

  static const _cardBg = Color(0xFF252525);
  static const _textLight = Color(0xFFE0E0E0);
  static const _primary = Color(0xFFFF6B00);

  @override
  void initState() {
    super.initState();
    _loadMesas();
    _configurarWebSockets();
    _iniciarSincronizacion();
  }

  void _iniciarSincronizacion() {
    // Sincronización deshabilitada
  }

  @override
  void dispose() {
    // Limpiar subscripciones
    _pedidoCompletadoSubscription.cancel();
    _pedidoPagadoSubscription.cancel();
    super.dispose();
  }

  void _configurarWebSockets() {
    // Suscribirse a eventos de pedidos completados
    _pedidoCompletadoSubscription = _pedidoService.onPedidoCompletado.listen((
      _,
    ) {
      print('🔄 MesasScreen: Pedido completado detectado, recargando mesas');
      _loadMesas();
    });

    // Suscribirse a eventos de pedidos pagados
    _pedidoPagadoSubscription = _pedidoService.onPedidoPagado.listen((_) {
      print('💰 MesasScreen: Pago detectado, recargando mesas');
      _loadMesas();
    });
  }

  Future<void> _loadMesas() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Cargar las mesas
      final loadedMesas = await _mesaService.getMesas();

      // Sincronizar estado de mesas con pedidos activos
      await _sincronizarEstadoMesas(loadedMesas);

      setState(() {
        mesas = loadedMesas;
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = 'Error al cargar mesas: $error';
        isLoading = false;
      });
    }
  }

  Future<void> _sincronizarEstadoMesas(List<Mesa> mesas) async {
    print(
      '🔄 Sincronizando estado de ${mesas.length} mesas con pedidos activos...',
    );

    for (Mesa mesa in mesas) {
      try {
        // Solo verificar mesas que aparecen como ocupadas
        if (mesa.ocupada || mesa.total > 0) {
          final pedidos = await _pedidoService.getPedidosByMesa(mesa.nombre);
          final hayPedidoActivo = pedidos.any(
            (pedido) => pedido.estado == EstadoPedido.activo,
          );

          if (!hayPedidoActivo) {
            print(
              '⚠️ Mesa ${mesa.nombre}: Sin pedidos activos, liberando mesa...',
            );

            // Si no hay pedidos activos pero la mesa aparece ocupada, liberarla
            if (mesa.ocupada || mesa.total > 0) {
              mesa.ocupada = false;
              mesa.productos = [];
              mesa.total = 0.0;

              try {
                await _mesaService.updateMesa(mesa);
                print('✅ Mesa ${mesa.nombre} liberada automáticamente');
              } catch (e) {
                print('❌ Error al liberar mesa ${mesa.nombre}: $e');
              }
            }
          } else {
            print('✅ Mesa ${mesa.nombre}: Pedido activo confirmado');
          }
        }
      } catch (e) {
        print('❌ Error verificando mesa ${mesa.nombre}: $e');
      }
    }
  }

  Future<Pedido?> _obtenerPedidoActivoDeMesa(Mesa mesa) async {
    try {
      print('🔍 Buscando pedido activo para mesa: ${mesa.id}');

      // Siempre buscar en el servidor para obtener el ID más actualizado
      final pedidos = await _pedidoService.getPedidosByMesa(mesa.nombre);
      print('📋 Pedidos encontrados para la mesa: ${pedidos.length}');

      final pedidoActivo = pedidos.firstWhere(
        (pedido) => pedido.estado == EstadoPedido.activo,
        orElse: () => throw Exception('No hay pedido activo'),
      );

      print(
        '✅ Pedido activo encontrado - ID: "${pedidoActivo.id}" - Mesa: ${pedidoActivo.mesa}',
      );

      // Verificar que el ID no esté vacío
      if (pedidoActivo.id.isEmpty) {
        print('❌ ERROR: El pedido activo no tiene ID válido');
        throw Exception('El pedido activo no tiene ID válido');
      }

      return pedidoActivo;
    } catch (e) {
      print('❌ Error al obtener pedido activo: $e');

      // Si no hay pedido activo pero la mesa aparece ocupada, corregir automáticamente
      if (mesa.ocupada || mesa.total > 0) {
        print(
          '🔧 Corrigiendo estado de mesa ${mesa.nombre} sin pedidos activos...',
        );
        try {
          mesa.ocupada = false;
          mesa.productos = [];
          mesa.total = 0.0;
          await _mesaService.updateMesa(mesa);
          print('✅ Mesa ${mesa.nombre} corregida automáticamente');

          // Recargar las mesas para reflejar el cambio en la UI
          _loadMesas();
        } catch (updateError) {
          print('❌ Error al corregir mesa ${mesa.nombre}: $updateError');
        }
      }

      return null;
    }
  }

  void _mostrarMenuMesa(Mesa mesa) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mesa ${mesa.nombre}',
                style: TextStyle(
                  color: _textLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.sync, color: _primary),
                title: Text(
                  'Sincronizar estado con pedidos',
                  style: TextStyle(color: _textLight),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _sincronizarMesa(mesa);
                },
              ),
              if (mesa.ocupada) ...[
                ListTile(
                  leading: Icon(Icons.cleaning_services, color: _primary),
                  title: Text(
                    'Vaciar mesa manualmente',
                    style: TextStyle(color: _textLight),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _vaciarMesaManualmente(mesa);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _mostrarDialogoForzarLimpieza() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          '¿Restaurar todas las mesas?',
          style: TextStyle(color: _textLight),
        ),
        content: Text(
          'Esta acción marcará TODAS las mesas como disponibles y eliminará todos los productos asociados. Esta operación es útil cuando se han eliminado manualmente los pedidos de la base de datos y las mesas han quedado desincronizadas.\n\n¿Desea continuar?',
          style: TextStyle(color: _textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Restaurar Todo'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        setState(() {
          isLoading = true;
        });

        // Funcionalidad de limpieza deshabilitada
        int mesasLimpiadas = 0;

        // Recargar las mesas
        await _loadMesas();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$mesasLimpiadas mesas han sido restauradas correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar mesas: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _vaciarMesaManualmente(Mesa mesa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('¿Vaciar mesa?', style: TextStyle(color: _textLight)),
        content: Text(
          'Esta acción marcará la mesa como disponible y eliminará todos los productos asociados. Esto NO afectará a los pedidos existentes en el sistema.',
          style: TextStyle(color: _textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Vaciar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        setState(() {
          isLoading = true;
        });

        await _mesaService.vaciarMesa(mesa.id);
        await _loadMesas();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesa ${mesa.nombre} vaciada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al vaciar mesa: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _sincronizarMesa(Mesa mesa) async {
    try {
      setState(() {
        isLoading = true;
      });

      await _loadMesas(); // Recargar las mesas

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesa ${mesa.nombre} actualizada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al sincronizar mesa: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildMesaCard(Mesa mesa) {
    bool isOcupada = mesa.ocupada;
    Color statusColor = isOcupada ? Colors.red : Colors.green;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    bool canProcessPayment =
        userProvider.isAdmin && isOcupada && mesa.total > 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PedidoScreen(mesa: mesa)),
        );
      },
      onLongPress: userProvider.isAdmin ? () => _mostrarMenuMesa(mesa) : null,
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primary.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize
                .min, // Prevent overflow by allowing column to shrink
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Línea de estado en la parte superior izquierda
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                ],
              ),
              // Icono de mesa
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.table_restaurant, color: _primary, size: 16),
              ),
              // Nombre de la mesa
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  mesa.nombre,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Estado y total si existe
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isOcupada ? 'Ocupada' : 'Disponible',
                    style: TextStyle(
                      fontSize: 9,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (mesa.total > 0) ...[
                    canProcessPayment
                        ? GestureDetector(
                            onTap: () async {
                              // Solo para admins: procesar pago al tocar el precio
                              final pedido = await _obtenerPedidoActivoDeMesa(
                                mesa,
                              );
                              if (pedido != null) {
                                _mostrarDialogoPago(mesa, pedido);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se encontró un pedido activo para esta mesa',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '\$${mesa.total.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.payment, size: 8, color: _primary),
                                ],
                              ),
                            ),
                          )
                        : Text(
                            '\$${mesa.total.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: _primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoPago(Mesa mesa, Pedido pedido) async {
    String _medioPago = 'efectivo';
    bool _incluyePropina = false;
    TextEditingController _descuentoPorcentajeController =
        TextEditingController();
    TextEditingController _descuentoValorController = TextEditingController();
    TextEditingController _propinaController = TextEditingController();

    // NUEVAS VARIABLES PARA LAS OPCIONES MOVIDAS
    bool _esCortesia = false;
    bool _esConsumoInterno = false;
    String? _mesaDestinoId;

    // Mostrar indicador de carga mientras se prepara el diálogo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        content: Row(
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(width: 20),
            Text(
              'Cargando información de productos...',
              style: TextStyle(color: _textLight),
            ),
          ],
        ),
      ),
    );

    // Asegurarse de que todos los productos estén cargados antes de mostrar el diálogo
    try {
      await PedidoService().cargarProductosParaPedido(pedido);
      print('✅ Productos del pedido cargados correctamente');
    } catch (e) {
      print('❌ Error cargando productos del pedido: $e');
    }

    // Cerrar el diálogo de carga
    Navigator.of(context).pop();
    final formResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen del Pedido',
                    style: TextStyle(
                      color: _textLight,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Información del pedido
                  Text(
                    'Mesa: ${pedido.mesa}',
                    style: TextStyle(color: _textLight),
                  ),
                  Text(
                    'Mesero: ${pedido.mesero}',
                    style: TextStyle(color: _textLight),
                  ),
                  if (pedido.cliente != null)
                    Text(
                      'Cliente: ${pedido.cliente}',
                      style: TextStyle(color: _textLight),
                    ),
                  SizedBox(height: 16),

                  // Detalle de productos
                  Text(
                    'Productos:',
                    style: TextStyle(
                      color: _textLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...pedido.items.map(
                    (item) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.cantidad}x ${item.producto?.nombre ?? "Producto desconocido"}',
                                  style: TextStyle(
                                    color: _textLight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (item.notas != null &&
                                    item.notas!.isNotEmpty)
                                  Text(
                                    item.notas!,
                                    style: TextStyle(
                                      color: _textLight.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Removed the per-unit price display to avoid redundancy
                          Text(
                            '\$${((item.precio) * item.cantidad).toStringAsFixed(0)}',
                            style: TextStyle(
                              color: _textLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: _textLight.withOpacity(0.3)),

                  // Campos de descuento
                  SwitchListTile(
                    title: Row(
                      children: [
                        Text(
                          'Es cortesía',
                          style: TextStyle(color: _textLight, fontSize: 16),
                        ),
                        if (_esCortesia)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.card_giftcard,
                              color: _primary,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    value: _esCortesia,
                    activeColor: _primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        _esCortesia = value;
                        if (value) {
                          _esConsumoInterno = false;
                        }
                      });
                    },
                  ),

                  // Opción Consumo interno
                  SwitchListTile(
                    title: Row(
                      children: [
                        Text(
                          'Consumo interno',
                          style: TextStyle(color: _textLight, fontSize: 16),
                        ),
                        if (_esConsumoInterno)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.people,
                              color: _primary,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    value: _esConsumoInterno,
                    activeColor: _primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        _esConsumoInterno = value;
                        if (value) {
                          _esCortesia = false;
                        }
                      });
                    },
                  ),

                  // Opción Mover a otra mesa
                  InkWell(
                    onTap: () async {
                      final mesaSeleccionada =
                          await _mostrarDialogoSeleccionMesa();
                      if (mesaSeleccionada != null) {
                        setState(() {
                          _mesaDestinoId = mesaSeleccionada.id;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, color: _textLight),
                          SizedBox(width: 8),
                          Text(
                            'Mover a otra mesa',
                            style: TextStyle(color: _textLight, fontSize: 16),
                          ),
                          Spacer(),
                          if (_mesaDestinoId != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Seleccionada',
                                style: TextStyle(
                                  color: _primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: _textLight),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),
                  Divider(color: _textLight.withOpacity(0.3)),

                  // Campos de descuento
                  Text(
                    'Descuentos:',
                    style: TextStyle(
                      color: _textLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _descuentoPorcentajeController,
                          decoration: InputDecoration(
                            labelText: 'Descuento %',
                            labelStyle: TextStyle(color: _textLight),
                            suffixText: '%',
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _textLight.withOpacity(0.3),
                              ),
                            ),
                          ),
                          style: TextStyle(color: _textLight),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _descuentoValorController,
                          decoration: InputDecoration(
                            labelText: 'Descuento \$',
                            labelStyle: TextStyle(color: _textLight),
                            prefixText: '\$',
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _textLight.withOpacity(0.3),
                              ),
                            ),
                          ),
                          style: TextStyle(color: _textLight),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Forma de pago
                  Text(
                    'Forma de pago:',
                    style: TextStyle(
                      color: _textLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'efectivo',
                        groupValue: _medioPago,
                        onChanged: (value) {
                          setState(() => _medioPago = value!);
                        },
                        activeColor: _primary,
                      ),
                      Text('Efectivo', style: TextStyle(color: _textLight)),
                      SizedBox(width: 16),
                      Radio<String>(
                        value: 'tarjeta',
                        groupValue: _medioPago,
                        onChanged: (value) {
                          setState(() => _medioPago = value!);
                        },
                        activeColor: _primary,
                      ),
                      Text('Tarjeta', style: TextStyle(color: _textLight)),
                    ],
                  ),

                  // Propina
                  Text(
                    'Propina:',
                    style: TextStyle(
                      color: _textLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _propinaController,
                    decoration: InputDecoration(
                      labelText: 'Propina %',
                      labelStyle: TextStyle(color: _textLight),
                      suffixText: '%',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: _textLight.withOpacity(0.3),
                        ),
                      ),
                    ),
                    style: TextStyle(color: _textLight),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _incluyePropina =
                            value.isNotEmpty &&
                            double.tryParse(value) != null &&
                            double.parse(value) > 0;
                      });
                    },
                  ),

                  SizedBox(height: 16),

                  // Total
                  Builder(
                    builder: (context) {
                      double subtotal = pedido.total;
                      double propinaPercent =
                          double.tryParse(_propinaController.text) ?? 0.0;
                      double propinaMonto = (subtotal * propinaPercent / 100)
                          .roundToDouble();
                      double total = subtotal + propinaMonto;

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal:',
                                style: TextStyle(
                                  color: _textLight,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '\$${subtotal.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: _textLight,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          if (propinaPercent > 0) ...[
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Propina ($propinaPercent%):',
                                  style: TextStyle(
                                    color: _textLight,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '\$${propinaMonto.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: _textLight,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total:',
                                style: TextStyle(
                                  color: _textLight,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '\$${total.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: _primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  SizedBox(height: 24),

                  // OPCIONES ESPECIALES
                  Text(
                    'Opciones especiales:',
                    style: TextStyle(
                      color: _textLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),

                  // Opción Es cortesía
                  SwitchListTile(
                    title: Row(
                      children: [
                        Text(
                          'Es cortesía',
                          style: TextStyle(color: _textLight, fontSize: 16),
                        ),
                        if (_esCortesia)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.card_giftcard,
                              color: _primary,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    value: _esCortesia,
                    activeColor: _primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        _esCortesia = value;
                        if (value) {
                          _esConsumoInterno = false;
                        }
                      });
                    },
                  ),

                  // Opción Consumo interno
                  SwitchListTile(
                    title: Row(
                      children: [
                        Text(
                          'Consumo interno',
                          style: TextStyle(color: _textLight, fontSize: 16),
                        ),
                        if (_esConsumoInterno)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.people,
                              color: _primary,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    value: _esConsumoInterno,
                    activeColor: _primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        _esConsumoInterno = value;
                        if (value) {
                          _esCortesia = false;
                        }
                      });
                    },
                  ),

                  // Opción Mover a otra mesa
                  InkWell(
                    onTap: () async {
                      final mesaSeleccionada =
                          await _mostrarDialogoSeleccionMesa();
                      if (mesaSeleccionada != null) {
                        setState(() {
                          _mesaDestinoId = mesaSeleccionada.id;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, color: _textLight),
                          SizedBox(width: 8),
                          Text(
                            'Mover a otra mesa',
                            style: TextStyle(color: _textLight, fontSize: 16),
                          ),
                          Spacer(),
                          if (_mesaDestinoId != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Seleccionada',
                                style: TextStyle(
                                  color: _primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: _textLight),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancelar'),
                        style: TextButton.styleFrom(
                          foregroundColor: _textLight,
                        ),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, {
                            'medioPago': _medioPago,
                            'incluyePropina': _incluyePropina,
                            'descuentoPorcentaje':
                                _descuentoPorcentajeController.text,
                            'descuentoValor': _descuentoValorController.text,
                            'propina': _propinaController.text,
                            'esCortesia': _esCortesia,
                            'esConsumoInterno': _esConsumoInterno,
                            'mesaDestinoId': _mesaDestinoId,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Confirmar pago'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (formResult != null) {
      try {
        // Manejar las opciones especiales
        bool esCortesia = formResult['esCortesia'] ?? false;
        bool esConsumoInterno = formResult['esConsumoInterno'] ?? false;
        String? mesaDestinoId = formResult['mesaDestinoId'];

        // Preparar datos de pago
        double propina = 0.0;
        // Calcular propina basada en el porcentaje ingresado
        double propinaPercentage =
            double.tryParse(formResult['propina'] ?? '0') ?? 0.0;
        if (propinaPercentage > 0) {
          propina = (pedido.total * propinaPercentage / 100).roundToDouble();
        }

        print(
          '📝 Procesando pago del pedido: "${pedido.id}" - Mesa: ${mesa.nombre}',
        );
        print('🎯 Opciones seleccionadas:');
        print('  - Es cortesía: $esCortesia');
        print('  - Es consumo interno: $esConsumoInterno');
        print('  - Mesa destino: $mesaDestinoId');
        print('  - Tipo actual del pedido: ${pedido.tipo}');

        if (pedido.id.isEmpty) {
          throw Exception('El ID del pedido es inválido o está vacío');
        }

        print('🆔 ID del pedido confirmado: "${pedido.id}"');

        // Obtener el usuario actual para el pago
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final usuarioPago = userProvider.userName ?? 'Usuario Desconocido';

        // PRIMERO: Cambiar el tipo de pedido si es necesario
        if (esCortesia || esConsumoInterno) {
          try {
            TipoPedido nuevoTipo = esCortesia
                ? TipoPedido.cortesia
                : TipoPedido.interno;
            print('🔄 Cambiando tipo de pedido a: $nuevoTipo');
            print('  - Pedido ID: ${pedido.id}');
            print('  - Tipo anterior: ${pedido.tipo}');

            await _pedidoService.actualizarTipoPedido(pedido.id, nuevoTipo);

            // Actualizar el objeto pedido local
            pedido.tipo = nuevoTipo;

            print('✅ Tipo de pedido actualizado correctamente');
            print('  - Nuevo tipo asignado: $nuevoTipo');
            print('  - Tipo en objeto local: ${pedido.tipo}');

            // Esperar un momento para que el backend procese el cambio
            await Future.delayed(Duration(milliseconds: 300));
          } catch (e) {
            print('❌ Error al cambiar tipo de pedido: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al actualizar tipo de pedido: $e'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.of(context).pop();
            return; // Salir si falla el cambio de tipo
          }
        }

        // SEGUNDO: Pagar el pedido (sin cambiar tipo aquí)
        print('💰 Iniciando proceso de pago...');
        print('  - Forma de pago: ${formResult['medioPago']}');
        print('  - Propina: $propina');
        print('  - Pagado por: $usuarioPago');
        print('  - Tipo final del pedido: ${pedido.tipo}');

        await _pedidoService.pagarPedido(
          pedido.id,
          formaPago: formResult['medioPago'],
          propina: propina,
          procesadoPor: usuarioPago, // Cambio de 'pagadoPor' a 'procesadoPor'
          esCortesia: esCortesia,
          esConsumoInterno: esConsumoInterno,
          motivoCortesia: esCortesia ? 'Pedido procesado como cortesía' : null,
          tipoConsumoInterno: esConsumoInterno ? 'empleado' : null,
        );

        print('✅ Pago procesado exitosamente');

        // Actualizar el objeto pedido con el estado devuelto por el servidor
        pedido.estado = EstadoPedido.pagado;
        print('  - Estado actualizado a: ${pedido.estado}');
        print('  - Tipo final confirmado: ${pedido.tipo}');

        // Manejar opciones especiales antes de liberar la mesa
        if (mesaDestinoId != null) {
          // Mover a otra mesa
          try {
            final mesasDisponibles = await _mesaService.getMesas();
            final mesaDestino = mesasDisponibles.firstWhere(
              (m) => m.id == mesaDestinoId,
            );

            mesaDestino.ocupada = true;
            mesaDestino.total = pedido.total;
            await _mesaService.updateMesa(mesaDestino);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Pedido movido a la mesa ${mesaDestino.nombre} y pagado',
                ),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            print('Error moviendo pedido a otra mesa: $e');
          }
        }

        // Liberar la mesa después del pago exitoso
        try {
          mesa.ocupada = false;
          mesa.productos = [];
          mesa.total = 0.0;
          await _mesaService.updateMesa(mesa);
          print('✅ Mesa ${mesa.nombre} liberada después del pago');
        } catch (e) {
          print('❌ Error al liberar mesa después del pago: $e');
        }

        // Notificar el cambio para actualizar el dashboard
        NotificationService().notificarCambioPedido(pedido);

        String tipoTexto = '';
        if (esCortesia) tipoTexto = ' (Cortesía)';
        if (esConsumoInterno) tipoTexto = ' (Consumo Interno)';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido pagado exitosamente$tipoTexto'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMesas(); // Recargar las mesas
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar el pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Mesa?> _mostrarDialogoSeleccionMesa() async {
    try {
      // Cargar la lista de mesas disponibles
      final mesas = await _mesaService.getMesas();

      // Filtrar mesas especiales y la mesa actual
      final mesasDisponibles = mesas
          .where(
            (mesa) => ![
              'DOMICILIO',
              'CAJA',
              'MESA AUXILIAR',
            ].contains(mesa.nombre.toUpperCase()),
          )
          .toList();

      if (mesasDisponibles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No hay otras mesas disponibles'),
            backgroundColor: Colors.orange,
          ),
        );
        return null;
      }

      // Mostrar diálogo de selección
      final mesaSeleccionada = await showDialog<Mesa>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: _cardBg,
            title: Text(
              'Seleccionar mesa destino',
              style: TextStyle(color: _textLight),
            ),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: mesasDisponibles.length,
                itemBuilder: (context, index) {
                  final mesa = mesasDisponibles[index];
                  return ListTile(
                    title: Text(
                      mesa.nombre,
                      style: TextStyle(color: _textLight),
                    ),
                    subtitle: Text(
                      mesa.ocupada ? 'Ocupada' : 'Libre',
                      style: TextStyle(
                        color: mesa.ocupada ? Colors.orange : Colors.green,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(mesa),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancelar', style: TextStyle(color: _textLight)),
              ),
            ],
          );
        },
      );

      return mesaSeleccionada;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar las mesas: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cardBg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        title: const Text('Mesas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar todas las mesas',
            onPressed: () async {
              try {
                setState(() {
                  isLoading = true;
                });
                await _loadMesas();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Mesas actualizadas'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al sincronizar mesas: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                setState(() {
                  isLoading = false;
                });
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMesas),
          // Solo para administradores: botón de restauración completa
          if (Provider.of<UserProvider>(context, listen: false).isAdmin)
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              icon: Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'forzar_limpieza') {
                  _mostrarDialogoForzarLimpieza();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'forzar_limpieza',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, color: _primary, size: 18),
                      SizedBox(width: 8),
                      Text('Restaurar todas las mesas'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : _buildMesasLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildMesasLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double responsivePadding = _getResponsivePadding(constraints.maxWidth);

        return SingleChildScrollView(
          padding: EdgeInsets.all(responsivePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mesas especiales en la parte superior
              _buildMesasEspeciales(),
              SizedBox(height: responsivePadding * 1.5),

              // Mesas organizadas por filas (A1-A10, B1-B10, etc.)
              _buildMesasPorFilas(),
            ],
          ),
        );
      },
    );
  }

  double _getResponsivePadding(double screenWidth) {
    if (screenWidth < 600) return 12; // Móvil
    if (screenWidth < 900) return 16; // Tablet
    return 20; // Desktop
  }

  Widget _buildMesasEspeciales() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;
        double especialHeight = _getResponsiveEspecialHeight(screenWidth);

        return Column(
          children: [
            // Primera fila: Domicilio y Caja
            Row(
              children: [
                Expanded(
                  child: _buildMesaEspecial(
                    'Domicilio',
                    Icons.delivery_dining,
                    'disponible',
                    () => _crearPedido('Domicilio'),
                    height: especialHeight,
                  ),
                ),
                SizedBox(width: _getResponsiveMargin(screenWidth)),
                Expanded(
                  child: _buildMesaEspecial(
                    'Caja',
                    Icons.point_of_sale,
                    'disponible',
                    () => _crearPedido('Caja'),
                    height: especialHeight,
                  ),
                ),
              ],
            ),
            SizedBox(height: _getResponsiveMargin(screenWidth)),
            // Segunda fila: Mesa Auxiliar centrada
            Row(
              children: [
                Expanded(
                  child: _buildMesaEspecial(
                    'Mesa\nAuxiliar',
                    Icons.table_restaurant,
                    'disponible',
                    () => _crearPedido('Mesa Auxiliar'),
                    height: especialHeight,
                  ),
                ),
                Expanded(child: SizedBox()), // Espacio vacío para centrar
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMesaEspecial(
    String nombre,
    IconData icono,
    String estado,
    VoidCallback onTap, {
    required double height,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;
        double iconSize = _getResponsiveIconSize(screenWidth);
        double fontSize = _getResponsiveFontSize(screenWidth, 10);
        double statusFontSize = _getResponsiveFontSize(screenWidth, 7);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _primary.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icono, color: _primary, size: iconSize),
                ),
                SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      nombre,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textLight,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 2),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Disponible',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: statusFontSize,
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

  double _getResponsiveEspecialHeight(double screenWidth) {
    if (screenWidth < 600) return 70; // Móvil
    if (screenWidth < 900) return 80; // Tablet
    return 90; // Desktop
  }

  double _getResponsiveIconSize(double screenWidth) {
    if (screenWidth < 600) return 14; // Móvil
    if (screenWidth < 900) return 16; // Tablet
    return 18; // Desktop
  }

  Widget _buildMesasPorFilas() {
    // Organizar mesas por LETRAS (A, B, C, D, E) - cada letra es una columna
    Map<String, List<Mesa>> mesasPorLetra = {};

    for (Mesa mesa in mesas) {
      if (mesa.nombre.length > 0) {
        String letra = mesa.nombre[0].toUpperCase();
        // Filtrar solo las mesas regulares (no especiales)
        if (![
          'DOMICILIO',
          'CAJA',
          'MESA AUXILIAR',
        ].contains(mesa.nombre.toUpperCase())) {
          if (mesasPorLetra[letra] == null) {
            mesasPorLetra[letra] = [];
          }
          mesasPorLetra[letra]!.add(mesa);
        }
      }
    }

    // Ordenar las letras alfabéticamente (A, B, C, D, E)
    List<String> letrasOrdenadas = mesasPorLetra.keys.toList()..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular tamaños responsivos
        double screenWidth = constraints.maxWidth;
        double cardWidth = _getResponsiveCardWidth(screenWidth);
        double cardHeight = _getResponsiveCardHeight(screenWidth);
        double horizontalMargin = _getResponsiveMargin(screenWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: letrasOrdenadas.map((letra) {
              List<Mesa> mesasDeLaLetra = mesasPorLetra[letra]!;

              // Ordenar las mesas de cada letra por NÚMERO (1, 2, 3...10)
              mesasDeLaLetra.sort((a, b) {
                int numeroA = int.tryParse(a.nombre.substring(1)) ?? 0;
                int numeroB = int.tryParse(b.nombre.substring(1)) ?? 0;

                // Convertir 0 a 10 para que vaya al final
                if (numeroA == 0) numeroA = 10;
                if (numeroB == 0) numeroB = 10;

                return numeroA.compareTo(numeroB);
              });

              return Container(
                margin: EdgeInsets.only(right: horizontalMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título de la columna (letra)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Fila $letra',
                        style: TextStyle(
                          color: _primary,
                          fontSize: _getResponsiveFontSize(screenWidth, 16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Mesas de la letra organizadas verticalmente (A1, A2, A3... A10)
                    Column(
                      children: mesasDeLaLetra
                          .map(
                            (mesa) => Container(
                              width: cardWidth,
                              height: cardHeight,
                              margin: EdgeInsets.only(
                                bottom: horizontalMargin * 0.75,
                              ),
                              child: _buildMesaCard(mesa),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Métodos helper para responsive design
  double _getResponsiveCardWidth(double screenWidth) {
    if (screenWidth < 600) return 110; // Móvil
    if (screenWidth < 900) return 140; // Tablet
    return 160; // Desktop
  }

  double _getResponsiveCardHeight(double screenWidth) {
    if (screenWidth < 600) return 100; // Móvil (increased for content)
    if (screenWidth < 900) return 110; // Tablet
    return 120; // Desktop
  }

  double _getResponsiveMargin(double screenWidth) {
    if (screenWidth < 600) return 8; // Móvil
    if (screenWidth < 900) return 12; // Tablet
    return 16; // Desktop
  }

  double _getResponsiveFontSize(double screenWidth, double baseSize) {
    if (screenWidth < 600) return baseSize * 0.9; // Móvil
    if (screenWidth < 900) return baseSize; // Tablet
    return baseSize * 1.1; // Desktop
  }

  void _crearPedido(String nombreMesa) {
    // Buscar la mesa real en la lista de mesas cargadas
    Mesa? mesaReal = mesas.firstWhere(
      (mesa) => mesa.nombre.toUpperCase() == nombreMesa.toUpperCase(),
      orElse: () => Mesa(
        id: '', // ID vacío para indicar que no se encontró
        nombre: nombreMesa,
        ocupada: false,
        total: 0.0,
        productos: [],
      ),
    );

    // Si no se encontró la mesa real, mostrar error
    if (mesaReal.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se encontró la mesa $nombreMesa en el sistema'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navegar con la mesa real encontrada
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PedidoScreen(mesa: mesaReal)),
    );
  }
}
