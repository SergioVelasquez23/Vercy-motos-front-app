import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../services/cuadre_caja_service.dart';
import '../services/pedido_service.dart';
import '../utils/format_utils.dart';

class CerrarCajaScreen extends StatefulWidget {
  @override
  _CerrarCajaScreenState createState() => _CerrarCajaScreenState();
}

class _CerrarCajaScreenState extends State<CerrarCajaScreen> {
  final Color primary = Color(0xFFFF6B00); // Color naranja fuego
  final Color bgDark = Color(0xFF1E1E1E); // Color de fondo negro
  final Color cardBg = Color(0xFF252525); // Color de tarjetas
  final Color textDark = Color(0xFFE0E0E0); // Color de texto claro
  final Color textLight = Color(0xFFA0A0A0); // Color de texto más suave

  // Controllers
  final TextEditingController _efectivoDeclaradoController =
      TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();

  // Services
  final CuadreCajaService _cuadreCajaService = CuadreCajaService();

  // Variables de estado
  bool _isLoading = false;
  bool _hayCajaAbierta = false;
  CuadreCaja? _cajaActual;
  double _efectivoEsperado =
      0.0; // Este es el efectivo esperado tras descontar gastos
  double _ventasEfectivo = 0.0; // Este es el monto bruto de ventas en efectivo
  double _transferenciasEsperadas = 0.0;
  double _totalGastos = 0.0;
  double _totalDomicilios = 0.0;
  double _diferencia = 0.0;

  // Contadores para resumen del cuadre actual
  int _totalPedidos = 0;
  int _totalProductos = 0;
  double _valorTotalVentas = 0.0;

  // Servicio de pedidos
  final PedidoService _pedidoService = PedidoService();

  @override
  void initState() {
    super.initState();
    _verificarEstadoCaja();
    _efectivoDeclaradoController.addListener(_calcularDiferencia);
  }

  @override
  void dispose() {
    _efectivoDeclaradoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  // Método para cargar el resumen de pedidos (total pedidos, productos y valor)
  Future<void> _cargarResumenPedidos() async {
    try {
      // Obtener los pedidos del cuadre actual (desde la apertura de caja)
      if (_cajaActual == null) return;

      final fechaDesde = _cajaActual!.fechaApertura;

      // Obtener todos los pedidos y filtrarlos por fecha
      final todosPedidos = await PedidoService.getPedidos();

      // Filtrar pedidos por fecha (desde la apertura de la caja)
      final pedidosDelCuadre = todosPedidos.where((pedido) {
        // Verificar si el pedido es posterior a la apertura de la caja
        return pedido.fecha.isAfter(fechaDesde) ||
            pedido.fecha.isAtSameMomentAs(fechaDesde);
      }).toList();

      // Contar pedidos y productos
      int pedidosCount = pedidosDelCuadre.length;
      int productosCount = 0;
      double valorTotal = 0.0;

      for (var pedido in pedidosDelCuadre) {
        // Contar productos en cada pedido
        productosCount += pedido.items.length;

        // Sumar el total del pedido
        valorTotal += pedido.total;
      }

      setState(() {
        _totalPedidos = pedidosCount;
        _totalProductos = productosCount;
        _valorTotalVentas = valorTotal;
      });

      print(
        '📊 Resumen de pedidos: $_totalPedidos pedidos, $_totalProductos productos, \$${_valorTotalVentas.toStringAsFixed(0)}',
      );

      setState(() {
        _totalPedidos = pedidosCount;
        _totalProductos = productosCount;
        _valorTotalVentas = valorTotal;
      });

      print(
        '📊 Resumen de pedidos: $_totalPedidos pedidos, $_totalProductos productos, \$${_valorTotalVentas.toStringAsFixed(0)}',
      );
    } catch (e) {
      print('Error cargando resumen de pedidos: $e');
    }
  }

  Future<void> _verificarEstadoCaja() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cuadres = await _cuadreCajaService.getAllCuadres();
      final cajaAbierta = cuadres.where((c) => !c.cerrada).toList();

      setState(() {
        _hayCajaAbierta = cajaAbierta.isNotEmpty;
        _cajaActual = cajaAbierta.isNotEmpty ? cajaAbierta.first : null;
      });

      if (_cajaActual != null) {
        await _cargarEfectivoEsperado();
      }
    } catch (e) {
      print('Error verificando estado de caja: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarEfectivoEsperado() async {
    setState(() => _isLoading = true);

    try {
      print('🔄 Iniciando carga de efectivo esperado...');

      // Cargar contadores de pedidos y productos
      await _cargarResumenPedidos();

      // Intentar obtener cuadre completo primero
      try {
        final cuadreCompleto = await _cuadreCajaService.getCuadreCompleto();
        print('✅ Datos del cuadre completo: $cuadreCompleto');

        setState(() {
          // Capturar valores individuales
          _ventasEfectivo = (cuadreCompleto['ventasEfectivo'] ?? 0.0)
              .toDouble();
          _transferenciasEsperadas =
              (cuadreCompleto['ventasTransferencias'] ?? 0.0).toDouble();
          _totalDomicilios = (cuadreCompleto['totalDomicilios'] ?? 0.0)
              .toDouble();
          _totalGastos = (cuadreCompleto['totalGastos'] ?? 0.0).toDouble();

          // El efectivo esperado debería incluir las ventas en efectivo y domicilios menos gastos
          // Si el backend ya incluye domicilios, usamos su valor directamente
          if (cuadreCompleto.containsKey('efectivoEsperado')) {
            _efectivoEsperado = (cuadreCompleto['efectivoEsperado'] ?? 0.0)
                .toDouble();

            // Asegurarnos que siempre agregamos los domicilios al efectivo esperado
            // a menos que el backend explícitamente indique que ya están incluidos
            if (_totalDomicilios > 0 &&
                !cuadreCompleto.containsKey('domiciliosIncluidos')) {
              print(
                'Agregando domicilios al efectivo esperado: $_totalDomicilios',
              );
              _efectivoEsperado += _totalDomicilios;
            }
          } else {
            // Calcular manualmente si no viene del backend
            _efectivoEsperado =
                _ventasEfectivo + _totalDomicilios - _totalGastos;
          }
        });
        _calcularDiferencia();
        print('💰 Datos del cuadre completo cargados exitosamente');
        print('💵 Efectivo esperado: $_efectivoEsperado');
        print('💳 Transferencias esperadas: $_transferenciasEsperadas');
        return;
      } catch (e) {
        print(
          '⚠️ Error obteniendo cuadre completo, usando método tradicional: $e',
        );
      }

      // Fallback: usar detalles de ventas tradicional
      final detallesVentas = await _cuadreCajaService.getDetallesVentas();
      setState(() {
        // Capturar las ventas brutas y los gastos por separado
        _ventasEfectivo = (detallesVentas['ventasEfectivo'] ?? 0).toDouble();
        _totalGastos = (detallesVentas['totalGastos'] ?? 0).toDouble();
        _transferenciasEsperadas = (detallesVentas['ventasTransferencias'] ?? 0)
            .toDouble();
        _totalDomicilios = (detallesVentas['totalDomicilios'] ?? 0).toDouble();

        // Verificar si el backend ya incluye domicilios en efectivoEsperadoPorVentas
        if (detallesVentas.containsKey('efectivoEsperadoPorVentas')) {
          _efectivoEsperado = (detallesVentas['efectivoEsperadoPorVentas'] ?? 0)
              .toDouble();

          // Siempre asegurarnos de incluir domicilios a menos que el backend diga que ya están incluidos
          if (_totalDomicilios > 0 &&
              !detallesVentas.containsKey('domiciliosIncluidos')) {
            print(
              'Agregando domicilios al efectivo esperado: $_totalDomicilios',
            );
            _efectivoEsperado += _totalDomicilios;
          }
        } else {
          // Calcular manualmente si no viene del backend
          // Sumamos ventas efectivo + domicilios - gastos
          _efectivoEsperado = _ventasEfectivo + _totalDomicilios - _totalGastos;
        }
      });
      _calcularDiferencia();

      // Intentar obtener datos más actualizados usando el endpoint de pedidos
      try {
        final ventasPorTipo = await _cuadreCajaService.getVentasPorTipoPago();
        print('💳 Ventas por tipo actualizadas: $ventasPorTipo');

        setState(() {
          // Actualizar con datos más precisos del endpoint de pedidos
          if (ventasPorTipo['transferencias'] != null) {
            _transferenciasEsperadas = (ventasPorTipo['transferencias'] ?? 0.0)
                .toDouble();
            print('💳 Transferencias actualizadas: $_transferenciasEsperadas');
          }
          // Actualizar ventas en efectivo (monto bruto)
          final efectivoFromPedidos = (ventasPorTipo['efectivo'] ?? 0.0)
              .toDouble();
          if (efectivoFromPedidos > _ventasEfectivo) {
            _ventasEfectivo = efectivoFromPedidos;
          }

          // Actualizar información de domicilios si está disponible
          if (ventasPorTipo.containsKey('domicilios') &&
              ventasPorTipo['domicilios'] != null) {
            _totalDomicilios = (ventasPorTipo['domicilios'] ?? 0.0).toDouble();
            print('🏠 Domicilios actualizados: $_totalDomicilios');
          }

          // Recalcular el efectivo esperado: ventas + domicilios - gastos
          _efectivoEsperado = _ventasEfectivo + _totalDomicilios - _totalGastos;

          // Log del cálculo para depuración
          print(
            '💰 Recálculo: efectivo=${_ventasEfectivo} + domicilios=${_totalDomicilios} - gastos=${_totalGastos} = ${_efectivoEsperado}',
          );

          print(
            '💰 Ventas efectivo actualizado: $_ventasEfectivo, ' +
                'Domicilios: $_totalDomicilios, ' +
                'Efectivo esperado (tras gastos): $_efectivoEsperado',
          );
        });
        _calcularDiferencia();
        print('✅ Datos actualizados con endpoint de pedidos');
      } catch (ventasError) {
        print(
          '⚠️ No se pudieron obtener datos del endpoint de pedidos: $ventasError',
        );
      }

      print('=== DETALLES DE VENTAS ===');
      print('Fondo inicial: \$${detallesVentas['fondoInicial']}');
      print('Total ventas: \$${detallesVentas['totalVentas']}');
      print('Ventas efectivo: \$${detallesVentas['ventasEfectivo']}');
      print(
        'Ventas transferencias: \$${detallesVentas['ventasTransferencias']}',
      );
      print('Ventas otros: \$${detallesVentas['ventasOtros']}');
      print('Total gastos: \$${detallesVentas['totalGastos']}');
      print('Total domicilios: ${detallesVentas['totalDomicilios']}');
      print('Efectivo esperado por ventas: \$${_efectivoEsperado}');
      print(
        'Total efectivo en caja: \$${detallesVentas['totalEfectivoEnCaja']}',
      );
      print('🏠 Domicilios: $_totalDomicilios');
      print('💳 Transferencias: \$_transferenciasEsperadas');
    } catch (e) {
      print('💥 Error cargando efectivo esperado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando datos de efectivo: $e'),
          backgroundColor: Colors.orange,
        ),
      );

      // Intentar obtener contadores por separado si falló todo lo demás
      try {
        final resumenVentas = await _cuadreCajaService.getResumenVentasHoy();
        print('📊 Resumen de emergencia: $resumenVentas');
        setState(() {
          _totalDomicilios = (resumenVentas['totalDomicilios'] ?? 0).toDouble();
          _totalGastos = (resumenVentas['totalGastos'] ?? 0.0).toDouble();
        });
      } catch (fallbackError) {
        print(
          '⚠️ No se pudieron obtener contadores de emergencia: $fallbackError',
        );
      }

      // Usar el valor del cuadre actual como fallback final
      if (_cajaActual != null) {
        setState(() {
          _efectivoEsperado = _cajaActual!.efectivoEsperado;
        });
        _calcularDiferencia();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calcularDiferencia() {
    final efectivoDeclarado =
        double.tryParse(_efectivoDeclaradoController.text) ?? 0;
    // La diferencia debe ser contra el total esperado
    // En caja debe haber: fondo inicial + (ventas efectivo + domicilios - gastos)
    // Nota: El backend podría no estar contabilizando domicilios en efectivoEsperado
    // así que los agregamos explícitamente
    final totalEsperado = (_cajaActual?.fondoInicial ?? 0) + _efectivoEsperado;
    setState(() {
      _diferencia = efectivoDeclarado - totalEsperado;
    });
  }

  Future<void> _cerrarCaja() async {
    if (_cajaActual == null) {
      _mostrarError('No hay caja abierta para cerrar');
      return;
    }

  // Eliminado: No se requiere efectivo declarado

    // Mostrar confirmación
    final confirmar = await _mostrarDialogoConfirmacion();
    if (!confirmar) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final responsable = userProvider.userName ?? _cajaActual!.responsable;

      final cuadre = await _cuadreCajaService.updateCuadre(
        _cajaActual!.id!,
        responsable: responsable,
        observaciones: 'Caja cerrada - ${_observacionesController.text}',
        cerrarCaja: true,
        estado: 'cerrada',
      );

      if (cuadre.id != null) {
        _mostrarExito('Caja cerrada exitosamente');
        // Volver a la pantalla anterior
        Navigator.of(
          context,
        ).pop(true); // true indica que se cerró exitosamente
      } else {
        throw Exception('Error al cerrar el cuadre');
      }
    } catch (e) {
      String errorMessage = 'Error al cerrar caja: $e';

      // Verificar si es el error específico de caja ya cerrada
      if (e.toString().contains('La caja ya está cerrada')) {
        errorMessage =
            'La caja ya está cerrada. No se puede cerrar una caja que ya ha sido cerrada.';
        // Actualizar el estado
        await _verificarEstadoCaja();
      }

      _mostrarError(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _mostrarDialogoConfirmacion() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: cardBg,
              title: Text(
                'Confirmar Cierre de Caja',
                style: TextStyle(color: textDark),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Está seguro que desea cerrar la caja?',
                    style: TextStyle(color: textDark),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Resumen:',
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Fondo inicial: \$${(_cajaActual?.fondoInicial ?? 0).toStringAsFixed(0)}',
                    style: TextStyle(color: textLight),
                  ),
                  Text(
                    'Monto inicial: ${formatCurrency(_cajaActual?.fondoInicial ?? 0)}',
                    style: TextStyle(color: textLight),
                  ),
                  Text(
                    'Ventas en efectivo: \$${_ventasEfectivo.toStringAsFixed(0)}',
                    style: TextStyle(color: textLight),
                  ),
                  // Mostrar transferencias (siempre)
                  Text(
                    'Ventas en transferencias: \$${_transferenciasEsperadas.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: _transferenciasEsperadas > 0
                          ? textLight
                          : Colors.grey,
                    ),
                  ),
                  // Eliminado: No mostrar ventas a domicilio
                  if (_totalGastos > 0)
                    Text(
                      'Total gastos: \$${_totalGastos.toStringAsFixed(0)}',
                      style: TextStyle(color: Colors.red[300]),
                    ),
                  Divider(color: Colors.grey.withOpacity(0.3)),
                  Text(
                    'Cálculo: ${(_cajaActual?.fondoInicial ?? 0).toStringAsFixed(0)} + ${_ventasEfectivo.toStringAsFixed(0)} - ${_totalGastos.toStringAsFixed(0)}',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Total esperado en caja: \$${((_cajaActual?.fondoInicial ?? 0) + _efectivoEsperado).toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Eliminado: No mostrar efectivo declarado ni diferencia
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancelar', style: TextStyle(color: textLight)),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primary),
                  child: Text(
                    'Cerrar Caja',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          'Cerrar Caja',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Center(
                    child: Text(
                      'CIERRE DE CAJA',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Verificación de estado de caja
                  if (!_hayCajaAbierta) ...[
                    Card(
                      color: Colors.orange.shade900,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.orange.shade300),
                                SizedBox(width: 8),
                                Text(
                                  'NO HAY CAJA ABIERTA',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade100,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No hay ninguna caja abierta para cerrar.',
                              style: TextStyle(
                                color: Colors.orange.shade100,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Botón para ir a abrir caja
                    Center(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.lock_open),
                        label: Text('Ir a Abrir Caja'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/abrir_caja');
                        },
                      ),
                    ),
                  ] else if (_cajaActual != null) ...[
                    // Panel de Resumen de Ventas (estilo pedidos_screen)
                    Card(
                      elevation: 4,
                      color: Color(0xFF2F1500), // Color marrón oscuro
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Total Pedidos
                            _buildCounterCard(
                              icon: Icons.receipt,
                              count: _totalPedidos.toString(),
                              label: 'Total',
                              color: primary,
                            ),
                            // Total Items
                            _buildCounterCard(
                              icon: Icons.fastfood,
                              count: _totalProductos.toString(),
                              label: 'Items',
                              color: primary,
                            ),
                            // Valor Total
                            _buildCounterCard(
                              icon: Icons.attach_money,
                              count:
                                  '\$${_valorTotalVentas.toStringAsFixed(0)}',
                              label: 'Valor Total',
                              color: primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Información de la caja abierta
                    Card(
                      elevation: 4,
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Información de la Caja Abierta',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildInfoRow('Caja:', _cajaActual!.nombre),
                            _buildInfoRow(
                              'Responsable:',
                              _cajaActual!.responsable,
                            ),
                            _buildInfoRow(
                              'Fecha apertura:',
                              '${_cajaActual!.fechaApertura.day}/${_cajaActual!.fechaApertura.month}/${_cajaActual!.fechaApertura.year} ${_cajaActual!.fechaApertura.hour}:${_cajaActual!.fechaApertura.minute.toString().padLeft(2, '0')}',
                            ),
                            _buildInfoRow(
                              'Monto inicial:',
                              formatCurrency(_cajaActual!.fondoInicial),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Información financiera
                    Card(
                      elevation: 4,
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumen Financiero',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildInfoRow(
                              'Monto inicial:',
                              formatCurrency(_cajaActual!.fondoInicial),
                            ),
                            _buildInfoRow(
                              'Ventas en efectivo:',
                              formatCurrency(_ventasEfectivo),
                              valueColor: Colors.blue,
                            ),
                            // Mostrar transferencias (siempre mostrar, aunque sea 0)
                            _buildInfoRow(
                              'Ventas en transferencias:',
                              formatCurrency(_transferenciasEsperadas),
                              valueColor: _transferenciasEsperadas > 0
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            // Mostrar gastos si los hay
                            if (_totalGastos > 0)
                              _buildInfoRow(
                                'Total gastos:',
                                formatCurrency(_totalGastos),
                                valueColor: Colors.red,
                              ),
                            // Mostrar domicilios siempre (como las transferencias)
                            _buildInfoRow(
                              'Ventas domicilio:',
                              formatCurrency(_totalDomicilios),
                              valueColor: _totalDomicilios > 0
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                            // Separador visual
                            if (_transferenciasEsperadas > 0 ||
                                _totalGastos > 0) ...[
                              SizedBox(height: 8),
                              Divider(color: Colors.grey.withOpacity(0.3)),
                              SizedBox(height: 8),
                            ],
                            _buildInfoRow(
                              'Total esperado en caja:',
                              formatCurrency(
                                _cajaActual!.fondoInicial + _efectivoEsperado,
                              ),
                              valueColor: Colors.green,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Eliminado: No se requiere efectivo declarado ni diferencia

                    // Observaciones
                    Card(
                      elevation: 4,
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Observaciones',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 10),
                            TextFormField(
                              controller: _observacionesController,
                              maxLines: 3,
                              style: TextStyle(color: textDark),
                              decoration: InputDecoration(
                                labelText:
                                    'Observaciones del cierre (opcional)',
                                labelStyle: TextStyle(color: textLight),
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30),

                    // Botón para cerrar caja
                    Center(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.lock),
                        label: Text('CERRAR CAJA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 4,
                        ),
                        onPressed: _cerrarCaja,
                      ),
                    ),
                  ],

                  SizedBox(height: 20),

                  // Botón para actualizar estado
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.refresh, color: primary),
                          label: Text(
                            'Actualizar Estado',
                            style: TextStyle(color: primary),
                          ),
                          onPressed: _verificarEstadoCaja,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Widget para construir filas de información
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textLight)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Widget para construir tarjetas de contador (similar a pedidos_screen)
  Widget _buildCounterCard({
    required IconData icon,
    required String count,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
