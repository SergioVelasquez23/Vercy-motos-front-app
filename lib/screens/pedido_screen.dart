import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mesa.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/pedido.dart';
import '../models/item_pedido.dart';
import '../services/producto_service.dart';
import '../services/mesa_service.dart';
import '../services/pedido_service.dart';

class PedidoScreen extends StatefulWidget {
  final Mesa mesa;

  PedidoScreen({required this.mesa});

  @override
  _PedidoScreenState createState() => _PedidoScreenState();
}

class _PedidoScreenState extends State<PedidoScreen> {
  final ProductoService _productoService = ProductoService();
  final MesaService _mesaService = MesaService();

  List<Producto> productosMesa = [];
  List<Producto> productosDisponibles = [];
  List<Categoria> categorias = [];

  // Map para controlar el estado de pago de cada producto
  Map<String, bool> productoPagado = {};

  bool isLoading = true;
  String? errorMessage;
  bool esCortesia = false;
  bool esConsumoInterno = false;
  String? clienteSeleccionado;
  TextEditingController busquedaController = TextEditingController();
  String filtro = '';
  String? categoriaSelecionadaId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Load products and categories from backend
      final productos = await _productoService.getProductos();
      final categoriasData = await _productoService.getCategorias();

      setState(() {
        productosDisponibles = productos;
        categorias = categoriasData;

        // Clone existing products from mesa for local editing
        if (widget.mesa.productos.isNotEmpty) {
          productosMesa = List.from(widget.mesa.productos);
        }

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error al cargar datos: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _agregarProducto(Producto producto) {
    setState(() {
      // Verificar si el producto ya está en la mesa
      int index = productosMesa.indexWhere((p) => p.id == producto.id);
      if (index != -1) {
        productosMesa[index].cantidad++;
      } else {
        // Crear una nueva instancia para no afectar al original
        productosMesa.add(
          Producto(
            id: producto.id,
            nombre: producto.nombre,
            precio: producto.precio,
            costo: producto.costo,
            impuestos: producto.impuestos,
            utilidad: producto.utilidad,
            tieneVariantes: producto.tieneVariantes,
            estado: producto.estado,
            imagenUrl: producto.imagenUrl,
            categoria: producto.categoria,
            descripcion: producto.descripcion,
            cantidad: 1,
          ),
        );
      }
    });
  }

  void _eliminarProducto(Producto producto) {
    setState(() {
      int index = productosMesa.indexWhere((p) => p.id == producto.id);
      if (index != -1) {
        if (productosMesa[index].cantidad > 1) {
          productosMesa[index].cantidad--;
        } else {
          productosMesa.removeAt(index);
        }
      }
    });
  }

  Future<void> _guardarPedido() async {
    try {
      setState(() {
        isLoading = true;
      });

      if (productosMesa.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No hay productos en el pedido'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Crear los items del pedido
      List<ItemPedido> items = productosMesa.map((producto) {
        return ItemPedido(
          productoId: producto.id,
          producto: producto,
          cantidad: producto.cantidad,
          notas: null,
          precio: producto.precio,
        );
      }).toList();

      // Calcular total
      double total = productosMesa.fold(
        0,
        (sum, producto) => sum + (producto.precio * producto.cantidad),
      );

      // Determinar el tipo de pedido
      TipoPedido tipo;
      if (esCortesia) {
        tipo = TipoPedido.cortesia;
      } else if (esConsumoInterno) {
        tipo = TipoPedido.interno;
      } else {
        tipo = TipoPedido.normal;
      }

      // Crear el pedido
      final pedido = Pedido(
        id: '',
        fecha: DateTime.now(),
        tipo: tipo,
        mesa: widget.mesa.nombre,
        mesero: 'Juan Diego', // TODO: Obtener del usuario logueado
        items: items,
        total: total,
        estado: EstadoPedido.activo,
        cliente: clienteSeleccionado,
      );

      // Crear el pedido en el backend
      final pedidoCreado = await PedidoService().createPedido(pedido);

      // Actualizar la mesa para marcarla como ocupada
      widget.mesa.ocupada = true;
      widget.mesa.total = total;
      await _mesaService.updateMesa(widget.mesa);

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pedido #${pedidoCreado.id} guardado exitosamente - Total: \$${total.toStringAsFixed(0)}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Regresar a la pantalla anterior y notificar que se actualizó
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar pedido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Color(0xFFFF6B00);
    final Color bgDark = Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          '${widget.mesa.nombre} - Pedido',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        elevation: 0,
        actions: [
          // Refresh button
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadData),
          // Save button
          TextButton.icon(
            onPressed: isLoading ? null : () => _guardarPedido(),
            icon: Icon(Icons.save, color: Colors.white),
            label: Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingState()
          : errorMessage != null
          ? _buildErrorState()
          : _buildMainContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            errorMessage!,
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B00)),
            child: Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final Color primary = Color(0xFFFF6B00);
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

    return Column(
      children: [
        // Barra de búsqueda
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: busquedaController,
                  style: TextStyle(color: textLight),
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    hintStyle: TextStyle(color: textLight.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, color: primary),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primary),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      filtro = value.toLowerCase();
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // Filtro de categorías
        Container(
          height: 50,
          margin: EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Botón "Todas las categorías"
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  backgroundColor: categoriaSelecionadaId == null
                      ? primary
                      : cardBg,
                  label: Text(
                    'Todas',
                    style: TextStyle(
                      color: categoriaSelecionadaId == null
                          ? Colors.white
                          : textLight,
                    ),
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      categoriaSelecionadaId = null;
                    });
                  },
                  selected: categoriaSelecionadaId == null,
                ),
              ),
              // Chips para cada categoría
              ...categorias.map((categoria) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    backgroundColor: categoriaSelecionadaId == categoria.id
                        ? primary
                        : cardBg,
                    label: Text(
                      categoria.nombre,
                      style: TextStyle(
                        color: categoriaSelecionadaId == categoria.id
                            ? Colors.white
                            : textLight,
                      ),
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        categoriaSelecionadaId = selected ? categoria.id : null;
                      });
                    },
                    selected: categoriaSelecionadaId == categoria.id,
                  ),
                );
              }).toList(),
            ],
          ),
        ),

        SizedBox(height: 8),

        // Lista de productos en el pedido
        if (productosMesa.isNotEmpty)
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Productos en el pedido:',
                  style: TextStyle(
                    color: textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                ...productosMesa.map(
                  (producto) => _buildProductoEnPedido(producto),
                ),
                Divider(color: textLight.withOpacity(0.3)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        color: textLight,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${_calcularTotal().toStringAsFixed(0)}',
                      style: TextStyle(
                        color: primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        SizedBox(height: 20),

        // Lista de productos disponibles
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _filtrarProductos().length,
            itemBuilder: (context, index) {
              return _buildProductoDisponible(_filtrarProductos()[index]);
            },
          ),
        ),
      ],
    );
  }

  List<Producto> _filtrarProductos() {
    if (filtro.isEmpty && categoriaSelecionadaId == null) {
      return productosDisponibles;
    }

    return productosDisponibles.where((producto) {
      bool matchesNombre =
          filtro.isEmpty ||
          producto.nombre.toLowerCase().contains(filtro.toLowerCase());

      bool matchesCategoria =
          categoriaSelecionadaId == null ||
          producto.categoria?.id == categoriaSelecionadaId;

      return matchesNombre && matchesCategoria;
    }).toList();
  }

  double _calcularTotal() {
    return productosMesa.fold(
      0,
      (sum, producto) => sum + (producto.precio * producto.cantidad),
    );
  }

  Widget _buildProductoDisponible(Producto producto) {
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);
    final Color primary = Color(0xFFFF6B00);

    // Categoría etiqueta
    final String categoriaText = producto.categoria?.nombre ?? 'Sin categoría';

    return GestureDetector(
      onTap: () => _agregarProducto(producto),
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Imagen del producto
            Expanded(child: _buildProductImage(producto.imagenUrl)),
            SizedBox(height: 8),
            // Etiqueta de categoría
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                categoriaText,
                style: TextStyle(
                  color: primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 4),
            // Nombre del producto
            Text(
              producto.nombre,
              style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Descripción si existe
            if (producto.descripcion != null &&
                producto.descripcion!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  producto.descripcion!,
                  style: TextStyle(
                    color: textLight.withOpacity(0.7),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            SizedBox(height: 4),
            // Precio
            Text(
              '\$${producto.precio.toStringAsFixed(0)}',
              style: TextStyle(color: primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(String? imagenUrl) {
    final Color primary = Color(0xFFFF6B00);

    // Si no hay imagen o la URL es inválida
    if (imagenUrl == null || imagenUrl.isEmpty) {
      return Icon(Icons.restaurant, color: primary, size: 48);
    }

    // Si es una URL web
    if (imagenUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imagenUrl,
        placeholder: (context, url) => CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primary),
        ),
        errorWidget: (context, url, error) =>
            Icon(Icons.restaurant, color: primary),
        fit: BoxFit.cover,
      );
    }

    // Si es un archivo local o asset
    return Image.asset(
      imagenUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.restaurant, color: primary),
    );
  }

  Widget _buildProductoEnPedido(Producto producto) {
    final Color textLight = Color(0xFFE0E0E0);
    final Color primary = Color(0xFFFF6B00);

    // Inicializar el estado de pago si no existe
    productoPagado.putIfAbsent(producto.id, () => true);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Switch para controlar estado activo/pagado
          Switch(
            value: productoPagado[producto.id]!,
            onChanged: (bool value) {
              setState(() {
                productoPagado[producto.id] = value;
              });
            },
            activeColor: primary,
          ),
          Expanded(
            flex: 2,
            child: Text(
              producto.nombre,
              style: TextStyle(
                color: productoPagado[producto.id]!
                    ? textLight
                    : textLight.withOpacity(0.5),
                decoration: productoPagado[producto.id]!
                    ? null
                    : TextDecoration.lineThrough,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.remove_circle,
                    color: productoPagado[producto.id]!
                        ? Colors.red
                        : Colors.red.withOpacity(0.5),
                  ),
                  onPressed: productoPagado[producto.id]!
                      ? () => _eliminarProducto(producto)
                      : null,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                SizedBox(width: 10),
                Text(
                  '${producto.cantidad}',
                  style: TextStyle(
                    color: productoPagado[producto.id]!
                        ? textLight
                        : textLight.withOpacity(0.5),
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: productoPagado[producto.id]!
                        ? Colors.green
                        : Colors.green.withOpacity(0.5),
                  ),
                  onPressed: productoPagado[producto.id]!
                      ? () => _agregarProducto(producto)
                      : null,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '\$${(producto.precio * producto.cantidad).toStringAsFixed(0)}',
              style: TextStyle(
                color: productoPagado[producto.id]!
                    ? primary
                    : primary.withOpacity(0.5),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
