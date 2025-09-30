import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final ApiConfig _apiConfig = ApiConfig.instance;
  bool _isLoading = false;
  String? _lastResult;
  Map<String, dynamic>? _stats;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _incluirFacturas = false;

  String get baseUrl => _apiConfig.baseUrl;
  Map<String, String> get headers => _apiConfig.getSecureHeaders();

  @override
  void initState() {
    super.initState();
    _loadStats();
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

  String _formatConteoResult(Map<String, dynamic> data) {
    final conteos = data['conteos'] as Map<String, dynamic>;
    final buffer = StringBuffer();
    buffer.writeln('CONTEO DE REGISTROS');
    buffer.writeln(
      'Período: ${formatDate(DateTime.parse(data['fechaInicio']))} - ${formatDate(DateTime.parse(data['fechaFin']))}',
    );
    buffer.writeln('');

    conteos.forEach((key, value) {
      buffer.writeln('• $key: $value');
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
      buffer.writeln('• $key: $value eliminados');
    });

    buffer.writeln('');
    buffer.writeln('TOTAL ELIMINADO: ${data['totalEliminado']} registros');

    return buffer.toString();
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardBg,
            title: Text(title, style: TextStyle(color: AppTheme.textPrimary)),
            content: Text(
              content,
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: AppTheme.textSecondary),
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

  Widget _buildStatsCard() {
    if (_stats == null) return SizedBox.shrink();

    final counts = _stats!['collectionCounts'] as Map<String, dynamic>;

    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas de Base de Datos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 12),
            ...counts.entries.map(
              (entry) => Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
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
    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📅 Seleccionar Rango de Fechas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text(
                      'Fecha Inicio',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      _fechaInicio != null
                          ? formatDate(_fechaInicio!)
                          : 'No seleccionada',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    trailing: Icon(
                      Icons.calendar_today,
                      color: AppTheme.accent,
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate:
                            _fechaInicio ??
                            DateTime.now().subtract(Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _fechaInicio = date);
                      }
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ListTile(
                    title: Text(
                      'Fecha Fin',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      _fechaFin != null
                          ? formatDate(_fechaFin!)
                          : 'No seleccionada',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    trailing: Icon(
                      Icons.calendar_today,
                      color: AppTheme.accent,
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _fechaFin ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _fechaFin = date);
                      }
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            CheckboxListTile(
              title: Text(
                'Incluir facturas en eliminación',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              value: _incluirFacturas,
              onChanged: (value) =>
                  setState(() => _incluirFacturas = value ?? false),
              activeColor: AppTheme.accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🛠️ Acciones Administrativas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 16),

            // Botones de acción general
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _loadStats,
                    icon: Icon(Icons.refresh),
                    label: Text('Actualizar Stats'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _resetMesas,
                    icon: Icon(Icons.table_restaurant),
                    label: Text('Resetear Mesas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Botones de eliminación por fechas
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _contarPorFechas,
                    icon: Icon(Icons.analytics),
                    label: Text('Contar por Fechas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _eliminarPorFechas,
                    icon: Icon(Icons.delete_forever),
                    label: Text('Eliminar por Fechas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Botón de eliminación total
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _clearAllData,
                icon: Icon(Icons.warning),
                label: Text('ELIMINAR TODOS LOS DATOS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_lastResult == null) return SizedBox.shrink();

    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📋 Último Resultado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Text(
                _lastResult!,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 12,
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
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          '🔧 Panel de Administración',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red[900],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.accent),
                  SizedBox(height: 16),
                  Text(
                    'Procesando...',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatsCard(),
                  SizedBox(height: 16),
                  _buildDateRangeSelector(),
                  SizedBox(height: 16),
                  _buildActionButtons(),
                  SizedBox(height: 16),
                  _buildResultCard(),
                ],
              ),
            ),
    );
  }
}
