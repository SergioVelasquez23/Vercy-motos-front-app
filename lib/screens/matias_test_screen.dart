import 'package:flutter/material.dart';
import '../services/matias_service.dart';
import '../theme/app_theme.dart';

/// Screen de testing para validar endpoints Matias API punto por punto
class MatiasTestScreen extends StatefulWidget {
  const MatiasTestScreen({super.key});

  @override
  State<MatiasTestScreen> createState() => _MatiasTestScreenState();
}

class _MatiasTestScreenState extends State<MatiasTestScreen> {
  final List<TestResult> resultados = [];
  bool testeando = false;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            // Control buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: testeando ? null : _correrTodos,
                  icon: testeando 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.play_arrow),
                  label: Text(testeando ? 'Testeando...' : '▶️ Ejecutar todos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() => resultados.clear()),
                  icon: Icon(Icons.delete_sweep),
                  label: Text('🗑️ Limpiar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Resultados
            if (resultados.isEmpty)
              Center(
                child: Text(
                  'Haz clic en "Ejecutar todos" para probar los endpoints',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: resultados.length,
                  itemBuilder: (context, index) {
                    final r = resultados[index];
                    return _buildResultCard(r);
                  },
                ),
              )
          ],
        ),
      );
  }

  Widget _buildResultCard(TestResult r) {
    final isSuccess = r.success;
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.endpoint,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                  if (r.tiempo != null)
                    Text(
                      '⏱️ ${r.tiempo}ms',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            Text(
              isSuccess ? '✅' : '❌',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.mensaje != null) ...[
                  Text(
                    'Mensaje:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      r.mensaje!,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 12),
                ],
                if (r.datos != null) ...[
                  Text(
                    'Datos (${r.datos!.length} registros):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: r.datos!
                          .take(10)
                          .map(
                            (d) => Chip(
                              label: Text(
                                d,
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if (r.datos!.length > 10)
                    Text(
                      '${r.datos!.length - 10} más...',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
                if (r.error != null) ...[
                  Text(
                    'Error:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      r.error!,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _correrTodos() async {
    setState(() {
      resultados.clear();
      testeando = true;
    });

    final tests = [
      ('Autenticación', _testAuth),
      ('Status', _testStatus),
      ('Tipos Documento', _testTiposDocumento),
      ('Formas Pago', _testFormasPago),
      ('Medios Pago', _testMediosPago),
      ('Tipos Organización', _testTiposOrganizacion),
      ('Tipos Operación', _testTiposOperacion),
      ('Tipos Doc Electrónico', _testTiposDocElectronico),
      ('Unidades Medida', _testUnidadesMedida),
      ('Conceptos Nota Corrección', _testConceptosNotaCorreccion),
      ('Monedas', _testMonedas),
    ];

    for (final (nombre, test) in tests) {
      try {
        final resultado = await test();
        setState(() => resultados.add(resultado));
      } catch (e) {
        setState(() => resultados.add(
          TestResult(
            endpoint: nombre,
            success: false,
            error: e.toString(),
          ),
        ));
      }
      await Future.delayed(Duration(milliseconds: 200)); // Un poco de espacio
    }

    setState(() => testeando = false);
  }

  Future<TestResult> _testAuth() async {
    final inicio = DateTime.now();
    try {
      final resultado = await MatiasService.authenticate();
      final tiempo = DateTime.now().difference(inicio).inMilliseconds;
      return TestResult(
        endpoint: 'POST /authenticate',
        success: resultado,
        mensaje: resultado ? 'Autenticado exitosamente' : 'Falló la autenticación',
        tiempo: tiempo,
      );
    } catch (e) {
      return TestResult(
        endpoint: 'POST /authenticate',
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<TestResult> _testStatus() async {
    final inicio = DateTime.now();
    try {
      final resultado = await MatiasService.checkStatus();
      final tiempo = DateTime.now().difference(inicio).inMilliseconds;
      return TestResult(
        endpoint: 'GET /status',
        success: resultado,
        mensaje: resultado ? 'Autenticado' : 'No autenticado',
        tiempo: tiempo,
      );
    } catch (e) {
      return TestResult(
        endpoint: 'GET /status',
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<TestResult> _testTiposDocumento() async {
    final inicio = DateTime.now();
    final datos = await MatiasService.obtenerTiposDocumento();
    final tiempo = DateTime.now().difference(inicio).inMilliseconds;
    return TestResult(
      endpoint: 'GET /lookup/tipos-documento',
      success: datos.isNotEmpty,
      datos: datos,
      tiempo: tiempo,
    );
  }

  Future<TestResult> _testFormasPago() async {
    final inicio = DateTime.now();
    final datos = await MatiasService.obtenerFormasPago();
    final tiempo = DateTime.now().difference(inicio).inMilliseconds;
    return TestResult(
      endpoint: 'GET /lookup/formas-pago',
      success: datos.isNotEmpty,
      datos: datos,
      tiempo: tiempo,
    );
  }

  Future<TestResult> _testMediosPago() async {
    final inicio = DateTime.now();
    final datos = await MatiasService.obtenerMediosPago();
    final tiempo = DateTime.now().difference(inicio).inMilliseconds;
    return TestResult(
      endpoint: 'GET /lookup/medios-pago',
      success: datos.isNotEmpty,
      datos: datos,
      tiempo: tiempo,
    );
  }

  Future<TestResult> _testTiposOrganizacion() async {
    final inicio = DateTime.now();
    final datos = await MatiasService.obtenerTiposOrganizacion();
    final tiempo = DateTime.now().difference(inicio).inMilliseconds;
    return TestResult(
      endpoint: 'GET /lookup/tipos-organizacion',
      success: datos.isNotEmpty,
      datos: datos,
      tiempo: tiempo,
    );
  }

  Future<TestResult> _testTiposOperacion() async {
    final inicio = DateTime.now();
    final datos = await MatiasService.obtenerTiposOperacion();
    final tiempo = DateTime.now().difference(inicio).inMilliseconds;
    return TestResult(
      endpoint: 'GET /lookup/tipos-operacion',
      success: datos.isNotEmpty,
      datos: datos,
      tiempo: tiempo,
    );
  }

  Future<TestResult> _testTiposDocElectronico() async {
    final inicio = DateTime.now();
    final datos = await MatiasService.obtenerTiposDocumentoElectronico();
    final tiempo = DateTime.now().difference(inicio).inMilliseconds;
    return TestResult(
      endpoint: 'GET /lookup/tipos-documento-electronico',
      success: datos.isNotEmpty,
      datos: datos,
      tiempo: tiempo,
    );
  }

  Future<TestResult> _testUnidadesMedida() async {
    final inicio = DateTime.now();
    final datos = await MatiasService.obtenerUnidadesMedida();
    final tiempo = DateTime.now().difference(inicio).inMilliseconds;
    return TestResult(
      endpoint: 'GET /lookup/unidades-medida',
      success: datos.isNotEmpty,
      datos: datos,
      tiempo: tiempo,
    );
  }

  Future<TestResult> _testConceptosNotaCorreccion() async {
    final inicio = DateTime.now();
    final datos = await MatiasService.obtenerConceptosNotaCorreccion();
    final tiempo = DateTime.now().difference(inicio).inMilliseconds;
    return TestResult(
      endpoint: 'GET /lookup/conceptos-nota-correccion',
      success: datos.isNotEmpty,
      datos: datos,
      tiempo: tiempo,
    );
  }

  Future<TestResult> _testMonedas() async {
    final inicio = DateTime.now();
    final datos = await MatiasService.obtenerMonedas();
    final tiempo = DateTime.now().difference(inicio).inMilliseconds;
    return TestResult(
      endpoint: 'GET /lookup/monedas',
      success: datos.isNotEmpty,
      datos: datos,
      tiempo: tiempo,
    );
  }
}

class TestResult {
  final String endpoint;
  final bool success;
  final String? mensaje;
  final List<String>? datos;
  final String? error;
  final int? tiempo;

  TestResult({
    required this.endpoint,
    required this.success,
    this.mensaje,
    this.datos,
    this.error,
    this.tiempo,
  });
}
