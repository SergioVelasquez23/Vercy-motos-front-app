import 'package:flutter/material.dart';
import 'retencion_field.dart';

/// Descripción de la compra y los 3 campos de retención lado a lado, usado
/// en crear_factura_compra_screen.dart (antes
/// _buildDescripcionYRetencionesCompacto). Copiado tal cual, sin cambios de
/// lógica.
class DescripcionYRetencionesCompacto extends StatelessWidget {
  final TextEditingController descripcionController;
  final TextEditingController porcentajeRetencionController;
  final TextEditingController porcentajeReteIvaController;
  final TextEditingController porcentajeReteIcaController;
  final VoidCallback onRetencionChanged;

  const DescripcionYRetencionesCompacto({
    super.key,
    required this.descripcionController,
    required this.porcentajeRetencionController,
    required this.porcentajeReteIvaController,
    required this.porcentajeReteIcaController,
    required this.onRetencionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Descripción
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Descripción',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descripcionController,
                maxLines: 4,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Descripción de la compra...',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Retenciones
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RetencionField(
                label: 'Retención',
                controller: porcentajeRetencionController,
                onChanged: onRetencionChanged,
              ),
              const SizedBox(height: 8),
              RetencionField(
                label: 'Reteiva',
                controller: porcentajeReteIvaController,
                onChanged: onRetencionChanged,
              ),
              const SizedBox(height: 8),
              RetencionField(
                label: 'Reteica',
                controller: porcentajeReteIcaController,
                onChanged: onRetencionChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}