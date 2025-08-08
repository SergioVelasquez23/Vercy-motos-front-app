import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cancelar_producto_request.dart';
import '../models/producto.dart';
import '../services/pedido_service.dart';
import '../providers/user_provider.dart';

class CancelarProductoDialog extends StatefulWidget {
  final String pedidoId;
  final Producto producto;
  final VoidCallback? onProductoCancelado;

  const CancelarProductoDialog({
    Key? key,
    required this.pedidoId,
    required this.producto,
    this.onProductoCancelado,
  }) : super(key: key);

  @override
  _CancelarProductoDialogState createState() => _CancelarProductoDialogState();
}

class _CancelarProductoDialogState extends State<CancelarProductoDialog> {
  final PedidoService _pedidoService = PedidoService();
  final TextEditingController _motivoController = TextEditingController();

  List<IngredienteDevolucion> _ingredientes = [];
  bool _isLoading = true;
  bool _isCanceling = false;
  String? _error;

  // Motivos predefinidos
  final List<String> _motivosPredefinidos = [
    'Cambio de cliente',
    'Error en el pedido',
    'Producto no disponible',
    'Solicitud del cliente',
    'Error del sistema',
    'Otro motivo',
  ];

  String _motivoSeleccionado = 'Cambio de cliente';
  final Map<String, String> _motivosNoDevolucion = {
    'Ya fue preparado': 'El ingrediente ya fue procesado/cocinado',
    'Producto perecedero': 'No se puede devolver por higiene',
    'Ingrediente contaminado':
        'El ingrediente fue expuesto y no es reutilizable',
    'Política de la casa': 'Por política no se devuelve este ingrediente',
  };

  @override
  void initState() {
    super.initState();
    _cargarIngredientes();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _cargarIngredientes() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final ingredientes = await _pedidoService
          .obtenerIngredientesParaDevolucion(
            widget.pedidoId,
            widget.producto.id,
          );

      setState(() {
        _ingredientes = ingredientes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar ingredientes: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelarProducto() async {
    if (_ingredientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay ingredientes para procesar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final responsable = userProvider.userName ?? 'Usuario desconocido';

    // Determinar motivo final
    String motivoFinal = _motivoSeleccionado;
    if (_motivoSeleccionado == 'Otro motivo' &&
        _motivoController.text.isNotEmpty) {
      motivoFinal = _motivoController.text.trim();
    }

    final request = CancelarProductoRequest(
      pedidoId: widget.pedidoId,
      productoId: widget.producto.id,
      ingredientes: _ingredientes,
      motivo: motivoFinal,
      responsable: responsable,
    );

    try {
      setState(() => _isCanceling = true);

      await _pedidoService.cancelarProductoConIngredientes(request);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Producto cancelado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.onProductoCancelado != null) {
        widget.onProductoCancelado!();
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cancelar producto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCanceling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Cancelar: ${widget.producto.nombre}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),

            Divider(),

            // Contenido
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 48),
                          SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _cargarIngredientes,
                            child: Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : _buildContenido(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_ingredientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Este producto no tiene ingredientes descontados del inventario',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '¿Deseas cancelar el producto directamente?',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('No cancelar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Cancelar producto'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selección de motivo
          Text(
            'Motivo de cancelación:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),

          DropdownButtonFormField<String>(
            value: _motivoSeleccionado,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _motivosPredefinidos.map((motivo) {
              return DropdownMenuItem(value: motivo, child: Text(motivo));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _motivoSeleccionado = value!;
              });
            },
          ),

          // Campo de texto para "Otro motivo"
          if (_motivoSeleccionado == 'Otro motivo') ...[
            SizedBox(height: 12),
            TextField(
              controller: _motivoController,
              decoration: InputDecoration(
                labelText: 'Especifica el motivo',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLines: 2,
            ),
          ],

          SizedBox(height: 20),

          // Lista de ingredientes
          Text(
            'Ingredientes descontados del inventario:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),

          Text(
            'Selecciona cuáles ingredientes deseas devolver al inventario:',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 12),

          // Cards de ingredientes
          ..._ingredientes.map(
            (ingrediente) => _buildIngredienteCard(ingrediente),
          ),

          SizedBox(height: 20),

          // Resumen
          _buildResumen(),
        ],
      ),
    );
  }

  Widget _buildIngredienteCard(IngredienteDevolucion ingrediente) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ingrediente.nombre,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: ingrediente.devolver,
                  onChanged: (value) {
                    setState(() {
                      int index = _ingredientes.indexOf(ingrediente);
                      _ingredientes[index] = ingrediente.copyWith(
                        devolver: value,
                      );
                    });
                  },
                ),
              ],
            ),

            SizedBox(height: 8),

            Text(
              'Cantidad descontada: ${ingrediente.cantidadDescontada} ${ingrediente.unidad}',
              style: TextStyle(color: Colors.grey[600]),
            ),

            if (ingrediente.cantidadADevolver !=
                ingrediente.cantidadDescontada) ...[
              Text(
                'Cantidad a devolver: ${ingrediente.cantidadADevolver} ${ingrediente.unidad}',
                style: TextStyle(color: Colors.blue[600]),
              ),
            ],

            // Motivo de no devolución
            if (!ingrediente.devolver) ...[
              SizedBox(height: 8),
              Text(
                'Motivo de no devolución:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              DropdownButton<String>(
                value: ingrediente.motivoNoDevolucion ?? 'Ya fue preparado',
                isExpanded: true,
                items: _motivosNoDevolucion.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key),
                        Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    int index = _ingredientes.indexOf(ingrediente);
                    _ingredientes[index] = ingrediente.copyWith(
                      motivoNoDevolucion: value,
                    );
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResumen() {
    final ingredientesADevolver = _ingredientes.where((i) => i.devolver).length;
    final ingredientesNoDevolver = _ingredientes
        .where((i) => !i.devolver)
        .length;

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '• $ingredientesADevolver ingredientes se devolverán al inventario',
            ),
            Text('• $ingredientesNoDevolver ingredientes NO se devolverán'),
            SizedBox(height: 12),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isCanceling
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text('Cancelar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                ),
                ElevatedButton(
                  onPressed: _isCanceling ? null : _cancelarProducto,
                  child: _isCanceling
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Procesando...'),
                          ],
                        )
                      : Text('Confirmar cancelación'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
