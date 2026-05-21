import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/matias_service.dart';
import '../../services/documento_service.dart';
import '../../services/negocio_info_service.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/pedido.dart';

import 'confirmacion_dian_dialog.dart';

/// Botón "POS Rápido" — emite un documento POS electrónico SIN datos del cliente.
///
/// Ideal para ventas de mostrador donde el cliente no proporciona datos.
/// Llama directamente a `MatiasService.emitirDocumentoPOS()` construyendo
/// el payload SIN campo `customer`.
///
/// Uso:
/// ```dart
/// PosRapidoButton(
///   pedido: pedido,
///   onSuccess: () => _cargarDatos(),
/// );
/// ```
class PosRapidoButton extends StatefulWidget {
  final Pedido pedido;
  final VoidCallback? onSuccess;
  final Function(String)? onError;

  const PosRapidoButton({
    Key? key,
    required this.pedido,
    this.onSuccess,
    this.onError,
  }) : super(key: key);

  @override
  State<PosRapidoButton> createState() => _PosRapidoButtonState();
}

class _PosRapidoButtonState extends State<PosRapidoButton> {
  bool _loading = false;

  Future<void> _emitirPOS() async {
    setState(() => _loading = true);
    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;

      // Cargar información del negocio para obtener la resolución
      final negocioInfoService = NegocioInfoService();
      final negocioInfo = await negocioInfoService.getNegocioInfo();

      // Validar que tenemos la información necesaria
      if (negocioInfo?.resolutionNumber == null ||
          negocioInfo!.resolutionNumber!.isEmpty) {
        throw Exception('⚠️ Número de resolución no configurado. Por favor, verifique la configuración del negocio.');
      }

      // Construir documento POS COMPLETO con todos los campos requeridos
      final payloadCompleto = MatiasService.buildCompletePOSDocument(
        pedido: widget.pedido,
        negocioInfo: negocioInfo,
        resolutionNumber: negocioInfo.resolutionNumber!,
        type_document_id: 11,
      );

      final resultado = await MatiasService.emitirDocumentoPOS(
        payloadCompleto,
        token: token,
      );

      if (!mounted) return;

      if (resultado.success) {
        // Convertir MatiasDocumentoResult → FacturacionResult para el dialog
        final facturacionResult = FacturacionResult(
          success: true,
          message: resultado.message,
          cufe: resultado.documentKey,
          pdfUrl: resultado.pdfUrl,
          raw: resultado.raw,
        );

        showDialog(
          context: context,
          builder: (_) => ConfirmacionDianDialog(
            resultado: facturacionResult,
            tipoDocumento: 'POS Electrónico',
            onClose: widget.onSuccess,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${resultado.message}'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
        widget.onError?.call(resultado.message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e'), backgroundColor: AppTheme.error),
        );
        widget.onError?.call(e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : _emitirPOS,
      icon: _loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  Colors.white.withOpacity(0.7),
                ),
              ),
            )
          : const Icon(Icons.flash_on_rounded, size: 18, color: Colors.white),
      label: Text(
        _loading ? 'Enviando...' : 'POS Rápido',
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
