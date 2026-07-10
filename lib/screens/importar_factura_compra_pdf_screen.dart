import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/factura_compra.dart';
import '../models/factura_compra_pdf_preview.dart';
import '../models/producto.dart';
import '../services/factura_compra_service.dart';
import '../services/producto_service.dart';
import '../providers/datos_cache_provider.dart';
import '../theme/app_theme.dart';
import '../utils/submit_guard.dart';
import '../utils/currency_utils.dart';
import '../utils/snackbar_helper.dart';
import '../utils/datetime_utils.dart';

/// Fila editable de la vista previa: envuelve el ítem parseado del PDF con
/// controladores editables. Nada de esto se persiste hasta confirmar.
class _FilaImportPdf {
  final ItemFacturaPdfPreview original;
  bool incluir = true;
  String destino = 'ALMACÉN';
  final TextEditingController descripcionCtrl;
  final TextEditingController cantidadCtrl;
  final TextEditingController costoCtrl;
  final TextEditingController porcentajeIvaCtrl;
  final TextEditingController precioVentaCtrl;
  final TextEditingController cantidadAlmacenCtrl = TextEditingController();
  final TextEditingController cantidadBodegaCtrl = TextEditingController();

  _FilaImportPdf(this.original)
      : descripcionCtrl = TextEditingController(text: original.descripcion),
        cantidadCtrl = TextEditingController(
          text: original.cantidad.toStringAsFixed(
            original.cantidad == original.cantidad.roundToDouble() ? 0 : 2,
          ),
        ),
        // costoUnitarioNeto ya viene con el descuento del proveedor aplicado
        // (subtotal / cantidad); valorUnitario es el precio de lista bruto.
        costoCtrl = TextEditingController(
          text: original.costoUnitarioNeto.toStringAsFixed(2),
        ),
        porcentajeIvaCtrl = TextEditingController(
          text: original.porcentajeIva.toStringAsFixed(
            original.porcentajeIva == original.porcentajeIva.roundToDouble() ? 0 : 2,
          ),
        ),
        // Para productos nuevos se sugiere un precio (editable). Para
        // productos existentes queda vacío a propósito: si el usuario no lo
        // llena, el precio de venta actual NO se toca.
        precioVentaCtrl = TextEditingController(
          text: original.esNuevo
              ? precioSugerido(original.costoUnitarioNeto).toStringAsFixed(0)
              : '',
        );

  bool get esNuevo => original.esNuevo;

  /// Precio de venta sugerido para un producto nuevo: costo + 49% de margen,
  /// redondeado hacia arriba al siguiente múltiplo de $1.000
  /// (ej. 13.460 → 14.000, 42.500 → 43.000).
  static double precioSugerido(double costo) {
    final conMargen = costo * 1.49;
    return (conMargen / 1000).ceil() * 1000;
  }

  void dispose() {
    descripcionCtrl.dispose();
    cantidadCtrl.dispose();
    costoCtrl.dispose();
    porcentajeIvaCtrl.dispose();
    precioVentaCtrl.dispose();
    cantidadAlmacenCtrl.dispose();
    cantidadBodegaCtrl.dispose();
  }
}

class ImportarFacturaCompraPdfScreen extends StatefulWidget {
  const ImportarFacturaCompraPdfScreen({super.key});

  @override
  State<ImportarFacturaCompraPdfScreen> createState() =>
      _ImportarFacturaCompraPdfScreenState();
}

class _ImportarFacturaCompraPdfScreenState
    extends State<ImportarFacturaCompraPdfScreen> with SubmitGuard {
  final FacturaCompraService _facturaCompraService = FacturaCompraService();
  final ProductoService _productoService = ProductoService();

  String _plantilla = 'AKT';

  static const Map<String, String> _plantillasDisponibles = {
    'AKT': 'AKT Motos',
    'CASSARELLA': 'Cassarella (Integrando S.A.S)',
    'IDLASER': 'IDLASER (Ingeniería y Diseño Laser SAS)',
    'INDUSTRIA_IP': 'Industria IP S.A.S',
    'INVERSIONES_PG': 'Inversiones P&G SAS (Motos y Accesorios)',
  };

  bool _cargandoPreview = false;
  bool _guardando = false;
  FacturaCompraPdfPreview? _preview;
  final List<_FilaImportPdf> _filas = [];

  final _proveedorNombreController = TextEditingController();
  final _proveedorNitController = TextEditingController();
  final _origenCompraController = TextEditingController();
  DateTime _fechaFactura = DateTime.now();
  DateTime _fechaVencimiento = DateTime.now().add(const Duration(days: 30));
  bool _pagadoDesdeCaja = false;
  String _destinoGlobal = 'ALMACÉN';
  List<Producto> _productosParaBusqueda = [];

  @override
  void initState() {
    super.initState();
    _cargarProductosParaBusqueda();
  }

  Future<void> _cargarProductosParaBusqueda() async {
    try {
      final cacheProvider = Provider.of<DatosCacheProvider>(context, listen: false);
      if (cacheProvider.productos != null && cacheProvider.productos!.isNotEmpty) {
        _productosParaBusqueda = cacheProvider.productos!;
      } else {
        _productosParaBusqueda = await _productoService.getProductos();
      }
    } catch (_) {
      // No crítico: si falla, "Agregar ítem" solo permitirá texto libre (producto nuevo).
    }
  }

  @override
  void dispose() {
    _proveedorNombreController.dispose();
    _proveedorNitController.dispose();
    _origenCompraController.dispose();
    for (final fila in _filas) {
      fila.dispose();
    }
    super.dispose();
  }

  Future<void> _seleccionarPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final archivo = result.files.first;
      final bytes = archivo.bytes;
      if (bytes == null) {
        if (mounted) {
          showErrorSnackBar(context, 'No se pudo leer el archivo seleccionado');
        }
        return;
      }

      await _subirYPrevisualizar(bytes, archivo.name);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error al seleccionar el PDF: $e');
      }
    }
  }

  Future<void> _subirYPrevisualizar(Uint8List bytes, String nombreArchivo) async {
    setState(() => _cargandoPreview = true);
    try {
      final preview = await _facturaCompraService.previewImportarPdf(
        bytes,
        plantilla: _plantilla,
        nombreArchivo: nombreArchivo,
      );

      for (final fila in _filas) {
        fila.dispose();
      }
      _filas.clear();
      _filas.addAll(preview.items.map((i) => _FilaImportPdf(i)));

      _proveedorNombreController.text =
          preview.proveedorNombre ?? _plantillasDisponibles[_plantilla] ?? '';
      _proveedorNitController.text = preview.proveedorNit ?? '';
      _fechaFactura = preview.fechaFactura ?? DateTime.now();
      _fechaVencimiento =
          preview.fechaVencimiento ?? DateTime.now().add(const Duration(days: 30));

      setState(() => _preview = preview);

      if (mounted) {
        showSuccessSnackBar(
          context,
          '${preview.items.length} ítems reconocidos. Revisa antes de confirmar.',
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error al interpretar el PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _cargandoPreview = false);
    }
  }

  void _volverASubirOtro() {
    setState(() {
      for (final fila in _filas) {
        fila.dispose();
      }
      _filas.clear();
      _preview = null;
    });
  }

  Future<void> _seleccionarFecha(bool esFechaFactura) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: esFechaFactura ? _fechaFactura : _fechaVencimiento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (fecha != null) {
      setState(() {
        if (esFechaFactura) {
          _fechaFactura = fecha;
        } else {
          _fechaVencimiento = fecha;
        }
      });
    }
  }

  void _aplicarDestinoATodas() {
    setState(() {
      for (final fila in _filas.where((f) => f.incluir)) {
        fila.destino = _destinoGlobal;
      }
    });
    showInfoSnackBar(context, 'Destino aplicado a todas las filas incluidas');
  }

  void _eliminarFila(_FilaImportPdf fila) {
    setState(() {
      fila.dispose();
      _filas.remove(fila);
    });
  }

  /// Diálogo para agregar manualmente un ítem que el PDF no trajo o que no se
  /// pudo interpretar (ver [FacturaCompraPdfPreview.advertencias]). Permite
  /// buscar un producto existente o escribir el nombre de uno nuevo.
  Future<void> _mostrarDialogoAgregarItem() async {
    final nombreCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: '1');
    final costoCtrl = TextEditingController();
    final ivaCtrl = TextEditingController(text: '19');
    String destino = 'ALMACÉN';
    Producto? seleccionado;
    List<Producto> sugerencias = [];

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: cs.surface,
            title: Row(
              children: [
                Icon(Icons.add_circle_outline, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Agregar ítem', style: TextStyle(color: cs.onSurface)),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      style: TextStyle(color: cs.onSurface),
                      decoration: const InputDecoration(
                        labelText: 'Producto (buscar existente o escribir nombre nuevo)',
                      ),
                      onChanged: (v) {
                        seleccionado = null;
                        final q = v.trim().toLowerCase();
                        setDialogState(() {
                          sugerencias = q.length < 2
                              ? []
                              : _productosParaBusqueda
                                  .where((p) => p.nombre.toLowerCase().contains(q))
                                  .take(6)
                                  .toList();
                        });
                      },
                    ),
                    if (sugerencias.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          border: Border.all(color: cs.onSurface.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: sugerencias.map((p) {
                            return ListTile(
                              dense: true,
                              title: Text(p.nombre, style: TextStyle(color: cs.onSurface, fontSize: 13)),
                              subtitle: Text(
                                'Costo actual: ${CurrencyUtils.format(p.costo)}',
                                style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 11),
                              ),
                              onTap: () {
                                seleccionado = p;
                                nombreCtrl.text = p.nombre;
                                costoCtrl.text = p.costo.toStringAsFixed(2);
                                setDialogState(() => sugerencias = []);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    if (seleccionado != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '✅ Coincide con producto existente',
                          style: TextStyle(color: AppTheme.success, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cantidadCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: cs.onSurface),
                            decoration: const InputDecoration(labelText: 'Cantidad'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: costoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: cs.onSurface),
                            decoration: const InputDecoration(labelText: 'Costo unitario'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ivaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: cs.onSurface),
                            decoration: const InputDecoration(labelText: '% IVA'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: destino,
                            decoration: const InputDecoration(labelText: 'Destino'),
                            dropdownColor: cs.surface,
                            style: TextStyle(color: cs.onSurface, fontSize: 13),
                            items: ['ALMACÉN', 'BODEGA']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (v) => setDialogState(() => destino = v ?? 'ALMACÉN'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancelar', style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () {
                  final nombre = nombreCtrl.text.trim();
                  final cantidad = double.tryParse(cantidadCtrl.text) ?? 0;
                  final costo = double.tryParse(costoCtrl.text) ?? 0;
                  final iva = double.tryParse(ivaCtrl.text) ?? 0;

                  if (nombre.isEmpty) {
                    showWarningSnackBar(context, 'Escribe o selecciona un producto');
                    return;
                  }
                  if (cantidad <= 0) {
                    showWarningSnackBar(context, 'Cantidad inválida');
                    return;
                  }
                  if (costo <= 0) {
                    showWarningSnackBar(context, 'Costo unitario inválido');
                    return;
                  }

                  final item = ItemFacturaPdfPreview(
                    plu: 'MANUAL',
                    codigoInterno: seleccionado?.codigo,
                    codigoBarras: seleccionado?.codigoBarras,
                    descripcion: nombre,
                    cantidad: cantidad,
                    valorUnitario: costo,
                    costoUnitarioNeto: costo,
                    porcentajeIva: iva,
                    valorIva: costo * cantidad * (iva / 100),
                    subtotal: costo * cantidad,
                    valorTotal: costo * cantidad * (1 + iva / 100),
                    esNuevo: seleccionado == null,
                    productoId: seleccionado?.id,
                    productoNombreActual: seleccionado?.nombre,
                    costoActual: seleccionado?.costo,
                    precioActual: seleccionado?.precio,
                    cantidadAlmacen: seleccionado?.almacen,
                    cantidadBodega: seleccionado?.bodega,
                    controlInventario: true,
                  );

                  setState(() {
                    final fila = _FilaImportPdf(item);
                    fila.destino = destino;
                    _filas.add(fila);
                  });

                  Navigator.pop(dialogContext);
                  showSuccessSnackBar(context, 'Ítem agregado');
                },
                child: const Text('Agregar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );

    nombreCtrl.dispose();
    cantidadCtrl.dispose();
    costoCtrl.dispose();
    ivaCtrl.dispose();
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  /// Base gravable (sin IVA): suma de cantidad × costo de las filas incluidas.
  double get _totalSubtotal {
    double total = 0;
    for (final fila in _filas.where((f) => f.incluir)) {
      final cantidad = double.tryParse(fila.cantidadCtrl.text) ?? 0;
      final costo = double.tryParse(fila.costoCtrl.text) ?? 0;
      total += cantidad * costo;
    }
    return total;
  }

  /// Suma del IVA de todas las filas incluidas.
  double get _totalIva {
    double total = 0;
    for (final fila in _filas.where((f) => f.incluir)) {
      final cantidad = double.tryParse(fila.cantidadCtrl.text) ?? 0;
      final costo = double.tryParse(fila.costoCtrl.text) ?? 0;
      final ivaPct = double.tryParse(fila.porcentajeIvaCtrl.text) ?? 0;
      total += cantidad * costo * (ivaPct / 100);
    }
    return total;
  }

  /// Total con IVA: es el valor final que se guarda como total de la factura.
  double get _totalConIva => _totalSubtotal + _totalIva;

  int get _countNuevos =>
      _filas.where((f) => f.incluir && f.esNuevo).length;

  int get _countExistentes =>
      _filas.where((f) => f.incluir && !f.esNuevo).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Importar factura de compra (PDF)',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/compras'),
        ),
        actions: [
          if (_preview != null)
            TextButton.icon(
              onPressed: _guardando ? null : _volverASubirOtro,
              icon: const Icon(Icons.upload_file),
              label: const Text('Subir otro PDF'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _preview == null ? _buildPasoSubida() : _buildPasoRevision(),
    );
  }

  // ─── Paso 1: subir PDF ──────────────────────────────────────────────────

  Widget _buildPasoSubida() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, color: AppTheme.primary, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Plantilla',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _plantilla,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      items: _plantillasDisponibles.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _plantilla = v ?? 'AKT'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sube la factura de compra en PDF de ${_plantillasDisponibles[_plantilla]}. '
                  'Vas a poder revisar y editar cada línea antes de crear la compra.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                _cargandoPreview
                    ? Column(
                        children: [
                          CircularProgressIndicator(color: AppTheme.primary),
                          const SizedBox(height: 12),
                          Text(
                            'Interpretando PDF...',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ],
                      )
                    : ElevatedButton.icon(
                        onPressed: _seleccionarPdf,
                        icon: const Icon(Icons.upload_file, color: Colors.white),
                        label: const Text('Seleccionar PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Paso 2: revisión y confirmación ────────────────────────────────────

  Widget _buildPasoRevision() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_preview!.advertencias.isNotEmpty) _buildAdvertenciasBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildBulkDestinoRow(),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _mostrarDialogoAgregarItem,
                  icon: Icon(Icons.add_circle_outline, color: AppTheme.primary),
                  label: Text('Agregar ítem manualmente', style: TextStyle(color: AppTheme.primary)),
                ),
              ),
              const SizedBox(height: 8),
              ..._filas.asMap().entries.map((e) => _buildFilaCard(e.value)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.onSurface.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Base gravable: ${CurrencyUtils.format(_totalSubtotal)}   ·   '
                      'IVA: ${CurrencyUtils.format(_totalIva)}',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 12),
                    ),
                    Text(
                      'Total: ${CurrencyUtils.format(_totalConIva)}   ·   '
                      '$_countExistentes existentes  ·  $_countNuevos nuevos',
                      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _guardando ? null : () => runGuarded(_confirmarCompra),
                icon: _guardando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, color: Colors.white),
                label: Text(_guardando ? 'Creando compra...' : 'Confirmar y crear compra'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvertenciasBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppTheme.warning.withOpacity(0.15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_preview!.advertencias.length} línea(s) del PDF no se pudieron '
              'interpretar y no aparecen abajo. Agrégalas manualmente si aplica:\n'
              '${_preview!.advertencias.join('\n')}',
              style: TextStyle(color: AppTheme.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datos de la factura',
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (_preview!.numeroFacturaProveedor != null) ...[
              const SizedBox(height: 4),
              Text(
                'Factura proveedor N° ${_preview!.numeroFacturaProveedor}',
                style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _proveedorNombreController,
                    style: TextStyle(color: cs.onSurface),
                    decoration: const InputDecoration(labelText: 'Proveedor'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _proveedorNitController,
                    style: TextStyle(color: cs.onSurface),
                    decoration: const InputDecoration(labelText: 'NIT proveedor'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _seleccionarFecha(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Fecha factura'),
                      child: Text(_formatearFecha(_fechaFactura), style: TextStyle(color: cs.onSurface)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _seleccionarFecha(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Vencimiento'),
                      child: Text(_formatearFecha(_fechaVencimiento), style: TextStyle(color: cs.onSurface)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pagadoDesdeCaja,
              activeColor: AppTheme.success,
              title: Text('Pagado desde caja', style: TextStyle(color: cs.onSurface)),
              onChanged: (v) => setState(() => _pagadoDesdeCaja = v),
            ),
            if (!_pagadoDesdeCaja)
              TextField(
                controller: _origenCompraController,
                style: TextStyle(color: cs.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Origen de la compra',
                  hintText: 'Ej: Transferencia, Sistecrédito, etc.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkDestinoRow() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text('Destino para todas: ', style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _destinoGlobal,
          dropdownColor: cs.surface,
          style: TextStyle(color: cs.onSurface),
          items: ['ALMACÉN', 'BODEGA', 'PARTE Y PARTE']
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _destinoGlobal = v ?? 'ALMACÉN'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _aplicarDestinoATodas,
          child: const Text('Aplicar a todas'),
        ),
      ],
    );
  }

  Widget _buildFilaCard(_FilaImportPdf fila) {
    final cs = Theme.of(context).colorScheme;
    final cantidad = double.tryParse(fila.cantidadCtrl.text) ?? 0;
    final costo = double.tryParse(fila.costoCtrl.text) ?? 0;
    final ivaPct = double.tryParse(fila.porcentajeIvaCtrl.text) ?? 0;
    final subtotal = cantidad * costo;
    final valorIva = subtotal * (ivaPct / 100);
    final totalConIva = subtotal + valorIva;

    return Opacity(
      opacity: fila.incluir ? 1 : 0.5,
      child: Card(
        color: cs.surface,
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: fila.incluir,
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setState(() => fila.incluir = v ?? true),
                  ),
                  _buildEstadoChip(fila),
                  const Spacer(),
                  Text(
                    'Código: ${fila.original.codigoBarras ?? fila.original.codigoInterno ?? fila.original.plu}',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 11),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                    tooltip: 'Eliminar ítem',
                    onPressed: () => _eliminarFila(fila),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: fila.descripcionCtrl,
                enabled: fila.incluir,
                style: TextStyle(color: cs.onSurface),
                decoration: const InputDecoration(labelText: 'Descripción / nombre del producto'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fila.cantidadCtrl,
                      enabled: fila.incluir,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: cs.onSurface),
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fila.costoCtrl,
                      enabled: fila.incluir,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Costo unitario',
                        helperText: fila.original.porcentajeDescuento > 0
                            ? 'Lista: ${CurrencyUtils.format(fila.original.valorUnitario)}'
                                ' − ${fila.original.porcentajeDescuento.toStringAsFixed(0)}% desc. proveedor'
                            : null,
                        helperMaxLines: 2,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Subtotal'),
                      child: Text(CurrencyUtils.format(subtotal), style: TextStyle(color: cs.onSurface)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fila.porcentajeIvaCtrl,
                      enabled: fila.incluir,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: cs.onSurface),
                      decoration: const InputDecoration(labelText: '% IVA'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Valor IVA'),
                      child: Text(CurrencyUtils.format(valorIva), style: TextStyle(color: cs.onSurface)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Total con IVA'),
                      child: Text(
                        CurrencyUtils.format(totalConIva),
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              if (fila.esNuevo) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: fila.precioVentaCtrl,
                  enabled: fila.incluir,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: cs.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Precio de venta (producto nuevo)',
                    helperText: 'Sugerido, edítalo antes de confirmar',
                  ),
                ),
              ] else ...[
                if (fila.original.costoActual != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Costo actual: ${CurrencyUtils.format(fila.original.costoActual!)} → nuevo: ${CurrencyUtils.format(costo)}'
                    '   |   Stock: ALM ${fila.original.cantidadAlmacen ?? 0} / BOD ${fila.original.cantidadBodega ?? 0}',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: fila.precioVentaCtrl,
                  enabled: fila.incluir,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Nuevo precio de venta (opcional)',
                    helperText: fila.original.precioActual != null
                        ? 'Vacío = no cambia (actual: ${CurrencyUtils.format(fila.original.precioActual!)})'
                        : 'Vacío = no cambia el precio de venta',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: fila.destino,
                      decoration: const InputDecoration(labelText: 'Destino'),
                      dropdownColor: cs.surface,
                      style: TextStyle(color: cs.onSurface, fontSize: 13),
                      items: ['ALMACÉN', 'BODEGA', 'PARTE Y PARTE']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: fila.incluir
                          ? (v) => setState(() => fila.destino = v ?? 'ALMACÉN')
                          : null,
                    ),
                  ),
                  if (fila.destino == 'PARTE Y PARTE') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fila.cantidadAlmacenCtrl,
                        enabled: fila.incluir,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: cs.onSurface),
                        decoration: const InputDecoration(labelText: 'Cant. almacén'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fila.cantidadBodegaCtrl,
                        enabled: fila.incluir,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: cs.onSurface),
                        decoration: const InputDecoration(labelText: 'Cant. bodega'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoChip(_FilaImportPdf fila) {
    final color = fila.esNuevo ? AppTheme.warning : AppTheme.success;
    final texto = fila.esNuevo ? '🆕 Producto nuevo' : '✅ Producto existente';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  // ─── Confirmar ───────────────────────────────────────────────────────────

  Future<void> _confirmarCompra() async {
    final filasIncluidas = _filas.where((f) => f.incluir).toList();
    if (filasIncluidas.isEmpty) {
      showWarningSnackBar(context, 'Selecciona al menos un ítem para crear la compra');
      return;
    }

    // Validación previa de cada fila incluida
    for (final fila in filasIncluidas) {
      final cantidad = double.tryParse(fila.cantidadCtrl.text) ?? 0;
      final costo = double.tryParse(fila.costoCtrl.text) ?? 0;
      if (fila.descripcionCtrl.text.trim().isEmpty) {
        showErrorSnackBar(context, 'Hay un ítem sin descripción/nombre');
        return;
      }
      if (cantidad <= 0) {
        showErrorSnackBar(context, 'Cantidad inválida en "${fila.descripcionCtrl.text}"');
        return;
      }
      if (costo <= 0) {
        showErrorSnackBar(context, 'Costo unitario inválido en "${fila.descripcionCtrl.text}"');
        return;
      }
      if (fila.esNuevo && (double.tryParse(fila.precioVentaCtrl.text) ?? 0) <= 0) {
        showErrorSnackBar(context, 'Precio de venta inválido en "${fila.descripcionCtrl.text}"');
        return;
      }
      // Para productos existentes el precio nuevo es opcional, pero si se
      // escribió algo debe ser un número válido (para no ignorar un typo en
      // silencio).
      if (!fila.esNuevo && fila.precioVentaCtrl.text.trim().isNotEmpty) {
        final nuevoPrecio = double.tryParse(fila.precioVentaCtrl.text.trim());
        if (nuevoPrecio == null || nuevoPrecio <= 0) {
          showErrorSnackBar(
            context,
            'El nuevo precio de venta en "${fila.descripcionCtrl.text}" no es un número válido',
          );
          return;
        }
      }
      if (fila.destino == 'PARTE Y PARTE') {
        final ca = double.tryParse(fila.cantidadAlmacenCtrl.text) ?? 0;
        final cb = double.tryParse(fila.cantidadBodegaCtrl.text) ?? 0;
        if ((ca + cb - cantidad).abs() > 0.01) {
          showErrorSnackBar(
            context,
            'En "${fila.descripcionCtrl.text}" la suma de almacén + bodega debe ser igual a la cantidad',
          );
          return;
        }
      }
    }

    setState(() => _guardando = true);
    int creados = 0;
    int actualizados = 0;
    final List<ItemFacturaCompra> items = [];
    final List<_FilaImportPdf> filasParaActualizarCosto = [];

    try {
      for (final fila in filasIncluidas) {
        final cantidad = double.tryParse(fila.cantidadCtrl.text) ?? 0;
        final costo = double.tryParse(fila.costoCtrl.text) ?? 0;
        final nombre = fila.descripcionCtrl.text.trim();

        String productoId;
        String productoNombre;

        if (fila.esNuevo) {
          final precioVenta = double.tryParse(fila.precioVentaCtrl.text) ?? costo;
          final nuevo = Producto(
            id: '',
            nombre: nombre,
            precio: precioVenta,
            costo: costo,
            utilidad: precioVenta - costo,
            codigoBarras: fila.original.codigoBarras,
            controlInventario: 'SI',
            estado: 'Activo',
            tipoProducto: 'individual',
          );
          final creado = await _productoService.addProducto(nuevo);
          productoId = creado.id;
          productoNombre = creado.nombre;
          creados++;
        } else {
          productoId = fila.original.productoId!;
          productoNombre = fila.original.productoNombreActual ?? nombre;
          filasParaActualizarCosto.add(fila);
          actualizados++;
        }

        double cantidadAlmacen = 0;
        double cantidadBodega = 0;
        if (fila.destino == 'BODEGA') {
          cantidadBodega = cantidad;
        } else if (fila.destino == 'PARTE Y PARTE') {
          cantidadAlmacen = double.tryParse(fila.cantidadAlmacenCtrl.text) ?? 0;
          cantidadBodega = double.tryParse(fila.cantidadBodegaCtrl.text) ?? 0;
        } else {
          cantidadAlmacen = cantidad;
        }

        final porcentajeIva = double.tryParse(fila.porcentajeIvaCtrl.text) ?? 0;
        final subtotal = cantidad * costo;
        final valorImpuesto = subtotal * (porcentajeIva / 100);

        items.add(ItemFacturaCompra(
          ingredienteId: productoId,
          ingredienteNombre: productoNombre,
          cantidad: cantidad,
          unidad: 'UND',
          precioUnitario: costo,
          subtotal: subtotal,
          porcentajeImpuesto: porcentajeIva,
          valorImpuesto: valorImpuesto,
          destino: fila.destino,
          cantidadAlmacen: cantidadAlmacen,
          cantidadBodega: cantidadBodega,
        ));
      }

      // El valor final que se guarda en la factura es el total CON IVA (base
      // gravable + impuestos), no solo la base gravable.
      final subtotalItems = items.fold<double>(0, (sum, item) => sum + item.subtotal);
      final totalImpuestosItems = items.fold<double>(0, (sum, item) => sum + item.valorImpuesto);
      final totalConIva = subtotalItems + totalImpuestosItems;

      final now = DateTime.now();
      final numeroFactura =
          'C-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      final descripcionPartes = <String>[];
      if (_preview?.numeroFacturaProveedor != null) {
        descripcionPartes.add(
          'Factura proveedor ${_plantillasDisponibles[_plantilla] ?? _plantilla} No. ${_preview!.numeroFacturaProveedor}',
        );
      }
      if (!_pagadoDesdeCaja) {
        descripcionPartes.add(
          'Origen: ${_origenCompraController.text.isNotEmpty ? _origenCompraController.text : 'No especificado'}',
        );
      }

      final factura = FacturaCompra(
        numeroFactura: numeroFactura,
        proveedorNit: _proveedorNitController.text.trim().isEmpty
            ? null
            : _proveedorNitController.text.trim(),
        proveedorNombre: _proveedorNombreController.text.trim().isEmpty
            ? null
            : _proveedorNombreController.text.trim(),
        fechaFactura: _fechaFactura,
        fechaVencimiento: _fechaVencimiento,
        // El total final de la factura incluye el IVA (no solo la base gravable).
        total: totalConIva,
        estado: _pagadoDesdeCaja ? 'PENDIENTE' : 'PROCESADA',
        pagadoDesdeCaja: _pagadoDesdeCaja,
        items: items,
        descripcion: descripcionPartes.isEmpty ? null : descripcionPartes.join(' · '),
        fechaCreacion: DateTimeUtils.nowColombia(),
        fechaActualizacion: DateTimeUtils.nowColombia(),
        subtotal: subtotalItems,
        baseGravable: subtotalItems,
        totalImpuestos: totalImpuestosItems,
      );

      await _facturaCompraService.crearFacturaCompra(factura);

      // Actualizar el costo (y opcionalmente el precio de venta) de los
      // productos que ya existían (mismo patrón que
      // CrearFacturaCompraScreen._actualizarCostoProductos). Si el campo de
      // "nuevo precio de venta" quedó vacío, se reenvía el precio actual sin
      // cambios.
      for (final fila in filasParaActualizarCosto) {
        final costo = double.tryParse(fila.costoCtrl.text) ?? 0;
        final nuevoPrecioTexto = fila.precioVentaCtrl.text.trim();
        final nuevoPrecio =
            nuevoPrecioTexto.isEmpty ? null : double.tryParse(nuevoPrecioTexto);
        final precioAEnviar = (nuevoPrecio != null && nuevoPrecio > 0)
            ? nuevoPrecio
            : fila.original.precioActual;

        if (costo > 0 && fila.original.productoId != null) {
          try {
            await _productoService.actualizarCostoProducto(
              fila.original.productoId!,
              costo,
              precioActual: precioAEnviar,
            );
          } catch (_) {
            // No crítico: la compra ya se creó, seguir con las demás.
          }
        }
      }

      if (mounted) {
        try {
          final cacheProvider = Provider.of<DatosCacheProvider>(context, listen: false);
          await cacheProvider.forceRefreshProductos();
        } catch (_) {}
      }

      if (mounted) {
        showSuccessSnackBar(
          context,
          'Compra creada: $creados producto(s) nuevo(s), $actualizados actualizado(s)',
        );
        context.go('/compras');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error al crear la compra: $e');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}
