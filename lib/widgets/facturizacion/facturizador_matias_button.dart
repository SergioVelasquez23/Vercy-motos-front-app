import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/matias_service.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';

/// Widget botón para facturar un Pedido en Matias
class FacturizarMatiasButton extends StatefulWidget {
  final String pedidoId;
  final VoidCallback? onSuccess;
  final Function(String)? onError;

  const FacturizarMatiasButton({
    Key? key,
    required this.pedidoId,
    this.onSuccess,
    this.onError,
  }) : super(key: key);

  @override
  State<FacturizarMatiasButton> createState() => _FacturizarMatiasButtonState();
}

class _FacturizarMatiasButtonState extends State<FacturizarMatiasButton> {
  bool isLoading = false;

  Future<void> _facturar() async {
    setState(() => isLoading = true);

    try {
      // Obtener token del UserProvider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;

      final resultado = await MatiasService.facturarPedido(
        widget.pedidoId,
        token: token,
      );

      if (!mounted) return;

      if (resultado != null) {
        final cufe = resultado['xmlDocumentKey'] ?? 'N/A';
        _mostrarSnackbar(
          '✅ Facturado exitosamente. CUFE: $cufe',
          AppTheme.success,
        );
        widget.onSuccess?.call();
      } else {
        _mostrarSnackbar(
          '❌ Error al facturar. Intenta nuevamente.',
          Colors.red,
        );
        widget.onError?.call('Error al facturar');
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackbar('❌ Error: ${e.toString()}', Colors.red);
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _mostrarSnackbar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : _facturar,
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.grey.shade700),
              ),
            )
          : const Icon(Icons.receipt_long),
      label: Text(isLoading ? 'Facturando...' : 'Facturar en Matias'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
