import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mesa.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/pedido.dart';
import '../models/item_pedido.dart';
import '../services/producto_service.dart';
import '../services/mesa_service.dart';
import '../services/pedido_service.dart';
import '../services/inventario_service.dart';
import '../models/movimiento_inventario.dart';
import '../models/inventario.dart';
import '../providers/user_provider.dart';

class PedidoScreen extends StatefulWidget {
  final Mesa mesa;

  PedidoScreen({required this.mesa});

  @override
  _PedidoScreenState createState() => _PedidoScreenState();
}

class _PedidoScreenState extends State<PedidoScreen> {
  final ProductoService _productoService = ProductoService();
  final MesaService _mesaService = MesaService();
  final InventarioService _inventarioService = InventarioService();

  List<Producto> productosMesa = [];
  List<Producto> productosDisponibles = [];

  // Mapa para guardar los IDs de productos de carne para descontar del inventario
  Map<String, String> productosCarneMap = {};
  List<Categoria> categorias = [];

  // Map para controlar el estado de pago de cada producto
  Map<String, bool> productoPagado = {};

  bool isLoading = true;
  String? errorMessage;
  String? clienteSeleccionado;
  TextEditingController busquedaController = TextEditingController();
  String filtro = '';
  String? categoriaSelecionadaId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<dynamic> _mostrarDialogoOpciones(
    Producto producto,
    List<String> opciones,
  ) async {
    TextEditingController observacionesController = TextEditingController();
    int cantidad = 1;
    String? opcionSeleccionada = opciones.isNotEmpty ? opciones.first : null;

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Seleccionar opción para ${producto.nombre}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (opciones.isNotEmpty) ...[
                      DropdownButton<String>(
                        value: opcionSeleccionada,
                        items: opciones
                            .map(
                              (opcion) => DropdownMenuItem(
                                value: opcion,
                                child: Text(opcion),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            opcionSeleccionada = value;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            if (cantidad > 1) {
                              setState(() => cantidad--);
                            }
                          },
                        ),
                        Text('$cantidad'),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            setState(() => cantidad++);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: observacionesController,
                      decoration: InputDecoration(
                        labelText: 'Observaciones',
                        hintText: 'Ej: Sin sal, término medio, etc.',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'nota': opcionSeleccionada ?? '',
                      'cantidad': cantidad,
                      'observaciones': observacionesController.text,
                      'productoId': producto.id,
                      'nombre': opcionSeleccionada ?? producto.nombre,
                    });
                  },
                  child: Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );

    return resultado;
  }

  // Nuevo método para seleccionar ingredientes
  Future<Map<String, dynamic>?> _mostrarDialogoSeleccionIngredientes(
    Producto producto,
  ) async {
    List<String> ingredientesSeleccionados = [];
    TextEditingController notasController = TextEditingController();

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Seleccionar ingredientes para ${producto.nombre}',
                style: TextStyle(fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Container(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecciona los ingredientes que deseas:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Lista de ingredientes disponibles
                      ...producto.ingredientesDisponibles.map((ingrediente) {
                        final bool isSelected = ingredientesSeleccionados
                            .contains(ingrediente);
                        return CheckboxListTile(
                          title: Text(ingrediente),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                ingredientesSeleccionados.add(ingrediente);
                              } else {
                                ingredientesSeleccionados.remove(ingrediente);
                              }
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),

                      SizedBox(height: 16),

                      // Campo de notas adicionales
                      TextField(
                        controller: notasController,
                        decoration: InputDecoration(
                          labelText: 'Notas adicionales (opcional)',
                          border: OutlineInputBorder(),
                          hintText: 'Ej: Sin sal, término medio...',
                        ),
                        maxLines: 2,
                      ),

                      if (ingredientesSeleccionados.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Text(
                          'Ingredientes seleccionados:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          ingredientesSeleccionados.join(', '),
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: ingredientesSeleccionados.isEmpty
                      ? null
                      : () {
                          String notasFinales = '';
                          if (ingredientesSeleccionados.isNotEmpty) {
                            notasFinales =
                                'Ingredientes: ${ingredientesSeleccionados.join(', ')}';
                          }
                          if (notasController.text.isNotEmpty) {
                            if (notasFinales.isNotEmpty) {
                              notasFinales += ' - ${notasController.text}';
                            } else {
                              notasFinales = notasController.text;
                            }
                          }

                          Navigator.of(context).pop({
                            'ingredientes': ingredientesSeleccionados,
                            'notas': notasFinales,
                          });
                        },
                  child: Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    return resultado;
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

  Future<void> _agregarProducto(Producto producto) async {
    String? notasEspeciales;
    String? productoCarneId;
    List<String> ingredientesSeleccionados = [];

    // Verificar si el producto tiene ingredientes disponibles
    if (producto.ingredientesDisponibles.isNotEmpty) {
      // Mostrar diálogo de selección de ingredientes
      final resultadoIngredientes = await _mostrarDialogoSeleccionIngredientes(
        producto,
      );
      if (resultadoIngredientes != null) {
        ingredientesSeleccionados =
            resultadoIngredientes['ingredientes'] as List<String>;
        notasEspeciales = resultadoIngredientes['notas'] as String?;
      } else {
        // Si el usuario canceló la selección, no agregar el producto
        return;
      }
    }

    if (producto.tieneVariantes) {
      // Detectar productos específicos que requieren selección de opciones
      bool esAsadoCombinado = producto.nombre.toLowerCase().contains(
        'asado combinado',
      );
      bool esEjecutivo = producto.nombre.toLowerCase().contains('ejecutivo');

      if (esAsadoCombinado || esEjecutivo || producto.tieneVariantes) {
        // Determinar opciones personalizadas según el tipo de plato
        List<String>? opcionesPersonalizadas;

        // Configurar opciones según el nombre del plato
        if (producto.nombre.toLowerCase().contains('chuzo')) {
          opcionesPersonalizadas = ['Pollo', 'Res', 'Cerdo'];
        } else if (producto.nombre.toLowerCase().contains('asado combinado')) {
          opcionesPersonalizadas = ['Res', 'Cerdo'];
        } else if (producto.nombre.toLowerCase().contains('ejecutivo')) {
          opcionesPersonalizadas = [
            'Res',
            'Cerdo',
            'Pollo',
            'Pechuga',
            'Chicharrón',
          ];
        }
        // Puedes agregar más condiciones para otros platos aquí

        // Mostrar diálogo para seleccionar opciones
        final resultado = await _mostrarDialogoOpciones(
          producto,
          opcionesPersonalizadas ?? [],
        );

        // Verificamos si el resultado es un mapa (formato nuevo) o string (formato anterior)
        if (resultado is Map<String, dynamic>) {
          // Combinar notas de ingredientes con notas de variantes
          String? notasVariantes = resultado['nota'];
          if (notasEspeciales != null && notasVariantes != null) {
            notasEspeciales = '$notasEspeciales - $notasVariantes';
          } else if (notasVariantes != null) {
            notasEspeciales = notasVariantes;
          }

          productoCarneId = resultado['productoId'];

          // Si hay una cantidad específica, la incluimos en las notas
          if (resultado['cantidad'] != null && resultado['cantidad'] > 1) {
            int cantidadSeleccionada = resultado['cantidad'] as int;
            notasEspeciales =
                "$notasEspeciales (Cantidad: $cantidadSeleccionada)";
          }

          // Si hay observaciones, las incluimos también
          if (resultado['observaciones'] != null &&
              resultado['observaciones'].toString().isNotEmpty) {
            notasEspeciales =
                "$notasEspeciales - ${resultado['observaciones']}";
          }
        } else if (resultado is String) {
          // Combinar notas de ingredientes con notas de variantes
          if (notasEspeciales != null) {
            notasEspeciales = '$notasEspeciales - $resultado';
          } else {
            notasEspeciales = resultado;
          }
        }

        // Si no hay notas especiales ni ingredientes, no agregar el producto
        if (notasEspeciales == null && ingredientesSeleccionados.isEmpty)
          return;
      }
    }

    setState(() {
      // Verificar si el producto ya está en la mesa
      int index = productosMesa.indexWhere((p) => p.id == producto.id);
      if (index != -1) {
        // Si ya existe y tiene las mismas opciones, solo incrementamos cantidad
        if ((productosMesa[index].nota == null && notasEspeciales == null) ||
            productosMesa[index].nota == notasEspeciales) {
          productosMesa[index].cantidad++;
          // Si es un producto con carne y tenemos ID de carne, actualizamos el mapa
          if (productoCarneId != null) {
            productosCarneMap[productosMesa[index].id] = productoCarneId;
          }
        } else {
          // Si tiene opciones diferentes, lo agregamos como nuevo ítem
          Producto nuevoProd = Producto(
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
            nota: notasEspeciales,
            cantidad: 1,
            ingredientesDisponibles: ingredientesSeleccionados,
          );

          productosMesa.add(nuevoProd);

          // Guardar el ID del producto de carne si existe
          if (productoCarneId != null) {
            productosCarneMap[nuevoProd.id] = productoCarneId;
          }
        }
      } else {
        // Crear una nueva instancia para no afectar al original
        Producto nuevoProd = Producto(
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
          nota: notasEspeciales,
          cantidad: 1,
          ingredientesDisponibles: ingredientesSeleccionados,
        );

        productosMesa.add(nuevoProd);

        // Guardar el ID del producto de carne si existe
        if (productoCarneId != null) {
          productosCarneMap[nuevoProd.id] = productoCarneId;
        }
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
          // Si eliminamos un producto, eliminamos su referencia de carne del mapa
          productosCarneMap.remove(productosMesa[index].id);
          productosMesa.removeAt(index);
        }
      }
    });
  }

  // Método para descontar los productos de carne del inventario
  Future<void> _descontarCarnesDelInventario() async {
    try {
      // Si no hay productos de carne para descontar, terminamos
      if (productosCarneMap.isEmpty) return;

      // Obtener todos los items del inventario
      final inventario = await _inventarioService.getInventario();

      // Para cada producto de carne, realizar un movimiento de inventario
      for (var entry in productosCarneMap.entries) {
        final productoId = entry.value; // ID del producto de carne

        // Buscar el producto en el inventario
        final itemInventario = inventario.firstWhere(
          (item) => item.id == productoId,
          orElse: () => Inventario(
            id: '',
            categoria: '',
            codigo: '',
            nombre: 'No encontrado',
            unidad: '',
            precioCompra: 0,
            stockActual: 0,
            stockMinimo: 0,
            estado: 'INACTIVO',
          ),
        );

        // Si encontramos el producto en inventario, realizar el movimiento
        if (itemInventario.id.isNotEmpty) {
          // Determinar la cantidad a descontar (cantidad del producto en mesa)
          final producto = productosMesa.firstWhere(
            (p) => p.id == entry.key,
            orElse: () => Producto(
              id: '',
              nombre: '',
              precio: 0,
              costo: 0,
              utilidad: 0,
              cantidad: 0,
            ),
          );

          if (producto.id.isNotEmpty) {
            // Crear un movimiento de salida para este producto
            final movimiento = MovimientoInventario(
              inventarioId: itemInventario.id,
              productoId: producto.id,
              productoNombre: producto.nombre,
              tipoMovimiento: 'Salida - Venta',
              motivo: 'Consumo en Pedido',
              cantidadAnterior: itemInventario.stockActual,
              cantidadMovimiento:
                  -1.0 * producto.cantidad, // Negativo para salidas
              cantidadNueva: itemInventario.stockActual - producto.cantidad,
              responsable: 'Sistema',
              referencia: 'Pedido Mesa: ${widget.mesa.nombre}',
              observaciones: 'Automático por selección en ${producto.nombre}',
              fecha: DateTime.now(),
            );

            // Realizar el movimiento de inventario
            await _inventarioService.crearMovimientoInventario(movimiento);

            print(
              'Descontado del inventario: ${itemInventario.nombre} x ${producto.cantidad}',
            );
          }
        }
      }
    } catch (e) {
      print('Error al descontar carnes del inventario: $e');
      // No interrumpimos el flujo del pedido si esto falla
    }
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
          notas: producto.nota, // Pasar las notas con opciones específicas
          precio: producto.precio,
          ingredientesSeleccionados: producto.ingredientesDisponibles,
        );
      }).toList();

      // Calcular total
      double total = productosMesa.fold(
        0,
        (sum, producto) => sum + (producto.precio * producto.cantidad),
      );

      // Obtener el usuario actual
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final meseroActual = userProvider.userName ?? 'Usuario Desconocido';

      // Crear el pedido (siempre como pedido normal)
      final pedido = Pedido(
        id: '',
        fecha: DateTime.now(),
        tipo: TipoPedido.normal,
        mesa: widget.mesa.nombre,
        mesero: meseroActual,
        items: items,
        total: total,
        estado: EstadoPedido.activo,
        cliente: clienteSeleccionado,
      );

      // Crear el pedido en el backend
      final pedidoCreado = await PedidoService().createPedido(pedido);

      // Descontar productos de carne del inventario si existen
      await _descontarCarnesDelInventario();

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                if (producto.nota != null && producto.nota!.isNotEmpty)
                  Text(
                    producto.nota!,
                    style: TextStyle(
                      color: productoPagado[producto.id]!
                          ? primary.withOpacity(0.7)
                          : primary.withOpacity(0.3),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
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
