import 'package:flutter/material.dart';
import '../config/constants.dart';

class UnidadesScreen extends StatefulWidget {
  @override
  _UnidadesScreenState createState() => _UnidadesScreenState();
}

class _UnidadesScreenState extends State<UnidadesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nuevaUnidadController = TextEditingController();
  bool _isLoading = false;

  // Datos de ejemplo para unidades (en un entorno real, estos vendrían de una API)
  List<String> _unidades = ['Kg', 'Gr', 'Unidad', 'Lb', 'Oz', 'Lt', 'ml'];

  List<String> _unidadesFiltradas = [];

  @override
  void initState() {
    super.initState();
    _unidadesFiltradas = _unidades;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nuevaUnidadController.dispose();
    super.dispose();
  }

  void _filtrarUnidades(String query) {
    if (query.isEmpty) {
      setState(() {
        _unidadesFiltradas = _unidades;
      });
    } else {
      setState(() {
        _unidadesFiltradas = _unidades
            .where(
              (unidad) => unidad.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      });
    }
  }

  void _mostrarDialogoNuevaUnidad() {
    final Color cardBg = Color(kCardBackgroundDark);
    final Color textDark = Color(kTextDark);
    final Color primary = Color(kPrimaryColor);

    _nuevaUnidadController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('Nueva Unidad', style: TextStyle(color: textDark)),
        content: TextField(
          controller: _nuevaUnidadController,
          decoration: InputDecoration(
            hintText: 'Nombre de la unidad',
            filled: true,
            fillColor: Colors.white12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          style: TextStyle(color: textDark),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: Text('Guardar'),
            onPressed: () {
              final nuevaUnidad = _nuevaUnidadController.text.trim();
              if (nuevaUnidad.isNotEmpty) {
                setState(() {
                  _unidades.add(nuevaUnidad);
                  _unidades.sort(); // Ordenar alfabéticamente
                  _unidadesFiltradas = _unidades;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unidad "$nuevaUnidad" agregada')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'El nombre de la unidad no puede estar vacío',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarUnidad(String unidad) {
    final Color cardBg = Color(kCardBackgroundDark);
    final Color textDark = Color(kTextDark);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('Eliminar Unidad', style: TextStyle(color: textDark)),
        content: Text(
          '¿Está seguro de que desea eliminar la unidad "$unidad"?',
          style: TextStyle(color: textDark),
        ),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            onPressed: () {
              setState(() {
                _unidades.remove(unidad);
                _unidadesFiltradas = _unidades
                    .where(
                      (u) => u.toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      ),
                    )
                    .toList();
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unidad "$unidad" eliminada')),
              );
            },
          ),
        ],
      ),
    );
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
        title: Text('Unidades', style: TextStyle(color: textDark)),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filtrarUnidades,
              decoration: InputDecoration(
                hintText: 'Buscar unidad...',
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

          // Lista de unidades
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  )
                : _unidadesFiltradas.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron unidades',
                      style: TextStyle(color: textDark),
                    ),
                  )
                : ListView.builder(
                    itemCount: _unidadesFiltradas.length,
                    itemBuilder: (context, index) {
                      final unidad = _unidadesFiltradas[index];
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        color: cardBg,
                        child: ListTile(
                          title: Text(
                            unidad,
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: primary),
                                onPressed: () {
                                  // Implementar edición en el futuro
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Función de edición en desarrollo',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    _confirmarEliminarUnidad(unidad),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
        onPressed: _mostrarDialogoNuevaUnidad,
        child: Icon(Icons.add),
        tooltip: 'Añadir nueva unidad',
      ),
    );
  }
}
