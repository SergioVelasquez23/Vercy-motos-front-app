import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/documento_mesa.dart';
import '../models/pedido.dart';
import '../models/item_pedido.dart';
import '../models/factura_electronica_dian.dart';
import '../services/factura_electronica_service.dart';
import '../utils/factura_electronica_xml_generator.dart';
import '../widgets/factura_electronica_widgets.dart';
import 'configuracion_facturacion_screen.dart';

/// Pantalla de prueba para facturación electrónica
/// Permite probar toda la funcionalidad sin necesidad de tener una mesa real
class PruebaFacturacionScreen extends StatefulWidget {
  const PruebaFacturacionScreen({Key? key}) : super(key: key);

  @override
  State<PruebaFacturacionScreen> createState() =>
      _PruebaFacturacionScreenState();
}

class _PruebaFacturacionScreenState extends State<PruebaFacturacionScreen> {
  FacturaElectronicaDian? _facturaGenerada;
  String? _xmlGenerado;
  bool _cargando = false;
  String? _error;

  // Para crear documento de prueba
  final _totalController = TextEditingController(text: '50000');
  final _consecutivoController = TextEditingController(text: '0000001');

  @override
  void dispose() {
    _totalController.dispose();
    _consecutivoController.dispose();
    super.dispose();
  }

  /// Crear un documento de mesa de prueba
  DocumentoMesa _crearDocumentoPrueba() {
    final total = double.tryParse(_totalController.text) ?? 50000;

    // Crear items de ejemplo
    final items = [
      ItemPedido(
        productoId: 'PROD001',
        productoNombre: 'Bandeja Paisa',
        cantidad: 1,
        precioUnitario: 25000,
      ),
      ItemPedido(
        productoId: 'PROD002',
        productoNombre: 'Jugo Natural',
        cantidad: 2,
        precioUnitario: 8000,
      ),
      ItemPedido(
        productoId: 'PROD003',
        productoNombre: 'Postre',
        cantidad: 1,
        precioUnitario: 9000,
      ),
    ];

    final pedido = Pedido(
      id: 'PEDIDO-TEST-001',
      fecha: DateTime.now(),
      tipo: TipoPedido.normal,
      mesa: 'Mesa 1 (Prueba)',
      mesero: 'Mesero Test',
      items: items,
      total: total,
      estado: EstadoPedido.pagado,
    );

    return DocumentoMesa(
      id: 'DOC-TEST-001',
      numeroDocumento: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      fecha: DateTime.now(),
      total: total,
      vendedor: 'Mesero Test',
      mesaNombre: 'Mesa 1',
      pedidos: [pedido],
      pedidosIds: [pedido.id],
      pagado: true,
      formaPago: 'efectivo',
      fechaCreacion: DateTime.now(),
      fechaPago: DateTime.now(),
      requiereFacturaElectronica: true,
    );
  }

  /// Probar generación completa de factura
  Future<void> _probarGeneracionFactura() async {
    setState(() {
      _cargando = true;
      _error = null;
      _facturaGenerada = null;
      _xmlGenerado = null;
    });

    try {
      // 1. Crear documento de prueba
      final documento = _crearDocumentoPrueba();

      // 2. Solicitar datos del cliente
      final datosCliente = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) =>
            DatosFacturaElectronicaDialog(documentoMesa: documento),
      );

      if (datosCliente == null) {
        setState(() => _cargando = false);
        return;
      }

      // 3. Actualizar documento con datos del cliente
      final documentoConDatos = documento.copyWith(
        clienteNombre: datosCliente['nombre'],
        clienteIdentificacion: datosCliente['identificacion'],
        clienteTipoDocumento: datosCliente['tipoDocumento'],
        clienteEmail: datosCliente['email'],
        clienteTelefono: datosCliente['telefono'],
        clienteDireccion: datosCliente['direccion'],
      );

      // 4. Generar factura electrónica
      final factura =
          await FacturaElectronicaService.generarFacturaDesdeDocumentoMesa(
            documentoMesa: documentoConDatos,
            numeroConsecutivo: _consecutivoController.text,
            clienteNombre: datosCliente['nombre'],
            clienteIdentificacion: datosCliente['identificacion'],
            clienteTipoDocumento: datosCliente['tipoDocumento'],
            clienteEmail: datosCliente['email'],
            clienteTelefono: datosCliente['telefono'],
            clienteDireccion: datosCliente['direccion'],
          );

      // 5. Validar factura
      if (!FacturaElectronicaService.validarFacturaParaEnvio(factura)) {
        throw Exception('La factura no cumple con los requisitos mínimos');
      }

      // 6. Generar XML UBL
      final xml = FacturaElectronicaXmlGenerator.generarXmlUBL(factura);

      setState(() {
        _facturaGenerada = factura;
        _xmlGenerado = xml;
        _cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Factura generada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Copiar XML al portapapeles
  void _copiarXml() {
    if (_xmlGenerado != null) {
      Clipboard.setData(ClipboardData(text: _xmlGenerado!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('XML copiado al portapapeles')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba de Facturación DIAN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuración',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ConfiguracionFacturacionScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Información
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Entorno de Pruebas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Esta pantalla te permite probar la generación de facturas electrónicas sin afectar datos reales.',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '⚠️ Recuerda configurar primero los datos de tu empresa.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Configuración de prueba
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuración de Prueba',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _totalController,
                      decoration: const InputDecoration(
                        labelText: 'Total de la Factura',
                        prefixText: '\$ ',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _consecutivoController,
                      decoration: const InputDecoration(
                        labelText: 'Número Consecutivo',
                        prefixIcon: Icon(Icons.confirmation_number),
                        helperText: 'Sin prefijo, solo números',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botón de prueba
            ElevatedButton.icon(
              onPressed: _cargando ? null : _probarGeneracionFactura,
              icon: _cargando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _cargando ? 'Generando...' : 'Generar Factura de Prueba',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Error',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Resultado
            if (_facturaGenerada != null) ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Factura Generada',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      _buildInfoRow('Número', _facturaGenerada!.numeroFactura),
                      _buildInfoRow('CUFE', _facturaGenerada!.cufe ?? 'N/A'),
                      _buildInfoRow(
                        'Cliente',
                        _facturaGenerada!.adquiriente.nombre,
                      ),
                      _buildInfoRow(
                        'Identificación',
                        _facturaGenerada!.adquiriente.identificacion,
                      ),
                      _buildInfoRow(
                        'Subtotal',
                        '\$${_facturaGenerada!.subtotal.toStringAsFixed(0)}',
                      ),
                      _buildInfoRow(
                        'IVA',
                        '\$${_facturaGenerada!.totalImpuestos.toStringAsFixed(0)}',
                      ),
                      _buildInfoRow(
                        'Total',
                        '\$${_facturaGenerada!.totalFactura.toStringAsFixed(0)}',
                        bold: true,
                      ),
                      _buildInfoRow(
                        'Items',
                        '${_facturaGenerada!.items.length}',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botones de acción
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _copiarXml,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar XML'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _mostrarXml(),
                    icon: const Icon(Icons.code),
                    label: const Text('Ver XML'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _mostrarDetalles(),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Ver Detalles'),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Instrucciones
            ExpansionTile(
              title: const Text('💡 Instrucciones'),
              initiallyExpanded: false,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstruccion(
                        '1',
                        'Configura los datos de tu empresa',
                        'Ve a Configuración (⚙️) y llena los datos del emisor y autorización DIAN.',
                      ),
                      _buildInstruccion(
                        '2',
                        'Genera una factura de prueba',
                        'Haz clic en "Generar Factura de Prueba" e ingresa los datos del cliente.',
                      ),
                      _buildInstruccion(
                        '3',
                        'Revisa el XML generado',
                        'Verifica que el XML cumpla con el formato UBL 2.1 de la DIAN.',
                      ),
                      _buildInstruccion(
                        '4',
                        'Valida el CUFE',
                        'El CUFE debe tener 96 caracteres (SHA-384).',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruccion(String numero, String titulo, String descripcion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                numero,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(descripcion, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarXml() {
    if (_xmlGenerado == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'XML UBL 2.1',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: _copiarXml,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _xmlGenerado!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalles() {
    if (_facturaGenerada == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detalles de la Factura',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._facturaGenerada!.items.map(
                        (item) => Card(
                          child: ListTile(
                            title: Text(item.descripcion),
                            subtitle: Text(
                              'Cantidad: ${item.cantidad} x \$${item.precioUnitario.toStringAsFixed(0)}',
                            ),
                            trailing: Text(
                              '\$${item.totalItem.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Impuestos:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._facturaGenerada!.impuestos.map(
                        (imp) => Card(
                          child: ListTile(
                            title: Text(
                              '${imp.nombreImpuesto} (${imp.porcentaje}%)',
                            ),
                            subtitle: Text(
                              'Base: \$${imp.baseImponible.toStringAsFixed(0)}',
                            ),
                            trailing: Text(
                              '\$${imp.valorImpuesto.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
