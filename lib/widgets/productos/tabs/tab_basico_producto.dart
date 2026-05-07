import 'package:flutter/material.dart';
import '../../../models/categoria.dart';
import '../../../theme/app_theme.dart';

class TabBasicoProducto extends StatelessWidget {
  final TextEditingController nombreController;
  final TextEditingController descripcionController;
  final TextEditingController codigoController;
  final TextEditingController codigoBarrasController;
  final String tipoSeleccionado;
  final String? categoriaSeleccionada;
  final StateSetter setState;
  final List<String> tipoSeleccionadoList;
  final List<Categoria> categorias;
  final ValueChanged<String?>? onCategoriaChanged;

  const TabBasicoProducto({
    super.key,
    required this.nombreController,
    required this.descripcionController,
    required this.codigoController,
    required this.codigoBarrasController,
    required this.tipoSeleccionado,
    required this.categoriaSeleccionada,
    required this.setState,
    required this.tipoSeleccionadoList,
    required this.categorias,
    this.onCategoriaChanged,
  });

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, bool isNumeric = false}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Colors.black87),
      maxLines: maxLines,
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

  Widget _buildCategoriaDropdown(String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AppTheme.cardBg,
      style: TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: 'Categoría',
        labelStyle: TextStyle(color: Colors.black54),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary),
        ),
      ),
      items: [
        DropdownMenuItem<String>(value: null, child: Text('Sin categoría')),
        ...categorias.map((categoria) {
          return DropdownMenuItem<String>(
            value: categoria.id,
            child: Text(categoria.nombre),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                // Tipo de producto
                Expanded(
                  child: _buildDropdown(
                    'Tipo *',
                    tipoSeleccionado,
                    ['PRODUCTO', 'SERVICIO'],
                    (value) {
                      setState(() {
                        tipoSeleccionadoList[0] = value ?? 'PRODUCTO';
                      });
                    },
                  ),
                ),
                SizedBox(width: 16),
                // Código
                Expanded(
                  child: _buildTextField('Código', codigoController),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Código de barras
            _buildTextField('Código de barras', codigoBarrasController),
            SizedBox(height: 16),

            // Nombre (ancho completo)
            _buildTextField('Nombre *', nombreController),
            SizedBox(height: 16),

            // Descripción (ancho completo, multilinea)
            _buildTextField('Descripción', descripcionController, maxLines: 4),
            SizedBox(height: 16),

            // Categoría
            _buildCategoriaDropdown(categoriaSeleccionada, (value) {
              setState(() {});
              onCategoriaChanged?.call(value);
            }),
          ],
        ),
      ),
    );
  }
}
