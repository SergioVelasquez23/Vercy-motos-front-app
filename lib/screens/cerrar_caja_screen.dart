import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../services/cuadre_caja_service.dart';
import '../services/pedido_service.dart';
import '../services/resumen_cierre_completo_service.dart';
import '../services/backup_inventario_service.dart';
import '../models/resumen_cierre_completo.dart';
import '../utils/format_utils.dart';
import '../utils/file_download_helper.dart';
import '../theme/app_theme.dart';
import '../utils/logger.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';

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
  final BackupInventarioService _backupService = BackupInventarioService();

  // Estado de conciliación de inventario
  List<Map<String, dynamic>>? _conciliacionData;
  bool _descargandoExcel = false;

  // Variables de estado
  bool _isLoading = false;
  bool _hayCajaAbierta = false;
  CuadreCaja? _cajaActual;
  // Todas las cajas abiertas (puede haber una LOCAL y una ENVIOS a la vez).
  // _cajaActual es "la que se está viendo/cerrando ahora mismo" de esta lista.
  List<CuadreCaja> _cajasAbiertas = [];
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
        _cajasAbiertas = cajaAbierta;
        // Si la caja que se estaba viendo sigue abierta, mantenerla
        // seleccionada (evita que un refresh salte de vuelta a otra caja);
        // si no, elegir la primera disponible.
        final actualSigueAbierta = _cajaActual != null &&
            cajaAbierta.any((c) => c.id == _cajaActual!.id);
        if (!actualSigueAbierta) {
          _cajaActual = cajaAbierta.isNotEmpty ? cajaAbierta.first : null;
        }
      });

      if (_cajaActual != null) {
        await _cargarEfectivoEsperado();
      }
    } catch (e) {
      showErrorDialog(context, errorMessage(e));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Cambia cuál de las cajas abiertas (LOCAL/ENVIOS) se está viendo/cerrando
  /// y recarga sus datos — solo visible cuando hay más de una abierta.
  Future<void> _seleccionarCaja(CuadreCaja caja) async {
    if (_cajaActual?.id == caja.id) return;
    setState(() => _cajaActual = caja);
    await _cargarEfectivoEsperado();
  }

  Future<void> _cargarEfectivoEsperado() async {
    setState(() => _isLoading = true);

    try {
      // Intentar obtener cuadre completo primero
      try {
        final cuadreCompleto = await _cuadreCajaService.getCuadreCompleto(
          tipoCaja: _cajaActual?.tipoCaja,
        );
        appLog('');
        appLog('═══════════════════════════════════════════════════');
        appLog('📥 RESPUESTA DEL BACKEND - CUADRE COMPLETO:');
        appLog('   efectivoEsperado: ${cuadreCompleto['efectivoEsperado']}');
        appLog(
          '   fondoInicial: ${cuadreCompleto['fondoInicial'] ?? _cajaActual?.fondoInicial}',
        );
        appLog('   ventasEfectivo: ${cuadreCompleto['ventasEfectivo']}');
        appLog(
          '   ventasTransferencias: ${cuadreCompleto['ventasTransferencias']}',
        );
        appLog('   totalGastos: ${cuadreCompleto['totalGastos']}');
        appLog('   totalDomicilios: ${cuadreCompleto['totalDomicilios']}');
        appLog('═══════════════════════════════════════════════════');
        appLog('');
        
        if (!mounted) return;
        setState(() {
          _cuadreCompletoData = cuadreCompleto;
          // Capturar valores individuales
          _ventasEfectivo = (cuadreCompleto['ventasEfectivo'] ?? 0.0)
              .toDouble();
          _transferenciasEsperadas =
              (cuadreCompleto['ventasTransferencias'] ?? 0.0).toDouble();
          _totalDomicilios = (cuadreCompleto['totalDomicilios'] ?? 0.0)
              .toDouble();
          _totalGastos = (cuadreCompleto['totalGastos'] ?? 0.0).toDouble();

          // Log important values for debugging
            
            
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
          // Efectivo esperado = ventas en efectivo + fondo inicial
          if (cuadreCompleto.containsKey('efectivoEsperado')) {
            final ventasEfectivo = (cuadreCompleto['efectivoEsperado'] ?? 0.0)
                .toDouble();
            final fondo = (cuadreCompleto['fondoInicial'] ??
                    _cajaActual?.fondoInicial ??
                    0.0)
                .toDouble();
            _efectivoEsperado = ventasEfectivo + fondo;
            appLog('');
            appLog('✅ ═══════════════════════════════════════════════════');
            appLog('💰 EFECTIVO ESPERADO ESTABLECIDO:');
            appLog('   Ventas efectivo: $ventasEfectivo');
            appLog('   Fondo inicial: $fondo');
            appLog('   Total: $_efectivoEsperado');
            appLog('═══════════════════════════════════════════════════');
            appLog('');
          } else {
            appLog('');
            appLog('⚠️ ═══════════════════════════════════════════════════');
            appLog('❌ BACKEND NO ENVIÓ efectivoEsperado');
            appLog('   Usando valor por defecto: 0');
            appLog('═══════════════════════════════════════════════════');
            appLog('');
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
      if (!mounted) return;
      setState(() {
        // Capturar las ventas brutas y los gastos por separado
        _ventasEfectivo = (detallesVentas['ventasEfectivo'] ?? 0).toDouble();
        _totalGastos = (detallesVentas['totalGastos'] ?? 0).toDouble();
        _transferenciasEsperadas = (detallesVentas['ventasTransferencias'] ?? 0)
            .toDouble();
        _totalDomicilios = (detallesVentas['totalDomicilios'] ?? 0).toDouble();

        // ✅ USAR EL VALOR DEL BACKEND DIRECTAMENTE - SIN RECALCULAR NADA
        if (detallesVentas.containsKey('efectivoEsperadoPorVentas')) {
          _efectivoEsperado = (detallesVentas['efectivoEsperadoPorVentas'] ?? 0)
              .toDouble();
          appLog(
            '💰 Efectivo esperado del backend (fallback): $_efectivoEsperado',
          );
        }
      });
      _calcularDiferencia();

      // Intentar obtener datos más actualizados usando el endpoint de pedidos
      try {
        final ventasPorTipo = await _cuadreCajaService.getVentasPorTipoPago();

        if (!mounted) return;
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

          // ❌ NO RECALCULAR - Usar el valor del backend sin modificar
          appLog('🚫 NO se recalcula el efectivo esperado');
          // Log del cálculo para depuració
        });
        _calcularDiferencia();
      } catch (ventasError) {
        // Error en método de respaldo - manejar silenciosamente
          
      }
    } catch (e) {
      String mensajeAmigable = errorMessage(e);

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
        
        // ✅ SOLO actualizar si no tenemos valor aún
        // No sobrescribir el valor de cuadreCompleto
        if (_efectivoEsperado == 0 || _efectivoEsperado == 0.0) {
          _efectivoEsperado =
              resumenCompleto.movimientosEfectivo.efectivoEsperado;
          appLog('💰 Efectivo esperado del resumenCompleto: $_efectivoEsperado');
        } else {
          appLog(
            '✅ Manteniendo efectivo esperado de cuadreCompleto: $_efectivoEsperado',
          );
        }

        // Also sync the sales values between cuadreCompleto and resumenCompleto
        if (resumenCompleto.movimientosEfectivo.ventasEfectivo > 0 ||
            resumenCompleto.movimientosEfectivo.ventasTransferencia > 0) {
            
                          
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
    // ✅ USAR DIRECTAMENTE _efectivoEsperado (ya incluye fondo inicial del backend)
    setState(() {
      _diferencia = efectivoDeclarado - _efectivoEsperado;
    });
    appLog('💵 Cálculo de diferencia:');
    appLog('   Efectivo declarado: $efectivoDeclarado');
    appLog('   Efectivo esperado: $_efectivoEsperado');
    appLog('   Diferencia: $_diferencia');
  }

  // Mostrar diálogo para ingresar el efectivo declarado
  Future<double?> _mostrarDialogoEfectivoDeclarado() async {
    final efectivoController = TextEditingController();
    double? efectivoDeclarado;
    bool mostrarDescuadre = false;
    double descuadre = 0.0;

    return await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Text(
                '💵 Declarar Efectivo en Caja',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recordatorio de cuál caja se está cerrando — este
                    // diálogo es el último paso antes de confirmar el cierre.
                    if (_cajaActual != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              _cajaActual!.tipoCaja == 'ENVIOS'
                                  ? Icons.local_shipping
                                  : Icons.storefront,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Vas a cerrar: CAJA ${_cajaActual!.tipoCaja == 'ENVIOS' ? 'ENVÍOS' : 'LOCAL'}',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Información del efectivo esperado
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Efectivo esperado:',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            formatCurrency(_efectivoEsperado),
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Campo para ingresar el efectivo declarado
                    Text(
                      'Ingrese el efectivo real en caja:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: efectivoController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(
                          Icons.monetization_on,
                          color: Colors.green,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          efectivoDeclarado = double.tryParse(value);
                          if (efectivoDeclarado != null) {
                            descuadre = _efectivoEsperado - efectivoDeclarado!;
                            mostrarDescuadre =
                                descuadre.abs() > 0.01; // Tolerancia mínima
                          } else {
                            mostrarDescuadre = false;
                          }
                        });
                      },
                    ),

                    // Mostrar descuadre si existe
                    if (mostrarDescuadre) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: descuadre > 0
                              ? Colors.red.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: descuadre > 0
                                ? Colors.red.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  descuadre > 0
                                      ? Icons.warning_amber_rounded
                                      : Icons.info_outline,
                                  color: descuadre > 0
                                      ? Colors.red
                                      : Colors.orange,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '⚠️ Descuadre detectado',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  descuadre > 0 ? 'Falta:' : 'Sobra:',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                ),
                                Text(
                                  formatCurrency(descuadre.abs()),
                                  style: TextStyle(
                                    color: descuadre > 0
                                        ? Colors.red
                                        : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              descuadre > 0
                                  ? 'El efectivo en caja es menor al esperado'
                                  : 'El efectivo en caja es mayor al esperado',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                // Botón cancelar
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),

                // Botón reintentar (si hay descuadre)
                if (mostrarDescuadre)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        efectivoController.clear();
                        mostrarDescuadre = false;
                        efectivoDeclarado = null;
                      });
                    },
                    child: Text(
                      'Reintentar',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),

                // Botón confirmar
                ElevatedButton(
                  onPressed: efectivoDeclarado != null
                      ? () {
                          Navigator.of(context).pop(efectivoDeclarado);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mostrarDescuadre
                        ? Colors.orange
                        : Colors.green,
                  ),
                  child: Text(
                    mostrarDescuadre ? 'Cerrar con Descuadre' : 'Confirmar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cerrarCaja() async {
    if (_cajaActual == null) {
      _mostrarError('No hay caja abierta para cerrar');
      return;
    }

    // Solicitar el efectivo declarado
    final efectivoDeclarado = await _mostrarDialogoEfectivoDeclarado();
    
    // Si el usuario canceló, no continuar
    if (efectivoDeclarado == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final responsable = userProvider.userName ?? _cajaActual!.responsable;

      // Calcular el descuadre
      final descuadre = _efectivoEsperado - efectivoDeclarado;

      // Actualizar el cuadre con el efectivo declarado
      final cuadre = await _cuadreCajaService.updateCuadre(
        _cajaActual!.id!,
        responsable: responsable,
        efectivoDeclarado: efectivoDeclarado,
        observaciones:
            'Caja cerrada - ${_observacionesController.text}${descuadre.abs() > 0.01 ? ' - Descuadre: ${formatCurrency(descuadre.abs())} ${descuadre > 0 ? "(Falta)" : "(Sobra)"}' : ''}',
        cerrarCaja: true,
        estado: 'cerrada',
      );

      if (cuadre.id != null) {
        // Mostrar mensaje apropiado según si hay descuadre o no
        if (descuadre.abs() > 0.01) {
          _mostrarExito(
            'Caja cerrada con descuadre de ${formatCurrency(descuadre.abs())} ${descuadre > 0 ? "(Falta)" : "(Sobra)"}',
          );
        } else {
          _mostrarExito('Caja cerrada exitosamente - Sin descuadre');
        }

        // Descargar Excel de conciliación automáticamente y cargar resultado
        await _descargarExcelYMostrarConciliacion(cuadre.id!);

        // Volver a la pantalla anterior solo si no hay discrepancias o si el usuario ya vio el reporte
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Error al cerrar el cuadre');
      }
    } catch (e) {
      // Verificar si es el error específico de caja ya cerrada
      if (e.toString().contains('La caja ya está cerrada')) {
        // Actualizar el estado
        await _verificarEstadoCaja();
      }

      showErrorDialog(context, errorMessage(e));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ===== BACKUP / CONCILIACIÓN DE INVENTARIO =====

  /// Descarga automáticamente el Excel de conciliación y carga el resumen de discrepancias.
  /// Si el backend aún no tiene el backup listo, reintenta una vez tras 2 segundos.
  Future<void> _descargarExcelYMostrarConciliacion(String cajaId) async {
    // Pequeña espera para que el backend termine de guardar el backup
    await Future.delayed(const Duration(seconds: 2));

    // Descargar Excel en background
    _iniciarDescargaExcel(cajaId);

    // Cargar la conciliación para mostrar en pantalla
    try {
      final conciliacion = await _backupService.getConciliacion(cajaId);
      if (mounted) {
        setState(() => _conciliacionData = conciliacion);
        final discrepancias = _backupService.contarDiscrepancias(conciliacion);
        if (discrepancias > 0) {
          _mostrarDialogoDiscrepancias(discrepancias, conciliacion);
        }
      }
    } catch (e) {
      appLog('⚠️ No se pudo cargar la conciliación: $e');
    }
  }

  /// Dispara la descarga del Excel de conciliación sin bloquear la UI.
  void _iniciarDescargaExcel(String cajaId) async {
    if (_descargandoExcel) return;
    setState(() => _descargandoExcel = true);
    try {
      final bytes = await _backupService.descargarExcelConciliacion(cajaId);
      final now = DateTime.now();
      final nombre =
          'conciliacion_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.xlsx';
      FileDownloadHelper.downloadFile(
        bytes,
        filename: nombre,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📥 Excel de conciliación de inventario descargado'),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      appLog('⚠️ No se pudo descargar el Excel de conciliación: $e');
    } finally {
      if (mounted) setState(() => _descargandoExcel = false);
    }
  }

  /// Muestra un diálogo alertando que hay discrepancias en el inventario.
  void _mostrarDialogoDiscrepancias(
      int totalDiscrepancias, List<Map<String, dynamic>> conciliacion) {
    final faltantes = conciliacion.where((f) => f['estado'] == 'FALTANTE').toList();
    final sobrantes = conciliacion.where((f) => f['estado'] == 'SOBRANTE').toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Discrepancias en Inventario',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se encontraron $totalDiscrepancias producto(s) con diferencias entre el stock esperado y el real.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
              ),
              const SizedBox(height: 12),
              if (faltantes.isNotEmpty) ...[
                Text('Faltantes (${faltantes.length}):',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...faltantes.take(5).map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(f['nombre'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis)),
                          Text(
                            f['discrepancia'].toString(),
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    )),
                if (faltantes.length > 5)
                  Text('...y ${faltantes.length - 5} más',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
              if (sobrantes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Sobrantes (${sobrantes.length}):',
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...sobrantes.take(5).map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(f['nombre'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis)),
                          Text(
                            '+${f['discrepancia']}',
                            style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    )),
                if (sobrantes.length > 5)
                  Text('...y ${sobrantes.length - 5} más',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.teal.withOpacity(0.3))),
                child: const Row(
                  children: [
                    Icon(Icons.download_done, color: Colors.teal, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El Excel detallado ya está siendo descargado automáticamente.',
                        style: TextStyle(fontSize: 12, color: Colors.teal),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  // ===== FIN BACKUP / CONCILIACIÓN =====

  void _mostrarError(String mensaje) {
    showErrorDialog(context, mensaje);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Cerrar Caja',
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
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
                          SizedBox(height: 8),
                          // Siempre visible, sin importar si hay una sola caja
                          // abierta o dos: cuál se está cerrando (LOCAL/ENVIOS)
                          // no debe depender de que aparezca el selector.
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white70),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _cajaActual!.tipoCaja == 'ENVIOS'
                                      ? Icons.local_shipping
                                      : Icons.storefront,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  _cajaActual!.tipoCaja == 'ENVIOS' ? 'CAJA ENVÍOS' : 'CAJA LOCAL',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_cajaActual!.nombre.isNotEmpty && _cajaActual!.nombre != 'Caja Principal') ...[
                            SizedBox(height: 4),
                            Text(
                              _cajaActual!.nombre,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Selector de cuál caja ver/cerrar — solo cuando hay más de una abierta
                  if (_cajasAbiertas.length > 1) ...[
                    Row(
                      children: _cajasAbiertas.map((caja) {
                        final seleccionada = caja.id == _cajaActual?.id;
                        final esEnvios = caja.tipoCaja == 'ENVIOS';
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: caja == _cajasAbiertas.last ? 0 : 8,
                            ),
                            child: InkWell(
                              onTap: () => _seleccionarCaja(caja),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: seleccionada ? AppTheme.primaryGradient : null,
                                  color: seleccionada ? null : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  border: Border.all(
                                    color: seleccionada
                                        ? Colors.transparent
                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      esEnvios ? Icons.local_shipping : Icons.storefront,
                                      size: 18,
                                      color: seleccionada
                                          ? Colors.white
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      esEnvios ? 'Envíos' : 'Local',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: seleccionada ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 20),
                  ],

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
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
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
                        color: Theme.of(context).colorScheme.surface,
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
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          TextFormField(
                            controller: _observacionesController,
                            maxLines: 3,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Observaciones del cierre (opcional)',
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
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

                    // Indicador de descarga de Excel en progreso
                    if (_descargandoExcel) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.teal),
                            ),
                            SizedBox(width: 10),
                            Text('Generando Excel de conciliación...',
                                style: TextStyle(color: Colors.teal)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

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
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
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
                   // Can't modify the object directly, but we can update the display values
        _transferenciasEsperadas = transferenciaValue;
      }
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
            formatCurrencyRoundedTo1000(movimientos.fondoInicial),
          ),
          _buildInfoRow(
            'Ventas Efectivo:',
            formatCurrencyRoundedTo1000(
              _ventasEfectivo > 0
                  ? _ventasEfectivo
                  : movimientos.ventasEfectivo,
            ),
            valueColor: AppTheme.success,
          ),
          _buildInfoRow(
            'Ventas Transferencia:',
            formatCurrencyRoundedTo1000(
              _transferenciasEsperadas > 0
                  ? _transferenciasEsperadas
                  : movimientos.ventasTransferencia,
            ),
            valueColor: AppTheme.primary,
          ),
          _buildInfoRow(
            'Gastos Efectivo:',
            formatCurrencyRoundedTo1000(movimientos.gastosEfectivo),
            valueColor: AppTheme.error,
          ),
          _buildInfoRow(
            'Compras Efectivo:',
            formatCurrencyRoundedTo1000(movimientos.comprasEfectivo),
            valueColor: AppTheme.warning,
          ),
          Divider(color: Colors.grey.withOpacity(0.3), height: 20),
          _buildInfoRow(
            'Efectivo Esperado:',
            formatCurrencyRoundedTo1000(
              _efectivoEsperado > 0
                  ? _efectivoEsperado
                  : movimientos.efectivoEsperado,
            ),
            valueColor: Colors.amber,
          ),
          // Mostrar efectivo declarado si existe
          if (movimientos.efectivoDeclarado > 0) ...[
            _buildInfoRow(
              'Efectivo Declarado:',
              formatCurrency(movimientos.efectivoDeclarado),
              valueColor: Colors.blue,
            ),
          ],
          // Mostrar descuadre si existe
          if (movimientos.descuadre.abs() > 0.01) ...[
            Divider(color: Colors.grey.withOpacity(0.3), height: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: movimientos.descuadre > 0
                    ? Colors.red.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: movimientos.descuadre > 0
                      ? Colors.red.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        movimientos.descuadre > 0
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline,
                        color: movimientos.descuadre > 0
                            ? Colors.red
                            : Colors.orange,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Descuadre en Caja',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        movimientos.descuadre > 0 ? 'Faltante:' : 'Sobrante:',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        formatCurrency(movimientos.descuadre.abs()),
                        style: TextStyle(
                          color: movimientos.descuadre > 0
                              ? Colors.red
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
  }

  Widget _buildResumenGastosSection() {
    final gastos = _resumenCompletoData!.resumenGastos;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.onSurface,
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
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        Text(
                          'Forma: ${gasto.formaPago ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ],
                    ),
                    if (gasto.fecha != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Fecha: ${_formatearFecha(gasto.fecha!)}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
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
        color: Theme.of(context).colorScheme.surface,
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
            valueColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                color: Theme.of(context).colorScheme.onSurface,
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
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    Text(
                      'Medio: ${compra.medioPago}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    if (compra.observaciones.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        'Obs: ${compra.observaciones}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade300,
                        ),
                      ),
                    ],
                    if (compra.fecha != null) ...[
                      Text(
                        'Fecha: ${_formatearFecha(compra.fecha!)}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (compras.detallesComprasNoDesdeCaja.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              'Compras NO Pagadas desde Caja:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade300,
              ),
            ),
            SizedBox(height: 8),
            ...compras.detallesComprasNoDesdeCaja.map(
              (compra) => Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
                            color: Colors.blue.shade300,
                          ),
                        ),
                        Text(
                          formatCurrency(compra.total),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade300,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Proveedor: ${compra.proveedor}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    if (compra.observaciones.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${compra.observaciones}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade200,
                          ),
                        ),
                      ),
                    ],
                    if (compra.fecha != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Fecha: ${_formatearFecha(compra.fecha!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
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
        color: Theme.of(context).colorScheme.surface,
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
            formatCurrencyRoundedTo1000(ventas.totalVentas),
            valueColor: AppTheme.success,
          ),
          _buildInfoRow(
            'Promedio por Pedido:',
            ventas.totalPedidos > 0
                ? formatCurrencyRoundedTo1000(ventas.totalVentas / ventas.totalPedidos)
                : formatCurrencyRoundedTo1000(0),
            valueColor: Colors.amber,
          ),
          Divider(color: Colors.grey.withOpacity(0.3), height: 24),
          Text(
            'Ventas por Forma de Pago:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 8),
          // Mostrar TODOS los métodos de pago siempre (buscar en mayúscula y minúscula)
          _buildInfoRow(
            'Ventas Efectivo:',
            formatCurrencyRoundedTo1000((ventas.ventasPorFormaPago['Efectivo'] ?? ventas.ventasPorFormaPago['efectivo']) ?? 0),
            valueColor: AppTheme.success,
          ),
          _buildInfoRow(
            'Ventas Transferencia:',
            formatCurrencyRoundedTo1000((ventas.ventasPorFormaPago['Transferencia'] ?? ventas.ventasPorFormaPago['transferencia']) ?? 0),
            valueColor: AppTheme.primary,
          ),
          _buildInfoRow(
            'Ventas Tarjeta:',
            formatCurrencyRoundedTo1000((ventas.ventasPorFormaPago['Tarjeta'] ?? ventas.ventasPorFormaPago['tarjeta']) ?? 0),
            valueColor: AppTheme.warning,
          ),
          _buildInfoRow(
            'Ventas Sistecredito:',
            formatCurrencyRoundedTo1000((ventas.ventasPorFormaPago['Sistecredito'] ?? ventas.ventasPorFormaPago['sistecredito']) ?? 0),
            valueColor: Colors.purple,
          ),
          _buildInfoRow(
            'Ventas Datafono:',
            formatCurrencyRoundedTo1000((ventas.ventasPorFormaPago['Datafono'] ?? ventas.ventasPorFormaPago['datafono']) ?? 0),
            valueColor: Colors.teal,
          ),
          _buildInfoRow(
            'Ventas A Crédito:',
            formatCurrencyRoundedTo1000((ventas.ventasPorFormaPago['Crédito'] ?? ventas.ventasPorFormaPago['crédito']) ?? 0),
            valueColor: Colors.deepOrange,
          ),
          // Desglose visual adicional por plataforma específica (no cambia los
          // totales de arriba, son un subconjunto de Transferencia/Datafono/Efectivo).
          // Solo se muestran las plataformas que tuvieron movimiento este cuadre.
          if ((ventas.ventasPorDetallePago['nequi'] ?? 0) > 0)
            _buildInfoRow(
              '   ↳ Nequi:',
              formatCurrencyRoundedTo1000(ventas.ventasPorDetallePago['nequi'] ?? 0),
              valueColor: AppTheme.primary,
            ),
          if ((ventas.ventasPorDetallePago['daviplata'] ?? 0) > 0)
            _buildInfoRow(
              '   ↳ DaviPlata:',
              formatCurrencyRoundedTo1000(ventas.ventasPorDetallePago['daviplata'] ?? 0),
              valueColor: AppTheme.primary,
            ),
          if ((ventas.ventasPorDetallePago['bancolombia'] ?? 0) > 0)
            _buildInfoRow(
              '   ↳ Bancolombia:',
              formatCurrencyRoundedTo1000(ventas.ventasPorDetallePago['bancolombia'] ?? 0),
              valueColor: AppTheme.primary,
            ),
          if ((ventas.ventasPorDetallePago['bold'] ?? 0) > 0)
            _buildInfoRow(
              '   ↳ Bold:',
              formatCurrencyRoundedTo1000(ventas.ventasPorDetallePago['bold'] ?? 0),
              valueColor: Colors.teal,
            ),
          if ((ventas.ventasPorDetallePago['addi'] ?? 0) > 0)
            _buildInfoRow(
              '   ↳ Addi:',
              formatCurrencyRoundedTo1000(ventas.ventasPorDetallePago['addi'] ?? 0),
              valueColor: AppTheme.success,
            ),
          if ((ventas.ventasPorDetallePago['credilondon'] ?? 0) > 0)
            _buildInfoRow(
              '   ↳ Credilondon:',
              formatCurrencyRoundedTo1000(ventas.ventasPorDetallePago['credilondon'] ?? 0),
              valueColor: AppTheme.success,
            ),

          // Display Ingresos Caja
          Divider(color: Colors.grey.withOpacity(0.3), height: 24),
          Text(
            'Ingresos Adicionales:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 8),
          _buildInfoRow(
            'Ingresos Efectivo:',
            formatCurrencyRoundedTo1000(
              _resumenCompletoData?.movimientosEfectivo.ingresosEfectivo ?? 0,
            ),
            valueColor: Colors.amber,
          ),
          _buildInfoRow(
            'Total Ingresos Caja:',
            formatCurrencyRoundedTo1000(
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 8),
          // Mostrar TODAS las cantidades por método de pago siempre (buscar en mayúscula y minúscula)
          _buildInfoRow(
            'Pedidos en Efectivo:',
            ((ventas.cantidadPorFormaPago['Efectivo'] ?? ventas.cantidadPorFormaPago['efectivo']) ?? 0).toString(),
            valueColor: AppTheme.success,
          ),
          _buildInfoRow(
            'Pedidos por Transferencia:',
            ((ventas.cantidadPorFormaPago['Transferencia'] ?? ventas.cantidadPorFormaPago['transferencia']) ?? 0).toString(),
            valueColor: AppTheme.primary,
          ),
          _buildInfoRow(
            'Pedidos con Tarjeta:',
            ((ventas.cantidadPorFormaPago['Tarjeta'] ?? ventas.cantidadPorFormaPago['tarjeta']) ?? 0).toString(),
            valueColor: AppTheme.warning,
          ),
          _buildInfoRow(
            'Pedidos Sistecredito:',
            ((ventas.cantidadPorFormaPago['Sistecredito'] ?? ventas.cantidadPorFormaPago['sistecredito']) ?? 0).toString(),
            valueColor: Colors.purple,
          ),
          _buildInfoRow(
            'Pedidos Datafono:',
            ((ventas.cantidadPorFormaPago['Datafono'] ?? ventas.cantidadPorFormaPago['datafono']) ?? 0).toString(),
            valueColor: Colors.teal,
          ),
          _buildInfoRow(
            'Pedidos A Crédito:',
            ((ventas.cantidadPorFormaPago['Crédito'] ?? ventas.cantidadPorFormaPago['crédito']) ?? 0).toString(),
            valueColor: Colors.deepOrange,
          ),

          // Add a summary of today's sales instead of individual orders
          SizedBox(height: 16),
          Text(
            'Resumen General',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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

}
