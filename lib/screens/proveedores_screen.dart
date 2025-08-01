import 'package:flutter/material.dart';
import '../config/constants.dart';

class ProveedoresScreen extends StatefulWidget {
  @override
  _ProveedoresScreenState createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  // Datos de ejemplo para proveedores (en un entorno real, estos vendrían de una API)
  final List<Map<String, dynamic>> _proveedores = [
    {
      'nombre': 'Aliños Mac',
      'documento': '890316938-1',
      'email': 'productosmaccali@productosmac.com',
      'telefono': '',
      'direccion': '',
    },
    {
      'nombre': 'Andalucía',
      'documento': '79534994-5',
      'email': 'alexandalucia@gmail.com',
      'telefono': '312 219 8946, 884 0747',
      'direccion': 'calle 12 # 13 - 27 Chipre',
    },
    {
      'nombre': 'Baratiko',
      'documento': '10528180890',
      'email': '',
      'telefono': '',
      'direccion': '',
    },
    {
      'nombre': 'Bodega Agroplaza',
      'documento': '30296801',
      'email': '',
      'telefono': '880 05 55 / 314 639 7929',
      'direccion': 'carrera 16 # 23 - 52',
    },
    {
      'nombre': 'CARNES',
      'documento': '1',
      'email': '',
      'telefono': '',
      'direccion': '',
    },
  ];

  List<Map<String, dynamic>> _proveedoresFiltrados = [];

  @override
  void initState() {
    super.initState();
    _proveedoresFiltrados = _proveedores;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarProveedores(String query) {
    if (query.isEmpty) {
      setState(() {
        _proveedoresFiltrados = _proveedores;
      });
    } else {
      setState(() {
        _proveedoresFiltrados = _proveedores
            .where(
              (proveedor) =>
                  proveedor['nombre'].toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  proveedor['documento'].toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  (proveedor['email'] != null &&
                      proveedor['email'].toLowerCase().contains(
                        query.toLowerCase(),
                      )),
            )
            .toList();
      });
    }
  }

  void _mostrarDetalleProveedor(Map<String, dynamic> proveedor) {
    final Color cardBg = Color(kCardBackgroundDark);
    final Color textDark = Color(kTextDark);
    final Color textLight = Color(kTextLight);
    final Color primary = Color(kPrimaryColor);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(proveedor['nombre'], style: TextStyle(color: textDark)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                'Documento:',
                proveedor['documento'],
                textDark,
                textLight,
              ),
              _buildInfoRow('Email:', proveedor['email'], textDark, textLight),
              _buildInfoRow(
                'Teléfono:',
                proveedor['telefono'],
                textDark,
                textLight,
              ),
              _buildInfoRow(
                'Dirección:',
                proveedor['direccion'],
                textDark,
                textLight,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cerrar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: Text('Editar'),
            onPressed: () {
              Navigator.of(context).pop();
              // Implementar edición en el futuro
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Función de edición en desarrollo')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color titleColor,
    Color valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        Text(
          value.isEmpty ? 'No especificado' : value,
          style: TextStyle(color: valueColor),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  void _mostrarDialogoNuevoProveedor() {
    // Implementar en el futuro
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Función en desarrollo')));
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Color(kPrimaryColor);
    final Color bgDark = Color(kBackgroundDark);
    final Color cardBg = Color(kCardBackgroundDark);
    final Color textDark = Color(kTextDark);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardBg,
        title: Text('Proveedores', style: TextStyle(color: textDark)),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filtrarProveedores,
              decoration: InputDecoration(
                hintText: 'Buscar proveedor...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              style: TextStyle(color: textDark),
            ),
          ),

          // Lista de proveedores
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  )
                : _proveedoresFiltrados.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron proveedores',
                      style: TextStyle(color: textDark),
                    ),
                  )
                : ListView.builder(
                    itemCount: _proveedoresFiltrados.length,
                    itemBuilder: (context, index) {
                      final proveedor = _proveedoresFiltrados[index];
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        color: cardBg,
                        child: ListTile(
                          title: Text(
                            proveedor['nombre'],
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Doc: ${proveedor['documento']}',
                            style: TextStyle(color: Color(kTextLight)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: primary),
                                onPressed: () {
                                  // Implementar edición en el futuro
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  // Implementar eliminación en el futuro
                                },
                              ),
                            ],
                          ),
                          onTap: () => _mostrarDetalleProveedor(proveedor),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
        onPressed: _mostrarDialogoNuevoProveedor,
        child: Icon(Icons.add),
        tooltip: 'Añadir nuevo proveedor',
      ),
    );
  }
}
