import 'package:flutter/material.dart';
import 'dart:async';
import '../models/mesa.dart';
import '../models/pedido.dart';
import '../services/pedido_service.dart';
import '../services/mesa_service.dart';
import '../services/notification_service.dart';
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

      final loadedMesas = await _mesaService.getMesas();
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

  Future<Pedido?> _obtenerPedidoActivoDeMesa(Mesa mesa) async {
    try {
      print('🔍 Buscando pedido activo para mesa: ${mesa.id}');
      if (mesa.pedidoActual != null &&
          mesa.pedidoActual!.estado == EstadoPedido.activo) {
        print('✅ Pedido activo encontrado en la mesa');
        return mesa.pedidoActual;
      }

      final pedidos = await _pedidoService.getPedidosByMesa(mesa.nombre);
      print('📋 Pedidos encontrados para la mesa: ${pedidos.length}');

      final pedidoActivo = pedidos.firstWhere(
        (pedido) => pedido.estado == EstadoPedido.activo,
        orElse: () => throw Exception('No hay pedido activo'),
      );
      print('✅ Pedido activo encontrado: ${pedidoActivo.id}');
      return pedidoActivo;
    } catch (e) {
      print('❌ Error al obtener pedido activo: $e');
      return null;
    }
  }

  Widget _buildMesaCard(Mesa mesa) {
    bool isOcupada = mesa.ocupada;
    Color statusColor = isOcupada ? Colors.red : Colors.green;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PedidoScreen(mesa: mesa)),
        );
      },
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Línea de estado en la parte superior izquierda
            Row(
              children: [
                Container(
                  width: 4, // Aumentado de 3 a 4
                  height: 16, // Aumentado de 12 a 16
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
                Spacer(),
              ],
            ),

            Spacer(),

            // Icono de mesa
            Container(
              padding: EdgeInsets.all(6), // Aumentado de 4 a 6
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.table_restaurant,
                color: _primary,
                size: 16,
              ), // Aumentado de 12 a 16
            ),

            SizedBox(height: 6), // Aumentado de 4 a 6
            // Nombre de la mesa
            Text(
              mesa.nombre,
              style: TextStyle(
                fontSize: 12, // Aumentado de 10 a 12
                fontWeight: FontWeight.bold,
                color: _textLight,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 4), // Aumentado de 2 a 4
            // Estado y total si existe
            Column(
              children: [
                Text(
                  isOcupada ? 'Ocupada' : 'Disponible',
                  style: TextStyle(
                    fontSize: 9, // Aumentado de 7 a 9
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (mesa.total > 0) ...[
                  SizedBox(height: 2), // Aumentado de 1 a 2
                  Text(
                    '\$${mesa.total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 9, // Aumentado de 7 a 9
                      color: _primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),

            Spacer(),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoCancelacion(Mesa mesa, Pedido pedido) async {
    String _medioPago = 'efectivo';
    bool _incluyePropina = false;
    TextEditingController _descuentoPorcentajeController =
        TextEditingController();
    TextEditingController _descuentoValorController = TextEditingController();

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
                            child: Text(
                              '${item.cantidad}x ${item.producto?.nombre ?? item.productoId}',
                              style: TextStyle(color: _textLight),
                            ),
                          ),
                          Text(
                            '\$${((item.producto?.precio ?? 0) * item.cantidad).toStringAsFixed(0)}',
                            style: TextStyle(color: _textLight),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                  SwitchListTile(
                    title: Text(
                      'Incluir propina',
                      style: TextStyle(color: _textLight),
                    ),
                    value: _incluyePropina,
                    onChanged: (value) {
                      setState(() => _incluyePropina = value);
                    },
                    activeColor: _primary,
                  ),

                  SizedBox(height: 16),

                  // Total
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
                        '\$${pedido.total.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

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
        // Preparar datos de pago
        double propina = 0.0;
        if (formResult['incluyePropina'] == true) {
          // Si hay descuentoValor, lo usamos como propina
          propina = double.tryParse(formResult['descuentoValor'] ?? '0') ?? 0.0;
        }

        print(
          '📝 Procesando pago del pedido: ${pedido.id} - Mesa: ${mesa.nombre}',
        );

        if (pedido.id.isEmpty) {
          throw Exception('El ID del pedido es inválido');
        }

        // Usar el nuevo método pagarPedido en lugar de cancelar
        await _pedidoService.pagarPedido(
          pedido.id,
          formaPago: formResult['medioPago'],
          propina: propina,
          pagadoPor: 'Mesa', // TODO: Obtener del usuario logueado
        );

        // Actualizar la mesa
        mesa.ocupada = false;
        mesa.total = 0;
        mesa.productos = [];
        mesa.pedidoActual = null;
        await _mesaService.updateMesa(mesa);

        // Notificar el cambio para actualizar el dashboard
        NotificationService().notificarCambioPedido(pedido);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido pagado exitosamente'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cardBg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        title: const Text('Mesas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMesas),
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
                Text(
                  nombre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textLight,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
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
    if (screenWidth < 600) return 120; // Móvil
    if (screenWidth < 900) return 140; // Tablet
    return 160; // Desktop
  }

  double _getResponsiveCardHeight(double screenWidth) {
    if (screenWidth < 600) return 90; // Móvil
    if (screenWidth < 900) return 100; // Tablet
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
