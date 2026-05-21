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

  Widget _buildTextField(BuildContext context, String label, TextEditingController controller, {int maxLines = 1, bool isNumeric = false}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      maxLines: maxLines,
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
    // Si el valor recibido no está en items (vacío, casing distinto, etc.) se
    // usa el primero como fallback para evitar el assert de Dropdown.
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

  Widget _buildCategoriaDropdown(BuildContext context, String? value, ValueChanged<String?> onChanged) {
    // Si la categoría apunta a un ID que ya no existe en la lista cargada,
    // tratarla como "Sin categoría" para no romper el dropdown.
    final categoriaIds = categorias.map((c) => c.id).toSet();
    final safeValue = (value != null && categoriaIds.contains(value)) ? value : null;
    return DropdownButtonFormField<String>(
      value: safeValue,
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: 'Categoría',
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
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
                    context,
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
                  child: _buildTextField(context, 'Código', codigoController),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Código de barras
            _buildTextField(context, 'Código de barras', codigoBarrasController),
            SizedBox(height: 16),

            // Nombre (ancho completo)
            _buildTextField(context, 'Nombre *', nombreController),
            SizedBox(height: 16),

            // Descripción (ancho completo, multilinea)
            _buildTextField(context, 'Descripción', descripcionController, maxLines: 4),
            SizedBox(height: 16),

            // Categoría
            _buildCategoriaDropdown(context, categoriaSeleccionada, (value) {
              setState(() {});
              onCategoriaChanged?.call(value);
            }),
          ],
        ),
      ),
    );
  }
}
