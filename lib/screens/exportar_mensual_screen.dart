import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import '../services/estadisticas_mensuales_service.dart';
import '../services/excel_export_service.dart';
import '../providers/user_provider.dart';

class ExportarMensualScreen extends StatefulWidget {
  const ExportarMensualScreen({super.key});

  @override
  State<ExportarMensualScreen> createState() => _ExportarMensualScreenState();
}

class _ExportarMensualScreenState extends State<ExportarMensualScreen> {
  final EstadisticasMensualesService _estadisticasService =
      EstadisticasMensualesService();

  DateTime _fechaSeleccionada = DateTime.now();
  bool _isLoading = false;
  bool _isExporting = false;
  Map<String, dynamic>? _datosPreview;

  @override
  void initState() {
    super.initState();
    // Inicializar formato de fecha para español
    initializeDateFormatting('es_ES', null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportar Estadísticas Mensuales'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildSelectorFecha(),
            const SizedBox(height: 16),
            _buildBotonesAccion(),
            const SizedBox(height: 16),
            if (_datosPreview != null) _buildPreviewCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.file_download,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Exportación Mensual a Excel',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Exporta todas las estadísticas de un mes específico en un archivo Excel completo.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El archivo incluirá: Resumen, Ventas, Gastos, Facturas, Top Productos y Cuadres de Caja.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
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

  Widget _buildSelectorFecha() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleccionar Mes y Año',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _mostrarSelectorFecha,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat(
                              'MMMM yyyy',
                              'es_ES',
                            ).format(_fechaSeleccionada),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Mes seleccionado: ${DateFormat('MM/yyyy').format(_fechaSeleccionada)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonesAccion() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Botón Preview
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _cargarPreview,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.preview),
                label: Text(
                  _isLoading
                      ? 'Cargando datos del servidor...'
                      : 'Cargar Vista Previa',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                  disabledForegroundColor: Colors.white,
                ),
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Esto puede tardar hasta 2 minutos...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // Botón Exportar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (_isExporting ||
                        !ExcelExportService.hayDatosEstadisticasParaExportar(
                          _datosPreview,
                        ))
                    ? null
                    : _exportarAExcel,
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  _isExporting ? 'Generando Excel...' : 'Exportar a Excel',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final periodoInfo = _datosPreview!['periodoInfo'] as Map<String, dynamic>;
    final resumenVentas =
        _datosPreview!['resumenVentas'] as Map<String, dynamic>;
    final resumenGastos =
        _datosPreview!['resumenGastos'] as Map<String, dynamic>;
    final resumenFinanciero =
        _datosPreview!['resumenFinanciero'] as Map<String, dynamic>;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Vista Previa de Datos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Período
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Período: ${periodoInfo['mes']}/${periodoInfo['año']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Exportación: ${_formatearFecha(periodoInfo['fechaExportacion'])}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Resumen de datos
            Row(
              children: [
                Expanded(
                  child: _buildEstadisticaItem(
                    'Ventas',
                    '\$${_formatearMonto(resumenVentas['totalVentas'])}',
                    '${resumenVentas['pedidosPagados']} pedidos',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEstadisticaItem(
                    'Gastos',
                    '\$${_formatearMonto(resumenGastos['totalGastos'])}',
                    '${resumenGastos['cantidadGastos']} registros',
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Utilidad
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Utilidad Neta:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${_formatearMonto(resumenFinanciero['utilidadNeta'])}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (resumenFinanciero['utilidadNeta'] as double) >= 0
                          ? Colors.green
                          : Colors.red,
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

  Widget _buildEstadisticaItem(
    String titulo,
    String valor,
    String detalle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            detalle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _mostrarSelectorFecha() async {
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      selectableDayPredicate: (DateTime date) {
        // Solo permitir seleccionar el primer día del mes
        return date.day == 1;
      },
      helpText: 'Seleccionar mes y año',
      fieldLabelText: 'Mes/Año',
    );

    if (fechaSeleccionada != null) {
      setState(() {
        _fechaSeleccionada = DateTime(
          fechaSeleccionada.year,
          fechaSeleccionada.month,
          1,
        );
        _datosPreview = null;
      });
    }
  }

  Future<void> _cargarPreview() async {
    setState(() {
      _isLoading = true;
      _datosPreview = null; // Limpiar datos previos
    });

    try {
      print(
        'INFO: Iniciando carga de preview - ${_fechaSeleccionada.month}/${_fechaSeleccionada.year}',
      );
      
      final datos = await _estadisticasService.exportarEstadisticasMensuales(
        _fechaSeleccionada.year,
        _fechaSeleccionada.month,
      );

      print('INFO: Datos recibidos exitosamente');
      print('INFO: Claves en datos: ${datos.keys.toList()}');

      setState(() {
        _datosPreview = datos;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Vista previa cargada exitosamente')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('ERROR: Error al cargar preview: $e');
      
      if (mounted) {
        // Determinar mensaje de error específico
        String errorMsg = 'Error al cargar preview';
        if (e.toString().contains('timeout') ||
            e.toString().contains('Timeout')) {
          errorMsg =
              'El servidor tardó demasiado. Intenta con un rango de fechas menor.';
        } else if (e.toString().contains('No autorizado') ||
            e.toString().contains('401')) {
          errorMsg = 'Sesión expirada. Vuelve a iniciar sesión.';
        } else if (e.toString().contains('Sin conexión') ||
            e.toString().contains('SocketException')) {
          errorMsg = 'Sin conexión a internet. Verifica tu red.';
        } else {
          errorMsg = 'Error: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: _cargarPreview,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportarAExcel() async {
    if (!ExcelExportService.hayDatosEstadisticasParaExportar(_datosPreview)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay datos para exportar. Carga la vista previa primero.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar diálogo de opciones de exportación
    final resultado = await _mostrarDialogoExportacion();
    if (resultado == null) return;

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 20),
                const Text('Generando Excel...'),
              ],
            ),
          ),
        );
      },
    );

    setState(() {
      _isExporting = true;
    });

    try {
      // Obtener información del usuario
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      String? nombreUsuario = userProvider.userName;

      // Exportar archivo
      String? filePath = await ExcelExportService.exportarEstadisticasMensuales(
        datosEstadisticas: _datosPreview!,
        nombreUsuario: nombreUsuario,
        observaciones: resultado['observaciones'],
      );

      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      if (filePath != null) {
        // Mostrar opciones de éxito
        _mostrarDialogoExitoExportacion(
          filePath,
          resultado['compartir'] ?? false,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al generar el archivo Excel'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _mostrarDialogoExportacion() async {
    String observaciones = '';
    bool compartir = false;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Opciones de Exportación'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Observaciones (opcional):'),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (value) => observaciones = value,
                    decoration: const InputDecoration(
                      hintText: 'Agregar comentarios al archivo...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Compartir automáticamente'),
                    subtitle: const Text(
                      'Abrir opciones para compartir el archivo',
                    ),
                    value: compartir,
                    onChanged: (value) {
                      setState(() {
                        compartir = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop({
                    'observaciones': observaciones,
                    'compartir': compartir,
                  }),
                  child: const Text('Exportar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoExitoExportacion(
    String filePath,
    bool compartirAutomaticamente,
  ) {
    final isWeb = filePath.startsWith('web_download:');
    final fileName = isWeb
        ? filePath.replaceFirst('web_download:', '')
        : filePath.split('/').last;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Excel Generado'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isWeb
                    ? '¡Archivo descargado exitosamente! Verifica tu carpeta de descargas.'
                    : 'El archivo Excel se ha generado exitosamente.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      isWeb ? Icons.download_done : Icons.folder,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (isWeb) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El archivo se descargó en tu carpeta de Descargas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            if (!isWeb)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ExcelExportService.compartirExcel(filePath);
                },
                child: const Text('Compartir'),
              ),
          ],
        );
      },
    );

    // Compartir automáticamente si se seleccionó la opción (solo en móvil)
    if (compartirAutomaticamente && !isWeb) {
      Future.delayed(const Duration(milliseconds: 500), () {
        ExcelExportService.compartirExcel(filePath);
      });
    }
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) return 'N/A';
    try {
      if (fecha is String) {
        final dateTime = DateTime.parse(fecha);
        return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      }
      return fecha.toString();
    } catch (e) {
      return fecha.toString();
    }
  }

  String _formatearMonto(dynamic monto) {
    if (monto == null) return '0';
    try {
      final valor = double.parse(monto.toString());
      return NumberFormat('#,##0').format(valor);
    } catch (e) {
      return monto.toString();
    }
  }
}
