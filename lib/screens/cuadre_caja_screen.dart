import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../models/gasto.dart';
import '../services/cuadre_caja_service.dart';
import '../services/gasto_service.dart';
import 'gastos_screen.dart';
import 'tipos_gasto_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CuadreCajaScreen extends StatefulWidget {
  @override
  _CuadreCajaScreenState createState() => _CuadreCajaScreenState();
}

class _CuadreCajaScreenState extends State<CuadreCajaScreen>
    with SingleTickerProviderStateMixin {
  final Color primary = Color(0xFFFF6B00); // Color naranja fuego
  final Color bgDark = Color(0xFF1E1E1E); // Color de fondo negro
  final Color cardBg = Color(0xFF252525); // Color de tarjetas
  final Color textDark = Color(0xFFE0E0E0); // Color de texto claro
  final Color textLight = Color(0xFFA0A0A0); // Color de texto más suave
  final Color accentOrange = Color(0xFFFF8800); // Naranja más brillante

  // Services
  final GastoService _gastoService = GastoService();

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
  final String baseUrl = 'http://192.168.20.24:8081';

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

  // Limpiar los controladores del formulario
  void _limpiarFormulario() {
    _montoAperturaController.clear();
    _montoEfectivoController.clear();
    _montoTransferenciasController.clear();
    _notasController.clear();
    _cerrarCajaSwitch = false;
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

  Future<void> _loadCuadresCaja() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Usar el nuevo servicio en lugar de llamadas HTTP directas
      final cuadres = await _cuadreCajaService.getAllCuadres();

      setState(() {
        _cuadresCaja = cuadres;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar cuadres: ${e.toString()}';
      });
      print('Error loading cuadres caja: $e');
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
        final responseData = json.decode(response.body);
        // Ajustar según la estructura de respuesta del backend
        if (responseData['success'] == true || responseData['data'] != null) {
          final userData = responseData['data'] ?? responseData['users'] ?? [];
          setState(() {
            _usuariosDisponibles = List<String>.from(
              userData.map(
                (user) => user['nombre'] ?? user['name'] ?? user['email'] ?? '',
              ),
            );
          });
        }
      } else if (response.statusCode == 404) {
        // Si el endpoint no existe, usar lista predefinida basada en roles comunes
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
    } catch (e) {
      print('Error loading usuarios: $e');
      // Fallback a lista predefinida
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

  // Cargar efectivo esperado del backend
  Future<double> _loadEfectivoEsperado() async {
    try {
      final efectivoData = await _cuadreCajaService.getEfectivoEsperado();
      return (efectivoData['efectivoEsperado'] ?? 0).toDouble();
    } catch (e) {
      print('Error loading efectivo esperado: $e');
      // Fallback: calcular manualmente basado en ventas del día
      return 0.0; // Se calculará cuando se abra el diálogo
    }
  }

  Future<void> _buscarCuadres() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Por ahora obtenemos todos los cuadres
      // TODO: Mejorar el servicio para aceptar filtros
      final cuadres = await _cuadreCajaService.getAllCuadres();
      setState(() {
        _cuadresCaja = cuadres;
      });
    } catch (e) {
      print('Error en búsqueda: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _crearNuevoCuadre() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final responsable = userProvider.userName ?? 'Usuario Desconocido';
      final montoApertura = double.tryParse(_montoAperturaController.text) ?? 0;

      // Debug: Verificar que el monto se está leyendo correctamente
      print(
        'DEBUG FRONTEND: Monto inicial texto: "${_montoAperturaController.text}"',
      );
      print('DEBUG FRONTEND: Monto inicial parseado: $montoApertura');
      print('DEBUG FRONTEND: Responsable: $responsable');
      print(
        'DEBUG FRONTEND: Nombre caja: ${_selectedCaja ?? 'Caja Principal'}',
      );

      final cuadre = await _cuadreCajaService.createCuadre(
        nombre: _selectedCaja ?? 'Caja Principal',
        responsable: responsable,
        fondoInicial: montoApertura,
        efectivoDeclarado: 0, // Al crear se inicia en 0
        efectivoEsperado: 0, // Al crear se inicia en 0
        tolerancia: 5.0, // Tolerancia por defecto
        observaciones: 'Cuadre creado - ${_idMaquinaController.text}',
      );

      if (cuadre.id != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cuadre de caja creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCuadresCaja();
      } else {
        throw Exception('Error al crear el cuadre');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear cuadre: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

      print('DEBUG: _cerrarCajaSwitch = $_cerrarCajaSwitch');
      print(
        'DEBUG: Fecha cierre = ${_cerrarCajaSwitch ? DateTime.now() : null}',
      );

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

  void _imprimirComprobante(CuadreCaja cuadre) {
    // TODO: Implementar lógica de impresión de comprobante
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Función de impresión de comprobante en desarrollo'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _imprimirInventario(CuadreCaja cuadre) {
    // TODO: Implementar lógica de impresión de inventario
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Función de impresión de inventario en desarrollo'),
        backgroundColor: Colors.orange,
      ),
    );
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
                } else if (value == 'tipos_gasto') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TiposGastoScreen()),
                  );
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
              ],
            ),
          _showCashRegisterForm
              ? TextButton.icon(
                  icon: Icon(Icons.save, color: Colors.white),
                  label: Text('Guardar', style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    // Validar campos requeridos
                    if (_cuadreActual == null) {
                      // Crear nuevo cuadre
                      if (_montoAperturaController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Por favor ingrese el monto inicial'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      await _crearNuevoCuadre();
                    } else {
                      // Actualizar cuadre existente
                      await _actualizarCuadre();
                    }

                    setState(() {
                      _showCashRegisterForm = false;
                    });
                  },
                )
              : TextButton.icon(
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text('Nueva', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () async {
                    setState(() {
                      _cuadreActual = null; // Nuevo cuadre
                      _showCashRegisterForm = true;
                    });
                    _limpiarFormulario(); // Limpiar los campos para nueva caja
                    await _loadEfectivoEsperado();
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
                          value: _selectedCaja,
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
                          value: _selectedResponsable,
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
                          value: _selectedEstado,
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
              : Container(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        Colors.black.withOpacity(0.3),
                      ),
                      dataRowColor: MaterialStateProperty.all(
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
                                '\$ ${cuadre.fondoInicial.toStringAsFixed(0)}',
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
                                  if (cuadre.cerrada) {
                                    // Si la caja está cerrada, mostrar diálogo de detalles
                                    _mostrarDialogoDetalleCuadre(cuadre);
                                  } else {
                                    // Si está abierta, mostrar formulario de edición
                                    setState(() {
                                      _cuadreActual = cuadre;
                                      _showCashRegisterForm = true;
                                    });
                                    await _loadEfectivoEsperado();
                                    // Prellenar campos con datos del cuadre actual
                                    if (_cuadreActual != null) {
                                      _montoAperturaController.text =
                                          _cuadreActual!.fondoInicial
                                              .toString();
                                      _montoEfectivoController.text =
                                          _cuadreActual!.efectivoDeclarado
                                              .toString();
                                      _notasController.text =
                                          _cuadreActual!.observaciones ?? '';
                                    }
                                  }
                                },
                                child: Text(
                                  cuadre.cerrada ? 'Ver' : 'Ver/Cerrar',
                                ),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: Icon(Icons.print, color: primary),
                                onPressed: () {
                                  _imprimirComprobante(cuadre);
                                },
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: Icon(Icons.print, color: primary),
                                onPressed: () {
                                  _imprimirInventario(cuadre);
                                },
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
                          value: _selectedCajero,
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
                            )
                            .toList(),
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
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1),
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
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Total",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "\$ ${_totalIngresos.toStringAsFixed(0)}",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
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
                          "\$ ${_cuadreActual!.fondoInicial.toStringAsFixed(0)}",
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
                  FutureBuilder<double>(
                    future: _loadEfectivoEsperado(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Efectivo esperado:",
                              style: TextStyle(color: textDark),
                            ),
                            Text(
                              "\$ ${snapshot.data!.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Efectivo esperado:",
                              style: TextStyle(color: textDark),
                            ),
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
          SizedBox(height: 20), // Cerrar caja
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
                    activeColor: primary,
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
                if (_cuadreActual == null) {
                  // Crear nuevo cuadre
                  await _crearNuevoCuadre();
                } else {
                  // Actualizar cuadre existente
                  await _actualizarCuadre();
                }
                setState(() {
                  _showCashRegisterForm = false;
                });
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
          child: Container(
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
                        "Cuadre de caja",
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

                // Contenido del diálogo
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fechas
                        Center(
                          child: Column(
                            children: [
                              Text(
                                "Fecha inicio: ${_formatearFechaHora(cuadre.fechaApertura)}",
                                style: TextStyle(fontSize: 16, color: textDark),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Fecha Fin: ${cuadre.fechaCierre != null ? _formatearFechaHora(cuadre.fechaCierre!) : 'No cerrada'}",
                                style: TextStyle(fontSize: 16, color: textDark),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 30),

                        // Responsable y Caja
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Responsable",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: textLight,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    cuadre.responsable,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Caja",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: textLight,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    cuadre.nombre,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 30),

                        // Cajeros
                        _buildSeccionDetalle("Cajeros", [
                          "Alejandro Montoya Rojas, Alejandro Giraldo, Camila Giraldo, Daniel Vargas, Dania Alvarán, Felipe Villa Caicedo, Gustavo Galvis, Isabella Quintero, Jacobo Martínez Rojas, Juan Diego Castaño, Leonardo Vargas, Paula Díaz, SARA VELEZ, Sara Sofía Pardo, Sebastian Vargas, Sergio Velasquez, Sopa y Carbon Vargas Rendon, Valentina Ocampo, Valeria Alvarez, Victor Patiño",
                        ]),

                        SizedBox(height: 20),

                        // Tabla de inicial
                        _buildTablaDetalle("Inicial", [
                          ["Medio de pago", "Inicial"],
                          [
                            "Efectivo",
                            "\$ ${cuadre.fondoInicial.toStringAsFixed(0)}",
                          ],
                          ["Transferencia", "\$ 0"],
                          [
                            "Total",
                            "\$ ${cuadre.fondoInicial.toStringAsFixed(0)}",
                          ],
                        ]),

                        SizedBox(height: 20),

                        // Tabla de ventas
                        _buildTablaDetalle("Ventas", [
                          ["Nombre", "Sistema"],
                          [
                            "Efectivo",
                            "\$ ${cuadre.efectivoEsperado.toStringAsFixed(0)}",
                          ],
                          ["Transferencia", "\$ 0"],
                          [
                            "Total Ventas",
                            "\$ ${cuadre.efectivoEsperado.toStringAsFixed(0)}",
                          ],
                          ["Total Propinas", "\$ 0"],
                        ]),

                        SizedBox(height: 20),

                        // Tabla de resumen
                        _buildTablaDetalle(
                          "",
                          [
                            [
                              "Efectivo",
                              "\$ ${cuadre.efectivoEsperado.toStringAsFixed(0)}",
                              "\$ 0",
                              "\$ 0",
                              "\$ ${cuadre.efectivoEsperado.toStringAsFixed(0)}",
                            ],
                            ["Transferencia", "\$ 0", "\$ 0", "\$ 0", "\$ 0"],
                            [
                              "Total",
                              "\$ ${cuadre.efectivoEsperado.toStringAsFixed(0)}",
                              "\$ 0",
                              "\$ 0",
                              "\$ ${cuadre.efectivoEsperado.toStringAsFixed(0)}",
                            ],
                          ],
                          encabezados: ["", "", "", "", ""],
                        ),

                        SizedBox(height: 20),

                        // Impuestos
                        _buildTablaDetalle("Impuestos", [
                          ["Nombre", "Base", "Imp"],
                          ["Total", "", "\$ 0"],
                        ]),

                        SizedBox(height: 20),

                        // Gastos - Ahora usando datos dinámicos del backend
                        FutureBuilder<List<Gasto>>(
                          future: _gastoService.getGastosByCuadre(cuadre.id!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Container(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: primary,
                                  ),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return _buildTablaDetalle("Gastos", [
                                ["Tipo de gasto", "Total"],
                                ["Error al cargar gastos", "\$ 0"],
                              ]);
                            }

                            final gastos = snapshot.data ?? [];

                            // Agrupar gastos por tipo
                            Map<String, double> gastosPorTipo = {};
                            double totalGastos = 0;

                            for (final gasto in gastos) {
                              final tipoNombre = gasto.tipoGastoNombre.isEmpty
                                  ? 'Sin categoría'
                                  : gasto.tipoGastoNombre;
                              gastosPorTipo[tipoNombre] =
                                  (gastosPorTipo[tipoNombre] ?? 0) +
                                  gasto.monto;
                              totalGastos += gasto.monto;
                            }

                            // Construir filas para la tabla
                            List<List<String>> filasGastos = [
                              ["Tipo de gasto", "Total"],
                            ];

                            if (gastosPorTipo.isEmpty) {
                              filasGastos.add([
                                "No hay gastos registrados",
                                "\$ 0",
                              ]);
                            } else {
                              gastosPorTipo.forEach((tipo, monto) {
                                filasGastos.add([
                                  tipo,
                                  "\$ ${monto.toStringAsFixed(0)}",
                                ]);
                              });

                              // Agregar fila de total si hay más de un tipo
                              if (gastosPorTipo.length > 1) {
                                filasGastos.add([
                                  "TOTAL GASTOS",
                                  "\$ ${totalGastos.toStringAsFixed(0)}",
                                ]);
                              }
                            }

                            return Column(
                              children: [
                                _buildTablaDetalle("Gastos", filasGastos),
                                SizedBox(height: 10),
                                // Botón para ir a gestión de gastos
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(
                                      context,
                                    ).pop(); // Cerrar diálogo
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => GastosScreen(
                                          cuadreCajaId: cuadre.id,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.edit, color: Colors.white),
                                  label: Text(
                                    'Gestionar Gastos',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        SizedBox(height: 20),

                        // Resumen final
                        _buildResumenFinal(cuadre),
                      ],
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
        ...contenido
            .map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(item, style: TextStyle(color: textDark)),
              ),
            )
            .toList(),
      ],
    );
  }

  // Helper para construir tablas de detalle
  Widget _buildTablaDetalle(
    String titulo,
    List<List<String>> filas, {
    List<String>? encabezados,
  }) {
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

  // Helper para construir el resumen final - Ahora con gastos dinámicos
  Widget _buildResumenFinal(CuadreCaja cuadre) {
    return FutureBuilder<List<Gasto>>(
      future: _gastoService.getGastosByCuadre(cuadre.id!),
      builder: (context, snapshot) {
        double inicial = cuadre.fondoInicial;
        double ventas = cuadre.efectivoEsperado;
        double gastos = 0;

        // Calcular total de gastos desde el backend
        if (snapshot.hasData) {
          gastos = snapshot.data!.fold(
            0,
            (total, gasto) => total + gasto.monto,
          );
        }

        double facturas = 0; // Podrías agregar otra consulta para facturas
        double totalEfectivo = inicial + ventas - gastos - facturas;

        return _buildTablaDetalle("Resumen", [
          ["", ""],
          ["Inicial + ventas", "\$ ${(inicial + ventas).toStringAsFixed(0)}"],
          [
            "Inicial + ventas + propinas + domicilios",
            "\$ ${(inicial + ventas).toStringAsFixed(0)}",
          ],
          ["Pagos facturas de compras", "-\$ ${facturas.toStringAsFixed(0)}"],
          ["Total Gastos", "-\$ ${gastos.toStringAsFixed(0)}"],
          ["Total Efectivo", "\$ ${totalEfectivo.toStringAsFixed(0)}"],
          ["", ""],
          ["Debe tener", "\$ ${totalEfectivo.toStringAsFixed(0)}"],
          ["", ""],
          ["Domicilios", "\$ 0"],
        ]);
      },
    );
  }
}
