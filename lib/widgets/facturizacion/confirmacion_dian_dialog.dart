import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/documento_service.dart';

/// Dialog que muestra el resultado de una facturación electrónica exitosa:
///   - CUFE / CUDE
///   - QR Code (imagen o texto)
///   - Número electrónico
///   - Botón para copiar CUFE
///   - Link al PDF si disponible
///
/// Uso:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => ConfirmacionDianDialog(resultado: resultado),
/// );
/// ```
class ConfirmacionDianDialog extends StatelessWidget {
  final FacturacionResult resultado;
  final String? tipoDocumento; // 'Factura', 'Nota Crédito', etc.
  final VoidCallback? onClose;

  const ConfirmacionDianDialog({
    Key? key,
    required this.resultado,
    this.tipoDocumento,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tipo = tipoDocumento ?? 'Documento';

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Ícono de éxito ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.success,
                  size: 52,
                ),
              ),
              const SizedBox(height: 16),

              // ── Título ──
              Text(
                '✅ $tipo enviado a DIAN',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'La DIAN ha aceptado el documento',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // ── CUFE ──
              if (resultado.cufe != null && resultado.cufe!.isNotEmpty) ...[
                _InfoRow(
                  label: 'CUFE',
                  value: resultado.cufe!,
                  copiable: true,
                ),
                const SizedBox(height: 12),
              ],

              // ── Número electrónico ──
              if (resultado.numeroElectronico != null &&
                  resultado.numeroElectronico!.isNotEmpty) ...[
                _InfoRow(
                  label: 'N° Electrónico',
                  value: resultado.numeroElectronico!,
                  copiable: true,
                ),
                const SizedBox(height: 12),
              ],

              // ── QR Code ──
              if (resultado.qrCode != null &&
                  resultado.qrCode!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Código QR',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Si el QR es una URL de imagen, mostrarla
                      if (_esUrlImagen(resultado.qrCode!))
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            resultado.qrCode!,
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _QrTexto(
                              texto: resultado.qrCode!,
                            ),
                          ),
                        )
                      else if (resultado.qrUrl != null &&
                          _esUrlImagen(resultado.qrUrl!))
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            resultado.qrUrl!,
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _QrTexto(
                              texto: resultado.qrCode!,
                            ),
                          ),
                        )
                      else
                        _QrTexto(texto: resultado.qrCode!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── PDF link ──
              if (resultado.pdfUrl != null &&
                  resultado.pdfUrl!.isNotEmpty) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: resultado.pdfUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('URL del PDF copiada'),
                      duration: Duration(seconds: 2),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.picture_as_pdf,
                            color: Colors.red.shade400, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Ver PDF del documento',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.copy, color: Colors.blue.shade400, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 8),

              // ── Botón cerrar ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onClose?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Aceptar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _esUrlImagen(String s) {
    final lower = s.toLowerCase();
    return lower.startsWith('http') &&
        (lower.contains('.png') ||
            lower.contains('.jpg') ||
            lower.contains('.jpeg') ||
            lower.contains('.svg') ||
            lower.contains('qr'));
  }
}

// ── Info row copiable ────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copiable;

  const _InfoRow({
    required this.label,
    required this.value,
    this.copiable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value.length > 40 ? '${value.substring(0, 40)}...' : value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (copiable)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$label copiado al portapapeles'),
                  backgroundColor: AppTheme.success,
                  duration: const Duration(seconds: 2),
                ));
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.copy_rounded,
                    size: 16, color: AppTheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}

// ── QR como texto (fallback) ─────────────────────────────────────────────────

class _QrTexto extends StatelessWidget {
  final String texto;
  const _QrTexto({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        texto,
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'monospace',
          color: Theme.of(context).colorScheme.onSurface,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
