import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/mesa.dart';
import '../models/pedido.dart';
import '../models/item_pedido.dart';
import '../models/documento_mesa.dart';
import '../services/pedido_service.dart';
import '../services/mesa_service.dart';
import '../services/documento_mesa_service.dart';
import '../services/documento_automatico_service.dart';
import '../services/impresion_service.dart';
import '../services/notification_service.dart';
import '../providers/user_provider.dart';
import '../utils/format_utils.dart';
import '../utils/impresion_mixin.dart';
import '../widgets/pago_parcial_dialog.dart';
import '../widgets/cancelar_producto_dialog.dart';
import '../widgets/mover_productos_dialog.dart';
import 'pedido_screen.dart';
import 'documentos_mesa_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import '../services/pdf_service_factory.dart';

class MesasScreen extends StatefulWidget {
  const MesasScreen({super.key});

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> with ImpresionMixin {
  final MesaService _mesaService = MesaService();
  final PedidoService _pedidoService = PedidoService();
  final DocumentoMesaService _documentoMesaService = DocumentoMesaService();
  final DocumentoAutomaticoService _documentoAutomaticoService =
      DocumentoAutomaticoService();

  final ImpresionService _impresionService = ImpresionService();
  List<Mesa> mesas = [];
  bool isLoading = true;
  String? errorMessage;

  // Subscripciones para actualizaciones en tiempo real
  late StreamSubscription<bool> _pedidoCompletadoSubscription;
  late StreamSubscription<bool> _pedidoPagadoSubscription;

  // Paleta de colores mejorada
  static const _backgroundDark = Color(0xFF1A1A1A);
  static const _surfaceDark = Color(0xFF2A2A2A);
  static const _cardBg = Color(0xFF313131);
  static const _cardElevated = Color(0xFF3A3A3A);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFFB0B0B0);
  static const _textMuted = Color(0xFF808080);
  static const _primary = Color(0xFFFF6B00);
  static const _primaryLight = Color(0xFFFF8F3D);
  static const _primaryDark = Color(0xFFE55A00);
  static const _success = Color(0xFF4CAF50);
  static const _warning = Color(0xFFFF9800);
  static const _error = Color(0xFFF44336);
  static const _accent = Color(0xFF03DAC6);

  // Banderas para evitar procesamiento múltiple
  bool _procesandoPago = false;

  // Control de zoom para móviles
  double _zoomScale = 1.0;

  /// Método para resetear manualmente el flag de procesamiento
  /// Útil para casos donde el sistema se quede colgado
  void _resetearFlagProcesamiento() {
    if (mounted) {
      setState(() {
        _procesandoPago = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flag de procesamiento reseteado'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Método para enviar documento al servidor
  Future<void> _enviarDocumentoAlServidor(
    Map<String, dynamic> documento,
  ) async {
    try {
      print('📤 Enviando documento al servidor...');
      // Implementación básica - agregar lógica según necesidades
      await Future.delayed(Duration(milliseconds: 500)); // Simular envío
    } catch (e) {
      print('❌ Error enviando documento: $e');
      throw Exception('Error enviando documento: $e');
    }
  }

  // Método para construir sección de título
  Widget _buildSeccionTitulo(String titulo) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary.withOpacity(0.15), _primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        titulo,
        style: TextStyle(
          color: _primary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Método para construir fila de información
  Widget _buildInfoRow(IconData icono, String etiqueta, String valor) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceDark.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _textMuted.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icono, size: 14, color: _primary),
          ),
          SizedBox(width: 12),
          Text(
            '$etiqueta: ',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método auxiliar para construir sección de resumen
  Widget _buildSeccionResumen(String titulo, List<String> items) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _primary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          SizedBox(height: 12),
          ...items.map(
            (item) => Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _surfaceDark.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 13,
                  color: _textPrimary,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Crea una factura/documento automáticamente para un pedido pagado
  Future<void> _crearFacturaPedido(
    String pedidoId, {
    String? formaPago,
    double? propina,
    String? pagadoPor,
  }) async {
    try {
      // Obtener el pedido completo para extraer información
      final pedido = await _pedidoService.getPedidoById(pedidoId);

      if (pedido == null) {
        throw Exception('No se encontró el pedido con ID: $pedidoId');
      }

      // Obtener el usuario actual
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final vendedor = userProvider.userName ?? 'Sistema';

      // Validar forma de pago
      String formapagoValidada = formaPago ?? 'efectivo';
      if (formapagoValidada != 'efectivo' &&
          formapagoValidada != 'transferencia') {
        print(
          '⚠️ Forma de pago no reconocida: "$formapagoValidada". Usando efectivo por defecto.',
        );
        formapagoValidada = 'efectivo';
      }

      print('💰 Datos del documento:');
      print('  - Mesa: ${pedido.mesa}');
      print('  - Forma de pago: $formapagoValidada');
      print('  - Propina: ${propina ?? 0.0}');
      print('  - Pagado por: ${pagadoPor ?? vendedor}');

      // Crear documento usando el servicio real
      final documento = await _documentoMesaService.crearDocumento(
        mesaNombre: pedido.mesa,
        vendedor: vendedor,
        pedidosIds: [pedidoId],
        formaPago: formapagoValidada,
        pagadoPor: pagadoPor ?? vendedor,
        propina: propina ?? 0.0,
        pagado: true,
        estado: 'Pagado',
        fechaPago: DateTime.now(),
      );

      if (documento != null) {
        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Documento ${documento.numeroDocumento} creado exitosamente',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('El servicio de documentos devolvió null');
      }
    } catch (e) {
      print('❌ Error creando documento automático: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error creando documento: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      // No lanzar la excepción para que no interrumpa el flujo de pago
    }
  }

  // Método para imprimir resumen de pedido
  Future<void> _imprimirResumenPedido(Map<String, dynamic> resumen) async {
    try {
      final textoImpresion = _impresionService.generarTextoImpresion(resumen);

      // Mostrar vista previa antes de imprimir
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: _cardElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Encabezado del diálogo
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primary.withOpacity(0.1),
                        _primary.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.print, color: _primary, size: 24),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Vista Previa de Impresión',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenido del diálogo
                Flexible(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _backgroundDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _textMuted.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          textoImpresion,
                          style: TextStyle(
                            color: _textPrimary,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Botones de acción
                Container(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cerrar',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await imprimirDocumento(resumen);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.print, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Imprimir',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparando impresión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para mostrar opciones de compartir
  Future<void> _mostrarOpcionesCompartir(Map<String, dynamic> resumen) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Compartir Resumen', style: TextStyle(color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Cómo deseas compartir este resumen?',
              style: TextStyle(color: _textPrimary),
            ),
            SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (mounted) {
                Navigator.pop(context);
                await _generarYCompartirPDF(resumen);
              }
            },
            icon: Icon(Icons.picture_as_pdf),
            label: Text('PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (mounted) {
                Navigator.pop(context);
                await _compartirTexto(resumen);
              }
            },
            icon: Icon(Icons.text_fields),
            label: Text('Texto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (mounted) {
                Navigator.pop(context);
                await imprimirDocumento(resumen);
              }
            },
            icon: Icon(Icons.print),
            label: Text('Imprimir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Método para compartir como texto simple
  Future<void> _compartirTexto(Map<String, dynamic> resumen) async {
    try {
      final textoImpresion = _impresionService.generarTextoImpresion(resumen);
      await Share.share(
        textoImpresion,
        subject: 'Resumen de Pedido - ${resumen['pedidoId']}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error compartiendo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para generar y compartir PDF
  Future<void> _generarYCompartirPDF(Map<String, dynamic> resumen) async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: _cardBg,
            content: Row(
              children: [
                CircularProgressIndicator(color: _primary),
                SizedBox(width: 20),
                Text(
                  kIsWeb ? 'Preparando documento...' : 'Generando PDF...',
                  style: TextStyle(color: _textPrimary),
                ),
              ],
            ),
          ),
        );
      }

      if (kIsWeb) {
        // Para web, generar PDF directamente
        final pdfServiceWeb = PDFServiceFactory.create();

        if (mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
        }

        try {
          pdfServiceWeb.generarYDescargarPDF(resumen: resumen);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Generando PDF...'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error generando PDF: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      } else {
        // Para plataformas nativas, usar PDF tradicional
        final pdf = pw.Document();

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              final textoImpresion = _impresionService.generarTextoImpresion(
                resumen,
              );
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Resumen de Pedido',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(textoImpresion, style: pw.TextStyle(fontSize: 10)),
                ],
              );
            },
          ),
        );

        final pdfBytes = await pdf.save();

        // Guardar temporalmente el PDF
        final tempDir = Directory.systemTemp;
        final fileName =
            'resumen_pedido_${resumen['pedidoId']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        if (mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
        }

        // Compartir el archivo PDF
        await Share.shareXFiles([
          XFile(file.path),
        ], subject: 'Resumen de Pedido - ${resumen['pedidoId']}');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generando PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Opciones específicas para web
  Future<void> _mostrarOpcionesWebPDF(
    Map<String, dynamic> resumen,
    PDFServiceInterface pdfServiceWeb,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Opciones de documento',
          style: TextStyle(color: _textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Cómo deseas procesar este documento?',
              style: TextStyle(color: _textSecondary),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      pdfServiceWeb.abrirVentanaImpresion(resumen: resumen);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ventana de impresión abierta'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(Icons.print),
                  label: Text('Imprimir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      pdfServiceWeb.descargarComoTexto(resumen: resumen);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Archivo descargado'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(Icons.download),
                  label: Text('Descargar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await pdfServiceWeb.compartirTexto(resumen: resumen);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Contenido copiado al portapapeles'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(Icons.share),
                  label: Text('Compartir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: _textSecondary)),
          ),
        ],
      ),
    );
  }

  // Método para marcar como deuda
  Future<void> _marcarComoDeuda(Map<String, dynamic> resumen) async {
    String nombreDeudor = '';
    String observaciones = '';

    final resultado = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.orange),
            SizedBox(width: 8),
            Text('Registrar Deuda', style: TextStyle(color: _textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total a deber: \$${(resumen['total'] ?? 0.0).toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              style: TextStyle(color: _textPrimary),
              decoration: InputDecoration(
                labelText: 'Nombre del deudor (opcional)',
                labelStyle: TextStyle(color: _textSecondary),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: _surfaceDark,
              ),
              onChanged: (value) => nombreDeudor = value,
            ),
            SizedBox(height: 16),
            TextField(
              style: TextStyle(color: _textPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Observaciones (opcional)',
                labelStyle: TextStyle(color: _textSecondary),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: _surfaceDark,
              ),
              onChanged: (value) => observaciones = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'nombreDeudor': nombreDeudor,
                'observaciones': observaciones,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Registrar Deuda'),
          ),
        ],
      ),
    );

    if (resultado != null) {
      await _guardarDeuda(
        resumen,
        resultado['nombreDeudor'] ?? '',
        resultado['observaciones'] ?? '',
      );
    }
  }

  // Método para guardar la deuda
  Future<void> _guardarDeuda(
    Map<String, dynamic> resumen,
    String nombreDeudor,
    String observaciones,
  ) async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: _cardBg,
            content: Row(
              children: [
                CircularProgressIndicator(color: _primary),
                SizedBox(width: 20),
                Text(
                  'Registrando deuda...',
                  style: TextStyle(color: _textPrimary),
                ),
              ],
            ),
          ),
        );
      }

      // Crear el registro de deuda
      final deuda = {
        'pedidoId': resumen['pedidoId'],
        'mesa': resumen['mesa'] ?? 'Mesa Auxiliar',
        'total': resumen['total'] ?? 0.0,
        'nombreDeudor': nombreDeudor.isNotEmpty
            ? nombreDeudor
            : 'Cliente sin nombre',
        'observaciones': observaciones,
        'fechaCreacion': DateTime.now().toIso8601String(),
        'estado': 'pendiente',
        'vendedor': resumen['mesero'] ?? 'Sistema',
        'productos': resumen['productos'] ?? [],
      };

      // Guardar en el servicio de deudas (necesitaría implementar este servicio)
      await _guardarDeudaEnServicio(deuda);

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        Navigator.pop(context); // Cerrar diálogo de resumen

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Deuda registrada exitosamente'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error registrando deuda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para guardar deuda en servicio (placeholder)
  Future<void> _guardarDeudaEnServicio(Map<String, dynamic> deuda) async {
    try {
      // Simular guardado en base de datos local o archivo
      // En una implementación real, esto debería enviar a tu backend
      print('📁 Guardando deuda: ${jsonEncode(deuda)}');

      // Simular delay de red
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) {
      print('❌ Error guardando deuda: $e');
      throw Exception('Error guardando deuda: $e');
    }
  }

  // Método para mostrar diálogo simple de pago
  Future<Map<String, dynamic>?> _mostrarDialogoSimplePago() async {
    String medioPago = 'efectivo';
    double propina = 0.0;
    String pagadoPor = '';

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: _cardElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Encabezado
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primary.withOpacity(0.15),
                        _primary.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.payment, color: _primary, size: 24),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Información de Pago',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenido
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    children: [
                      // Dropdown de método de pago
                      Container(
                        decoration: BoxDecoration(
                          color: _surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _textMuted.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: medioPago,
                          decoration: InputDecoration(
                            labelText: 'Método de Pago',
                            labelStyle: TextStyle(
                              color: _textSecondary,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          dropdownColor: _cardElevated,
                          style: TextStyle(color: _textPrimary, fontSize: 15),
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: _primary,
                          ),
                          items:
                              [
                                    'efectivo',
                                    'tarjeta',
                                    'transferencia',
                                    'cortesia',
                                  ]
                                  .map(
                                    (String value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (String? newValue) {
                            setState(() => medioPago = newValue!);
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      // Campo de propina
                      Container(
                        decoration: BoxDecoration(
                          color: _surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _textMuted.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Propina',
                            labelStyle: TextStyle(
                              color: _textSecondary,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.monetization_on,
                              color: _primary,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          style: TextStyle(color: _textPrimary, fontSize: 15),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            propina = double.tryParse(value) ?? 0.0;
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      // Campo pagado por
                      Container(
                        decoration: BoxDecoration(
                          color: _surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _textMuted.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Pagado por',
                            labelStyle: TextStyle(
                              color: _textSecondary,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(Icons.person, color: _primary),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          style: TextStyle(color: _textPrimary, fontSize: 15),
                          onChanged: (value) {
                            pagadoPor = value;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Botones de acción
                Container(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, {
                            'medioPago': medioPago,
                            'propina': propina,
                            'pagadoPor': pagadoPor,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Continuar',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Método para construir item de producto con ingredientes
  Widget _buildProductoItemConIngredientes(Map<String, dynamic> producto) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _textMuted.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${producto['cantidad']}x ${producto['nombre'] ?? 'Producto'}',
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '\$${(producto['subtotal'] ?? 0.0).toStringAsFixed(0)}',
                style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (producto['ingredientes'] != null &&
              (producto['ingredientes'] as List).isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              'Ingredientes: ${(producto['ingredientes'] as List).join(', ')}',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (producto['observaciones'] != null &&
              producto['observaciones'].toString().isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              'Obs: ${producto['observaciones']}',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Asegurar que el flag de procesamiento empiece limpio
    _procesandoPago = false;
    _loadMesas();
    _configurarWebSockets();
    _iniciarSincronizacion();
  }

  void _iniciarSincronizacion() {
    // Sincronización deshabilitada
  }

  @override
  void dispose() {
    // Limpiar subscripciones
    _pedidoCompletadoSubscription.cancel();
    _pedidoPagadoSubscription.cancel();
    super.dispose();
  }

  void _configurarWebSockets() {
    // Suscribirse a eventos de pedidos completados
    _pedidoCompletadoSubscription = _pedidoService.onPedidoCompletado.listen((
      _,
    ) {
      _loadMesas();
    });

    // Suscribirse a eventos de pedidos pagados
    _pedidoPagadoSubscription = _pedidoService.onPedidoPagado.listen((_) {
      _loadMesas();
    });
  }

  Future<void> _loadMesas() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Cargar las mesas
      final loadedMesas = await _mesaService.getMesas();

      // Sincronizar estado de mesas con pedidos activos
      await _sincronizarEstadoMesas(loadedMesas);

      setState(() {
        mesas = loadedMesas;
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = 'Error al cargar mesas: $error';
        isLoading = false;
      });
    }
  }

  Future<void> _sincronizarEstadoMesas(List<Mesa> mesas) async {
    for (Mesa mesa in mesas) {
      try {
        // Solo verificar mesas que aparecen como ocupadas
        if (mesa.ocupada || mesa.total > 0) {
          final pedidos = await _pedidoService.getPedidosByMesa(mesa.nombre);
          final hayPedidoActivo = pedidos.any(
            (pedido) => pedido.estado == EstadoPedido.activo,
          );

          if (!hayPedidoActivo) {
            print(
              '⚠️ Mesa ${mesa.nombre}: Sin pedidos activos, liberando mesa...',
            );

            // Si no hay pedidos activos pero la mesa aparece ocupada, liberarla
            if (mesa.ocupada || mesa.total > 0) {
              mesa.ocupada = false;
              mesa.productos = [];
              mesa.total = 0.0;

              try {
                await _mesaService.updateMesa(mesa);
              } catch (e) {
                print('❌ Error al liberar mesa ${mesa.nombre}: $e');
              }
            }
          }
        }
      } catch (e) {
        print('❌ Error verificando mesa ${mesa.nombre}: $e');
      }
    }
  }

  /// Crea un documento de mesa agrupando varios pedidos
  Future<void> _crearDocumentoMesa(Mesa mesa) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final vendedor = userProvider.userName ?? 'Usuario';

    try {
      // 1. Obtener pedidos activos para esta mesa
      List<Pedido> pedidosActivos = await _pedidoService.getPedidosByMesa(
        mesa.nombre,
      );
      pedidosActivos = pedidosActivos
          .where((p) => p.estado != EstadoPedido.pagado)
          .toList();

      if (pedidosActivos.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay pedidos activos para agrupar'),
            ),
          );
        }
        return;
      }

      // 2. Mostrar diálogo para seleccionar pedidos
      await _mostrarDialogoSeleccionPedidos(mesa, pedidosActivos, vendedor);
    } catch (e) {
      print('❌ Error al crear documento: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al crear documento: $e')));
    }
  }

  /// Muestra un diálogo para seleccionar pedidos al crear un documento
  Future<void> _mostrarDialogoSeleccionPedidos(
    Mesa mesa,
    List<Pedido> pedidos,
    String vendedor,
  ) async {
    List<String> pedidosSeleccionados = [];

    return showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF252525),
              title: Text(
                'Crear documento para ${mesa.nombre}',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selecciona los pedidos a incluir:',
                      style: TextStyle(color: Color(0xFFE0E0E0)),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: pedidos.length,
                        itemBuilder: (context, index) {
                          final pedido = pedidos[index];
                          return CheckboxListTile(
                            title: Text(
                              'Pedido ${pedido.id.substring(0, 8)}...',
                              style: const TextStyle(color: Color(0xFFE0E0E0)),
                            ),
                            subtitle: Text(
                              'Total: ${formatCurrency(pedido.total)}',
                              style: TextStyle(
                                color: const Color(0xFFE0E0E0).withOpacity(0.7),
                              ),
                            ),
                            value: pedidosSeleccionados.contains(pedido.id),
                            activeColor: const Color(0xFFFF6B00),
                            checkColor: Colors.white,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  pedidosSeleccionados.add(pedido.id);
                                } else {
                                  pedidosSeleccionados.remove(pedido.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Color(0xFFE0E0E0)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                  ),
                  onPressed: pedidosSeleccionados.isEmpty
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await _enviarDocumentoAlServidor({
                            'mesa': mesa.nombre,
                            'vendedor': vendedor,
                            'pedidos': pedidosSeleccionados,
                          });
                        },
                  child: const Text('Crear Documento'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Pedido?> _obtenerPedidoActivoDeMesa(Mesa mesa) async {
    try {
      print('🔍 Buscando pedido activo para mesa: ${mesa.id}');

      // Siempre buscar en el servidor para obtener el ID más actualizado
      final pedidos = await _pedidoService.getPedidosByMesa(mesa.nombre);
      print('📋 Pedidos encontrados para la mesa: ${pedidos.length}');

      final pedidoActivo = pedidos.firstWhere(
        (pedido) => pedido.estado == EstadoPedido.activo,
        orElse: () => throw Exception('No hay pedido activo'),
      );

      // Verificar que el ID no esté vacío
      if (pedidoActivo.id.isEmpty) {
        print('❌ ERROR: El pedido activo no tiene ID válido');
        throw Exception('El pedido activo no tiene ID válido');
      }

      return pedidoActivo;
    } catch (e) {
      print('❌ Error al obtener pedido activo: $e');

      // Si no hay pedido activo pero la mesa aparece ocupada, corregir automáticamente
      if (mesa.ocupada || mesa.total > 0) {
        print(
          '🔧 Corrigiendo estado de mesa ${mesa.nombre} sin pedidos activos...',
        );
        try {
          mesa.ocupada = false;
          mesa.productos = [];
          mesa.total = 0.0;
          await _mesaService.updateMesa(mesa);

          // Recargar las mesas para reflejar el cambio en la UI
          _loadMesas();
        } catch (updateError) {
          print('❌ Error al corregir mesa ${mesa.nombre}: $updateError');
        }
      }

      return null;
    }
  }

  void _mostrarMenuMesa(Mesa mesa) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_cardElevated, _cardBg],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: _primary.withOpacity(0.3), width: 2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Título
              Container(
                padding: EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.table_restaurant,
                        color: _primary,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mesa ${mesa.nombre}',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          mesa.ocupada ? 'Ocupada' : 'Disponible',
                          style: TextStyle(
                            color: mesa.ocupada ? _error : _success,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Opciones del menú
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    _buildMenuOption(
                      icon: Icons.sync,
                      title: 'Sincronizar estado',
                      subtitle: 'Actualizar estado con pedidos',
                      onTap: () {
                        Navigator.pop(context);
                        _sincronizarMesa(mesa);
                      },
                    ),
                    if (mesa.ocupada) ...[
                      SizedBox(height: 8),
                      _buildMenuOption(
                        icon: Icons.payment_outlined,
                        title: 'Pago Parcial',
                        subtitle: 'Pagar productos seleccionados',
                        onTap: () async {
                          Navigator.pop(context);
                          final pedido = await _obtenerPedidoActivoDeMesa(mesa);
                          if (pedido != null) {
                            _mostrarDialogoPagoParcial(mesa, pedido);
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'No se encontró un pedido activo para esta mesa',
                                  ),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      SizedBox(height: 8),
                      _buildMenuOption(
                        icon: Icons.cancel_outlined,
                        title: 'Cancelar Productos',
                        subtitle: 'Cancelar productos del pedido',
                        onTap: () async {
                          Navigator.pop(context);
                          final pedido = await _obtenerPedidoActivoDeMesa(mesa);
                          if (pedido != null) {
                            _mostrarDialogoCancelarProductos(mesa, pedido);
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'No se encontró un pedido activo para esta mesa',
                                  ),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      SizedBox(height: 8),
                      _buildMenuOption(
                        icon: Icons.move_to_inbox_outlined,
                        title: 'Mover Productos',
                        subtitle: 'Mover productos a otra mesa',
                        onTap: () async {
                          Navigator.pop(context);
                          final pedido = await _obtenerPedidoActivoDeMesa(mesa);
                          if (pedido != null) {
                            _mostrarDialogoMoverProductos(mesa, pedido);
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'No se encontró un pedido activo para esta mesa',
                                  ),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      SizedBox(height: 8),
                      _buildMenuOption(
                        icon: Icons.cleaning_services,
                        title: 'Vaciar mesa',
                        subtitle: 'Liberar mesa manualmente',
                        onTap: () {
                          Navigator.pop(context);
                          _vaciarMesaManualmente(mesa);
                        },
                        isDestructive: true,
                      ),
                      SizedBox(height: 8),
                      _buildMenuOption(
                        icon: Icons.description_outlined,
                        title: 'Crear documento',
                        subtitle: 'Agrupar pedidos de la mesa',
                        onTap: () {
                          Navigator.pop(context);
                          _crearDocumentoMesa(mesa);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? _error : _primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceDark.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: _textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoForzarLimpieza() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          '¿Restaurar todas las mesas?',
          style: TextStyle(color: _textPrimary),
        ),
        content: Text(
          'Esta acción marcará TODAS las mesas como disponibles y eliminará todos los productos asociados. Esta operación es útil cuando se han eliminado manualmente los pedidos de la base de datos y las mesas han quedado desincronizadas.\n\n¿Desea continuar?',
          style: TextStyle(color: _textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Restaurar Todo'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        if (mounted) {
          setState(() {
            isLoading = true;
          });
        }

        // Funcionalidad de limpieza deshabilitada
        int mesasLimpiadas = 0;

        // Recargar las mesas
        await _loadMesas();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$mesasLimpiadas mesas han sido restauradas correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al restaurar mesas: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _vaciarMesaManualmente(Mesa mesa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('¿Vaciar mesa?', style: TextStyle(color: _textPrimary)),
        content: Text(
          'Esta acción marcará la mesa como disponible y eliminará todos los productos asociados. Esto NO afectará a los pedidos existentes en el sistema.',
          style: TextStyle(color: _textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Vaciar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        if (mounted) {
          setState(() {
            isLoading = true;
          });
        }

        await _mesaService.vaciarMesa(mesa.id);
        await _loadMesas();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mesa ${mesa.nombre} vaciada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al vaciar mesa: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _sincronizarMesa(Mesa mesa) async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      await _loadMesas(); // Recargar las mesas

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesa ${mesa.nombre} actualizada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar mesa: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _buildMesaCard(Mesa mesa) {
    bool isOcupada = mesa.ocupada;
    Color statusColor = isOcupada ? AppTheme.error : AppTheme.success;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    bool canProcessPayment =
        userProvider.isAdmin && isOcupada && mesa.total > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PedidoScreen(mesa: mesa)),
            );
          },
          onLongPress: userProvider.isAdmin
              ? () => _mostrarMenuMesa(mesa)
              : null,
          child: Container(
            decoration: BoxDecoration(
              gradient: isOcupada ? AppTheme.cardGradient : null,
              color: isOcupada ? null : AppTheme.cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: isOcupada
                    ? AppTheme.primary.withOpacity(0.6)
                    : statusColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                ...AppTheme.cardShadow,
                if (isOcupada) ...AppTheme.primaryShadow,
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(
                constraints.maxWidth * 0.12,
              ), // Padding responsivo aumentado
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicador de estado superior
                  Container(
                    width: double.infinity,
                    height: 2,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusSmall / 2,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  // Icono de mesa
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.table_restaurant,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  SizedBox(height: 6),
                  // Nombre de la mesa
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      mesa.nombre,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 6),
                  // Estado
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                        color: statusColor.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          isOcupada ? 'Ocupada' : 'Disponible',
                          style: AppTheme.labelMedium.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Total si existe
                  if (mesa.total > 0) ...[
                    SizedBox(height: 8),
                    canProcessPayment
                        ? Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final pedido = await _obtenerPedidoActivoDeMesa(
                                  mesa,
                                );
                                if (pedido != null) {
                                  _mostrarDialogoPago(mesa, pedido);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'No se encontró un pedido activo para esta mesa',
                                      ),
                                      backgroundColor: AppTheme.error,
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSmall,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Icon(
                                      Icons.payment,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      formatCurrency(mesa.total),
                                      style: AppTheme.labelMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall,
                              ),
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              formatCurrency(mesa.total),
                              style: AppTheme.labelMedium.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarDialogoPago(Mesa mesa, Pedido pedido) async {
    String medioPago0 = 'efectivo';
    bool incluyePropina = false;
    TextEditingController descuentoPorcentajeController =
        TextEditingController();
    TextEditingController descuentoValorController = TextEditingController();
    TextEditingController propinaController = TextEditingController();

    // Reseteamos la bandera de procesamiento al comenzar
    setState(() {
      _procesandoPago = false;
    });

    // NUEVAS VARIABLES PARA LAS OPCIONES MOVIDAS
    bool esCortesia0 = false;
    bool esConsumoInterno0 = false;

    // Funcionalidad de selección individual eliminada para simplificar la interfaz

    // NUEVAS VARIABLES PARA SELECTOR DE BILLETES Y CAMBIO
    double billetesSeleccionados = 0.0;
    TextEditingController billetesController = TextEditingController();
    Map<int, int> contadorBilletes = {
      50000: 0,
      20000: 0,
      10000: 0,
      5000: 0,
      2000: 0,
      1000: 0,
    };

    // Función local para construir botones de billetes mejorados
    Widget buildBilletButton(int valor, Function(VoidCallback) setStateLocal) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: () {
              setStateLocal(() {
                billetesSeleccionados += valor.toDouble();
                contadorBilletes[valor] = (contadorBilletes[valor] ?? 0) + 1;
                billetesController.text = billetesSeleccionados.toStringAsFixed(
                  0,
                );
              });
            },
            child: Container(
              height: 80, // Más alto
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primary, _primary.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mostrar contador si hay billetes seleccionados
                  if ((contadorBilletes[valor] ?? 0) > 0) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '${contadorBilletes[valor]}',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                  ],

                  // Icono de billete
                  Icon(Icons.money, color: Colors.white, size: 20),
                  SizedBox(height: 4),

                  // Valor del billete
                  Text(
                    '\$${(valor / 1000).toStringAsFixed(0)}K',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Mostrar indicador de carga mientras se prepara el diálogo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        content: Row(
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(width: 20),
            Text(
              'Cargando información de productos...',
              style: TextStyle(color: _textPrimary),
            ),
          ],
        ),
      ),
    );

    // Asegurarse de que todos los productos estén cargados antes de mostrar el diálogo
    try {
      await PedidoService().cargarProductosParaPedido(pedido);
    } catch (e) {
      print('❌ Error cargando productos del pedido: $e');
    }

    // Cerrar el diálogo de carga
    Navigator.of(context).pop();
    final formResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Bordes más redondeados
          ),
          child: Container(
            width:
                MediaQuery.of(context).size.width *
                0.85, // Ancho ligeramente mayor
            padding: EdgeInsets.all(28), // Más padding
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header del diálogo
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.payment, color: _primary, size: 32),
                        SizedBox(height: 12),
                        Text(
                          'Procesar Pago',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32), // Más espacio
                  // Sección: Información del pedido
                  _buildSeccionTitulo('Información del Pedido'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(20), // Más padding
                    decoration: BoxDecoration(
                      color: _cardBg.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(
                        16,
                      ), // Bordes más redondeados
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          Icons.table_restaurant,
                          'Mesa',
                          pedido.mesa,
                        ),
                        SizedBox(height: 12),
                        _buildInfoRow(Icons.person, 'Mesero', pedido.mesero),
                        if (pedido.cliente != null) ...[
                          SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.person_outline,
                            'Cliente',
                            pedido.cliente!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 32), // Más espacio
                  // Sección: Productos del Pedido - Versión Simplificada
                  _buildSeccionTitulo('Productos del Pedido'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(20), // Más padding
                    decoration: BoxDecoration(
                      color: _cardBg.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: pedido.items
                          .map(
                            (item) => Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 8,
                              ), // Más padding vertical
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Información del producto
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item.cantidad}x ${item.productoNombre ?? 'Producto'}',
                                            style: TextStyle(
                                              color: _textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          if (item.notas != null &&
                                              item.notas!.isNotEmpty) ...[
                                            SizedBox(height: 4),
                                            Text(
                                              item.notas!,
                                              style: TextStyle(
                                                color: _textPrimary.withOpacity(
                                                  0.7,
                                                ),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Precio
                                    Text(
                                      '\$${(item.precioUnitario * item.cantidad).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: _primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(height: 32),

                  // Sección: Forma de pago
                  _buildSeccionTitulo('Método de Pago'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardBg.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        // Botones de método de pago mejorados
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => medioPago0 = 'efectivo'),
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: medioPago0 == 'efectivo'
                                        ? _primary.withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: medioPago0 == 'efectivo'
                                          ? _primary
                                          : _textMuted,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.money,
                                        color: medioPago0 == 'efectivo'
                                            ? _primary
                                            : _textSecondary,
                                        size: 24,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Efectivo',
                                        style: TextStyle(
                                          color: medioPago0 == 'efectivo'
                                              ? _primary
                                              : _textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => medioPago0 = 'transferencia',
                                ),
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: medioPago0 == 'transferencia'
                                        ? _primary.withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: medioPago0 == 'transferencia'
                                          ? _primary
                                          : _textMuted,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.credit_card,
                                        color: medioPago0 == 'transferencia'
                                            ? _primary
                                            : _textSecondary,
                                        size: 24,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tarjeta/Transfer.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: medioPago0 == 'transferencia'
                                              ? _primary
                                              : _textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),

                  // Sección: Pago en efectivo (condicional)
                  if (medioPago0 == 'efectivo') ...[
                    _buildSeccionTitulo('Cálculo de Cambio'),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _cardBg.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Campo para entrada manual
                          TextField(
                            controller: billetesController,
                            decoration: InputDecoration(
                              labelText: 'Total recibido',
                              labelStyle: TextStyle(color: _textPrimary),
                              prefixText: '\$',
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: _textMuted),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _primary,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            style: TextStyle(color: _textPrimary, fontSize: 16),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                billetesSeleccionados =
                                    double.tryParse(value) ?? 0.0;
                                if (value.isNotEmpty) {
                                  contadorBilletes.updateAll((key, val) => 0);
                                }
                              });
                            },
                          ),
                          SizedBox(height: 20),

                          Text(
                            'O selecciona los billetes:',
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 16),

                          // Botones de billetes mejorados
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              buildBilletButton(50000, setState),
                              buildBilletButton(20000, setState),
                              buildBilletButton(10000, setState),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              buildBilletButton(5000, setState),
                              buildBilletButton(2000, setState),
                              buildBilletButton(1000, setState),
                            ],
                          ),
                          SizedBox(height: 16),

                          // Botones de acción para billetes
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      contadorBilletes.updateAll(
                                        (key, value) => 0,
                                      );
                                      double subtotal = pedido.total;
                                      double propinaPercent =
                                          double.tryParse(
                                            propinaController.text,
                                          ) ??
                                          0.0;
                                      double propinaMonto =
                                          (subtotal * propinaPercent / 100)
                                              .roundToDouble();
                                      double total = subtotal + propinaMonto;
                                      billetesSeleccionados = total;
                                      billetesController.text =
                                          billetesSeleccionados.toStringAsFixed(
                                            0,
                                          );
                                    });
                                  },
                                  icon: Icon(Icons.check, size: 18),
                                  label: Text('Exacto'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      billetesSeleccionados = 0.0;
                                      billetesController.text = '0';
                                      contadorBilletes.updateAll(
                                        (key, value) => 0,
                                      );
                                    });
                                  },
                                  icon: Icon(Icons.clear, size: 18),
                                  label: Text('Limpiar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Sección: Propina y Totales
                  _buildSeccionTitulo('Propina y Totales'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardBg.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        // Campo de propina
                        TextField(
                          controller: propinaController,
                          decoration: InputDecoration(
                            labelText: 'Propina (%)',
                            labelStyle: TextStyle(color: _textPrimary),
                            suffixText: '%',
                            prefixIcon: Icon(Icons.star, color: _primary),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _textMuted),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _primary, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: TextStyle(color: _textPrimary, fontSize: 16),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              incluyePropina =
                                  value.isNotEmpty &&
                                  double.tryParse(value) != null &&
                                  double.parse(value) > 0;
                            });
                          },
                        ),
                        SizedBox(height: 24),

                        // Resumen de totales
                        Builder(
                          builder: (context) {
                            double subtotal = pedido.total;
                            double propinaPercent =
                                double.tryParse(propinaController.text) ?? 0.0;
                            double propinaMonto =
                                (subtotal * propinaPercent / 100)
                                    .roundToDouble();
                            double total = subtotal + propinaMonto;

                            return Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _primary.withOpacity(0.1),
                                    _primary.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _primary.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Subtotal:',
                                        style: TextStyle(
                                          color: _textPrimary,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        formatCurrency(subtotal),
                                        style: TextStyle(
                                          color: _textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (propinaPercent > 0) ...[
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Propina ($propinaPercent%):',
                                          style: TextStyle(
                                            color: _textPrimary,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          formatCurrency(propinaMonto),
                                          style: TextStyle(
                                            color: _textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  SizedBox(height: 16),
                                  Divider(
                                    color: _primary.withOpacity(0.3),
                                    thickness: 2,
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'TOTAL:',
                                        style: TextStyle(
                                          color: _textPrimary,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      Text(
                                        formatCurrency(total),
                                        style: TextStyle(
                                          color: _primary,
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Mostrar cálculo de cambio para efectivo
                                  if (medioPago0 == 'efectivo' &&
                                      billetesSeleccionados > 0) ...[
                                    SizedBox(height: 20),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _cardBg.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Recibido:',
                                                style: TextStyle(
                                                  color: _textPrimary,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                '\$${billetesSeleccionados.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color: _textPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Cambio:',
                                                style: TextStyle(
                                                  color: _textPrimary,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                (billetesSeleccionados -
                                                            total) >=
                                                        0
                                                    ? '\$${(billetesSeleccionados - total).toStringAsFixed(0)}'
                                                    : '-\$${(total - billetesSeleccionados).toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color:
                                                      (billetesSeleccionados -
                                                              total) >=
                                                          0
                                                      ? Colors.green
                                                      : Colors.red,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
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
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),

                  // Sección: Opciones Especiales
                  _buildSeccionTitulo('Opciones Especiales'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardBg.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        // Opción Es cortesía
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: esCortesia0
                                ? _primary.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: esCortesia0
                                  ? _primary
                                  : _textPrimary.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.card_giftcard,
                                color: esCortesia0 ? _primary : _textSecondary,
                                size: 24,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Es cortesía',
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Switch(
                                value: esCortesia0,
                                activeThumbColor: _primary,
                                onChanged: (value) {
                                  setState(() {
                                    esCortesia0 = value;
                                    if (value) {
                                      esConsumoInterno0 = false;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // Opción Consumo interno
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: esConsumoInterno0
                                ? _primary.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: esConsumoInterno0
                                  ? _primary
                                  : _textPrimary.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people,
                                color: esConsumoInterno0
                                    ? _primary
                                    : _textSecondary,
                                size: 24,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Consumo interno',
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Switch(
                                value: esConsumoInterno0,
                                activeThumbColor: _primary,
                                onChanged: (value) {
                                  setState(() {
                                    esConsumoInterno0 = value;
                                    if (value) {
                                      esCortesia0 = false;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),

                  // Botones principales
                  Row(
                    children: [
                      // Botón Compartir Resumen (solo compartir, no facturar)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              // Mostrar indicador de carga
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => AlertDialog(
                                  backgroundColor: _cardBg,
                                  content: Row(
                                    children: [
                                      CircularProgressIndicator(
                                        color: _primary,
                                      ),
                                      SizedBox(width: 20),
                                      Text(
                                        'Generando resumen...',
                                        style: TextStyle(color: _textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              // Generar resumen
                              var resumenNullable = await _impresionService
                                  .generarResumenPedido(pedido.id);

                              // Cerrar diálogo de carga
                              Navigator.of(context).pop();

                              if (resumenNullable != null) {
                                final resumen = await actualizarConInfoNegocio(
                                  resumenNullable,
                                );
                                await _mostrarOpcionesCompartir(resumen);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo generar el resumen',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              Navigator.of(
                                context,
                              ).pop(); // Cerrar carga si hay error
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: Icon(Icons.share, size: 20),
                          label: Text('Compartir Resumen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 3,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),

                      // Botón Cancelar
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textPrimary,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            side: BorderSide(color: _textMuted),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),

                      // Botón Confirmar Pago
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Devolver resultado después de un pequeño delay
                            Future.delayed(Duration(milliseconds: 300), () {
                              if (mounted) {
                                Navigator.pop(context, {
                                  'medioPago': medioPago0,
                                  'incluyePropina': incluyePropina,
                                  'descuentoPorcentaje':
                                      descuentoPorcentajeController.text,
                                  'descuentoValor':
                                      descuentoValorController.text,
                                  'propina': propinaController.text,
                                  'esCortesia': esCortesia0,
                                  'esConsumoInterno': esConsumoInterno0,

                                  'billetesRecibidos': billetesSeleccionados,
                                });
                              }
                            });
                          },
                          icon: Icon(Icons.payment, size: 20),
                          label: Text('Confirmar Pago'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (formResult != null) {
      print('🔒 Iniciando procesamiento de pago...');

      try {
        // Manejar las opciones especiales
        bool esCortesia = formResult['esCortesia'] ?? false;
        bool esConsumoInterno = formResult['esConsumoInterno'] ?? false;
        String? mesaDestinoId = formResult['mesaDestinoId'];

        // Preparar datos de pago
        double propina = 0.0;
        // Calcular propina basada en el porcentaje ingresado
        double propinaPercentage =
            double.tryParse(formResult['propina'] ?? '0') ?? 0.0;
        if (propinaPercentage > 0) {
          propina = (pedido.total * propinaPercentage / 100).roundToDouble();
        }

        print(
          '📝 Procesando pago del pedido: "${pedido.id}" - Mesa: ${mesa.nombre}',
        );
        if (pedido.id.isEmpty) {
          throw Exception('El ID del pedido es inválido o está vacío');
        }

        // Obtener el usuario actual para el pago
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final usuarioPago = userProvider.userName ?? 'Usuario Desconocido';

        // PRIMERO: Cambiar el tipo de pedido si es necesario
        if (esCortesia || esConsumoInterno) {
          try {
            TipoPedido nuevoTipo = esCortesia
                ? TipoPedido.cortesia
                : TipoPedido.interno;
            print('🔄 Cambiando tipo de pedido a: $nuevoTipo');
            print('  - Pedido ID: ${pedido.id}');
            print('  - Tipo anterior: ${pedido.tipo}');

            await _pedidoService.actualizarTipoPedido(pedido.id, nuevoTipo);

            // Actualizar el objeto pedido local
            pedido.tipo = nuevoTipo;

            print('✅ Tipo de pedido actualizado correctamente');
            print('  - Nuevo tipo asignado: $nuevoTipo');
            print('  - Tipo en objeto local: ${pedido.tipo}');

            // Esperar un momento para que el backend procese el cambio
            await Future.delayed(Duration(milliseconds: 300));
          } catch (e) {
            print('❌ Error al cambiar tipo de pedido: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al actualizar tipo de pedido: $e'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.of(context).pop();
            return; // Salir si falla el cambio de tipo
          }
        }

        // SEGUNDO: Pagar el pedido (sin cambiar tipo aquí)
        print('💰 Iniciando proceso de pago...');
        print('  - Forma de pago: ${formResult['medioPago']}');
        print('  - Propina: $propina');
        print('  - Pagado por: $usuarioPago');
        print('  - Tipo final del pedido: ${pedido.tipo}');

        // Validar forma de pago
        String medioPago = formResult['medioPago'] ?? 'efectivo';
        if (medioPago != 'efectivo' && medioPago != 'transferencia') {
          print(
            '⚠️ Forma de pago no reconocida: "$medioPago". Usando efectivo por defecto.',
          );
          medioPago = 'efectivo';
        }

        print('💲 Forma de pago seleccionada: $medioPago');

        await _pedidoService.pagarPedido(
          pedido.id,
          formaPago: medioPago,
          propina: propina,
          procesadoPor: usuarioPago, // Cambio de 'pagadoPor' a 'procesadoPor'
          esCortesia: esCortesia,
          esConsumoInterno: esConsumoInterno,
          motivoCortesia: esCortesia ? 'Pedido procesado como cortesía' : null,
          tipoConsumoInterno: esConsumoInterno ? 'empleado' : null,
        );

        print('✅ Pago procesado exitosamente');

        // Actualizar el objeto pedido con el estado devuelto por el servidor
        pedido.estado = EstadoPedido.pagado;
        print('  - Estado actualizado a: ${pedido.estado}');
        print('  - Tipo final confirmado: ${pedido.tipo}');

        // CREAR DOCUMENTO AUTOMÁTICAMENTE DESPUÉS DEL PAGO EXITOSO
        print('📄 Creando documento automático para pedido pagado...');
        print('💰 Método de pago seleccionado: ${formResult['medioPago']}');
        try {
          final documento = await _documentoAutomaticoService
              .generarDocumentoAutomatico(
                pedidoId: pedido.id,
                vendedor: usuarioPago,
                formaPago: formResult['medioPago'],
                propina: propina,
                pagadoPor: usuarioPago,
              );

          if (documento != null) {
            print(
              '✅ Documento automático generado: ${documento.numeroDocumento}',
            );
          }
        } catch (e) {
          print('⚠️ Error generando documento automático: $e');
          // No interrumpir el flujo de pago por error en documento
        }

        // Manejar opciones especiales antes de liberar la mesa
        if (mesaDestinoId != null) {
          // Mover a otra mesa usando la nueva API y actualizar documento
          try {
            final mesasDisponibles = await _mesaService.getMesas();
            final mesaDestino = mesasDisponibles.firstWhere(
              (m) => m.id == mesaDestinoId,
              orElse: () => throw Exception('Mesa destino no encontrada'),
            );

            // Usar la nueva API para mover el pedido
            await _pedidoService.moverPedidoAMesa(
              pedido.id,
              mesaDestino.nombre,
              nombrePedido:
                  mesaDestino.nombre.toUpperCase().contains('DOMICILIO')
                  ? 'Cliente'
                  : null,
            );

            print('🚚 Pedido movido correctamente a ${mesaDestino.nombre}');

            // Actualizar la mesa en el objeto pedido para el documento
            pedido.mesa = mesaDestino.nombre;

            // Generar documento para el movimiento usando el nuevo servicio
            try {
              final documentoMovimiento = await _documentoAutomaticoService
                  .generarDocumentoMovimiento(
                    pedidoId: pedido.id,
                    mesaOrigen: mesa.nombre,
                    mesaDestino: mesaDestino.nombre,
                    vendedor: usuarioPago,
                    formaPago: formResult['medioPago'],
                    propina: propina,
                  );

              if (documentoMovimiento != null) {
                print(
                  '✅ Documento de movimiento generado: ${documentoMovimiento.numeroDocumento}',
                );
              }
            } catch (e) {
              print('⚠️ Error generando documento de movimiento: $e');
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Pedido movido a ${mesaDestino.nombre} y documento actualizado',
                ),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            print('Error moviendo pedido a otra mesa: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error moviendo pedido: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        // Liberar la mesa después del pago exitoso
        try {
          mesa.ocupada = false;
          mesa.productos = [];
          mesa.total = 0.0;
          await _mesaService.updateMesa(mesa);
          print('✅ Mesa ${mesa.nombre} liberada después del pago');
        } catch (e) {
          print('❌ Error al liberar mesa después del pago: $e');
        }

        // Notificar el cambio para actualizar el dashboard
        NotificationService().notificarCambioPedido(pedido);

        // Notificar que se debe actualizar la lista de documentos
        _notificarActualizacionDocumentos(pedido);

        String tipoTexto = '';
        if (esCortesia) tipoTexto = ' (Cortesía)';
        if (esConsumoInterno) tipoTexto = ' (Consumo Interno)';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pedido pagado y documento generado exitosamente$tipoTexto',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadMesas(); // Recargar las mesas

        print('✅ Procesamiento completado exitosamente');
      } catch (e) {
        print('❌ Error en procesamiento: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al procesar el pago: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print('⏭️ Usuario canceló el diálogo');
    }
  }

  /// Actualiza el documento tras mover un pedido entre mesas

  /// Muestra el diálogo de pago parcial para seleccionar productos específicos
  void _mostrarDialogoPagoParcial(Mesa mesa, Pedido pedido) async {
    try {
      // Cargar información completa de productos si es necesario
      await PedidoService().cargarProductosParaPedido(pedido);

      final resultado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PagoParcialDialog(
          pedido: pedido,
          onPagoConfirmado: (itemsSeleccionados, datosPago) async {
            await _procesarPagoParcial(
              mesa,
              pedido,
              itemsSeleccionados,
              datosPago,
            );
          },
        ),
      );

      if (resultado == true) {
        // Recargar datos después del pago parcial exitoso
        _loadMesas();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos del pedido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Procesa el pago parcial de productos seleccionados
  Future<void> _procesarPagoParcial(
    Mesa mesa,
    Pedido pedido,
    List<dynamic> itemsSeleccionados,
    Map<String, dynamic> datosPago,
  ) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Procesar el pago parcial usando el servicio
      final resultado = await _pedidoService.pagarProductosParciales(
        pedido.id,
        itemsSeleccionados: itemsSeleccionados.cast(),
        formaPago: datosPago['formaPago'] ?? 'efectivo',
        propina: datosPago['propina'] ?? 0.0,
        procesadoPor: userProvider.userName ?? 'Usuario',
        notas: 'Pago parcial - Mesa ${mesa.nombre}',
      );

      if (resultado['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Pago parcial procesado exitosamente'),
                Text('Items pagados: ${resultado['itemsPagados']}'),
                Text('Total: ${formatCurrency(resultado['totalPagado'])}'),
                if (datosPago['cambio'] > 0)
                  Text('Cambio: ${formatCurrency(datosPago['cambio'])}'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Navegar al detalle del pedido actualizado si es necesario
        Navigator.of(context).pop(true);
      } else {
        throw Exception('El servidor no confirmó el pago parcial');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al procesar pago parcial: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  /// Muestra el diálogo para cancelar productos del pedido
  void _mostrarDialogoCancelarProductos(Mesa mesa, Pedido pedido) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Cargar información completa de productos si es necesario
      await PedidoService().cargarProductosParaPedido(pedido);

      if (pedido.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No hay productos en este pedido para cancelar'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final resultado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => CancelarProductoDialog(
          items: pedido.items,
          mesaId: mesa.id,
          mesaNombre: mesa.nombre,
          usuarioId: userProvider.userId ?? '',
          usuarioNombre: userProvider.userName ?? 'Usuario',
          onProductosCancelados: (itemsCancelados, motivo) async {
            await _procesarCancelacionProductos(
              mesa,
              pedido,
              itemsCancelados,
              motivo,
            );
          },
        ),
      );

      if (resultado == true) {
        // Recargar datos después de la cancelación exitosa
        _loadMesas();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos del pedido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Procesa la cancelación de productos seleccionados
  Future<void> _procesarCancelacionProductos(
    Mesa mesa,
    Pedido pedido,
    List<ItemPedido> itemsCancelados,
    String motivo,
  ) async {
    try {
      // Por ahora solo mostramos un mensaje de éxito
      // TODO: Implementar la cancelación real en el backend
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Productos cancelados exitosamente'),
              Text('Items cancelados: ${itemsCancelados.length}'),
              Text('Mesa: ${mesa.nombre}'),
              Text('Motivo: $motivo'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Recargar datos de la mesa
      await _loadMesas();

      // Recargar la pantalla principal
      _loadMesas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al procesar cancelación: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  /// Muestra el diálogo para mover productos seleccionados a otra mesa
  void _mostrarDialogoMoverProductos(Mesa mesa, Pedido pedido) async {
    try {
      // Cargar información completa de productos si es necesario
      await PedidoService().cargarProductosParaPedido(pedido);

      if (pedido.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No hay productos en este pedido para mover'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Obtener mesas disponibles
      final mesasDisponibles = await _mesaService.getMesas();
      final mesasDestino = mesasDisponibles
          .where((m) => m.id != mesa.id) // Excluir la mesa actual
          .toList();

      if (mesasDestino.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No hay otras mesas disponibles'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final resultado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => MoverProductosDialog(
          items: pedido.items,
          mesaOrigen: mesa,
          mesasDestino: mesasDestino,
          onProductosMovidos: (itemsMovidos, mesaDestino) async {
            await _procesarMovimientoProductos(
              mesa,
              pedido,
              itemsMovidos,
              mesaDestino,
            );
          },
        ),
      );

      if (resultado == true) {
        // Recargar datos después del movimiento exitoso
        _loadMesas();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos del pedido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Procesa el movimiento de productos seleccionados a otra mesa
  Future<void> _procesarMovimientoProductos(
    Mesa mesaOrigen,
    Pedido pedidoOrigen,
    List<dynamic> itemsMovidos,
    Mesa mesaDestino,
  ) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final usuario = userProvider.userName ?? 'Usuario';

      // Mover productos usando el servicio
      final resultado = await _pedidoService.moverProductosEspecificos(
        pedidoOrigenId: pedidoOrigen.id,
        mesaDestinoNombre: mesaDestino.nombre,
        itemsParaMover: itemsMovidos.cast(),
        usuarioId: userProvider.userId ?? '',
        usuarioNombre: usuario,
      );

      if (resultado['success'] == true) {
        // Verificar si se debe crear una orden automáticamente
        final bool seCreoNuevaOrden = resultado['nuevaOrdenCreada'] ?? false;

        String mensaje =
            '✅ Productos movidos exitosamente a ${mesaDestino.nombre}';
        if (seCreoNuevaOrden) {
          mensaje += '\n🆕 Nueva orden creada automáticamente';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mensaje),
                Text('Items movidos: ${itemsMovidos.length}'),
                Text('De: ${mesaOrigen.nombre} → A: ${mesaDestino.nombre}'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Recargar la pantalla principal
        _loadMesas();
      } else {
        throw Exception(resultado['message'] ?? 'Error desconocido');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al mover productos: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  /// Crea una factura/documento para un pedido en una mesa específica
  Future<void> _crearFacturaPedidoEnMesa(
    String pedidoId,
    String mesaNombre, {
    String? formaPago,
    double? propina,
    String? pagadoPor,
  }) async {
    try {
      print('📄 Creando documento para pedido $pedidoId en mesa $mesaNombre');

      // Obtener el usuario actual si no se especifica
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final vendedor = pagadoPor ?? userProvider.userName ?? 'Sistema';

      // Validar forma de pago
      String formapagoValidada = formaPago ?? 'efectivo';
      if (formapagoValidada != 'efectivo' &&
          formapagoValidada != 'transferencia') {
        formapagoValidada = 'efectivo';
      }

      // Crear documento usando el servicio
      final documento = await _documentoMesaService.crearDocumento(
        mesaNombre: mesaNombre,
        vendedor: vendedor,
        pedidosIds: [pedidoId],
        formaPago: formapagoValidada,
        pagadoPor: vendedor,
        propina: propina ?? 0.0,
        pagado: true,
        estado: 'Pagado',
        fechaPago: DateTime.now(),
      );

      if (documento != null) {
        print(
          '✅ Documento creado en mesa $mesaNombre: ${documento.numeroDocumento}',
        );
      } else {
        throw Exception('No se pudo crear el documento');
      }
    } catch (e) {
      print('❌ Error creando documento en mesa específica: $e');
      throw e;
    }
  }

  // Notificar actualización de documentos
  Future<void> _notificarActualizacionDocumentos(Pedido pedido) async {
    try {
      print(
        '📄 Notificando actualización de documentos para pedido: ${pedido.id}',
      );

      // Aquí puedes agregar lógica adicional si necesitas comunicación
      // entre pantallas para actualizar los documentos en tiempo real

      // Por ejemplo, usando un EventBus o Stream si lo tienes configurado
      // EventBus().fire(DocumentoActualizadoEvent(pedido.id));
    } catch (e) {
      print('❌ Error notificando actualización de documentos: $e');
    }
  }

  // Método para mostrar resumen e imprimir factura
  void _mostrarResumenImpresion(Pedido pedido) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        content: Row(
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(width: 20),
            Text(
              'Generando resumen de impresión...',
              style: TextStyle(color: _textPrimary),
            ),
          ],
        ),
      ),
    );

    try {
      // Generar resumen desde el backend usando el nuevo endpoint
      var resumenNullable = await _impresionService.generarResumenPedido(
        pedido.id,
      );

      if (resumenNullable == null) {
        // Cerrar diálogo de carga
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo generar el resumen del pedido'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Actualizar resumen con información del negocio
      final resumen = await actualizarConInfoNegocio(resumenNullable);

      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      // Mostrar diálogo con resumen - trabajando directamente con los datos del endpoint
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Resumen del Pedido',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: _textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(color: _textMuted),
                  SizedBox(height: 16),

                  // Información del restaurante
                  _buildSeccionResumen('RESTAURANTE', [
                    resumen['nombreRestaurante'] ?? 'SOPA Y CARBÓN',
                    resumen['direccionRestaurante'] ??
                        'Dirección del restaurante',
                    'Tel: ${resumen['telefonoRestaurante'] ?? 'Teléfono'}',
                  ]),

                  // Información del pedido
                  _buildSeccionResumen('INFORMACIÓN DEL PEDIDO', [
                    'Pedido: ${resumen['pedidoId'] ?? 'N/A'}',
                    'Fecha: ${resumen['fecha'] ?? 'N/A'}',
                    'Hora: ${resumen['hora'] ?? 'N/A'}',
                    if (resumen['mesa'] != null) 'Mesa: ${resumen['mesa']}',
                    if (resumen['mesero'] != null)
                      'Mesero: ${resumen['mesero']}',
                    if (resumen['tipo'] != null) 'Tipo: ${resumen['tipo']}',
                  ]),

                  // Detalle de productos
                  Text(
                    'DETALLE DE PRODUCTOS:',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),

                  Container(
                    constraints: BoxConstraints(maxHeight: 350),
                    child: SingleChildScrollView(
                      child: Column(
                        children: (resumen['productos'] as List? ?? [])
                            .map<Widget>(
                              (producto) =>
                                  _buildProductoItemConIngredientes(producto),
                            )
                            .toList(),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),
                  Divider(color: _textMuted),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL:',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${(resumen['total'] ?? 0.0).toStringAsFixed(0)}',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _imprimirResumenPedido(resumen);
                        },
                        icon: Icon(Icons.print, size: 18),
                        label: Text('Imprimir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _mostrarOpcionesCompartir(resumen);
                        },
                        icon: Icon(Icons.share, size: 18),
                        label: Text('Compartir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context); // Cerrar diálogo actual

                          // Solicitar información de pago antes de crear la factura
                          final formResult = await _mostrarDialogoSimplePago();

                          if (formResult != null) {
                            await _crearFacturaPedido(
                              resumen['pedidoId'],
                              formaPago: formResult['medioPago'],
                              propina: formResult['propina'] ?? 0.0,
                              pagadoPor: formResult['pagadoPor'],
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Factura creada exitosamente'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.receipt_long, size: 18),
                        label: Text('Facturar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando resumen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Notificar actualización de documentos
  Future<void> notificarActualizacionDocumentos(Pedido pedido) async {
    try {
      print(
        '📄 Notificando actualización de documentos para pedido: ${pedido.id}',
      );

      // Aquí puedes agregar lógica adicional si necesitas comunicación
      // entre pantallas para actualizar los documentos en tiempo real

      // Por ejemplo, usando un EventBus o Stream si lo tienes configurado
      // EventBus().fire(DocumentoActualizadoEvent(pedido.id));
    } catch (e) {
      print('❌ Error notificando actualización de documentos: $e');
    }
  }

  Future<Mesa?> mostrarDialogoSeleccionMesa() async {
    try {
      // Cargar la lista de mesas disponibles
      final mesas = await _mesaService.getMesas();

      // Filtrar mesas especiales y la mesa actual
      final mesasDisponibles = mesas
          .where(
            (mesa) => ![
              'DOMICILIO',
              'CAJA',
              'MESA AUXILIAR',
            ].contains(mesa.nombre.toUpperCase()),
          )
          .toList();

      if (mesasDisponibles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No hay otras mesas disponibles'),
            backgroundColor: Colors.orange,
          ),
        );
        return null;
      }

      // Mostrar diálogo de selección
      final mesaSeleccionada = await showDialog<Mesa>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: _cardBg,
            title: Text(
              'Seleccionar mesa destino',
              style: TextStyle(color: _textPrimary),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: mesasDisponibles.length,
                itemBuilder: (context, index) {
                  final mesa = mesasDisponibles[index];
                  return ListTile(
                    title: Text(
                      mesa.nombre,
                      style: TextStyle(color: _textPrimary),
                    ),
                    subtitle: Text(
                      mesa.ocupada ? 'Ocupada' : 'Libre',
                      style: TextStyle(
                        color: mesa.ocupada ? Colors.orange : Colors.green,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(mesa),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancelar', style: TextStyle(color: _textPrimary)),
              ),
            ],
          );
        },
      );

      return mesaSeleccionada;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar las mesas: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  // Método para mostrar resumen e imprimir factura
  void mostrarResumenImpresion(Pedido pedido) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        content: Row(
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(width: 20),
            Text(
              'Generando resumen de impresión...',
              style: TextStyle(color: _textPrimary),
            ),
          ],
        ),
      ),
    );

    try {
      // Generar resumen desde el backend usando el nuevo endpoint
      var resumenNullable = await _impresionService.generarResumenPedido(
        pedido.id,
      );

      if (resumenNullable == null) {
        // Cerrar diálogo de carga
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo generar el resumen del pedido'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Actualizar resumen con información del negocio
      final resumen = await actualizarConInfoNegocio(resumenNullable);

      // Cerrar diálogo de carga
      Navigator.of(context).pop();

      // Mostrar diálogo con resumen - trabajando directamente con los datos del endpoint
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Resumen del Pedido',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: _textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(color: _textMuted),
                  SizedBox(height: 16),

                  // Información del restaurante
                  _buildSeccionResumen('RESTAURANTE', [
                    resumen['nombreRestaurante'] ?? 'SOPA Y CARBÓN',
                    resumen['direccionRestaurante'] ??
                        'Dirección del restaurante',
                    'Tel: ${resumen['telefonoRestaurante'] ?? 'Teléfono'}',
                  ]),

                  // Información del pedido
                  _buildSeccionResumen('INFORMACIÓN DEL PEDIDO', [
                    'Pedido: ${resumen['pedidoId'] ?? 'N/A'}',
                    'Fecha: ${resumen['fecha'] ?? 'N/A'}',
                    'Hora: ${resumen['hora'] ?? 'N/A'}',
                    if (resumen['mesa'] != null) 'Mesa: ${resumen['mesa']}',
                    if (resumen['mesero'] != null)
                      'Mesero: ${resumen['mesero']}',
                    if (resumen['tipo'] != null) 'Tipo: ${resumen['tipo']}',
                  ]),

                  // Detalle de productos
                  Text(
                    'DETALLE DE PRODUCTOS:',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),

                  Container(
                    constraints: BoxConstraints(maxHeight: 350),
                    child: SingleChildScrollView(
                      child: Column(
                        children: (resumen['productos'] as List? ?? [])
                            .map<Widget>(
                              (producto) =>
                                  _buildProductoItemConIngredientes(producto),
                            )
                            .toList(),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),
                  Divider(color: _textMuted),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL:',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${(resumen['total'] ?? 0.0).toStringAsFixed(0)}',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _imprimirResumenPedido(resumen);
                        },
                        icon: Icon(Icons.print, size: 18),
                        label: Text('Imprimir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _mostrarOpcionesCompartir(resumen);
                        },
                        icon: Icon(Icons.share, size: 18),
                        label: Text('Compartir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _marcarComoDeuda(resumen);
                        },
                        icon: Icon(Icons.account_balance_wallet, size: 18),
                        label: Text('Debe'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando resumen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para compartir pedido
  @override
  Future<void> compartirPedido(Map<String, dynamic> resumen) async {
    try {
      final textoImpresion = _impresionService.generarTextoImpresion(resumen);
      await Share.share(
        textoImpresion,
        subject: 'Resumen de Pedido - ${resumen['pedidoId']}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error compartiendo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para imprimir documento (real)
  @override
  Future<void> imprimirDocumento(Map<String, dynamic> resumen) async {
    try {
      if (kIsWeb) {
        // Para web, ir directamente a imprimir
        final pdfServiceWeb = PDFServiceFactory.create();
        try {
          pdfServiceWeb.abrirVentanaImpresion(resumen: resumen);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Abriendo ventana de impresión...'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al abrir impresión: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          content: Row(
            children: [
              CircularProgressIndicator(color: _primary),
              SizedBox(width: 20),
              Text(
                'Enviando a impresora...',
                style: TextStyle(color: _textPrimary),
              ),
            ],
          ),
        ),
      );

      final textoImpresion = _impresionService.generarTextoImpresion(resumen);

      // Mostrar opciones de impresión
      Navigator.of(context).pop(); // Cerrar diálogo de carga

      // Mostrar diálogo con opciones de impresión
      await mostrarOpcionesImpresion(textoImpresion, resumen);
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar diálogo de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparando impresión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Mostrar opciones de impresión
  @override
  Future<void> mostrarOpcionesImpresion(
    String contenido,
    Map<String, dynamic> resumen,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Opciones de Impresión',
          style: TextStyle(color: _textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Cómo deseas imprimir este documento?',
              style: TextStyle(color: _textPrimary),
            ),
            SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await abrirDialogoImpresionNativo(contenido, resumen);
            },
            icon: Icon(Icons.print),
            label: Text('Imprimir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await guardarYAbrir(contenido);
            },
            icon: Icon(Icons.open_in_new),
            label: Text('Abrir con Notepad'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await compartirPedido(resumen);
            },
            icon: Icon(Icons.share),
            label: Text('Compartir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> mostrarOpcionesArchivo(File archivo, String tipo) async {
    final fileName = archivo.path.split('\\').last;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('$tipo Generado', style: TextStyle(color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Archivo guardado como:',
              style: TextStyle(color: _textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              fileName,
              style: TextStyle(
                color:
                    Colors.black87, // TODO: Usar _textDark cuando esté definido
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text('Opciones:', style: TextStyle(color: _textPrimary)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              copiarRutaAlPortapapeles(archivo.path);
            },
            icon: Icon(Icons.copy, color: _primary),
            label: Text('Copiar Ruta', style: TextStyle(color: _primary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              intentarAbrirArchivo(archivo.path);
            },
            icon: Icon(Icons.open_in_new),
            label: Text('Abrir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> copiarRutaAlPortapapeles(String ruta) async {
    try {
      await Clipboard.setData(ClipboardData(text: ruta));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📋 Ruta copiada al portapapeles'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error copiando ruta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> intentarAbrirArchivo(String rutaArchivo) async {
    try {
      // Mostrar instrucciones al usuario
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          title: Text('Abrir Archivo', style: TextStyle(color: _textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El archivo se encuentra en:',
                style: TextStyle(color: _textPrimary),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _cardBg.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  rutaArchivo,
                  style: TextStyle(
                    color: Colors
                        .black87, // TODO: Usar _textDark cuando esté definido
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Para abrir el archivo:',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '1. Navega a la carpeta Downloads',
                style: TextStyle(color: _textPrimary),
              ),
              Text(
                '2. Busca el archivo y ábrelo con tu aplicación preferida',
                style: TextStyle(color: _textPrimary),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'La ruta ya fue copiada al portapapeles',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Entendido', style: TextStyle(color: _primary)),
            ),
          ],
        ),
      );

      // Copiar automáticamente la ruta al portapapeles
      await copiarRutaAlPortapapeles(rutaArchivo);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<Uint8List> generarPDFTicket(
    String contenido,
    Map<String, dynamic> resumen,
  ) async {
    final pdf = pw.Document();

    // Dividir el contenido en líneas
    final lineas = contenido.split('\n');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.all(8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: lineas.map((linea) {
              // Diferentes estilos según el contenido de la línea
              if (linea.contains('=====')) {
                return pw.Text(
                  linea,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                );
              } else if (linea.contains('TOTAL') || linea.contains('Total')) {
                return pw.Text(
                  linea,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                );
              } else {
                return pw.Text(linea, style: pw.TextStyle(fontSize: 8));
              }
            }).toList(),
          );
        },
      ),
    );

    return pdf.save();
  }

  // Generar PDF y mostrarlo al usuario
  Future<void> abrirDialogoImpresionNativo(
    String contenido,
    Map<String, dynamic> resumen,
  ) async {
    try {
      if (kIsWeb) {
        // Para web, usar el servicio web
        final pdfServiceWeb = PDFServiceFactory.create();
        pdfServiceWeb.abrirVentanaImpresion(resumen: resumen);
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          content: Row(
            children: [
              CircularProgressIndicator(color: _primary),
              SizedBox(width: 20),
              Text(
                'Generando documento PDF...',
                style: TextStyle(color: _textPrimary),
              ),
            ],
          ),
        ),
      );

      // Generar PDF
      final pdfBytes = await generarPDFTicket(contenido, resumen);

      // Guardar archivo PDF
      final tempDir = Directory.systemTemp;
      final pdfFile = File(
        '${tempDir.path}/ticket_${resumen['pedidoId'] ?? DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      await pdfFile.writeAsBytes(pdfBytes);

      Navigator.of(context).pop(); // Cerrar diálogo de carga

      // Mostrar opciones para el archivo generado
      await mostrarOpcionesArchivo(pdfFile, 'PDF');
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar diálogo de carga si hay error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generando PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Error completo: $e');
    }
  }

  // Método para guardar archivo y mostrarlo al usuario
  Future<void> guardarYAbrir(String contenido) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          content: Row(
            children: [
              CircularProgressIndicator(color: _primary),
              SizedBox(width: 20),
              Text(
                'Generando documento de texto...',
                style: TextStyle(color: _textPrimary),
              ),
            ],
          ),
        ),
      );

      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/ticket_${DateTime.now().millisecondsSinceEpoch}.txt',
      );

      await tempFile.writeAsString(contenido, encoding: utf8);

      Navigator.of(context).pop();

      // Mostrar opciones para el archivo de texto
      await mostrarOpcionesArchivo(tempFile, 'Texto');
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error generando documento: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Obtener el conteo de documentos del día actual
  Future<int> obtenerConteoDocumentosHoy() async {
    try {
      // TODO: Implement with FacturaService
      // final hoy = DateTime.now();
      // final fechaHoy =
      //     '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';

      // final documentos = await _facturaService.getFacturas();
      // return documentos.length;

      return 0; // Placeholder until proper implementation
    } catch (e) {
      print('❌ Error obteniendo conteo de documentos: $e');
      return 0;
    }
  }

  // Navegar a la pantalla de documentos
  Future<void> navegarADocumentos() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Verificar que el usuario no sea únicamente mesero
      if (userProvider.isOnlyMesero) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No tienes permisos para acceder a documentos'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Navegar a la pantalla de documentos
      if (mounted) {
        await Navigator.of(context).pushNamed('/documentos');
        // Al regresar, actualizar las mesas por si hubo cambios
        await _loadMesas();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error navegando a documentos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Mostrar opciones después de crear una factura
  Future<void> mostrarOpcionesPostFacturacion(
    Map<String, dynamic> factura,
  ) async {
    await Future.delayed(
      Duration(seconds: 2),
    ); // Esperar un poco para que el usuario lea el mensaje

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Factura Creada Exitosamente',
          style: TextStyle(color: _textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              'Factura ${factura['numero']} ha sido creada correctamente.',
              style: TextStyle(color: _textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Total: \$${factura['total']?.toStringAsFixed(0) ?? '0'}',
              style: TextStyle(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await navegarADocumentos();
            },
            icon: Icon(Icons.receipt_long),
            label: Text('Ver Todos los Documentos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await compartirFactura(factura);
            },
            icon: Icon(Icons.share),
            label: Text('Compartir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Método para mostrar resumen de factura
  void mostrarResumenFactura(Map<String, dynamic> factura) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Factura Generada', style: TextStyle(color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Número: ${factura['numero']}',
              style: TextStyle(color: _textPrimary, fontSize: 16),
            ),
            Text(
              'Total: \$${factura['total'].toStringAsFixed(0)}',
              style: TextStyle(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await compartirFactura(factura);
            },
            child: Text('Compartir Factura'),
          ),
        ],
      ),
    );
  }

  // Método para compartir factura
  Future<void> compartirFactura(Map<String, dynamic> factura) async {
    try {
      final textoFactura = _impresionService.generarTextoImpresion(
        factura,
        esFactura: true,
      );
      await Share.share(textoFactura, subject: 'Factura ${factura['numero']}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error compartiendo factura: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Métodos helper para responsive design
  double getResponsiveCardWidth(double screenWidth) {
    if (screenWidth < 600) return 110; // Móvil
    if (screenWidth < 900) return 140; // Tablet
    return 160; // Desktop
  }

  double getResponsiveCardHeight(double screenWidth) {
    if (screenWidth < 600)
      return 140; // Móvil (aumentado para el botón de pago)
    if (screenWidth < 900) return 150; // Tablet
    return 160; // Desktop
  }

  double getResponsiveMargin(double screenWidth) {
    if (screenWidth < 600) return 8; // Móvil
    if (screenWidth < 900) return 12; // Tablet
    return 16; // Desktop
  }

  double getResponsiveFontSize(double screenWidth, double baseSize) {
    if (screenWidth < 600) return baseSize * 0.9; // Móvil
    if (screenWidth < 900) return baseSize; // Tablet
    return baseSize * 1.1; // Desktop
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Mesas', style: AppTheme.headlineMedium),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Botón para mostrar resumen rápido de documentos del día - Solo para no-meseros
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              // Ocultar el botón para meseros únicamente
              if (userProvider.isOnlyMesero) {
                return SizedBox.shrink();
              }

              return Container(
                margin: EdgeInsets.only(right: AppTheme.spacingSmall),
                child: IconButton(
                  icon: Stack(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                        child: Icon(Icons.receipt_long, size: 20),
                      ),
                      FutureBuilder<int>(
                        future: obtenerConteoDocumentosHoy(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data! > 0) {
                            return Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSmall,
                                  ),
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  '${snapshot.data}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }
                          return SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  tooltip: 'Ver documentos del día',
                  onPressed: () => navegarADocumentos(),
                ),
              );
            },
          ),
          // Botón "Mis Pedidos" - Solo para meseros
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              // Mostrar el botón solo para meseros
              if (!userProvider.isMesero) {
                return SizedBox.shrink();
              }

              return Container(
                margin: EdgeInsets.only(right: AppTheme.spacingSmall),
                child: IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Icon(Icons.receipt_long, size: 20),
                  ),
                  tooltip: 'Mis Pedidos',
                  onPressed: () {
                    Navigator.pushNamed(context, '/mesero');
                  },
                ),
              );
            },
          ),
          // Botón de zoom - Solo en móvil
          if (MediaQuery.of(context).size.width < 600) ...[
            Container(
              margin: EdgeInsets.only(right: AppTheme.spacingSmall),
              child: IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    _zoomScale < 1.0 ? Icons.zoom_in : Icons.zoom_out,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    if (_zoomScale <= 0.8) {
                      _zoomScale = 1.0; // Reset a tamaño normal
                    } else {
                      _zoomScale = 0.8; // Zoom out para ver más mesas
                    }
                  });
                },
                tooltip: _zoomScale < 1.0 ? 'Acercar vista' : 'Alejar vista',
              ),
            ),
          ],
          Container(
            margin: EdgeInsets.only(right: AppTheme.spacingSmall),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(Icons.refresh, size: 20),
              ),
              onPressed: _loadMesas,
              tooltip: 'Actualizar mesas',
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.spacingLarge),
                    decoration: AppTheme.cardDecoration,
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingLarge),
                  Text('Cargando mesas...', style: AppTheme.bodyLarge),
                ],
              ),
            )
          : errorMessage != null
          ? Center(
              child: Container(
                margin: EdgeInsets.all(AppTheme.spacingLarge),
                padding: EdgeInsets.all(AppTheme.spacingXLarge),
                decoration: AppTheme.elevatedCardDecoration.copyWith(
                  border: Border.all(
                    color: AppTheme.error.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingMedium),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.error_outline,
                        color: AppTheme.error,
                        size: 48,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingLarge),
                    Text(
                      'Error al cargar mesas',
                      style: AppTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppTheme.spacingMedium),
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingMedium),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                      ),
                      child: Text(
                        errorMessage!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingLarge),
                    ElevatedButton(
                      onPressed: _loadMesas,
                      style: AppTheme.primaryButtonStyle,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 20),
                          SizedBox(width: AppTheme.spacingSmall),
                          Text('Reintentar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : buildMesasLayout(),
    );
  }

  Widget buildMesasLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Detectar si es móvil usando el breakpoint establecido
        bool isMobile = constraints.maxWidth < 768;

        return Transform.scale(
          scale: _zoomScale,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.responsivePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mesas especiales en la parte superior
                buildMesasEspeciales(),
                SizedBox(
                  height: isMobile ? 40 : AppTheme.spacingXLarge,
                ), // Más espacio en móvil
                // Vista responsiva para mesas regulares
                if (isMobile) _buildMobileMesasView() else buildMesasPorFilas(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileMesasView() {
    // Organizar mesas por letras (igual que en escritorio)
    Map<String, List<Mesa>> mesasPorLetra = {};

    for (Mesa mesa in mesas) {
      if (mesa.nombre.isNotEmpty) {
        String letra = mesa.nombre[0].toUpperCase();
        // Filtrar solo las mesas regulares (no especiales)
        if (![
          'DOMICILIO',
          'CAJA',
          'MESA AUXILIAR',
        ].contains(mesa.nombre.toUpperCase())) {
          if (mesasPorLetra[letra] == null) {
            mesasPorLetra[letra] = [];
          }
          mesasPorLetra[letra]!.add(mesa);
        }
      }
    }

    // Ordenar las letras alfabéticamente
    List<String> letrasOrdenadas = mesasPorLetra.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: AppTheme.spacingMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: letrasOrdenadas.map((letra) {
          List<Mesa> mesasDeLaLetra = mesasPorLetra[letra]!;

          // Ordenar las mesas de cada letra por número
          mesasDeLaLetra.sort((a, b) {
            int numeroA = int.tryParse(a.nombre.substring(1)) ?? 0;
            int numeroB = int.tryParse(b.nombre.substring(1)) ?? 0;

            // Convertir 0 a 10 para que vaya al final
            if (numeroA == 0) numeroA = 10;
            if (numeroB == 0) numeroB = 10;

            return numeroA.compareTo(numeroB);
          });

          return Container(
            margin: EdgeInsets.only(right: AppTheme.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Título de la columna (letra)
                Container(
                  margin: EdgeInsets.only(bottom: AppTheme.spacingMedium),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMedium,
                    vertical: AppTheme.spacingSmall,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: AppTheme.primaryShadow,
                  ),
                  child: Text(
                    'Fila $letra',
                    style: AppTheme.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16, // Tamaño reducido para móvil
                    ),
                  ),
                ),
                // Mesas de la letra organizadas verticalmente
                Column(
                  children: mesasDeLaLetra
                      .map(
                        (mesa) => Container(
                          width: 140, // Ancho fijo para móvil
                          height: 140, // Altura aumentada para móvil
                          margin: EdgeInsets.only(
                            bottom: AppTheme.spacingMedium,
                          ),
                          child: _buildMesaCard(mesa),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  double getResponsivePadding(double screenWidth) {
    if (screenWidth < 600) return 12; // Móvil
    if (screenWidth < 900) return 16; // Tablet
    return 20; // Desktop
  }

  Widget buildMesasEspeciales() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Detectar si es móvil usando el breakpoint establecado
        bool isMobile = constraints.maxWidth < 768;

        if (isMobile) {
          // Vista móvil: diseño horizontal con scroll
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
            child: Row(
              children: [
                _buildMesaEspecialMobile(
                  'Domicilio',
                  Icons.delivery_dining,
                  'disponible',
                  () => _navegarAPedido('Domicilio'),
                ),
                SizedBox(
                  width: AppTheme.spacingLarge,
                ), // Más espacio entre mesas
                _buildMesaEspecialMobile(
                  'Caja',
                  Icons.point_of_sale,
                  'disponible',
                  () => _navegarAPedido('Caja'),
                ),
                SizedBox(
                  width: AppTheme.spacingLarge,
                ), // Más espacio entre mesas
                _buildMesaEspecialMobile(
                  'Mesa Auxiliar',
                  Icons.table_restaurant,
                  'disponible',
                  () => _navegarAPedido('Mesa Auxiliar'),
                ),
              ],
            ),
          );
        } else {
          // Vista desktop/tablet: diseño original en filas
          double especialHeight = context.isTablet ? 120 : 140;

          return Column(
            children: [
              // Primera fila: Domicilio y Caja
              Row(
                children: [
                  Expanded(
                    child: buildMesaEspecial(
                      'Domicilio',
                      Icons.delivery_dining,
                      'disponible',
                      () => _navegarAPedido('Domicilio'),
                      height: especialHeight,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingMedium),
                  Expanded(
                    child: buildMesaEspecial(
                      'Caja',
                      Icons.point_of_sale,
                      'disponible',
                      () => _navegarAPedido('Caja'),
                      height: especialHeight,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spacingMedium),
              // Segunda fila: Mesa Auxiliar
              Row(
                children: [
                  Expanded(
                    child: buildMesaEspecial(
                      'Mesa Auxiliar',
                      Icons.table_restaurant,
                      'disponible',
                      () => _navegarAPedido('Mesa Auxiliar'),
                      height: especialHeight,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildMesaEspecialMobile(
    String nombre,
    IconData icono,
    String estado,
    VoidCallback onTap,
  ) {
    return FutureBuilder<List<Pedido>>(
      future: _pedidoService.getPedidosByMesa(nombre),
      builder: (context, snapshot) {
        List<Pedido> pedidosActivos = [];
        if (snapshot.hasData) {
          pedidosActivos = snapshot.data!
              .where((pedido) => pedido.estado == EstadoPedido.activo)
              .toList();
        }

        // Determinar el estado basado en pedidos activos
        bool tienePedidos = pedidosActivos.isNotEmpty;
        Color statusColor = tienePedidos ? AppTheme.error : AppTheme.success;
        String estadoTexto = tienePedidos
            ? '${pedidosActivos.length} pedido${pedidosActivos.length > 1 ? 's' : ''}'
            : 'Disponible';

        // Calcular total de todos los pedidos activos
        double totalGeneral = pedidosActivos.fold(
          0.0,
          (sum, pedido) => sum + pedido.total,
        );

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 130, // Ancho reducido para móvil
            height: 110, // Altura reducida para móvil
            decoration: AppTheme.cardDecoration.copyWith(
              gradient: tienePedidos
                  ? LinearGradient(
                      colors: [AppTheme.cardBg, AppTheme.cardElevated],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: Border.all(
                color: tienePedidos
                    ? AppTheme.primary.withOpacity(0.5)
                    : AppTheme.success.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(6), // Padding reducido
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Icono principal
                  Container(
                    padding: EdgeInsets.all(6), // Padding reducido
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.primaryShadow,
                    ),
                    child: Icon(
                      icono,
                      color: AppTheme.primary,
                      size: 16, // Ícono más pequeño
                    ),
                  ),
                  // Nombre de la mesa especial
                  Text(
                    nombre,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyLarge.copyWith(
                      fontSize: 10, // Texto más pequeño
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Estado
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            estadoTexto,
                            style: AppTheme.labelMedium.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Total si existe
                  if (totalGeneral > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                      ),
                      child: Text(
                        '\$${totalGeneral.toStringAsFixed(0)}',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildMesaEspecial(
    String nombre,
    IconData icono,
    String estado,
    VoidCallback onTap, {
    required double height,
  }) {
    return FutureBuilder<List<Pedido>>(
      future: _pedidoService.getPedidosByMesa(nombre),
      builder: (context, snapshot) {
        List<Pedido> pedidosActivos = [];
        if (snapshot.hasData) {
          pedidosActivos = snapshot.data!
              .where((pedido) => pedido.estado == EstadoPedido.activo)
              .toList();
        }

        // Determinar el estado basado en pedidos activos
        bool tienePedidos = pedidosActivos.isNotEmpty;
        Color statusColor = tienePedidos ? AppTheme.error : AppTheme.success;
        String estadoTexto = tienePedidos
            ? '${pedidosActivos.length} pedido${pedidosActivos.length > 1 ? 's' : ''}'
            : 'Disponible';

        // Calcular total de todos los pedidos activos
        double totalGeneral = pedidosActivos.fold(
          0.0,
          (sum, pedido) => sum + pedido.total,
        );

        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: height,
            decoration: AppTheme.cardDecoration.copyWith(
              gradient: tienePedidos
                  ? LinearGradient(
                      colors: [AppTheme.cardBg, AppTheme.cardElevated],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: Border.all(
                color: tienePedidos
                    ? AppTheme.primary.withOpacity(0.5)
                    : AppTheme.success.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(
                context.isMobile
                    ? AppTheme.spacingSmall
                    : AppTheme.spacingMedium,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment
                    .spaceAround, // Cambiar de spaceEvenly a spaceAround para mejor distribución
                children: [
                  // Icono principal
                  Container(
                    padding: EdgeInsets.all(context.isMobile ? 8 : 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.primaryShadow,
                    ),
                    child: Icon(
                      icono,
                      color: AppTheme.primary,
                      size: context.isMobile
                          ? 20
                          : context.isTablet
                          ? 24
                          : 28,
                    ),
                  ),
                  // Nombre de la mesa especial
                  Flexible(
                    child: Text(
                      nombre,
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyLarge.copyWith(
                        fontSize: context.isMobile
                            ? 12 // Reducir tamaño para móvil
                            : context.isTablet
                            ? 14
                            : 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Estado
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSmall,
                      vertical: AppTheme.spacingXSmall,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: AppTheme.spacingXSmall),
                        Flexible(
                          child: Text(
                            estadoTexto,
                            style: AppTheme.labelMedium.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Total si existe
                  if (totalGeneral > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSmall,
                        vertical: AppTheme.spacingXSmall,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                      ),
                      child: Text(
                        '\$${totalGeneral.toStringAsFixed(0)}',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double getResponsiveEspecialHeight(double screenWidth) {
    if (screenWidth < 600) return 70; // Móvil
    if (screenWidth < 900) return 80; // Tablet
    return 90; // Desktop
  }

  double getResponsiveIconSize(double screenWidth) {
    if (screenWidth < 600) return 14; // Móvil
    if (screenWidth < 900) return 16; // Tablet
    return 18; // Desktop
  }

  Widget buildMesasPorFilas() {
    // Organizar mesas por LETRAS (A, B, C, D, E) - cada letra es una columna
    Map<String, List<Mesa>> mesasPorLetra = {};

    for (Mesa mesa in mesas) {
      if (mesa.nombre.isNotEmpty) {
        String letra = mesa.nombre[0].toUpperCase();
        // Filtrar solo las mesas regulares (no especiales)
        if (![
          'DOMICILIO',
          'CAJA',
          'MESA AUXILIAR',
        ].contains(mesa.nombre.toUpperCase())) {
          if (mesasPorLetra[letra] == null) {
            mesasPorLetra[letra] = [];
          }
          mesasPorLetra[letra]!.add(mesa);
        }
      }
    }

    // Ordenar las letras alfabéticamente (A, B, C, D, E)
    List<String> letrasOrdenadas = mesasPorLetra.keys.toList()..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tamaños responsivos usando AppTheme y extension
        double cardWidth = context.isMobile
            ? 90
            : context.isTablet
            ? 110
            : 130;
        double cardHeight = context.isMobile
            ? 140
            : context.isTablet
            ? 160
            : 180;

        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSmall,
              vertical: AppTheme.spacingMedium,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: letrasOrdenadas.map((letra) {
                List<Mesa> mesasDeLaLetra = mesasPorLetra[letra]!;

                // Ordenar las mesas de cada letra por NÚMERO (1, 2, 3...10)
                mesasDeLaLetra.sort((a, b) {
                  int numeroA = int.tryParse(a.nombre.substring(1)) ?? 0;
                  int numeroB = int.tryParse(b.nombre.substring(1)) ?? 0;

                  // Convertir 0 a 10 para que vaya al final
                  if (numeroA == 0) numeroA = 10;
                  if (numeroB == 0) numeroB = 10;

                  return numeroA.compareTo(numeroB);
                });

                return Container(
                  margin: EdgeInsets.only(right: AppTheme.spacingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Título de la columna (letra) mejorado
                      Container(
                        margin: EdgeInsets.only(bottom: AppTheme.spacingMedium),
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMedium,
                          vertical: AppTheme.spacingSmall,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                          boxShadow: AppTheme.primaryShadow,
                        ),
                        child: Text(
                          'Fila $letra',
                          style: AppTheme.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: context.responsiveFontSize + 2,
                          ),
                        ),
                      ),
                      // Mesas de la letra organizadas verticalmente
                      Column(
                        children: mesasDeLaLetra
                            .map(
                              (mesa) => Container(
                                width: cardWidth,
                                height: cardHeight,
                                margin: EdgeInsets.only(
                                  bottom: AppTheme.spacingMedium,
                                ),
                                child: _buildMesaCard(mesa),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void editarPedidoExistente(Mesa mesa, Pedido pedido) {
    // Logging detallado para debug
    print('🔍 Editando pedido existente:');
    print('  - ID: ${pedido.id}');
    print('  - Mesa: ${mesa.nombre}');
    print('  - Estado: ${pedido.estado}');
    print('  - Total: ${pedido.total}');
    print('  - Items: ${pedido.items.length}');

    // Imprimir los primeros items para diagnóstico
    if (pedido.items.isNotEmpty) {
      print('📝 Detalles de los primeros items:');
      for (var i = 0; i < pedido.items.length && i < 3; i++) {
        final item = pedido.items[i];
        print('  Item ${i + 1}:');
        print('    - ProductoID: ${item.productoId}');
        print('    - Nombre: ${item.productoNombre ?? 'Producto'}');
        print('    - Cantidad: ${item.cantidad}');
        print('    - Precio: ${item.precioUnitario}');
      }
    }

    // Navega a la pantalla de PedidoScreen pasando tanto la mesa como el pedido existente
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PedidoScreen(
          mesa: mesa,
          pedidoExistente: pedido, // Pasamos el pedido existente para editarlo
        ),
      ),
    ).then((_) {
      // Recargar las mesas cuando regrese de la pantalla de pedido
      _loadMesas();
    });
  }

  Future<void> mostrarPedidosMesaEspecial(Mesa mesa) async {
    try {
      setState(() {
        isLoading = true;
      });

      // Cargar pedidos activos de esta mesa
      final pedidos = await _pedidoService.getPedidosByMesa(mesa.nombre);
      final pedidosActivos = pedidos
          .where((p) => p.estado == EstadoPedido.activo)
          .toList();

      setState(() {
        isLoading = false;
      });

      if (pedidosActivos.isEmpty) {
        // Si no hay pedidos activos, ir directamente a crear un nuevo pedido
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PedidoScreen(mesa: mesa)),
        );
        return;
      }

      // Mostrar la lista de pedidos activos
      showModalBottomSheet(
        context: context,
        backgroundColor: _cardBg,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pedidos Activos - ${mesa.nombre}',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: _textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Lista de pedidos
                Expanded(
                  child: ListView.builder(
                    itemCount: pedidosActivos.length,
                    itemBuilder: (context, index) {
                      final pedido = pedidosActivos[index];
                      return Card(
                        color: _cardBg.withOpacity(0.8),
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: _primary.withOpacity(0.3)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cabecera del pedido
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      pedido.cliente ?? 'Pedido ${index + 1}',
                                      style: TextStyle(
                                        color: _textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '\$${pedido.total.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),

                              // Información del pedido
                              Row(
                                children: [
                                  Icon(Icons.person, color: _primary, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Mesero: ${pedido.mesero}',
                                    style: TextStyle(color: _textSecondary),
                                  ),
                                  SizedBox(width: 16),
                                  Icon(
                                    Icons.access_time,
                                    color: _primary,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '${pedido.fecha.hour.toString().padLeft(2, '0')}:${pedido.fecha.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(color: _textSecondary),
                                  ),
                                ],
                              ),

                              if (pedido.notas != null &&
                                  pedido.notas!.isNotEmpty) ...[
                                SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.note, color: _primary, size: 16),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        pedido.notas!,
                                        style: TextStyle(color: _textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              SizedBox(height: 8),

                              // Items del pedido
                              Text(
                                'Items (${pedido.items.length}):',
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              ...pedido.items
                                  .take(3)
                                  .map(
                                    (item) => Padding(
                                      padding: EdgeInsets.only(
                                        left: 16,
                                        bottom: 2,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '• ${item.cantidad}x ${item.productoNombre ?? 'Producto'} - \$${(item.precioUnitario * item.cantidad).toStringAsFixed(0)}',
                                            style: TextStyle(
                                              color: _textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (item.agregadoPor != null)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                left: 12,
                                                top: 1,
                                              ),
                                              child: Text(
                                                '👤 Agregado por: ${item.agregadoPor}',
                                                style: TextStyle(
                                                  color: _textSecondary
                                                      .withOpacity(0.7),
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                              if (pedido.items.length > 3)
                                Padding(
                                  padding: EdgeInsets.only(left: 16),
                                  child: Text(
                                    '... y ${pedido.items.length - 3} más',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),

                              SizedBox(height: 12),

                              // Fila de botones para acciones
                              Row(
                                children: [
                                  // Botón para editar pedido/agregar productos
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(
                                          context,
                                        ); // Cerrar el modal
                                        editarPedidoExistente(mesa, pedido);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            Provider.of<UserProvider>(
                                                  context,
                                                  listen: false,
                                                ).isAdmin
                                                ? 'Editar Pedido'
                                                : 'Agregar Productos',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  SizedBox(width: 8),

                                  // Botón de pago (solo para admins)
                                  if (Provider.of<UserProvider>(
                                    context,
                                    listen: false,
                                  ).isAdmin)
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(
                                            context,
                                          ); // Cerrar el modal
                                          _mostrarDialogoPago(mesa, pedido);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.payment, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Procesar Pago',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Botón para agregar nuevo pedido
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // Cerrar el modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PedidoScreen(mesa: mesa),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: BorderSide(color: _primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 18),
                        SizedBox(width: 8),
                        Text('Agregar Nuevo Pedido'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar pedidos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navegarAPedido(String nombreMesa) {
    // Buscar la mesa en la lista de mesas
    Mesa? mesa = mesas.firstWhere(
      (m) => m.nombre.toLowerCase() == nombreMesa.toLowerCase(),
      orElse: () => Mesa(
        id: '',
        nombre: nombreMesa,
        ocupada: false,
        total: 0.0,
        productos: [],
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PedidoScreen(mesa: mesa)),
    );
  }

  // Métodos de utilidad para mostrar mensajes
  @override
  void mostrarMensajeExito(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void mostrarMensajeError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void mostrarMensajeInfo(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Métodos auxiliares para el diálogo de pago mejorado
  Widget buildSeccionTitulo(String titulo) {
    return Text(
      titulo,
      style: TextStyle(
        color: _textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget buildInfoRow(IconData icono, String etiqueta, String valor) {
    return Row(
      children: [
        Icon(icono, color: _primary, size: 18),
        SizedBox(width: 12),
        Text(
          '$etiqueta: ',
          style: TextStyle(color: _textSecondary, fontSize: 14),
        ),
        Expanded(
          child: Text(
            valor,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Envía la petición al servidor para crear un nuevo documento
  Future<void> enviarDocumentoAlServidor(
    String mesaNombre,
    String vendedor,
    List<String> pedidosIds,
  ) async {
    try {
      // Mostrar indicador de carga
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Creando documento...')));

      // Llamar al servicio para crear el documento
      final DocumentoMesa? documento = await _documentoMesaService
          .crearDocumento(
            mesaNombre: mesaNombre,
            vendedor: vendedor,
            pedidosIds: pedidosIds,
          );

      if (documento != null) {
        // Documento creado con éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Documento #${documento.numeroDocumento} creado con éxito',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navegar a la pantalla de documentos de la mesa
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentosMesaScreen(
              mesa: Mesa(
                id: '', // No necesitamos el ID real aquí
                nombre: mesaNombre,
                ocupada: true,
                total: 0,
                productos: [],
                pedidoActual: null,
              ),
            ),
          ),
        );
      } else {
        // Error al crear documento
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al crear el documento'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error enviando documento al servidor: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Diálogo simple para solo obtener información de pago
  Future<Map<String, dynamic>?> mostrarDialogoSimplePago() async {
    String medioPago = 'efectivo';
    String pagadoPor = '';
    double propina = 0.0;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long, color: _primary, size: 32),
                      SizedBox(height: 12),
                      Text(
                        'Información de Facturación',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Método de pago
                Text(
                  'Método de Pago',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => medioPago = 'efectivo'),
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: medioPago == 'efectivo'
                                ? _primary.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: medioPago == 'efectivo'
                                  ? _primary
                                  : _textMuted,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.money,
                                color: medioPago == 'efectivo'
                                    ? _primary
                                    : _textSecondary,
                                size: 24,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Efectivo',
                                style: TextStyle(
                                  color: medioPago == 'efectivo'
                                      ? _primary
                                      : _textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => medioPago = 'transferencia'),
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: medioPago == 'transferencia'
                                ? _primary.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: medioPago == 'transferencia'
                                  ? _primary
                                  : _textMuted,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.account_balance,
                                color: medioPago == 'transferencia'
                                    ? _primary
                                    : _textSecondary,
                                size: 24,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Transferencia',
                                style: TextStyle(
                                  color: medioPago == 'transferencia'
                                      ? _primary
                                      : _textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Campo para pagado por
                Text(
                  'Pagado por (opcional)',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  onChanged: (value) => pagadoPor = value,
                  style: TextStyle(color: _textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Nombre del cliente o facturador',
                    hintStyle: TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _cardBg.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _textMuted),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _textMuted),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primary),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Campo para propina
                Text(
                  'Propina (opcional)',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  onChanged: (value) => propina = double.tryParse(value) ?? 0.0,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: _textPrimary),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: _textSecondary),
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: _primary),
                    filled: true,
                    fillColor: _cardBg.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _textMuted),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _textMuted),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primary),
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(color: _textPrimary),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop({
                            'medioPago': medioPago,
                            'pagadoPor': pagadoPor.isNotEmpty
                                ? pagadoPor
                                : null,
                            'propina': propina,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Crear Factura',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
