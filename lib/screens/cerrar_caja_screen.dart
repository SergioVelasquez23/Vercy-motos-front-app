import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../services/cuadre_caja_service.dart';
import '../services/pedido_service.dart';
import '../services/resumen_cierre_completo_service.dart';
import '../models/resumen_cierre_completo.dart';
import '../utils/format_utils.dart';

class CerrarCajaScreen extends StatefulWidget {
  const CerrarCajaScreen({super.key});

  @override
  _CerrarCajaScreenState createState() => _CerrarCajaScreenState();
}

class _CerrarCajaScreenState extends State<CerrarCajaScreen> {
  // Store cuadre completo response
  Map<String, dynamic>? _cuadreCompletoData;
  // Store resumen completo data
  ResumenCierreCompleto? _resumenCompletoData;
  final ResumenCierreCompletoService _resumenService =
      ResumenCierreCompletoService();
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
      // Intentar obtener cuadre completo primero
      try {
        final cuadreCompleto = await _cuadreCajaService.getCuadreCompleto();
        setState(() {
          _cuadreCompletoData = cuadreCompleto;
        });

        // Debug: Mostrar específicamente los campos de cantidad
        setState(() {
          // Capturar valores individuales
          _ventasEfectivo = (cuadreCompleto['ventasEfectivo'] ?? 0.0)
              .toDouble();
          _transferenciasEsperadas =
              (cuadreCompleto['ventasTransferencias'] ?? 0.0).toDouble();
          _totalDomicilios = (cuadreCompleto['totalDomicilios'] ?? 0.0)
              .toDouble();
          _totalGastos = (cuadreCompleto['totalGastos'] ?? 0.0).toDouble();

          // Cargar datos del resumen completo si existe caja actual
          if (_cajaActual?.id != null) {
            _cargarResumenCompleto(_cajaActual!.id!);
          }

          // NUEVOS: Obtener contadores del backend con fallbacks mejorados
          // Convertir null a 0 para totalPedidos
          var totalPedidosRaw = cuadreCompleto['totalPedidos'];
          _totalPedidos = (totalPedidosRaw == null)
              ? 0
              : (totalPedidosRaw as num).toInt();

          // Obtener cantidades individuales (convertir null a 0)
          int cantidadEfectivo = (cuadreCompleto['cantidadEfectivo'] == null)
              ? 0
              : (cuadreCompleto['cantidadEfectivo'] as num).toInt();
          int cantidadTransferencias =
              (cuadreCompleto['cantidadTransferencias'] == null)
              ? 0
              : (cuadreCompleto['cantidadTransferencias'] as num).toInt();
          int cantidadTarjetas = (cuadreCompleto['cantidadTarjetas'] == null)
              ? 0
              : (cuadreCompleto['cantidadTarjetas'] as num).toInt();
          int cantidadOtros = (cuadreCompleto['cantidadOtros'] == null)
              ? 0
              : (cuadreCompleto['cantidadOtros'] as num).toInt();

          // Si totalPedidos es 0 o null, usar la suma de cantidades individuales
          if (_totalPedidos == 0) {
            _totalPedidos =
                cantidadEfectivo +
                cantidadTransferencias +
                cantidadTarjetas +
                cantidadOtros;
          }
          // Para totalProductos, también manejar null
          var totalProductosRaw = cuadreCompleto['totalProductos'];
          _totalProductos = (totalProductosRaw == null)
              ? 0
              : (totalProductosRaw as num).toInt();

          // Si totalProductos es 0, usar el mismo valor que totalPedidos como fallback
          if (_totalProductos == 0) {
            _totalProductos = _totalPedidos;
          }

          // Obtener valor total de ventas ANTES de la validación del respaldo
          _valorTotalVentas =
              (cuadreCompleto['totalVentas'] ??
                      cuadreCompleto['ventasEfectivo'] ??
                      0.0)
                  .toDouble();

          // Respaldo adicional: Si aún tenemos 0 pedidos pero hay ventas significativas
          if (_totalPedidos == 0 && _valorTotalVentas > 0) {
            // Usar el cantidadPedidos del backend como respaldo
            int cantidadPedidosBackend =
                (cuadreCompleto['cantidadPedidos'] == null)
                ? 0
                : (cuadreCompleto['cantidadPedidos'] as num).toInt();

            if (cantidadPedidosBackend > 0) {
              _totalPedidos = cantidadPedidosBackend;
              _totalProductos = cantidadPedidosBackend;
            } else {
              // Último respaldo: estimar pedidos basado en ventas promedio
              int pedidosEstimados = (_valorTotalVentas / 30000)
                  .ceil(); // ~30k promedio por pedido
              if (pedidosEstimados > 0) {
                _totalPedidos = pedidosEstimados;
                _totalProductos = pedidosEstimados;
              }
            }
          }
          // El efectivo esperado debería incluir las ventas en efectivo y domicilios menos gastos
          // Si el backend ya incluye domicilios, usamos su valor directamente
          if (cuadreCompleto.containsKey('efectivoEsperado')) {
            _efectivoEsperado = (cuadreCompleto['efectivoEsperado'] ?? 0.0)
                .toDouble();

            // Asegurarnos que siempre agregamos los domicilios al efectivo esperado
            // a menos que el backend explícitamente indique que ya están incluidos
            if (_totalDomicilios > 0 &&
                !cuadreCompleto.containsKey('domiciliosIncluidos')) {
              _efectivoEsperado += _totalDomicilios;
            }
          } else {
            // Calcular manualmente si no viene del backend
            _efectivoEsperado =
                _ventasEfectivo + _totalDomicilios - _totalGastos;
          }
        });
        _calcularDiferencia();
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

        setState(() {
          // Actualizar con datos más precisos del endpoint de pedidos
          if (ventasPorTipo['transferencias'] != null) {
            _transferenciasEsperadas = (ventasPorTipo['transferencias'] ?? 0.0)
                .toDouble();
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

          // Log del cálculo para depuració
        });
        _calcularDiferencia();
      } catch (ventasError) {
        print(
          '⚠️ No se pudieron obtener datos del endpoint de pedidos: $ventasError',
        );
      }
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

  Future<void> _cargarResumenCompleto(String cuadreId) async {
    try {
      print('🔍 Cargando resumen completo para cuadre: $cuadreId');
      final resumenCompleto = await _resumenService.getResumenCierre(cuadreId);

      setState(() {
        _resumenCompletoData = resumenCompleto;
      });
      print('✅ Resumen completo cargado exitosamente');
      print(
        '📊 Datos de gastos: ${resumenCompleto.resumenGastos.detallesGastos.length} gastos',
      );
      print(
        '📊 Datos de compras: ${resumenCompleto.resumenCompras.detallesComprasDesdeCaja.length} compras desde caja',
      );
    } catch (e) {
      print('❌ Error cargando resumen completo: $e');
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

                    // Información de la caja abierta (campos del cuadre completo)
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
                            _buildInfoRow(
                              'Caja:',
                              _cajaActual?.nombre ?? 'Caja Principal',
                            ),
                            _buildInfoRow(
                              'Responsable:',
                              _cuadreCompletoData?['responsable'] ?? '',
                            ),
                            _buildInfoRow(
                              'Fecha apertura:',
                              _cuadreCompletoData?['fechaInicio'] != null
                                  ? _cuadreCompletoData!['fechaInicio']
                                        .toString()
                                        .substring(0, 16)
                                        .replaceFirst('T', ' ')
                                  : '',
                            ),
                            _buildInfoRow(
                              'Fecha cierre:',
                              _cuadreCompletoData?['fechaFin'] != null
                                  ? _cuadreCompletoData!['fechaFin']
                                        .toString()
                                        .substring(0, 16)
                                        .replaceFirst('T', ' ')
                                  : '',
                            ),
                            _buildInfoRow(
                              'Monto inicial:',
                              formatCurrency(
                                _cuadreCompletoData?['totalInicial'] ?? 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Información financiera (campos del cuadre completo)
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
                              formatCurrency(
                                _cuadreCompletoData?['totalInicial'] ?? 0,
                              ),
                            ),
                            _buildInfoRow(
                              'Ventas en efectivo:',
                              formatCurrency(
                                _cuadreCompletoData?['ventasEfectivo'] ?? 0,
                              ),
                              valueColor: Colors.blue,
                            ),
                            _buildInfoRow(
                              'Ventas en transferencias:',
                              formatCurrency(
                                _cuadreCompletoData?['ventasTransferencias'] ??
                                    0,
                              ),
                              valueColor: Colors.green,
                            ),
                            _buildInfoRow(
                              'Ventas en tarjetas:',
                              formatCurrency(
                                _cuadreCompletoData?['ventasTarjetas'] ?? 0,
                              ),
                              valueColor: Colors.purple,
                            ),
                            _buildInfoRow(
                              'Total ventas:',
                              formatCurrency(
                                _cuadreCompletoData?['totalVentas'] ?? 0,
                              ),
                              valueColor: Colors.blueGrey,
                            ),
                            _buildInfoRow(
                              'Total propinas:',
                              formatCurrency(
                                _cuadreCompletoData?['totalPropinas'] ?? 0,
                              ),
                              valueColor: Colors.teal,
                            ),
                            _buildInfoRow(
                              'Total gastos:',
                              formatCurrency(
                                _cuadreCompletoData?['totalGastos'] ?? 0,
                              ),
                              valueColor: Colors.red,
                            ),
                            if (_cuadreCompletoData?['gastosPorTipo'] != null)
                              ..._cuadreCompletoData!['gastosPorTipo'].entries
                                  .map(
                                    (e) => _buildInfoRow(
                                      'Gasto: ${e.key}',
                                      formatCurrency(e.value),
                                      valueColor: Colors.red,
                                    ),
                                  ),
                            _buildInfoRow(
                              'Total esperado en caja:',
                              formatCurrency(
                                _cuadreCompletoData?['debeTener'] ?? 0,
                              ),
                              valueColor: Colors.green,
                            ),
                            _buildInfoRow(
                              'Cantidad facturas:',
                              (_cuadreCompletoData?['cantidadFacturas'] ?? 0)
                                  .toString(),
                            ),
                            _buildInfoRow(
                              'Cantidad pedidos:',
                              (_cuadreCompletoData?['cantidadPedidos'] ?? 0)
                                  .toString(),
                            ),
                            if (_cuadreCompletoData?['detalleVentas'] != null)
                              ..._cuadreCompletoData!['detalleVentas'].entries
                                  .map(
                                    (e) => _buildInfoRow(
                                      'Detalle venta: ${e.key}',
                                      formatCurrency(e.value),
                                      valueColor: Colors.blue,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Secciones del Resumen Completo
                    if (_resumenCompletoData != null) ...[
                      _buildResumenFinalSection(),
                      SizedBox(height: 20),
                      _buildMovimientosEfectivoSection(),
                      SizedBox(height: 20),
                      _buildResumenGastosSection(),
                      SizedBox(height: 20),
                      _buildResumenComprasSection(),
                      SizedBox(height: 20),
                      _buildResumenVentasSection(),
                      SizedBox(height: 20),
                    ],

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

  // Métodos para construir las secciones del resumen completo
  Widget _buildResumenFinalSection() {
    final resumen = _resumenCompletoData!.resumenFinal;
    final Color cardBg = Color(0xFF2A2A2A);
    final Color textDark = Colors.white;
    final Color textLight = Colors.white70;

    return Card(
      elevation: 4,
      color: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen Final',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              'Fondo Inicial:',
              formatCurrency(resumen.fondoInicial),
            ),
            _buildInfoRow(
              'Ventas Efectivo:',
              formatCurrency(resumen.ventasEfectivo),
              valueColor: Colors.green,
            ),
            _buildInfoRow(
              'Total Gastos:',
              formatCurrency(resumen.totalGastos),
              valueColor: Colors.red,
            ),
            _buildInfoRow(
              'Efectivo Esperado:',
              formatCurrency(resumen.efectivoEsperado),
              valueColor: Colors.blue,
            ),
            // _buildInfoRow('Diferencia:', formatCurrency(resumen.diferencia),
            //   valueColor: resumen.diferencia >= 0 ? Colors.green : Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildMovimientosEfectivoSection() {
    final movimientos = _resumenCompletoData!.movimientosEfectivo;
    final Color cardBg = Color(0xFF2A2A2A);

    return Card(
      elevation: 4,
      color: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Movimientos de Efectivo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              'Fondo Inicial:',
              formatCurrency(movimientos.fondoInicial),
            ),
            _buildInfoRow(
              'Ventas Efectivo:',
              formatCurrency(movimientos.ventasEfectivo),
              valueColor: Colors.green,
            ),
            _buildInfoRow(
              'Ventas Transferencia:',
              formatCurrency(movimientos.ventasTransferencia),
              valueColor: Colors.blue,
            ),
            // _buildInfoRow('Total Gastos:', formatCurrency(movimientos.totalGastos), valueColor: Colors.red),
            // _buildInfoRow('Compras desde Caja:', formatCurrency(movimientos.comprasDesdeCaja), valueColor: Colors.orange),
            // _buildInfoRow('Efectivo Final:', formatCurrency(movimientos.efectivoFinal), valueColor: Colors.yellow),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenGastosSection() {
    final gastos = _resumenCompletoData!.resumenGastos;
    final Color cardBg = Color(0xFF2A2A2A);
    final Color textDark = Colors.white;
    final Color textLight = Colors.white70;

    return Card(
      elevation: 4,
      color: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de Gastos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              'Total Gastos:',
              formatCurrency(gastos.totalGastos),
              valueColor: Colors.red,
            ),
            _buildInfoRow(
              'Gastos Efectivo:',
              formatCurrency(gastos.gastosPorFormaPago['efectivo'] ?? 0),
              valueColor: Colors.red,
            ),
            _buildInfoRow(
              'Gastos Transferencia:',
              formatCurrency(gastos.gastosPorFormaPago['transferencia'] ?? 0),
              valueColor: Colors.red,
            ),

            if (gastos.detallesGastos.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Detalles de Gastos:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
              SizedBox(height: 8),
              ...gastos.detallesGastos.map(
                (gasto) => Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Gasto: ${gasto.concepto}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          Text(
                            formatCurrency(gasto.monto),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Concepto: ${gasto.concepto ?? 'N/A'}',
                            style: TextStyle(fontSize: 12, color: textLight),
                          ),
                          Text(
                            'Forma: ${gasto.formaPago ?? 'N/A'}',
                            style: TextStyle(fontSize: 12, color: textLight),
                          ),
                        ],
                      ),
                      Text(
                        'Proveedor: ${gasto.proveedor ?? 'N/A'}',
                        style: TextStyle(fontSize: 12, color: textLight),
                      ),
                      if (gasto.fecha != null) ...[
                        SizedBox(height: 4),
                        Text(
                          'Fecha: ${_formatearFecha(gasto.fecha!)}',
                          style: TextStyle(fontSize: 12, color: textLight),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResumenComprasSection() {
    final compras = _resumenCompletoData!.resumenCompras;
    final Color cardBg = Color(0xFF2A2A2A);
    final Color textDark = Colors.white;
    final Color textLight = Colors.white70;

    return Card(
      elevation: 4,
      color: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de Compras',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              'Total Compras desde Caja:',
              formatCurrency(compras.totalComprasDesdeCaja),
              valueColor: Colors.orange,
            ),
            _buildInfoRow(
              'Total Facturas desde Caja:',
              compras.totalFacturasDesdeCaja.toString(),
            ),
            _buildInfoRow(
              'Total Compras No desde Caja:',
              formatCurrency(compras.totalComprasNoDesdeCaja),
              valueColor: Colors.orange,
            ),
            _buildInfoRow(
              'Total Facturas No desde Caja:',
              compras.totalFacturasNoDesdeCaja.toString(),
            ),
            _buildInfoRow(
              'Total General de Compras:',
              formatCurrency(compras.totalComprasGenerales),
              valueColor: Colors.orange,
            ),

            if (compras.detallesComprasDesdeCaja.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Compras Pagadas desde Caja:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
              SizedBox(height: 8),
              ...compras.detallesComprasDesdeCaja.map(
                (compra) => Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            compra.numero,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            formatCurrency(compra.total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Proveedor: ${compra.proveedor}',
                        style: TextStyle(fontSize: 12, color: textLight),
                      ),
                      Text(
                        'Medio: ${compra.medioPago}',
                        style: TextStyle(fontSize: 12, color: textLight),
                      ),
                      if (compra.fecha != null) ...[
                        Text(
                          'Fecha: ${_formatearFecha(compra.fecha!)}',
                          style: TextStyle(fontSize: 12, color: textLight),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResumenVentasSection() {
    final ventas = _resumenCompletoData!.resumenVentas;
    final Color cardBg = Color(0xFF2A2A2A);

    return Card(
      elevation: 4,
      color: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de Ventas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow('Total Pedidos:', ventas.totalPedidos.toString()),
            _buildInfoRow(
              'Total Ventas:',
              formatCurrency(ventas.totalVentas),
              valueColor: Colors.green,
            ),
            _buildInfoRow(
              'Ventas Efectivo:',
              formatCurrency(ventas.ventasPorFormaPago['efectivo'] ?? 0),
              valueColor: Colors.green,
            ),
            _buildInfoRow(
              'Ventas Transferencia:',
              formatCurrency(ventas.ventasPorFormaPago['transferencia'] ?? 0),
              valueColor: Colors.blue,
            ),

            if (ventas.detallesPedidos.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Últimos Pedidos:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              ...ventas.detallesPedidos
                  .take(5)
                  .map(
                    (pedido) => Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pedido #${pedido.id}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            formatCurrency(pedido.total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatearFecha(String fecha) {
    try {
      final dateTime = DateTime.parse(fecha);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return fecha;
    }
  }
}
