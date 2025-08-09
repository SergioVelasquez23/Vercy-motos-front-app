import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../models/mesa.dart';
import '../models/pedido.dart';
import '../services/pedido_service.dart';
import '../services/mesa_service.dart';
import '../services/impresion_service.dart';
import '../services/notification_service.dart';
import '../services/documento_service.dart';
import '../services/pdf_service.dart';
import '../providers/user_provider.dart';
import 'pedido_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class MesasScreen extends StatefulWidget {
  const MesasScreen({Key? key}) : super(key: key);

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  final MesaService _mesaService = MesaService();
  final PedidoService _pedidoService = PedidoService();
  final ImpresionService _impresionService = ImpresionService();
  final DocumentoService _documentoService = DocumentoService();
  final PDFService _pdfService = PDFService();
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

    // NUEVAS VARIABLES PARA SELECTOR DE BILLETES Y CAMBIO
    double _billetesSeleccionados = 0.0;
    TextEditingController _billetesController = TextEditingController();
    Map<int, int> _contadorBilletes = {
      50000: 0,
      20000: 0,
      10000: 0,
      5000: 0,
      2000: 0,
      1000: 0,
    };

    // Función local para construir botones de billetes mejorados
    Widget _buildBilletButton(int valor, Function(VoidCallback) setStateLocal) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: () {
              setStateLocal(() {
                _billetesSeleccionados += valor.toDouble();
                _contadorBilletes[valor] = (_contadorBilletes[valor] ?? 0) + 1;
                _billetesController.text = _billetesSeleccionados
                    .toStringAsFixed(0);
              });
            },
            child: Container(
              height: 80, // Más alto
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primary, _primary.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mostrar contador si hay billetes seleccionados
                  if ((_contadorBilletes[valor] ?? 0) > 0) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '${_contadorBilletes[valor]}',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                  ],

                  // Icono de billete
                  Icon(Icons.money, color: Colors.white, size: 20),
                  SizedBox(height: 4),

                  // Valor del billete
                  Text(
                    '\$${(valor / 1000).toStringAsFixed(0)}K',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
            borderRadius: BorderRadius.circular(20), // Bordes más redondeados
          ),
          child: Container(
            width:
                MediaQuery.of(context).size.width *
                0.85, // Ancho ligeramente mayor
            padding: EdgeInsets.all(28), // Más padding
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header del diálogo
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.payment, color: _primary, size: 32),
                        SizedBox(height: 12),
                        Text(
                          'Procesar Pago',
                          style: TextStyle(
                            color: _textLight,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32), // Más espacio
                  // Sección: Información del pedido
                  _buildSeccionTitulo('Información del Pedido'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(20), // Más padding
                    decoration: BoxDecoration(
                      color: _cardBg.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(
                        16,
                      ), // Bordes más redondeados
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          Icons.table_restaurant,
                          'Mesa',
                          pedido.mesa,
                        ),
                        SizedBox(height: 12),
                        _buildInfoRow(Icons.person, 'Mesero', pedido.mesero),
                        if (pedido.cliente != null) ...[
                          SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.person_outline,
                            'Cliente',
                            pedido.cliente!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 32), // Más espacio
                  // Sección: Productos
                  _buildSeccionTitulo('Detalle de Productos'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(20), // Más padding
                    decoration: BoxDecoration(
                      color: _cardBg.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: pedido.items
                          .map(
                            (item) => Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 8,
                              ), // Más padding vertical
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item.cantidad}x ${item.producto?.nombre ?? "Producto desconocido"}',
                                          style: TextStyle(
                                            color: _textLight,
                                            fontWeight:
                                                FontWeight.w600, // Más peso
                                            fontSize: 15, // Texto más grande
                                          ),
                                        ),
                                        if (item.notas != null &&
                                            item.notas!.isNotEmpty) ...[
                                          SizedBox(height: 4),
                                          Text(
                                            item.notas!,
                                            style: TextStyle(
                                              color: _textLight.withOpacity(
                                                0.7,
                                              ),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '\$${((item.precio) * item.cantidad).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: _primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16, // Texto más grande
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(height: 32),

                  // Sección: Forma de pago
                  _buildSeccionTitulo('Método de Pago'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardBg.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        // Botones de método de pago mejorados
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _medioPago = 'efectivo'),
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _medioPago == 'efectivo'
                                        ? _primary.withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _medioPago == 'efectivo'
                                          ? _primary
                                          : _textLight.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.money,
                                        color: _medioPago == 'efectivo'
                                            ? _primary
                                            : _textLight.withOpacity(0.6),
                                        size: 24,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Efectivo',
                                        style: TextStyle(
                                          color: _medioPago == 'efectivo'
                                              ? _primary
                                              : _textLight.withOpacity(0.8),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _medioPago = 'transferencia',
                                ),
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _medioPago == 'transferencia'
                                        ? _primary.withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _medioPago == 'transferencia'
                                          ? _primary
                                          : _textLight.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.credit_card,
                                        color: _medioPago == 'transferencia'
                                            ? _primary
                                            : _textLight.withOpacity(0.6),
                                        size: 24,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tarjeta/Transfer.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _medioPago == 'transferencia'
                                              ? _primary
                                              : _textLight.withOpacity(0.8),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),

                  // Sección: Pago en efectivo (condicional)
                  if (_medioPago == 'efectivo') ...[
                    _buildSeccionTitulo('Cálculo de Cambio'),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _cardBg.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Campo para entrada manual
                          TextField(
                            controller: _billetesController,
                            decoration: InputDecoration(
                              labelText: 'Total recibido',
                              labelStyle: TextStyle(color: _textLight),
                              prefixText: '\$',
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _textLight.withOpacity(0.3),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _primary,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            style: TextStyle(color: _textLight, fontSize: 16),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                _billetesSeleccionados =
                                    double.tryParse(value) ?? 0.0;
                                if (value.isNotEmpty) {
                                  _contadorBilletes.updateAll((key, val) => 0);
                                }
                              });
                            },
                          ),
                          SizedBox(height: 20),

                          Text(
                            'O selecciona los billetes:',
                            style: TextStyle(
                              color: _textLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 16),

                          // Botones de billetes mejorados
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildBilletButton(50000, setState),
                              _buildBilletButton(20000, setState),
                              _buildBilletButton(10000, setState),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildBilletButton(5000, setState),
                              _buildBilletButton(2000, setState),
                              _buildBilletButton(1000, setState),
                            ],
                          ),
                          SizedBox(height: 16),

                          // Botones de acción para billetes
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _contadorBilletes.updateAll(
                                        (key, value) => 0,
                                      );
                                      double subtotal = pedido.total;
                                      double propinaPercent =
                                          double.tryParse(
                                            _propinaController.text,
                                          ) ??
                                          0.0;
                                      double propinaMonto =
                                          (subtotal * propinaPercent / 100)
                                              .roundToDouble();
                                      double total = subtotal + propinaMonto;
                                      _billetesSeleccionados = total;
                                      _billetesController.text =
                                          _billetesSeleccionados
                                              .toStringAsFixed(0);
                                    });
                                  },
                                  icon: Icon(Icons.check, size: 18),
                                  label: Text('Exacto'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _billetesSeleccionados = 0.0;
                                      _billetesController.text = '0';
                                      _contadorBilletes.updateAll(
                                        (key, value) => 0,
                                      );
                                    });
                                  },
                                  icon: Icon(Icons.clear, size: 18),
                                  label: Text('Limpiar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Sección: Propina y Totales
                  _buildSeccionTitulo('Propina y Totales'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardBg.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        // Campo de propina
                        TextField(
                          controller: _propinaController,
                          decoration: InputDecoration(
                            labelText: 'Propina (%)',
                            labelStyle: TextStyle(color: _textLight),
                            suffixText: '%',
                            prefixIcon: Icon(Icons.star, color: _primary),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _textLight.withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _primary, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: TextStyle(color: _textLight, fontSize: 16),
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
                        SizedBox(height: 24),

                        // Resumen de totales
                        Builder(
                          builder: (context) {
                            double subtotal = pedido.total;
                            double propinaPercent =
                                double.tryParse(_propinaController.text) ?? 0.0;
                            double propinaMonto =
                                (subtotal * propinaPercent / 100)
                                    .roundToDouble();
                            double total = subtotal + propinaMonto;

                            return Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _primary.withOpacity(0.1),
                                    _primary.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _primary.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (propinaPercent > 0) ...[
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  SizedBox(height: 16),
                                  Divider(
                                    color: _primary.withOpacity(0.3),
                                    thickness: 2,
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'TOTAL:',
                                        style: TextStyle(
                                          color: _textLight,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      Text(
                                        '\$${total.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: _primary,
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Mostrar cálculo de cambio para efectivo
                                  if (_medioPago == 'efectivo' &&
                                      _billetesSeleccionados > 0) ...[
                                    SizedBox(height: 20),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _cardBg.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Recibido:',
                                                style: TextStyle(
                                                  color: _textLight,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                '\$${_billetesSeleccionados.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color: _textLight,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Cambio:',
                                                style: TextStyle(
                                                  color: _textLight,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                (_billetesSeleccionados -
                                                            total) >=
                                                        0
                                                    ? '\$${(_billetesSeleccionados - total).toStringAsFixed(0)}'
                                                    : '-\$${(total - _billetesSeleccionados).toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color:
                                                      (_billetesSeleccionados -
                                                              total) >=
                                                          0
                                                      ? Colors.green
                                                      : Colors.red,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),

                  // Sección: Opciones Especiales
                  _buildSeccionTitulo('Opciones Especiales'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardBg.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        // Opción Es cortesía
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _esCortesia
                                ? _primary.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _esCortesia
                                  ? _primary
                                  : _textLight.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.card_giftcard,
                                color: _esCortesia
                                    ? _primary
                                    : _textLight.withOpacity(0.6),
                                size: 24,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Es cortesía',
                                  style: TextStyle(
                                    color: _textLight,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _esCortesia,
                                activeColor: _primary,
                                onChanged: (value) {
                                  setState(() {
                                    _esCortesia = value;
                                    if (value) {
                                      _esConsumoInterno = false;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // Opción Consumo interno
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _esConsumoInterno
                                ? _primary.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _esConsumoInterno
                                  ? _primary
                                  : _textLight.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people,
                                color: _esConsumoInterno
                                    ? _primary
                                    : _textLight.withOpacity(0.6),
                                size: 24,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Consumo interno',
                                  style: TextStyle(
                                    color: _textLight,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _esConsumoInterno,
                                activeColor: _primary,
                                onChanged: (value) {
                                  setState(() {
                                    _esConsumoInterno = value;
                                    if (value) {
                                      _esCortesia = false;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

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
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _mesaDestinoId != null
                                  ? _primary.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _mesaDestinoId != null
                                    ? _primary
                                    : _textLight.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  color: _mesaDestinoId != null
                                      ? _primary
                                      : _textLight.withOpacity(0.6),
                                  size: 24,
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Mover a otra mesa',
                                    style: TextStyle(
                                      color: _textLight,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (_mesaDestinoId != null)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Seleccionada',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                SizedBox(width: 12),
                                Icon(
                                  Icons.chevron_right,
                                  color: _textLight.withOpacity(0.6),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40), // Más espacio antes de botones
                  // Botones de acción mejorados
                  Row(
                    children: [
                      // Botón Resumen
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _mostrarResumenImpresion(pedido);
                          },
                          icon: Icon(Icons.receipt_long, size: 20),
                          label: Text('Ver Resumen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 3,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),

                      // Botón Cancelar
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textLight,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            side: BorderSide(
                              color: _textLight.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),

                      // Botón Confirmar Pago
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
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
                              'billetesRecibidos': _billetesSeleccionados,
                            });
                          },
                          icon: Icon(Icons.payment, size: 20),
                          label: Text('Confirmar Pago'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                        ),
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

        // Notificar que se debe actualizar la lista de documentos
        _notificarActualizacionDocumentos(pedido);

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

  // Notificar actualización de documentos
  Future<void> _notificarActualizacionDocumentos(Pedido pedido) async {
    try {
      print(
        '📄 Notificando actualización de documentos para pedido: ${pedido.id}',
      );

      // Aquí puedes agregar lógica adicional si necesitas comunicación
      // entre pantallas para actualizar los documentos en tiempo real

      // Por ejemplo, usando un EventBus o Stream si lo tienes configurado
      // EventBus().fire(DocumentoActualizadoEvent(pedido.id));
    } catch (e) {
      print('❌ Error notificando actualización de documentos: $e');
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

  // Método para mostrar resumen e imprimir factura
  void _mostrarResumenImpresion(Pedido pedido) async {
    // Mostrar indicador de carga
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
              'Generando resumen de impresión...',
              style: TextStyle(color: _textLight),
            ),
          ],
        ),
      ),
    );

    try {
      // Generar resumen desde el backend usando el nuevo endpoint
      final resumen = await _impresionService.generarResumenPedido(pedido.id);

      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      if (resumen == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo generar el resumen del pedido'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Mostrar diálogo con resumen - trabajando directamente con los datos del endpoint
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Resumen del Pedido',
                        style: TextStyle(
                          color: _textLight,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: _textLight),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(color: _textLight.withOpacity(0.3)),
                  SizedBox(height: 16),

                  // Información del restaurante
                  _buildSeccionResumen('RESTAURANTE', [
                    resumen['nombreRestaurante'] ?? 'SOPA Y CARBÓN',
                    resumen['direccionRestaurante'] ??
                        'Dirección del restaurante',
                    'Tel: ${resumen['telefonoRestaurante'] ?? 'Teléfono'}',
                  ]),

                  // Información del pedido
                  _buildSeccionResumen('INFORMACIÓN DEL PEDIDO', [
                    'Pedido: ${resumen['pedidoId'] ?? 'N/A'}',
                    'Fecha: ${resumen['fecha'] ?? 'N/A'}',
                    'Hora: ${resumen['hora'] ?? 'N/A'}',
                    if (resumen['mesa'] != null) 'Mesa: ${resumen['mesa']}',
                    if (resumen['mesero'] != null)
                      'Mesero: ${resumen['mesero']}',
                    if (resumen['tipo'] != null) 'Tipo: ${resumen['tipo']}',
                  ]),

                  // Detalle de productos
                  Text(
                    'DETALLE DE PRODUCTOS:',
                    style: TextStyle(
                      color: _textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),

                  Container(
                    constraints: BoxConstraints(maxHeight: 350),
                    child: SingleChildScrollView(
                      child: Column(
                        children: (resumen['productos'] as List? ?? [])
                            .map<Widget>(
                              (producto) =>
                                  _buildProductoItemConIngredientes(producto),
                            )
                            .toList(),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),
                  Divider(color: _textLight.withOpacity(0.3)),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL:',
                        style: TextStyle(
                          color: _textLight,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${(resumen['total'] ?? 0.0).toStringAsFixed(0)}',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _imprimirResumenPedido(resumen);
                        },
                        icon: Icon(Icons.print, size: 18),
                        label: Text('Imprimir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _compartirResumenPedido(resumen);
                        },
                        icon: Icon(Icons.share, size: 18),
                        label: Text('Compartir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context); // Cerrar diálogo actual
                          await _crearYMostrarFactura(pedido.id);
                        },
                        icon: Icon(Icons.receipt_long, size: 18),
                        label: Text('Facturar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando resumen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método auxiliar para construir items de producto con ingredientes (nuevo endpoint)
  Widget _buildProductoItemConIngredientes(Map<String, dynamic> producto) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información del producto
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${producto['cantidad'] ?? 1}x ${producto['nombre'] ?? 'Producto desconocido'}',
                      style: TextStyle(
                        color: _textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (producto['observaciones'] != null &&
                        producto['observaciones'].toString().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Observaciones: ${producto['observaciones']}',
                          style: TextStyle(
                            color: _textLight.withOpacity(0.8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '\$${((producto['precio'] ?? 0.0) * (producto['cantidad'] ?? 1)).toStringAsFixed(0)}',
                style: TextStyle(
                  color: _primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Ingredientes requeridos
          if (producto['ingredientesRequeridos'] != null &&
              (producto['ingredientesRequeridos'] as List).isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingredientes requeridos:',
                    style: TextStyle(
                      color: _textLight.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  ...(producto['ingredientesRequeridos'] as List)
                      .map(
                        (ingrediente) => Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '${ingrediente['nombre']} (${ingrediente['cantidad']} ${ingrediente['unidad'] ?? ''})',
                                style: TextStyle(
                                  color: _textLight.withOpacity(0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            ),

          // Ingredientes opcionales
          if (producto['ingredientesOpcionales'] != null &&
              (producto['ingredientesOpcionales'] as List).isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8, left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingredientes opcionales:',
                    style: TextStyle(
                      color: _textLight.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  ...(producto['ingredientesOpcionales'] as List)
                      .map(
                        (ingrediente) => Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '${ingrediente['nombre']} (${ingrediente['cantidad']} ${ingrediente['unidad'] ?? ''})',
                                style: TextStyle(
                                  color: _textLight.withOpacity(0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            ),

          SizedBox(height: 8),
          Divider(color: _textLight.withOpacity(0.1), height: 1),
        ],
      ),
    );
  }

  // Método auxiliar para construir secciones del resumen
  Widget _buildSeccionResumen(String titulo, List<String> contenido) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: _primary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        ...contenido
            .map(
              (linea) => Text(
                linea,
                style: TextStyle(color: _textLight, fontSize: 13),
              ),
            )
            .toList(),
        SizedBox(height: 12),
      ],
    );
  }

  // Método auxiliar para construir items de producto
  Widget _buildProductoItem(Map<String, dynamic> producto) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                child: Text(
                  '${producto['cantidad']}x',
                  style: TextStyle(
                    color: _textLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto['nombre'] ?? 'Producto desconocido',
                      style: TextStyle(
                        color: _textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (producto['observaciones'] != null &&
                        producto['observaciones'].toString().isNotEmpty)
                      Text(
                        '  • ${producto['observaciones']}',
                        style: TextStyle(
                          color: _textLight.withOpacity(0.7),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    // Mostrar ingredientes si están disponibles
                    if (producto['ingredientes'] != null &&
                        (producto['ingredientes'] as List).isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        'Ingredientes:',
                        style: TextStyle(
                          color: _textLight.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      ...(producto['ingredientes'] as List)
                          .map<Widget>(
                            (ing) => Text(
                              '  - ${ing['nombre']}: ${ing['cantidad']} ${ing['unidad']}',
                              style: TextStyle(
                                color: _textLight.withOpacity(0.6),
                                fontSize: 10,
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ],
                ),
              ),
              Text(
                '\$${producto['subtotal'].toStringAsFixed(0)}',
                style: TextStyle(
                  color: _textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Divider(color: _textLight.withOpacity(0.1), height: 1),
        ],
      ),
    );
  }

  // Método para imprimir resumen de pedido (usando nuevo endpoint)
  Future<void> _imprimirResumenPedido(Map<String, dynamic> resumen) async {
    try {
      // Mostrar opciones de impresión/compartir
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          title: Text(
            'Opciones de Impresión',
            style: TextStyle(color: _textLight),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Resumen de Pedido #${resumen['pedidoId'] ?? 'N/A'}',
                style: TextStyle(color: _textLight),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.print, color: _primary),
                title: Text('Imprimir', style: TextStyle(color: _textLight)),
                subtitle: Text(
                  'Usar impresora del sistema',
                  style: TextStyle(color: _textLight.withOpacity(0.7)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _pdfService.mostrarDialogoImpresion(
                      resumen: resumen,
                      esFactura: false,
                    );
                    _mostrarMensajeExito('PDF enviado a impresión');
                  } catch (e) {
                    _mostrarMensajeError('Error al imprimir: $e');
                  }
                },
              ),
              Divider(color: _textLight.withOpacity(0.3)),
              ListTile(
                leading: Icon(Icons.preview, color: _primary),
                title: Text(
                  'Vista Previa',
                  style: TextStyle(color: _textLight),
                ),
                subtitle: Text(
                  'Ver antes de imprimir',
                  style: TextStyle(color: _textLight.withOpacity(0.7)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _pdfService.mostrarVistaPrevia(
                      resumen: resumen,
                      esFactura: false,
                    );
                  } catch (e) {
                    _mostrarMensajeError('Error en vista previa: $e');
                  }
                },
              ),
              Divider(color: _textLight.withOpacity(0.3)),
              ListTile(
                leading: Icon(Icons.share, color: _primary),
                title: Text(
                  'Compartir PDF',
                  style: TextStyle(color: _textLight),
                ),
                subtitle: Text(
                  'Enviar por WhatsApp, email, etc.',
                  style: TextStyle(color: _textLight.withOpacity(0.7)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _pdfService.compartirPDF(
                      resumen: resumen,
                      esFactura: false,
                    );
                  } catch (e) {
                    _mostrarMensajeError('Error al compartir: $e');
                  }
                },
              ),
              Divider(color: _textLight.withOpacity(0.3)),
              ListTile(
                leading: Icon(Icons.save, color: _primary),
                title: Text('Guardar PDF', style: TextStyle(color: _textLight)),
                subtitle: Text(
                  'Almacenar en el dispositivo',
                  style: TextStyle(color: _textLight.withOpacity(0.7)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final file = await _pdfService.guardarPDF(
                      resumen: resumen,
                      esFactura: false,
                    );
                    _mostrarMensajeExito('PDF guardado: ${file.path}');
                  } catch (e) {
                    _mostrarMensajeError('Error al guardar: $e');
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: _textLight)),
            ),
          ],
        ),
      );
    } catch (e) {
      _mostrarMensajeError('Error generando opciones: $e');
    }
  }

  // Método para compartir resumen de pedido
  Future<void> _compartirResumenPedido(Map<String, dynamic> resumen) async {
    try {
      await _pdfService.compartirPDF(resumen: resumen, esFactura: false);
      _mostrarMensajeExito('Resumen compartido exitosamente');
    } catch (e) {
      _mostrarMensajeError('Error compartiendo resumen: $e');
    }
  }

  // Método para crear y mostrar factura oficial
  Future<void> _crearYMostrarFactura(String pedidoId) async {
    // Mostrar indicador de carga
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
              'Creando factura oficial...',
              style: TextStyle(color: _textLight),
            ),
          ],
        ),
      ),
    );

    try {
      // Crear factura desde el pedido
      final facturaCreada = await _impresionService.crearFacturaDesdepedido(
        pedidoId,
        medioPago: 'Efectivo',
      );

      if (facturaCreada == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo crear la factura'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Obtener la factura para impresión
      final facturaParaImpresion = await _impresionService
          .obtenerFacturaParaImpresion(facturaCreada['id'].toString());

      Navigator.of(context).pop(); // Cerrar diálogo de carga

      if (facturaParaImpresion == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo obtener los datos de la factura'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Mostrar la factura oficial
      _mostrarFacturaOficial(facturaParaImpresion);
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar diálogo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creando factura: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para mostrar factura oficial
  void _mostrarFacturaOficial(Map<String, dynamic> factura) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Factura Oficial',
                      style: TextStyle(
                        color: _textLight,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: _textLight),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(color: _textLight.withOpacity(0.3)),
                SizedBox(height: 16),

                // Información del restaurante
                _buildSeccionResumen('RESTAURANTE', [
                  factura['nombreRestaurante'] ?? 'SOPA Y CARBÓN',
                  factura['direccionRestaurante'] ??
                      'Dirección del restaurante',
                  'NIT: ${factura['nitRestaurante'] ?? 'NIT del restaurante'}',
                  'Tel: ${factura['telefonoRestaurante'] ?? 'Teléfono'}',
                ]),

                // Información de la factura
                _buildSeccionResumen('FACTURA', [
                  'Número: ${factura['numero'] ?? 'N/A'}',
                  'Fecha: ${factura['fecha'] ?? 'N/A'}',
                  'Hora: ${factura['hora'] ?? 'N/A'}',
                  'NIT Cliente: ${factura['nit'] ?? '22222222222'}',
                  if (factura['clienteTelefono'] != null &&
                      factura['clienteTelefono'].toString().isNotEmpty)
                    'Teléfono: ${factura['clienteTelefono']}',
                  if (factura['clienteDireccion'] != null &&
                      factura['clienteDireccion'].toString().isNotEmpty)
                    'Dirección: ${factura['clienteDireccion']}',
                  'Medio de Pago: ${factura['medioPago'] ?? 'Efectivo'}',
                ]),

                // Productos facturados
                Text(
                  'PRODUCTOS FACTURADOS:',
                  style: TextStyle(
                    color: _textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),

                Container(
                  constraints: BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      children: (factura['productos'] as List? ?? [])
                          .map<Widget>(
                            (producto) => _buildProductoFacturado(producto),
                          )
                          .toList(),
                    ),
                  ),
                ),

                SizedBox(height: 16),
                Divider(color: _textLight.withOpacity(0.3)),

                // Totales
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal:', style: TextStyle(color: _textLight)),
                        Text(
                          '\$${(factura['subtotal'] ?? 0.0).toStringAsFixed(0)}',
                          style: TextStyle(color: _textLight),
                        ),
                      ],
                    ),
                    if (factura['propina'] != null && factura['propina'] > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Propina:', style: TextStyle(color: _textLight)),
                          Text(
                            '\$${(factura['propina'] ?? 0.0).toStringAsFixed(0)}',
                            style: TextStyle(color: _textLight),
                          ),
                        ],
                      ),
                    Divider(color: _textLight.withOpacity(0.3)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL:',
                          style: TextStyle(
                            color: _textLight,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${(factura['total'] ?? 0.0).toStringAsFixed(0)}',
                          style: TextStyle(
                            color: _primary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // Botones de acción para factura
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _imprimirFacturaOficial(factura);
                      },
                      icon: Icon(Icons.print, size: 18),
                      label: Text('Imprimir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _compartirFacturaOficial(factura);
                      },
                      icon: Icon(Icons.share, size: 18),
                      label: Text('Compartir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget para productos facturados
  Widget _buildProductoFacturado(Map<String, dynamic> producto) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${producto['cantidad'] ?? 1}x ${producto['nombre'] ?? 'Producto'}',
              style: TextStyle(color: _textLight, fontSize: 14),
            ),
          ),
          Text(
            '\$${((producto['precio'] ?? 0.0) * (producto['cantidad'] ?? 1)).toStringAsFixed(0)}',
            style: TextStyle(
              color: _primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Método para imprimir factura oficial
  Future<void> _imprimirFacturaOficial(Map<String, dynamic> factura) async {
    try {
      // Mostrar opciones de impresión/compartir para factura
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          title: Text(
            'Opciones de Factura',
            style: TextStyle(color: _textLight),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Factura #${factura['numero'] ?? 'N/A'}',
                style: TextStyle(color: _textLight),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.print, color: _primary),
                title: Text(
                  'Imprimir Factura',
                  style: TextStyle(color: _textLight),
                ),
                subtitle: Text(
                  'Usar impresora del sistema',
                  style: TextStyle(color: _textLight.withOpacity(0.7)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _pdfService.mostrarDialogoImpresion(
                      resumen: factura,
                      esFactura: true,
                    );
                    _mostrarMensajeExito('Factura enviada a impresión');
                  } catch (e) {
                    _mostrarMensajeError('Error al imprimir: $e');
                  }
                },
              ),
              Divider(color: _textLight.withOpacity(0.3)),
              ListTile(
                leading: Icon(Icons.preview, color: _primary),
                title: Text(
                  'Vista Previa',
                  style: TextStyle(color: _textLight),
                ),
                subtitle: Text(
                  'Ver factura antes de imprimir',
                  style: TextStyle(color: _textLight.withOpacity(0.7)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _pdfService.mostrarVistaPrevia(
                      resumen: factura,
                      esFactura: true,
                    );
                  } catch (e) {
                    _mostrarMensajeError('Error en vista previa: $e');
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: _textLight)),
            ),
          ],
        ),
      );
    } catch (e) {
      _mostrarMensajeError('Error generando opciones: $e');
    }
  }

  // Método para compartir factura oficial
  Future<void> _compartirFacturaOficial(Map<String, dynamic> factura) async {
    try {
      await _pdfService.compartirPDF(resumen: factura, esFactura: true);
      _mostrarMensajeExito('Factura compartida exitosamente');
    } catch (e) {
      _mostrarMensajeError('Error compartiendo factura: $e');
    }
  }

  // Método para imprimir pedido
  Future<void> _imprimirPedido(Map<String, dynamic> resumen) async {
    try {
      final textoImpresion = _impresionService.generarTextoImpresion(resumen);

      // En una app real, aquí se enviaría a una impresora
      // Por ahora, mostraremos el texto en un diálogo
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          title: Text(
            'Vista Previa de Impresión',
            style: TextStyle(color: _textLight),
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                textoImpresion,
                style: TextStyle(
                  color: _textLight,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _imprimirDocumento(resumen);
              },
              child: Text('Imprimir'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error preparando impresión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para compartir pedido
  Future<void> _compartirPedido(Map<String, dynamic> resumen) async {
    try {
      final textoImpresion = _impresionService.generarTextoImpresion(resumen);
      await Share.share(
        textoImpresion,
        subject: 'Resumen de Pedido - ${resumen['pedidoId']}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error compartiendo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para imprimir documento (real)
  Future<void> _imprimirDocumento(Map<String, dynamic> resumen) async {
    try {
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
                'Enviando a impresora...',
                style: TextStyle(color: _textLight),
              ),
            ],
          ),
        ),
      );

      final textoImpresion = _impresionService.generarTextoImpresion(resumen);

      // Mostrar opciones de impresión
      Navigator.of(context).pop(); // Cerrar diálogo de carga

      // Mostrar diálogo con opciones de impresión
      await _mostrarOpcionesImpresion(textoImpresion, resumen);
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar diálogo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error preparando impresión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mostrar opciones de impresión
  Future<void> _mostrarOpcionesImpresion(
    String contenido,
    Map<String, dynamic> resumen,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Opciones de Impresión',
          style: TextStyle(color: _textLight),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Cómo deseas imprimir este documento?',
              style: TextStyle(color: _textLight),
            ),
            SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _abrirDialogoImpresionNativo(contenido, resumen);
            },
            icon: Icon(Icons.print),
            label: Text('Imprimir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _guardarYAbrir(contenido);
            },
            icon: Icon(Icons.open_in_new),
            label: Text('Abrir con Notepad'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _compartirPedido(resumen);
            },
            icon: Icon(Icons.share),
            label: Text('Compartir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Generar PDF y mostrarlo al usuario
  Future<void> _abrirDialogoImpresionNativo(
    String contenido,
    Map<String, dynamic> resumen,
  ) async {
    try {
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
                'Generando documento PDF...',
                style: TextStyle(color: _textLight),
              ),
            ],
          ),
        ),
      );

      // Generar PDF
      final pdfBytes = await _generarPDFTicket(contenido, resumen);

      // Guardar archivo PDF
      final tempDir = Directory.systemTemp;
      final pdfFile = File(
        '${tempDir.path}/ticket_${resumen['pedidoId'] ?? DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      await pdfFile.writeAsBytes(pdfBytes);

      Navigator.of(context).pop(); // Cerrar diálogo de carga

      // Mostrar opciones para el archivo generado
      await _mostrarOpcionesArchivo(pdfFile, 'PDF');
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar diálogo de carga si hay error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error generando PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('❌ Error completo: $e');
    }
  }

  // Mostrar opciones para el archivo generado
  Future<void> _mostrarOpcionesArchivo(File archivo, String tipo) async {
    final fileName = archivo.path.split('\\').last;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('$tipo Generado', style: TextStyle(color: _textLight)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tipo == 'PDF' ? Icons.picture_as_pdf : Icons.description,
              color: tipo == 'PDF' ? Colors.red : Colors.blue,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'El archivo $tipo se ha generado correctamente.',
              style: TextStyle(color: _textLight),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            SelectableText(
              'Archivo: $fileName',
              style: TextStyle(
                color: _textLight.withOpacity(0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            SelectableText(
              'Ubicación: ${archivo.parent.path}',
              style: TextStyle(
                color: _textLight.withOpacity(0.5),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _copiarRutaAlPortapapeles(archivo.path);
            },
            icon: Icon(Icons.copy),
            label: Text('Copiar Ruta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _intentarAbrirArchivo(archivo.path);
            },
            icon: Icon(Icons.open_in_new),
            label: Text('Intentar Abrir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Copiar ruta al portapapeles
  Future<void> _copiarRutaAlPortapapeles(String ruta) async {
    try {
      await Clipboard.setData(ClipboardData(text: ruta));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📋 Ruta copiada al portapapeles'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error copiando ruta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Intentar abrir archivo (fallback seguro)
  Future<void> _intentarAbrirArchivo(String rutaArchivo) async {
    try {
      // Mostrar instrucciones al usuario
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          title: Text('Abrir Archivo', style: TextStyle(color: _textLight)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para abrir el archivo, puedes:',
                style: TextStyle(
                  color: _textLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '• Abrir el Explorador de Windows',
                style: TextStyle(color: _textLight),
              ),
              Text(
                '• Navegar a la carpeta temporal',
                style: TextStyle(color: _textLight),
              ),
              Text(
                '• Buscar el archivo y hacer doble clic',
                style: TextStyle(color: _textLight),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  rutaArchivo,
                  style: TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Entendido'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _copiarRutaAlPortapapeles(rutaArchivo);
              },
              child: Text('Copiar Ruta'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  } // Generar PDF del ticket

  Future<Uint8List> _generarPDFTicket(
    String contenido,
    Map<String, dynamic> resumen,
  ) async {
    final pdf = pw.Document();

    // Dividir el contenido en líneas
    final lineas = contenido.split('\n');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.all(8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: lineas.map((linea) {
              // Diferentes estilos según el contenido de la línea
              if (linea.contains('=====')) {
                return pw.Text(
                  linea,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                );
              } else if (linea.contains('TOTAL:') || linea.contains('Total:')) {
                return pw.Text(
                  linea,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                );
              } else if (linea.trim().isEmpty) {
                return pw.SizedBox(height: 4);
              } else {
                return pw.Text(linea, style: pw.TextStyle(fontSize: 10));
              }
            }).toList(),
          );
        },
      ),
    );

    return pdf.save();
  }

  // Método para guardar archivo y mostrarlo al usuario
  Future<void> _guardarYAbrir(String contenido) async {
    try {
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
                'Generando documento de texto...',
                style: TextStyle(color: _textLight),
              ),
            ],
          ),
        ),
      );

      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/ticket_${DateTime.now().millisecondsSinceEpoch}.txt',
      );

      await tempFile.writeAsString(contenido, encoding: utf8);

      Navigator.of(context).pop();

      // Mostrar opciones para el archivo de texto
      await _mostrarOpcionesArchivo(tempFile, 'Texto');
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error generando documento: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Obtener el conteo de documentos del día actual
  Future<int> _obtenerConteoDocumentosHoy() async {
    try {
      final hoy = DateTime.now();
      final fechaHoy =
          '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';

      final documentos = await _documentoService.obtenerDocumentos(
        fechaInicio: fechaHoy,
        fechaFin: fechaHoy,
      );

      return documentos.length;
    } catch (e) {
      print('❌ Error obteniendo conteo de documentos: $e');
      return 0;
    }
  }

  // Navegar a la pantalla de documentos
  Future<void> _navegarADocumentos() async {
    try {
      // Navegar a la pantalla de documentos
      await Navigator.of(context).pushNamed('/documentos');

      // Al regresar, actualizar las mesas por si hubo cambios
      await _loadMesas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error navegando a documentos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // MÉTODO ANTERIOR - YA NO SE USA (Se reemplazó por _crearYMostrarFactura)
  // Método para crear factura
  /*
  Future<void> _crearFacturaPedido(String pedidoId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          content: Row(
            children: [
              CircularProgressIndicator(color: _primary),
              SizedBox(width: 20),
              Text('Generando factura...', style: TextStyle(color: _textLight)),
            ],
          ),
        ),
      );

      final factura = await _impresionService.crearFacturaDesdepedido(pedidoId);

      Navigator.of(context).pop(); // Cerrar diálogo de carga

      if (factura != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Factura generada: ${factura['numero']}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Ver Documentos',
              onPressed: () {
                // Navegar a la pantalla de documentos y actualizar
                _navegarADocumentos();
              },
            ),
          ),
        );

        // Mostrar resumen de factura y opciones
        final resumenFactura = await _impresionService
            .obtenerFacturaParaImpresion(factura['_id']);
        if (resumenFactura != null) {
          _mostrarResumenFactura(resumenFactura);
        }

        // Actualizar el estado de la mesa después de facturar
        await _loadMesas();

        // Mostrar opción adicional para navegar a documentos
        _mostrarOpcionesPostFacturacion(factura);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo generar la factura'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar diálogo de carga si hay error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creando factura: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  */

  // Mostrar opciones después de crear una factura
  Future<void> _mostrarOpcionesPostFacturacion(
    Map<String, dynamic> factura,
  ) async {
    await Future.delayed(
      Duration(seconds: 2),
    ); // Esperar un poco para que el usuario lea el mensaje

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Factura Creada Exitosamente',
          style: TextStyle(color: _textLight),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              'Factura ${factura['numero']} ha sido creada correctamente.',
              style: TextStyle(color: _textLight),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Total: \$${factura['total']?.toStringAsFixed(0) ?? '0'}',
              style: TextStyle(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _navegarADocumentos();
            },
            icon: Icon(Icons.receipt_long),
            label: Text('Ver Todos los Documentos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _compartirFactura(factura);
            },
            icon: Icon(Icons.share),
            label: Text('Compartir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Método para mostrar resumen de factura
  void _mostrarResumenFactura(Map<String, dynamic> factura) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Factura Generada', style: TextStyle(color: _textLight)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Número: ${factura['numero']}',
              style: TextStyle(color: _textLight, fontSize: 16),
            ),
            Text(
              'Total: \$${factura['total'].toStringAsFixed(0)}',
              style: TextStyle(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _compartirFactura(factura);
            },
            child: Text('Compartir Factura'),
          ),
        ],
      ),
    );
  }

  // Método para compartir factura
  Future<void> _compartirFactura(Map<String, dynamic> factura) async {
    try {
      final textoFactura = _impresionService.generarTextoImpresion(
        factura,
        esFactura: true,
      );
      await Share.share(textoFactura, subject: 'Factura ${factura['numero']}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error compartiendo factura: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          // Botón para mostrar resumen rápido de documentos del día
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.receipt_long),
                FutureBuilder<int>(
                  future: _obtenerConteoDocumentosHoy(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data! > 0) {
                      return Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${snapshot.data}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ],
            ),
            tooltip: 'Ver documentos del día',
            onPressed: () => _navegarADocumentos(),
          ),
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
    return FutureBuilder<List<Pedido>>(
      future: _pedidoService.getPedidosByMesa(nombre),
      builder: (context, snapshot) {
        List<Pedido> pedidosActivos = [];
        if (snapshot.hasData) {
          pedidosActivos = snapshot.data!
              .where((pedido) => pedido.estado == EstadoPedido.activo)
              .toList();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            double screenWidth = constraints.maxWidth;
            double iconSize = _getResponsiveIconSize(screenWidth);
            double fontSize = _getResponsiveFontSize(screenWidth, 10);
            double statusFontSize = _getResponsiveFontSize(screenWidth, 7);

            // Determinar el estado basado en pedidos activos
            bool tienePedidos = pedidosActivos.isNotEmpty;
            Color statusColor = tienePedidos ? Colors.red : Colors.green;
            String estadoTexto = tienePedidos
                ? '${pedidosActivos.length} pedido${pedidosActivos.length > 1 ? 's' : ''}'
                : 'Disponible';

            // Calcular total de todos los pedidos activos
            double totalGeneral = pedidosActivos.fold(
              0.0,
              (sum, pedido) => sum + pedido.total,
            );

            return GestureDetector(
              onTap: onTap,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _primary.withOpacity(0.3),
                    width: 1,
                  ),
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
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        estadoTexto,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: statusFontSize,
                        ),
                      ),
                    ),
                    if (totalGeneral > 0) ...[
                      SizedBox(height: 2),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '\$${totalGeneral.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: _primary,
                            fontSize: statusFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
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

    // Verificar si es una mesa especial (puede tener múltiples pedidos activos)
    final mesasEspeciales = ['DOMICILIO', 'CAJA', 'MESA AUXILIAR'];
    if (mesasEspeciales.contains(nombreMesa.toUpperCase())) {
      // Para mesas especiales, mostrar la lista de pedidos activos
      _mostrarPedidosMesaEspecial(mesaReal);
    } else {
      // Para mesas normales, usar la lógica original
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PedidoScreen(mesa: mesaReal)),
      );
    }
  }

  Future<void> _mostrarPedidosMesaEspecial(Mesa mesa) async {
    try {
      setState(() {
        isLoading = true;
      });

      // Cargar pedidos activos de esta mesa
      final pedidos = await _pedidoService.getPedidosByMesa(mesa.nombre);
      final pedidosActivos = pedidos
          .where((p) => p.estado == EstadoPedido.activo)
          .toList();

      setState(() {
        isLoading = false;
      });

      if (pedidosActivos.isEmpty) {
        // Si no hay pedidos activos, ir directamente a crear un nuevo pedido
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PedidoScreen(mesa: mesa)),
        );
        return;
      }

      // Mostrar la lista de pedidos activos
      showModalBottomSheet(
        context: context,
        backgroundColor: _cardBg,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pedidos Activos - ${mesa.nombre}',
                      style: TextStyle(
                        color: _textLight,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: _textLight),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Lista de pedidos
                Expanded(
                  child: ListView.builder(
                    itemCount: pedidosActivos.length,
                    itemBuilder: (context, index) {
                      final pedido = pedidosActivos[index];
                      return Card(
                        color: _cardBg.withOpacity(0.8),
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: _primary.withOpacity(0.3)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cabecera del pedido
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      pedido.cliente ?? 'Pedido ${index + 1}',
                                      style: TextStyle(
                                        color: _textLight,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '\$${pedido.total.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),

                              // Información del pedido
                              Row(
                                children: [
                                  Icon(Icons.person, color: _primary, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Mesero: ${pedido.mesero}',
                                    style: TextStyle(
                                      color: _textLight.withOpacity(0.8),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Icon(
                                    Icons.access_time,
                                    color: _primary,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '${pedido.fecha.hour.toString().padLeft(2, '0')}:${pedido.fecha.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: _textLight.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),

                              if (pedido.notas != null &&
                                  pedido.notas!.isNotEmpty) ...[
                                SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.note, color: _primary, size: 16),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        pedido.notas!,
                                        style: TextStyle(
                                          color: _textLight.withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              SizedBox(height: 8),

                              // Items del pedido
                              Text(
                                'Items (${pedido.items.length}):',
                                style: TextStyle(
                                  color: _textLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              ...pedido.items
                                  .take(3)
                                  .map(
                                    (item) => Padding(
                                      padding: EdgeInsets.only(
                                        left: 16,
                                        bottom: 2,
                                      ),
                                      child: Text(
                                        '• ${item.cantidad}x ${item.producto?.nombre ?? "Producto"} - \$${(item.precio * item.cantidad).toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: _textLight.withOpacity(0.8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),

                              if (pedido.items.length > 3)
                                Padding(
                                  padding: EdgeInsets.only(left: 16),
                                  child: Text(
                                    '... y ${pedido.items.length - 3} más',
                                    style: TextStyle(
                                      color: _textLight.withOpacity(0.6),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),

                              SizedBox(height: 12),

                              // Botón de pago (solo para admins)
                              if (Provider.of<UserProvider>(
                                context,
                                listen: false,
                              ).isAdmin)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context); // Cerrar el modal
                                      _mostrarDialogoPago(mesa, pedido);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.payment, size: 18),
                                        SizedBox(width: 8),
                                        Text('Procesar Pago'),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Botón para agregar nuevo pedido
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // Cerrar el modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PedidoScreen(mesa: mesa),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: BorderSide(color: _primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 18),
                        SizedBox(width: 8),
                        Text('Agregar Nuevo Pedido'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar pedidos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Métodos de utilidad para mostrar mensajes
  void _mostrarMensajeExito(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _mostrarMensajeError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _mostrarMensajeInfo(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Métodos auxiliares para el diálogo de pago mejorado
  Widget _buildSeccionTitulo(String titulo) {
    return Text(
      titulo,
      style: TextStyle(
        color: _textLight,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoRow(IconData icono, String etiqueta, String valor) {
    return Row(
      children: [
        Icon(icono, color: _primary, size: 18),
        SizedBox(width: 12),
        Text(
          '$etiqueta: ',
          style: TextStyle(color: _textLight.withOpacity(0.8), fontSize: 14),
        ),
        Expanded(
          child: Text(
            valor,
            style: TextStyle(
              color: _textLight,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
