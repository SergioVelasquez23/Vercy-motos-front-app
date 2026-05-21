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

  Widget _buildTextField(BuildContext context, String label, TextEditingController controller, {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
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

  Widget _buildDropdown(BuildContext context, String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    // Defensa: si el valor no está en items (ej. backend devuelve "true"/"false"
    // en vez de "SI"/"NO"), usar el primero como fallback para no romper el
    // assert del DropdownButton.
    final safeValue = items.contains(value)
        ? value
        : (items.isNotEmpty ? items.first : null);
    return DropdownButtonFormField<String>(
      value: safeValue,
      dropdownColor: Theme.of(context).colorScheme.surface,
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
                    context,
                    'Control Inventario',
                    controlInventarioSeleccionado,
                    ['SI', 'NO'],
                    (value) => setState(() => controlInventarioSeleccionadoList[0] = value ?? 'SI'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(child: _buildTextField(context, 'Inv. Bajo', inventarioBajoController, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField(context, 'Inv. Óptimo', inventarioOptimoController, isNumeric: true)),
              ],
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildTextField(context, 'Almacén', almacenController, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField(context, 'Bodega', bodegaController, isNumeric: true)),
              ],
            ),
            SizedBox(height: 24),

            Text('Ubicaciones', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(context, 'Ubicación 1', ubicacion1Controller)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField(context, 'Ubicación 2', ubicacion2Controller)),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(context, 'Ubicación 3', ubicacion3Controller)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField(context, 'Ubicación 4', ubicacion4Controller)),
              ],
            ),
            SizedBox(height: 16),
            _buildTextField(context, 'Localización', localizacionController),
          ],
        ),
      ),
    );
  }
}
