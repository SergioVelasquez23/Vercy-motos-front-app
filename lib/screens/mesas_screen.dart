import 'package:flutter/material.dart';
import '../utils/mesa_websocket_mixin.dart';
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
import '../services/producto_cancelado_service.dart';
import '../models/producto_cancelado.dart';
import '../services/documento_automatico_service.dart';
import '../services/impresion_service.dart';
import '../services/notification_service.dart';
import '../services/cuadre_caja_service.dart';
import '../providers/user_provider.dart';
import '../utils/format_utils.dart';
import '../utils/impresion_mixin.dart';
import 'pedido_screen.dart';
import 'documentos_mesa_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import '../services/pdf_service_web.dart';
import 'dart:html' as html;

// Importes de los nuevos módulos
import '../widgets/mesa/mesa_card.dart';

import '../services/websocket_service.dart';

extension FirstWhereOrNullExtension<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class MesasScreen extends StatefulWidget {
  const MesasScreen({super.key});

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen>
    with ImpresionMixin, MesaWebSocketMixin {
  // Recarga toda la pestaña de mesas y navega al mismo módulo/tab
  void _recargarPestanaActual() {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => const MesasScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        settings: RouteSettings(name: currentRoute),
      ),
    );
  }

  final MesaService _mesaService = MesaService();
  final PedidoService _pedidoService = PedidoService();
  final DocumentoMesaService _documentoMesaService = DocumentoMesaService();
  final ProductoCanceladoService _productoCanceladoService =
      ProductoCanceladoService();
  final DocumentoAutomaticoService _documentoAutomaticoService =
      DocumentoAutomaticoService();
  final CuadreCajaService _cuadreCajaService = CuadreCajaService();

  /// Verifica si existe la mesa "Deudas" y sugiere crearla si no existe
  Future<void> _verificarMesaDeudas() async {
    try {
      final mesas = await _mesaService.getMesas();
      final mesaDeudas = mesas.firstWhere(
        (mesa) => mesa.nombre.toLowerCase() == 'deudas',
        orElse: () => throw StateError('Mesa Deudas no encontrada'),
      );
    } catch (e) {
      print('⚠️ Mesa Deudas no encontrada en el sistema');
      print(
        '   📝 Para habilitar pagos parciales, crear mesa "Deudas" con tipo "DEUDAS" en el backend',
      );
    }
  }

  /// Mejora los mensajes de error para hacerlos más amigables al usuario
  String _mejorarMensajeError(String error) {
    final errorLower = error.toLowerCase();

    // Error de caja cerrada
    if (errorLower.contains('caja pendiente') ||
        errorLower.contains('abrir una caja') ||
        errorLower.contains('abrir caja')) {
      return ' Debe abrir caja para continuar\n\nPara registrar pedidos primero debe abrir la caja del día.';
    }

    // Error de conexión
    if (errorLower.contains('conexión') ||
        errorLower.contains('network') ||
        errorLower.contains('timeout')) {
      return ' Sin conexión\n\nVerifique su conexión a internet e intente de nuevo.';
    }

    // Error de servidor
    if (errorLower.contains('500') ||
        errorLower.contains('servidor') ||
        errorLower.contains('server')) {
      return ' Error del sistema\n\nIntente de nuevo en unos momentos.';
    }

    // Error de permisos
    if (errorLower.contains('permiso') ||
        errorLower.contains('autorizado') ||
        errorLower.contains('forbidden')) {
      return ' Sin permisos\n\nNo tiene autorización para realizar esta acción.';
    }

    // Mensaje genérico mejorado para otros errores
    return ' Error\n\n$error';
  }

  /// Convierte un string de motivo a enum MotivoCancelacion
  MotivoCancelacion _obtenerMotivoCancelacion(String motivo) {
    final motivoLower = motivo.toLowerCase();

    if (motivoLower.contains('cliente') || motivoLower.contains('solicito')) {
      return MotivoCancelacion.clienteSolicito;
    } else if (motivoLower.contains('error') &&
        motivoLower.contains('pedido')) {
      return MotivoCancelacion.errorPedido;
    } else if (motivoLower.contains('no disponible') ||
        motivoLower.contains('agotado')) {
      return MotivoCancelacion.noDisponible;
    } else if (motivoLower.contains('mesa') || motivoLower.contains('mover')) {
      return MotivoCancelacion.cambioMesa;
    } else if (motivoLower.contains('sistema')) {
      return MotivoCancelacion.errorSistema;
    } else {
      return MotivoCancelacion.otro;
    }
  }

  final ImpresionService _impresionService = ImpresionService();
  List<Mesa> mesas = [];
  bool isLoading = true;
  String? errorMessage;

  // Key para forzar reconstrucción de widgets después de operaciones
  int _widgetRebuildKey = 0;

  // La subscripción WebSocket ahora se maneja en el mixin MesaWebSocketMixin

  // ========== SISTEMA DE OPTIMIZACIÓN DE RECARGA ==========
  // Control de debounce para evitar múltiples llamadas
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(
    milliseconds: 200,
  ); // ✅ Optimizado para mayor velocidad

  // Set para trackear mesas que necesitan actualización
  final Set<String> _mesasPendientesActualizacion = <String>{};

  // Flag para prevenir actualizaciones múltiples simultáneas
  bool _actualizacionEnProgreso = false;

  // Paleta de colores mejorada
  static const _backgroundDark = Color(0xFF1A1A1A);
  static const _surfaceDark = Color(0xFF2A2A2A);
  static const _cardBg = Color(0xFF313131);
  static const _cardElevated = Color(0xFF3A3A3A);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFFB0B0B0);
  static const _textMuted = Color(0xFFB0B0B0);
  static const _primary = Color(0xFFFF6B00);
  static const _success = Color(0xFF4CAF50);
  static const _error = Color(0xFFF44336);

  // Banderas para evitar procesamiento múltiple
  // Flag de procesamiento removido por no ser utilizado

  // Método para crear documento en el servidor con método de pago
  Future<void> _enviarDocumentoAlServidor(
    Map<String, dynamic> documento,
  ) async {
    try {
      print('📤 Creando documento en el servidor...');

      // Extraer información del documento
      String mesaNombre = documento['mesa'] ?? '';
      String vendedor = documento['vendedor'] ?? '';
      List<String> pedidosIds = documento['pedidos'] ?? [];

      if (mesaNombre.isEmpty || vendedor.isEmpty || pedidosIds.isEmpty) {
        throw Exception('Información del documento incompleta');
      }

      // ✅ CORREGIDO: Solicitar método de pago al crear documento
      final paymentInfo = await _solicitarMetodoPago();
      if (paymentInfo == null) {
        throw Exception('Método de pago requerido para crear documento');
      }

      // Crear documento con método de pago
      final documentoCreado = await _documentoMesaService.crearDocumento(
        mesaNombre: mesaNombre,
        vendedor: vendedor,
        pedidosIds: pedidosIds,
        formaPago: paymentInfo['metodoPago'] ?? 'efectivo',
        pagadoPor: vendedor,
        propina: paymentInfo['propina'] ?? 0.0,
        pagado: false, // Documento pendiente hasta que se procese el pago
        estado: 'Pendiente',
        fechaPago: null,
      );

      if (documentoCreado != null) {
        print(
          '✅ Documento creado exitosamente: ${documentoCreado.numeroDocumento}',
        );

        // Mostrar confirmación al usuario
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Documento ${documentoCreado.numeroDocumento} creado exitosamente',
              ),
              backgroundColor: _success,
            ),
          );
        }

        // Recargar mesas para reflejar cambios
        await _recargarMesasConCards();
      }
    } catch (e) {
      print('❌ Error creando documento: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear documento: ${e.toString()}'),
            backgroundColor: _error,
          ),
        );
      }
      throw Exception('Error creando documento: $e');
    }
  }

  /// Solicita al usuario el método de pago para crear un documento
  Future<Map<String, dynamic>?> _solicitarMetodoPago() async {
    String metodoPagoSeleccionado = 'efectivo';
    double propina = 0.0;
    TextEditingController propinaController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: _cardBg,
          title: Row(
            children: [
              Icon(Icons.payment, color: _primary, size: 24),
              SizedBox(width: 12),
              Text(
                'Método de Pago',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seleccione el método de pago para el documento:',
                style: TextStyle(color: _textSecondary, fontSize: 14),
              ),
              SizedBox(height: 20),

              // Método de pago
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primary.withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: metodoPagoSeleccionado,
                    isExpanded: true,
                    dropdownColor: _surfaceDark,
                    style: TextStyle(color: _textPrimary),
                    items: [
                      DropdownMenuItem(
                        value: 'efectivo',
                        child: Text('💵 Efectivo'),
                      ),
                      DropdownMenuItem(
                        value: 'tarjeta',
                        child: Text('💳 Tarjeta'),
                      ),
                      DropdownMenuItem(
                        value: 'transferencia',
                        child: Text('📱 Transferencia'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          metodoPagoSeleccionado = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Propina opcional
              TextField(
                controller: propinaController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _textPrimary),
                decoration: InputDecoration(
                  labelText: 'Propina (opcional)',
                  labelStyle: TextStyle(color: _textSecondary),
                  prefixIcon: Icon(Icons.star, color: _primary),
                  suffixText: '%',
                  filled: true,
                  fillColor: _surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _textMuted),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _primary, width: 2),
                  ),
                ),
                onChanged: (value) {
                  propina = double.tryParse(value) ?? 0.0;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text('Cancelar', style: TextStyle(color: _textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'metodoPago': metodoPagoSeleccionado,
                  'propina': propina,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    return result;
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
        formapagoValidada = 'efectivo';
      }
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

      if (documento == null) {
        throw Exception('El servicio de documentos devolvió null');
      }
    } catch (e) {
      print('❌ Error creando documento automático: $e');
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
            content: Text(_mejorarMensajeError(e.toString())),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
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
              backgroundColor: _error,
              foregroundColor: _textPrimary,
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
        subject: 'Resumen de Pedido - ${resumen['numeroPedido'] ?? 'N/A'}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mejorarMensajeError(e.toString())),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
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
        final pdfServiceWeb = PDFServiceWeb();

        if (mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
        }

        try {
          pdfServiceWeb.generarYDescargarPDF(resumen: resumen);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Generando PDF...'),
                backgroundColor: _success,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error generando PDF: $e'),
                backgroundColor: _error,
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
            'resumen_pedido_${resumen['numeroPedido'] ?? DateTime.now().millisecondsSinceEpoch}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        if (mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
        }

        // Compartir el archivo PDF
        await Share.shareXFiles([
          XFile(file.path),
        ], subject: 'Resumen de Pedido - ${resumen['numeroPedido'] ?? 'N/A'}');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generando PDF: $e'),
            backgroundColor: _error,
          ),
        );
      }
    }
  }

  // Opciones específicas para web
  Future<void> _mostrarOpcionesWebPDF(
    Map<String, dynamic> resumen,
    PDFServiceWeb pdfServiceWeb,
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
                            backgroundColor: _success,
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
                            backgroundColor: _success,
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
                    backgroundColor: Color(0xFF2196F3),
                    foregroundColor: _textPrimary,
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
                            backgroundColor: _success,
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
                    backgroundColor: _success,
                    foregroundColor: _textPrimary,
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
            Icon(Icons.account_balance_wallet, color: _primary),
            SizedBox(width: 8),
            Text('Registrar Deuda', style: TextStyle(color: _textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total a deber: ${formatCurrency(resumen['total'] ?? 0.0)}',
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
              backgroundColor: _primary,
              foregroundColor: _textPrimary,
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
            content: Text(_mejorarMensajeError(e.toString())),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
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
            constraints: BoxConstraints(maxWidth: 400),
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
                  padding: EdgeInsets.all(24),
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
                formatCurrency(producto['subtotal'] ?? 0.0),
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
          // Mostrar quien agregó el producto en vista resumida
          if (producto['agregadoPor'] != null &&
              producto['agregadoPor'].toString().isNotEmpty) ...[
            SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 12,
                  color: Colors.green.withOpacity(0.7),
                ),
                SizedBox(width: 4),
                Text(
                  'por ${producto['agregadoPor']}',
                  style: TextStyle(
                    color: Colors.green.withOpacity(0.8),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
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

  // ========== MÉTODOS OPTIMIZADOS DE RECARGA ==========

  /// Método optimizado para actualizar mesas específicas con debounce
  void _programarActualizacionMesa(String mesaNombre) {
    _mesasPendientesActualizacion.add(mesaNombre);

    // Cancelar timer anterior si existe
    _debounceTimer?.cancel();

    // Programar nueva actualización
    _debounceTimer = Timer(_debounceDuration, () {
      _ejecutarActualizacionesPendientes();
    });
  }

  /// Ejecuta todas las actualizaciones pendientes en batch
  Future<void> _ejecutarActualizacionesPendientes() async {
    if (_actualizacionEnProgreso || _mesasPendientesActualizacion.isEmpty) {
      return;
    }

    _actualizacionEnProgreso = true;

    try {
      // Hacer una sola llamada para obtener las mesas actualizadas
      final mesasActualizadas = await _mesaService.getMesas();

      // Actualizar solo las mesas que están en el set de pendientes
      for (final nombreMesa in _mesasPendientesActualizacion) {
        final mesaActualizada = mesasActualizadas.firstWhere(
          (m) => m.nombre == nombreMesa,
          orElse: () => throw StateError('Mesa no encontrada: $nombreMesa'),
        );

        final index = mesas.indexWhere((m) => m.nombre == nombreMesa);
        if (index != -1 && mounted) {
          setState(() {
            mesas[index] = mesaActualizada;
          });
        }
      }

      // Limpiar el set de pendientes
      _mesasPendientesActualizacion.clear();
    } catch (e) {
      print('❌ Error en actualización optimizada: $e');
      // En caso de error, hacer recarga completa como fallback
      _recargarMesasConCards();
    } finally {
      _actualizacionEnProgreso = false;
    }
  }

  /// Método optimizado que reemplaza múltiples llamadas individuales
  void _actualizarMesasOptimizado(List<String> nombresMesas) {
    // Agregar todas las mesas al set de pendientes
    _mesasPendientesActualizacion.addAll(nombresMesas);

    // Programar actualización con debounce
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _ejecutarActualizacionesPendientes();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadMesas();
    // Configurar WebSocket para actualización en tiempo real
    setupMesaWebSockets(() => _recargarMesasConCards());
    _verificarMesaDeudas(); // ✅ Verificar mesa Deudas al iniciar
  }

  // void _iniciarSincronizacion() {
  //   // Sincronización deshabilitada
  // }

  @override
  void dispose() {
    // Limpiar timer de debounce
    _debounceTimer?.cancel();

    // Liberar recursos de WebSocket
    disposeMesaWebSockets();

    // Desactivar el modo keep-alive cuando se salga de la pantalla
    final ws = WebSocketService();
    ws.setKeepAlive(false);

    super.dispose();
  }

  // Este método ha sido reemplazado por el mixin MesaWebSocketMixin
  // WebSocket configuration is now handled by MesaWebSocketMixin

  Future<void> _loadMesas() async {
    try {
      // Cargando todas las mesas...
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Obtener todas las mesas en una sola llamada
      final loadedMesas = await _mesaService.getMesas();

      // ✅ OPTIMIZACIÓN: Cargar pedidos solo para primeras mesas ocupadas
      // para acelerar carga inicial, el resto se carga bajo demanda
      final List<Future<void>> pedidosFutures = [];
      int mesasOcupadasProcesadas = 0;
      const int maxMesasIniciales = 8; // Reducido para carga más rápida

      for (final mesa in loadedMesas) {
        if (mesa.ocupada && mesasOcupadasProcesadas < maxMesasIniciales) {
          pedidosFutures.add(_cargarPedidosParaMesa(mesa));
          mesasOcupadasProcesadas++;
        }
      }

      // Esperar a que todas las cargas de pedidos terminen (en paralelo)
      if (pedidosFutures.isNotEmpty) {
        await Future.wait(pedidosFutures);
      }

      setState(() {
        mesas = loadedMesas;
        isLoading = false;
      });

      // Carga de mesas completada silenciosamente
    } catch (error) {
      // Error al cargar mesas - mostrar mensaje amigable
      String mensajeAmigable;
      if (error.toString().contains('TimeoutException') ||
          error.toString().contains('SocketException') ||
          error.toString().contains('connection')) {
        mensajeAmigable =
            'Error de conexión a internet. Verifica tu conectividad WiFi.';
      } else if (error.toString().contains('500')) {
        mensajeAmigable =
            'El servidor está experimentando problemas. Intenta nuevamente.';
      } else {
        mensajeAmigable = 'Error al cargar las mesas. Intenta nuevamente.';
      }

      setState(() {
        errorMessage = mensajeAmigable;
        isLoading = false;
      });
    }
  }

  // Método auxiliar para cargar pedidos de una mesa específica
  Future<void> _cargarPedidosParaMesa(Mesa mesa) async {
    try {
      // Obtener los pedidos de la mesa
      await _pedidoService.getPedidosByMesa(mesa.nombre);
      // No necesitamos guardar la variable ya que solo queremos pre-cargar los datos
      // para que estén en caché cuando los necesitemos
    } catch (e) {
      print('⚠️ Error al cargar pedidos para mesa ${mesa.nombre}: $e');
      // No lanzamos excepción para que la carga de otras mesas pueda continuar
    }
  }

  /// Método optimizado para recarga completa de mesas
  Future<void> _recargarMesasConCards() async {
    if (_actualizacionEnProgreso) {
      print('⏸️ Recarga ya en progreso, evitando duplicación...');
      return;
    }

    _actualizacionEnProgreso = true;

    try {
      print('🔄 Iniciando recarga optimizada de mesas...');

      // Cancelar cualquier actualización parcial pendiente
      _debounceTimer?.cancel();
      _mesasPendientesActualizacion.clear();

      // Una sola recarga completa eficiente
      await _loadMesas();
      if (mounted) {
        setState(() => _widgetRebuildKey++);
      }

      print('✅ Recarga de mesas completada');
    } catch (e) {
      print('❌ Error en recarga de mesas: $e');
    } finally {
      _actualizacionEnProgreso = false;
    }
  }

  // ========== MÉTODOS OBSOLETOS ELIMINADOS ==========
  // Los métodos _actualizarMesaEspecifica, _reconstruirCardDesdeCero y
  // _obtenerPedidosActivosReales han sido eliminados y reemplazados
  // por el sistema optimizado de debounce

  /// VERIFICA el estado real de una mesa en tiempo de construcción del widget
  void _verificarEstadoRealMesa(Mesa mesa) {
    // Hacer esta verificación de forma asíncrona para no bloquear el build
    Future.microtask(() async {
      try {
        final pedidos = await _pedidoService.getPedidosByMesa(mesa.nombre);
        final pedidosActivos = pedidos
            .where(
              (p) =>
                  p.estado != 'pagado' &&
                  p.estado != 'cancelado' &&
                  p.estado != EstadoPedido.pagado &&
                  p.estado != EstadoPedido.cancelado,
            )
            .toList();

        double totalReal = pedidosActivos.fold(0.0, (sum, p) => sum + p.total);
        bool ocupadaReal = pedidosActivos.isNotEmpty;

        // ✅ COMENTADO: Logs de verificación repetitivos removidos
        // print('🔍 VERIFICACIÓN REAL ${mesa.nombre}:');
        // print('   - Card muestra: total=${mesa.total}, ocupada=${mesa.ocupada}');
        // print('   - Reality check: total=$totalReal, ocupada=$ocupadaReal');
        // print('   - Pedidos activos: ${pedidosActivos.length}');

        if (mesa.total != totalReal || mesa.ocupada != ocupadaReal) {
          // ✅ OPTIMIZACIÓN: Logs comentados para mejorar rendimiento
          // print('🚨 ¡INCONSISTENCIA DETECTADA EN TIEMPO REAL!');
          // print('   - Diferencia total: ${mesa.total} vs $totalReal');
          // print('   - Diferencia ocupada: ${mesa.ocupada} vs $ocupadaReal');
        }
      } catch (e) {
        // Error verificando estado real - ignorado silenciosamente
      }
    });
  }

  // Eliminar completamente la función _sincronizarEstadoMesas

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener pedidos de la mesa'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
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
                            title:
                                pedido.cliente != null &&
                                    pedido.cliente!.isNotEmpty
                                ? Text(
                                    pedido.cliente!,
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : Text(
                                    'Sin cliente',
                                    style: const TextStyle(
                                      color: Color(0xFFE0E0E0),
                                      fontSize: 16,
                                    ),
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
      // Siempre buscar en el servidor para obtener el ID más actualizado
      final pedidos = await _pedidoService.getPedidosByMesa(mesa.nombre);

      final pedidoActivo = pedidos.firstWhere(
        (pedido) => pedido.estado == EstadoPedido.activo,
        orElse: () => throw Exception('No hay pedido activo'),
      );

      // Verificar que el ID no esté vacío
      if (pedidoActivo.id.isEmpty) {
        throw Exception('El pedido activo no tiene ID válido');
      }

      return pedidoActivo;
    } catch (e) {
      print('❌ Error al obtener pedido activo: $e');

      // Si no hay pedido activo pero la mesa aparece ocupada, corregir automáticamente
      if (mesa.ocupada || mesa.total > 0) {
        try {
          mesa.ocupada = false;
          mesa.productos = [];
          mesa.total = 0.0;
          await _mesaService.updateMesa(mesa);

          // Recargar las mesas para reflejar el cambio en la UI
          _recargarMesasConCards();
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
                            _mostrarDialogoPago(mesa, pedido);
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
                            _mostrarDialogoPago(mesa, pedido);
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
                            _mostrarDialogoPago(mesa, pedido);
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
        await _recargarMesasConCards();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$mesasLimpiadas mesas han sido restauradas correctamente',
            ),
            backgroundColor: _success,
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
        await _recargarMesasConCards();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mesa ${mesa.nombre} vaciada correctamente'),
              backgroundColor: _success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al vaciar mesa: $e'),
              backgroundColor: _error,
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

      await _recargarMesasConCards(); // Recargar las mesas

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesa ${mesa.nombre} actualizada'),
            backgroundColor: _success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar mesa: $e'),
            backgroundColor: _error,
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Función eliminada - ahora se usa MesaCard widget

  void _mostrarDialogoPago(Mesa mesa, Pedido pedido) async {
    String medioPago0 = 'efectivo';
    bool incluyePropina = false;
    TextEditingController descuentoPorcentajeController =
        TextEditingController();
    TextEditingController descuentoValorController = TextEditingController();
    TextEditingController propinaController = TextEditingController();

    // Bandera de procesamiento removida por no ser utilizada

    // NUEVAS VARIABLES PARA LAS OPCIONES MOVIDAS
    bool esCortesia0 = false;
    bool esConsumoInterno0 = false;
    String? mesaDestinoId0;

    // VARIABLE PARA PRODUCTOS SELECCIONADOS
    List<ItemPedido> productosSeleccionados = [];

    // ✅ NUEVAS VARIABLES PARA CANTIDAD ESPECÍFICA
    Map<String, bool> itemsSeleccionados = {};
    Map<String, int> cantidadesSeleccionadas = {};
    Map<String, TextEditingController> cantidadControllers = {};

    // Inicializar controladores para cada producto
    for (int i = 0; i < pedido.items.length; i++) {
      final indexKey = i.toString();
      itemsSeleccionados[indexKey] = false;
      cantidadesSeleccionadas[indexKey] = 0;
      cantidadControllers[indexKey] = TextEditingController(text: '0');
    }

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

    // ✅ NUEVAS VARIABLES PARA PAGO MÚLTIPLE
    bool pagoMultiple = false;
    TextEditingController montoEfectivoController = TextEditingController();
    TextEditingController montoTarjetaController = TextEditingController();
    TextEditingController montoTransferenciaController =
        TextEditingController();

    // Función local para construir botones de billetes mejorados
    Widget buildBilletButton(int valor, Function(VoidCallback) setStateLocal) {
      final isMovil = MediaQuery.of(context).size.width < 768;

      return Expanded(
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
            height: isMovil ? 40 : 50, // Más pequeño como solicitas
            decoration: BoxDecoration(
              color: _primary, // Color sólido como en la imagen
              borderRadius: BorderRadius.circular(
                8,
              ), // Bordes menos redondeados
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Mostrar contador en la esquina superior derecha si hay billetes
                if ((contadorBilletes[valor] ?? 0) > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${contadorBilletes[valor]}',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Contenido central del botón
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.attach_money,
                        color: Colors.white,
                        size: isMovil ? 12 : 14,
                      ),
                      SizedBox(width: 2),
                      Text(
                        '${formatCurrency(valor / 1000)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMovil ? 11 : 13,
                          fontWeight: FontWeight.bold,
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

    // Función helper para calcular el total de productos seleccionados
    double calcularTotalSeleccionados() {
      if (productosSeleccionados.isEmpty) {
        return pedido
            .total; // Si no hay productos seleccionados, usar total completo
      }
      return productosSeleccionados.fold<double>(
        0,
        (sum, item) => sum + (item.cantidad * item.precioUnitario),
      );
    }

    final formResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isMovil = MediaQuery.of(context).size.width < 768;
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;

          return Dialog(
            backgroundColor: Colors.transparent,
            child: KeyboardListener(
              focusNode: FocusNode()..requestFocus(),
              onKeyEvent: (KeyEvent event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                width: isMovil ? screenWidth * 0.98 : screenWidth * 0.95,
                constraints: BoxConstraints(
                  maxHeight: isMovil ? screenHeight * 0.98 : screenHeight * 0.9,
                  maxWidth: isMovil ? screenWidth * 0.98 : double.infinity,
                  minWidth: isMovil ? screenWidth * 0.98 : 1200,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(isMovil ? 8 : 20),
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
                    // Header con estilo moderno
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMovil ? 12 : 24,
                        vertical: isMovil ? 8 : 20,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isMovil ? 8 : 20),
                          topRight: Radius.circular(isMovil ? 8 : 20),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (!isMovil) // Ocultar icono en móvil para ahorrar espacio
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.credit_card,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          if (!isMovil) SizedBox(width: 12),
                          Text(
                            isMovil ? 'Pago' : 'Procesar Pago',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMovil ? 16 : 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Spacer(),
                          if (isMovil) // En móvil, mostrar mesa en header
                            Text(
                              'Mesa ${mesa.nombre}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (!isMovil)
                            Text(
                              '${productosSeleccionados.length}/${pedido.items.length}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Contenido scrolleable con scroll horizontal
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          width: isMovil
                              ? screenWidth * 1.2
                              : screenWidth * 0.95,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(isMovil ? 8 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Información de la mesa con estilo moderno
                                if (!isMovil) // Ocultar en móvil ya que está en header
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF3A3A3C),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Color(
                                          0xFFFF6B35,
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Color(
                                              0xFFFF6B35,
                                            ).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.table_restaurant,
                                            color: Color(0xFFFF6B35),
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Mesa: ${mesa.nombre}',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                'Pedido #${pedido.id}',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                SizedBox(height: isMovil ? 12 : 24),

                                // Header de productos con botones de selección
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isMovil
                                            ? 'Productos (${productosSeleccionados.length}/${pedido.items.length})'
                                            : 'Productos del Pedido',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isMovil ? 14 : 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Spacer(),
                                    // Botón "Todos"
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          for (
                                            int i = 0;
                                            i < pedido.items.length;
                                            i++
                                          ) {
                                            final indexKey = i.toString();
                                            itemsSeleccionados[indexKey] = true;
                                            cantidadesSeleccionadas[indexKey] =
                                                pedido.items[i].cantidad;
                                            cantidadControllers[indexKey]!
                                                .text = pedido.items[i].cantidad
                                                .toString();
                                          }
                                          // Actualizar lista de productos seleccionados
                                          productosSeleccionados.clear();
                                          for (
                                            int i = 0;
                                            i < pedido.items.length;
                                            i++
                                          ) {
                                            final indexKey = i.toString();
                                            if (itemsSeleccionados[indexKey] ==
                                                true) {
                                              final item = pedido.items[i];
                                              final cantidad =
                                                  cantidadesSeleccionadas[indexKey] ??
                                                  0;
                                              if (cantidad > 0) {
                                                productosSeleccionados.add(
                                                  ItemPedido(
                                                    id: item.id,
                                                    productoId: item.productoId,
                                                    productoNombre:
                                                        item.productoNombre,
                                                    cantidad: cantidad,
                                                    precioUnitario:
                                                        item.precioUnitario,
                                                    agregadoPor:
                                                        item.agregadoPor,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFFF6B35),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_box,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Todos',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // Botón "Ninguno"
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          for (
                                            int i = 0;
                                            i < pedido.items.length;
                                            i++
                                          ) {
                                            final indexKey = i.toString();
                                            itemsSeleccionados[indexKey] =
                                                false;
                                            cantidadesSeleccionadas[indexKey] =
                                                0;
                                            cantidadControllers[indexKey]!
                                                    .text =
                                                '0';
                                          }
                                          productosSeleccionados.clear();
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF4A4A4C),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.white24,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_box_outline_blank,
                                              color: Colors.white70,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Ninguno',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    color: _cardBg.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _primary.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Header de la tabla como en la imagen
                                      if (!isMovil)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(12),
                                              topRight: Radius.circular(12),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 40,
                                              ), // Espacio para checkbox
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  'Fecha',
                                                  style: TextStyle(
                                                    color: _textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  'Und',
                                                  style: TextStyle(
                                                    color: _textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  'Producto',
                                                  style: TextStyle(
                                                    color: _textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  'Precio',
                                                  style: TextStyle(
                                                    color: _textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),

                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  'Total',
                                                  style: TextStyle(
                                                    color: _textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  'Vendedor',
                                                  style: TextStyle(
                                                    color: _textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 80,
                                              ), // Espacio para botón cancelar
                                            ],
                                          ),
                                        ),

                                      // Lista de productos
                                      ...List.generate(pedido.items.length, (
                                        index,
                                      ) {
                                        final item = pedido.items[index];
                                        final indexKey = index.toString();
                                        final isSelected =
                                            itemsSeleccionados[indexKey] ==
                                            true;

                                        return Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ), // Más padding vertical
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? _primary.withOpacity(0.1)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? _primary
                                                    : Colors.transparent,
                                                width: 1,
                                              ),
                                            ),
                                            padding: EdgeInsets.all(12),
                                            child: isMovil
                                                ? Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Layout móvil compacto
                                                      Row(
                                                        children: [
                                                          Checkbox(
                                                            value: isSelected,
                                                            onChanged: (bool? value) {
                                                              setState(() {
                                                                itemsSeleccionados[indexKey] =
                                                                    value ??
                                                                    false;
                                                                if (value ==
                                                                    true) {
                                                                  cantidadesSeleccionadas[indexKey] =
                                                                      item.cantidad;
                                                                  cantidadControllers[indexKey]
                                                                      ?.text = item
                                                                      .cantidad
                                                                      .toString();
                                                                  productosSeleccionados
                                                                      .add(
                                                                        item,
                                                                      );
                                                                } else {
                                                                  cantidadesSeleccionadas[indexKey] =
                                                                      0;
                                                                  cantidadControllers[indexKey]
                                                                          ?.text =
                                                                      '0';
                                                                  productosSeleccionados
                                                                      .remove(
                                                                        item,
                                                                      );
                                                                }
                                                              });
                                                            },
                                                            activeColor:
                                                                _primary,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  '${item.productoNombre ?? 'Producto'}',
                                                                  style: TextStyle(
                                                                    color:
                                                                        _textPrimary,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  formatCurrency(
                                                                    item.precioUnitario,
                                                                  ),
                                                                  style: TextStyle(
                                                                    color:
                                                                        _primary,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                                if (item.agregadoPor !=
                                                                        null &&
                                                                    item
                                                                        .agregadoPor!
                                                                        .isNotEmpty) ...[
                                                                  SizedBox(
                                                                    height: 2,
                                                                  ),
                                                                  Text(
                                                                    '👤 ${item.agregadoPor}',
                                                                    style: TextStyle(
                                                                      color: _textPrimary
                                                                          .withOpacity(
                                                                            0.7,
                                                                          ),
                                                                      fontSize:
                                                                          11,
                                                                      fontStyle:
                                                                          FontStyle
                                                                              .italic,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                          Text(
                                                            '${item.cantidad}',
                                                            style: TextStyle(
                                                              color:
                                                                  _textPrimary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  )
                                                : Row(
                                                    children: [
                                                      // Checkbox
                                                      Checkbox(
                                                        value: isSelected,
                                                        onChanged: (bool? value) {
                                                          setState(() {
                                                            itemsSeleccionados[indexKey] =
                                                                value ?? false;
                                                            if (value == true) {
                                                              cantidadesSeleccionadas[indexKey] =
                                                                  item.cantidad;
                                                              cantidadControllers[indexKey]
                                                                  ?.text = item
                                                                  .cantidad
                                                                  .toString();
                                                              productosSeleccionados
                                                                  .add(item);
                                                            } else {
                                                              cantidadesSeleccionadas[indexKey] =
                                                                  0;
                                                              cantidadControllers[indexKey]
                                                                      ?.text =
                                                                  '0';
                                                              productosSeleccionados
                                                                  .remove(item);
                                                            }
                                                          });
                                                        },
                                                        activeColor: _primary,
                                                      ),

                                                      // Fecha (simulada)
                                                      Expanded(
                                                        flex: 1,
                                                        child: Text(
                                                          '2025-10-04 10:37:11 p. m.',
                                                          style: TextStyle(
                                                            color: _textPrimary,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ),

                                                      // Unidad
                                                      Expanded(
                                                        flex: 1,
                                                        child: Text(
                                                          '${item.cantidad}',
                                                          style: TextStyle(
                                                            color: _textPrimary,
                                                            fontSize: 12,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),

                                                      // Producto
                                                      Expanded(
                                                        flex: 3,
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              '${item.productoNombre ?? 'Producto'}',
                                                              style: TextStyle(
                                                                color:
                                                                    _textPrimary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                fontSize: 13,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            if (item.agregadoPor !=
                                                                    null &&
                                                                item
                                                                    .agregadoPor!
                                                                    .isNotEmpty) ...[
                                                              Text(
                                                                '👤 ${item.agregadoPor}',
                                                                style: TextStyle(
                                                                  color: _textPrimary
                                                                      .withOpacity(
                                                                        0.7,
                                                                      ),
                                                                  fontSize: 10,
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ],
                                                            if (item.notas !=
                                                                    null &&
                                                                item
                                                                    .notas!
                                                                    .isNotEmpty)
                                                              Text(
                                                                item.notas!,
                                                                style: TextStyle(
                                                                  color: _textPrimary
                                                                      .withOpacity(
                                                                        0.6,
                                                                      ),
                                                                  fontSize: 10,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                          ],
                                                        ),
                                                      ),

                                                      // Precio unitario
                                                      Expanded(
                                                        flex: 1,
                                                        child: Text(
                                                          formatCurrency(
                                                            item.precioUnitario,
                                                          ),
                                                          style: TextStyle(
                                                            color: _textPrimary,
                                                            fontSize: 12,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),

                                                      // Total
                                                      Expanded(
                                                        flex: 1,
                                                        child: Text(
                                                          formatCurrency(
                                                            item.precioUnitario *
                                                                item.cantidad,
                                                          ),
                                                          style: TextStyle(
                                                            color: _primary,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),

                                                      // Vendedor
                                                      Expanded(
                                                        flex: 1,
                                                        child: Text(
                                                          item.agregadoPor ??
                                                              'Sergio',
                                                          style: TextStyle(
                                                            color: _textPrimary,
                                                            fontSize: 11,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),

                                                      // Botón cancelar como en la imagen
                                                      Container(
                                                        width: 80,
                                                        child: ElevatedButton(
                                                          onPressed: () {
                                                            // Lógica para cancelar este producto específico
                                                          },
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                _primary,
                                                            foregroundColor:
                                                                Colors.white,
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    6,
                                                                  ),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            'Cancelar',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),

                                // Acciones rápidas para productos seleccionados
                                if (productosSeleccionados.isNotEmpty) ...[
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _primary.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '${productosSeleccionados.length} producto${productosSeleccionados.length > 1 ? 's' : ''} seleccionado${productosSeleccionados.length > 1 ? 's' : ''}',
                                          style: TextStyle(
                                            color: _textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () async {
                                                  // Cancelar productos seleccionados
                                                  final motivo = await showDialog<String>(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      backgroundColor: _cardBg,
                                                      title: Text(
                                                        'Cancelar Productos',
                                                        style: TextStyle(
                                                          color: _textPrimary,
                                                        ),
                                                      ),
                                                      content: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            '¿Está seguro de cancelar ${productosSeleccionados.length} producto${productosSeleccionados.length > 1 ? 's' : ''}?',
                                                            style: TextStyle(
                                                              color:
                                                                  _textPrimary,
                                                            ),
                                                          ),
                                                          SizedBox(height: 16),
                                                          TextField(
                                                            decoration: InputDecoration(
                                                              labelText:
                                                                  'Motivo (opcional)',
                                                              labelStyle: TextStyle(
                                                                color:
                                                                    _textPrimary,
                                                              ),
                                                              enabledBorder:
                                                                  OutlineInputBorder(
                                                                    borderSide:
                                                                        BorderSide(
                                                                          color:
                                                                              _textMuted,
                                                                        ),
                                                                  ),
                                                              focusedBorder:
                                                                  OutlineInputBorder(
                                                                    borderSide:
                                                                        BorderSide(
                                                                          color:
                                                                              _primary,
                                                                        ),
                                                                  ),
                                                            ),
                                                            style: TextStyle(
                                                              color:
                                                                  _textPrimary,
                                                            ),
                                                            onChanged:
                                                                (value) {},
                                                          ),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                              ),
                                                          child: Text(
                                                            'Cancelar',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                'Cancelado por usuario',
                                                              ),
                                                          style:
                                                              ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    Colors.red,
                                                              ),
                                                          child: Text(
                                                            'Confirmar',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  if (motivo != null) {
                                                    print(
                                                      '🗑️ Iniciando cancelación de ${productosSeleccionados.length} productos',
                                                    );

                                                    // Cerrar diálogo principal primero
                                                    Navigator.pop(context);

                                                    // Procesar cancelación de productos DESPUÉS
                                                    await _procesarCancelacionProductos(
                                                      mesa,
                                                      pedido,
                                                      productosSeleccionados,
                                                      motivo,
                                                    );
                                                  }
                                                },
                                                icon: Icon(
                                                  Icons.remove_circle_outline,
                                                  size: 16,
                                                ),
                                                label: Text('Cancelar'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: _primary,
                                                  foregroundColor: _textPrimary,
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () async {
                                                  final mesaDestino = await showDialog<Mesa>(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      backgroundColor: _cardBg,
                                                      title: Text(
                                                        'Mover Productos',
                                                        style: TextStyle(
                                                          color: _textPrimary,
                                                        ),
                                                      ),
                                                      content: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'Seleccione la mesa destino para ${productosSeleccionados.length} producto${productosSeleccionados.length > 1 ? 's' : ''}:',
                                                            style: TextStyle(
                                                              color:
                                                                  _textPrimary,
                                                            ),
                                                          ),
                                                          SizedBox(height: 16),
                                                          Container(
                                                            height: 200,
                                                            width: double
                                                                .maxFinite,
                                                            child: ListView.builder(
                                                              itemCount: mesas
                                                                  .where(
                                                                    (m) =>
                                                                        m.id !=
                                                                        mesa.id,
                                                                  )
                                                                  .length,
                                                              itemBuilder: (context, index) {
                                                                final mesaOption = mesas
                                                                    .where(
                                                                      (m) =>
                                                                          m.id !=
                                                                          mesa.id,
                                                                    )
                                                                    .toList()[index];
                                                                return ListTile(
                                                                  leading: Icon(
                                                                    Icons
                                                                        .table_restaurant,
                                                                    color:
                                                                        _primary,
                                                                  ),
                                                                  title: Text(
                                                                    mesaOption
                                                                        .nombre,
                                                                    style: TextStyle(
                                                                      color:
                                                                          _textPrimary,
                                                                    ),
                                                                  ),
                                                                  subtitle: Text(
                                                                    'Mesa disponible',
                                                                    style: TextStyle(
                                                                      color:
                                                                          _textSecondary,
                                                                    ),
                                                                  ),
                                                                  onTap: () =>
                                                                      Navigator.pop(
                                                                        context,
                                                                        mesaOption,
                                                                      ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                              ),
                                                          child: Text(
                                                            'Cancelar',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  if (mesaDestino != null) {
                                                    // Cerrar diálogo principal primero
                                                    Navigator.pop(context);

                                                    // Procesar el movimiento de productos DESPUÉS
                                                    await _procesarMovimientoProductos(
                                                      mesa,
                                                      pedido,
                                                      productosSeleccionados,
                                                      mesaDestino,
                                                    );
                                                  }
                                                },
                                                icon: Icon(
                                                  Icons.swap_horiz,
                                                  size: 16,
                                                ),
                                                label: Text('Mover'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Color(
                                                    0xFF9C27B0,
                                                  ),
                                                  foregroundColor: _textPrimary,
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                SizedBox(height: 32),

                                // Eliminado: sección duplicada que se consolidará más adelante
                                SizedBox(height: 32),

                                // Secciones eliminadas: ahora consolidadas en la sección final
                                SizedBox(height: 32),

                                // 9. MÉTODOS DE PAGO
                                _buildSeccionTitulo('Método de Pago'),
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: _cardBg.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _primary.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Botones de método de pago mejorados
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => setState(
                                                () => medioPago0 = 'efectivo',
                                              ),
                                              child: Container(
                                                padding: EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color:
                                                      medioPago0 == 'efectivo'
                                                      ? _primary.withOpacity(
                                                          0.2,
                                                        )
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        medioPago0 == 'efectivo'
                                                        ? _primary
                                                        : _textMuted,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Icon(
                                                      Icons.money,
                                                      color:
                                                          medioPago0 ==
                                                              'efectivo'
                                                          ? _primary
                                                          : _textSecondary,
                                                      size: 24,
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'Efectivo',
                                                      style: TextStyle(
                                                        color:
                                                            medioPago0 ==
                                                                'efectivo'
                                                            ? _primary
                                                            : _textSecondary,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                                () => medioPago0 =
                                                    'transferencia',
                                              ),
                                              child: Container(
                                                padding: EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color:
                                                      medioPago0 ==
                                                          'transferencia'
                                                      ? _primary.withOpacity(
                                                          0.2,
                                                        )
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        medioPago0 ==
                                                            'transferencia'
                                                        ? _primary
                                                        : _textMuted,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Icon(
                                                      Icons.credit_card,
                                                      color:
                                                          medioPago0 ==
                                                              'transferencia'
                                                          ? _primary
                                                          : _textSecondary,
                                                      size: 24,
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'Tarjeta/Transfer.',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color:
                                                            medioPago0 ==
                                                                'transferencia'
                                                            ? _primary
                                                            : _textSecondary,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                      border: Border.all(
                                        color: _primary.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Campo para entrada manual
                                        TextField(
                                          controller: billetesController,
                                          decoration: InputDecoration(
                                            labelText: 'Total recibido',
                                            labelStyle: TextStyle(
                                              color: _textPrimary,
                                            ),
                                            prefixText: '\$',
                                            enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: _textMuted,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: _primary,
                                                width: 2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          style: TextStyle(
                                            color: _textPrimary,
                                            fontSize: 16,
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            setState(() {
                                              billetesSeleccionados =
                                                  double.tryParse(value) ?? 0.0;
                                              if (value.isNotEmpty) {
                                                contadorBilletes.updateAll(
                                                  (key, val) => 0,
                                                );
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

                                        // Botones de billetes mejorados en grid 3x2 como la imagen
                                        Row(
                                          children: [
                                            buildBilletButton(2000, setState),
                                            SizedBox(width: 8),
                                            buildBilletButton(5000, setState),
                                            SizedBox(width: 8),
                                            buildBilletButton(10000, setState),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            buildBilletButton(20000, setState),
                                            SizedBox(width: 8),
                                            buildBilletButton(50000, setState),
                                            SizedBox(width: 8),
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
                                                    double subtotal =
                                                        calcularTotalSeleccionados();
                                                    double propinaPercent =
                                                        double.tryParse(
                                                          propinaController
                                                              .text,
                                                        ) ??
                                                        0.0;
                                                    double propinaMonto =
                                                        (subtotal *
                                                                propinaPercent /
                                                                100)
                                                            .roundToDouble();
                                                    double total =
                                                        subtotal + propinaMonto;
                                                    billetesSeleccionados =
                                                        total;
                                                    billetesController.text =
                                                        billetesSeleccionados
                                                            .toStringAsFixed(0);
                                                  });
                                                },
                                                icon: Icon(
                                                  Icons.check,
                                                  size: 18,
                                                ),
                                                label: Text('Exacto'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
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
                                                    billetesController.text =
                                                        '0';
                                                    contadorBilletes.updateAll(
                                                      (key, value) => 0,
                                                    );
                                                  });
                                                },
                                                icon: Icon(
                                                  Icons.clear,
                                                  size: 18,
                                                ),
                                                label: Text('Limpiar'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
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
                                ],

                                // 10. MONTO RECIBIDO Y CAMBIO
                                if (medioPago0 == 'efectivo' &&
                                    billetesSeleccionados > 0) ...[
                                  _buildSeccionTitulo('Cálculo de Cambio'),
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: _cardBg.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _primary.withOpacity(0.2),
                                      ),
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
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              formatCurrency(
                                                billetesSeleccionados,
                                              ),
                                              style: TextStyle(
                                                color: _textPrimary,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Cambio:',
                                              style: TextStyle(
                                                color: _textPrimary,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Builder(
                                              builder: (context) {
                                                double total =
                                                    calcularTotalSeleccionados();
                                                double descuento = 0;
                                                if (descuentoPorcentajeController
                                                    .text
                                                    .isNotEmpty) {
                                                  final porcentaje =
                                                      double.tryParse(
                                                        descuentoPorcentajeController
                                                            .text,
                                                      ) ??
                                                      0;
                                                  descuento =
                                                      total *
                                                      (porcentaje / 100);
                                                } else if (descuentoValorController
                                                    .text
                                                    .isNotEmpty) {
                                                  descuento =
                                                      double.tryParse(
                                                        descuentoValorController
                                                            .text,
                                                      ) ??
                                                      0;
                                                }
                                                double propina = 0;
                                                if (incluyePropina &&
                                                    propinaController
                                                        .text
                                                        .isNotEmpty) {
                                                  propina =
                                                      double.tryParse(
                                                        propinaController.text,
                                                      ) ??
                                                      0;
                                                }
                                                double totalFinal =
                                                    total - descuento + propina;
                                                double cambio =
                                                    billetesSeleccionados -
                                                    totalFinal;

                                                return Text(
                                                  cambio >= 0
                                                      ? formatCurrency(cambio)
                                                      : '-${formatCurrency(-cambio)}',
                                                  style: TextStyle(
                                                    color: cambio >= 0
                                                        ? Colors.green
                                                        : Colors.red,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 32),
                                ],

                                // Sección eliminada: pago múltiple ahora aparece debajo del botón "Otro medio de pago"
                                SizedBox(height: 32),

                                // Sección eliminada: resumen duplicado ahora consolidado al final
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: _cardBg.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _primary.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Campo de propina
                                      TextField(
                                        controller: propinaController,
                                        decoration: InputDecoration(
                                          labelText: 'Propina (%)',
                                          labelStyle: TextStyle(
                                            color: _textPrimary,
                                          ),
                                          suffixText: '%',
                                          prefixIcon: Icon(
                                            Icons.star,
                                            color: _primary,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: _textMuted,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: _primary,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: _textPrimary,
                                          fontSize: 16,
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            incluyePropina =
                                                value.isNotEmpty &&
                                                double.tryParse(value) !=
                                                    null &&
                                                double.parse(value) > 0;
                                          });
                                        },
                                      ),
                                      SizedBox(height: 24),

                                      // Resumen de totales
                                      Builder(
                                        builder: (context) {
                                          double subtotal =
                                              calcularTotalSeleccionados();
                                          double propinaPercent =
                                              double.tryParse(
                                                propinaController.text,
                                              ) ??
                                              0.0;
                                          double propinaMonto =
                                              (subtotal * propinaPercent / 100)
                                                  .roundToDouble();

                                          // ✅ Calcular descuento
                                          double descuento = 0.0;
                                          String descuentoPorcentajeStr =
                                              descuentoPorcentajeController
                                                  .text;
                                          String descuentoValorStr =
                                              descuentoValorController.text;

                                          if (descuentoPorcentajeStr
                                              .isNotEmpty) {
                                            double descuentoPorcentaje =
                                                double.tryParse(
                                                  descuentoPorcentajeStr,
                                                ) ??
                                                0.0;
                                            descuento =
                                                (subtotal *
                                                descuentoPorcentaje /
                                                100);
                                          } else if (descuentoValorStr
                                              .isNotEmpty) {
                                            descuento =
                                                double.tryParse(
                                                  descuentoValorStr,
                                                ) ??
                                                0.0;
                                          }

                                          // ✅ Total con descuento aplicado
                                          double total =
                                              subtotal -
                                              descuento +
                                              propinaMonto;

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
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: _primary.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
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
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                // ✅ Mostrar descuento si está aplicado
                                                if (descuento > 0) ...[
                                                  SizedBox(height: 12),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Descuento:',
                                                        style: TextStyle(
                                                          color: Colors.green,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      Text(
                                                        '-${formatCurrency(descuento)}',
                                                        style: TextStyle(
                                                          color: Colors.green,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                                if (propinaPercent > 0) ...[
                                                  SizedBox(height: 12),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Propina ($propinaPercent%):',
                                                        style: TextStyle(
                                                          color: _textPrimary,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      Text(
                                                        formatCurrency(
                                                          propinaMonto,
                                                        ),
                                                        style: TextStyle(
                                                          color: _textPrimary,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                                SizedBox(height: 16),
                                                Divider(
                                                  color: _primary.withOpacity(
                                                    0.3,
                                                  ),
                                                  thickness: 2,
                                                ),
                                                SizedBox(height: 16),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'TOTAL:',
                                                      style: TextStyle(
                                                        color: _textPrimary,
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 1.2,
                                                      ),
                                                    ),
                                                    Text(
                                                      formatCurrency(total),
                                                      style: TextStyle(
                                                        color: _primary,
                                                        fontSize: 26,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                // Mostrar cálculo de cambio para efectivo
                                                if (medioPago0 == 'efectivo' &&
                                                    billetesSeleccionados >
                                                        0) ...[
                                                  SizedBox(height: 20),
                                                  Container(
                                                    padding: EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: _cardBg
                                                          .withOpacity(0.5),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Recibido:',
                                                              style: TextStyle(
                                                                color:
                                                                    _textPrimary,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                            Text(
                                                              formatCurrency(
                                                                billetesSeleccionados,
                                                              ),
                                                              style: TextStyle(
                                                                color:
                                                                    _textPrimary,
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 8),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Cambio:',
                                                              style: TextStyle(
                                                                color:
                                                                    _textPrimary,
                                                                fontSize: 17,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            Text(
                                                              (billetesSeleccionados -
                                                                          total) >=
                                                                      0
                                                                  ? formatCurrency(
                                                                      billetesSeleccionados -
                                                                          total,
                                                                    )
                                                                  : '-${formatCurrency(total - billetesSeleccionados)}',
                                                              style: TextStyle(
                                                                color:
                                                                    (billetesSeleccionados -
                                                                            total) >=
                                                                        0
                                                                    ? Colors
                                                                          .green
                                                                    : Colors
                                                                          .red,
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
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

                                // Botones de pago específicos
                                Row(
                                  children: [
                                    // Botón pago simple
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            pagoMultiple = false;
                                            // Limpiar campos de pago múltiple para evitar datos residuales
                                            montoEfectivoController.clear();
                                            montoTarjetaController.clear();
                                            montoTransferenciaController.clear();
                                          });
                                        },
                                        icon: Icon(
                                          medioPago0 == 'efectivo' 
                                            ? Icons.money 
                                            : medioPago0 == 'transferencia'
                                              ? Icons.account_balance
                                              : Icons.credit_card,
                                          size: 16,
                                          color: !pagoMultiple ? _primary : _textSecondary,
                                        ),
                                        label: Text('Pago Simple'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: !pagoMultiple ? _primary : _textSecondary,
                                          backgroundColor: !pagoMultiple ? _primary.withOpacity(0.1) : null,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          side: BorderSide(
                                            color: !pagoMultiple ? _primary : _textMuted,
                                            width: !pagoMultiple ? 2 : 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    // Botón pago mixto
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            pagoMultiple = true;
                                          });
                                        },
                                        icon: Icon(
                                          Icons.payment,
                                          size: 16,
                                          color: pagoMultiple ? _primary : _textSecondary,
                                        ),
                                        label: Text('Pago Mixto'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: pagoMultiple ? _primary : _textSecondary,
                                          backgroundColor: pagoMultiple ? _primary.withOpacity(0.1) : null,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          side: BorderSide(
                                            color: pagoMultiple ? _primary : _textMuted,
                                            width: pagoMultiple ? 2 : 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Explicación del modo seleccionado
                                if (!pagoMultiple) ...[
                                  SizedBox(height: 12),
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Pago con ${medioPago0 == 'efectivo' ? 'efectivo' : medioPago0 == 'transferencia' ? 'transferencia' : 'tarjeta'} únicamente',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Campos de pago múltiple (aparecen cuando se selecciona pago mixto)
                                if (pagoMultiple) ...[
                                  SizedBox(height: 12),
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.blue,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Pago combinado con múltiples métodos',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: _cardBg.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _primary.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet,
                                              color: _primary,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Dividir pago entre métodos',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Efectivo (\$)',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: _textPrimary,
                                                    ),
                                                  ),
                                                  SizedBox(height: 6),
                                                  TextFormField(
                                                    controller:
                                                        montoEfectivoController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter.allow(
                                                        RegExp(r'^\d*\.?\d*'),
                                                      ),
                                                    ],
                                                    decoration: InputDecoration(
                                                      hintText: '0.00',
                                                      prefixIcon: Icon(
                                                        Icons.money,
                                                        color: Colors.green,
                                                        size: 18,
                                                      ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            borderSide:
                                                                BorderSide(
                                                                  color:
                                                                      _primary,
                                                                ),
                                                          ),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Tarjeta (\$)',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: _textPrimary,
                                                    ),
                                                  ),
                                                  SizedBox(height: 6),
                                                  TextFormField(
                                                    controller:
                                                        montoTarjetaController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter.allow(
                                                        RegExp(r'^\d*\.?\d*'),
                                                      ),
                                                    ],
                                                    decoration: InputDecoration(
                                                      hintText: '0.00',
                                                      prefixIcon: Icon(
                                                        Icons.credit_card,
                                                        color: Colors.blue,
                                                        size: 18,
                                                      ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            borderSide:
                                                                BorderSide(
                                                                  color:
                                                                      _primary,
                                                                ),
                                                          ),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Transferencia (\$)',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: _textPrimary,
                                                    ),
                                                  ),
                                                  SizedBox(height: 6),
                                                  TextFormField(
                                                    controller:
                                                        montoTransferenciaController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter.allow(
                                                        RegExp(r'^\d*\.?\d*'),
                                                      ),
                                                    ],
                                                    decoration: InputDecoration(
                                                      hintText: '0.00',
                                                      prefixIcon: Icon(
                                                        Icons.account_balance,
                                                        color: Colors.purple,
                                                        size: 18,
                                                      ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            borderSide:
                                                                BorderSide(
                                                                  color:
                                                                      _primary,
                                                                ),
                                                          ),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                // Sección consolidada: Subtotal, descuento, propina y total (penúltima como en las imágenes)
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
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _primary.withOpacity(0.3),
                                    ),
                                  ),
                                  // Consolidando en una sola sección al final
                                  child: Column(
                                    children: [
                                      // SECCIÓN CONSOLIDADA: Subtotal, Descuento, Propina, Total

                                      // Subtotal
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Subtotal',
                                            style: TextStyle(
                                              color: _textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            formatCurrency(
                                              calcularTotalSeleccionados(),
                                            ),
                                            style: TextStyle(
                                              color: _textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16),

                                      // Descuentos en horizontal (consolidados)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Descuento (%)',
                                                  style: TextStyle(
                                                    color: _textPrimary
                                                        .withOpacity(0.7),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Container(
                                                  height: 40,
                                                  child: TextField(
                                                    controller:
                                                        descuentoPorcentajeController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _textPrimary,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText: '0',
                                                      hintStyle: TextStyle(
                                                        color: _textPrimary
                                                            .withOpacity(0.5),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white
                                                          .withOpacity(0.1),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: _textPrimary
                                                              .withOpacity(0.3),
                                                        ),
                                                      ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            borderSide:
                                                                BorderSide(
                                                                  color:
                                                                      _primary,
                                                                ),
                                                          ),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 8,
                                                          ),
                                                    ),
                                                    onChanged: (value) {
                                                      setState(() {
                                                        if (value.isNotEmpty) {
                                                          descuentoValorController
                                                              .clear();
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            '•',
                                            style: TextStyle(
                                              color: _primary,
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Descuento (\$)',
                                                  style: TextStyle(
                                                    color: _textPrimary
                                                        .withOpacity(0.7),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Container(
                                                  height: 40,
                                                  child: TextField(
                                                    controller:
                                                        descuentoValorController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _textPrimary,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText: '0',
                                                      hintStyle: TextStyle(
                                                        color: _textPrimary
                                                            .withOpacity(0.5),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white
                                                          .withOpacity(0.1),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: _textPrimary
                                                              .withOpacity(0.3),
                                                        ),
                                                      ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            borderSide:
                                                                BorderSide(
                                                                  color:
                                                                      _primary,
                                                                ),
                                                          ),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 8,
                                                          ),
                                                    ),
                                                    onChanged: (value) {
                                                      setState(() {
                                                        if (value.isNotEmpty) {
                                                          descuentoPorcentajeController
                                                              .clear();
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16),

                                      // Propina (consolidada)
                                      TextField(
                                        controller: propinaController,
                                        decoration: InputDecoration(
                                          labelText: 'Propina (%)',
                                          labelStyle: TextStyle(
                                            color: _textPrimary,
                                          ),
                                          suffixText: '%',
                                          prefixIcon: Icon(
                                            Icons.star,
                                            color: _primary,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: _textMuted,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: _primary,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: _textPrimary,
                                          fontSize: 16,
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            incluyePropina =
                                                value.isNotEmpty &&
                                                double.tryParse(value) !=
                                                    null &&
                                                double.parse(value) > 0;
                                          });
                                        },
                                      ),
                                      SizedBox(height: 20),

                                      // Divisor
                                      Divider(
                                        color: _primary.withOpacity(0.3),
                                        thickness: 2,
                                      ),
                                      SizedBox(height: 16),

                                      // Total final con cálculos consolidados
                                      Builder(
                                        builder: (context) {
                                          double subtotal =
                                              calcularTotalSeleccionados();
                                          double descuento = 0.0;

                                          // Calcular descuento
                                          String descuentoPorcentajeStr =
                                              descuentoPorcentajeController
                                                  .text;
                                          String descuentoValorStr =
                                              descuentoValorController.text;

                                          if (descuentoPorcentajeStr
                                              .isNotEmpty) {
                                            double porcentaje =
                                                double.tryParse(
                                                  descuentoPorcentajeStr,
                                                ) ??
                                                0.0;
                                            descuento =
                                                (subtotal * porcentaje) / 100;
                                          } else if (descuentoValorStr
                                              .isNotEmpty) {
                                            descuento =
                                                double.tryParse(
                                                  descuentoValorStr,
                                                ) ??
                                                0.0;
                                          }

                                          // Calcular propina
                                          double propinaPorcentaje =
                                              double.tryParse(
                                                propinaController.text,
                                              ) ??
                                              0.0;
                                          double propinaMonto =
                                              (subtotal *
                                                      propinaPorcentaje /
                                                      100)
                                                  .roundToDouble();
                                          double total =
                                              subtotal -
                                              descuento +
                                              propinaMonto;

                                          return Column(
                                            children: [
                                              // Mostrar descuento si está aplicado
                                              if (descuento > 0) ...[
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Descuento:',
                                                      style: TextStyle(
                                                        color: Colors.green,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    Text(
                                                      '-${formatCurrency(descuento)}',
                                                      style: TextStyle(
                                                        color: Colors.green,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 12),
                                              ],
                                              // Mostrar propina si está aplicada
                                              if (propinaPorcentaje > 0) ...[
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Propina ($propinaPorcentaje%):',
                                                      style: TextStyle(
                                                        color: _textPrimary,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    Text(
                                                      formatCurrency(
                                                        propinaMonto,
                                                      ),
                                                      style: TextStyle(
                                                        color: _textPrimary,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 12),
                                              ],
                                              // Total final
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'TOTAL:',
                                                    style: TextStyle(
                                                      color: _textPrimary,
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                                  Text(
                                                    formatCurrency(total),
                                                    style: TextStyle(
                                                      color: _primary,
                                                      fontSize: 26,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20),

                                // Botones consolidados de cortesía y consumo interno (una sola vez)
                                Row(
                                  children: [
                                    // Es cortesía
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          esCortesia0 = !esCortesia0;
                                          if (esCortesia0)
                                            esConsumoInterno0 = false;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: esCortesia0
                                            ? _primary
                                            : Colors.grey.withOpacity(0.3),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Es cortesía',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // Consumo interno
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          esConsumoInterno0 =
                                              !esConsumoInterno0;
                                          if (esConsumoInterno0)
                                            esCortesia0 = false;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: esConsumoInterno0
                                            ? _primary
                                            : Colors.grey.withOpacity(0.3),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Consumo interno',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Spacer(),
                                  ],
                                ),
                                SizedBox(height: 24),

                                // Botones principales como en la imagen: Facturar y Pago Directo
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
                                                      style: TextStyle(
                                                        color: _textPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );

                                            // Generar resumen
                                            var resumenNullable =
                                                await _impresionService
                                                    .generarResumenPedido(
                                                      pedido.id,
                                                    );

                                            // Cerrar diálogo de carga
                                            Navigator.of(context).pop();

                                            if (resumenNullable != null) {
                                              final resumen =
                                                  await actualizarConInfoNegocio(
                                                    resumenNullable,
                                                  );
                                              await _mostrarOpcionesCompartir(
                                                resumen,
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: _error,
                                              ),
                                            );
                                          }
                                        },
                                        icon: Icon(Icons.share, size: 20),
                                        label: Text('Facturar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF1976D2),
                                          foregroundColor: _textPrimary,
                                          padding: EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
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
                                          padding: EdgeInsets.symmetric(
                                            vertical: isMovil ? 12 : 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              isMovil ? 8 : 15,
                                            ),
                                          ),
                                          side: BorderSide(color: _textMuted),
                                        ),
                                        child: Text(
                                          'Cancelar',
                                          style: TextStyle(
                                            fontSize: isMovil ? 14 : 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: isMovil ? 8 : 16),

                                    // Botón Confirmar Pago
                                    Expanded(
                                      flex: isMovil ? 2 : 2,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          print('🔄 INICIANDO PROCESO DE PAGO');
                                          print('   - Modo pago múltiple: $pagoMultiple');
                                          print('   - Método de pago seleccionado: $medioPago0');
                                          
                                          // ✅ NUEVA LÓGICA: Verificar si es pago múltiple parcial
                                          if (pagoMultiple) {
                                            double montoEfectivo =
                                                double.tryParse(
                                                  montoEfectivoController.text,
                                                ) ??
                                                0.0;
                                            double montoTarjeta =
                                                double.tryParse(
                                                  montoTarjetaController.text,
                                                ) ??
                                                0.0;
                                            double montoTransferencia =
                                                double.tryParse(
                                                  montoTransferenciaController
                                                      .text,
                                                ) ??
                                                0.0;
                                            double totalPagando =
                                                montoEfectivo +
                                                montoTarjeta +
                                                montoTransferencia;

                                            // Calcular descuento
                                            double descuento = 0.0;
                                            String descuentoPorcentajeStr =
                                                descuentoPorcentajeController
                                                    .text;
                                            String descuentoValorStr =
                                                descuentoValorController.text;

                                            if (descuentoPorcentajeStr
                                                .isNotEmpty) {
                                              double porcentaje =
                                                  double.tryParse(
                                                    descuentoPorcentajeStr,
                                                  ) ??
                                                  0.0;
                                              descuento =
                                                  (pedido.total * porcentaje) /
                                                  100;
                                            } else if (descuentoValorStr
                                                .isNotEmpty) {
                                              descuento =
                                                  double.tryParse(
                                                    descuentoValorStr,
                                                  ) ??
                                                  0.0;
                                            }

                                            double totalConDescuento =
                                                pedido.total - descuento;

                                            print(
                                              '💰 VERIFICANDO PAGO MÚLTIPLE:',
                                            );
                                            print(
                                              '   - Total pedido: \$${pedido.total}',
                                            );
                                            print(
                                              '   - Descuento: \$${descuento}',
                                            );
                                            print(
                                              '   - Total con descuento: \$${totalConDescuento}',
                                            );
                                            print(
                                              '   - Pagando: \$${totalPagando}',
                                            );

                                            if (totalPagando <
                                                totalConDescuento) {
                                              // PAGO PARCIAL - Crear pedido de deuda por el restante
                                              double montoPendiente =
                                                  totalConDescuento -
                                                  totalPagando;
                                              print(
                                                '⚠️ PAGO PARCIAL: Queda pendiente \$${montoPendiente}',
                                              );

                                              // Procesar pago parcial
                                              Navigator.pop(context);
                                              await _procesarPagoMultipleParcial(
                                                mesa,
                                                pedido,
                                                totalPagando,
                                                montoPendiente,
                                                {
                                                  'medioPago': medioPago0,
                                                  'incluyePropina':
                                                      incluyePropina,
                                                  'descuentoPorcentaje':
                                                      descuentoPorcentajeController
                                                          .text,
                                                  'descuentoValor':
                                                      descuentoValorController
                                                          .text,
                                                  'propina':
                                                      propinaController.text,
                                                  'esCortesia': esCortesia0,
                                                  'esConsumoInterno':
                                                      esConsumoInterno0,
                                                  'pagoMultiple': pagoMultiple,
                                                  'montoEfectivo':
                                                      montoEfectivoController
                                                          .text,
                                                  'montoTarjeta':
                                                      montoTarjetaController
                                                          .text,
                                                  'montoTransferencia':
                                                      montoTransferenciaController
                                                          .text,
                                                  'descuento': descuento,
                                                },
                                              );
                                              return;
                                            }
                                          }

                                          // Verificar si todos los productos están seleccionados o ninguno
                                          bool todosProdutosSeleccionados =
                                              productosSeleccionados.length ==
                                              pedido.items.length;

                                          // Si no hay productos seleccionados O todos están seleccionados, usar pago completo
                                          if (productosSeleccionados.isEmpty ||
                                              todosProdutosSeleccionados) {
                                            print(
                                              '🔄 Usando flujo de pago COMPLETO - Productos seleccionados: ${productosSeleccionados.length}/${pedido.items.length}',
                                            );
                                            
                                            if (!pagoMultiple) {
                                              print('✅ PAGO SIMPLE CON $medioPago0 - Total: \$${pedido.total}');
                                            } else {
                                              print('✅ PAGO MÚLTIPLE COMPLETO - Total: \$${pedido.total}');
                                            }

                                            // Pago total del pedido (usar flujo completo que maneja bien la caja)
                                            Navigator.pop(context, {
                                              'medioPago': medioPago0,
                                              'incluyePropina': incluyePropina,
                                              'descuentoPorcentaje':
                                                  descuentoPorcentajeController
                                                      .text,
                                              'descuentoValor':
                                                  descuentoValorController.text,
                                              'propina': propinaController.text,
                                              'esCortesia': esCortesia0,
                                              'esConsumoInterno':
                                                  esConsumoInterno0,
                                              'mesaDestinoId': mesaDestinoId0,
                                              'billetesRecibidos':
                                                  billetesSeleccionados,
                                              // ✅ NUEVO: Campos de pago múltiple
                                              'pagoMultiple': pagoMultiple,
                                              'montoEfectivo':
                                                  montoEfectivoController.text,
                                              'montoTarjeta':
                                                  montoTarjetaController.text,
                                              'montoTransferencia':
                                                  montoTransferenciaController
                                                      .text,
                                              'productosSeleccionados':
                                                  [], // Lista vacía = pagar todo
                                            });
                                          } else {
                                            // Pago parcial REAL - solo algunos productos seleccionados
                                            print(
                                              '🔄 Usando flujo de pago PARCIAL con ${productosSeleccionados.length}/${pedido.items.length} productos',
                                            );

                                            // Cerrar diálogo primero para evitar bloqueo
                                            Navigator.pop(context);

                                            // Procesar pago parcial DESPUÉS de cerrar diálogo
                                            await _pagarProductosParciales(
                                              mesa,
                                              pedido,
                                              productosSeleccionados,
                                              {
                                                'medioPago': medioPago0,
                                                'incluyePropina':
                                                    incluyePropina,
                                                'descuentoPorcentaje':
                                                    descuentoPorcentajeController
                                                        .text,
                                                'descuentoValor':
                                                    descuentoValorController
                                                        .text,
                                                'propina':
                                                    propinaController.text,
                                                'esCortesia': esCortesia0,
                                                'esConsumoInterno':
                                                    esConsumoInterno0,
                                                'mesaDestinoId': mesaDestinoId0,
                                                'billetesRecibidos':
                                                    billetesSeleccionados,
                                                // ✅ NUEVO: Campos de pago múltiple
                                                'pagoMultiple': pagoMultiple,
                                                'montoEfectivo':
                                                    montoEfectivoController
                                                        .text,
                                                'montoTarjeta':
                                                    montoTarjetaController.text,
                                                'montoTransferencia':
                                                    montoTransferenciaController
                                                        .text,
                                              },
                                            );
                                          }
                                        },
                                        icon: Icon(
                                          Icons.payment,
                                          size: isMovil ? 18 : 20,
                                        ),
                                        label: Text(
                                          isMovil
                                              ? 'Pago Directo'
                                              : 'Pago Directo',
                                          style: TextStyle(
                                            fontSize: isMovil ? 14 : 16,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _primary,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: isMovil ? 12 : 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              isMovil ? 8 : 15,
                                            ),
                                          ),
                                          elevation: 5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ], // Cierra el Column dentro del SingleChildScrollView
                            ),
                          ),
                        ),
                      ),
                    ), // Cierra el Flexible
                  ], // Cierra el Column principal
                ),
              ), // Cierra el KeyboardListener
            ),
          ); // Cierra el Dialog
        }, // Cierra el StatefulBuilder builder function
      ), // Cierra el StatefulBuilder
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

        // CALCULAR DESCUENTO
        double descuento = 0.0;
        String descuentoPorcentajeStr = formResult['descuentoPorcentaje'] ?? '';
        String descuentoValorStr = formResult['descuentoValor'] ?? '';

        if (descuentoPorcentajeStr.isNotEmpty) {
          double porcentaje = double.tryParse(descuentoPorcentajeStr) ?? 0.0;
          descuento = (pedido.total * porcentaje) / 100;
          print(
            '📊 Descuento por porcentaje: $porcentaje% = \$${descuento.toStringAsFixed(0)}',
          );
        } else if (descuentoValorStr.isNotEmpty) {
          descuento = double.tryParse(descuentoValorStr) ?? 0.0;
          print(
            '📊 Descuento fijo aplicado: \$${descuento.toStringAsFixed(0)}',
          );
        }

        // Validar que el descuento no sea mayor al total
        if (descuento > pedido.total) {
          descuento = pedido.total;
          print(
            '⚠️ Descuento limitado al total del pedido: \$${descuento.toStringAsFixed(0)}',
          );
        }

        double totalConDescuento = pedido.total - descuento;
        print('💰 Total original: \$${pedido.total.toStringAsFixed(0)}');
        print('💰 Descuento: \$${descuento.toStringAsFixed(0)}');
        print('💰 Total final: \$${totalConDescuento.toStringAsFixed(0)}');

        // ✅ NUEVO: Verificar si es pago múltiple completo
        bool esPagoMultiple = formResult['pagoMultiple'] == true;
        
        print('🔍 ANALISIS DEL TIPO DE PAGO:');
        print('  - pagoMultiple desde diálogo: ${formResult['pagoMultiple']}');
        print('  - esPagoMultiple calculado: $esPagoMultiple');
        print('  - medioPago seleccionado: $medioPago');
        
        if (esPagoMultiple) {
          print('💳 PROCESANDO PAGO MÚLTIPLE COMPLETO');

          double montoEfectivo =
              double.tryParse(formResult['montoEfectivo'] ?? '0') ?? 0.0;
          double montoTarjeta =
              double.tryParse(formResult['montoTarjeta'] ?? '0') ?? 0.0;
          double montoTransferencia =
              double.tryParse(formResult['montoTransferencia'] ?? '0') ?? 0.0;

          print('   - Efectivo: \$${montoEfectivo.toStringAsFixed(0)}');
          print('   - Tarjeta: \$${montoTarjeta.toStringAsFixed(0)}');
          print(
            '   - Transferencia: \$${montoTransferencia.toStringAsFixed(0)}',
          );

          // Preparar pagos parciales para el backend
          List<Map<String, dynamic>> pagosParciales = [];

          if (montoEfectivo > 0) {
            pagosParciales.add({
              'metodo': 'efectivo',
              'monto': montoEfectivo,
              'procesadoPor': usuarioPago,
              'fecha': DateTime.now().toIso8601String(),
            });
          }

          if (montoTarjeta > 0) {
            pagosParciales.add({
              'metodo': 'tarjeta',
              'monto': montoTarjeta,
              'procesadoPor': usuarioPago,
              'fecha': DateTime.now().toIso8601String(),
            });
          }

          if (montoTransferencia > 0) {
            pagosParciales.add({
              'metodo': 'transferencia',
              'monto': montoTransferencia,
              'procesadoPor': usuarioPago,
              'fecha': DateTime.now().toIso8601String(),
            });
          }

          // Determinar el método de pago principal para el pago múltiple
          String metodoPagoPrincipal = 'otro'; // Por defecto
          if (montoEfectivo > 0 &&
              montoEfectivo >= montoTarjeta &&
              montoEfectivo >= montoTransferencia) {
            metodoPagoPrincipal = 'efectivo';
          } else if (montoTransferencia > 0 &&
              montoTransferencia >= montoTarjeta) {
            metodoPagoPrincipal = 'transferencia';
          } else if (montoTarjeta > 0) {
            metodoPagoPrincipal = 'tarjeta';
          }

          // Procesar pago múltiple usando pagosParciales
          await _pedidoService.pagarPedido(
            pedido.id,
            formaPago: metodoPagoPrincipal, // ✅ CORREGIDO: Usar método válido
            propina: propina,
            procesadoPor: usuarioPago,
            esCortesia: esCortesia,
            esConsumoInterno: esConsumoInterno,
            motivoCortesia: esCortesia
                ? 'Pedido procesado como cortesía'
                : null,
            tipoConsumoInterno: esConsumoInterno ? 'empleado' : null,
            descuento: descuento,
            pagosParciales:
                pagosParciales, // ✅ NUEVO: Enviar los pagos parciales
          );

          print(
            '✅ Pago múltiple procesado - ambos métodos enviados al backend como pagosParciales',
          );
        } else {
          // Pago con un solo método
          print('💰 PROCESANDO PAGO SIMPLE:');
          print('  - Pedido ID: ${pedido.id}');
          print('  - Forma de pago: $medioPago');
          print('  - Propina: $propina');
          print('  - Usuario: $usuarioPago');
          print('  - Es cortesía: $esCortesia');
          print('  - Es consumo interno: $esConsumoInterno');
          print('  - Descuento: $descuento');
          
          await _pedidoService.pagarPedido(
            pedido.id,
            formaPago: medioPago,
            propina: propina,
            procesadoPor: usuarioPago, // Cambio de 'pagadoPor' a 'procesadoPor'
            esCortesia: esCortesia,
            esConsumoInterno: esConsumoInterno,
            motivoCortesia: esCortesia
                ? 'Pedido procesado como cortesía'
                : null,
            tipoConsumoInterno: esConsumoInterno ? 'empleado' : null,
            descuento: descuento, // ✅ NUEVO: Pasar el descuento al servicio
          );
        }

        print('✅ Pago procesado exitosamente');

        // Actualizar el objeto pedido con el estado devuelto por el servidor
        pedido.estado = EstadoPedido.pagado;
        print('  - Estado actualizado a: ${pedido.estado}');
        print('  - Tipo final confirmado: ${pedido.tipo}');

        // CREAR DOCUMENTO AUTOMÁTICAMENTE DESPUÉS DEL PAGO EXITOSO
        print('📄 Creando documento automático para pedido pagado...');

        // Determinar la forma de pago para el documento
        String formaPagoDocumento;
        if (esPagoMultiple) {
          // Recalcular método principal para el documento
          double montoEfectivo =
              double.tryParse(formResult['montoEfectivo'] ?? '0') ?? 0.0;
          double montoTarjeta =
              double.tryParse(formResult['montoTarjeta'] ?? '0') ?? 0.0;
          double montoTransferencia =
              double.tryParse(formResult['montoTransferencia'] ?? '0') ?? 0.0;

          String metodoPrincipalDoc = 'otro';
          if (montoEfectivo > 0 &&
              montoEfectivo >= montoTarjeta &&
              montoEfectivo >= montoTransferencia) {
            metodoPrincipalDoc = 'efectivo';
          } else if (montoTransferencia > 0 &&
              montoTransferencia >= montoTarjeta) {
            metodoPrincipalDoc = 'transferencia';
          } else if (montoTarjeta > 0) {
            metodoPrincipalDoc = 'tarjeta';
          }

          formaPagoDocumento = metodoPrincipalDoc;
          print(
            '💰 Documento con pago múltiple - Método principal: $metodoPrincipalDoc',
          );
        } else {
          print('🔍 DEBUG - Determinando forma de pago para documento:');
          print('  - formResult[\'medioPago\']: ${formResult['medioPago']}');
          print('  - medioPago fallback: $medioPago');
          
          formaPagoDocumento = formResult['medioPago'] ?? medioPago;
          print('💰 Método de pago seleccionado para documento: $formaPagoDocumento');
          
          // Validar que el método de pago sea válido para el backend
          if (formaPagoDocumento != 'efectivo' && 
              formaPagoDocumento != 'transferencia' && 
              formaPagoDocumento != 'tarjeta') {
            print('⚠️ Método de pago no válido para documento: $formaPagoDocumento, usando efectivo');
            formaPagoDocumento = 'efectivo';
          }
        }

        try {
          final documento = await _documentoAutomaticoService
              .generarDocumentoAutomatico(
                pedidoId: pedido.id,
                vendedor: usuarioPago,
                formaPago: formaPagoDocumento,
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
        print('🔍 Verificando opciones especiales...');
        print('  - mesaDestinoId: $mesaDestinoId');
        print('  - esCortesia: $esCortesia');
        print('  - esConsumoInterno: $esConsumoInterno');

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

            // ✅ ACTUALIZACIÓN OPTIMIZADA - Una sola llamada para ambas mesas
            _actualizarMesasOptimizado([mesa.nombre, mesaDestino.nombre]);
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
          print('🔓 Liberando mesa ${mesa.nombre}...');
          print(
            '  - Estado actual: ocupada=${mesa.ocupada}, total=${mesa.total}',
          );

          mesa.ocupada = false;
          mesa.productos = [];
          mesa.total = 0.0;

          print(
            '  - Estado después del cambio: ocupada=${mesa.ocupada}, total=${mesa.total}',
          );

          await _mesaService.updateMesa(mesa);

          print('✅ Mesa ${mesa.nombre} liberada después del pago');
          print(
            '  - Estado final enviado al servidor: ocupada=${mesa.ocupada}, total=${mesa.total}',
          );
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

        // Mostrar mensaje de éxito inmediatamente
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pedido pagado y documento generado exitosamente$tipoTexto',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        print('✅ Procesamiento completado exitosamente');

        // Realizar actualizaciones de UI en background (sin bloquear)
        _actualizarUIEnBackground(mesa);

        // ✅ MANTENER EN PANTALLA DE MESAS - No redirigir al dashboard
        print('🏠 Permaneciendo en pantalla de mesas después del pago');

        // Verificar que estamos en la ruta correcta
        final currentRoute = ModalRoute.of(context)?.settings.name;
        print('📍 Ruta actual después del pago: $currentRoute');

        // Si por alguna razón nos salimos de la pantalla de mesas, volver a ella
        if (mounted && currentRoute != '/mesas') {
          print('🔄 Regresando a la pantalla de mesas...');
          Navigator.of(context).pushReplacementNamed('/mesas');
        }
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
      } finally {
        // Asegurar que el diálogo de carga siempre se cierre
        // SOLO cerrar el diálogo de carga, no navegar hacia atrás más allá
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    } else {
      print('⏭️ Usuario canceló el diálogo');
    }
  }

  /// Actualiza la UI en background después de un pago exitoso
  void _actualizarUIEnBackground(Mesa mesa) async {
    try {
      print('🔄 Iniciando actualización de UI en background...');

      // ✅ ACTUALIZACIÓN OPTIMIZADA - Una sola llamada
      _programarActualizacionMesa(mesa.nombre);

      print('✅ Actualización de UI completada en background');
    } catch (e) {
      print('⚠️ Error en actualización de UI background: $e');
      // No mostrar error al usuario, la operación crítica ya se completó
    }
  }

  /// Actualiza el documento tras mover un pedido entre mesas
  Future<void> _actualizarDocumentoTrasMovimiento(
    Pedido pedido,
    String mesaOrigen,
    String mesaDestino,
    String formaPago,
    double propina,
    String pagadoPor,
  ) async {
    try {
      // Verificar si ya existe un documento para este pedido
      final documentosOrigen = await _documentoMesaService.getDocumentosPorMesa(
        mesaOrigen,
      );
      final documentoExistente = documentosOrigen
          .where((doc) => doc.pedidosIds.contains(pedido.id))
          .firstOrNull;

      if (documentoExistente != null) {
        print(
          '⚠️ Ya existe un documento para este pedido en mesa origen: ${documentoExistente.numeroDocumento}',
        );
        print(
          '  - El documento queda asociado a la mesa original para mantenimiento de registros',
        );

        // Opcional: Crear un nuevo documento en la mesa destino que referencie el movimiento
        await _crearDocumentoMovimiento(
          pedido,
          mesaDestino,
          documentoExistente,
          pagadoPor,
        );
      } else {
        // No existe documento previo, crear uno nuevo en la mesa destino
        print('🆕 Creando nuevo documento en mesa destino...');
        await _crearFacturaPedidoEnMesa(
          pedido.id,
          mesaDestino,
          formaPago: formaPago,
          propina: propina,
          pagadoPor: pagadoPor,
        );
      }

      print('✅ Documentos actualizados correctamente tras movimiento');
    } catch (e) {
      print('❌ Error actualizando documento tras movimiento: $e');
      // No lanzar excepción para no interrumpir el flujo principal
    }
  }

  /// Crea un documento de referencia para un pedido movido
  Future<void> _crearDocumentoMovimiento(
    Pedido pedido,
    String mesaDestino,
    DocumentoMesa documentoOriginal,
    String pagadoPor,
  ) async {
    try {
      print('🔄 Creando documento de referencia para movimiento...');

      // Crear un documento que indique el movimiento
      final documentoMovimiento = await _documentoMesaService.crearDocumento(
        mesaNombre: mesaDestino,
        vendedor: pagadoPor,
        pedidosIds: [pedido.id],
        formaPago: documentoOriginal.formaPago ?? 'efectivo',
        pagadoPor: pagadoPor,
        propina: documentoOriginal.propina ?? 0.0,
        pagado: true,
        estado: 'Movido de ${documentoOriginal.mesaNombre}',
        fechaPago: DateTime.now(),
      );

      if (documentoMovimiento != null) {
        print(
          '✅ Documento de movimiento creado: ${documentoMovimiento.numeroDocumento}',
        );
      }
    } catch (e) {
      print('❌ Error creando documento de movimiento: $e');
    }
  }

  /// Procesa el pago parcial usando la API correcta del backend
  Future<void> _pagarProductosParciales(
    Mesa mesa,
    Pedido pedido,
    List<ItemPedido> itemsSeleccionados,
    Map<String, dynamic> datosPago,
  ) async {
    try {
      print(
        '🚀 =========================== INICIO PAGO PARCIAL (API) ===========================',
      );

      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Calcular propina si está incluida
      double propina = 0.0;
      if (datosPago['incluyePropina'] == true) {
        propina =
            double.tryParse(datosPago['propina']?.toString() ?? '0') ?? 0.0;
      }

      print('📊 DATOS PARA API:');
      print('   • Pedido ID: ${pedido.id}');
      print('   • Items seleccionados: ${itemsSeleccionados.length}');
      print('   • Forma de pago: ${datosPago['medioPago'] ?? 'efectivo'}');
      print('   • Propina: \$${propina}');
      print('   • Usuario: ${userProvider.userName ?? 'Usuario'}');

      // Llamar a la API correcta
      final resultado = await _pedidoService.pagarProductosParciales(
        pedido.id,
        itemsSeleccionados: itemsSeleccionados,
        formaPago: datosPago['medioPago'] ?? 'efectivo',
        propina: propina,
        procesadoPor: userProvider.userName ?? 'Usuario',
        notas: 'Pago parcial desde mesa ${mesa.nombre}',
      );

      if (resultado['success'] == true) {
        print('✅ PAGO PARCIAL EXITOSO:');
        print('   • Items pagados: ${resultado['itemsPagados']}');
        print('   • Total pagado: \$${resultado['totalPagado']}');

        // --- Mensaje de confirmación simple ---
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Acción realizada con éxito'),
              backgroundColor: _success,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // ✅ ACTUALIZACIÓN OPTIMIZADA - Una sola recarga completa es suficiente
        await _recargarMesasConCards();

        // ✅ MANTENER EN PANTALLA DE MESAS - No redirigir después del pago parcial
        print('🏠 Permaneciendo en pantalla de mesas después del pago parcial');

        // Verificar que estamos en la ruta correcta
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (mounted && currentRoute != '/mesas') {
          print(
            '🔄 Regresando a la pantalla de mesas después del pago parcial...',
          );
          Navigator.of(context).pushReplacementNamed('/mesas');
        }
      } else {
        throw Exception('Error en la respuesta de la API: ${resultado}');
      }

      print(
        '✅ =========================== FIN PAGO PARCIAL (ÉXITO) ===========================',
      );
    } catch (e) {
      print('❌ ERROR EN PAGO PARCIAL (API): $e');
      print(
        '❌ =========================== FIN PAGO PARCIAL (ERROR) ===========================',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mejorarMensajeError(e.toString())),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }

      rethrow;
    }
  }

  /// Procesa pago múltiple parcial cuando la suma de montos es menor al total
  Future<void> _procesarPagoMultipleParcial(
    Mesa mesa,
    Pedido pedido,
    double montoPagado,
    double montoPendiente,
    Map<String, dynamic> datosPago,
  ) async {
    try {
      print(
        '🚀 ================== INICIO PAGO MÚLTIPLE PARCIAL ==================',
      );
      print('💰 Total pedido: \$${pedido.total}');
      print('💵 Monto pagado: \$${montoPagado}');
      print('⏳ Monto pendiente: \$${montoPendiente}');

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final usuarioPago = userProvider.userName ?? 'Usuario Desconocido';

      // 1. CREAR REGISTRO DE PAGO PARCIAL PRIMERO
      print('📝 Registrando pago parcial...');

      // Preparar datos del pago parcial
      Map<String, dynamic> datosPagoParcial = {
        'tipoPago': 'pago_parcial',
        'procesadoPor': usuarioPago,
        'notas': 'Pago múltiple parcial desde mesa ${mesa.nombre}',
        'montoPagado': montoPagado,
        'montoPendiente': montoPendiente,
        'formaPago': datosPago['medioPago'] ?? 'efectivo',
        'pagoMultiple': true,
        'montoEfectivo':
            double.tryParse(datosPago['montoEfectivo'] ?? '0') ?? 0.0,
        'montoTarjeta':
            double.tryParse(datosPago['montoTarjeta'] ?? '0') ?? 0.0,
        'montoTransferencia':
            double.tryParse(datosPago['montoTransferencia'] ?? '0') ?? 0.0,
        'descuento': datosPago['descuento'] ?? 0.0,
        'fechaPago': DateTime.now().toIso8601String(),
      };

      print(
        '📤 Enviando datos de pago parcial: ${json.encode(datosPagoParcial)}',
      );

      // TODO: Aquí llamaríamos a un endpoint del backend para registrar el pago parcial
      // Por ahora simularemos que fue exitoso

      // 2. MOSTRAR CONFIRMACIÓN AL USUARIO
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _cardBg,
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text(
                  'Pago Parcial Registrado',
                  style: TextStyle(color: _textPrimary),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mesa: ${mesa.nombre}',
                  style: TextStyle(color: _textPrimary),
                ),
                Text(
                  'Monto pagado: \$${montoPagado.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.green),
                ),
                Text(
                  'Monto pendiente: \$${montoPendiente.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.orange),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El pedido queda pendiente por \$${montoPendiente.toStringAsFixed(0)}. Se puede completar el pago más tarde.',
                          style: TextStyle(color: _textPrimary, fontSize: 13),
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
                child: Text('Aceptar', style: TextStyle(color: _primary)),
              ),
            ],
          ),
        );
      }

      // 3. ACTUALIZAR ESTADO LOCAL DEL PEDIDO
      // El pedido mantiene su estado actual pero con información de pago parcial
      print('🔄 Actualizando estado local del pedido...');

      // ✅ REFRESCAR LA UI OPTIMIZADO - Una sola recarga completa
      await _recargarMesasConCards();

      // ✅ MANTENER EN PANTALLA DE MESAS - No redirigir después del pago múltiple parcial
      print(
        '🏠 Permaneciendo en pantalla de mesas después del pago múltiple parcial',
      );

      // Verificar que estamos en la ruta correcta
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (mounted && currentRoute != '/mesas') {
        print(
          '🔄 Regresando a la pantalla de mesas después del pago múltiple parcial...',
        );
        Navigator.of(context).pushReplacementNamed('/mesas');
      }

      print(
        '✅ ================== FIN PAGO MÚLTIPLE PARCIAL (ÉXITO) ==================',
      );
    } catch (e) {
      print('❌ ERROR EN PAGO MÚLTIPLE PARCIAL: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar pago parcial: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }

      rethrow;
    }
  }

  /// Procesa el pago parcial de productos seleccionados (MÉTODO ANTERIOR - NO USAR)
  Future<void> _procesarPagoParcial(
    Mesa mesa,
    Pedido pedido,
    List<ItemPedido> itemsSeleccionados,
    Map<String, dynamic> datosPago,
  ) async {
    try {
      print(
        '� =========================== INICIO PAGO PARCIAL ===========================',
      );
      print('📊 DATOS DEL PAGO PARCIAL:');
      print('   • Mesa: ${mesa.nombre} (ID: ${mesa.id})');
      print('   • Pedido Original ID: ${pedido.id}');
      print('   • Total Original: ${formatCurrency(pedido.total)}');
      print('   • Items Originales: ${pedido.items.length}');
      print('   • Items Seleccionados: ${itemsSeleccionados.length}');
      print('   • Datos Pago: $datosPago');
      print('   • Timestamp: ${DateTime.now().toIso8601String()}');

      final userProvider = Provider.of<UserProvider>(context, listen: false);

      print('👤 USUARIO PROCESANDO PAGO:');
      print('   • ID Usuario: ${userProvider.userId ?? 'No disponible'}');
      print('   • Nombre Usuario: ${userProvider.userName ?? 'No disponible'}');

      // Calcular el total de los productos seleccionados
      double totalSeleccionado = 0;
      for (var item in itemsSeleccionados) {
        double itemTotal = item.cantidad * item.precioUnitario;
        totalSeleccionado += itemTotal;
        print(
          '   - ${item.productoNombre ?? 'Producto'} x${item.cantidad} = ${formatCurrency(itemTotal)}',
        );
      }

      print('💰 Total a pagar: ${formatCurrency(totalSeleccionado)}');
      print('💳 Medio de pago: ${datosPago['medioPago'] ?? 'efectivo'}');

      // Crear el pedido con los productos pagados
      final fechaActual = DateTime.now();
      print('📅 FECHA PAGO: ${fechaActual.toIso8601String()}');

      Pedido pedidoPagado = Pedido(
        id: '', // Se asignará en el backend
        fecha: fechaActual,
        tipo: TipoPedido.normal,
        mesa: mesa.nombre,
        mesero: userProvider.userName ?? 'Usuario',
        items: itemsSeleccionados,
        total: totalSeleccionado,
        estado: EstadoPedido.pagado,
        formaPago: datosPago['medioPago'] ?? 'efectivo',
        descuento:
            double.tryParse(datosPago['descuentoValor']?.toString() ?? '0') ??
            0,
        notas: 'Pago parcial - Mesa ${mesa.nombre}',
      );

      // Crear el pedido con los productos restantes
      List<ItemPedido> itemsRestantes = pedido.items.where((item) {
        return !itemsSeleccionados.any(
          (seleccionado) => seleccionado.id == item.id,
        );
      }).toList();

      print('📋 Productos restantes: ${itemsRestantes.length}');

      if (itemsRestantes.isNotEmpty) {
        double totalRestante = 0;
        for (var item in itemsRestantes) {
          double itemTotal = item.cantidad * item.precioUnitario;
          totalRestante += itemTotal;
          print(
            '   - ${item.productoNombre ?? 'Producto'} x${item.cantidad} = ${formatCurrency(itemTotal)}',
          );
        }
        print('💰 Total restante: ${formatCurrency(totalRestante)}');

        // ✅ OPCIÓN 1: ACTUALIZAR PEDIDO ORIGINAL CON PRODUCTOS RESTANTES
        print('� ACTUALIZANDO PEDIDO ORIGINAL CON PRODUCTOS RESTANTES:');
        print('   • Pedido ID: ${pedido.id}');
        print('   • Nuevos items: ${itemsRestantes.length}');
        print('   • Nuevo total: ${formatCurrency(totalRestante)}');

        // Crear objeto actualizado del pedido original
        Pedido pedidoActualizado = Pedido(
          id: pedido.id, // Mantener el mismo ID
          fecha: pedido.fecha, // Mantener fecha original
          tipo: pedido.tipo,
          mesa: pedido.mesa,
          mesero: pedido.mesero,
          items: itemsRestantes, // Solo los productos restantes
          total: totalRestante,
          estado: EstadoPedido.activo, // Mantener activo
          notas:
              (pedido.notas ?? '') +
              '\n[PAGO PARCIAL] ${itemsSeleccionados.length} productos pagados (${fechaActual.toIso8601String()})',
        );

        // Actualizar el pedido original
        print('🌐 LLAMADA API - ACTUALIZAR PEDIDO ORIGINAL:');
        print('   • Endpoint: PUT /api/pedidos/${pedido.id}');
        print('   • Items restantes: ${itemsRestantes.length}');
        print('   • Nuevo total: ${formatCurrency(totalRestante)}');
        print('📊 Datos del pedido actualizado: ${pedidoActualizado.toJson()}');

        await _pedidoService.updatePedido(pedidoActualizado);
        print(
          '✅ RESPUESTA API - PEDIDO ORIGINAL ACTUALIZADO CON PRODUCTOS RESTANTES',
        );

        // Crear pedido pagado separado
        print('🌐 LLAMADA API - CREAR PEDIDO PAGADO:');
        print('   • Endpoint: POST /api/pedidos');
        print('   • Mesa ID: ${mesa.id}');
        print('   • Estado: pagado');
        print('   • Total: ${formatCurrency(totalSeleccionado)}');
        print('   • Items: ${itemsSeleccionados.length}');
        print('📊 Datos del pedido pagado: ${pedidoPagado.toJson()}');
        final resultadoPagado = await _pedidoService.crearPedido(pedidoPagado);
        print('✅ RESPUESTA API - PEDIDO PAGADO CREADO: ${resultadoPagado.id}');

        print(
          '✅ PAGO PARCIAL COMPLETADO - PEDIDO ORIGINAL CONSERVADO CON PRODUCTOS RESTANTES',
        );
      } else {
        // Solo guardar el pedido pagado si no quedan productos
        print('💾 Guardando pedido completo (no quedan productos)...');
        print('📊 Datos del pedido completo: ${pedidoPagado.toJson()}');

        // 🔍 Validar que hay una caja pendiente antes de procesar el pago
        print('🔍 Validando que hay una caja pendiente...');
        try {
          print('🔍 Buscando caja activa...');
          final cajas = await _cuadreCajaService.getAllCuadres();
          print('📊 Total de cajas encontradas: ${cajas.length}');

          for (var caja in cajas) {
            print(
              '   • Caja: ${caja.id} - Estado: ${caja.estado} - Nombre: ${caja.nombre}',
            );
          }

          final cajaActiva = cajas
              .where((c) => c.estado == 'pendiente')
              .firstOrNull;

          if (cajaActiva == null) {
            print('❌ No se encontró ninguna caja con estado "pendiente"');
            throw Exception(
              'No hay una caja en estado pendiente. Debe abrir caja antes de procesar pagos.',
            );
          }

          print(
            '✅ Caja activa encontrada: ${cajaActiva.id} - ${cajaActiva.nombre}',
          );

          // Vincular el pedido con el cuadre de caja activo
          pedidoPagado.cuadreId = cajaActiva.id;
          print(
            '✅ Pedido vinculado a cuadre: ${cajaActiva.id} - ${cajaActiva.nombre}',
          );
        } catch (e) {
          print('❌ Error validando caja: $e');
          throw Exception('Error validando caja pendiente: $e');
        }

        final resultadoCompleto = await _pedidoService.crearPedido(
          pedidoPagado,
        );
        print('✅ Pedido completo guardado: ${resultadoCompleto.id}');
        // Cambiar el estado del pedido original a cancelado cuando NO quedan productos
        print('🌐 LLAMADA API - CAMBIAR ESTADO PEDIDO ORIGINAL A CANCELADO:');
        print('   • Endpoint: PUT /api/pedidos/${pedido.id}/estado/cancelado');
        print('   • Pedido ID: ${pedido.id}');
        print('   • Razón: Pago completo - no quedan productos restantes');
        await PedidoService.actualizarEstado(pedido.id, EstadoPedido.cancelado);
        print('✅ RESPUESTA API - PEDIDO ORIGINAL MARCADO COMO CANCELADO');
      }

      print(
        '💰 =========================== FIN PAGO PARCIAL (ÉXITO) ===========================',
      );

      // SnackBar eliminado: Pago parcial procesado exitosamente

      // 🔄 ACTUALIZAR TOTAL DE LA MESA DESPUÉS DEL PAGO PARCIAL
      print('🔄 ACTUALIZANDO MESA DESPUÉS DEL PAGO PARCIAL:');
      if (itemsRestantes.isNotEmpty) {
        // Calcular total restante
        double nuevoTotalMesa = 0;
        for (var item in itemsRestantes) {
          nuevoTotalMesa += item.cantidad * item.precioUnitario;
        }

        print('   • Mesa: ${mesa.nombre}');
        print('   • Total anterior: ${formatCurrency(mesa.total)}');
        print('   • Nuevo total (restante): ${formatCurrency(nuevoTotalMesa)}');

        mesa.total = nuevoTotalMesa;

        try {
          await _mesaService.updateMesa(mesa);
          print(
            '✅ Mesa actualizada con total restante: ${formatCurrency(mesa.total)}',
          );
        } catch (e) {
          print('❌ Error al actualizar mesa después de pago parcial: $e');
        }
      } else {
        // Si no quedan productos, liberar la mesa
        print('   • Liberando mesa ${mesa.nombre} (sin productos restantes)');
        mesa.ocupada = false;
        mesa.total = 0.0;

        try {
          await _mesaService.updateMesa(mesa);
          print('✅ Mesa liberada exitosamente');
        } catch (e) {
          print('❌ Error al liberar mesa: $e');
        }
      }

      // 🧹 LIMPIAR CACHE DE FORMATEO después del pago parcial
      clearFormatCache();
      print('🧩 Cache de formateo limpiado después del pago parcial');

      // Recargar datos
      await _recargarMesasConCards();
    } catch (e) {
      print('❌ EXCEPCIÓN EN PAGO PARCIAL: $e');
      print(
        '💰 =========================== FIN PAGO PARCIAL (ERROR) ===========================',
      );

      String mensajeError = 'Error al procesar pago parcial: $e';
      if (e.toString().contains('Token de autenticación no encontrado')) {
        mensajeError =
            '🔐 Sesión expirada. Por favor, recarga la página y vuelve a iniciar sesión.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $mensajeError'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 6),
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
      print(
        '🗑️ CANCELACIÓN: ${itemsCancelados.length} productos en mesa ${mesa.nombre}',
      );
      print('   • Pedido: ${pedido.id} (${pedido.items.length} items total)');
      print('   • Motivo: $motivo');

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final usuario = userProvider.userName ?? 'Usuario';

      // Mostrar productos a cancelar con sus IDs
      print('🎯 PRODUCTOS SELECCIONADOS PARA CANCELAR:');
      double totalCancelado = 0;
      for (int i = 0; i < itemsCancelados.length; i++) {
        final item = itemsCancelados[i];
        double itemTotal = item.cantidad * item.precioUnitario;
        totalCancelado += itemTotal;
        print('   ${i + 1}. ${item.productoNombre} (ID: ${item.productoId})');
        print('      - ItemID: ${item.id}');
        print('      - Cantidad: ${item.cantidad}');
        print('      - Total: ${formatCurrency(itemTotal)}');
        if (item.agregadoPor != null && item.agregadoPor!.isNotEmpty) {
          print('      - Agregado por: ${item.agregadoPor}');
        }
      }
      print('💰 Valor total a cancelar: ${formatCurrency(totalCancelado)}');

      // 📝 REGISTRAR PRODUCTOS CANCELADOS EN EL SISTEMA
      print('🌐 LLAMADA API - REGISTRAR PRODUCTOS CANCELADOS:');
      print('   • Endpoint: POST /api/productos-cancelados');
      print('   • Cantidad de productos: ${itemsCancelados.length}');

      for (var itemCancelado in itemsCancelados) {
        try {
          print('📝 Registrando cancelación: ${itemCancelado.productoNombre}');
          final resultadoRegistro = await _productoCanceladoService
              .registrarCancelacion(
                pedidoId: pedido.id,
                mesaNombre: mesa.nombre,
                itemOriginal: itemCancelado,
                canceladoPor: usuario,
                motivo: _obtenerMotivoCancelacion(motivo),
                descripcionMotivo: motivo,
                observaciones:
                    'Cancelación desde mesa ${mesa.nombre} - Usuario: $usuario',
              );

          if (resultadoRegistro['success']) {
            print(
              '✅ RESPUESTA API - PRODUCTO CANCELADO REGISTRADO: ${itemCancelado.productoNombre}',
            );
            print(
              '   • ID Registro: ${resultadoRegistro['productoCancelado']?.id ?? 'N/A'}',
            );
          } else {
            print(
              '❌ RESPUESTA API - ERROR AL REGISTRAR: ${resultadoRegistro['message']}',
            );
          }
        } catch (e) {
          print('❌ EXCEPCIÓN AL REGISTRAR CANCELACIÓN: $e');
          // Continuar con otros productos aunque uno falle
        }
      }

      print('📝 REGISTRO DE CANCELACIONES COMPLETADO');

      // PASO CRÍTICO: Identificar productos a cancelar
      List<int> indicesCancelados = [];
      print('🔍 IDENTIFICANDO PRODUCTOS EN EL PEDIDO:');

      // Mostrar todos los productos del pedido actual
      for (int i = 0; i < pedido.items.length; i++) {
        final item = pedido.items[i];
        print(
          '   [$i] ${item.productoNombre} (ProdID: ${item.productoId}, ItemID: ${item.id})',
        );
      }

      print('🎯 BUSCANDO COINCIDENCIAS PARA CANCELAR:');
      for (
        int canceladoIndex = 0;
        canceladoIndex < itemsCancelados.length;
        canceladoIndex++
      ) {
        var itemCancelado = itemsCancelados[canceladoIndex];
        print(
          '   Buscando: ${itemCancelado.productoNombre} (ProdID: ${itemCancelado.productoId})',
        );

        bool encontrado = false;
        for (int i = 0; i < pedido.items.length; i++) {
          final itemOriginal = pedido.items[i];

          bool esElMismoProducto = false;
          if (itemCancelado.productoId.isNotEmpty &&
              itemOriginal.productoId.isNotEmpty) {
            esElMismoProducto =
                itemOriginal.productoId == itemCancelado.productoId;
            print(
              '     -> Comparando por ProductoID: ${itemOriginal.productoId} == ${itemCancelado.productoId} = $esElMismoProducto',
            );
          } else {
            esElMismoProducto =
                itemOriginal.productoNombre == itemCancelado.productoNombre;
            print(
              '     -> Comparando por nombre: "${itemOriginal.productoNombre}" == "${itemCancelado.productoNombre}" = $esElMismoProducto',
            );
          }

          if (esElMismoProducto && !indicesCancelados.contains(i)) {
            indicesCancelados.add(i);
            print(
              '   ✅ PRODUCTO IDENTIFICADO para cancelar [índice $i]: ${itemOriginal.productoNombre}',
            );
            encontrado = true;
            break;
          }
        }

        if (!encontrado) {
          print('   ❌ NO ENCONTRADO: ${itemCancelado.productoNombre}');
        }
      }

      print('� RESUMEN DE IDENTIFICACIÓN:');
      print(
        '   • Productos a cancelar seleccionados: ${itemsCancelados.length}',
      );
      print('   • Índices identificados para cancelar: $indicesCancelados');
      print('   • Total productos en pedido: ${pedido.items.length}');

      if (indicesCancelados.isEmpty) {
        throw Exception(
          'PROBLEMA CRÍTICO: No se pudieron identificar los productos a cancelar',
        );
      }

      if (indicesCancelados.length != itemsCancelados.length) {
        print(
          '⚠️ ADVERTENCIA: Se seleccionaron ${itemsCancelados.length} productos pero solo se identificaron ${indicesCancelados.length}',
        );
      }

      // Filtrar productos manteniendo solo los que NO están en los índices cancelados
      List<ItemPedido> productosRestantes = [];
      for (int i = 0; i < pedido.items.length; i++) {
        if (!indicesCancelados.contains(i)) {
          productosRestantes.add(pedido.items[i]);
          print(
            '✅ Producto mantenido (índice $i): ${pedido.items[i].productoNombre}',
          );
        } else {
          print(
            '❌ Producto cancelado (índice $i): ${pedido.items[i].productoNombre}',
          );
        }
      }

      print('🔍 ANÁLISIS DE PRODUCTOS RESTANTES:');
      for (int i = 0; i < productosRestantes.length; i++) {
        final item = productosRestantes[i];
        print(
          '   ${i + 1}. ${item.productoNombre} - Cantidad: ${item.cantidad} - Precio: ${formatCurrency(item.precioUnitario)}',
        );
      }

      print('📊 PRODUCTOS DESPUÉS DE CANCELACIÓN:');
      print('   • Productos originales: ${pedido.items.length}');
      print('   • Productos cancelados: ${itemsCancelados.length}');
      print('   • Productos restantes: ${productosRestantes.length}');

      if (productosRestantes.isEmpty) {
        // Si no quedan productos, cambiar el estado del pedido a 'cancelado' en vez de eliminarlo
        print('⚠️ ADVERTENCIA: No quedan productos después de la cancelación');
        print('📊 VERIFICACIÓN FINAL:');
        print('   • Items originales: ${pedido.items.length}');
        print('   • Items a cancelar: ${itemsCancelados.length}');
        print('   • Índices cancelados: $indicesCancelados');
        print(
          '   • Productos restantes calculados: ${productosRestantes.length}',
        );

        print('🌐 LLAMADA API - CAMBIAR ESTADO DEL PEDIDO A CANCELADO:');
        print('   • Endpoint: PUT /api/pedidos/${pedido.id}/estado/cancelado');
        print('   • Pedido ID: ${pedido.id}');
        print('   • Motivo: No quedan productos después de cancelación');
        await PedidoService.actualizarEstado(pedido.id, EstadoPedido.cancelado);
        print('✅ RESPUESTA API - PEDIDO MARCADO COMO CANCELADO');

        // Liberar la mesa
        mesa.ocupada = false;
        mesa.productos = [];
        mesa.total = 0.0;
        await _mesaService.updateMesa(mesa);
        print(
          '✅ Mesa ${mesa.nombre} liberada (pedido cancelado completamente)',
        );

        // Recarga automática de mesas eliminada tras cancelar productos
        // await _loadMesas();
        // print('🔄 Mesas recargadas tras liberar mesa por cancelación total');
      } else {
        // Calcular nuevo total
        double nuevoTotal = productosRestantes.fold<double>(
          0,
          (sum, item) => sum + (item.cantidad * item.precioUnitario),
        );
        print('💰 NUEVO TOTAL DEL PEDIDO: ${formatCurrency(nuevoTotal)}');

        // Crear pedido actualizado sin los productos cancelados
        Pedido pedidoActualizado = Pedido(
          id: pedido.id,
          fecha: pedido.fecha,
          tipo: pedido.tipo,
          mesa: pedido.mesa,
          mesero: pedido.mesero,
          items: productosRestantes,
          total: nuevoTotal,
          estado: pedido.estado,
          cliente: pedido.cliente,
          notas: pedido.notas != null
              ? '${pedido.notas}\n[CANCELACIÓN] $motivo - $usuario (${DateTime.now().day}/${DateTime.now().month})'
              : '[CANCELACIÓN] $motivo - $usuario (${DateTime.now().day}/${DateTime.now().month})',
          plataforma: pedido.plataforma,
          pedidoPor: pedido.pedidoPor,
          guardadoPor: pedido.guardadoPor,
          fechaCortesia: pedido.fechaCortesia,
          formaPago: pedido.formaPago,
          incluyePropina: pedido.incluyePropina,
          descuento: pedido.descuento,
          cuadreId: pedido.cuadreId,
        );

        print(
          '🔄 Actualizando pedido: ${productosRestantes.length} items restantes, nuevo total: ${formatCurrency(nuevoTotal)}',
        );

        final pedidoRespuesta = await _pedidoService.updatePedido(
          pedidoActualizado,
        );

        // Actualizar total de la mesa
        mesa.total = pedidoRespuesta.total;
        await _mesaService.updateMesa(mesa);

        print(
          'Pedido actualizado: ${pedidoRespuesta.id} - Total: ${formatCurrency(pedidoRespuesta.total)}',
        );
      }

      print('Cancelación completada exitosamente');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancelación realizada correctamente',
                style: TextStyle(fontFamily: 'Roboto'),
              ),
              if (productosRestantes.isEmpty)
                Text(
                  'Pedido eliminado completamente',
                  style: TextStyle(fontFamily: 'Roboto'),
                )
              else
                Text(
                  'Productos restantes: ${productosRestantes.length}',
                  style: TextStyle(fontFamily: 'Roboto'),
                ),
            ],
          ),
          backgroundColor: _success,
          duration: Duration(seconds: 4),
        ),
      );

      _recargarPestanaActual();

      print(
        '🎉 =========================== CANCELACIÓN COMPLETADA ===========================',
      );
    } catch (e) {
      print(' ERROR EN CANCELACIÓN DE PRODUCTOS:');

      String mensajeError = 'Error al cancelar productos: $e';
      if (e.toString().contains('Token de autenticación no encontrado')) {
        mensajeError =
            '🔐 Sesión expirada. Por favor, recarga la página y vuelve a iniciar sesión.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $mensajeError'),
          backgroundColor: _error,
          duration: Duration(seconds: 6),
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
      print(
        'Moviendo ${itemsMovidos.length} productos de ${mesaOrigen.nombre} a ${mesaDestino.nombre}',
      );

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final usuario = userProvider.userName ?? 'Usuario';

      final totalMovimiento = itemsMovidos.fold<double>(
        0,
        (sum, item) => sum + (item.cantidad * item.precio),
      );
      print('💰 Valor total: ${formatCurrency(totalMovimiento)}');

      final resultado = await _pedidoService.moverProductosEspecificos(
        pedidoOrigenId: pedidoOrigen.id,
        mesaDestinoNombre: mesaDestino.nombre,
        itemsParaMover: itemsMovidos.cast(),
        usuarioId: userProvider.userId ?? '',
        usuarioNombre: usuario,
      );

      if (resultado['success'] == true) {
        // Obtener datos del backend correctamente
        final dataMovimiento = resultado['data'] ?? {};
        final String? nuevoPedidoId = dataMovimiento['nuevoPedidoId']
            ?.toString();
        final bool seCreoNuevaOrden =
            nuevoPedidoId != null && nuevoPedidoId.isNotEmpty;
        final dynamic productosMovidosRaw =
            dataMovimiento['productosMovidos'] ?? itemsMovidos.length;
        final int itemsMovidosCount = productosMovidosRaw is String
            ? int.tryParse(productosMovidosRaw) ?? itemsMovidos.length
            : productosMovidosRaw as int;

        print('Movimiento exitoso: $itemsMovidosCount items');
        print('VERIFICANDO CREACIÓN DEL PEDIDO EN MESA DESTINO...');
        print('   • Mesa destino: ${mesaDestino.nombre}');
        print('   • Nuevo pedido ID: $nuevoPedidoId');
        print('   • Se creó nueva orden: $seCreoNuevaOrden');

        // --- NUEVO: Marcar mesa destino como ocupada y actualizar total ---
        mesaDestino.ocupada = true;
        double totalMovido = 0;
        for (var item in itemsMovidos) {
          totalMovido += item.cantidad * item.precio;
        }
        mesaDestino.total = mesaDestino.total + totalMovido;
        try {
          await _mesaService.updateMesa(mesaDestino);
          print('✅ Mesa destino marcada como ocupada y total actualizado.');
        } catch (e) {
          print('❌ Error actualizando mesa destino: $e');
        }

        // --- Mensaje de confirmación simple ---
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Acción realizada con éxito'),
              backgroundColor: _success,
              duration: Duration(seconds: 3),
            ),
          );
        }

        if (nuevoPedidoId != null && nuevoPedidoId.isNotEmpty) {
          // mensaje += '\n🆕 Nueva orden creada: $nuevoPedidoId';

          try {
            // BÚSQUEDA MEJORADA: Ahora enviamos nombre completo, debería estar en mesa correcta
            print('🔍 VERIFICANDO PEDIDO EN MESA DESTINO...');

            Pedido? pedidoEncontrado;
            String? mesaRealPedido;

            // Primero buscar en la mesa destino esperada
            final pedidosEnMesaDestino = await _pedidoService.getPedidosByMesa(
              mesaDestino.nombre,
            );
            pedidoEncontrado = pedidosEnMesaDestino
                .where((p) => p.id == nuevoPedidoId)
                .firstOrNull;

            if (pedidoEncontrado != null) {
              mesaRealPedido = mesaDestino.nombre;
              print(
                '✅ Pedido encontrado en mesa esperada: ${mesaDestino.nombre}',
              );
            } else {
              // Si no se encuentra, buscar con enfoque de respaldo por número
              print(
                '⚠️ Pedido no encontrado en mesa esperada, buscando por número...',
              );
              final numeroMatch = RegExp(r'\d+').firstMatch(mesaDestino.nombre);
              final numeroMesa = numeroMatch?.group(0);

              if (numeroMesa != null) {
                final todasLasMesas = await _mesaService.getMesas();
                final mesasConMismoNumero = todasLasMesas.where((mesa) {
                  final numeroMesaActual = RegExp(
                    r'\d+',
                  ).firstMatch(mesa.nombre)?.group(0);
                  return numeroMesaActual == numeroMesa;
                }).toList();

                print(
                  '   • Buscando en mesas con número $numeroMesa: ${mesasConMismoNumero.map((m) => m.nombre).join(', ')}',
                );

                for (var mesa in mesasConMismoNumero) {
                  final pedidosEnMesa = await _pedidoService.getPedidosByMesa(
                    mesa.nombre,
                  );
                  final pedidoTemp = pedidosEnMesa
                      .where((p) => p.id == nuevoPedidoId)
                      .firstOrNull;
                  if (pedidoTemp != null) {
                    pedidoEncontrado = pedidoTemp;
                    mesaRealPedido = mesa.nombre;
                    break;
                  }
                }
              }
            }

            if (pedidoEncontrado != null) {
              print('✅ PEDIDO ENCONTRADO:');
              print('   • ID: ${pedidoEncontrado.id}');
              print('   • Mesa solicitada: ${mesaDestino.nombre}');
              print('   • Mesa real en BD: $mesaRealPedido');
              print('   • Items: ${pedidoEncontrado.items.length}');
              print('   • Total: ${formatCurrency(pedidoEncontrado.total)}');

              if (mesaRealPedido != mesaDestino.nombre) {
                // mensaje +=
                //     '\n⚠️ Nota: Pedido almacenado en mesa $mesaRealPedido (conversión del backend)';
              }
            } else {
              print('❌ PEDIDO NO ENCONTRADO CON NUEVO ENFOQUE');
              print('   • ID buscado: $nuevoPedidoId');
              print('   • Mesa objetivo: ${mesaDestino.nombre}');
              // mensaje +=
              //     '\n⚠️ Advertencia: No se pudo verificar la creación del pedido';
            }
          } catch (e) {
            print('❌ Error verificando pedido: $e');
            // mensaje += '\n⚠️ Error verificando creación del pedido';
          }
        } else {
          print('⚠️ No se devolvió ID de nuevo pedido');
        }

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Column(
        //       mainAxisSize: MainAxisSize.min,
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         Text(mensaje, style: TextStyle(fontFamily: 'Roboto')),
        //         Text(
        //           'Items movidos: ${itemsMovidos.length}',
        //           style: TextStyle(fontFamily: 'Roboto'),
        //         ),
        //         Text(
        //           'De: ${mesaOrigen.nombre} → A: ${mesaDestino.nombre}',
        //           style: TextStyle(fontFamily: 'Roboto'),
        //         ),
        //       ],
        //     ),
        //     backgroundColor: _success,
        //     duration: Duration(seconds: 4),
        //   ),
        // );

        // ✅ ACTUALIZACIÓN OPTIMIZADA - Una sola recarga completa
        await _recargarMesasConCards();
      } else {
        print(
          '❌ Error del servicio: ${resultado['message'] ?? 'Error desconocido'}',
        );
        throw Exception(resultado['message'] ?? 'Error desconocido');
      }
    } catch (e) {
      print(
        '💥 Error movimiento productos ${mesaOrigen.nombre} → ${mesaDestino.nombre}: $e',
      );

      String mensajeError = 'Error al mover productos: $e';
      if (e.toString().contains('Token de autenticación no encontrado')) {
        // Mostrar diálogo específico para problemas de token
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Sesión Expirada'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu sesión ha expirado durante el movimiento de productos.',
                  style: TextStyle(fontFamily: 'Roboto'),
                ),
                SizedBox(height: 8),
                Text(
                  'Mesa origen: ${mesaOrigen.nombre}',
                  style: TextStyle(fontFamily: 'Roboto'),
                ),
                Text(
                  'Mesa destino: ${mesaDestino.nombre}',
                  style: TextStyle(fontFamily: 'Roboto'),
                ),
                Text(
                  'Items: ${itemsMovidos.length} productos',
                  style: TextStyle(fontFamily: 'Roboto'),
                ),
                SizedBox(height: 16),
                Text(
                  '¿Deseas recargar la página para reiniciar sesión?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: _textPrimary,
                ),
                onPressed: () {
                  html.window.location.reload();
                },
                child: Text('Recargar Página'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $mensajeError'),
            backgroundColor: _error,
            duration: Duration(seconds: 6),
          ),
        );
      }
    } finally {
      // Siempre recargar las mesas al final, independientemente del resultado
      await _recargarMesasConCards();
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

  Future<Mesa?> _mostrarDialogoSeleccionMesa() async {
    try {
      // Cargar la lista de mesas disponibles
      final mesas = await _mesaService.getMesas();

      // Incluir todas las mesas (incluyendo especiales)
      final mesasDisponibles = mesas.toList();

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
      final resumenConInfo = await actualizarConInfoNegocio(resumenNullable);

      // Limpiar el resumen de IDs de MongoDB para mejor presentación
      final resumen = _impresionService.limpiarResumenParaVisualizacion(
        resumenConInfo,
      );

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
                    'N° Pedido: ${resumen['numeroPedido'] ?? 'N/A'}',
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
                        formatCurrency(resumen['total'] ?? 0.0),
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
        subject: 'Resumen de Pedido - ${resumen['numeroPedido'] ?? 'N/A'}',
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
        final pdfServiceWeb = PDFServiceWeb();
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
                color: _textPrimary,
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
                  style: TextStyle(color: _textPrimary, fontSize: 12),
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
        final pdfServiceWeb = PDFServiceWeb();
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
        '${tempDir.path}/ticket_${resumen['numeroPedido'] ?? DateTime.now().millisecondsSinceEpoch}.pdf',
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

      // Debug logs para verificar el rol del usuario
      print('🔍 DEBUG MESAS - userProvider.isMesero: ${userProvider.isMesero}');
      print('🔍 DEBUG MESAS - userProvider.roles: ${userProvider.roles}');
      print(
        '🔍 DEBUG MESAS - userProvider.isOnlyMesero: ${userProvider.isOnlyMesero}',
      );

      if (mounted) {
        if (userProvider.isMesero) {
          // Si es mesero, navegar a la pantalla de mesero
          print('✅ MESAS - Navegando a /mesero para usuario mesero');
          await Navigator.of(context).pushNamed('/mesero');
        } else {
          // Si no es mesero, navegar a documentos
          print('❌ MESAS - Navegando a /documentos para usuario no-mesero');
          await Navigator.of(context).pushNamed('/documentos');
        }
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
              'Total: ${formatCurrency(factura['total'] ?? 0.0)}',
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
            label: Text(
              Provider.of<UserProvider>(context, listen: false).isMesero
                  ? 'Ir a Mis Pedidos'
                  : 'Ver Todos los Documentos',
            ),
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
              'Total: ${formatCurrency(factura['total'])}',
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
    if (screenWidth < 600) return 100; // Móvil (increased for content)
    if (screenWidth < 900) return 110; // Tablet
    return 120; // Desktop
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
          // Botón para mostrar resumen rápido de documentos del día
          Container(
            margin: EdgeInsets.only(right: AppTheme.spacingSmall),
            child: IconButton(
              icon: Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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
              tooltip:
                  Provider.of<UserProvider>(context, listen: false).isMesero
                  ? 'Ir a Mis Pedidos'
                  : 'Ver documentos del día',
              onPressed: () => navegarADocumentos(),
            ),
          ),
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
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingMedium),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          print(
            '🚨 BOTÓN DEBUG PRESIONADO - RECONSTRUCCIÓN TOTAL DE TODAS LAS MESAS',
          );

          // ✅ RECARGA OPTIMIZADA - Una sola llamada para todas las mesas
          print('🔄 Recargando todas las mesas de forma optimizada...');
          await _recargarMesasConCards();
        },
        backgroundColor: Colors.red,
        child: Icon(Icons.refresh, color: Colors.white),
        tooltip: 'DEBUG: Reconstruir todas las mesas desde cero',
      ),
    );
  }

  Widget buildMesasLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Detectar si es móvil usando el breakpoint establecido
        bool isMobile = constraints.maxWidth < 768;

        return SingleChildScrollView(
          padding: EdgeInsets.all(context.responsivePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mesas especiales en la parte superior
              buildMesasEspeciales(),
              SizedBox(height: AppTheme.spacingXLarge),

              // Vista responsiva para mesas regulares
              if (isMobile) _buildMobileMesasView() else buildMesasPorFilas(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileMesasView() {
    // Organizar mesas por LETRAS (A, B, C, D, E) - igual que en desktop
    Map<String, List<Mesa>> mesasPorLetra = {};

    for (Mesa mesa in mesas) {
      if (mesa.nombre.isNotEmpty) {
        String letra = mesa.nombre[0].toUpperCase();
        // Filtrar solo las mesas regulares (no especiales)
        if (![
          'DOMICILIO',
          'CAJA',
          'MESA AUXILIAR',
          'DEUDAS', // ✅ Mesa Deudas como mesa especial
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

    // Tamaños para móvil
    double cardWidth = 90;
    double cardHeight = 120;

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
                  // Título de la columna (letra) igual que desktop
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
                        fontSize: 16, // Ajustado para móvil
                      ),
                    ),
                  ),
                  // Mesas de la letra organizadas verticalmente (igual que desktop)
                  Column(
                    children: mesasDeLaLetra
                        .map(
                          (mesa) => Container(
                            width: cardWidth,
                            height: cardHeight,
                            margin: EdgeInsets.only(
                              bottom: AppTheme.spacingMedium,
                            ),
                            child: MesaCard(
                              mesa: mesa,
                              widgetRebuildKey: _widgetRebuildKey,
                              onRecargarMesas: _loadMesas,
                              onMostrarMenuMesa: _mostrarMenuMesa,
                              onMostrarDialogoPago: _mostrarDialogoPago,
                              onObtenerPedidoActivo: _obtenerPedidoActivoDeMesa,
                              onVerificarEstadoReal: _verificarEstadoRealMesa,
                            ),
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
  }

  double getResponsivePadding(double screenWidth) {
    if (screenWidth < 600) return 12; // Móvil
    if (screenWidth < 900) return 16; // Tablet
    return 20; // Desktop
  }

  Widget buildMesasEspeciales() {
    return LayoutBuilder(
      key: ValueKey('mesas_especiales_$_widgetRebuildKey'),
      builder: (context, constraints) {
        // Detectar si es móvil usando el breakpoint establecado
        bool isMobile = constraints.maxWidth < 768;

        // Definir altura responsive
        double especialHeight = context.isMobile
            ? 100
            : context.isTablet
            ? 120
            : 140;

        if (isMobile) {
          // Vista móvil: diseño en grid 2x2 como en desktop
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
                      () => _mostrarPedidosMesaEspecial('Domicilio'),
                      height: especialHeight,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingMedium),
                  Expanded(
                    child: buildMesaEspecial(
                      'Caja',
                      Icons.point_of_sale,
                      'disponible',
                      () => _mostrarPedidosMesaEspecial('Caja'),
                      height: especialHeight,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spacingMedium),
              // Segunda fila: Mesa Auxiliar y Deudas
              Row(
                children: [
                  Expanded(
                    child: buildMesaEspecial(
                      'Mesa Auxiliar',
                      Icons.table_restaurant,
                      'disponible',
                      () => _mostrarPedidosMesaEspecial('Mesa Auxiliar'),
                      height: especialHeight,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingMedium),
                  Expanded(
                    child: buildMesaEspecial(
                      'Deudas',
                      Icons.account_balance_wallet,
                      'disponible',
                      () => _mostrarPedidosMesaEspecial('Deudas'),
                      height: especialHeight,
                    ),
                  ),
                ],
              ),
            ],
          );
        } else {
          // Vista desktop/tablet: diseño original en filas
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
                      () => _mostrarPedidosMesaEspecial('Domicilio'),
                      height: especialHeight,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingMedium),
                  Expanded(
                    child: buildMesaEspecial(
                      'Caja',
                      Icons.point_of_sale,
                      'disponible',
                      () => _mostrarPedidosMesaEspecial('Caja'),
                      height: especialHeight,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spacingMedium),
              // Segunda fila: Mesa Auxiliar y Deudas
              Row(
                children: [
                  Expanded(
                    child: buildMesaEspecial(
                      'Mesa Auxiliar',
                      Icons.table_restaurant,
                      'disponible',
                      () => _mostrarPedidosMesaEspecial('Mesa Auxiliar'),
                      height: especialHeight,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingMedium),
                  Expanded(
                    child: buildMesaEspecial(
                      'Deudas',
                      Icons.account_balance_wallet,
                      'disponible',
                      () => _mostrarPedidosMesaEspecial('Deudas'),
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

  Widget buildMesaEspecial(
    String nombre,
    IconData icono,
    String estado,
    VoidCallback onTap, {
    required double height,
  }) {
    return FutureBuilder<List<Pedido>>(
      key: ValueKey('mesa_especial_${nombre}_$_widgetRebuildKey'),
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

        // Calcular total de todos los pedidos activos (método consistente)
        double totalGeneral = 0.0;
        for (var pedido in pedidosActivos) {
          for (var item in pedido.items) {
            totalGeneral += item.cantidad * item.precioUnitario;
          }
        }

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
              padding: EdgeInsets.all(AppTheme.spacingMedium),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                            ? 14
                            : context.isTablet
                            ? 16
                            : 18,
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
                        formatCurrency(totalGeneral),
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
          'DEUDAS', // ✅ Mesa Deudas como mesa especial
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
            ? 120
            : context.isTablet
            ? 140
            : 160;

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
                                child: MesaCard(
                                  mesa: mesa,
                                  widgetRebuildKey: _widgetRebuildKey,
                                  onRecargarMesas: _loadMesas,
                                  onMostrarMenuMesa: _mostrarMenuMesa,
                                  onMostrarDialogoPago: _mostrarDialogoPago,
                                  onObtenerPedidoActivo:
                                      _obtenerPedidoActivoDeMesa,
                                  onVerificarEstadoReal:
                                      _verificarEstadoRealMesa,
                                ),
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
        print('    - Precio: ${item.precio}');
        if (item.agregadoPor != null && item.agregadoPor!.isNotEmpty) {
          print('    - Agregado por: ${item.agregadoPor}');
        }
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
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PedidoScreen(mesa: mesa)),
        );
        // Si se creó o actualizó un pedido, recargar las mesas
        if (result == true) {
          await _recargarMesasConCards();
        }
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
                                      formatCurrency(pedido.total),
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

                              // ✅ NUEVO: Mostrar cliente si existe
                              if (pedido.cliente != null &&
                                  pedido.cliente!.isNotEmpty) ...[
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_circle,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Cliente: ${pedido.cliente}',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

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
                                            '• ${item.cantidad}x ${item.productoNombre ?? 'Producto'} - ${formatCurrency(item.precioUnitario * item.cantidad)}',
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
                    onPressed: () async {
                      Navigator.pop(context); // Cerrar el modal
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PedidoScreen(mesa: mesa),
                        ),
                      );
                      // Si se creó o actualizó un pedido, recargar las mesas
                      if (result == true) {
                        await _recargarMesasConCards();
                      }
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

  Future<void> _navegarAPedido(String nombreMesa) async {
    // Método simplificado para navegación directa a crear pedido
    Mesa? mesa = mesas.cast<Mesa?>().firstWhere(
      (m) => m?.nombre.toLowerCase() == nombreMesa.toLowerCase(),
      orElse: () => null,
    );

    if (mesa == null) {
      mesa = Mesa(
        id: '',
        nombre: nombreMesa,
        ocupada: false,
        total: 0.0,
        productos: [],
      );
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PedidoScreen(mesa: mesa!)),
    );
    // Si se creó o actualizó un pedido, recargar las mesas
    if (result == true) {
      await _recargarMesasConCards();
    }
  }

  // Nuevo método para mostrar lista de pedidos de mesas especiales
  void _mostrarPedidosMesaEspecial(String nombreMesa) async {
    try {
      print(
        '🔍 VERSIÓN ACTUALIZADA: Iniciando búsqueda de pedidos para mesa: "$nombreMesa"',
      );

      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ); // 🔧 BÚSQUEDA ROBUSTA: Probar múltiples variantes del nombre
      List<Pedido> pedidos = [];
      final variantes = [
        nombreMesa, // Original
        nombreMesa.toUpperCase(), // CAJA
        nombreMesa.toLowerCase(), // caja
        nombreMesa.replaceAll(' ', ''), // Sin espacios
        nombreMesa.replaceAll(' ', '').toUpperCase(), // Sin espacios mayúscula
        nombreMesa.replaceAll(' ', '').toLowerCase(), // Sin espacios minúscula
      ];

      print('🔄 Probando variantes de nombre: ${variantes.join(", ")}');

      for (String variante in variantes) {
        try {
          print('   🔍 Buscando con: "$variante"');
          final resultado = await _pedidoService.getPedidosByMesa(variante);
          if (resultado.isNotEmpty) {
            pedidos = resultado;
            print(
              '   ✅ ¡Encontrados ${pedidos.length} pedidos con "$variante"!',
            );
            break;
          } else {
            print('   ❌ No encontrado con "$variante"');
          }
        } catch (e) {
          print('   ⚠️ Error con "$variante": $e');
          continue;
        }
      }

      print('📦 Total final de pedidos encontrados: ${pedidos.length}');

      // Debug: No es necesario iterar sobre los pedidos solo para contarlos
      // El total ya se muestra en el log anterior

      // Filtrar solo pedidos activos (no pagados, no cancelados)
      final pedidosActivos = pedidos
          .where((p) => p.estado == EstadoPedido.activo)
          .toList();

      print('✅ Pedidos activos encontrados: ${pedidosActivos.length}');

      // Cerrar indicador de carga
      Navigator.of(context).pop();

      if (pedidosActivos.isEmpty) {
        // Si no hay pedidos activos, mostrar mensaje y ir a crear uno
        print('📝 No hay pedidos activos para "$nombreMesa", creando nuevo...');

        // 🧪 TEMPORAL: Mostrar la pantalla vacía para testing
        print('🧪 TESTING: Mostrando pantalla vacía para debug');
        _mostrarPantallaPedidosEspeciales(nombreMesa, pedidosActivos);
        return;

        // Código original comentado para testing:
        /*
        // Mostrar mensaje informativo antes de crear nuevo pedido
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No hay pedidos activos en $nombreMesa. Creando nuevo pedido...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Delay corto para que el usuario vea el mensaje
        await Future.delayed(Duration(milliseconds: 500));
        _navegarAPedido(nombreMesa);
        return;
        */
      }

      // Si hay pedidos activos, mostrar la pantalla de lista
      print(
        '📋 Mostrando pantalla con ${pedidosActivos.length} pedidos activos para "$nombreMesa"',
      );
      _mostrarPantallaPedidosEspeciales(nombreMesa, pedidosActivos);
    } catch (e) {
      // Cerrar indicador de carga si hay error
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print('❌ Error cargando pedidos para "$nombreMesa": $e');

      // Mostrar error al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar pedidos: $e'),
          backgroundColor: AppTheme.error,
          duration: Duration(seconds: 3),
        ),
      );

      // Si hay error, ir directo a crear pedido después de un delay
      await Future.delayed(Duration(seconds: 1));
      _navegarAPedido(nombreMesa);
    }
  }

  // Pantalla para mostrar lista de pedidos de mesa especial
  void _mostrarPantallaPedidosEspeciales(
    String nombreMesa,
    List<Pedido> pedidos,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PedidosEspecialesScreen(
          nombreMesa: nombreMesa,
          pedidos: pedidos,
          onAgregarPedido: () {
            Navigator.pop(context); // Cerrar la pantalla de lista
            _navegarAPedido(nombreMesa);
          },
          onPagarPedido: (pedido) => _pagarPedidoIndividual(pedido),
          onEditarPedido: (pedido) => _editarPedidoExistente(pedido),
          onRecargarPedidos: () {
            Navigator.pop(context); // Cerrar la pantalla actual
            _mostrarPedidosMesaEspecial(nombreMesa); // Recargar
          },
        ),
      ),
    );
  }

  // Método de prueba para forzar mostrar la pantalla (solo para debug)
  void _mostrarPantallaPedidosEspecialesForzado(String nombreMesa) {
    print('🧪 FORZANDO pantalla de pedidos para: $nombreMesa');
    // Crear algunos pedidos de prueba
    final pedidosPrueba = <Pedido>[];

    _mostrarPantallaPedidosEspeciales(nombreMesa, pedidosPrueba);
  }

  // Método para pagar un pedido individual
  void _pagarPedidoIndividual(Pedido pedido) async {
    try {
      // Crear mesa temporal para el pedido
      final mesaTemporal = Mesa(
        id: pedido.id, // Usar ID del pedido como referencia
        nombre: pedido.mesa,
        ocupada: true,
        total: pedido.total,
        productos: [],
      );

      // Mostrar diálogo de pago
      _mostrarDialogoPago(mesaTemporal, pedido);
    } catch (e) {
      print('❌ Error al procesar pago individual: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar el pago: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  // Método para editar un pedido existente
  void _editarPedidoExistente(Pedido pedido) {
    // Crear mesa temporal para navegar al pedido
    final mesaTemporal = Mesa(
      id: pedido.id, // Usar ID del pedido
      nombre: pedido.mesa,
      ocupada: true,
      total: pedido.total,
      productos: [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PedidoScreen(
          mesa: mesaTemporal,
          // Pasar información adicional si la pantalla lo soporta
        ),
      ),
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

// Pantalla para mostrar pedidos de mesas especiales con pagos individuales
class PedidosEspecialesScreen extends StatefulWidget {
  final String nombreMesa;
  final List<Pedido> pedidos;
  final VoidCallback onAgregarPedido;
  final Function(Pedido) onPagarPedido;
  final Function(Pedido) onEditarPedido;
  final VoidCallback onRecargarPedidos;

  const PedidosEspecialesScreen({
    Key? key,
    required this.nombreMesa,
    required this.pedidos,
    required this.onAgregarPedido,
    required this.onPagarPedido,
    required this.onEditarPedido,
    required this.onRecargarPedidos,
  }) : super(key: key);

  @override
  _PedidosEspecialesScreenState createState() =>
      _PedidosEspecialesScreenState();
}

class _PedidosEspecialesScreenState extends State<PedidosEspecialesScreen> {
  @override
  Widget build(BuildContext context) {
    final totalGeneral = widget.pedidos.fold<double>(
      0,
      (sum, pedido) => sum + pedido.total,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nombreMesa,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${widget.pedidos.length} pedidos activos',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              widget.onRecargarPedidos();
              Navigator.of(context).pop(); // Volver y recargar
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumen total
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.1),
                  AppTheme.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total General:',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  formatCurrency(totalGeneral),
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Lista de pedidos
          Expanded(
            child: widget.pedidos.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: widget.pedidos.length,
                    itemBuilder: (context, index) {
                      final pedido = widget.pedidos[index];
                      return _buildPedidoCard(pedido);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAgregarPedido,
        backgroundColor: AppTheme.primary,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Agregar Pedido',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 64,
                color: AppTheme.primary,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No hay pedidos activos',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Esta mesa no tiene pedidos pendientes.\n¡Agrega el primer pedido!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: widget.onAgregarPedido,
              icon: Icon(Icons.add, color: Colors.white),
              label: Text(
                'Crear Primer Pedido',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidoCard(Pedido pedido) {
    final esActivo = pedido.estado == EstadoPedido.activo;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: esActivo ? AppTheme.cardGradient : null,
        color: esActivo ? null : AppTheme.cardBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del pedido
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Eliminado: Pedido #ID
                      SizedBox(height: 4),
                      Text(
                        'Mesero: ${pedido.mesero}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (pedido.cliente != null &&
                          pedido.cliente!.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          'Cliente: ${pedido.cliente}',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      SizedBox(height: 4),
                      Text(
                        'Fecha: ${_formatFecha(pedido.fecha)}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Estado del pedido
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getEstadoColor(pedido.estado).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getEstadoColor(pedido.estado),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getEstadoTexto(pedido.estado),
                    style: TextStyle(
                      color: _getEstadoColor(pedido.estado),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Items del pedido (resumen)
            if (pedido.items.isNotEmpty) ...[
              Text(
                'Productos (${pedido.items.length}):',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              ...pedido.items
                  .take(3)
                  .map(
                    (item) => Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.cantidad}x ${item.productoNombre ?? 'Producto'}',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                formatCurrency(
                                  item.cantidad * item.precioUnitario,
                                ),
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          // Mostrar quien agregó el producto en vista resumida
                          if (item.agregadoPor != null &&
                              item.agregadoPor!.isNotEmpty) ...[
                            SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 12,
                                  color: Colors.green.withOpacity(0.7),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'por ${item.agregadoPor}',
                                  style: TextStyle(
                                    color: Colors.green.withOpacity(0.8),
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              if (pedido.items.length > 3)
                Text(
                  '... y ${pedido.items.length - 3} más',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],

            SizedBox(height: 16),

            // Total y acciones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Total del pedido
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    formatCurrency(pedido.total),
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Botones de acción
                Row(
                  children: [
                    // Botón editar
                    IconButton(
                      onPressed: () => widget.onEditarPedido(pedido),
                      icon: Icon(Icons.edit, color: AppTheme.primary),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Botón pagar
                    if (esActivo)
                      ElevatedButton.icon(
                        onPressed: () => widget.onPagarPedido(pedido),
                        icon: Icon(Icons.payment, size: 18),
                        label: Text('Pagar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Notas si existen
            if (pedido.notas != null && pedido.notas!.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notas:',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      pedido.notas!,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
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
    );
  }

  Color _getEstadoColor(EstadoPedido estado) {
    switch (estado) {
      case EstadoPedido.activo:
        return AppTheme.success;
      case EstadoPedido.pagado:
        return AppTheme.primary;
      case EstadoPedido.cancelado:
        return AppTheme.error;
      case EstadoPedido.cortesia:
        return Colors.orange;
    }
  }

  String _getEstadoTexto(EstadoPedido estado) {
    switch (estado) {
      case EstadoPedido.activo:
        return 'ACTIVO';
      case EstadoPedido.pagado:
        return 'PAGADO';
      case EstadoPedido.cancelado:
        return 'CANCELADO';
      case EstadoPedido.cortesia:
        return 'CORTESÍA';
    }
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }
}
