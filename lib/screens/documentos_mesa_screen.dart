import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/documento_mesa.dart';
import '../models/mesa.dart';
import '../models/pedido.dart';
import '../services/documento_mesa_service.dart';
import '../providers/user_provider.dart';
import 'pedido_screen.dart';

class DocumentosMesaScreen extends StatefulWidget {
  final Mesa mesa;

  const DocumentosMesaScreen({Key? key, required this.mesa}) : super(key: key);

  @override
  State<DocumentosMesaScreen> createState() => _DocumentosMesaScreenState();
}

class _DocumentosMesaScreenState extends State<DocumentosMesaScreen>
    with TickerProviderStateMixin {
  final DocumentoMesaService _documentoService = DocumentoMesaService();
  List<DocumentoMesa> _documentos = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  // Constantes de diseño
  static const Color _primary = Color(0xFFFF6B00);
  static const Color _bgDark = Color(0xFF121212);
  static const Color _cardBg = Color(0xFF1E1E1E);
  static const Color _textLight = Color(0xFFE0E0E0);
  static const Color _textDark = Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDocumentos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDocumentos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final documentos = await _documentoService.getDocumentosPorMesa(
        widget.mesa.nombre,
      );
      setState(() {
        _documentos = documentos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar documentos: $e';
        _isLoading = false;
      });
    }
  }

  List<DocumentoMesa> get _documentosPendientes =>
      _documentos.where((doc) => !doc.pagado).toList();

  List<DocumentoMesa> get _documentosPagados =>
      _documentos.where((doc) => doc.pagado).toList();

  double get _totalPendiente =>
      _documentosPendientes.fold(0.0, (sum, doc) => sum + doc.total);

  double get _totalPagado =>
      _documentosPagados.fold(0.0, (sum, doc) => sum + doc.total);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        title: Text(
          '${widget.mesa.nombre} - Documentos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargarDocumentos),
          IconButton(icon: Icon(Icons.add), onPressed: _crearNuevoDocumento),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Todos (${_documentos.length})'),
            Tab(text: 'Pendientes (${_documentosPendientes.length})'),
            Tab(text: 'Pagados (${_documentosPagados.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildResumenCard(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primary))
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: TextStyle(color: Colors.red)),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cargarDocumentos,
                          child: Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDocumentosList(_documentos),
                      _buildDocumentosList(_documentosPendientes),
                      _buildDocumentosList(_documentosPagados),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resumen',
                style: TextStyle(
                  color: _textLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.analytics, color: _primary),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildResumenItem(
                  'Pendiente',
                  '\$${_totalPendiente.toStringAsFixed(0)}',
                  Colors.orange,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildResumenItem(
                  'Pagado',
                  '\$${_totalPagado.toStringAsFixed(0)}',
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(String titulo, String valor, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentosList(List<DocumentoMesa> documentos) {
    if (documentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: _textLight.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'No hay documentos',
              style: TextStyle(color: _textLight.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: documentos.length,
      itemBuilder: (context, index) {
        final documento = documentos[index];
        return _buildDocumentoCard(documento);
      },
    );
  }

  Widget _buildDocumentoCard(DocumentoMesa documento) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final canPay = userProvider.isAdmin && !documento.pagado;

    return Card(
      color: _cardBg,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: documento.pagado
              ? Colors.green.withOpacity(0.3)
              : _primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Doc. No. ${documento.numeroDocumento}',
                  style: TextStyle(
                    color: _textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: documento.estadoColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    documento.estadoTexto,
                    style: TextStyle(
                      color: documento.estadoColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Fecha: ${documento.fechaFormateada}',
              style: TextStyle(
                color: _textLight.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            Text(
              'Vendedor: ${documento.vendedor}',
              style: TextStyle(
                color: _textLight.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: \$${documento.total.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (canPay) ...[
                      ElevatedButton.icon(
                        onPressed: () => _pagarDocumento(documento),
                        icon: Icon(Icons.payment, size: 16),
                        label: Text('Pagar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => _verDetalleDocumento(documento),
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('Ver'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: BorderSide(color: _primary),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _crearNuevoDocumento() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PedidoScreen(mesa: widget.mesa)),
    );

    if (resultado == true) {
      _cargarDocumentos();
    }
  }

  void _verDetalleDocumento(DocumentoMesa documento) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Documento ${documento.numeroDocumento}',
          style: TextStyle(color: _textLight),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetalleItem('Fecha', documento.fechaFormateada),
              _buildDetalleItem('Vendedor', documento.vendedor),
              _buildDetalleItem(
                'Total',
                '\$${documento.total.toStringAsFixed(0)}',
              ),
              _buildDetalleItem('Estado', documento.estadoTexto),
              if (documento.pagado) ...[
                _buildDetalleItem('Pagado por', documento.pagadoPor ?? 'N/A'),
                _buildDetalleItem(
                  'Forma de pago',
                  documento.formaPago ?? 'N/A',
                ),
                if (documento.fechaPago != null)
                  _buildDetalleItem(
                    'Fecha de pago',
                    documento.fechaPago!.toString(),
                  ),
              ],
              SizedBox(height: 16),
              Text(
                'Pedidos (${documento.pedidos.length})',
                style: TextStyle(
                  color: _textLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              ...documento.pedidos.map(
                (pedido) => Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido #${pedido.id}',
                          style: TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Total: \$${pedido.total.toStringAsFixed(0)}',
                          style: TextStyle(color: _textLight.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: _textLight.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: _textLight)),
          ),
        ],
      ),
    );
  }

  void _pagarDocumento(DocumentoMesa documento) async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _buildDialogoPago(documento),
    );

    if (resultado != null) {
      try {
        setState(() => _isLoading = true);

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final pagadoPor = userProvider.userName ?? 'Usuario Desconocido';

        await _documentoService.pagarDocumento(
          documentoId: documento.id,
          formaPago: resultado['formaPago'],
          pagadoPor: pagadoPor,
          propina: resultado['propina'] ?? 0.0,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documento pagado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        _cargarDocumentos();
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al pagar documento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDialogoPago(DocumentoMesa documento) {
    String formaPago = 'efectivo';
    double propina = 0.0;
    final propinaController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Pagar Documento ${documento.numeroDocumento}',
          style: TextStyle(color: _textLight),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total a pagar: \$${documento.total.toStringAsFixed(0)}',
              style: TextStyle(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Forma de pago:',
              style: TextStyle(color: _textLight, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            DropdownButton<String>(
              value: formaPago,
              dropdownColor: _cardBg,
              style: TextStyle(color: _textLight),
              onChanged: (value) => setState(() => formaPago = value!),
              items: [
                DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                DropdownMenuItem(
                  value: 'transferencia',
                  child: Text('Transferencia/Tarjeta'),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: propinaController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: _textLight),
              decoration: InputDecoration(
                labelText: 'Propina (\$)',
                labelStyle: TextStyle(color: _textLight.withOpacity(0.7)),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _textLight.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _primary),
                ),
              ),
              onChanged: (value) {
                propina = double.tryParse(value) ?? 0.0;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'formaPago': formaPago,
              'propina': propina,
            }),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Confirmar Pago'),
          ),
        ],
      ),
    );
  }
}
