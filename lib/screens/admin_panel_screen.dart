import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../services/pedido_service.dart';
import '../services/reportes_service.dart';
import '../models/dashboard_data.dart';
import 'exportar_mensual_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final ApiConfig _apiConfig = ApiConfig.instance;
  final ReportesService _reportesService = ReportesService();
  bool _isLoading = false;
  String? _lastResult;
  Map<String, dynamic>? _stats;
  DashboardData? _dashboardTotal;
  bool _isLoadingDashboard = false;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _incluirFacturas = false;

  String get baseUrl => _apiConfig.baseUrl;
  Map<String, String> get headers => _apiConfig.getSecureHeaders();

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadDashboardTotal();
  }

  Future<void> _loadDashboardTotal() async {
    setState(() => _isLoadingDashboard = true);
    try {
      final data = await _reportesService.getDashboard(
        forceRefresh: true,
        soloElectronicos: false,
      );
      if (mounted) setState(() => _dashboardTotal = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingDashboard = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _stats = data);
      }
    } catch (e) {
      _showError('Error cargando estadísticas: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await _showConfirmDialog(
      ' ELIMINAR TODOS LOS DATOS',
      'Esto eliminará TODOS los pedidos, facturas, documentos, cuadres, gastos e ingresos.\n\n'
          ' Esta operación NO se puede deshacer.\n\n'
          '¿Estás completamente seguro?',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/clear-data'),
        headers: headers,
      );

      final data = json.decode(response.body);
      if (data['success']) {
        _showSuccess('Accion realizada');
        setState(() => _lastResult = json.encode(data['deletedCounts']));
        await _loadStats();
      } else {
        _showError('Error: ${data['message']}');
      }
    } catch (e) {
      _showError('Error eliminando datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetMesas() async {
    final confirmed = await _showConfirmDialog(
      'RESETEAR MESAS',
      'Esto reseteará el estado de todas las mesas (las marcará como libres y limpiará sus datos).\n\n'
          '¿Continuar?',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/reset-mesas'),
        headers: headers,
      );

      final data = json.decode(response.body);
      if (data['success']) {
        _showSuccess('Accion realizada');
      } else {
        _showError('Error: ${data['message']}');
      }
    } catch (e) {
      _showError('Error reseteando mesas: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _contarPorFechas() async {
    if (_fechaInicio == null || _fechaFin == null) {
      _showError('Selecciona ambas fechas primero');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('$baseUrl/api/admin/contar-por-fechas').replace(
        queryParameters: {
          'fechaInicio': _fechaInicio!.toIso8601String(),
          'fechaFin': _fechaFin!.toIso8601String(),
        },
      );

      final response = await http.get(url, headers: headers);
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() => _lastResult = _formatConteoResult(data));
        _showSuccess('Accion realizada');
      } else {
        _showError('Error: ${data['message']}');
      }
    } catch (e) {
      _showError('Error contando registros: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarPorFechas() async {
    if (_fechaInicio == null || _fechaFin == null) {
      _showError('Selecciona ambas fechas primero');
      return;
    }

    final confirmed = await _showConfirmDialog(
      'ELIMINAR POR FECHAS',
      'Esto eliminará TODOS los registros entre:\n'
          ' ${formatDate(_fechaInicio!)} y ${formatDate(_fechaFin!)}\n\n'
          'Incluir facturas: ${_incluirFacturas ? "SÍ" : "NO"}\n\n'
          'Esta operación NO se puede deshacer.\n\n'
          '¿Estás completamente seguro?',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('$baseUrl/api/admin/eliminar-todo-por-fechas')
          .replace(
            queryParameters: {
              'fechaInicio': _fechaInicio!.toIso8601String(),
              'fechaFin': _fechaFin!.toIso8601String(),
              'incluirFacturas': _incluirFacturas.toString(),
            },
          );

      final response = await http.delete(url, headers: headers);
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() => _lastResult = _formatEliminacionResult(data));
        _showSuccess('Accion realizada');
        await _loadStats();
      } else {
        _showError('Error: ${data['message']}');
      }
    } catch (e) {
      _showError('Error eliminando registros: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Nueva función para eliminar pedido específico
  Future<void> _eliminarPedidoEspecifico() async {
    String? pedidoId;

    // Mostrar diálogo para ingresar ID del pedido
    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Eliminar Pedido Específico',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa el ID del pedido que deseas eliminar:\n\n'
                'ADVERTENCIA: Esto eliminará el pedido incluso si está pagado.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'ID del pedido',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                pedidoId = controller.text.trim();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (pedidoId == null || pedidoId!.isEmpty) return;

    // Confirmar eliminación
    final confirmed = await _showConfirmDialog(
      'ELIMINAR PEDIDO',
      'ID del pedido: $pedidoId\n\n'
          'Esta acción eliminará el pedido permanentemente,\n'
          'incluso si está pagado o facturado.\n\n'
          '¿Estás seguro?',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      // Importar el servicio de pedidos
      final pedidoService = PedidoService();

      // Intentar eliminación forzada
      await pedidoService.eliminarPedidoForzado(pedidoId!);

      _showSuccess('Pedido $pedidoId eliminado exitosamente');
      setState(() => _lastResult = 'Pedido eliminado: $pedidoId');
      await _loadStats();
    } catch (e) {
      _showError('Error eliminando pedido: $e');
        
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // NUEVA: Función para eliminar TODOS los pedidos activos
  Future<void> _eliminarTodosPedidosActivos() async {
    final confirmed = await _showConfirmDialog(
      'ELIMINAR TODOS LOS PEDIDOS ACTIVOS',
      'Esto eliminará ABSOLUTAMENTE TODOS los pedidos activos sin importar:\n'
          '- Su estado (activo, pagado, completado, etc.)\n'
          '- Su método de pago (efectivo, tarjeta, transferencia)\n'
          '- Su mesa (incluye domicilios y mesas especiales)\n\n'
          'Esta operación NO se puede deshacer.\n\n'
          '¿Estás COMPLETAMENTE seguro?',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      // Usar el servicio PedidoService para la eliminación
      final pedidoService = PedidoService();
      final result = await pedidoService.eliminarTodosPedidosActivos();

      if (result['success'] == true) {
        int deletedCount = 0;
        if (result.containsKey('deletedCount')) {
          deletedCount = result['deletedCount'] ?? 0;
        }

        _showSuccess(
          'Todos los pedidos activos eliminados${deletedCount > 0 ? ': $deletedCount pedidos' : ''}',
        );

        setState(
          () => _lastResult =
              'Pedidos eliminados${deletedCount > 0 ? ': $deletedCount' : ' correctamente'}',
        );

        // Recargar estadísticas
        await _loadStats();
      } else {
        _showError('Error: ${result['message'] ?? 'Operación fallida'}');
      }
    } catch (e) {
      _showError('Error eliminando pedidos activos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatConteoResult(Map<String, dynamic> data) {
    final conteos = data['conteos'] as Map<String, dynamic>;
    final buffer = StringBuffer();
    buffer.writeln('CONTEO DE REGISTROS');
    buffer.writeln(
      'Período: ${formatDate(DateTime.parse(data['fechaInicio']))} - ${formatDate(DateTime.parse(data['fechaFin']))}',
    );
    buffer.writeln('');

    conteos.forEach((key, value) {
      buffer.writeln('- $key: $value');
    });

    buffer.writeln('');
    buffer.writeln('TOTAL: ${data['totalRegistros']} registros');

    return buffer.toString();
  }

  String _formatEliminacionResult(Map<String, dynamic> data) {
    final eliminados = data['eliminados'] as Map<String, dynamic>;
    final buffer = StringBuffer();
    buffer.writeln('ELIMINACIÓN COMPLETADA');
    buffer.writeln(
      'Período: ${formatDate(DateTime.parse(data['fechaInicio']))} - ${formatDate(DateTime.parse(data['fechaFin']))}',
    );
    buffer.writeln('Incluir facturas: ${data['incluirFacturas']}');
    buffer.writeln('');

    eliminados.forEach((key, value) {
      buffer.writeln('- $key: $value eliminados');
    });

    buffer.writeln('');
    buffer.writeln('TOTAL ELIMINADO: ${data['totalEliminado']} registros');

    return buffer.toString();
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            content: Text(
              content,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Confirmar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
  }

  Widget _buildMetricasTotales() {
    final d = _dashboardTotal;

    Widget card(String titulo, Color color, double? valor) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              _isLoadingDashboard
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: color),
                    )
                  : Text(
                      valor != null ? '\$${formatNumberWithDots(valor)}' : '—',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bar_chart, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ventas Totales',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'LOCAL + POS + Factura Electrónica',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  color: AppTheme.secondary,
                  tooltip: 'Actualizar',
                  onPressed: _isLoadingDashboard ? null : _loadDashboardTotal,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(children: [
              card('Hoy', AppTheme.primary, d?.ventasHoy.total),
              const SizedBox(width: 10),
              card('7 días', AppTheme.secondary, d?.ventas7Dias.total),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              card('30 días', AppTheme.info, d?.ventas30Dias.total),
              const SizedBox(width: 10),
              card('Año actual', AppTheme.success, d?.ventasAnio.total),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_stats == null) return SizedBox.shrink();

    final counts = _stats!['collectionCounts'] as Map<String, dynamic>;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.analytics_outlined, color: Colors.white, size: 22),
                ),
                SizedBox(width: 12),
                Text(
                  'Estadísticas de Base de Datos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ...counts.entries.map(
              (entry) => Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.date_range, color: Colors.white, size: 22),
                ),
                SizedBox(width: 12),
                Text(
                  'Seleccionar Rango de Fechas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildDateSelector(
                    'Fecha Inicio',
                    _fechaInicio,
                    Icons.calendar_month,
                    () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _fechaInicio ?? DateTime.now().subtract(Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: AppTheme.primary,
                                surface: Theme.of(context).colorScheme.surface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() => _fechaInicio = date);
                      }
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildDateSelector(
                    'Fecha Fin',
                    _fechaFin,
                    Icons.event,
                    () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _fechaFin ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: AppTheme.primary,
                                surface: Theme.of(context).colorScheme.surface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() => _fechaFin = date);
                      }
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CheckboxListTile(
                title: Text(
                  'Incluir facturas en eliminación',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                ),
                value: _incluirFacturas,
                onChanged: (value) => setState(() => _incluirFacturas = value ?? false),
                activeColor: AppTheme.secondary,
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime? date, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: date != null ? AppTheme.primary.withOpacity(0.5) : Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: date != null ? AppTheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    date != null ? formatDate(date) : 'No seleccionada',
                    style: TextStyle(
                      color: date != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.warning, AppTheme.warning.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.build_outlined, color: Colors.white, size: 22),
                ),
                SizedBox(width: 12),
                Text(
                  'Acciones Administrativas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Botones de acción general
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.refresh,
                    label: 'Actualizar Stats',
                    color: AppTheme.primary,
                    onPressed: _isLoading ? null : _loadStats,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.table_restaurant,
                    label: 'Resetear Mesas',
                    color: AppTheme.secondary,
                    onPressed: _isLoading ? null : _resetMesas,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Botón de estadísticas mensuales
            _buildActionButton(
              icon: Icons.file_download_outlined,
              label: 'Exportar Estadísticas Mensuales',
              color: AppTheme.info,
              onPressed: _isLoading ? null : _navegarAEstadisticasMensuales,
              isFullWidth: true,
            ),

            SizedBox(height: 12),

            // Botones de eliminación por fechas
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.analytics_outlined,
                    label: 'Contar por Fechas',
                    color: AppTheme.metal,
                    onPressed: _isLoading ? null : _contarPorFechas,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.delete_forever_outlined,
                    label: 'Eliminar por Fechas',
                    color: AppTheme.warning,
                    onPressed: _isLoading ? null : _eliminarPorFechas,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),
            Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2)),
            SizedBox(height: 12),

            // Zona de peligro
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 18),
                SizedBox(width: 8),
                Text(
                  'Zona de Peligro',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.error,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Botón para eliminar TODOS los pedidos activos
            _buildDangerButton(
              icon: Icons.delete_sweep,
              label: 'ELIMINAR TODOS LOS PEDIDOS ACTIVOS',
              onPressed: _isLoading ? null : _eliminarTodosPedidosActivos,
            ),

            SizedBox(height: 10),

            // Botón para eliminar pedido específico
            _buildDangerButton(
              icon: Icons.delete_outline,
              label: 'Eliminar Pedido Específico',
              onPressed: _isLoading ? null : _eliminarPedidoEspecifico,
              isSecondary: true,
            ),

            SizedBox(height: 10),

            // Botón de eliminación total
            _buildDangerButton(
              icon: Icons.warning_rounded,
              label: 'ELIMINAR TODOS LOS DATOS',
              onPressed: _isLoading ? null : _clearAllData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    bool isSecondary = false,
  }) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? Theme.of(context).colorScheme.surface : AppTheme.error.withOpacity(0.15),
          foregroundColor: AppTheme.error,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: AppTheme.error.withOpacity(0.3)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_lastResult == null) return SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.check_circle_outline, color: AppTheme.success, size: 22),
                ),
                SizedBox(width: 12),
                Text(
                  'Último Resultado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.success.withOpacity(0.2)),
              ),
              child: SelectableText(
                _lastResult!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
            ),
            SizedBox(width: 10),
            Text(
              'Panel de Administración',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB71C1C), Color(0xFF880E4F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.close, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Procesando...',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildMetricasTotales(),
                  SizedBox(height: 16),
                  _buildStatsCard(),
                  SizedBox(height: 16),
                  _buildDateRangeSelector(),
                  SizedBox(height: 16),
                  _buildActionButtons(),
                  SizedBox(height: 16),
                  _buildResultCard(),
                  SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  void _navegarAEstadisticasMensuales() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ExportarMensualScreen()),
    );
  }
}
