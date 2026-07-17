import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Selector de tipo de documento (LOCAL / Documento POS / Factura
/// Electrónica) de facturacion_screen.dart. Copiado tal cual: mismas 3
/// opciones, mismos textos de ayuda.
class TipoFacturaDropdown extends StatelessWidget {
  final String tipoFactura;
  final ValueChanged<String> onChanged;

  const TipoFacturaDropdown({
    super.key,
    required this.tipoFactura,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: tipoFactura,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          items: const [
            DropdownMenuItem(
              value: 'LOCAL',
              child: Text(''),
            ),
            DropdownMenuItem(
              value: 'POS',
              child: Text('Documento POS'),
            ),
            DropdownMenuItem(
              value: 'FACTURA',
              child: Text('Factura Electrónica'),
            ),
          ],
          selectedItemBuilder: (context) => const [
            SizedBox.shrink(),
            Text('Documento POS'),
            Text('Factura Electrónica'),
          ],
          onChanged: (value) => onChanged(value!),
        ),
        const SizedBox(height: 4),
        if (tipoFactura == 'FACTURA')
          Text(
            'Se enviará a la DIAN como Factura Electrónica',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
        if (tipoFactura == 'POS')
          Text(
            'Se puede enviar a la DIAN como documento POS',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}
