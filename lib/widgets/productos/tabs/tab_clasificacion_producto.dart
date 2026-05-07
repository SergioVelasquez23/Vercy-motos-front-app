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

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.black54),
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
            _buildTextField('Marca', marcaController),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildTextField('Tipo Producto', tipoProductoNombreController)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Línea Producto', lineaProductoNombreController)),
              ],
            ),
            SizedBox(height: 16),
            _buildTextField('Clase Producto', claseProductoNombreController),
            SizedBox(height: 24),

            Text('Proveedor', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Nombre Proveedor', nombreProveedorController)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('NIT Proveedor', nitProveedorController)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
