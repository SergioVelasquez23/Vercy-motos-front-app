import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class TabClasificacionProducto extends StatelessWidget {
  final TextEditingController marcaController;
  final TextEditingController tipoProductoNombreController;
  final TextEditingController lineaProductoNombreController;
  final TextEditingController claseProductoNombreController;
  final TextEditingController nombreProveedorController;
  final TextEditingController nitProveedorController;

  const TabClasificacionProducto({
    super.key,
    required this.marcaController,
    required this.tipoProductoNombreController,
    required this.lineaProductoNombreController,
    required this.claseProductoNombreController,
    required this.nombreProveedorController,
    required this.nitProveedorController,
  });

  Widget _buildTextField(BuildContext context, String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clasificación', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            _buildTextField(context, 'Marca', marcaController),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildTextField(context, 'Tipo Producto', tipoProductoNombreController)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField(context, 'Línea Producto', lineaProductoNombreController)),
              ],
            ),
            SizedBox(height: 16),
            _buildTextField(context, 'Clase Producto', claseProductoNombreController),
            SizedBox(height: 24),

            Text('Proveedor', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(context, 'Nombre Proveedor', nombreProveedorController)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField(context, 'NIT Proveedor', nitProveedorController)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
