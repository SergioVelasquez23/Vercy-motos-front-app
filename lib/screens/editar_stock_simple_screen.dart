import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/producto.dart';
import '../providers/datos_cache_provider.dart';
import '../services/producto_service.dart';
import '../utils/busqueda_productos_utils.dart';
import '../utils/api_error.dart';

/// Pantalla mínima para editar solo la cantidad en almacén y bodega de un
/// producto: buscar, elegir, escribir el número, guardar. Pensada para un
/// usuario adulto mayor sin experiencia con la app — a propósito no usa la
/// paleta de colores ni las tarjetas/paneles del resto de la app, solo texto
/// negro grande sobre blanco y botones grandes, como una calculadora.
///
/// Acceso restringido a un solo correo (ver EMAIL_AUTORIZADO en
/// app_router.dart y app_shell.dart) — esta pantalla en sí no vuelve a
/// validar el correo porque para cuando el usuario llega aquí el router y el
/// menú ya se encargaron de que solo esa persona pueda entrar.
class EditarStockSimpleScreen extends StatefulWidget {
  const EditarStockSimpleScreen({super.key});

  @override
  State<EditarStockSimpleScreen> createState() => _EditarStockSimpleScreenState();
}

class _EditarStockSimpleScreenState extends State<EditarStockSimpleScreen> {
  static const double _tamanoTexto = 24;
  static const double _altoBoton = 64;

  final _busquedaController = TextEditingController();
  final _almacenController = TextEditingController();
  final _bodegaController = TextEditingController();
  final _nombreNuevoController = TextEditingController();
  final _codigoNuevoController = TextEditingController();
  final _precioNuevoController = TextEditingController();
  final _costoNuevoController = TextEditingController();
  final _productoService = ProductoService();

  List<Producto> _productos = [];
  List<Producto> _resultados = [];
  Producto? _seleccionado;
  bool _creandoProducto = false;
  bool _cargandoCatalogo = true;
  bool _guardando = false;
  String? _mensaje;
  bool _mensajeEsError = false;

  @override
  void initState() {
    super.initState();
    _busquedaController.addListener(_buscar);
    _cargarProductos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    _almacenController.dispose();
    _bodegaController.dispose();
    _nombreNuevoController.dispose();
    _codigoNuevoController.dispose();
    _precioNuevoController.dispose();
    _costoNuevoController.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    final cacheProvider = Provider.of<DatosCacheProvider>(context, listen: false);
    final productos = await cacheProvider.obtenerProductos();
    if (!mounted) return;
    setState(() {
      _productos = productos;
      _cargandoCatalogo = false;
    });
  }

  void _buscar() {
    setState(() {
      _resultados = filtrarYOrdenarProductos(_productos, _busquedaController.text, limite: 8);
    });
  }

  void _seleccionar(Producto producto) {
    setState(() {
      _seleccionado = producto;
      _resultados = [];
      _busquedaController.clear();
      _almacenController.text = '${producto.almacen ?? 0}';
      _bodegaController.text = '${producto.bodega ?? 0}';
      _mensaje = null;
    });
  }

  void _volverABuscar() {
    setState(() {
      _seleccionado = null;
      _creandoProducto = false;
      _mensaje = null;
    });
  }

  void _abrirCrearProducto() {
    setState(() {
      _creandoProducto = true;
      _resultados = [];
      _busquedaController.clear();
      _nombreNuevoController.clear();
      _codigoNuevoController.clear();
      _precioNuevoController.clear();
      _costoNuevoController.clear();
      _almacenController.text = '0';
      _bodegaController.text = '0';
      _mensaje = null;
    });
  }

  void _sumar(TextEditingController controller, int delta) {
    final actual = int.tryParse(controller.text.trim()) ?? 0;
    final nuevo = (actual + delta).clamp(0, 999999);
    controller.text = '$nuevo';
  }

  Future<void> _guardar() async {
    final producto = _seleccionado;
    if (producto == null) return;

    final nuevoAlmacen = int.tryParse(_almacenController.text.trim());
    final nuevoBodega = int.tryParse(_bodegaController.text.trim());
    if (nuevoAlmacen == null || nuevoBodega == null || nuevoAlmacen < 0 || nuevoBodega < 0) {
      setState(() {
        _mensaje = 'Escribe un número (0 o más) en almacén y en bodega.';
        _mensajeEsError = true;
      });
      return;
    }

    setState(() {
      _guardando = true;
      _mensaje = null;
    });
    try {
      final actualizado = producto.copyWith(almacen: nuevoAlmacen, bodega: nuevoBodega);
      final resultado = await _productoService.updateProducto(actualizado);
      if (!mounted) return;
      setState(() {
        _seleccionado = resultado;
        _almacenController.text = '${resultado.almacen ?? 0}';
        _bodegaController.text = '${resultado.bodega ?? 0}';
        _guardando = false;
        _mensaje = 'Guardado ✓';
        _mensajeEsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _mensaje = 'No se pudo guardar: ${errorMessage(e)}';
        _mensajeEsError = true;
      });
    }
  }

  Future<void> _guardarNuevoProducto() async {
    final nombre = _nombreNuevoController.text.trim();
    final precio = double.tryParse(_precioNuevoController.text.trim());
    final costo = double.tryParse(_costoNuevoController.text.trim());
    final almacen = int.tryParse(_almacenController.text.trim());
    final bodega = int.tryParse(_bodegaController.text.trim());

    if (nombre.isEmpty) {
      setState(() {
        _mensaje = 'Escribe el nombre del producto.';
        _mensajeEsError = true;
      });
      return;
    }
    if (precio == null || precio <= 0) {
      setState(() {
        _mensaje = 'Escribe un precio de venta mayor a 0.';
        _mensajeEsError = true;
      });
      return;
    }
    if (costo == null || costo < 0) {
      setState(() {
        _mensaje = 'Escribe un costo (0 o más).';
        _mensajeEsError = true;
      });
      return;
    }
    if (almacen == null || bodega == null || almacen < 0 || bodega < 0) {
      setState(() {
        _mensaje = 'Escribe un número (0 o más) en almacén y en bodega.';
        _mensajeEsError = true;
      });
      return;
    }

    setState(() {
      _guardando = true;
      _mensaje = null;
    });
    try {
      final codigo = _codigoNuevoController.text.trim();
      final nuevo = Producto(
        id: '',
        nombre: nombre,
        precio: precio,
        costo: costo,
        utilidad: precio - costo,
        codigo: codigo.isEmpty ? null : codigo,
        almacen: almacen,
        bodega: bodega,
      );
      final creado = await _productoService.addProducto(nuevo);
      if (!mounted) return;
      setState(() {
        _productos = [creado, ..._productos];
        _creandoProducto = false;
        _seleccionado = creado;
        _almacenController.text = '${creado.almacen ?? 0}';
        _bodegaController.text = '${creado.bodega ?? 0}';
        _guardando = false;
        _mensaje = 'Producto creado ✓';
        _mensajeEsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _mensaje = 'No se pudo crear: ${errorMessage(e)}';
        _mensajeEsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _cargandoCatalogo
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : _creandoProducto
                  ? _buildCrearProducto()
                  : _seleccionado == null
                      ? _buildBusqueda()
                      : _buildEdicion(_seleccionado!),
        ),
      ),
    );
  }

  Widget _buildBusqueda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Buscar producto',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            OutlinedButton(
              onPressed: _abrirCrearProducto,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, _altoBoton),
                side: const BorderSide(color: Colors.black, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text(
                '+ Nuevo producto',
                style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _busquedaController,
          autofocus: true,
          style: const TextStyle(fontSize: _tamanoTexto, color: Colors.black),
          decoration: InputDecoration(
            hintText: 'Nombre o código',
            hintStyle: const TextStyle(fontSize: _tamanoTexto, color: Colors.black38),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 3),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _resultados.isEmpty
              ? const SizedBox.shrink()
              : ListView.separated(
                  itemCount: _resultados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final producto = _resultados[index];
                    return _buildBotonResultado(producto);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBotonResultado(Producto producto) {
    return OutlinedButton(
      onPressed: () => _seleccionar(producto),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(_altoBoton),
        side: const BorderSide(color: Colors.black, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text(
        producto.nombre,
        style: const TextStyle(fontSize: _tamanoTexto, color: Colors.black, fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildCrearProducto() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nuevo producto',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 24),
          _buildCampoTexto('Nombre', _nombreNuevoController, autofocus: true),
          const SizedBox(height: 20),
          _buildCampoTexto('Código (opcional)', _codigoNuevoController),
          const SizedBox(height: 20),
          _buildCampoTexto(
            'Precio de venta',
            _precioNuevoController,
            teclado: TextInputType.number,
          ),
          const SizedBox(height: 20),
          _buildCampoTexto('Costo', _costoNuevoController, teclado: TextInputType.number),
          const SizedBox(height: 24),
          _buildCampoCantidad('Almacén', _almacenController),
          const SizedBox(height: 24),
          _buildCampoCantidad('Bodega', _bodegaController),
          const SizedBox(height: 32),
          if (_mensaje != null) ...[
            Text(
              _mensaje!,
              style: TextStyle(
                fontSize: _tamanoTexto,
                fontWeight: FontWeight.bold,
                color: _mensajeEsError ? Colors.red.shade900 : Colors.green.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _guardando ? null : _guardarNuevoProducto,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(_altoBoton),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _guardando
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : const Text('Guardar', style: TextStyle(fontSize: _tamanoTexto, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _guardando ? null : _volverABuscar,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(_altoBoton),
              side: const BorderSide(color: Colors.black, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(fontSize: _tamanoTexto, color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoTexto(
    String etiqueta,
    TextEditingController controller, {
    TextInputType teclado = TextInputType.text,
    bool autofocus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(fontSize: _tamanoTexto, color: Colors.black, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: teclado,
          style: const TextStyle(fontSize: _tamanoTexto, color: Colors.black),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 3),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildEdicion(Producto producto) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          producto.nombre,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 32),
        _buildCampoCantidad('Almacén', _almacenController),
        const SizedBox(height: 24),
        _buildCampoCantidad('Bodega', _bodegaController),
        const SizedBox(height: 32),
        if (_mensaje != null) ...[
          Text(
            _mensaje!,
            style: TextStyle(
              fontSize: _tamanoTexto,
              fontWeight: FontWeight.bold,
              color: _mensajeEsError ? Colors.red.shade900 : Colors.green.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(_altoBoton),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _guardando
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
              : const Text('Guardar', style: TextStyle(fontSize: _tamanoTexto, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _guardando ? null : _volverABuscar,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(_altoBoton),
            side: const BorderSide(color: Colors.black, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            'Buscar otro producto',
            style: TextStyle(fontSize: _tamanoTexto, color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoCantidad(String etiqueta, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(fontSize: _tamanoTexto, color: Colors.black, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildBotonPasoCantidad('-', () => setState(() => _sumar(controller, -1))),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 32, color: Colors.black, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 3),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildBotonPasoCantidad('+', () => setState(() => _sumar(controller, 1))),
          ],
        ),
      ],
    );
  }

  Widget _buildBotonPasoCantidad(String simbolo, VoidCallback onPressed) {
    return SizedBox(
      width: _altoBoton,
      height: _altoBoton,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: Colors.black, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          simbolo,
          style: const TextStyle(fontSize: 32, color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
