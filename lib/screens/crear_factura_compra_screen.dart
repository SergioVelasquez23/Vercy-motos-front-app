import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../utils/submit_guard.dart';
import '../models/factura_compra.dart';
import '../models/proveedor.dart';
import '../models/producto.dart';
import '../services/factura_compra_service.dart';
import '../services/proveedor_service.dart';
import '../services/producto_service.dart';
import '../providers/datos_cache_provider.dart';
import '../theme/app_theme.dart';
import '../utils/busqueda_productos_utils.dart';
import '../utils/currency_utils.dart';
import '../utils/logger.dart';
import '../utils/datetime_utils.dart';
import '../utils/api_error.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/compras/field_label.dart';
import '../widgets/compras/descripcion_y_retenciones_compacto.dart';
import '../widgets/compras/resumen_compra_lateral.dart';

class CrearFacturaCompraScreen extends StatefulWidget {
  final FacturaCompra? facturaParaEditar;

  const CrearFacturaCompraScreen({Key? key, this.facturaParaEditar})
    : super(key: key);

  @override
  _CrearFacturaCompraScreenState createState() =>
      _CrearFacturaCompraScreenState();
}

class _CrearFacturaCompraScreenState extends State<CrearFacturaCompraScreen> with SubmitGuard {
  final _formKey = GlobalKey<FormState>();
  final FacturaCompraService _facturaCompraService = FacturaCompraService();
  final ProveedorService _proveedorService = ProveedorService();
  final ProductoService _productoService = ProductoService();

  final _proveedorNitController = TextEditingController();
  final _proveedorNombreController = TextEditingController();
  final _descripcionController = TextEditingController();

  // 💰 Controladores DIAN para retenciones
  final _porcentajeRetencionController = TextEditingController(text: '0');
  final _porcentajeReteIvaController = TextEditingController(text: '0');
  final _porcentajeReteIcaController = TextEditingController(text: '0');

  // Descuento general
  final _descuentoGeneralValorController = TextEditingController(text: '0');
  String _tipoDescuentoGeneral = 'Porcentaje'; // 'Porcentaje' o 'Valor'

  // Controladores para agregar producto
  final _codigoProductoController = TextEditingController();
  final _nombreProductoController = TextEditingController();
  final _cantidadProductoController = TextEditingController();
  final _valorUnitarioController = TextEditingController();
  final _porcentajeImpuestoController = TextEditingController(text: '19');
  final _porcentajeDescuentoController = TextEditingController(text: '0');
  // 📦 Controladores para PARTE Y PARTE
  final _cantidadAlmacenController = TextEditingController();
  final _cantidadBodegaController = TextEditingController();
  
  // Campo para guardar desde donde salió la compra (transferencia, sistecredito, etc)
  final _origenCompraController = TextEditingController();
  
  String _tipoImpuesto = 'IVA';
  String _tipoDescuento = '%';
  Producto? _productoSeleccionado;
  String _destinoSeleccionado = 'ALMACÉN'; // 📦 BODEGA, ALMACÉN o PARTE Y PARTE

  DateTime _fechaFactura = DateTime.now();
  DateTime _fechaVencimiento = DateTime.now().add(Duration(days: 30));
  final List<ItemFacturaCompra> _items = [];
  List<Proveedor> _proveedores = [];
  List<Producto> _productos = [];
  Proveedor? _proveedorSeleccionado;
  bool _isLoading = false;
  bool _pagadoDesdeCaja = false;

  // Variable para controlar el timeout del botón guardar factura
  bool _guardandoFactura = false;
  String? _numeroFactura;
  bool _modoEdicion = false;

  // Estados de carga para productos y proveedores
  bool _cargandoProductos = true;

  @override
  void initState() {
    super.initState();
    _modoEdicion = widget.facturaParaEditar != null;
    if (_modoEdicion) {
      _cargarDatosFacturaParaEditar();
    } else {
      _generarNumeroFactura();
    }
    _cargarProductos();
    _cargarProveedores();
  }

  void _cargarDatosFacturaParaEditar() {
    final factura = widget.facturaParaEditar!;
    _numeroFactura = factura.numeroFactura;
    _proveedorNombreController.text = factura.proveedorNombre;
    _proveedorNitController.text = factura.proveedorNit ?? '';
    _fechaFactura = factura.fechaFactura;
    _fechaVencimiento =
        factura.fechaVencimiento ?? DateTime.now().add(Duration(days: 30));
    _pagadoDesdeCaja = factura.pagadoDesdeCaja;
    
    // Cargar descripción y origen
    if (factura.descripcion != null) {
      if (factura.descripcion!.startsWith('Origen:')) {
        // Extraer el origen de la descripción
        _origenCompraController.text = factura.descripcion!.replaceFirst(
          'Origen: ',
          '',
        );
      } else {
        _descripcionController.text = factura.descripcion!;
      }
    }

    // Cargar items
    _items.clear();
    _items.addAll(factura.items);

    setState(() {});
  }

  @override
  void dispose() {
    _proveedorNitController.dispose();
    _proveedorNombreController.dispose();
    _descripcionController.dispose();
    _porcentajeRetencionController.dispose();
    _porcentajeReteIvaController.dispose();
    _porcentajeReteIcaController.dispose();
    _descuentoGeneralValorController.dispose();
    _codigoProductoController.dispose();
    _nombreProductoController.dispose();
    _cantidadProductoController.dispose();
    _valorUnitarioController.dispose();
    _porcentajeImpuestoController.dispose();
    _porcentajeDescuentoController.dispose();
    _origenCompraController.dispose();
    _cantidadAlmacenController.dispose();
    _cantidadBodegaController.dispose();
    super.dispose();
  }

  void _generarNumeroFactura() {
    final now = DateTime.now();
    final numero =
        'C-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    setState(() => _numeroFactura = numero);
  }

  Future<void> _cargarProductos() async {
    try {
      // Obtener productos desde el provider de cache primero
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );

      if (cacheProvider.productos != null &&
          cacheProvider.productos!.isNotEmpty) {
        // ✅ El cache está disponible - asignar sin setState innecesarios
        _productos = cacheProvider.productos!;
        if (mounted) {
          setState(
            () => _cargandoProductos = false,
          ); // Solo actualizar estado de carga
        }
      } else {
        // Si no hay productos en cache, cargarlos del servicio
        if (mounted) setState(() => _cargandoProductos = true);
        final productos = await _productoService.getProductos();
        if (mounted) {
          setState(() {
            _productos = productos;
            _cargandoProductos = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoProductos = false);
      }
    }
  }

  Future<void> _cargarProveedores() async {
    try {
      final proveedores = await _proveedorService.getProveedores();
      if (mounted) {
        setState(() {
          _proveedores = proveedores;
        });
      }
    } catch (e) {
      // Ignorar error: si falla, _proveedores queda vacío/como estaba
    }
  }

  Future<void> _mostrarDialogoCrearProducto() async {
    final nombreController = TextEditingController();
    final codigoController = TextEditingController();
    final precioController = TextEditingController();
    final costoController = TextEditingController();
    final cantidadController = TextEditingController(text: '0');
    final descripcionController = TextEditingController();
    final codigoBarrasController = TextEditingController();
    final categoriaController = TextEditingController();
    final marcaController = TextEditingController();
    final ubicacionController = TextEditingController();
    final impuestosController = TextEditingController(text: '19');
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.add_shopping_cart, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Crear Nuevo Producto',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre
                  TextField(
                    controller: nombreController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Nombre del producto *',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Código y Código de barras
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codigoController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Código (opcional)',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: codigoBarrasController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Código barras',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Costo y Precio
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costoController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Costo *',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            prefixText: '\$ ',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: precioController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Precio venta *',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            prefixText: '\$ ',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Cantidad inicial
                  TextField(
                    controller: cantidadController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Cantidad inicial',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Cantidad y % Impuesto
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cantidadController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Cantidad',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: impuestosController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: '% Impuesto',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Categoría, Marca, Ubicación
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: categoriaController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Categoría',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: marcaController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Marca',
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Ubicación
                  TextField(
                    controller: ubicacionController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Ubicación/Localización',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Descripción
                  TextField(
                    controller: descripcionController,
                    maxLines: 2,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Descripción (opcional)',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(dialogContext),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            ElevatedButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (nombreController.text.isEmpty) {
                        showInfoSnackBar(context, 'El nombre es obligatorio');
                        return;
                      }
                      if (costoController.text.isEmpty ||
                          precioController.text.isEmpty) {
                        showInfoSnackBar(context, 'El costo y precio son obligatorios');
                        return;
                      }

                      setDialogState(() => guardando = true);

                      try {
                        final precio = double.parse(precioController.text);
                        final costo = double.parse(costoController.text);
                        final utilidad = precio - costo;
                        final cantidad =
                            int.tryParse(cantidadController.text) ?? 0;
                        final impuestos =
                            double.tryParse(impuestosController.text) ?? 19;

                        final nuevoProducto = Producto(
                          id: '',
                          nombre: nombreController.text.trim(),
                          codigo: codigoController.text.isNotEmpty
                              ? codigoController.text.trim()
                              : null,
                          codigoBarras: codigoBarrasController.text.isNotEmpty
                              ? codigoBarrasController.text.trim()
                              : null,
                          precio: precio,
                          costo: costo,
                          utilidad: utilidad,
                          cantidad: cantidad,
                          descripcion: descripcionController.text.isNotEmpty
                              ? descripcionController.text.trim()
                              : null,
                          categoria: null, // Sin categoría por ahora
                          marca: marcaController.text.isNotEmpty
                              ? marcaController.text.trim()
                              : null,
                          localizacion: ubicacionController.text.isNotEmpty
                              ? ubicacionController.text.trim()
                              : null,
                          porcentajeImpuesto: impuestos,
                          estado: 'Activo',
                        );

                        final productoCreado = await _productoService
                            .addProducto(nuevoProducto);

                        // � AGREGAR DIRECTAMENTE a la lista EXISTENTE (sin refetch!)
                        if (mounted) {
                          final cacheProvider = Provider.of<DatosCacheProvider>(
                            context,
                            listen: false,
                          );

                          // 1️⃣ Agregar a lista local - CREAR NUEVA LISTA
                          setState(() {
                            // Crear una nueva lista con el producto al inicio
                            _productos = [productoCreado, ..._productos];
                            _productoSeleccionado = productoCreado;
                            _codigoProductoController.text =
                                productoCreado.codigo ?? productoCreado.id;
                            _nombreProductoController.text =
                                productoCreado.nombre;
                            _valorUnitarioController.text = productoCreado.costo
                                .toString();
                          });

                          // 2️⃣ Actualizar TAMBIÉN el Provider para next time
                          cacheProvider.agregarProductoAlCache(productoCreado);
                        }

                        Navigator.pop(dialogContext);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ Producto creado: ${productoCreado.nombre}',
                            ),
                            backgroundColor: AppTheme.success,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => guardando = false);
                        showErrorSnackBar(context, 'Error al crear producto: ${errorMessage(e)}');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
              child: guardando
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _modoEdicion ? 'Editar compra' : 'Crear compra',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/compras'),
        ),
        actions: [
          // Botón Compras en borrador
          TextButton(
            onPressed: _verBorradores,
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Compras en borrador',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 900;

                  if (isWideScreen) {
                    // Layout de dos columnas para pantallas grandes
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna izquierda - Formulario
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFechasYProveedor(),
                                SizedBox(height: 24),
                                _buildDatosProducto(),
                                SizedBox(height: 24),
                                DescripcionYRetencionesCompacto(
                            descripcionController: _descripcionController,
                            porcentajeRetencionController: _porcentajeRetencionController,
                            porcentajeReteIvaController: _porcentajeReteIvaController,
                            porcentajeReteIcaController: _porcentajeReteIcaController,
                            onRetencionChanged: () => setState(() {}),
                          ),
                                SizedBox(height: 24),
                                _buildBotones(),
                              ],
                            ),
                          ),
                        ),
                        // Columna derecha - Resumen
                        Container(
                          width: 350,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(24),
                            child: ResumenCompraLateral(
                              items: _items,
                              descuentoGeneralValorController: _descuentoGeneralValorController,
                              tipoDescuentoGeneral: _tipoDescuentoGeneral,
                              onTipoDescuentoGeneralChanged: (v) => setState(() => _tipoDescuentoGeneral = v),
                              onDescuentoGeneralChanged: () => setState(() {}),
                              porcentajeRetencionController: _porcentajeRetencionController,
                              porcentajeReteIvaController: _porcentajeReteIvaController,
                              porcentajeReteIcaController: _porcentajeReteIcaController,
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Layout de una columna para móviles
                    return SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFechasYProveedor(),
                          SizedBox(height: 20),
                          _buildDatosProducto(),
                          SizedBox(height: 20),
                          DescripcionYRetencionesCompacto(
                            descripcionController: _descripcionController,
                            porcentajeRetencionController: _porcentajeRetencionController,
                            porcentajeReteIvaController: _porcentajeReteIvaController,
                            porcentajeReteIcaController: _porcentajeReteIcaController,
                            onRetencionChanged: () => setState(() {}),
                          ),
                          SizedBox(height: 20),
                          ResumenCompraLateral(
                              items: _items,
                              descuentoGeneralValorController: _descuentoGeneralValorController,
                              tipoDescuentoGeneral: _tipoDescuentoGeneral,
                              onTipoDescuentoGeneralChanged: (v) => setState(() => _tipoDescuentoGeneral = v),
                              onDescuentoGeneralChanged: () => setState(() {}),
                              porcentajeRetencionController: _porcentajeRetencionController,
                              porcentajeReteIvaController: _porcentajeReteIvaController,
                              porcentajeReteIcaController: _porcentajeReteIcaController,
                            ),
                          SizedBox(height: 20),
                          _buildBotones(),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
    );
  }

  // Nuevo: Fechas y Proveedor en formato compacto como en la imagen
  Widget _buildFechasYProveedor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: Fecha y Vencimiento
        Row(
          children: [
            // Fecha
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Fecha',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _seleccionarFecha(context, true),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatearFechaISO(_fechaFactura),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 32),
            // Vencimiento
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Vencimiento',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _seleccionarFecha(context, false),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatearFechaISO(_fechaVencimiento),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        // Fila 2: Proveedor y Factura
        Row(
          children: [
            // Proveedor
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Proveedor',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Autocomplete<Proveedor>(
                      displayStringForOption: (p) => p.nombre,
                      optionsBuilder: (TextEditingValue value) {
                        if (value.text.isEmpty) return _proveedores;
                        final q = value.text.toLowerCase();
                        return _proveedores.where((p) =>
                          p.nombre.toLowerCase().contains(q) ||
                          (p.documento ?? '').toLowerCase().contains(q),
                        );
                      },
                      onSelected: (Proveedor valor) {
                        setState(() {
                          _proveedorSeleccionado = valor;
                          _proveedorNitController.text = valor.documento ?? '';
                          _proveedorNombreController.text = valor.nombre;
                        });
                      },
                      fieldViewBuilder: (context, ctrl, focusNode, onSubmit) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_proveedorSeleccionado != null && ctrl.text.isEmpty) {
                            ctrl.text = _proveedorSeleccionado!.nombre;
                          }
                        });
                        return TextField(
                          controller: ctrl,
                          focusNode: focusNode,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                            ),
                            hintText: 'Buscar proveedor...',
                            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                            prefixIcon: Icon(Icons.search, color: AppTheme.primary, size: 18),
                            suffixIcon: ctrl.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                    onPressed: () {
                                      ctrl.clear();
                                      setState(() {
                                        _proveedorSeleccionado = null;
                                        _proveedorNitController.clear();
                                        _proveedorNombreController.clear();
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 32),
            // Factura (número)
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Factura',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _numeroFactura ?? 'Generando...',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        // Toggle de Pago desde Caja (VISIBLE Y PROMINENTE)
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _pagadoDesdeCaja
                ? Colors.green.withOpacity(0.15)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _pagadoDesdeCaja
                  ? Colors.green.withOpacity(0.5)
                  : Colors.orange.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _pagadoDesdeCaja ? Icons.check_circle : Icons.warning_amber,
                color: _pagadoDesdeCaja ? Colors.green : Colors.orange,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagado desde Caja',
                      style: TextStyle(
                        color: _pagadoDesdeCaja ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _pagadoDesdeCaja
                          ? 'Esta compra se descontara del efectivo de la caja'
                          : 'Esta compra NO afectara el flujo de caja del dia',
                      style: TextStyle(
                        color: _pagadoDesdeCaja
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _pagadoDesdeCaja,
                onChanged: (value) {
                  setState(() {
                    _pagadoDesdeCaja = value;
                  });
                },
                activeColor: Colors.green,
                activeTrackColor: Colors.green.withOpacity(0.3),
                inactiveThumbColor: Colors.orange,
                inactiveTrackColor: Colors.orange.withOpacity(0.3),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // Campo de Origen de Compra (solo se muestra cuando NO paga desde caja)
        if (!_pagadoDesdeCaja)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Origen de la Compra',
                  style: TextStyle(
                    color: Colors.blue.shade300,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _origenCompraController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText:
                        'Ej: Transferencia, Sistecredito, Efectivo en mano, etc.',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Nuevo: Sección Datos Producto como en la imagen
  Widget _buildDatosProducto() {
    // Calcular valor total del producto actual
    final cantidad = double.tryParse(_cantidadProductoController.text) ?? 0;
    final valorUnitario = double.tryParse(_valorUnitarioController.text) ?? 0;
    final valorTotal = cantidad * valorUnitario;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Datos Producto',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        // Fila 1: Código de Barras
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Text(
                'Código de Barras',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextField(
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    hintText: 'Escanear o ingresar código',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (value) {
                    // Buscar producto por código de barras
                    final producto = _productos
                        .where((p) => p.id == value)
                        .firstOrNull;
                    if (producto != null) {
                      setState(() {
                        _productoSeleccionado = producto;
                        _codigoProductoController.text = producto.id;
                        _nombreProductoController.text = producto.nombre;
                        _valorUnitarioController.text = producto.precio
                            .toString();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        // Fila 2: Código, Nombre, Cantidad, Valor unitario
        Row(
          children: [
            FieldLabel('Código', flex: 1),
            FieldLabel('Nombre producto', flex: 3),
            FieldLabel('Cantidad', flex: 1),
            FieldLabel('Valor unitario', flex: 1),
          ],
        ),
        SizedBox(height: 4),
        // Fila 3: Campos de entrada con Autocomplete para producto
        Row(
          children: [
            // Código - Autocomplete para buscar por código
            Expanded(
              flex: 1,
              child: _cargandoProductos
                  ? Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Cargando...',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Autocomplete<Producto>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Producto>.empty();
                        }
                        // Buscar por código - sin requisito de mínimo 2 caracteres
                        final texto = textEditingValue.text.toLowerCase();
                        return _productos
                            .where((p) {
                              final cod = (p.codigo ?? '').toLowerCase();
                              return cod.contains(texto) || cod.startsWith(texto);
                            })
                            .take(15);
                      },
                      displayStringForOption: (Producto producto) =>
                          (producto.codigo?.isNotEmpty ?? false) 
                              ? producto.codigo!
                              : producto.id,
                      onSelected: (Producto producto) {
                        setState(() {
                          _productoSeleccionado = producto;
                          _codigoProductoController.text = (producto.codigo?.isNotEmpty ?? false)
                              ? producto.codigo!
                              : producto.id;
                          _nombreProductoController.text = producto.nombre;
                          _valorUnitarioController.text = producto.costo
                              .toString();
                        });
                      },
                      fieldViewBuilder:
                          (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            // Sincronizar con el controlador principal
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              textEditingController.text = _codigoProductoController.text;
                            });
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                hintText: 'Código...',
                                hintStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder:
                          (
                            BuildContext context,
                            AutocompleteOnSelected<Producto> onSelected,
                            Iterable<Producto> options,
                          ) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: 250,
                                    maxWidth: 150,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.all(8.0),
                                    itemCount: options.length,
                                    shrinkWrap: true,
                                    itemBuilder: (BuildContext context, int index) {
                                      final Producto option = options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            (option.codigo?.isNotEmpty ?? false)
                                                ? option.codigo!
                                                : option.id,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                    ),
            ),
            SizedBox(width: 8),
            // Nombre Producto - Autocomplete con indicador de carga
            Expanded(
              flex: 2,
              child: _cargandoProductos
                  ? Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Cargando productos...',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Autocomplete<Producto>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        // No mostrar nada si está vacío (igual que facturación)
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Producto>.empty();
                        }
                        // Requerir al menos 2 caracteres para buscar (más rápido)
                        if (textEditingValue.text.length < 2) {
                          return const Iterable<Producto>.empty();
                        }
                        // Buscar en productos
                        return filtrarYOrdenarProductos(
                          _productos,
                          textEditingValue.text,
                          limite: 15,
                        );
                      },
                      displayStringForOption: (Producto producto) =>
                          producto.nombre,
                      onSelected: (Producto producto) {
                        setState(() {
                          _productoSeleccionado = producto;
                          _codigoProductoController.text = (producto.codigo?.isNotEmpty ?? false)
                              ? producto.codigo!
                              : producto.id;
                          _nombreProductoController.text = producto.nombre;
                          _valorUnitarioController.text = producto.costo
                              .toString();
                        });
                      },
                      fieldViewBuilder:
                          (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                hintText: _productos.isEmpty
                                    ? 'No hay productos disponibles'
                                    : 'Escribe al menos 2 letras...',
                                hintStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: Icon(
                                  Icons.arrow_drop_down,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  size: 20,
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder:
                          (
                            BuildContext context,
                            AutocompleteOnSelected<Producto> onSelected,
                            Iterable<Producto> options,
                          ) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: 300,
                                    maxWidth: 400,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.all(8.0),
                                    itemCount: options.length,
                                    shrinkWrap: true,
                                    itemBuilder: (BuildContext context, int index) {
                                      final Producto option = options.elementAt(
                                        index,
                                      );
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Container(
                                          padding: EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                                                    .withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                option.nombre,
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    'Código: ${option.id}',
                                                    style: TextStyle(
                                                      color: AppTheme
                                                          .textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Spacer(),
                                                  Text(
                                                    CurrencyUtils.format(option.precio),
                                                    style: TextStyle(
                                                      color: AppTheme.primary,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                    ),
            ),
            SizedBox(width: 4),
            // Botón para crear nuevo producto
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.add, color: AppTheme.primary, size: 20),
                onPressed: _mostrarDialogoCrearProducto,
                tooltip: 'Crear nuevo producto',
              ),
            ),
            SizedBox(width: 8),
            // Cantidad
            Expanded(
              flex: 1,
              child: TextField(
                controller: _cantidadProductoController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(width: 8),
            // Valor unitario
            Expanded(
              flex: 1,
              child: TextField(
                controller: _valorUnitarioController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  hintText: '\$0',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        // Fila 4: Valor total, Tipo Imp, % Imp, Tipo %, % Descuento, Destino, botones
        LayoutBuilder(builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final cs = Theme.of(context).colorScheme;

          Widget valorTotalWidget = Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                CurrencyUtils.format(valorTotal),
                style: TextStyle(color: cs.onSurface, fontSize: 13),
              ),
            ),
          );

          Widget tipoImpWidget = Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(4)),
              child: DropdownButtonFormField<String>(
                value: _tipoImpuesto,
                style: TextStyle(color: cs.onSurface, fontSize: 13),
                decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: InputBorder.none),
                dropdownColor: cs.surface,
                items: ['--', 'IVA', 'INC'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _tipoImpuesto = v ?? '--'),
              ),
            ),
          );

          Widget pctImpWidget = Expanded(
            flex: 2,
            child: TextField(
              controller: _porcentajeImpuestoController,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                hintText: '0',
                hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 13),
                filled: true, fillColor: cs.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
              ),
            ),
          );

          Widget tipoDctoWidget = Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(4)),
              child: DropdownButtonFormField<String>(
                value: _tipoDescuento,
                style: TextStyle(color: cs.onSurface, fontSize: 13),
                decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: InputBorder.none),
                dropdownColor: cs.surface,
                items: ['%', '\$'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _tipoDescuento = v ?? '%'),
              ),
            ),
          );

          Widget pctDctoWidget = Expanded(
            flex: 2,
            child: TextField(
              controller: _porcentajeDescuentoController,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                hintText: '0',
                hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 13),
                filled: true, fillColor: cs.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
              ),
            ),
          );

          Widget destinoWidget = Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(4)),
              child: DropdownButtonFormField<String>(
                value: _destinoSeleccionado,
                style: TextStyle(color: cs.onSurface, fontSize: 13),
                decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: InputBorder.none, hintText: 'Destino'),
                dropdownColor: cs.surface,
                items: ['BODEGA', 'ALMACÉN', 'PARTE Y PARTE'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _destinoSeleccionado = v ?? 'ALMACÉN'),
              ),
            ),
          );

          Widget botonesWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: IconButton(icon: Icon(Icons.add, color: Colors.white, size: 16), padding: EdgeInsets.zero, onPressed: _agregarItemDesdeFormulario),
              ),
              SizedBox(width: 4),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: IconButton(
                  icon: Icon(Icons.remove, color: Colors.white, size: 16),
                  padding: EdgeInsets.zero,
                  onPressed: () { if (_items.isNotEmpty) _eliminarItem(_items.length - 1); },
                ),
              ),
            ],
          );

          Widget? stockWidget = _productoSeleccionado != null
              ? Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ALM ${_productoSeleccionado!.almacen ?? 0}', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text('BOD ${_productoSeleccionado!.bodega ?? 0}', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : null;

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Etiquetas fila 1
                Row(children: [
                  FieldLabel('Total', flex: 2),
                  FieldLabel('Imp.', flex: 2),
                  FieldLabel('%', flex: 2),
                  FieldLabel('Dcto', flex: 2),
                  FieldLabel('%', flex: 2),
                ]),
                SizedBox(height: 4),
                Row(children: [valorTotalWidget, SizedBox(width: 6), tipoImpWidget, SizedBox(width: 6), pctImpWidget, SizedBox(width: 6), tipoDctoWidget, SizedBox(width: 6), pctDctoWidget]),
                SizedBox(height: 8),
                // Etiquetas fila 2
                Row(children: [
                  FieldLabel('Destino', flex: 3),
                  if (stockWidget != null) SizedBox(width: 8),
                  SizedBox(width: 60),
                ]),
                SizedBox(height: 4),
                Row(
                  children: [
                    destinoWidget,
                    if (stockWidget != null) ...[SizedBox(width: 8), stockWidget],
                    SizedBox(width: 8),
                    botonesWidget,
                  ],
                ),
              ],
            );
          }

          // Desktop: todo en una fila
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                FieldLabel('Valor total', flex: 2),
                FieldLabel('', flex: 2),
                FieldLabel('% Imp.', flex: 2),
                FieldLabel('', flex: 2),
                FieldLabel('% Desc.', flex: 2),
                FieldLabel('Destino', flex: 3),
                SizedBox(width: 64),
              ]),
              SizedBox(height: 4),
              Row(
                children: [
                  valorTotalWidget, SizedBox(width: 2),
                  tipoImpWidget, SizedBox(width: 2),
                  pctImpWidget, SizedBox(width: 2),
                  tipoDctoWidget, SizedBox(width: 2),
                  pctDctoWidget, SizedBox(width: 2),
                  destinoWidget, SizedBox(width: 2),
                  botonesWidget,
                ],
              ),
              if (stockWidget != null) ...[SizedBox(height: 4), stockWidget],
            ],
          );
        }),
        // 📦 Campos adicionales para PARTE Y PARTE
        if (_destinoSeleccionado == 'PARTE Y PARTE') ...[
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextFormField(
                    controller: _cantidadAlmacenController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      hintText: 'Cant. Almacén',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.store,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ),
                    onChanged: (value) {
                      // Auto-calcular cantidad bodega
                      final total =
                          double.tryParse(_cantidadProductoController.text) ??
                          0;
                      final almacen = double.tryParse(value) ?? 0;
                      if (almacen <= total) {
                        _cantidadBodegaController.text = (total - almacen)
                            .toString();
                      }
                    },
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextFormField(
                    controller: _cantidadBodegaController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      hintText: 'Cant. Bodega',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.warehouse,
                        color: Colors.orange,
                        size: 16,
                      ),
                    ),
                    onChanged: (value) {
                      // Auto-calcular cantidad almacén
                      final total =
                          double.tryParse(_cantidadProductoController.text) ??
                          0;
                      final bodega = double.tryParse(value) ?? 0;
                      if (bodega <= total) {
                        _cantidadAlmacenController.text = (total - bodega)
                            .toString();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: 16),
        // Lista de items agregados
        if (_items.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                // Header de la tabla
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Producto',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Cant.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'P. Unit',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Subtotal',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 40),
                    ],
                  ),
                ),
                // Items
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.ingredienteNombre,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${item.cantidad} ${item.unidad}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            CurrencyUtils.format(item.precioUnitario),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            CurrencyUtils.format(item.subtotal),
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // 📦 Mostrar destino
                        Tooltip(
                          message: item.destino == 'PARTE Y PARTE'
                              ? 'Almacén: ${item.cantidadAlmacen.toStringAsFixed(0)}\nBodega: ${item.cantidadBodega.toStringAsFixed(0)}'
                              : item.destino,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.destino == 'BODEGA'
                                  ? Colors.blue.withOpacity(0.2)
                                  : item.destino == 'ALMACÉN'
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.destino.length > 8
                                      ? 'P. P.'
                                      : item.destino,
                                  style: TextStyle(
                                    color: item.destino == 'BODEGA'
                                        ? Colors.blue
                                        : item.destino == 'ALMACÉN'
                                        ? Colors.orange
                                        : Colors.purple,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (item.destino == 'PARTE Y PARTE')
                                  Text(
                                    'A:${item.cantidadAlmacen.toStringAsFixed(0)} B:${item.cantidadBodega.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: Colors.purple,
                                      fontSize: 9,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: AppTheme.error,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => _eliminarItem(index),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatearFechaISO(DateTime fecha) {
    return '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
  }

  Widget _buildBotones() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botón Crear Borrador
        OutlinedButton(
          onPressed: _guardandoFactura
              ? null
              : () => runGuarded(_guardarComoBorrador),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppTheme.primary),
            padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Crear Borrador',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: 24),

        // Botón Comprar
        ElevatedButton(
          onPressed: _guardandoFactura ? null : () => runGuarded(_guardarFactura),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: EdgeInsets.symmetric(horizontal: 64, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _guardandoFactura
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Comprar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _seleccionarFecha(
    BuildContext context,
    bool esFechaFactura,
  ) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: esFechaFactura ? _fechaFactura : _fechaVencimiento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

  // Método para agregar item desde el formulario inline
  void _agregarItemDesdeFormulario() {
    if (_productoSeleccionado == null) {
      showWarningSnackBar(context, 'Seleccione un producto');
      return;
    }

    final cantidad = double.tryParse(_cantidadProductoController.text) ?? 0;
    if (cantidad <= 0) {
      showWarningSnackBar(context, 'La cantidad debe ser mayor a 0');
      return;
    }

    // 📦 Validar PARTE Y PARTE
    double cantidadAlmacen = 0;
    double cantidadBodega = 0;
    if (_destinoSeleccionado == 'PARTE Y PARTE') {
      cantidadAlmacen = double.tryParse(_cantidadAlmacenController.text) ?? 0;
      cantidadBodega = double.tryParse(_cantidadBodegaController.text) ?? 0;

      if (cantidadAlmacen <= 0 && cantidadBodega <= 0) {
        showWarningSnackBar(context, 'Ingrese las cantidades para Almacén y Bodega');
        return;
      }

      final sumaCantidades = cantidadAlmacen + cantidadBodega;
      if ((sumaCantidades - cantidad).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La suma de Almacén ($cantidadAlmacen) + Bodega ($cantidadBodega) debe ser igual a la cantidad total ($cantidad)',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    } else if (_destinoSeleccionado == 'BODEGA') {
      cantidadBodega = cantidad;
    } else {
      // ALMACÉN
      cantidadAlmacen = cantidad;
    }

    final precioUnitario = double.tryParse(_valorUnitarioController.text) ?? 0;
    if (precioUnitario <= 0) {
      showWarningSnackBar(context, 'El valor unitario debe ser mayor a 0');
      return;
    }

    final porcentajeImpuesto =
        double.tryParse(_porcentajeImpuestoController.text) ?? 0;
    final porcentajeDescuento =
        double.tryParse(_porcentajeDescuentoController.text) ?? 0;

    final subtotal = cantidad * precioUnitario;
    final descuento = _tipoDescuento == '%'
        ? subtotal * (porcentajeDescuento / 100)
        : porcentajeDescuento;
    final baseGravable = subtotal - descuento;
    final impuesto = _tipoImpuesto != '--'
        ? baseGravable * (porcentajeImpuesto / 100)
        : 0.0;

    final item = ItemFacturaCompra(
      ingredienteId: _productoSeleccionado!.id ?? '',
      ingredienteNombre: _productoSeleccionado!.nombre,
      cantidad: cantidad,
      unidad: 'UND',
      precioUnitario: precioUnitario,
      // ⚠️ subtotal = cantidad × precioUnitario SIN descontar (bruto), NO
      // baseGravable. El resumen (Subtotal / Dcto Producto / Impuesto / Total)
      // ya resta el descuento por separado: si aquí se guarda ya neto, el
      // descuento se resta dos veces y el Total sale más bajo de lo que
      // debería (ver ResumenCompraLateral en lib/widgets/compras/).
      subtotal: subtotal,
      valorImpuesto: impuesto,
      valorDescuento: descuento,
      porcentajeImpuesto: porcentajeImpuesto,
      porcentajeDescuento: porcentajeDescuento,
      destino: _destinoSeleccionado, // 📦 Agregar destino
      cantidadAlmacen: cantidadAlmacen, // 📦 Cantidad para almacén
      cantidadBodega: cantidadBodega, // 📦 Cantidad para bodega
    );

    setState(() {
      _items.add(item);
      // Limpiar los campos
      _productoSeleccionado = null;
      _codigoProductoController.clear();
      _nombreProductoController.clear();
      _cantidadProductoController.clear();
      _valorUnitarioController.clear();
      _porcentajeImpuestoController.text = '19';
      _porcentajeDescuentoController.text = '0';
      _tipoImpuesto = 'IVA';
      _tipoDescuento = '%';
      _destinoSeleccionado = 'ALMACÉN'; // 📦 Resetear destino
      _cantidadAlmacenController.clear(); // 📦 Limpiar cantidad almacén
      _cantidadBodegaController.clear(); // 📦 Limpiar cantidad bodega
    });

    showSuccessSnackBar(context, 'Producto agregado');
  }

  void _eliminarItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }


  // ─── Gestión de borradores ────────────────────────────────────────────────
  static const String _kDraftKey = 'factura_compra_borradores';

  /// Serializa el formulario actual como mapa JSON para guardar como borrador
  Map<String, dynamic> _formularioAJson() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'numeroFactura': _numeroFactura,
      'fechaFactura': _fechaFactura.toIso8601String(),
      'proveedorId': _proveedorSeleccionado?.id,
      'proveedorNombre': _proveedorSeleccionado?.nombre,
      'items': _items.map((i) => i.toJson()).toList(),
    };
  }

  /// Guarda el formulario actual como borrador en SharedPreferences
  Future<void> _guardarComoBorrador() async {
    if (_items.isEmpty && _proveedorSeleccionado == null) {
      showWarningSnackBar(context, 'El formulario está vacío, no hay nada que guardar');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDraftKey);
      final List<dynamic> borradores = raw != null ? jsonDecode(raw) : [];
      borradores.add(_formularioAJson());
      // Mantener máximo 10 borradores
      if (borradores.length > 10) borradores.removeAt(0);
      await prefs.setString(_kDraftKey, jsonEncode(borradores));

      if (mounted) {
        showSuccessSnackBar(context, 'Borrador guardado correctamente');
      }
    } catch (e) {
      appLog('Error guardando borrador: $e', level: LogLevel.error);
      if (mounted) {
        showErrorSnackBar(context, 'Error al guardar borrador: ${errorMessage(e)}');
      }
    }
  }

  /// Muestra la lista de borradores guardados y permite cargar uno
  Future<void> _verBorradores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDraftKey);
      if (raw == null || raw == '[]') {
        if (mounted) {
          showInfoSnackBar(context, 'No hay borradores guardados');
        }
        return;
      }

      final List<dynamic> borradores = jsonDecode(raw);
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Borradores guardados (${borradores.length})',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 500,
            height: 350,
            child: ListView.separated(
              itemCount: borradores.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white12),
              itemBuilder: (_, i) {
                final b = borradores[borradores.length - 1 - i] as Map<String, dynamic>;
                final fecha = DateTime.tryParse(b['timestamp'] ?? '')?.toLocal();
                final fechaStr = fecha != null
                    ? '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}'
                    : 'Fecha desconocida';
                final proveedor = b['proveedorNombre'] ?? 'Sin proveedor';
                final nItems = (b['items'] as List?)?.length ?? 0;

                return ListTile(
                  leading: Icon(Icons.description_outlined, color: AppTheme.primary),
                  title: Text(proveedor, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  subtitle: Text(
                    '$fechaStr · $nItems ítem(s)',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        child: const Text('Cargar', style: TextStyle(color: Colors.greenAccent)),
                        onPressed: () => Navigator.pop(ctx, b),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: 'Eliminar borrador',
                        onPressed: () async {
                          borradores.removeAt(borradores.length - 1 - i);
                          await prefs.setString(_kDraftKey, jsonEncode(borradores));
                          if (ctx.mounted) Navigator.pop(ctx);
                          _verBorradores(); // reabrir actualizado
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cerrar', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
            ),
          ],
        ),
      ).then((borrador) {
        if (borrador is Map<String, dynamic>) {
          _cargarBorrador(borrador);
        }
      });
    } catch (e) {
      appLog('Error cargando borradores: $e', level: LogLevel.error);
    }
  }

  /// Carga un borrador en el formulario
  void _cargarBorrador(Map<String, dynamic> b) {
    setState(() {
      _numeroFactura = b['numeroFactura'];
      if (b['fechaFactura'] != null) {
        _fechaFactura = DateTime.tryParse(b['fechaFactura']) ?? DateTime.now();
      }
      // Buscar proveedor por ID en la lista cargada
      if (b['proveedorId'] != null) {
        final prov = _proveedores.where((p) => p.id == b['proveedorId']).firstOrNull;
        _proveedorSeleccionado = prov;
      }
      _items.clear();
      if (b['items'] != null) {
        for (final item in b['items'] as List) {
          try {
            _items.add(ItemFacturaCompra.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      }
    });
    showSuccessSnackBar(context, 'Borrador cargado correctamente');
  }

  Future<void> _guardarFactura() async {
    if (!_formKey.currentState!.validate()) {
        
      return;
    }

    if (_items.isEmpty) {
        
      showErrorSnackBar(context, 'Debe agregar al menos un item');
      return;
    }

    // 🚀 TIMEOUT: Verificar si ya está guardando
    if (_guardandoFactura) return;

      
      
      

    setState(() {
      _isLoading = true;
      _guardandoFactura = true;
    });

    try {
      // Calcular el total acumulando los subtotales de cada ítem
      final total = _items.fold<double>(0, (sum, item) => sum + item.subtotal);
        

      // Verificar que el número de factura no esté vacío o sea "Generando..."
      if (_numeroFactura == null ||
          _numeroFactura!.isEmpty ||
          _numeroFactura == 'Generando...' ||
          _numeroFactura == 'Error al generar') {
          
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: Número de factura no válido. Reintentando generación...',
            ),
            backgroundColor: Colors.orange,
          ),
        );

        // Intentar regenerar el número
        _generarNumeroFactura();

        if (_numeroFactura == null ||
            _numeroFactura!.isEmpty ||
            _numeroFactura == 'Generando...' ||
            _numeroFactura == 'Error al generar') {
          throw Exception('No se pudo generar un número de factura válido');
        }
      }

      // Verificar que todos los ítems tengan subtotales válidos
      bool itemsValidos = _items.every((item) => item.subtotal > 0);
      if (!itemsValidos) {
          
        showErrorSnackBar(context, 'Error: Algunos ítems tienen valores inválidos');
        return;
      }

        
      // Asegurarnos que los items tengan valores correctos
      final List<ItemFacturaCompra> itemsVerificados = _items.map((item) {
        // Validar y corregir cualquier subtotal si fuera necesario
        double subtotalCalculado = item.cantidad * item.precioUnitario;
          
          
          
          
          

        if (subtotalCalculado != item.subtotal) {
          // Crear una nueva instancia con el subtotal correcto
          return ItemFacturaCompra(
            ingredienteId: item.ingredienteId,
            ingredienteNombre: item.ingredienteNombre,
            cantidad: item.cantidad,
            unidad: item.unidad,
            precioUnitario: item.precioUnitario,
            subtotal: subtotalCalculado,
            porcentajeImpuesto: item.porcentajeImpuesto,
            valorImpuesto: item.valorImpuesto,
            porcentajeDescuento: item.porcentajeDescuento,
            valorDescuento: item.valorDescuento,
            destino: item.destino, // 📦 Preservar destino
            cantidadAlmacen: item.cantidadAlmacen, // 📦 Preservar cantidad almacén
            cantidadBodega: item.cantidadBodega, // 📦 Preservar cantidad bodega
          );
        }
        return item;
      }).toList();

      // Calcular totales DIAN
      final subtotalItems = itemsVerificados.fold<double>(
        0,
        (sum, item) => sum + item.subtotal,
      );
      final totalDescuentosItems = itemsVerificados.fold<double>(
        0,
        (sum, item) => sum + item.valorDescuento,
      );
      final baseGravable = subtotalItems - totalDescuentosItems;
      final totalImpuestosItems = itemsVerificados.fold<double>(
        0,
        (sum, item) => sum + item.valorImpuesto,
      );

        
        
        
        
        

      // Retenciones
      final porcRetencion =
          double.tryParse(_porcentajeRetencionController.text) ?? 0;
      final porcReteIva =
          double.tryParse(_porcentajeReteIvaController.text) ?? 0;
      final porcReteIca =
          double.tryParse(_porcentajeReteIcaController.text) ?? 0;

      final valorRetencion = baseGravable * (porcRetencion / 100);
      final valorReteIva = totalImpuestosItems * (porcReteIva / 100);
      final valorReteIca = baseGravable * (porcReteIca / 100);
      final totalRetenciones = valorRetencion + valorReteIva + valorReteIca;

      // Total final DIAN
      double totalFinal = baseGravable + totalImpuestosItems - totalRetenciones;

        
        
        
        
        

      // Si el total es 0 pero hay items con subtotales, usar la suma directa de subtotales + IVA
      if (totalFinal <= 0 && itemsVerificados.isNotEmpty) {
        final sumaDirecta = itemsVerificados.fold<double>(
          0,
          (sum, item) => sum + item.subtotal + item.valorImpuesto - item.valorDescuento,
        );
        if (sumaDirecta > 0) {
          totalFinal = sumaDirecta;
        }
      }

      final factura = FacturaCompra(
        numeroFactura: _numeroFactura ?? '',
        proveedorNit: _proveedorNitController.text.trim().isEmpty
            ? null
            : _proveedorNitController.text.trim(),
        proveedorNombre: _proveedorNombreController.text.trim().isEmpty
            ? null
            : _proveedorNombreController.text.trim(),
        fechaFactura: _fechaFactura,
        fechaVencimiento: _fechaVencimiento,
        total: totalFinal,
        estado: _pagadoDesdeCaja ? 'PENDIENTE' : 'PROCESADA',
        pagadoDesdeCaja: _pagadoDesdeCaja,
        items: itemsVerificados,
        // Guardar el origen de la compra si no paga desde caja
        descripcion: !_pagadoDesdeCaja
            ? 'Origen: ${_origenCompraController.text.isNotEmpty ? _origenCompraController.text : 'No especificado'}'
            : _descripcionController.text.isNotEmpty
            ? _descripcionController.text
            : null,
        fechaCreacion: DateTimeUtils.nowColombia(),
        fechaActualizacion: DateTimeUtils.nowColombia(),
        // Campos DIAN
        subtotal: subtotalItems,
        totalDescuentos: totalDescuentosItems,
        baseGravable: baseGravable,
        totalImpuestos: totalImpuestosItems,
        totalRetenciones: totalRetenciones,
        porcentajeRetencion: porcRetencion,
        valorRetencion: valorRetencion,
        porcentajeReteIva: porcReteIva,
        valorReteIva: valorReteIva,
        porcentajeReteIca: porcReteIca,
        valorReteIca: valorReteIca,
      );

        
      final facturaCreada = await _facturaCompraService.crearFacturaCompra(
        factura,
      );
        

      // ✅ NO actualizar stock desde el frontend - el backend ya actualiza el stock
      // automáticamente al crear la factura. Hacerlo aquí también causaba duplicación (+2 en vez de +1).
      // Los items enviados ya incluyen 'destino', 'cantidadAlmacen' y 'cantidadBodega'
      // para que el backend sepa dónde poner el stock.

      // � Refrescar cache de productos para actualizar UI automáticamente
      try {
        final cacheProvider = Provider.of<DatosCacheProvider>(
          context,
          listen: false,
        );
        await cacheProvider.forceRefreshProductos();
        appLog('✅ Cache de productos actualizado después de la compra');
      } catch (e) {
        appLog('⚠️ Error refrescando cache (no crítico): $e');
      }

      // �💰 Actualizar el costo del producto con el último precio de compra
      await _actualizarCostoProductos(facturaCreada);

      // Verificar si la factura creada tiene el total correcto
      if (facturaCreada.total <= 0 && total > 0) {
          
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Advertencia: La factura se creó pero el total puede estar incorrecto. Se intentará corregir.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );

        // Intentar actualizar la factura con el total correcto
        try {
          // Aquí podrías llamar a un método para actualizar la factura si existe
        } catch (e) {
            
        }
      } else {
        showSuccessSnackBar(context, 'Factura creada exitosamente');
      }

      // Pequeño delay para asegurar que el backend procesó la factura
      await Future.delayed(Duration(milliseconds: 500));

      // Navegar a la lista de compras
      if (mounted) {
        context.go('/compras');
      }
    } catch (e) {
        
      if (mounted) {
        showErrorSnackBar(context, 'Error al crear factura: ${errorMessage(e)}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _guardandoFactura = false;
        });
      }
    }
  }

  // 💰 Actualizar el costo de los productos con el último precio de compra
  Future<void> _actualizarCostoProductos(FacturaCompra factura) async {
    try {
      for (var item in factura.items) {
        try {
          // Buscar el producto en la lista de productos disponibles
          Producto? producto;
          try {
            producto = _productos.firstWhere((p) => p.id == item.ingredienteId);
          } catch (e) {
            producto = null;
          }

          // Log del valor que se va a enviar
          appLog(
            '[ACTUALIZAR COSTO] Producto: "+item.ingredienteNombre+" (ID: ' +
                item.ingredienteId +
                ") - Costo a enviar: " +
                item.precioUnitario.toString(),
          );

          if (producto != null) {
            // Validar que el costo sea mayor a 0 antes de actualizar
            if (item.precioUnitario > 0) {
              await _productoService.actualizarCostoProducto(
                item.ingredienteId,
                item.precioUnitario,
                precioActual: producto.precio,
              );
            } else {
              appLog(
                '[ACTUALIZAR COSTO] ❌ No se actualiza porque el costo es <= 0',
              );
            }
          }
        } catch (e) {
          // Continuar con el siguiente item aunque haya error
        }
      }
    } catch (e) {
      // No lanzar excepción para no interrumpir el flujo de la factura
    }
  }

}
