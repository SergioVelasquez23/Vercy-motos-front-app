import 'package:flutter/material.dart';
import '../widgets/imagen_producto_widget.dart';
import '../config/endpoints_config.dart';

/// Screen de prueba para verificar la carga de imágenes en móviles
class TestImagenScreen extends StatefulWidget {
  const TestImagenScreen({super.key});

  @override
  State<TestImagenScreen> createState() => _TestImagenScreenState();
}

class _TestImagenScreenState extends State<TestImagenScreen> {
  final EndpointsConfig _config = EndpointsConfig();

  final List<String> urlsPrueba = [
    // URLs de ejemplo que pueden existir
    'producto1.jpg',
    'producto2.png',
    'categoria1.webp',
    '/images/platos/test.jpg',
    'https://via.placeholder.com/150x150.png?text=Test1',
    'https://via.placeholder.com/150x150.jpg?text=Test2',
    'invalid_image.txt', // Inválida
    '', // Vacía
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', // Base64 válida
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test de Imágenes'),
        backgroundColor: Color(0xFF1A1A1A),
        foregroundColor: Color(0xFFFF6B00),
      ),
      backgroundColor: Color(0xFF1A1A1A),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de configuración
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuración Actual',
                    style: TextStyle(
                      color: Color(0xFFFF6B00),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('🌐 Configuración de Red'),
                  Divider(),
                  Text(
                    'Base URL: ${EndpointsConfig.baseUrl}',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                  Text(
                    'Endpoint imágenes: ${EndpointsConfig.baseUrl}/images/platos/',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            Text(
              'Pruebas de Carga de Imágenes',
              style: TextStyle(
                color: Color(0xFFFF6B00),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // Grid de pruebas de imágenes
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: urlsPrueba.length,
              itemBuilder: (context, index) {
                final url = urlsPrueba[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: ImagenProductoWidget(
                            urlRemota: url,
                            width: double.infinity,
                            height: double.infinity,
                            backendBaseUrl: EndpointsConfig.baseUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          url.isEmpty
                              ? 'URL vacía'
                              : url.length > 20
                              ? '${url.substring(0, 20)}...'
                              : url,
                          style: TextStyle(
                            color: Color(0xFFCCCCCC),
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 20),

            // Botón para probar conectividad
            ElevatedButton(
              onPressed: _testConnectivity,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Probar Conectividad Backend'),
            ),
          ],
        ),
      ),
    );
  }

  void _testConnectivity() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Probando conectividad con ${EndpointsConfig.baseUrl}...',
        ),
        backgroundColor: Color(0xFFFF6B00),
      ),
    );

    try {
      // Esta es una prueba básica de conectividad
      // En un escenario real, harías una llamada HTTP real
      print('🔍 Probando conectividad con: ${EndpointsConfig.baseUrl}');
      print(
        '🔍 Endpoint de imágenes: ${EndpointsConfig.baseUrl}/images/platos/',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Revisa la consola para detalles de conectividad'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
