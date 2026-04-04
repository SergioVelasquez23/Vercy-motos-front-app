import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/factura.dart';
import '../../models/pedido.dart';
import '../../providers/user_provider.dart';
import '../../services/matias_service.dart';
import '../../services/documento_service.dart';
import '../../services/negocio_info_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/matias_mapper.dart';
import 'nota_credito_debito_dialog.dart';
import 'documento_soporte_dialog.dart';
import 'confirmacion_dian_dialog.dart';

/// Menú de acciones de facturación electrónica para una fila de documento.
///
/// Muestra un botón "FE ▾" que al presionarlo despliega las opciones
/// disponibles según el tipo y estado del documento.
///
/// Para facturas ya emitidas electrónicamente:
///   - Nota Crédito
///   - Nota Débito
///   - Reenviar (si fue rechazada)
///
/// Para pedidos POS pagados:
///   - Facturar (POS electrónico)
///   - Facturar con Nota Crédito (si ya fue facturado)
class FacturacionElectronicaMenu extends StatefulWidget {
  final dynamic documento; // Factura | Pedido
  final VoidCallback? onRefresh;

  const FacturacionElectronicaMenu({
    Key? key,
    required this.documento,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<FacturacionElectronicaMenu> createState() =>
      _FacturacionElectronicaMenuState();
}

class _FacturacionElectronicaMenuState
    extends State<FacturacionElectronicaMenu> {
  bool _loading = false;

  bool get _esFactura => widget.documento is Factura;
  bool get _esPedido => widget.documento is Pedido;

  Factura? get _factura => _esFactura ? widget.documento as Factura : null;
  Pedido? get _pedido => _esPedido ? widget.documento as Pedido : null;

  /// Si la factura tiene CUFE → ya fue emitida electrónicamente
  bool get _tieneEmisionElectronica =>
      _factura?.cufe != null && _factura!.cufe!.isNotEmpty;

  // ──────────────────────────────────────────────────────────────────────────
  //  Acciones
  // ──────────────────────────────────────────────────────────────────────────

  void _abrirNotaCredito() {
    if (_factura == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NotaCreditoDebitoDialog(
        factura: _factura!,
        tipo: TipoNota.credito,
        onSuccess: widget.onRefresh,
      ),
    );
  }

  void _abrirNotaDebito() {
    if (_factura == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NotaCreditoDebitoDialog(
        factura: _factura!,
        tipo: TipoNota.debito,
        onSuccess: widget.onRefresh,
      ),
    );
  }

  Future<void> _facturarElectronicaNormal() async {
    if (_pedido == null) return;
    setState(() => _loading = true);
    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;
      final payload = MatiasMapper.toMatiasPayload(_pedido!);
      // Forzar que sea FE (1 o 11 dependiendo de la API backend de Matias, o simplemente usar auto-increment)
      final resultado = await MatiasService.emitirFacturaElectronica(
        payload,
        token: token,
      );
      if (!mounted) return;
      if (resultado.success) {
        final facturacionResult = FacturacionResult(
          success: true,
          message: 'Factura Electrónica emitida exitosamente',
          cufe: resultado.documentKey,
          pdfUrl: resultado.pdfUrl,
          raw: resultado.raw,
        );
        showDialog(
          context: context,
          builder: (_) => ConfirmacionDianDialog(
            resultado: facturacionResult,
            tipoDocumento: 'Factura Electrónica',
            onClose: widget.onRefresh,
          ),
        );
      } else {
        _snack('❌ ${resultado.message}', AppTheme.error);
      }
    } catch (e) {
      _snack('❌ Error al emitir FE: $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _facturarPOS() async {
    if (_pedido == null) return;
    setState(() => _loading = true);
    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;

      // Cargar información del negocio para obtener la resolución
      final negocioInfoService = NegocioInfoService();
      final negocioInfo = await negocioInfoService.getNegocioInfo();

      // Agregar resolución a los datosAdicionales del pedido si existe
      final pedido = _pedido!;
      if (negocioInfo?.resolutionNumber != null &&
          negocioInfo!.resolutionNumber!.isNotEmpty) {
        pedido.datosAdicionales ??= {};
        pedido.datosAdicionales!['resolutionNumber'] =
            negocioInfo.resolutionNumber;
      }

      final payload = MatiasMapper.toMatiasPayload(pedido);
      final resultado = await MatiasService.emitirDocumentoPOS(
        payload,
        token: token,
      );
      if (!mounted) return;
      if (resultado.success) {
        // Mostrar dialog de confirmación con QR + CUFE
        final facturacionResult = FacturacionResult(
          success: true,
          message: 'POS facturado exitosamente',
          cufe: resultado.documentKey,
          pdfUrl: resultado.pdfUrl,
          raw: resultado.raw,
        );
        showDialog(
          context: context,
          builder: (_) => ConfirmacionDianDialog(
            resultado: facturacionResult,
            tipoDocumento: 'POS Electrónico',
            onClose: widget.onRefresh,
          ),
        );
      } else {
        _snack('❌ ${resultado.message}', AppTheme.error);
      }
    } catch (e) {
      _snack('❌ Error al emitir POS: $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _facturarPOSRapido() async {
    if (_pedido == null) return;
    setState(() => _loading = true);
    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;

      // Cargar información del negocio para obtener la resolución
      final negocioInfoService = NegocioInfoService();
      final negocioInfo = await negocioInfoService.getNegocioInfo();

      // Agregar resolución a los datosAdicionales del pedido si existe
      final pedido = _pedido!;
      if (negocioInfo?.resolutionNumber != null &&
          negocioInfo!.resolutionNumber!.isNotEmpty) {
        pedido.datosAdicionales ??= {};
        pedido.datosAdicionales!['resolutionNumber'] =
            negocioInfo.resolutionNumber;
      }

      final payload = MatiasMapper.toMatiasPayload(pedido);

      // Enviar cliente como Consumidor Final explícito para no causar error 500
      payload['customer'] = {
        "country_id": "45",
        "city_id": "836",
        "identity_document_id": "3", // cédula o consumidor final
        "type_organization_id": 2, // 2 = Persona Natural
        "tax_regime_id": 2,
        "tax_level_id": 2,
        "company_name": "CONSUMIDOR FINAL",
        "dni": "222222222222",
        "mobile": "0000000000",
        "email": "factura@example.com",
        "address": "Sin Direccion",
        "postal_code": "000000",
      };
      payload['send_email'] = 0;
      payload['type_document_id'] = 20; // 20 = POS en Matias u 11 si fuera FE

      final resultado = await MatiasService.emitirDocumentoPOS(
        payload,
        token: token,
      );
      if (!mounted) return;
      if (resultado.success) {
        final facturacionResult = FacturacionResult(
          success: true,
          message: 'POS rápido emitido',
          cufe: resultado.documentKey,
          pdfUrl: resultado.pdfUrl,
          raw: resultado.raw,
        );
        showDialog(
          context: context,
          builder: (_) => ConfirmacionDianDialog(
            resultado: facturacionResult,
            tipoDocumento: 'POS Rápido',
            onClose: widget.onRefresh,
          ),
        );
      } else {
        _snack('❌ ${resultado.message}', AppTheme.error);
      }
    } catch (e) {
      _snack('❌ $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reenviarDocumento() async {
    // Para facturas rechazadas — intenta reenviar como auto-increment invoice
    if (_factura == null) return;
    final uuid = _factura!.uuid ?? _factura!.id;
    if (uuid == null) {
      _snack('UUID no disponible', AppTheme.warning);
      return;
    }

    setState(() => _loading = true);
    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;
      final resultado = await MatiasService.reenviarDocumentoAutoIncrement(
        'invoices',
        uuid,
        token: token,
      );
      if (!mounted) return;
      if (resultado.success) {
        _snack('✅ Documento reenviado correctamente', AppTheme.success);
        widget.onRefresh?.call();
      } else {
        _snack('❌ ${resultado.message}', AppTheme.error);
      }
    } catch (e) {
      _snack('❌ $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // ── Pedido POS ──
    if (_esPedido) {
      return _BotonFE(
        label: 'Facturar',
        color: AppTheme.primary,
        icon: Icons.receipt_long,
        items: [
          _MenuItem(
            icon: Icons.receipt,
            label: 'Emitir Factura Electrónica',
            color: AppTheme.success,
            onTap: _facturarElectronicaNormal,
          ),
          _MenuItem(
            icon: Icons.point_of_sale,
            label: 'Emitir POS Electrónico',
            color: AppTheme.primary,
            onTap: _facturarPOS,
          ),
          _MenuItem(
            icon: Icons.flash_on_rounded,
            label: 'POS Rápido (sin cliente)',
            color: Colors.teal,
            onTap: _facturarPOSRapido,
          ),
        ],
      );
    }

    // ── Factura electrónica ──
    if (_esFactura) {
      return _BotonFE(
        label: 'FE',
        color: AppTheme.secondary,
        icon: Icons.more_horiz,
        items: [
          if (_tieneEmisionElectronica) ...[
            _MenuItem(
              icon: Icons.remove_circle_outline,
              label: 'Nota Crédito',
              color: Colors.orange,
              onTap: _abrirNotaCredito,
            ),
            _MenuItem(
              icon: Icons.add_circle_outline,
              label: 'Nota Débito',
              color: Colors.blue.shade600,
              onTap: _abrirNotaDebito,
            ),
          ],
          if (_factura?.estadoDIAN == 'RECHAZADA')
            _MenuItem(
              icon: Icons.refresh,
              label: 'Reenviar a DIAN',
              color: AppTheme.warning,
              onTap: _reenviarDocumento,
            ),
          if (!_tieneEmisionElectronica)
            _MenuItem(
              icon: Icons.send,
              label: 'Emitir Factura Electrónica',
              color: AppTheme.success,
              onTap: () => _snack(
                'Usa el botón Facturar desde la pantalla de Pedidos',
                AppTheme.info,
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Widget auxiliar: botón con popup ──────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _BotonFE extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final List<_MenuItem> items;

  const _BotonFE({
    required this.label,
    required this.color,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<int>(
      tooltip: 'Opciones de Facturación Electrónica',
      color: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      offset: const Offset(0, 36),
      onSelected: (i) => items[i].onTap(),
      itemBuilder: (_) => items.asMap().entries.map((e) {
        final item = e.value;
        return PopupMenuItem<int>(
          value: e.key,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(item.icon, color: item.color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                item.label,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
