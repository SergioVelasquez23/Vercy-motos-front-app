import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../services/cuadre_caja_service.dart';
import '../services/pedido_service.dart';
import '../services/resumen_cierre_completo_service.dart';
import '../models/resumen_cierre_completo.dart';
import '../utils/format_utils.dart';
import '../theme/app_theme.dart';

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
      String mensajeAmigable = _obtenerMensajeAmigable(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeAmigable),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
        
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

          // Log important values for debugging
            
            
          print(
            '  - Transferencias desde cuadreCompleto: $_transferenciasEsperadas',
          );
        });

        // Cargar datos del resumen completo si existe caja actual
        if (_cajaActual?.id != null) {
          await _cargarResumenCompleto(_cajaActual!.id!);
        }

        setState(() {
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
        // Error específico del cuadre completo - usar método alternativo
          

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Obteniendo datos de caja con método alternativo...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
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
              
          }

          // Recalcular el efectivo esperado: ventas + domicilios - gastos
          _efectivoEsperado = _ventasEfectivo + _totalDomicilios - _totalGastos;

          // Log del cálculo para depuració
        });
        _calcularDiferencia();
      } catch (ventasError) {
        // Error en método de respaldo - manejar silenciosamente
          
      }
    } catch (e) {
      String mensajeAmigable = _obtenerMensajeAmigable(e.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text(mensajeAmigable)),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
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
        // Error en fallback de emergencia - manejar silenciosamente
          
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
        

      // Agregar timeout específico para esta operación
      final resumenCompleto = await _resumenService
          .getResumenCierre(cuadreId)
          .timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'El resumen de cierre tardó demasiado en cargar. Continuando con datos básicos...',
              );
            },
          );

      setState(() {
        _resumenCompletoData = resumenCompleto;
        // Actualizar el efectivo esperado desde el resumen completo
        _efectivoEsperado =
            resumenCompleto.movimientosEfectivo.efectivoEsperado;

        // Also sync the sales values between cuadreCompleto and resumenCompleto
        if (resumenCompleto.movimientosEfectivo.ventasEfectivo > 0 ||
            resumenCompleto.movimientosEfectivo.ventasTransferencia > 0) {
            
          print(
            '  - Ventas Efectivo: ${resumenCompleto.movimientosEfectivo.ventasEfectivo}',
          );
          print(
            '  - Ventas Transferencia: ${resumenCompleto.movimientosEfectivo.ventasTransferencia}',
          );

          // Update the values from _ventasEfectivo and _transferenciasEsperadas
          if (_ventasEfectivo == 0) {
            _ventasEfectivo =
                resumenCompleto.movimientosEfectivo.ventasEfectivo;
          }
          if (_transferenciasEsperadas == 0) {
            _transferenciasEsperadas =
                resumenCompleto.movimientosEfectivo.ventasTransferencia;
          }
        }
      });
        
        
      print(
        '📊 Datos de gastos: ${resumenCompleto.resumenGastos.detallesGastos.length} gastos',
      );
      print(
        '📊 Datos de compras: ${resumenCompleto.resumenCompras.detallesComprasDesdeCaja.length} compras desde caja',
      );
    } catch (e) {
      // Error cargando resumen completo - continuar con datos básicos
        

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aviso: Usando datos básicos de caja. Resumen detallado no disponible.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
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

    // ✅ ELIMINADO: Diálogo de confirmación no necesario
    // Proceder directamente al cierre

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
      // Verificar si es el error específico de caja ya cerrada
      if (e.toString().contains('La caja ya está cerrada')) {
        // Actualizar el estado
        await _verificarEstadoCaja();
      }

      String mensajeAmigable = _obtenerMensajeAmigable(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeAmigable),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
        
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ ELIMINADO: Función de diálogo de confirmación no necesaria

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
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Cerrar Caja',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título con gradiente
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.point_of_sale, color: Colors.white, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'CIERRE DE CAJA',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (_cajaActual != null) ...[
                          SizedBox(height: 4),
                          Text(
                            _cajaActual!.nombre ?? 'Caja Principal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Verificación de estado de caja
                  if (!_hayCajaAbierta) ...[
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.warning.withOpacity(0.5)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'NO HAY CAJA ABIERTA',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.warning,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No hay ninguna caja abierta para cerrar.',
                            style: TextStyle(color: AppTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Botón para ir a abrir caja
                    Center(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.lock_open),
                        label: Text('Ir a Abrir Caja'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
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
                    // Secciones del Resumen Completo
                    if (_resumenCompletoData != null) ...[
                      _buildMovimientosEfectivoSection(),
                      SizedBox(height: 16),
                      _buildResumenVentasSection(),
                      SizedBox(height: 16),
                      _buildResumenGastosSection(),
                      SizedBox(height: 16),
                      _buildResumenComprasSection(),
                      SizedBox(height: 16),
                    ],

                    // Observaciones
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.note_alt, color: AppTheme.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Observaciones',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          TextFormField(
                            controller: _observacionesController,
                            maxLines: 3,
                            style: TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Observaciones del cierre (opcional)',
                              hintStyle: TextStyle(color: AppTheme.textMuted),
                              filled: true,
                              fillColor: AppTheme.surfaceDark,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppTheme.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Botón para cerrar caja
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.lock, size: 24),
                        label: Text(
                          'CERRAR CAJA',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                          icon: Icon(Icons.refresh, color: AppTheme.primary),
                          label: Text(
                            'Actualizar Estado',
                            style: TextStyle(color: AppTheme.primary),
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
          Text(label, style: TextStyle(color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Widget para construir tarjetas de contador (similar a pedidos_screen)
  // Métodos para construir las secciones del resumen completo

  Widget _buildMovimientosEfectivoSection() {
    final movimientos = _resumenCompletoData!.movimientosEfectivo;

    // Ensure consistent data between sections
    if (movimientos.ventasEfectivo == 0 &&
        _resumenCompletoData!.resumenVentas.ventasPorFormaPago.containsKey(
          'efectivo',
        )) {
      // If movimientos has zero but resumenVentas has a value, use that instead
      final efectivoValue =
          _resumenCompletoData!.resumenVentas.ventasPorFormaPago['efectivo'] ??
          0.0;
      if (efectivoValue > 0) {
          
        // Can't modify the object directly, but we can update the display values
        _ventasEfectivo = efectivoValue;
      }
    }

    if (movimientos.ventasTransferencia == 0 &&
        _resumenCompletoData!.resumenVentas.ventasPorFormaPago.containsKey(
          'transferencia',
        )) {
      // If movimientos has zero but resumenVentas has a value, use that instead
      final transferenciaValue =
          _resumenCompletoData!
              .resumenVentas
              .ventasPorFormaPago['transferencia'] ??
          0.0;
      if (transferenciaValue > 0) {
        print(
          '⚠️ Corrigiendo valor de ventas transferencia: $transferenciaValue',
        );
        // Can't modify the object directly, but we can update the display values
        _transferenciasEsperadas = transferenciaValue;
      }
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Movimientos de Efectivo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            'Fondo Inicial:',
            formatCurrency(movimientos.fondoInicial),
          ),
          _buildInfoRow(
            'Ventas Efectivo:',
            formatCurrency(
              _ventasEfectivo > 0
                  ? _ventasEfectivo
                  : movimientos.ventasEfectivo,
            ),
            valueColor: AppTheme.success,
          ),
          _buildInfoRow(
            'Ventas Transferencia:',
            formatCurrency(
              _transferenciasEsperadas > 0
                  ? _transferenciasEsperadas
                  : movimientos.ventasTransferencia,
            ),
            valueColor: AppTheme.primary,
          ),
          _buildInfoRow(
            'Gastos Efectivo:',
            formatCurrency(movimientos.gastosEfectivo),
            valueColor: AppTheme.error,
          ),
          _buildInfoRow(
            'Compras Efectivo:',
            formatCurrency(movimientos.comprasEfectivo),
            valueColor: AppTheme.warning,
          ),
          Divider(color: Colors.grey.withOpacity(0.3), height: 20),
          _buildInfoRow(
            'Efectivo Esperado:',
            formatCurrency(
              _efectivoEsperado > 0
                  ? _efectivoEsperado
                  : movimientos.efectivoEsperado,
            ),
            valueColor: Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildResumenGastosSection() {
    final gastos = _resumenCompletoData!.resumenGastos;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.money_off, color: AppTheme.error, size: 20),
              SizedBox(width: 8),
              Text(
                'Resumen de Gastos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            'Total Gastos:',
            formatCurrency(gastos.totalGastos),
            valueColor: AppTheme.error,
          ),
          _buildInfoRow(
            'Gastos Efectivo:',
            formatCurrency(gastos.gastosPorFormaPago['efectivo'] ?? 0),
            valueColor: AppTheme.error,
          ),
          _buildInfoRow(
            'Gastos Transferencia:',
            formatCurrency(gastos.gastosPorFormaPago['transferencia'] ?? 0),
            valueColor: AppTheme.error,
          ),

          if (gastos.detallesGastos.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              'Detalles de Gastos:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            ...gastos.detallesGastos.map(
              (gasto) => Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            gasto.concepto,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.error,
                            ),
                          ),
                        ),
                        Text(
                          formatCurrency(gasto.monto),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Proveedor: ${gasto.proveedor ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        Text(
                          'Forma: ${gasto.formaPago ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    if (gasto.fecha != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Fecha: ${_formatearFecha(gasto.fecha!)}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumenComprasSection() {
    final compras = _resumenCompletoData!.resumenCompras;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart, color: AppTheme.warning, size: 20),
              SizedBox(width: 8),
              Text(
                'Resumen de Compras',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            'Total Compras desde Caja:',
            formatCurrency(compras.totalComprasDesdeCaja),
            valueColor: AppTheme.warning,
          ),
          _buildInfoRow(
            'Total Compras No desde Caja:',
            formatCurrency(compras.totalComprasNoDesdeCaja),
            valueColor: AppTheme.textSecondary,
          ),
          _buildInfoRow(
            'Total General de Compras:',
            formatCurrency(compras.totalComprasGenerales),
            valueColor: AppTheme.warning,
          ),

          if (compras.detallesComprasDesdeCaja.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              'Compras Pagadas desde Caja:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            ...compras.detallesComprasDesdeCaja.map(
              (compra) => Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
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
                            color: AppTheme.warning,
                          ),
                        ),
                        Text(
                          formatCurrency(compra.total),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Proveedor: ${compra.proveedor}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(
                      'Medio: ${compra.medioPago}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    if (compra.fecha != null) ...[
                      Text(
                        'Fecha: ${_formatearFecha(compra.fecha!)}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumenVentasSection() {
    final ventas = _resumenCompletoData!.resumenVentas;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: AppTheme.success, size: 20),
              SizedBox(width: 8),
              Text(
                'Resumen de Ventas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow('Total Pedidos:', ventas.totalPedidos.toString()),
          _buildInfoRow(
            'Total Ventas:',
            formatCurrency(ventas.totalVentas),
            valueColor: AppTheme.success,
          ),
          _buildInfoRow(
            'Promedio por Pedido:',
            ventas.totalPedidos > 0
                ? formatCurrency(ventas.totalVentas / ventas.totalPedidos)
                : formatCurrency(0),
            valueColor: Colors.amber,
          ),
          Divider(color: Colors.grey.withOpacity(0.3), height: 24),
          Text(
            'Ventas por Forma de Pago:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          _buildInfoRow(
            'Ventas Efectivo:',
            formatCurrency(ventas.ventasPorFormaPago['efectivo'] ?? 0),
            valueColor: AppTheme.success,
          ),
          _buildInfoRow(
            'Ventas Transferencia:',
            formatCurrency(ventas.ventasPorFormaPago['transferencia'] ?? 0),
            valueColor: AppTheme.primary,
          ),
          if ((ventas.ventasPorFormaPago['tarjeta'] ?? 0) > 0)
            _buildInfoRow(
              'Ventas Tarjeta:',
              formatCurrency(ventas.ventasPorFormaPago['tarjeta'] ?? 0),
              valueColor: AppTheme.warning,
            ),
          if ((ventas.ventasPorFormaPago['mixto'] ?? 0) > 0)
            _buildInfoRow(
              'Ventas Mixtas:',
              formatCurrency(ventas.ventasPorFormaPago['mixto'] ?? 0),
              valueColor: AppTheme.secondary,
            ),

          // Display Ingresos Caja
          Divider(color: Colors.grey.withOpacity(0.3), height: 24),
          Text(
            'Ingresos Adicionales:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          _buildInfoRow(
            'Ingresos Efectivo:',
            formatCurrency(
              _resumenCompletoData?.movimientosEfectivo.ingresosEfectivo ?? 0,
            ),
            valueColor: Colors.amber,
          ),
          _buildInfoRow(
            'Total Ingresos Caja:',
            formatCurrency(
              _resumenCompletoData?.movimientosEfectivo.totalIngresosCaja ??
                  0,
            ),
            valueColor: Colors.amber,
          ),

          // Add quantity info by payment method
          Divider(color: Colors.grey.withOpacity(0.3), height: 24),
          Text(
            'Cantidad de Pedidos por Forma de Pago:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          _buildInfoRow(
            'Pedidos en Efectivo:',
            ventas.cantidadPorFormaPago['efectivo']?.toString() ?? "0",
            valueColor: AppTheme.success,
          ),
          _buildInfoRow(
            'Pedidos por Transferencia:',
            ventas.cantidadPorFormaPago['transferencia']?.toString() ?? "0",
            valueColor: AppTheme.primary,
          ),
          if ((ventas.cantidadPorFormaPago['tarjeta'] ?? 0) > 0)
            _buildInfoRow(
              'Pedidos con Tarjeta:',
              ventas.cantidadPorFormaPago['tarjeta']?.toString() ?? "0",
              valueColor: AppTheme.warning,
            ),
          if ((ventas.cantidadPorFormaPago['mixto'] ?? 0) > 0)
            _buildInfoRow(
              'Pedidos con Pago Mixto:',
              ventas.cantidadPorFormaPago['mixto']?.toString() ?? "0",
              valueColor: AppTheme.secondary,
            ),

          // Add a summary of today's sales instead of individual orders
          SizedBox(height: 16),
          Text(
            'Resumen General',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedidos del día: ${ventas.totalPedidos}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.success,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ventas totales: ${formatCurrency(ventas.totalVentas)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  /// Convierte errores técnicos en mensajes amigables para el usuario
  String _obtenerMensajeAmigable(String error) {
    // Convertir a minúsculas para comparaciones más fáciles
    final errorLower = error.toLowerCase();

    // Errores de conexión
    if (errorLower.contains('clientexception') ||
        errorLower.contains('failed to fetch') ||
        errorLower.contains('network error') ||
        errorLower.contains('connection') ||
        errorLower.contains('timeout') ||
        errorLower.contains('socketexception') ||
        errorLower.contains('no internet') ||
        errorLower.contains('unable to reach') ||
        errorLower.contains('host not found')) {
      return 'Error de conexión a WiFi';
    }

    // Errores de servidor
    if (errorLower.contains('500') ||
        errorLower.contains('internal server error') ||
        errorLower.contains('server error')) {
      return 'Error del servidor. Intente más tarde';
    }

    // Errores de autenticación
    if (errorLower.contains('401') ||
        errorLower.contains('unauthorized') ||
        errorLower.contains('authentication')) {
      return 'Error de autenticación. Inicie sesión nuevamente';
    }

    // Errores de permisos
    if (errorLower.contains('403') ||
        errorLower.contains('forbidden') ||
        errorLower.contains('access denied')) {
      return 'Sin permisos para realizar esta acción';
    }

    // Errores de datos no encontrados
    if (errorLower.contains('404') || errorLower.contains('not found')) {
      return 'Información no encontrada';
    }

    // Errores específicos de caja
    if (errorLower.contains('caja') && errorLower.contains('cerrada')) {
      return 'La caja ya está cerrada';
    }

    // Para cualquier otro error, mostrar mensaje genérico
    return 'Error del sistema. Intente nuevamente';
  }
}
