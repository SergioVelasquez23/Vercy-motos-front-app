import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/denominacion_efectivo.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../services/excel_export_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class ContadorEfectivoScreen extends StatefulWidget {
  final Function(double)?
  onTotalCalculado; // Callback para pasar el total calculado
  final double? montoInicial; // Monto inicial si se quiere precargar

  const ContadorEfectivoScreen({
    super.key,
    this.onTotalCalculado,
    this.montoInicial,
  });

  @override
  _ContadorEfectivoScreenState createState() => _ContadorEfectivoScreenState();
}

class _ContadorEfectivoScreenState extends State<ContadorEfectivoScreen> {
  // Getters para compatibilidad temporal con AppTheme
  Color get primary => AppTheme.primary;
  Color get bgDark => AppTheme.backgroundDark;
  Color get cardBg => AppTheme.cardBg;
  Color get textDark => AppTheme.textDark;
  Color get textLight => AppTheme.textLight;

  // Lista de denominaciones
  List<DenominacionEfectivo> _denominaciones = [];

  // Controladores de texto para cada denominación
  Map<int, TextEditingController> _controllers = {};

  // Totales calculados
  double _totalBilletes = 0.0;
  double _totalMonedas = 0.0;
  double _totalGeneral = 0.0;

  @override
  void initState() {
    super.initState();
    _inicializarDenominaciones();
  }

  @override
  void dispose() {
    // Limpiar controladores
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _inicializarDenominaciones() {
    _denominaciones = ContadorEfectivo.obtenerDenominacionesStandard();

    // Crear controladores para cada denominación
    for (var denominacion in _denominaciones) {
      _controllers[denominacion.valor] = TextEditingController(text: '0');
      _controllers[denominacion.valor]!.addListener(() => _calcularTotales());
    }

    _calcularTotales();
  }

  void _calcularTotales() {
    setState(() {
      // Actualizar cantidades desde los controladores
      for (var denominacion in _denominaciones) {
        final controller = _controllers[denominacion.valor]!;
        denominacion.cantidad = int.tryParse(controller.text) ?? 0;
      }

      // Calcular totales
      final totales = ContadorEfectivo.obtenerTotalesPorTipo(_denominaciones);
      _totalBilletes = totales['billetes']!;
      _totalMonedas = totales['monedas']!;
      _totalGeneral = totales['total']!;
    });
  }

  void _resetearContador() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: Text('Confirmar', style: TextStyle(color: textDark)),
          content: Text(
            '¿Estás seguro de que quieres resetear todos los valores?',
            style: TextStyle(color: textLight),
          ),
          actions: [
            TextButton(
              child: Text('Cancelar', style: TextStyle(color: textLight)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Resetear', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  for (var controller in _controllers.values) {
                    controller.text = '0';
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }

  // Función removida: _usarTotal ya no es necesaria
  // Solo se usa exportar a Excel

  Future<void> _exportarAExcel() async {
    if (!ExcelExportService.hayDatosParaExportar(_denominaciones)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay datos para exportar. Ingresa al menos una cantidad.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar diálogo de opciones de exportación
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) => _buildExportDialog(),
    );

    if (resultado == null) return;

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primary),
                SizedBox(width: 20),
                Text('Generando Excel...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Obtener información del usuario
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      String? nombreUsuario = userProvider.userName;

      // Exportar archivo
      String? filePath = await ExcelExportService.exportarContadorEfectivo(
        denominaciones: _denominaciones,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar el archivo Excel'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Cerrar diálogo de carga si hay error
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildExportDialog() {
    final TextEditingController observacionesController =
        TextEditingController();
    bool compartir = true;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.file_download, color: primary, size: 28),
              SizedBox(width: 8),
              Text(
                'Exportar a Excel',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Observaciones (opcional):',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: observacionesController,
                  decoration: InputDecoration(
                    hintText: 'Agregar notas o comentarios...',
                    hintStyle: TextStyle(color: textLight),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primary),
                    ),
                  ),
                  style: TextStyle(color: textDark),
                  maxLines: 3,
                  maxLength: 200,
                ),
                SizedBox(height: 16),
                CheckboxListTile(
                  title: Text(
                    'Compartir archivo inmediatamente',
                    style: TextStyle(color: textDark),
                  ),
                  subtitle: Text(
                    'El archivo se guardará y se abrirá el menú de compartir',
                    style: TextStyle(color: textLight, fontSize: 12),
                  ),
                  value: compartir,
                  onChanged: (value) {
                    setState(() {
                      compartir = value ?? true;
                    });
                  },
                  activeColor: primary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar', style: TextStyle(color: textLight)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop({
                  'observaciones': observacionesController.text.trim(),
                  'compartir': compartir,
                });
              },
              icon: Icon(Icons.download, color: Colors.white, size: 20),
              label: Text(
                'Exportar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoExitoExportacion(String filePath, bool autoCompartir) {
    if (autoCompartir) {
      // Compartir automáticamente
      ExcelExportService.compartirExcel(filePath).then((exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exito
                  ? 'Excel generado y compartido exitosamente'
                  : 'Excel generado. Error al compartir automáticamente.',
            ),
            backgroundColor: exito ? Colors.green : Colors.orange,
            action: !exito
                ? SnackBarAction(
                    label: 'Compartir',
                    onPressed: () =>
                        ExcelExportService.compartirExcel(filePath),
                  )
                : null,
          ),
        );
      });
    } else {
      // Mostrar diálogo con opciones
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text(
                  '¡Éxito!',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'El archivo Excel se ha generado correctamente.',
                  style: TextStyle(color: textDark),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder, color: primary, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          filePath.split('/').last,
                          style: TextStyle(color: textDark, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cerrar', style: TextStyle(color: textLight)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  ExcelExportService.compartirExcel(filePath);
                },
                icon: Icon(Icons.share, color: Colors.white, size: 20),
                label: Text('Compartir', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: Text(
          'Contador de Efectivo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.file_download, color: Colors.white),
            onPressed: ExcelExportService.hayDatosParaExportar(_denominaciones)
                ? _exportarAExcel
                : null,
            tooltip: 'Exportar a Excel',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetearContador,
            tooltip: 'Resetear contador',
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel de totales
          _buildTotalesPanel(),

          // Lista de denominaciones
          Expanded(child: _buildListaDenominaciones()),

          // Botones de acción
          _buildBotonesAccion(),
        ],
      ),
    );
  }

  Widget _buildTotalesPanel() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total general destacado
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL GENERAL',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                Text(
                  formatCurrency(_totalGeneral),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Subtotales
          Row(
            children: [
              Expanded(
                child: _buildSubtotalCard(
                  'Billetes',
                  _totalBilletes,
                  Icons.money,
                  Colors.green,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildSubtotalCard(
                  'Monedas',
                  _totalMonedas,
                  Icons.monetization_on,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubtotalCard(
    String titulo,
    double total,
    IconData icono,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            titulo,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            formatCurrency(total),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaDenominaciones() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: _denominaciones.length,
      itemBuilder: (context, index) {
        final denominacion = _denominaciones[index];
        final esBillete = denominacion.tipo == 'billete';

        return Card(
          color: cardBg,
          margin: EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Icono y denominación
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: esBillete
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: esBillete
                          ? Colors.green.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        esBillete ? Icons.money : Icons.monetization_on,
                        color: esBillete ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      Text(
                        denominacion.valorFormateado,
                        style: TextStyle(
                          color: esBillete ? Colors.green : Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 16),

                // Campo de cantidad
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${denominacion.valorFormateado} ${esBillete ? 'COP' : 'COP'}',
                        style: TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      TextField(
                        controller: _controllers[denominacion.valor],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(color: textDark, fontSize: 18),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: textLight),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: primary, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 16),

                // Total por denominación
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(color: textLight, fontSize: 12),
                      ),
                      Text(
                        formatCurrency(denominacion.total),
                        style: TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBotonesAccion() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primera fila: Resetear y Exportar Excel
          Row(
            children: [
              // Botón resetear
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.refresh, color: Colors.orange),
                  label: Text(
                    'Resetear',
                    style: TextStyle(color: Colors.orange),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.orange),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _resetearContador,
                ),
              ),

              SizedBox(width: 12),

              // Botón exportar Excel
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.file_download, color: Colors.blue),
                  label: Text('Excel', style: TextStyle(color: Colors.blue)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed:
                      ExcelExportService.hayDatosParaExportar(_denominaciones)
                      ? _exportarAExcel
                      : null,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Solo mostrar botón de exportar Excel
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.file_download, color: Colors.white),
              label: Text(
                'Exportar a Excel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed:
                  ExcelExportService.hayDatosParaExportar(_denominaciones)
                  ? _exportarAExcel
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
