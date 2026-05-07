import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class TabInventarioProducto extends StatelessWidget {
  final TextEditingController almacenController;
  final TextEditingController bodegaController;
  final TextEditingController inventarioBajoController;
  final TextEditingController inventarioOptimoController;
  final TextEditingController ubicacion1Controller;
  final TextEditingController ubicacion2Controller;
  final TextEditingController ubicacion3Controller;
  final TextEditingController ubicacion4Controller;
  final TextEditingController localizacionController;
  final String controlInventarioSeleccionado;
  final StateSetter setState;
  final List<String> controlInventarioSeleccionadoList;

  const TabInventarioProducto({
    super.key,
    required this.almacenController,
    required this.bodegaController,
    required this.inventarioBajoController,
    required this.inventarioOptimoController,
    required this.ubicacion1Controller,
    required this.ubicacion2Controller,
    required this.ubicacion3Controller,
    required this.ubicacion4Controller,
    required this.localizacionController,
    required this.controlInventarioSeleccionado,
    required this.setState,
    required this.controlInventarioSeleccionadoList,
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

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AppTheme.cardBg,
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
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
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
            Text('Control de Inventario', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    'Control Inventario',
                    controlInventarioSeleccionado,
                    ['SI', 'NO'],
                    (value) => setState(() => controlInventarioSeleccionadoList[0] = value ?? 'SI'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Inv. Bajo', inventarioBajoController, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Inv. Óptimo', inventarioOptimoController, isNumeric: true)),
              ],
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildTextField('Almacén', almacenController, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Bodega', bodegaController, isNumeric: true)),
              ],
            ),
            SizedBox(height: 24),

            Text('Ubicaciones', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Ubicación 1', ubicacion1Controller)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Ubicación 2', ubicacion2Controller)),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Ubicación 3', ubicacion3Controller)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Ubicación 4', ubicacion4Controller)),
              ],
            ),
            SizedBox(height: 16),
            _buildTextField('Localización', localizacionController),
          ],
        ),
      ),
    );
  }
}
