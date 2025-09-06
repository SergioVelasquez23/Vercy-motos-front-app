import 'package:flutter/material.dart';
import 'dart:convert';
import '../controllers/carga_masiva_controller.dart';
import '../theme/app_theme.dart';

class AdminCargaMasivaScreen extends StatefulWidget {
  const AdminCargaMasivaScreen({super.key});

  @override
  State<AdminCargaMasivaScreen> createState() => _AdminCargaMasivaScreenState();
}

class _AdminCargaMasivaScreenState extends State<AdminCargaMasivaScreen> {
  final CargaMasivaController _controller = CargaMasivaController();
  final TextEditingController _jsonController = TextEditingController();
  bool _isLoading = false;
  String _resultado = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Administración - Carga Masiva', style: AppTheme.headlineSmall),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título principal
            Text(
              '🚀 Herramientas de Carga Masiva',
              style: AppTheme.headlineMedium,
            ),
            SizedBox(height: 8),
            Text(
              'Utiliza estas herramientas para llenar rápidamente la base de datos',
              style: AppTheme.bodyMedium,
            ),
            SizedBox(height: 24),

            // Sección 1: Categorías
            _buildSeccionCard(
              '🗂️ Gestión de Categorías',
              'Crear y consultar categorías de productos',
              [
                _buildBotonAccion(
                  'Crear Categorías Básicas',
                  'Crea categorías predefinidas del restaurante',
                  Icons.add_box,
                  Colors.blue,
                  () => _ejecutarAccion(_controller.crearCategoriasBasicas),
                ),
                _buildBotonAccion(
                  'Ver IDs de Categorías',
                  'Consulta todos los IDs de categorías existentes',
                  Icons.list_alt,
                  Colors.green,
                  () => _ejecutarAccionConResultado(_controller.obtenerIdsCategorias),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Sección 2: Ingredientes
            _buildSeccionCard(
              '🥕 Gestión de Ingredientes',
              'Consultar ingredientes para asignación a productos',
              [
                _buildBotonAccion(
                  'Ver IDs de Ingredientes',
                  'Consulta todos los IDs de ingredientes existentes',
                  Icons.list_alt,
                  Colors.orange,
                  () => _ejecutarAccionConResultado(_controller.obtenerIdsIngredientes),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Sección 3: Productos
            _buildSeccionCard(
              '📦 Carga Masiva de Productos',
              'Cargar múltiples productos desde JSON',
              [
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: _jsonController,
                    maxLines: 8,
                    style: AppTheme.bodySmall,
                    decoration: InputDecoration(
                      labelText: 'JSON de Productos',
                      labelStyle: AppTheme.bodyMedium,
                      hintText: _getEjemploJSON(),
                      hintStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textLight),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppTheme.cardBg,
                    ),
                  ),
                ),
                _buildBotonAccion(
                  'Cargar Productos desde JSON',
                  'Procesa el JSON y crea los productos masivamente',
                  Icons.upload_file,
                  Colors.purple,
                  () => _cargarProductosDesdeJSON(),
                ),
                _buildBotonAccion(
                  'Ejemplo de Productos',
                  'Carga productos de ejemplo para pruebas',
                  Icons.restaurant_menu,
                  Colors.teal,
                  () => _cargarProductosEjemplo(),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Sección de resultados
            if (_resultado.isNotEmpty)
              _buildSeccionCard(
                '📊 Resultados',
                'Salida de la última operación',
                [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.textLight.withOpacity(0.3)),
                    ),
                    child: Text(
                      _resultado,
                      style: AppTheme.bodySmall.copyWith(
                        fontFamily: 'monospace',
                        color: AppTheme.success,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _resultado = ''),
                    child: Text('Limpiar resultados'),
                  ),
                ],
              ),

            SizedBox(height: 24),

            // Instrucciones de uso
            _buildSeccionCard(
              '📖 Instrucciones de Uso',
              'Pasos recomendados para la carga masiva',
              [
                _buildInstruccion('1', 'Crear categorías básicas primero', Icons.category),
                _buildInstruccion('2', 'Consultar IDs de categorías', Icons.find_in_page),
                _buildInstruccion('3', 'Preparar JSON con tus productos', Icons.edit),
                _buildInstruccion('4', 'Cargar productos masivamente', Icons.cloud_upload),
                _buildInstruccion('5', 'Agregar ingredientes después (opcional)', Icons.add),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionCard(String titulo, String descripcion, List<Widget> children) {
    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: AppTheme.headlineSmall),
            SizedBox(height: 4),
            Text(descripcion, style: AppTheme.bodyMedium),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildBotonAccion(String titulo, String descripcion, IconData icono, Color color, VoidCallback onPressed) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icono),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
            Text(descripcion, style: AppTheme.bodySmall),
          ],
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.all(16),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildInstruccion(String numero, String texto, IconData icono) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primary,
            child: Text(numero, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: 12),
          Icon(icono, color: AppTheme.primary, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: AppTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _getEjemploJSON() {
    return '''[
  {
    "nombre": "Bandeja Paisa",
    "descripcion": "Plato tradicional",
    "precio": 28000,
    "categoria": "Platos Principales",
    "disponible": true,
    "tiempoPreparacion": 25
  }
]''';
  }

  Future<void> _ejecutarAccion(Future<void> Function() accion) async {
    setState(() {
      _isLoading = true;
      _resultado = 'Ejecutando...';
    });

    try {
      await accion();
      setState(() {
        _resultado = 'Operación completada exitosamente ✅';
      });
    } catch (e) {
      setState(() {
        _resultado = 'Error: $e ❌';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _ejecutarAccionConResultado(Future<Map<String, String>> Function() accion) async {
    setState(() {
      _isLoading = true;
      _resultado = 'Consultando...';
    });

    try {
      final resultado = await accion();
      String resultadoTexto = 'Resultados:\\n\\n';
      resultado.forEach((nombre, id) {
        resultadoTexto += '"$nombre": "$id"\\n';
      });
      
      setState(() {
        _resultado = resultadoTexto;
      });
    } catch (e) {
      setState(() {
        _resultado = 'Error: $e ❌';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarProductosDesdeJSON() async {
    if (_jsonController.text.trim().isEmpty) {
      setState(() {
        _resultado = 'Por favor ingresa un JSON válido ⚠️';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _resultado = 'Procesando JSON...';
    });

    try {
      final List<dynamic> jsonData = jsonDecode(_jsonController.text);
      final List<Map<String, dynamic>> productosData = jsonData.cast<Map<String, dynamic>>();
      
      await _controller.cargarProductosMasivamente(productosData);
      
      setState(() {
        _resultado = 'Productos cargados exitosamente desde JSON ✅\\nTotal procesados: ${productosData.length}';
      });
    } catch (e) {
      setState(() {
        _resultado = 'Error procesando JSON: $e ❌';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarProductosEjemplo() async {
    final productosEjemplo = [
      {
        "nombre": "Bandeja Paisa",
        "descripcion": "Plato tradicional con frijoles, arroz, carne, chicharrón, huevo, aguacate y arepa",
        "precio": 28000,
        "categoria": "Platos Principales",
        "disponible": true,
        "tiempoPreparacion": 25
      },
      {
        "nombre": "Ajiaco Santafereño",
        "descripcion": "Sopa tradicional con pollo, mazorca, papa, guascas y alcaparras",
        "precio": 22000,
        "categoria": "Sopas",
        "disponible": true,
        "tiempoPreparacion": 30
      },
      {
        "nombre": "Pechuga a la Plancha",
        "descripcion": "Pechuga de pollo a la plancha con arroz y ensalada",
        "precio": 18000,
        "categoria": "Pollo",
        "disponible": true,
        "tiempoPreparacion": 20
      },
      {
        "nombre": "Jugo Natural de Naranja",
        "descripcion": "Jugo fresco de naranja natural",
        "precio": 6000,
        "categoria": "Bebidas",
        "disponible": true,
        "tiempoPreparacion": 5
      },
      {
        "nombre": "Flan de Caramelo",
        "descripcion": "Postre tradicional con caramelo",
        "precio": 8000,
        "categoria": "Postres",
        "disponible": true,
        "tiempoPreparacion": 10
      }
    ];

    setState(() {
      _isLoading = true;
      _resultado = 'Cargando productos de ejemplo...';
    });

    try {
      await _controller.cargarProductosMasivamente(productosEjemplo);
      
      setState(() {
        _resultado = 'Productos de ejemplo cargados exitosamente ✅\\nTotal cargados: ${productosEjemplo.length}';
      });
    } catch (e) {
      setState(() {
        _resultado = 'Error cargando productos de ejemplo: $e ❌';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }
}
