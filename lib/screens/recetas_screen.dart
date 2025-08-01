import 'package:flutter/material.dart';
import '../config/constants.dart';

class RecetasScreen extends StatefulWidget {
  @override
  _RecetasScreenState createState() => _RecetasScreenState();
}

class _RecetasScreenState extends State<RecetasScreen> {
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  // Datos de ejemplo para recetas (en un entorno real, estos vendrían de una API)
  final List<Map<String, dynamic>> _recetas = [
    {
      'nombre': 'Hamburguesa de res',
      'descripcion': 'Hamburguesa clásica con carne de res',
      'categoria': 'Hamburguesas',
      'ingredientes': ['Carne molida', 'Pan', 'Tomate', 'Lechuga', 'Queso'],
      'costo': 12000,
      'precioVenta': 22000,
    },
    {
      'nombre': 'Chorizo a la parrilla',
      'descripcion': 'Chorizo asado con chimichurri',
      'categoria': 'Parrillada',
      'ingredientes': ['Chorizo', 'Chimichurri'],
      'costo': 8000,
      'precioVenta': 15000,
    },
    {
      'nombre': 'Cerdo ejecutivo',
      'descripcion': 'Corte premium de cerdo con guarnición',
      'categoria': 'Platos fuertes',
      'ingredientes': ['Cerdo Ejecutivo', 'Papas', 'Ensalada'],
      'costo': 18000,
      'precioVenta': 32000,
    },
  ];

  List<Map<String, dynamic>> _recetasFiltradas = [];

  @override
  void initState() {
    super.initState();
    _recetasFiltradas = _recetas;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarRecetas(String query) {
    if (query.isEmpty) {
      setState(() {
        _recetasFiltradas = _recetas;
      });
    } else {
      setState(() {
        _recetasFiltradas = _recetas
            .where(
              (receta) =>
                  receta['nombre'].toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  receta['descripcion'].toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  receta['categoria'].toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();
      });
    }
  }

  void _mostrarDetalleReceta(Map<String, dynamic> receta) {
    final Color cardBg = Color(kCardBackgroundDark);
    final Color textDark = Color(kTextDark);
    final Color textLight = Color(kTextLight);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(receta['nombre'], style: TextStyle(color: textDark)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Descripción:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
              Text(receta['descripcion'], style: TextStyle(color: textLight)),
              SizedBox(height: 8),
              Text(
                'Categoría:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
              Text(receta['categoria'], style: TextStyle(color: textLight)),
              SizedBox(height: 8),
              Text(
                'Ingredientes:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
              ...receta['ingredientes']
                  .map<Widget>(
                    (ingrediente) => Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        '• $ingrediente',
                        style: TextStyle(color: textLight),
                      ),
                    ),
                  )
                  .toList(),
              SizedBox(height: 8),
              Text(
                'Costo:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
              Text('\$${receta['costo']}', style: TextStyle(color: textLight)),
              SizedBox(height: 8),
              Text(
                'Precio de venta:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
              Text(
                '\$${receta['precioVenta']}',
                style: TextStyle(color: textLight),
              ),
              SizedBox(height: 8),
              Text(
                'Margen:',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
              Text(
                '${(((receta['precioVenta'] - receta['costo']) / receta['precioVenta']) * 100).toStringAsFixed(2)}%',
                style: TextStyle(color: textLight),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cerrar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoNuevaReceta() {
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
        title: Text('Recetas', style: TextStyle(color: textDark)),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filtrarRecetas,
              decoration: InputDecoration(
                hintText: 'Buscar receta...',
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

          // Lista de recetas
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  )
                : _recetasFiltradas.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron recetas',
                      style: TextStyle(color: textDark),
                    ),
                  )
                : ListView.builder(
                    itemCount: _recetasFiltradas.length,
                    itemBuilder: (context, index) {
                      final receta = _recetasFiltradas[index];
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        color: cardBg,
                        child: ListTile(
                          title: Text(
                            receta['nombre'],
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Categoría: ${receta['categoria']} | Ingredientes: ${receta['ingredientes'].length}',
                            style: TextStyle(color: Color(kTextLight)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${receta['precioVenta']}',
                                    style: TextStyle(color: textDark),
                                  ),
                                  Text(
                                    'Costo: \$${receta['costo']}',
                                    style: TextStyle(
                                      color: Color(kTextLight),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 16),
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 18,
                                  color: primary,
                                ),
                                onPressed: () => _mostrarDetalleReceta(receta),
                              ),
                            ],
                          ),
                          onTap: () => _mostrarDetalleReceta(receta),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
        onPressed: _mostrarDialogoNuevaReceta,
        child: Icon(Icons.add),
        tooltip: 'Crear nueva receta',
      ),
    );
  }
}
