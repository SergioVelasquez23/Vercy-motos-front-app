import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../services/cuadre_caja_service.dart';
// import '../services/pedido_service.dart';
import '../utils/format_utils.dart';

class CerrarCajaScreen extends StatefulWidget {
  const CerrarCajaScreen({super.key});

  @override
  _CerrarCajaScreenState createState() => _CerrarCajaScreenState();
}

class _CerrarCajaScreenState extends State<CerrarCajaScreen> {
  // Método para verificar el estado de la caja (restaurado)
  Future<void> _verificarEstadoCaja() async {
    setState(() => _isLoading = true);
    try {
      final caja = await _cuadreCajaService.getCajaActiva();
      setState(() {
        _cajaActual = caja;
        _hayCajaAbierta = caja != null;
      });
    } catch (e) {
      print('Error verificando estado de caja: $e');
      _mostrarError('Error verificando estado de caja: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

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
  double _ventasEfectivo = 0.0; // Este es el monto bruto de ventas en efectivo
  double _transferenciasEsperadas = 0.0;
  double _totalGastos = 0.0;
  double _totalDomicilios = 0.0;
  double _diferencia = 0.0;

  // Contadores para resumen del cuadre actual
  int _totalPedidos = 0;
  int _totalProductos = 0;
  double _valorTotalVentas = 0.0;
  Future<void> _cargarEfectivoEsperado() async {
    // Eliminado: toda la lógica de efectivoEsperado
    // Si necesitas mostrar algún cálculo, usa los campos válidos del modelo
  }

  void _calcularDiferencia() {
    final efectivoDeclarado =
        double.tryParse(_efectivoDeclaradoController.text) ?? 0;
    // La diferencia debe ser contra el total esperado
    // En caja debe haber: fondo inicial + (ventas efectivo + domicilios - gastos)
    // Nota: El backend podría no estar contabilizando domicilios en efectivoEsperado
    // así que los agregamos explícitamente
    final totalEsperado = (_cajaActual?.efectivoInicial ?? 0);
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
                    'Fondo inicial: \${(_cajaActual?.efectivoInicial ?? 0).toStringAsFixed(0)}',
                    style: TextStyle(color: textLight),
                  ),
                  Text(
                    'Monto inicial: ${formatCurrency(_cajaActual?.efectivoInicial ?? 0)}',
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
                  // Mostrar siempre el campo de gastos, aunque sea 0
                  Text(
                    'Total gastos: \$${_totalGastos.toStringAsFixed(0)}',
                    style: TextStyle(color: Colors.red[300]),
                  ),
                  Divider(color: Colors.grey.withOpacity(0.3)),
                  Text(
                    'Cálculo: ${(_cajaActual?.efectivoInicial ?? 0).toStringAsFixed(0)} + ${_ventasEfectivo.toStringAsFixed(0)} - ${_totalGastos.toStringAsFixed(0)}',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Total esperado en caja: \${(_cajaActual?.efectivoInicial ?? 0).toStringAsFixed(0)}',
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
  void initState() {
    super.initState();
    _verificarEstadoCaja();
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
                    // Información de la caja (solo campos del cuadre completo, sin gastosPorTipo ni detalleVentas)
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
                              'Resumen de Caja',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildInfoRow(
                              'Fecha cierre',
                              _cajaActual!.fechaCierre?.toString() ?? '',
                            ),
                            _buildInfoRow(
                              'Fecha inicio',
                              _cajaActual!.fechaInicio?.toString() ?? '',
                            ),
                            _buildInfoRow(
                              'Fecha fin',
                              _cajaActual!.fechaFin?.toString() ?? '',
                            ),
                            _buildInfoRow(
                              'Responsable',
                              _cajaActual!.responsable,
                            ),
                            _buildInfoRow(
                              'Efectivo inicial',
                              formatCurrency(_cajaActual!.efectivoInicial),
                            ),
                            _buildInfoRow(
                              'Transferencias iniciales',
                              formatCurrency(
                                _cajaActual!.transferenciasIniciales,
                              ),
                            ),
                            _buildInfoRow(
                              'Total inicial',
                              formatCurrency(_cajaActual!.totalInicial),
                            ),
                            _buildInfoRow(
                              'Ventas efectivo',
                              formatCurrency(_cajaActual!.ventasEfectivo),
                            ),
                            _buildInfoRow(
                              'Ventas transferencias',
                              formatCurrency(_cajaActual!.ventasTransferencias),
                            ),
                            _buildInfoRow(
                              'Ventas tarjetas',
                              formatCurrency(_cajaActual!.ventasTarjetas),
                            ),
                            _buildInfoRow(
                              'Total ventas',
                              formatCurrency(_cajaActual!.totalVentas),
                            ),
                            _buildInfoRow(
                              'Total propinas',
                              formatCurrency(_cajaActual!.totalPropinas),
                            ),
                            _buildInfoRow(
                              'Total gastos',
                              formatCurrency(_cajaActual!.totalGastos),
                            ),
                            _buildInfoRow(
                              'Debo tener',
                              formatCurrency(_cajaActual!.deboTener),
                            ),
                            _buildInfoRow(
                              'Cantidad facturas',
                              _cajaActual!.cantidadFacturas.toString(),
                            ),
                            _buildInfoRow(
                              'Cantidad pedidos',
                              _cajaActual!.cantidadPedidos.toString(),
                            ),
                            _buildInfoRow(
                              'Observaciones',
                              _cajaActual!.observaciones ?? '',
                            ),
                            _buildInfoRow('Estado', _cajaActual!.estado),
                          ],
                        ),
                      ),
                    ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label + ': ', style: TextStyle(color: textLight)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? textDark,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.left,
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
    return Container(
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
    );
  }
}
