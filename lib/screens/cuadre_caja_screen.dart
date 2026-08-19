import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../config/constants.dart';

import '../services/cuadre_caja_service.dart';

import 'resumen_cierre_detallado_screen.dart';
import '../utils/format_utils.dart';
import 'contador_efectivo_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../utils/pagination_mixin.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';

class CuadreCajaScreen extends StatefulWidget {
  const CuadreCajaScreen({super.key});

  @override
  _CuadreCajaScreenState createState() => _CuadreCajaScreenState();
}

class _CuadreCajaScreenState extends State<CuadreCajaScreen>
    with SingleTickerProviderStateMixin, PaginacionMixin<CuadreCajaScreen> {
  // Getters para compatibilidad temporal con AppTheme
  Color get primary => AppTheme.primary;
  Color get bgDark => Theme.of(context).scaffoldBackgroundColor;
  Color get cardBg => Theme.of(context).colorScheme.surface;
  Color get textDark => Theme.of(context).colorScheme.onSurface;
  Color get textLight => Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
  Color get accentOrange => AppTheme.accent;

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
  final TextEditingController _montoTarjetaController =
      TextEditingController();
  final TextEditingController _montoSistereditoController =
      TextEditingController();
  final TextEditingController _montoDatafonoController =
      TextEditingController();
  final TextEditingController _ingresoEfectivoController =
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
  // Todas las cajas abiertas ahora mismo (puede haber una LOCAL y una ENVIOS
  // a la vez) — _cuadreActual es cuál de ellas se está mostrando/editando.
  List<CuadreCaja> _cajasAbiertas = [];

  // Services
  final CuadreCajaService _cuadreCajaService = CuadreCajaService();
  String get baseUrl => kDynamicBackendUrl;

  // Filtros
  String? _selectedCaja;
  String? _selectedResponsable;
  String? _selectedEstado;
  String? _selectedCajero;
  List<String> _cajerosAgregados = []; // cajeros confirmados para este cuadre

  @override
  void initState() {
    super.initState();
    _loadCuadresCaja();
    _loadUsuariosDisponibles();
    // Inicializar el controller de ingreso efectivo
    _ingresoEfectivoController.text = _totalIngresos.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _desdeController.dispose();
    _hastaController.dispose();
    _idMaquinaController.dispose();
    _montoAperturaController.dispose();
    _montoEfectivoController.dispose();
    _montoTransferenciasController.dispose();
    _montoTarjetaController.dispose();
    _montoSistereditoController.dispose();
    _montoDatafonoController.dispose();
    _ingresoEfectivoController.dispose();
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

      // Ordenar cuadres por fecha descendente (más recientes primero)
      cuadres.sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));

      if (!mounted) return;
      setState(() {
        _cuadresCaja = cuadres;

        _cajasAbiertas = cuadres
            .where(
              (cuadre) => (cuadre.estado == 'ABIERTA' || cuadre.estado == 'pendiente') && !cuadre.cerrada,
            )
            .toList();

        // 🔧 CORRECCIÓN: Asignar el cuadre actual (el que está abierto/pendiente)
        // Si el cuadre que se estaba viendo sigue abierto, mantenerlo
        // seleccionado en vez de saltar de vuelta al primero de la lista.
        final actualSigueAbierto = _cuadreActual != null &&
            _cajasAbiertas.any((c) => c.id == _cuadreActual!.id);
        if (!actualSigueAbierto) {
          _cuadreActual = _cajasAbiertas.firstOrNull ??
              (cuadres.isNotEmpty ? cuadres.first : null);
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al cargar cuadres: ${errorMessage(e)}';
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
      ).timeout(const Duration(seconds: 30));

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
              if (!mounted) return;
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
    // Esta función ya no modifica _totalIngresos para preservar
    // el valor de ingresosEfectivo que viene del backend

    // Si necesitamos actualizar otros totales en el futuro,
    // podemos hacerlo aquí
    setState(() {
      // Solo actualizamos la UI
    });
  }

  Future<void> _buscarCuadres() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener todos los cuadres y luego aplicar filtros en el cliente
      final cuadres = await _cuadreCajaService.getAllCuadres();

      // Aplicar filtros locales basados en los controles del formulario
      DateTime? desde;
      DateTime? hasta;

      if ((_desdeController.text).trim().isNotEmpty) {
        try {
          final parts = _desdeController.text.split('/');
          desde = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        } catch (e) {
          desde = null;
        }
      }

      if ((_hastaController.text).trim().isNotEmpty) {
        try {
          final parts = _hastaController.text.split('/');
          hasta = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
          // incluir todo el día
          hasta = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);
        } catch (e) {
          hasta = null;
        }
      }

      List<CuadreCaja> filtered = cuadres.where((c) {
        // Filtrar por fecha de apertura si aplica
        if (desde != null) {
          try {
            if (c.fechaApertura.isBefore(desde)) return false;
          } catch (_) {}
        }
        if (hasta != null) {
          try {
            if (c.fechaApertura.isAfter(hasta)) return false;
          } catch (_) {}
        }

        // Filtrar por tipo de caja (LOCAL/ENVIOS)
        if (_selectedCaja != null && _selectedCaja!.trim().isNotEmpty) {
          if (c.tipoCaja != _selectedCaja) return false;
        }

        // Filtrar por responsable
        if (_selectedResponsable != null &&
            _selectedResponsable!.trim().isNotEmpty) {
          if (c.responsable.toLowerCase() !=
              _selectedResponsable!.toLowerCase())
            return false;
        }

        // Filtrar por estado (UI: 'Abierta' / 'Cerrada')
        if (_selectedEstado != null && _selectedEstado!.trim().isNotEmpty) {
          final s = _selectedEstado!.toLowerCase();
          if (s == 'abierta' && (c.cerrada == true)) return false;
          if (s == 'cerrada' && (c.cerrada == false)) return false;
        }

        return true;
      }).toList();

      // Ordenar por fecha descendente
      filtered.sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));

      setState(() {
        _cuadresCaja = filtered;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error en búsqueda: ${errorMessage(e)}';
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
      showErrorDialog(context, 'Error al actualizar cuadre: ${errorMessage(e)}');
    }
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

  // Método para mostrar el resumen detallado del cuadre
  void _mostrarResumenDetallado(CuadreCaja cuadre) {
    if (cuadre.id == null) {
      showErrorDialog(context, 'ID del cuadre no disponible');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResumenCierreDetalladoScreen(
          cuadreId: cuadre.id!,
          nombreCuadre: cuadre.nombre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if user has admin permissions
    final userProvider = Provider.of<UserProvider>(context);
    if (!userProvider.isAdmin) {
      // Si el usuario no es admin, mostrar mensaje y pantalla de acceso restringido
      return Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(
          title: Text(
            'Cuadres de Caja',
            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
        body: Center(
          child: Container(
            margin: EdgeInsets.all(20),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, color: Colors.red, size: 64),
                SizedBox(height: 16),
                Text(
                  'Acceso Restringido',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Necesitas permisos de administrador para acceder a esta sección.',
                  style: TextStyle(color: textLight),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () =>
              context.go('/dashboard'),
        ),
        title: Text(
          'Cuadres de Caja',
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          // Botón para abrir caja — solo icono en móvil
          if (!_showCashRegisterForm)
            context.isMobile
                ? IconButton(
                    icon: Icon(Icons.lock_open, color: Colors.green),
                    tooltip: 'Abrir Caja',
                    onPressed: () async {
                      final result = await context.push('/abrir_caja');
                      if (result == true) _loadCuadresCaja();
                    },
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton.icon(
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
                        final result = await context.push('/abrir_caja');
                        if (result == true) _loadCuadresCaja();
                      },
                    ),
                  ),

          // Botón para cerrar caja — solo icono en móvil
          if (!_showCashRegisterForm)
            context.isMobile
                ? IconButton(
                    icon: Icon(Icons.lock, color: Colors.red),
                    tooltip: 'Cerrar Caja',
                    onPressed: () async {
                      final result = await context.push('/cerrar_caja');
                      if (result == true) _loadCuadresCaja();
                    },
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton.icon(
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
                        final result = await context.push('/cerrar_caja');
                        if (result == true) _loadCuadresCaja();
                      },
                    ),
                  ),

          // Menú de opciones de gestión
          if (!_showCashRegisterForm)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface),
              color: cardBg,
              onSelected: (value) {
                if (value == 'ingresos_caja') {
                  context.push('/ingresos-caja');
                } else if (value == 'contador_efectivo') {
                  _abrirContadorEfectivo();
                }
              },
              itemBuilder: (context) => [
                // PopupMenuItem de gastos eliminado
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
                // PopupMenuItem de tipos de gastos eliminado
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cajas abiertas ahora mismo (puede haber una LOCAL y una ENVIOS a
          // la vez) — acceso directo al resumen de cada una sin tener que
          // buscarlas entre el historial.
          if (_cajasAbiertas.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _cajasAbiertas.map((caja) {
                final esEnvios = caja.tipoCaja == 'ENVIOS';
                final color = esEnvios ? AppTheme.secondary : AppTheme.primary;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: caja == _cajasAbiertas.last ? 0 : 12,
                    ),
                    child: Card(
                      color: cardBg,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: color.withOpacity(0.4)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  esEnvios ? Icons.local_shipping : Icons.storefront,
                                  color: color,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  esEnvios ? 'Caja Envíos' : 'Caja Local',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                    fontSize: 14,
                                  ),
                                ),
                                Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ABIERTA',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Responsable: ${caja.responsable}',
                              style: TextStyle(color: textLight, fontSize: 12),
                            ),
                            Text(
                              'Fondo inicial: ${formatCurrency(caja.fondoInicial)}',
                              style: TextStyle(color: textLight, fontSize: 12),
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: color,
                                  side: BorderSide(color: color),
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () => _mostrarResumenDetallado(caja),
                                child: Text('Ver resumen', style: TextStyle(fontSize: 13)),
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
            SizedBox(height: 16),
          ],
          // Filtros de búsqueda
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
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: Theme.of(
                                      context,
                                    ).colorScheme.copyWith(primary: primary),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) {
                              setState(() {
                                _desdeController.text =
                                    "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                // Aplicar filtros inmediatamente cuando se selecciona una fecha
                                _buscarCuadres();
                              });
                            }
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
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: Theme.of(
                                      context,
                                    ).colorScheme.copyWith(primary: primary),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) {
                              setState(() {
                                _hastaController.text =
                                    "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                // Aplicar filtros inmediatamente cuando se selecciona una fecha
                                _buscarCuadres();
                              });
                            }
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
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Tipo de Caja',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                          style: TextStyle(color: textDark),
                          initialValue: _selectedCaja,
                          hint: Text(
                            '-- Tipo --',
                            style: TextStyle(color: textLight),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'LOCAL', child: Text('Local')),
                            DropdownMenuItem(value: 'ENVIOS', child: Text('Envíos')),
                          ],
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
                          isExpanded: true,
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
                          items: <String>['Vercy Motos', 'Administrador']
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
                          isExpanded: true,
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
              // ✅ CORRECCIÓN: Mostrar mensaje cuando no hay cuadres
              : _cuadresCaja.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No hay cuadres de caja registrados',
                        style: TextStyle(color: textLight, fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Presiona "Abrir Caja" para crear uno nuevo',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Encabezado
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          _cuadreColHeader('Fecha Inicio', flex: 2),
                          _cuadreColHeader('Fecha Fin', flex: 2),
                          _cuadreColHeader('Tipo', flex: 1),
                          _cuadreColHeader('Nombre de Caja', flex: 2),
                          _cuadreColHeader('Responsable', flex: 2),
                          _cuadreColHeader('Total Inicial', flex: 2),
                          _cuadreColHeader('Cerrada', flex: 1),
                          SizedBox(width: 80),
                        ],
                      ),
                    ),
                    // Filas paginadas — la paginación ya acota la cantidad
                    // (20/pág por defecto), así que se listan directo sin un
                    // ListView propio: todo el panel scrollea junto, incluida
                    // la franja de cajas abiertas y los filtros de arriba.
                    ...paginarLista(_cuadresCaja).asMap().entries.map((entry) {
                      final index = entry.key;
                      final cuadre = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: index.isEven
                              ? Theme.of(context).colorScheme.surface
                              : Theme.of(context).colorScheme.surface.withOpacity(0.6),
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            _cuadreCell(
                              cuadre.fechaApertura.toString().split(' ')[0],
                              flex: 2,
                            ),
                            _cuadreCell(
                              cuadre.fechaCierre?.toString().split(' ')[0] ?? 'Abierta',
                              flex: 2,
                            ),
                            Expanded(
                              flex: 1,
                              child: _TipoCajaBadge(tipoCaja: cuadre.tipoCaja),
                            ),
                            _cuadreCell(cuadre.nombre, flex: 2),
                            _cuadreCell(cuadre.responsable, flex: 2),
                            _cuadreCell(
                              formatCurrency(cuadre.fondoInicial),
                              flex: 2,
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                cuadre.cerrada ? 'Sí' : 'No',
                                style: TextStyle(
                                  color: cuadre.cerrada ? Colors.green : primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _mostrarResumenDetallado(cuadre),
                                child: const Text('Ver'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    buildPaginacion(
                      totalItems: _cuadresCaja.length,
                      accentColor: primary,
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _cuadreColHeader(String texto, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        texto,
        style: TextStyle(
          color: textDark,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _cuadreCell(String texto, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        texto,
        style: TextStyle(color: textDark, fontSize: 13),
        overflow: TextOverflow.ellipsis,
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
          if (_cajasAbiertas.length > 1) ...[
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _cajasAbiertas.map((caja) {
                final esActual = caja.id == _cuadreActual?.id;
                final esEnvios = caja.tipoCaja == 'ENVIOS';
                return InkWell(
                  onTap: () => setState(() => _cuadreActual = caja),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: esActual ? AppTheme.primaryGradient : null,
                      color: esActual ? null : cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: esActual ? Colors.transparent : textLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          esEnvios ? Icons.local_shipping : Icons.storefront,
                          size: 14,
                          color: esActual ? Colors.white : textDark,
                        ),
                        SizedBox(width: 6),
                        Text(
                          esEnvios ? 'Envíos' : 'Local',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: esActual ? Colors.white : textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
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
                    "Vercy Motos",
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
                          if (_selectedCajero != null &&
                              !_cajerosAgregados.contains(_selectedCajero)) {
                            setState(() {
                              _cajerosAgregados.add(_selectedCajero!);
                            });
                          } else if (_selectedCajero == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Seleccione un cajero primero'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Este cajero ya fue agregado'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
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
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
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
                        // Filas de cajeros agregados
                        if (_cajerosAgregados.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Sin cajeros agregados',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ..._cajerosAgregados.map(
                          (cajero) => Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade300),
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
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Quitar cajero',
                                  onPressed: () {
                                    setState(() {
                                      _cajerosAgregados.remove(cajero);
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$cajero eliminado'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
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
                        // Fila para ingreso efectivo
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("Ingreso Efectivo"),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: _ingresoEfectivoController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _totalIngresos =
                                        double.tryParse(value) ?? 0.0;
                                  });
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: IconButton(
                                icon: Icon(
                                  Icons.info_outline,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Total de ingresos de efectivo registrados en el sistema.',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                },
                                tooltip: 'Información sobre ingresos',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.blue.withOpacity(0.1),
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
                              child: Text("Tarjeta"),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: _montoTarjetaController,
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
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.payment,
                                  color: Colors.blue,
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
                              child: Text("Sistecredito"),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: _montoSistereditoController,
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
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.card_giftcard,
                                  color: Colors.orange,
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
                              child: Text("Datafono"),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: _montoDatafonoController,
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
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.contactless,
                                  color: Colors.green,
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
                    future: _cuadreCajaService.getEfectivoEsperado(tipoCaja: _cuadreActual?.tipoCaja),
                    builder: (context, snapshot) {
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
                                  color: (tieneError ? Colors.red : Colors.blue)
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        (tieneError ? Colors.red : Colors.blue)
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
                                          : Colors.blue,
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
                                            : Colors.blue,
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
                                    'Error: ${errorMessage(snapshot.error!)}',
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

          // 📊 NUEVA SECCIÓN: TOTALES POR MÉTODO DE PAGO
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
                    "💳 Totales por Método de Pago",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _cuadreCajaService.getCuadreCompleto(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: primary));
                      }
                      
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Container(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            "Error al obtener datos de métodos de pago",
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final data = snapshot.data!;
                      // 📊 Leer datos del backend: vienen en ventas.porMetodo (el
                      // backend nunca envía una clave "detalleVentas" en la raíz).
                      final ventasData = data['ventas'] as Map<String, dynamic>? ?? {};
                      final porMetodo = ventasData['porMetodo'] as Map<String, dynamic>? ?? {};
                      final detalleVentas = ventasData['ventasPorDetallePago'] as Map<String, dynamic>? ?? {};

                      double montoDe(String clave) {
                        final entry = porMetodo[clave] as Map<String, dynamic>?;
                        return ((entry?['monto']) ?? 0.0).toDouble();
                      }

                      double montoDetalle(String clave) {
                        return ((detalleVentas[clave]) ?? 0.0).toDouble();
                      }

                      final efectivo = montoDe('efectivo');
                      final transferencia = montoDe('transferencias');
                      final tarjeta = montoDe('tarjetas');
                      final sistecredito = montoDe('sistecredito');
                      final datafono = montoDe('datafono');

                      return Column(
                        children: [
                          _buildMetodoPagoRow("💵 Efectivo", efectivo, Colors.green),
                          _buildMetodoPagoRow("🏦 Transferencia", transferencia, Colors.blue),
                          _buildMetodoPagoRow("💳 Tarjeta", tarjeta, Colors.orange),
                          _buildMetodoPagoRow("🎁 Sistecredito", sistecredito, Colors.purple),
                          _buildMetodoPagoRow("📱 Datafono", datafono, Colors.teal),
                          // Desglose visual adicional por plataforma específica: no
                          // cambia los totales de arriba (son un subconjunto de
                          // Transferencia/Datafono/Sistecredito), solo se muestran
                          // las plataformas que tuvieron movimiento.
                          if (montoDetalle('nequi') > 0)
                            _buildMetodoPagoRow("   ↳ Nequi", montoDetalle('nequi'), Colors.blue),
                          if (montoDetalle('daviplata') > 0)
                            _buildMetodoPagoRow("   ↳ DaviPlata", montoDetalle('daviplata'), Colors.blue),
                          if (montoDetalle('bancolombia') > 0)
                            _buildMetodoPagoRow("   ↳ Bancolombia", montoDetalle('bancolombia'), Colors.blue),
                          if (montoDetalle('bold') > 0)
                            _buildMetodoPagoRow("   ↳ Bold", montoDetalle('bold'), Colors.teal),
                          if (montoDetalle('addi') > 0)
                            _buildMetodoPagoRow("   ↳ Addi", montoDetalle('addi'), Colors.purple),
                          if (montoDetalle('credilondon') > 0)
                            _buildMetodoPagoRow("   ↳ Credilondon", montoDetalle('credilondon'), Colors.purple),
                          Divider(color: Colors.grey.withOpacity(0.3)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "TOTAL GENERAL:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                formatCurrency(efectivo + transferencia + tarjeta + sistecredito + datafono),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          // 🔍 DEBUG: Mostrar datos raw del backend
                          if (data['debug'] == true || efectivo > 0) ...[
                            SizedBox(height: 8),
                            ExpansionTile(
                              title: Text(
                                "🔍 Datos del backend",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    "porMetodo: $porMetodo\nventasPorDetallePago: $detalleVentas",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
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

  // 🎨 Helper widget para mostrar filas de métodos de pago  
  Widget _buildMetodoPagoRow(String metodo, double monto, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                metodo,
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Text(
            formatCurrency(monto),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipoCajaBadge extends StatelessWidget {
  final String tipoCaja;

  const _TipoCajaBadge({required this.tipoCaja});

  @override
  Widget build(BuildContext context) {
    final esEnvios = tipoCaja == 'ENVIOS';
    final color = esEnvios ? AppTheme.secondary : AppTheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esEnvios ? Icons.local_shipping : Icons.storefront,
            size: 12,
            color: color,
          ),
          SizedBox(width: 3),
          Flexible(
            child: Text(
              esEnvios ? 'Envíos' : 'Local',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
