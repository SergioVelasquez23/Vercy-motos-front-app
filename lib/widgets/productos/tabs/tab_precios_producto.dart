import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class TabPreciosProducto extends StatelessWidget {
  final TextEditingController precioController;
  final TextEditingController costoController;
  final TextEditingController porcentajeImpuestoController;
  final TextEditingController precioVentaOpc1Controller;
  final TextEditingController precioVentaOpc2Controller;
  final TextEditingController precioVentaOpc3Controller;

  const TabPreciosProducto({
    super.key,
    required this.precioController,
    required this.costoController,
    required this.porcentajeImpuestoController,
    required this.precioVentaOpc1Controller,
    required this.precioVentaOpc2Controller,
    required this.precioVentaOpc3Controller,
  });

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Colors.black87),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
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
            Text('Precios Principales', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Costo *', costoController, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Precio *', precioController, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('% Impuesto', porcentajeImpuestoController, isNumeric: true)),
              ],
            ),
            SizedBox(height: 24),

            Text('Precios Opcionales', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Precio Opc. 1', precioVentaOpc1Controller, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Precio Opc. 2', precioVentaOpc2Controller, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Precio Opc. 3', precioVentaOpc3Controller, isNumeric: true)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
