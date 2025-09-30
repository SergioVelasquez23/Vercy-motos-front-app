import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

// Providers
import '../providers/user_provider.dart';

// Models
import '../models/cuadre_caja.dart';
import '../models/gasto.dart';
import '../models/resumen_cierre.dart';
import '../models/inventario.dart';
import '../models/movimiento_inventario.dart';

// Services
import '../services/cuadre_caja_service.dart';
import '../services/gasto_service.dart';
import '../services/resumen_cierre_service.dart';
import '../services/inventario_service.dart';
import '../services/impresion_service.dart';
import '../services/pdf_service_web.dart'
    if (dart.library.io) '../services/pdf_service_stub.dart';

// Screens
import 'ingresos_caja_screen.dart';
import 'gastos_screen.dart';
import 'tipos_gasto_screen.dart';
import 'movimientos_cuadre_screen.dart';
import 'contador_efectivo_screen.dart';

// Utils & Theme
import '../utils/format_utils.dart';
import '../theme/app_theme.dart';

class CuadreCajaScreen extends StatefulWidget {
  const CuadreCajaScreen({super.key});

  @override
  _CuadreCajaScreenState createState() => _CuadreCajaScreenState();
}

class _CuadreCajaScreenState extends State<CuadreCajaScreen>
    with SingleTickerProviderStateMixin {
  // Getters para compatibilidad temporal con AppTheme
  Color get primary => AppTheme.primary;
  Color get bgDark => AppTheme.backgroundDark;
  Color get cardBg => AppTheme.cardBg;
  Color get textDark => AppTheme.textDark;
  Color get textLight => AppTheme.textLight;
  Color get accentOrange => AppTheme.accent;

  // Services
  final GastoService _gastoService = GastoService();
  final ResumenCierreService _resumenCierreService = ResumenCierreService();
  final InventarioService _inventarioService = InventarioService();
  final ImpresionService _impresionService = ImpresionService();

  // Controllers para los filtros de búsqueda
  final TextEditingController _desdeController = TextEditingController();
  final TextEditingController _hastaController = TextEditingController();
  final TextEditingController _idMaquinaController = TextEditingController();

  // Controllers para el formulario de apertura/cierre
  final TextEditingController _montoAperturaController =
      TextEditingController();
  final TextEditingController _montoEfectivoController =
      TextEditingController();
  final TextEditingController _montoTransferenciasController =
      TextEditingController();
  final TextEditingController _notasController = TextEditingController();

  // Variables para el estado
  double _totalIngresos = 0;
  bool _showCashRegisterForm = false;
  bool _cerrarCajaSwitch = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Datos reales del backend
  List<CuadreCaja> _cuadresCaja = [];
  List<String> _usuariosDisponibles = [];
  CuadreCaja? _cuadreActual;

  // Services
  final CuadreCajaService _cuadreCajaService = CuadreCajaService();
  final String baseUrl = 'https://sopa-y-carbon.onrender.com';

  // Filtros
  String? _selectedCaja;
  String? _selectedResponsable;
  String? _selectedEstado;
  String? _selectedCajero;

  @override
  void initState() {
    super.initState();
    _loadCuadresCaja();
    _loadUsuariosDisponibles();
  }

  @override
  void dispose() {
    _desdeController.dispose();
    _hastaController.dispose();
    _idMaquinaController.dispose();
    _montoAperturaController.dispose();
    _montoEfectivoController.dispose();
    _montoTransferenciasController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTableHeader(String text) {
    return Container(
      padding: EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Container(
      padding: EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInfoCardFallback(List<List<String>> items) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item[0], style: TextStyle(color: textLight, fontSize: 14)),
                Text(
                  item[1],
                  style: TextStyle(
                    color: textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<Map<String, dynamic>?> _generarComprobanteDiario(
    CuadreCaja cuadre,
  ) async {
    try {
      final fechaCuadre = cuadre.fechaCierre ?? DateTime.now();
      final fechaInicio = DateTime(
        fechaCuadre.year,
        fechaCuadre.month,
        fechaCuadre.day,
      );
      final fechaFin = fechaInicio.add(const Duration(days: 1));
      final gastos = await _gastoService.getGastosByDateRange(
        fechaInicio,
        fechaFin,
      );

      final totalGastos = gastos.fold<double>(
        0,
        (sum, gasto) => sum + gasto.monto,
      );

      final resumen = {
        'tipo': 'comprobante_diario',
        'titulo': 'COMPROBANTE DIARIO',
        'nombreRestaurante': 'SOPA Y CARBÓN',
        'fecha': DateFormat('dd/MM/yyyy').format(fechaCuadre),
        'hora': DateFormat('HH:mm').format(fechaCuadre),
        'cuadre': {
          'id': cuadre.id,
          'fechaApertura': cuadre.fechaApertura != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(cuadre.fechaApertura!)
              : 'N/A',
          'fechaCierre': cuadre.fechaCierre != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(cuadre.fechaCierre!)
              : 'N/A',
          'responsable': cuadre.responsable ?? 'Sin especificar',
          'fondoInicial': cuadre.fondoInicial ?? 0.0,
          'efectivoEsperado': cuadre.efectivoEsperado ?? 0.0,
          'efectivoContado': cuadre.efectivoDeclarado,
          'diferencia': cuadre.diferencia,
        },
        'gastos': {
          'items': gastos
              .map(
                (gasto) => {
                  'descripcion': gasto.concepto,
                  'monto': gasto.monto,
                  'fecha': DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(gasto.fechaGasto),
                },
              )
              .toList(),
          'total': totalGastos,
        },
        'totales': {
          'fondoInicial': cuadre.fondoInicial ?? 0.0,
          'efectivoEsperado': cuadre.efectivoEsperado ?? 0.0,
          'efectivoContado': cuadre.efectivoDeclarado,
          'totalGastos': totalGastos,
          'diferencia': cuadre.diferencia,
        },
      };

      return resumen;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _generarReporteInventario() async {
    try {
      final inventario = await _inventarioService.getInventario();

      if (inventario.isEmpty) {
        return null;
      }

      final productosBajoStock = inventario
          .where((item) => item.stockActual <= item.stockMinimo)
          .toList();
      final productosAgotados = inventario
          .where((item) => item.stockActual <= 0)
          .toList();

      double valorTotal = 0.0;
      for (var item in inventario) {
        valorTotal += (item.stockActual * item.precioCompra);
      }

      final resumen = {
        'tipo': 'reporte_inventario',
        'titulo': 'REPORTE DE INVENTARIO',
        'nombreRestaurante': 'SOPA Y CARBÓN',
        'fecha': DateFormat('dd/MM/yyyy').format(DateTime.now()),
        'hora': DateFormat('HH:mm').format(DateTime.now()),
        'inventario': {
          'totalProductos': inventario.length,
          'valorTotal': valorTotal,
          'productosBajoStock': productosBajoStock.length,
          'productosAgotados': productosAgotados.length,
        },
        'productos': inventario
            .map(
              (item) => {
                'nombre': item.nombre,
                'cantidad': item.stockActual,
                'unidadMedida': item.unidad,
                'precioCompra': item.precioCompra,
                'valorTotal': item.stockActual * item.precioCompra,
                'stockMinimo': item.stockMinimo,
                'estado': item.stockActual <= 0
                    ? 'AGOTADO'
                    : item.stockActual <= item.stockMinimo
                    ? 'BAJO STOCK'
                    : 'OK',
              },
            )
            .toList(),
        'alertas': {
          'productosBajoStock': productosBajoStock
              .map(
                (item) => {
                  'nombre': item.nombre,
                  'cantidadActual': item.stockActual,
                  'stockMinimo': item.stockMinimo,
                },
              )
              .toList(),
          'productosAgotados': productosAgotados
              .map((item) => {'nombre': item.nombre})
              .toList(),
        },
      };

      return resumen;
    } catch (e) {
      return null;
    }
  }

  void _mostrarOpcionesImpresion(Map<String, dynamic> resumen, String titulo) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(titulo, style: TextStyle(color: Colors.white)),
        content: Text(
          'Selecciona una opción para el reporte generado:',
          style: TextStyle(color: textLight),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.print, color: primary),
                title: Text('Ver Reporte', style: TextStyle(color: textLight)),
                subtitle: Text(
                  'Ver contenido del reporte',
                  style: TextStyle(color: textLight.withOpacity(0.7)),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _mostrarContenidoReporte(resumen, titulo);
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: primary),
                title: Text('Compartir', style: TextStyle(color: textLight)),
                subtitle: Text(
                  'Compartir como texto',
                  style: TextStyle(color: textLight.withOpacity(0.7)),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _mostrarError('Función de compartir no implementada aún');
                },
              ),
            ],
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar', style: TextStyle(color: primary)),
          ),
        ],
      ),
    );
  }

  void _mostrarContenidoReporte(Map<String, dynamic> resumen, String titulo) {
    final textoReporte = _generarTextoReporte(resumen);

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(
          'Contenido del Reporte',
          style: TextStyle(color: textLight),
        ),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              textoReporte,
              style: TextStyle(
                color: textLight,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar', style: TextStyle(color: primary)),
          ),
        ],
      ),
    );
  }

  String _generarTextoReporte(Map<String, dynamic> resumen) {
    final buffer = StringBuffer();

    buffer.writeln('========================================');
    buffer.writeln('${resumen['titulo']}');
    buffer.writeln('${resumen['nombreRestaurante']}');
    buffer.writeln('Fecha: ${resumen['fecha']} - Hora: ${resumen['hora']}');
    buffer.writeln('========================================');
    buffer.writeln();

    if (resumen['tipo'] == 'comprobante_diario') {
      final cuadre = resumen['cuadre'];
      buffer.writeln('INFORMACIÓN DEL CUADRE:');
      buffer.writeln('ID: ${cuadre['id']}');
      buffer.writeln('Responsable: ${cuadre['responsable']}');
      buffer.writeln('Apertura: ${cuadre['fechaApertura']}');
      buffer.writeln('Cierre: ${cuadre['fechaCierre']}');
      buffer.writeln();
      buffer.writeln('RESUMEN FINANCIERO:');
      buffer.writeln('Fondo Inicial: \$${cuadre['fondoInicial']}');
      buffer.writeln('Efectivo Esperado: \$${cuadre['efectivoEsperado']}');
      buffer.writeln('Efectivo Contado: \$${cuadre['efectivoContado']}');
      buffer.writeln('Diferencia: \$${cuadre['diferencia']}');
      buffer.writeln();

      final gastos = resumen['gastos'];
      if (gastos['items'].isNotEmpty) {
        buffer.writeln('GASTOS DEL DÍA:');
        for (var gasto in gastos['items']) {
          buffer.writeln(
            '- ${gasto['descripcion']}: \$${gasto['monto']} (${gasto['fecha']})',
          );
        }
        buffer.writeln('Total Gastos: \$${gastos['total']}');
      }
    } else if (resumen['tipo'] == 'reporte_inventario') {
      final inventario = resumen['inventario'];
      buffer.writeln('RESUMEN DEL INVENTARIO:');
      buffer.writeln('Total Productos: ${inventario['totalProductos']}');
      buffer.writeln(
        'Valor Total: \$${inventario['valorTotal'].toStringAsFixed(2)}',
      );
      buffer.writeln(
        'Productos Bajo Stock: ${inventario['productosBajoStock']}',
      );
      buffer.writeln('Productos Agotados: ${inventario['productosAgotados']}');
      buffer.writeln();

      buffer.writeln('DETALLE DE PRODUCTOS:');
      for (var producto in resumen['productos']) {
        buffer.writeln(
          '${producto['nombre']}: ${producto['cantidad']} ${producto['unidadMedida']} - ${producto['estado']}',
        );
      }
    }

    buffer.writeln();
    buffer.writeln('========================================');

    return buffer.toString();
  }

  Future<void> _loadCuadresCaja() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Usar el nuevo servicio en lugar de llamadas HTTP directas
      final cuadres = await _cuadreCajaService.getAllCuadres();

      // Ordenar cuadres por fecha descendente (más recientes primero)
      cuadres.sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));

      setState(() {
        _cuadresCaja = cuadres;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar cuadres: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsuariosDisponibles() async {
    try {
      // Usar el endpoint que existe según la configuración
      final response = await http.get(
        Uri.parse('$baseUrl/api/users'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Parsear JSON de forma más segura
        Map<String, dynamic> responseData;
        try {
          responseData = json.decode(response.body);
        } catch (jsonError) {
          // Si no se puede parsear el JSON, usar lista predefinida
          _setDefaultUsuarios();
          return;
        }

        // Manejar diferentes tipos de respuesta success de forma más robusta
        bool isSuccess = false;
        try {
          if (responseData.containsKey('success') &&
              responseData['success'] != null) {
            final successValue = responseData['success'];
            if (successValue is bool) {
              isSuccess = successValue;
            } else if (successValue is String) {
              isSuccess = successValue.toString().toLowerCase() == 'true';
            } else if (successValue is int) {
              isSuccess = successValue == 1;
            } else {
              // Si es cualquier otro tipo, asumir éxito si hay datos
              isSuccess =
                  responseData.containsKey('data') &&
                  responseData['data'] != null;
            }
          } else {
            // Si no hay campo success, verificar si hay datos
            isSuccess =
                responseData.containsKey('data') &&
                responseData['data'] != null;
          }
        } catch (successParseError) {
          // Si hay error al parsear success, verificar si hay datos válidos
          isSuccess =
              responseData.containsKey('data') && responseData['data'] != null;
        }

        if (isSuccess || responseData['data'] != null) {
          try {
            final userData =
                responseData['data'] ?? responseData['users'] ?? [];
            if (userData is List && userData.isNotEmpty) {
              setState(() {
                _usuariosDisponibles = List<String>.from(
                  userData
                      .map(
                        (user) =>
                            user['nombre'] ??
                            user['name'] ??
                            user['email'] ??
                            'Usuario',
                      )
                      .where((name) => name.isNotEmpty),
                );
              });
              // Si la lista está vacía después del filtrado, usar predefinida
              if (_usuariosDisponibles.isEmpty) {
                _setDefaultUsuarios();
              }
            } else {
              _setDefaultUsuarios();
            }
          } catch (userParseError) {
            _setDefaultUsuarios();
          }
        } else {
          _setDefaultUsuarios();
        }
      } else if (response.statusCode == 404) {
        // Si el endpoint no existe, usar lista predefinida basada en roles comunes
        _setDefaultUsuarios();
      } else {
        // Otros códigos de estado
        _setDefaultUsuarios();
      }
    } catch (e) {
      // Fallback a lista predefinida para cualquier error de red o parsing
      _setDefaultUsuarios();
    }
  }

  void _setDefaultUsuarios() {
    setState(() {
      _usuariosDisponibles = [
        'Administrador',
        'Cajero Principal',
        'Cajero Secundario',
        'Supervisor',
        'Gerente',
        'Mesero 1',
        'Mesero 2',
      ];
    });
  }

  Future<Map<String, String>> _getHeaders() async {
    return {
      'Content-Type': 'application/json',
      // TODO: Agregar token de autenticación si es necesario
      // 'Authorization': 'Bearer $token',
    };
  }

  void _actualizarTotales() {
    double efectivo = double.tryParse(_montoEfectivoController.text) ?? 0;
    double transferencias =
        double.tryParse(_montoTransferenciasController.text) ?? 0;

    setState(() {
      _totalIngresos = efectivo + transferencias;
    });
  }

  Future<void> _buscarCuadres() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Por ahora obtenemos todos los cuadres
      // TODO: Mejorar el servicio para aceptar filtros
      final cuadres = await _cuadreCajaService.getAllCuadres();

      // Ordenar cuadres por fecha descendente (más recientes primero)
      cuadres.sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));

      setState(() {
        _cuadresCaja = cuadres;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error en búsqueda: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _actualizarCuadre() async {
    if (_cuadreActual == null) return;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final responsable = userProvider.userName ?? _cuadreActual!.responsable;
      final montoEfectivo = double.tryParse(_montoEfectivoController.text) ?? 0;
      final observaciones =
          '${_notasController.text}. Identificación máquina: ${_idMaquinaController.text}';

      final cuadre = await _cuadreCajaService.updateCuadre(
        _cuadreActual!.id!,
        responsable: responsable,
        efectivoDeclarado: montoEfectivo,
        observaciones: observaciones,
        cerrarCaja: _cerrarCajaSwitch, // Cambio de cerrada a cerrarCaja
        estado: _cerrarCajaSwitch ? 'cerrada' : 'pendiente',
      );

      if (cuadre.id != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cuadre actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCuadresCaja();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar cuadre: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarMovimientosCuadre(CuadreCaja cuadre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovimientosCuadreScreen(cuadre: cuadre),
      ),
    );
  }

  void _abrirContadorEfectivo({bool paraEfectivo = true}) async {
    final resultado = await Navigator.push<double>(
      context,
      MaterialPageRoute(
        builder: (context) => ContadorEfectivoScreen(
          onTotalCalculado: (total) {
            // Callback que se ejecuta cuando se usa el total
            if (paraEfectivo) {
              setState(() {
                _montoEfectivoController.text = total.toStringAsFixed(0);
              });
            } else {
              setState(() {
                _montoTransferenciasController.text = total.toStringAsFixed(0);
              });
            }
            _actualizarTotales();
          },
        ),
      ),
    );

    if (resultado != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Total de ${formatCurrency(resultado)} ${paraEfectivo ? 'agregado al efectivo' : 'agregado a transferencias'}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user has admin permissions
    final userProvider = Provider.of<UserProvider>(context);
    if (!userProvider.isAdmin) {
      // If user is not admin, redirect to dashboard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Acceso restringido. Necesitas permisos de administrador.',
            ),
          ),
        );
      });
      return Container(); // Return empty container while redirecting
    }

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          'Cuadres de Caja',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primary,
        elevation: 0,
        actions: [
          // Botón para abrir caja
          if (!_showCashRegisterForm)
            TextButton.icon(
              icon: Icon(Icons.lock_open, color: Colors.white),
              label: Text('Abrir Caja', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/abrir_caja',
                );
                if (result == true) {
                  // Si se abrió exitosamente, recargar la lista
                  _loadCuadresCaja();
                }
              },
            ),
          SizedBox(width: 8),

          // Botón para cerrar caja
          if (!_showCashRegisterForm)
            TextButton.icon(
              icon: Icon(Icons.lock, color: Colors.white),
              label: Text('Cerrar Caja', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/cerrar_caja',
                );
                if (result == true) {
                  // Si se cerró exitosamente, recargar la lista
                  _loadCuadresCaja();
                }
              },
            ),
          SizedBox(width: 8),

          // Menú de opciones de gestión
          if (!_showCashRegisterForm)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white),
              color: cardBg,
              onSelected: (value) {
                if (value == 'gastos') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => GastosScreen()),
                  );
                } else if (value == 'ingresos_caja') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IngresosCajaScreen(),
                    ),
                  );
                } else if (value == 'tipos_gasto') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TiposGastoScreen()),
                  );
                } else if (value == 'contador_efectivo') {
                  _abrirContadorEfectivo();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'gastos',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, color: primary),
                      SizedBox(width: 8),
                      Text(
                        'Gestión de Gastos',
                        style: TextStyle(color: textDark),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'ingresos_caja',
                  child: Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Ingresos de Caja',
                        style: TextStyle(color: textDark),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'tipos_gasto',
                  child: Row(
                    children: [
                      Icon(Icons.category, color: primary),
                      SizedBox(width: 8),
                      Text(
                        'Tipos de Gastos',
                        style: TextStyle(color: textDark),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'contador_efectivo',
                  child: Row(
                    children: [
                      Icon(Icons.calculate, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Contador de Efectivo',
                        style: TextStyle(color: textDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          // Botón para guardar cuando estamos en modo formulario
          if (_showCashRegisterForm)
            TextButton.icon(
              icon: Icon(Icons.save, color: Colors.white),
              label: Text('Guardar', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                // Solo actualizar cuadre existente
                if (_cuadreActual != null) {
                  await _actualizarCuadre();
                  setState(() {
                    _showCashRegisterForm = false;
                  });
                }
              },
            ),
          SizedBox(width: 16),
        ],
      ),
      body: _showCashRegisterForm
          ? _buildCashRegisterForm()
          : _buildSearchAndResults(),
    );
  }

  Widget _buildSearchAndResults() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Center(
            child: Text(
              'CUADRES DE CAJA',
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
          SizedBox(height: 20), // Filtros de búsqueda
          Card(
            color: cardBg,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filtros de fechas
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _desdeController,
                          decoration: InputDecoration(
                            labelText: 'Desde',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(
                              Icons.calendar_today,
                              color: primary,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                          onTap: () async {
                            // Aquí se podría mostrar un DatePicker
                          },
                          readOnly: true,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _hastaController,
                          decoration: InputDecoration(
                            labelText: 'Hasta',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(
                              Icons.calendar_today,
                              color: primary,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                          onTap: () async {
                            // Aquí se podría mostrar un DatePicker
                          },
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Filtros de dropdown
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Caja',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                          style: TextStyle(color: textDark),
                          initialValue: _selectedCaja,
                          hint: Text(
                            '-- Caja --',
                            style: TextStyle(color: textLight),
                          ),
                          items: <String>['Caja Principal', 'Caja Secundaria']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCaja = newValue;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Responsable',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                          style: TextStyle(color: textDark),
                          initialValue: _selectedResponsable,
                          hint: Text(
                            '-- Responsable --',
                            style: TextStyle(color: textLight),
                          ),
                          items: <String>['Sopa y Carbon', 'Sergio Pérez']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedResponsable = newValue;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Estado',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                          style: TextStyle(color: textDark),
                          initialValue: _selectedEstado,
                          hint: Text(
                            '-- Estado --',
                            style: TextStyle(color: textLight),
                          ),
                          items: <String>['Abierta', 'Cerrada']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedEstado = newValue;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16), // Botón de búsqueda
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        _buscarCuadres();
                      },
                      child: Text('Buscar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Tabla de resultados
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primary))
              : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Colors.black.withOpacity(0.3),
                      ),
                      dataRowColor: WidgetStateProperty.all(
                        cardBg.withOpacity(0.7),
                      ),
                      columns: [
                        DataColumn(
                          label: Text(
                            'Fecha Inicio',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Fecha Fin',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Nombre de Caja',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Responsable',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Total Inicial',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Cerrada',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Comprobante diario',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Inventario',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Movimientos',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      rows: _cuadresCaja.map((cuadre) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                cuadre.fechaApertura.toString().split(' ')[0],
                                style: TextStyle(color: textDark),
                              ),
                            ),
                            DataCell(
                              Text(
                                cuadre.fechaCierre?.toString().split(' ')[0] ??
                                    'Abierta',
                                style: TextStyle(color: textDark),
                              ),
                            ),
                            DataCell(
                              Text(
                                cuadre.nombre,
                                style: TextStyle(color: textDark),
                              ),
                            ),
                            DataCell(
                              Text(
                                cuadre.responsable,
                                style: TextStyle(color: textDark),
                              ),
                            ),
                            DataCell(
                              Text(
                                formatCurrency(cuadre.fondoInicial),
                                style: TextStyle(color: textDark),
                              ),
                            ),
                            DataCell(
                              Text(
                                cuadre.cerrada ? 'Sí' : 'No',
                                style: TextStyle(
                                  color: cuadre.cerrada
                                      ? Colors.green
                                      : primary,
                                ),
                              ),
                            ),
                            DataCell(
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 3,
                                ),
                                onPressed: () async {
                                  // Mostrar resumen detallado usando el nuevo endpoint
                                  _mostrarResumenDetallado(cuadre);
                                },
                                child: Text('Ver'),
                              ),
                            ),
                            DataCell(
                              Container(),
                            ), // Celda vacía donde estaba Comprobante diario
                            DataCell(
                              Container(),
                            ), // Celda vacía donde estaba Inventario
                            DataCell(
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 3,
                                ),
                                onPressed: () {
                                  _mostrarMovimientosCuadre(cuadre);
                                },
                                icon: Icon(
                                  Icons.account_balance_wallet,
                                  size: 16,
                                ),
                                label: Text(
                                  'Ver',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCashRegisterForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Cuadre de caja",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          SizedBox(height: 20), // Información del responsable y caja
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
                    "Responsable",
                    style: TextStyle(fontSize: 16, color: textLight),
                  ),
                  Text(
                    "Sopa y Carbon Vargas Rendón",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Caja",
                    style: TextStyle(fontSize: 16, color: textLight),
                  ),
                  Text(
                    "Caja Principal",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20), // Selección de cajeros
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Cajeros",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                      Text("*", style: TextStyle(color: primary, fontSize: 20)),
                    ],
                  ),
                  SizedBox(height: 10),

                  // Dropdown para seleccionar cajero
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 15,
                            ),
                          ),
                          initialValue: _selectedCajero,
                          hint: Text("-- Seleccione --"),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCajero = newValue;
                            });
                          },
                          items: _usuariosDisponibles
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                        ),
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: primary,
                          size: 30,
                        ),
                        onPressed: () {
                          // Agregar nuevo cajero
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 10), // Lista de cajeros seleccionados
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        // Encabezado de la tabla
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          padding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Cajero",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                ),
                              ),
                              SizedBox(width: 50),
                            ],
                          ),
                        ),
                        // Filas de cajeros seleccionados
                        ..._usuariosDisponibles
                            .where((cajero) => _selectedCajero == cajero)
                            .map(
                              (cajero) => Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cajero,
                                        style: TextStyle(color: textDark),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        // Eliminar cajero
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Campo para Monto Inicial (solo para nuevos cuadres)
          if (_cuadreActual == null) ...[
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
                      "Monto Inicial",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _montoAperturaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Ingrese el monto inicial',
                        labelStyle: TextStyle(color: textLight),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 15,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primary),
                        ),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: textDark),
                      ),
                      style: TextStyle(color: textDark),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese el monto inicial';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Por favor ingrese un número válido';
                        }
                        if (double.parse(value) < 0) {
                          return 'El monto no puede ser negativo';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
          ],

          // Identificación máquina
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
                    "Identificación máquina:",
                    style: TextStyle(fontSize: 16, color: textDark),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _idMaquinaController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20), // Ventas
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
                    "Ventas",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16), // Tabla de ventas
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Table(
                      columnWidths: {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(3),
                        2: FlexColumnWidth(1),
                      },
                      border: TableBorder.all(
                        color: Colors.grey.shade800,
                        width: 1,
                      ),
                      children: [
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Medio de pago",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Ventas",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Contador",
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("Efectivo"),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: _montoEfectivoController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => _actualizarTotales(),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: IconButton(
                                icon: Icon(
                                  Icons.calculate,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _abrirContadorEfectivo(paraEfectivo: true),
                                tooltip: 'Contador de billetes y monedas',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.green.withOpacity(
                                    0.1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("Transferencia"),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: _montoTransferenciasController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => _actualizarTotales(),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.credit_card,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Total Declarado",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                formatCurrency(_totalIngresos),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Información financiera importante
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
                    "Información Financiera",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  if (_cuadreActual != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Monto inicial:",
                          style: TextStyle(color: textDark),
                        ),
                        Text(
                          formatCurrency(_cuadreActual!.fondoInicial),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Fecha apertura:",
                          style: TextStyle(color: textDark),
                        ),
                        Text(
                          "${_cuadreActual!.fechaApertura.day}/${_cuadreActual!.fechaApertura.month}/${_cuadreActual!.fechaApertura.year}",
                          style: TextStyle(color: textDark),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                  ],

                  // Información de efectivo esperado con logging mejorado
                  FutureBuilder<Map<String, dynamic>>(
                    future: _cuadreCajaService.getEfectivoEsperado(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                      }

                      if (snapshot.hasData) {
                        final data = snapshot.data!;
                        final efectivoEsperado = (data['efectivoEsperado'] ?? 0)
                            .toDouble();
                        final transferenciasEsperadas =
                            (data['transferenciasEsperadas'] ??
                                    data['transferenciaEsperada'] ??
                                    0)
                                .toDouble();
                        final totalEsperado =
                            efectivoEsperado + transferenciasEsperadas;
                        final esCalculoManual = data['calculoManual'] == true;
                        final tieneError = data['error'] != null;

                        return Column(
                          children: [
                            // Indicador de estado del cálculo
                            if (esCalculoManual || tieneError) ...[
                              Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                margin: EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color:
                                      (tieneError ? Colors.red : Colors.orange)
                                          .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        (tieneError
                                                ? Colors.red
                                                : Colors.orange)
                                            .withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      tieneError ? Icons.error : Icons.info,
                                      size: 16,
                                      color: tieneError
                                          ? Colors.red
                                          : Colors.orange,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      tieneError
                                          ? 'Error en cálculo'
                                          : 'Cálculo manual',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tieneError
                                            ? Colors.red
                                            : Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // Botón para autocompletar campos
                                    if (!tieneError &&
                                        (efectivoEsperado > 0 ||
                                            transferenciasEsperadas > 0)) ...[
                                      GestureDetector(
                                        onTap: () {
                                          // Autocompletar los campos de ventas
                                          setState(() {
                                            _montoEfectivoController.text =
                                                formatNumberWithDots(
                                                  efectivoEsperado,
                                                );
                                            _montoTransferenciasController
                                                .text = formatNumberWithDots(
                                              transferenciasEsperadas,
                                            );
                                          });
                                          _actualizarTotales();

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Campos actualizados con valores esperados',
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.green.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.auto_fix_high,
                                                size: 12,
                                                color: Colors.green,
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                'Auto',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.w500,
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
                            ],

                            // Efectivo esperado
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Efectivo esperado:",
                                  style: TextStyle(color: textDark),
                                ),
                                Text(
                                  formatCurrency(efectivoEsperado),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: tieneError ? Colors.red : primary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),

                            // Transferencias esperadas
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Transferencias esperadas:",
                                  style: TextStyle(color: textDark),
                                ),
                                Text(
                                  formatCurrency(transferenciasEsperadas),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: tieneError
                                        ? Colors.red
                                        : accentOrange,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),

                            // Total esperado con comparación
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Total esperado:",
                                        style: TextStyle(
                                          color: textDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        formatCurrency(totalEsperado),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: tieneError
                                              ? Colors.red
                                              : Colors.green,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Mostrar comparación si hay valores declarados
                                  if (_totalIngresos > 0) ...[
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Total declarado:",
                                          style: TextStyle(
                                            color: textLight,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          formatCurrency(_totalIngresos),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: primary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Diferencia:",
                                          style: TextStyle(
                                            color: textLight,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          formatCurrency(
                                            _totalIngresos - totalEsperado,
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                (_totalIngresos - totalEsperado)
                                                        .abs() <=
                                                    5000
                                                ? Colors.green
                                                : (_totalIngresos >
                                                          totalEsperado
                                                      ? Colors.blue
                                                      : Colors.red),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Información de debug para usuarios admin
                            if (esCalculoManual || tieneError) ...[
                              SizedBox(height: 8),
                              ExpansionTile(
                                title: Text(
                                  'Información técnica',
                                  style: TextStyle(
                                    color: textLight,
                                    fontSize: 12,
                                  ),
                                ),
                                iconColor: textLight,
                                children: [
                                  if (data['timestamp'] != null)
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Calculado: ${DateTime.parse(data['timestamp']).toString().substring(11, 19)}',
                                            style: TextStyle(
                                              color: textLight,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (data['error'] != null)
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        'Error: ${data['error']}',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        );
                      } else if (snapshot.hasError) {
                        return Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.error,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Error al cargar efectivo esperado',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Error: ${snapshot.error.toString()}',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Efectivo esperado:",
                                  style: TextStyle(color: textDark),
                                ),
                                Text(
                                  "Error",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Transferencias esperadas:",
                                  style: TextStyle(color: textDark),
                                ),
                                Text(
                                  "Error",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      } else {
                        // Loading state
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Efectivo esperado:",
                                  style: TextStyle(color: textDark),
                                ),
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Transferencias esperadas:",
                                  style: TextStyle(color: textDark),
                                ),
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: accentOrange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Cerrar caja
          Card(
            elevation: 4,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    "Cerrar caja",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(width: 16),
                  Switch(
                    value: _cerrarCajaSwitch,
                    onChanged: (value) {
                      setState(() {
                        _cerrarCajaSwitch = value;
                      });
                    },
                    activeThumbColor: primary,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30), // Botón guardar cambios
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 4,
              ),
              onPressed: () async {
                // Solo actualizar cuadre existente
                if (_cuadreActual != null) {
                  await _actualizarCuadre();
                  setState(() {
                    _showCashRegisterForm = false;
                  });
                }
              },
              child: Text("Guardar cambios"),
            ),
          ),
        ],
      ),
    );
  }

  // Mostrar diálogo con detalles completos del cuadre cerrado
  void _mostrarDialogoDetalleCuadre(CuadreCaja cuadre) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: Column(
              children: [
                // Header del diálogo
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Resumen de Cierre",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Contenido del diálogo con FutureBuilder
                Expanded(
                  child: FutureBuilder<ResumenCierre>(
                    future: ResumenCierreService().getResumenCierre(
                      cuadre.id ?? '',
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Generando resumen detallado...',
                                style: TextStyle(color: textDark),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.red, size: 64),
                              SizedBox(height: 16),
                              Text(
                                'Error al cargar el resumen',
                                style: TextStyle(color: textDark, fontSize: 18),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                style: TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _mostrarDialogoDetalleCuadre(
                                    cuadre,
                                  ); // Reintentar
                                },
                                child: Text('Reintentar'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return Center(
                          child: Text(
                            'No hay datos disponibles',
                            style: TextStyle(color: textDark),
                          ),
                        );
                      }

                      final resumen = snapshot.data!;
                      return _buildResumenCierreContent(resumen);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper para formatear fecha y hora
  String _formatearFechaHora(DateTime fecha) {
    return "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}:${fecha.second.toString().padLeft(2, '0')} ${fecha.hour >= 12 ? 'p. m.' : 'a. m.'}";
  }

  // Helper para construir secciones de detalle
  Widget _buildSeccionDetalle(String titulo, List<String> contenido) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        SizedBox(height: 10),
        ...contenido.map(
          (item) => Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(item, style: TextStyle(color: textDark)),
          ),
        ),
      ],
    );
  }

  // Helper para construir tablas de detalle
  Widget _buildTablaDetalle(String titulo, List<List<String>> filas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titulo.isNotEmpty) ...[
          Center(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ),
          SizedBox(height: 10),
        ],
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade600),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade600),
            children: filas.asMap().entries.map((entry) {
              int index = entry.key;
              List<String> fila = entry.value;
              bool esEncabezado = index == 0;

              return TableRow(
                decoration: BoxDecoration(
                  color: esEncabezado
                      ? Colors.grey.shade800.withOpacity(0.3)
                      : null,
                ),
                children: fila
                    .map(
                      (celda) => Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          celda,
                          style: TextStyle(
                            color: textDark,
                            fontWeight: esEncabezado
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: fila.length > 2 && celda.contains('\$')
                              ? TextAlign.right
                              : TextAlign.left,
                        ),
                      ),
                    )
                    .toList(),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Helper para construir el resumen final - Ahora con gastos dinámicos y transferencias
  Widget _buildResumenFinal(CuadreCaja cuadre) {
    return FutureBuilder<Map<String, dynamic>>(
      future:
          Future.wait([
            _gastoService.getGastosByCuadre(cuadre.id!),
            _cuadreCajaService.getEfectivoEsperado(),
          ]).then(
            (results) => {
              'gastos': results[0] as List<Gasto>,
              'efectivoData': results[1] as Map<String, dynamic>,
            },
          ),
      builder: (context, snapshot) {
        double inicial = cuadre.fondoInicial;
        double ventasEfectivo = cuadre.efectivoEsperado;
        double ventasTransferencias = 0;
        double gastos = 0;

        if (snapshot.hasData) {
          final data = snapshot.data!;

          // Calcular gastos
          final gastosData = data['gastos'] as List<Gasto>;
          gastos = gastosData.fold(0, (total, gasto) => total + gasto.monto);

          // Obtener transferencias
          final efectivoData = data['efectivoData'] as Map<String, dynamic>;
          ventasTransferencias =
              (efectivoData['transferenciasEsperadas'] ??
                      efectivoData['transferenciaEsperada'] ??
                      0)
                  .toDouble();
        }

        double totalVentas = ventasEfectivo + ventasTransferencias;
        double facturas = 0; // Podrías agregar otra consulta para facturas
        double totalEfectivo = inicial + ventasEfectivo - gastos - facturas;

        return _buildTablaDetalle("Resumen", [
          ["", ""],
          [
            "Inicial + ventas efectivo",
            formatCurrency(inicial + ventasEfectivo),
          ],
          ["Transferencias", formatCurrency(ventasTransferencias)],
          [
            "Total inicial + ventas + transferencias",
            formatCurrency(inicial + totalVentas),
          ],
          ["Pagos facturas de compras", "-${formatCurrency(facturas)}"],
          ["Total Gastos", "-${formatCurrency(gastos)}"],
          ["Total Efectivo en caja", formatCurrency(totalEfectivo)],
          ["", ""],
          ["Debe tener en efectivo", formatCurrency(totalEfectivo)],
          [
            "Debe tener en transferencias",
            formatCurrency(ventasTransferencias),
          ],
          ["", ""],
          // Eliminado: Domicilios
        ]);
      },
    );
  }

  // Método que valida el cuadre antes de generar el resumen
  Future<ResumenCierre> _generarResumenConValidacion(String cuadreId) async {
    try {
      if (cuadreId.isEmpty) {
        throw Exception('ID de cuadre no válido');
      }

      // Validar que el cuadre existe
      final cuadreExiste = await _resumenCierreService.validarCuadreExiste(
        cuadreId,
      );
      if (!cuadreExiste) {
        throw Exception('El cuadre especificado no existe o no es accesible');
      }

      // Generar el resumen
      return await _resumenCierreService.getResumenCierre(cuadreId);
    } catch (e) {
      print('❌ Error en validación/generación de resumen: $e');
      rethrow;
    }
  }

  void _mostrarResumenDetallado(CuadreCaja cuadre) {
    final Color primary = Color(0xFF1976D2);
    final Color cardBg = Color(0xFF2C2C2C);
    final Color textDark = Color(0xFFFFFFFF);
    final Color textLight = Color(0xFFBBBBBB);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: Column(
              children: [
                // Header del diálogo
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Resumen de Cierre Detallado",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Contenido del diálogo con FutureBuilder
                Expanded(
                  child: FutureBuilder<ResumenCierre>(
                    future: _generarResumenConValidacion(cuadre.id ?? ''),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: primary),
                              SizedBox(height: 16),
                              Text(
                                'Generando resumen detallado...',
                                style: TextStyle(color: textDark),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Esto puede tomar unos segundos',
                                style: TextStyle(
                                  color: textLight,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mostrar error pero permitir ver información básica
                              Container(
                                padding: EdgeInsets.all(12),
                                margin: EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.warning,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Resumen completo no disponible',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '${snapshot.error}',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _mostrarResumenDetallado(cuadre);
                                          },
                                          icon: Icon(Icons.refresh, size: 16),
                                          label: Text('Reintentar'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Mostrar información básica disponible
                              Text(
                                'Información Básica Disponible',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                              SizedBox(height: 16),

                              // Información del cuadre
                              _buildInfoCardFallback([
                                ['Responsable', cuadre.responsable],
                                ['Caja', cuadre.nombre],
                                [
                                  'Fecha apertura',
                                  _formatearFechaHora(cuadre.fechaApertura),
                                ],
                                [
                                  'Fecha cierre',
                                  cuadre.fechaCierre != null
                                      ? _formatearFechaHora(cuadre.fechaCierre!)
                                      : 'No cerrada',
                                ],
                                [
                                  'Estado',
                                  cuadre.cerrada ? 'Cerrada' : 'Abierta',
                                ],
                              ]),
                              SizedBox(height: 20),

                              // Información financiera básica
                              Text(
                                'Información Financiera',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                              SizedBox(height: 10),
                              _buildInfoCardFallback([
                                [
                                  'Fondo inicial',
                                  formatCurrency(cuadre.fondoInicial),
                                ],
                                [
                                  'Efectivo esperado',
                                  formatCurrency(cuadre.efectivoEsperado),
                                ],
                                // Eliminado: Efectivo declarado y diferencia
                              ]),
                              SizedBox(height: 20),

                              // Observaciones si las hay
                              if (cuadre.observaciones != null &&
                                  cuadre.observaciones!.isNotEmpty) ...[
                                Text(
                                  'Observaciones',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    cuadre.observaciones!,
                                    style: TextStyle(color: textDark),
                                  ),
                                ),
                                SizedBox(height: 20),
                              ],

                              // Nota sobre limitaciones
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Información limitada',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'El resumen completo no está disponible debido a un problema técnico. Se muestra la información básica del cuadre. Para el resumen detallado, puede intentar nuevamente o contactar soporte.',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return Center(
                          child: Text(
                            'No hay datos disponibles',
                            style: TextStyle(color: textDark),
                          ),
                        );
                      }

                      final resumen = snapshot.data!;
                      return _buildResumenCierreContent(resumen);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResumenCierreContent(ResumenCierre resumen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información básica
          _buildSeccionTitulo('Información General'),
          _buildInfoCard([
            ['Responsable', resumen.cuadreInfo.responsable],
            ['Caja', resumen.cuadreInfo.nombre],
            [
              'Fecha apertura',
              _formatearFechaHora(
                DateTime.parse(resumen.cuadreInfo.fechaApertura),
              ),
            ],
            [
              'Fecha cierre',
              resumen.cuadreInfo.fechaCierre != null
                  ? _formatearFechaHora(
                      DateTime.parse(resumen.cuadreInfo.fechaCierre!),
                    )
                  : 'No cerrada',
            ],
            ['Estado', resumen.cuadreInfo.estado],
          ]),

          SizedBox(height: 20),

          // Resumen financiero
          _buildSeccionTitulo('Resumen Financiero'),
          _buildInfoCard([
            ['Fondo inicial', formatCurrency(resumen.cuadreInfo.fondoInicial)],
            ['Total ventas', formatCurrency(resumen.resumenFinal.totalVentas)],
            [
              'Ingresos de caja',
              formatCurrency(resumen.movimientosEfectivo.ingresosEfectivo),
            ],
            ['Total gastos', formatCurrency(resumen.resumenFinal.totalGastos)],
            [
              'Total compras',
              formatCurrency(resumen.resumenFinal.totalCompras),
            ],
            [
              'Utilidad bruta',
              formatCurrency(resumen.resumenFinal.utilidadBruta),
            ],
            [
              'Efectivo esperado',
              formatCurrency(resumen.resumenFinal.efectivoEsperado),
            ],
          ]),

          SizedBox(height: 20),

          // Movimientos de efectivo
          _buildSeccionTitulo('Movimientos de Efectivo'),
          _buildInfoCard([
            [
              'Fondo inicial',
              '\$${resumen.movimientosEfectivo.fondoInicial.toStringAsFixed(2)}',
            ],
            [
              'Ventas en efectivo',
              '\$${resumen.movimientosEfectivo.ventasEfectivo.toStringAsFixed(2)}',
            ],
            [
              'Ingresos de caja',
              '\$${resumen.movimientosEfectivo.ingresosEfectivo.toStringAsFixed(2)}',
            ],
            [
              'Gastos en efectivo',
              '\$${resumen.movimientosEfectivo.gastosEfectivo.toStringAsFixed(2)}',
            ],
            [
              'Compras en efectivo',
              '\$${resumen.movimientosEfectivo.comprasEfectivo.toStringAsFixed(2)}',
            ],
            [
              'Efectivo esperado',
              '\$${resumen.movimientosEfectivo.efectivoEsperado.toStringAsFixed(2)}',
            ],
            // Eliminado: Efectivo declarado, diferencia, tolerancia y cuadrado
          ]),

          SizedBox(height: 20),

          // Resumen de ventas
          _buildSeccionTitulo('Resumen de Ventas'),
          _buildInfoCard([
            ['Total pedidos', '${resumen.resumenVentas.totalPedidos}'],
            [
              'Total ventas',
              '\$${resumen.resumenVentas.totalVentas.toStringAsFixed(2)}',
            ],
          ]),

          SizedBox(height: 10),

          // Ventas por forma de pago
          if (resumen.resumenVentas.ventasPorFormaPago.isNotEmpty) ...[
            _buildSeccionTitulo('Ventas por Forma de Pago'),
            _buildVentasFormaPagoTable(resumen.resumenVentas),
            SizedBox(height: 20),
          ],

          // Detalle de pedidos
          if (resumen.resumenVentas.detallesPedidos.isNotEmpty) ...[
            _buildSeccionTitulo('Detalle de Pedidos'),
            _buildDetallesPedidosTable(resumen.resumenVentas.detallesPedidos),
            SizedBox(height: 20),
          ],

          // Resumen de gastos
          if (resumen.resumenGastos.totalRegistros > 0) ...[
            _buildSeccionTitulo('Resumen de Gastos'),
            _buildInfoCard([
              ['Total registros', '${resumen.resumenGastos.totalRegistros}'],
              [
                'Total gastos',
                '\$${resumen.resumenGastos.totalGastos.toStringAsFixed(2)}',
              ],
            ]),
            SizedBox(height: 20),
          ],

          // Resumen de compras
          if (resumen.resumenCompras.totalFacturas > 0) ...[
            _buildSeccionTitulo('Resumen de Compras'),
            _buildInfoCard([
              ['Total facturas', '${resumen.resumenCompras.totalFacturas}'],
              [
                'Total compras',
                '\$${resumen.resumenCompras.totalCompras.toStringAsFixed(2)}',
              ],
            ]),
            SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildVentasFormaPagoTable(ResumenVentas resumenVentas) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primary.withOpacity(0.3)),
      ),
      child: Table(
        border: TableBorder.all(color: primary.withOpacity(0.2), width: 1),
        children: [
          TableRow(
            decoration: BoxDecoration(color: primary.withOpacity(0.1)),
            children: [
              _buildTableHeader('Forma de Pago'),
              _buildTableHeader('Cantidad'),
              _buildTableHeader('Total'),
            ],
          ),
          ...resumenVentas.ventasPorFormaPago.entries.map((entry) {
            final cantidad = resumenVentas.cantidadPorFormaPago[entry.key] ?? 0;
            return TableRow(
              children: [
                _buildTableCell(entry.key.toUpperCase()),
                _buildTableCell('$cantidad'),
                _buildTableCell('\$${entry.value.toStringAsFixed(2)}'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetallesPedidosTable(List<DetallePedido> pedidos) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'Mesa',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Fecha',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Pago',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...pedidos.take(10).map((pedido) {
            return Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: primary.withOpacity(0.2)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(pedido.mesa, style: TextStyle(color: textDark)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatearFecha(DateTime.parse(pedido.fechaPago)),
                      style: TextStyle(color: textDark, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      pedido.formaPago.toUpperCase(),
                      style: TextStyle(color: textDark, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      formatCurrency(pedido.total),
                      style: TextStyle(color: textDark),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (pedidos.length > 10)
            Container(
              padding: EdgeInsets.all(12),
              child: Text(
                'Mostrando 10 de ${pedidos.length} pedidos',
                style: TextStyle(color: textLight, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _buildSeccionTitulo(String titulo) {
  final Color primary = Color(0xFF1976D2);

  return Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Text(
      titulo,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: primary,
      ),
    ),
  );
}

Widget _buildInfoCard(List<List<String>> datos) {
  final Color cardBg = Color(0xFF2C2C2C);
  final Color textDark = Color(0xFFFFFFFF);
  final Color textLight = Color(0xFFBBBBBB);

  return Card(
    color: cardBg,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: datos.map((fila) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(fila[0], style: TextStyle(color: textLight)),
                Text(
                  fila[1],
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ),
  );
}
