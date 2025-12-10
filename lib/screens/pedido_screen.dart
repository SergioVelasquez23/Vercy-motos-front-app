import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mesa.dart';
import '../widgets/imagen_producto_widget.dart';
import '../widgets/lazy_product_image_widget.dart';
import '../config/endpoints_config.dart';
import '../services/image_service.dart';
import '../services/image_loader_service.dart';
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
import '../models/tipo_mesa.dart';
import '../providers/user_provider.dart';
import '../providers/datos_cache_provider.dart';
import '../utils/format_utils.dart';
import '../utils/cache_helpers.dart';

class PedidoScreen extends StatefulWidget {
  final Mesa mesa;
  final Pedido? pedidoExistente; // Pedido existente para editar (opcional)
  final TipoMesa? tipoMesa; // Tipo de mesa seleccionado (opcional)

  const PedidoScreen({
    super.key,
    required this.mesa,
    this.pedidoExistente,
    this.tipoMesa,
  });

  @override
  _PedidoScreenState createState() => _PedidoScreenState();
}

class _PedidoScreenState extends State<PedidoScreen> {
  final ProductoService _productoService = ProductoService();
  final MesaService _mesaService = MesaService();
  final InventarioService _inventarioService = InventarioService();
  final ImageService _imageService = ImageService();

  /// Helper method to convert dynamic to Producto
  /// If forceNonNull is true, returns a default Producto instead of null for invalid inputs
  /// If productoId is provided, it will be used in case a default Producto needs to be created
  Producto? _getProductoFromItem(
    dynamic producto, {
    String? productoId,
    bool forceNonNull = false,
  }) {
    if (producto == null) {
      return forceNonNull
          ? Producto(
              id: productoId ?? "",
              nombre: "Producto desconocido",
              precio: 0,
              costo: 0,
              utilidad: 0,
            )
          : null;
    }
    if (producto is Producto) return producto;
    if (producto is Map<String, dynamic>) {
      return Producto.fromJson(producto);
    }
    return forceNonNull
        ? Producto(
            id: productoId ?? "",
            nombre: "Producto desconocido",
            precio: 0,
            costo: 0,
            utilidad: 0,
          )
        : null;
  }

  List<Producto> productosMesa = [];
  List<Producto> productosDisponibles = [];

  // Mapa para guardar la relación entre productos (key: productoId) y sus opciones de carne seleccionadas (value: opcionCarneId)
  // Esto permite reutilizar las selecciones previas y descontar correctamente del inventario
  Map<String, String> productosCarneMap = {};
  List<Categoria> categorias = [];

  // Map para controlar el estado de pago de cada producto
  Map<String, bool> productoPagado = {};

  bool isLoading = true;
  bool isSaving = false; // Nueva variable para controlar el estado de guardado
  DateTime?
  lastSaveAttempt; // Para controlar el timeout entre intentos de guardado
  String? errorMessage;
  String? clienteSeleccionado;
  TextEditingController busquedaController = TextEditingController();
  TextEditingController clienteController = TextEditingController();
  TextEditingController observacionesController = TextEditingController();
  String filtro = '';
  String? categoriaSelecionadaId;

  // Variables para el debounce en la búsqueda
  Timer? _debounceTimer;
  final int _debounceMilliseconds =
      150; // ✅ OPTIMIZADO: Reducido de 300ms a 150ms

  // Variable para almacenar los productos filtrados por la API
  List<Producto>? _productosFiltered;
  // ✅ OPTIMIZACIÓN: Cache de productos para vista para evitar recálculos en build
  List<Producto> _productosVista = [];
  // Variables para manejar pedido existente
  Pedido? pedidoExistente;
  bool esPedidoExistente = false;
  List<Producto> productosOriginales =
      []; // Productos que ya estaban en el pedido
  int cantidadProductosOriginales = 0; // Cantidad de productos originales

  @override
  void initState() {
    super.initState();

    // Establecer el estado inicial basado en si hay un pedido existente
    esPedidoExistente = widget.pedidoExistente != null;

    // Cargar datos optimizado para usar el DatosProvider
    _cargarDatosOptimizado();

    // Configurar el controlador de búsqueda con debounce
    busquedaController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    // Limpiar el timer de debounce
    _debounceTimer?.cancel();
    busquedaController.removeListener(_onSearchChanged);
    busquedaController.dispose();
    clienteController.dispose();
    observacionesController.dispose();
    super.dispose();
  }

  // Método optimizado para cargar datos utilizando el DatosProvider
  Future<void> _cargarDatosOptimizado() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Obtener el provider de datos
      final datosProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );

      // Si los datos no están inicializados, cargarlos
      if (!datosProvider.hasData) {
        print(
          '📝 PedidoScreen: Datos aún no inicializados, usando provider...',
        );
        await datosProvider.initialize();
      } else {
        print('📝 PedidoScreen: Usando datos en caché del provider');
      }

      // Obtener categorías y productos desde el provider (caché)
      final productosCache = datosProvider.productos;
      final categoriasCache = datosProvider.categorias;

      // Inicializar el pedido existente si es necesario
      if (widget.pedidoExistente != null) {
        pedidoExistente = widget.pedidoExistente;

        // Procesar productos del pedido existente
        for (var item in widget.pedidoExistente!.items) {
          final productoId = item.productoId;

          // Buscar el producto en la caché
          final productoBase =
              productosCache?.firstWhere(
                (p) => p.id == productoId,
                orElse: () => Producto(
                  id: productoId,
                  nombre: item.productoNombre ?? 'Producto desconocido',
                  precio: item.precioUnitario,
                  costo: 0,
                  utilidad: 0,
                ),
              ) ??
              Producto(
                id: productoId,
                nombre: item.productoNombre ?? 'Producto desconocido',
                precio: item.precioUnitario,
                costo: 0,
                utilidad: 0,
              );

          // Crear producto con la información del pedido existente preservada
          final producto = Producto(
            id: productoBase.id,
            nombre: productoBase.nombre,
            precio: productoBase.precio,
            costo: productoBase.costo,
            impuestos: productoBase.impuestos,
            utilidad: productoBase.utilidad,
            tieneVariantes: productoBase.tieneVariantes,
            estado: productoBase.estado,
            imagenUrl: productoBase.imagenUrl,
            categoria: productoBase.categoria,
            descripcion: productoBase.descripcion,
            // ✅ PRESERVAR las notas e ingredientes del pedido existente
            nota: item.notas, // Preservar las notas del ItemPedido
            cantidad: item.cantidad, // Preservar la cantidad
            ingredientesDisponibles:
                item.ingredientesSeleccionados, // Preservar ingredientes
            ingredientesRequeridos: productoBase.ingredientesRequeridos,
            ingredientesOpcionales: productoBase.ingredientesOpcionales,
            tieneIngredientes: productoBase.tieneIngredientes,
            tipoProducto: productoBase.tipoProducto,
          );

          // Agregar a la lista de productos de la mesa
          productosMesa.add(producto);

          // Marcar como pagado si el pedido está pagado
          if (widget.pedidoExistente!.estado == EstadoPedido.pagado) {
            productoPagado[productoId] = true;
          }
        }

        // Registrar cantidad original para comparación
        cantidadProductosOriginales = productosMesa.length;
        // Guardar copia para referencia
        productosOriginales = List.from(productosMesa);

        // Cargar cliente si existe
        if (widget.pedidoExistente!.cliente != null) {
          clienteSeleccionado = widget.pedidoExistente!.cliente;
          clienteController.text = clienteSeleccionado!;
        }

        // Cargar observaciones si existen
        if (widget.pedidoExistente!.notas != null &&
            widget.pedidoExistente!.notas!.isNotEmpty) {
          observacionesController.text = widget.pedidoExistente!.notas!;
        }
      }

      // Actualizar listas
      setState(() {
        categorias = categoriasCache ?? [];
        productosDisponibles = productosCache ?? [];
        // Por defecto, seleccionar "Todos" y cargar todos los productos
        categoriaSelecionadaId = null; // null significa "Todos"
        _resetearPaginacion();
        _actualizarProductosVista(); // Actualizar la vista con todos los productos
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        isLoading = false;
        errorMessage = "Error al cargar datos: $error";
      });
      print("❌ Error al cargar datos: $error");
    }
  }

  // Método para manejar cambios en la búsqueda con debounce y búsqueda mediante API
  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(Duration(milliseconds: _debounceMilliseconds), () {
      if (mounted) {
        final query = busquedaController.text;
        setState(() {
          filtro = query.toLowerCase();
          // Resetear paginación al cambiar la búsqueda
          _resetearPaginacion();
        });

        // ✅ OPTIMIZACIÓN: Búsqueda más inteligente con threshold
        if ((query.length >= 2) || categoriaSelecionadaId != null) {
          _searchProductosAPI(query);
        } else {
          // Si no hay suficiente texto ni categoría, limpiar resultados filtrados
          setState(() {
            _productosFiltered = null;
            _actualizarProductosVista(); // ✅ Actualizar cache
          });
        }
      }
    });
  }

  // Método para realizar la búsqueda de productos usando el cache del provider
  Future<void> _searchProductosAPI(String query) async {
    try {
      // Usar el provider para filtrar productos localmente (más rápido)
      final datosProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );

      // Filtrar productos en memoria desde el caché
      final productos = datosProvider.productos ?? [];
      final queryLower = query.toLowerCase();

      final results = productos.where((producto) {
        // Filtrar por categoría si está seleccionada
        final coincideCategoria =
            categoriaSelecionadaId == null ||
            producto.categoria?.id == categoriaSelecionadaId;

        // Filtrar por texto de búsqueda
        final coincideTexto =
            query.isEmpty || producto.nombre.toLowerCase().contains(queryLower);

        return coincideCategoria && coincideTexto;
      }).toList();

      if (mounted) {
        setState(() {
          _productosFiltered = results;
          _actualizarProductosVista(); // ✅ Actualizar cache
        });
      }
    } catch (error) {
      print('Error al buscar productos en caché: $error');
      // En caso de error, usar filtrado local como fallback
      if (mounted) {
        setState(() {
          _productosFiltered = _filtrarProductosLocal();
          _actualizarProductosVista(); // ✅ Actualizar cache
        });
      }
    }
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
    List<String> ingredientesOpcionalesSeleccionados =
        []; // Para tracking de opcionales múltiples
    TextEditingController notasController = TextEditingController();

    // ✅ COMENTADO: Logs de debugging detallados removidos
    // print('🔍 DEBUGING INGREDIENTES para ${producto.nombre}:');
    // print('  - ingredientesDisponibles: ${producto.ingredientesDisponibles}');
    // print('  - ingredientesRequeridos: ${producto.ingredientesRequeridos.length} items');
    // for (var ingrediente in producto.ingredientesRequeridos) {
    //   print('    * Requerido: ID="${ingrediente.ingredienteId}", Nombre="${ingrediente.ingredienteNombre}"');
    // }
    print(
      '  - ingredientesOpcionales: ${producto.ingredientesOpcionales.length} items',
    );
    for (var ingrediente in producto.ingredientesOpcionales) {
      print(
        '    * Opcional: ID="${ingrediente.ingredienteId}", Nombre="${ingrediente.ingredienteNombre}" (+\$${ingrediente.precioAdicional})',
      );
    }

    // ✅ LÓGICA CORREGIDA: Solo agregar ingredientes opcionales a las listas de selección
    List<String> ingredientesBasicos = List.from(
      producto.ingredientesDisponibles,
    );
    List<String> ingredientesOpcionales = [];
    // NO crear lista de requeridos para selección - se agregan automáticamente

    // Agregar ingredientes opcionales con precios SOLO para selección
    for (var ingrediente in producto.ingredientesOpcionales) {
      print(
        '🔍 Procesando ingrediente opcional: ID="${ingrediente.ingredienteId}", Nombre="${ingrediente.ingredienteNombre}", Precio Adicional: \$${ingrediente.precioAdicional}',
      );

      String nombreConPrecio = ingrediente.ingredienteNombre;
      if (ingrediente.precioAdicional > 0) {
        nombreConPrecio +=
            ' (+\$${ingrediente.precioAdicional.toStringAsFixed(0)})';
        print('✅ Ingrediente con precio adicional: "$nombreConPrecio"');
      } else {
        print(
          '⚠️ Ingrediente SIN precio adicional (será gratis): "$nombreConPrecio"',
        );
      }

      ingredientesOpcionales.add(nombreConPrecio);
    }

    print(
      '📋 TOTAL Ingredientes opcionales cargados: ${ingredientesOpcionales.length}',
    );
    if (ingredientesOpcionales.isNotEmpty) {
      print('📝 Lista completa de opcionales:');
      for (var i = 0; i < ingredientesOpcionales.length; i++) {
        print('   ${i + 1}. ${ingredientesOpcionales[i]}');
      }
    } else {
      print('⚠️ NO HAY ingredientes opcionales para mostrar');
    }

    // Los requeridos se agregan automáticamente al resultado final, NO para selección
    // ✅ COMENTADO: Logs de conteo básico removidos
    // print('📋 Ingredientes básicos: ${ingredientesBasicos.length}');
    // print('📋 Ingredientes opcionales para selección: ${ingredientesOpcionales.length}');
    // print('📋 Ingredientes requeridos (auto): ${producto.ingredientesRequeridos.length}');

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
                child: SizedBox(
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

                      // Mostrar información del producto si es combo
                      if (producto.esCombo) ...[
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'Producto tipo combo - Puedes personalizar los ingredientes',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                      ],

                      // Lista de ingredientes por tipo
                      if (ingredientesBasicos.isEmpty &&
                          ingredientesOpcionales.isEmpty)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Este producto solo tiene ingredientes incluidos automáticamente.\nNo hay ingredientes opcionales para seleccionar.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        )
                      else ...[
                        // ✅ SOLO mostrar ingredientes OPCIONALES para selección
                        // Los ingredientes requeridos se agregan automáticamente

                        // Mostrar info de ingredientes incluidos (solo informativo)
                        if (producto.ingredientesRequeridos.isNotEmpty) ...[
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ingredientes incluidos automáticamente:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                ...producto.ingredientesRequeridos.map(
                                  (ing) => Text(
                                    '✓ ${ing.ingredienteNombre}',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                        ],

                        // Ingredientes básicos (checkboxes múltiples)
                        // ✅ SOLO mostrar si hay ingredientes básicos Y no son todos opcionales de radio
                        if (ingredientesBasicos.isNotEmpty &&
                            !(ingredientesOpcionales.isNotEmpty &&
                                ingredientesBasicos.length == 1)) ...[
                          Text(
                            'Ingredientes adicionales:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                          ...ingredientesBasicos.map((ingrediente) {
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
                                    ingredientesSeleccionados.remove(
                                      ingrediente,
                                    );
                                  }
                                });
                              },
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            );
                          }),
                          SizedBox(height: 16),
                        ],

                        // Ingredientes opcionales (checkboxes múltiples)
                        if (ingredientesOpcionales.isNotEmpty) ...[
                          Text(
                            'Selecciona ingredientes opcionales (puedes elegir varios):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                          // Opción "Sin selección" - ahora es una opción independiente
                          CheckboxListTile(
                            title: Text(
                              'Sin selección - Una porción sin ingredientes opcionales',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.white70,
                              ),
                            ),
                            value: ingredientesOpcionalesSeleccionados.contains(
                              'SIN_SELECCION',
                            ),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  // Agregar "sin selección" como una opción más
                                  if (!ingredientesOpcionalesSeleccionados
                                      .contains('SIN_SELECCION')) {
                                    ingredientesOpcionalesSeleccionados.add(
                                      'SIN_SELECCION',
                                    );
                                  }
                                } else {
                                  // Remover "sin selección"
                                  ingredientesOpcionalesSeleccionados.remove(
                                    'SIN_SELECCION',
                                  );
                                }
                              });
                            },
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          SizedBox(height: 8),
                          // Lista de ingredientes opcionales
                          ...ingredientesOpcionales.map((ingrediente) {
                            final bool isSelected =
                                ingredientesOpcionalesSeleccionados.contains(
                                  ingrediente,
                                );
                            return CheckboxListTile(
                              title: Text(
                                ingrediente,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    // Agregar ingrediente a la lista de opcionales seleccionados
                                    ingredientesOpcionalesSeleccionados.add(
                                      ingrediente,
                                    );
                                    // También agregarlo a la lista general (para compatibilidad)
                                    if (!ingredientesSeleccionados.contains(
                                      ingrediente,
                                    )) {
                                      ingredientesSeleccionados.add(
                                        ingrediente,
                                      );
                                    }
                                  } else {
                                    // Remover ingrediente de ambas listas
                                    ingredientesOpcionalesSeleccionados.remove(
                                      ingrediente,
                                    );
                                    ingredientesSeleccionados.remove(
                                      ingrediente,
                                    );
                                  }
                                });
                              },
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            );
                          }),
                          SizedBox(height: 16),
                        ],
                      ],

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
                  onPressed: () {
                    // Caso 1: No hay ingredientes configurados
                    if (ingredientesBasicos.isEmpty &&
                        ingredientesOpcionales.isEmpty) {
                      Navigator.of(context).pop({
                        'ingredientes': <String>[],
                        'notas': notasController.text.isNotEmpty
                            ? notasController.text
                            : null,
                        'multiple': false,
                      });
                      return;
                    }

                    // Caso 2: "Sin selección" marcado o no hay opcionales seleccionados
                    if (ingredientesOpcionalesSeleccionados.isEmpty) {
                      String notasFinales = '';

                      // Solo incluir ingredientes básicos (no opcionales)
                      List<String> ingredientesBasicosSeleccionados =
                          ingredientesSeleccionados
                              .where(
                                (ing) => !ingredientesOpcionales.contains(ing),
                              )
                              .toList();

                      if (ingredientesBasicosSeleccionados.isNotEmpty) {
                        notasFinales =
                            'Ingredientes: ${ingredientesBasicosSeleccionados.join(', ')}';
                      }
                      if (notasController.text.isNotEmpty) {
                        if (notasFinales.isNotEmpty) {
                          notasFinales += ' - ${notasController.text}';
                        } else {
                          notasFinales = notasController.text;
                        }
                      }

                      Navigator.of(context).pop({
                        'ingredientes': ingredientesBasicosSeleccionados,
                        'notas': notasFinales.isNotEmpty ? notasFinales : null,
                        'multiple': false,
                      });
                      return;
                    }

                    // Caso 3: Múltiples ingredientes opcionales seleccionados
                    List<Map<String, dynamic>> productosMultiples = [];

                    for (String ingredienteOpcional
                        in ingredientesOpcionalesSeleccionados) {
                      // Incluir ingredientes básicos + este ingrediente opcional específico
                      List<String> ingredientesBasicosSeleccionados =
                          ingredientesSeleccionados
                              .where(
                                (ing) => !ingredientesOpcionales.contains(ing),
                              )
                              .toList();

                      List<String> ingredientesFinales = [
                        ...ingredientesBasicosSeleccionados,
                        ingredienteOpcional,
                      ];

                      String notasFinales = '';
                      if (ingredientesFinales.isNotEmpty) {
                        notasFinales =
                            'Ingredientes: ${ingredientesFinales.join(', ')}';
                      }
                      if (notasController.text.isNotEmpty) {
                        if (notasFinales.isNotEmpty) {
                          notasFinales += ' - ${notasController.text}';
                        } else {
                          notasFinales = notasController.text;
                        }
                      }

                      productosMultiples.add({
                        'ingredientes': ingredientesFinales,
                        'notas': notasFinales.isNotEmpty ? notasFinales : null,
                        'ingredienteOpcional': ingredienteOpcional,
                      });
                    }

                    Navigator.of(
                      context,
                    ).pop({'multiple': true, 'productos': productosMultiples});
                  },
                  child: Text(
                    (ingredientesBasicos.isEmpty &&
                            ingredientesOpcionales.isEmpty)
                        ? 'Continuar sin ingredientes'
                        : ingredientesOpcionalesSeleccionados.isEmpty
                        ? 'Confirmar (sin opcionales)'
                        : 'Confirmar (${ingredientesOpcionalesSeleccionados.length} producto${ingredientesOpcionalesSeleccionados.length > 1 ? 's' : ''})',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // ✅ NUEVA ESTRATEGIA: Manejar productos múltiples para ingredientes opcionales
    if (resultado != null) {
      // Verificar si son múltiples productos
      if (resultado['multiple'] == true && resultado['productos'] != null) {
        // Procesar múltiples productos
        List<Map<String, dynamic>> productosResultado = [];
        List<Map<String, dynamic>> productosData =
            List<Map<String, dynamic>>.from(resultado['productos']);

        for (var productoData in productosData) {
          var productoConvertido = _procesarIngredientesProducto(
            producto,
            productoData,
          );
          productosResultado.add(productoConvertido);
        }

        return {'multiple': true, 'productos': productosResultado};
      } else {
        // Producto único (caso tradicional)
        return _procesarIngredientesProducto(producto, resultado);
      }
    }

    return resultado;
  }

  // Método auxiliar para procesar ingredientes de un producto individual
  Map<String, dynamic> _procesarIngredientesProducto(
    Producto producto,
    Map<String, dynamic> productoData,
  ) {
    List<String> ingredientesFinales = List<String>.from(
      productoData['ingredientes'],
    );

    // 1. Agregar automáticamente todos los ingredientes requeridos ORIGINALES
    for (var ingrediente in producto.ingredientesRequeridos) {
      if (!ingredientesFinales.contains(ingrediente.ingredienteId)) {
        ingredientesFinales.add(ingrediente.ingredienteId);
        print(
          '✅ Requerido original agregado: ${ingrediente.ingredienteNombre}',
        );
      }
    }

    // 2. 🎯 CONVERTIR ingredientes opcionales seleccionados en REQUERIDOS
    List<IngredienteProducto> nuevosRequeridos = List.from(
      producto.ingredientesRequeridos,
    );

    for (var ingredienteId in ingredientesFinales) {
      // Buscar si este ID corresponde a un ingrediente opcional
      var ingredienteOpcional = producto.ingredientesOpcionales
          .where(
            (opt) =>
                opt.ingredienteId == ingredienteId ||
                opt.ingredienteNombre == ingredienteId,
          )
          .firstOrNull;

      if (ingredienteOpcional != null) {
        // Convertir el opcional en requerido
        var nuevoRequerido = IngredienteProducto(
          ingredienteId: ingredienteOpcional.ingredienteId,
          ingredienteNombre: ingredienteOpcional.ingredienteNombre,
          cantidadNecesaria:
              1.0, // Cantidad estándar para ingredientes seleccionados
          esOpcional: false, // Ya no es opcional
          precioAdicional: ingredienteOpcional.precioAdicional,
        );
        nuevosRequeridos.add(nuevoRequerido);
        print(
          '🔄 CONVERTIDO: ${ingredienteOpcional.ingredienteNombre} (opcional → requerido)',
        );
      }
    }

    // 3. Crear producto actualizado con los nuevos ingredientes requeridos
    final productoActualizado = producto.copyWith(
      ingredientesRequeridos: nuevosRequeridos,
      // ✅ Limpiar los opcionales que ya se convirtieron en requeridos
      ingredientesOpcionales: producto.ingredientesOpcionales.where((opt) {
        return !ingredientesFinales.any(
          (id) => opt.ingredienteId == id || opt.ingredienteNombre == id,
        );
      }).toList(),
    );

    print('📋 PRODUCTO PROCESADO:');
    print(
      '  - Ingredientes opcionales convertidos a requeridos: ${nuevosRequeridos.length - producto.ingredientesRequeridos.length}',
    );
    print('  - Total ingredientes requeridos: ${nuevosRequeridos.length}');
    print('  - Total ingredientes: ${ingredientesFinales.length}');

    return {
      'ingredientes': ingredientesFinales,
      'notas': productoData['notas'],
      'producto_actualizado': productoActualizado,
      'ingredienteOpcional':
          productoData['ingredienteOpcional'], // Para identificar en múltiples
    };
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // 🚀 OPTIMIZACIÓN: Usar datos del provider global
      final datosProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );

      // Si los datos no están inicializados, cargarlos
      if (!datosProvider.hasData) {
        await datosProvider.initialize();
      }

      final productos = datosProvider.productos ?? [];
      final categoriasData = datosProvider.categorias;

      // Si se pasó un pedido existente directamente, usarlo
      if (widget.pedidoExistente != null) {
        print('🔍 Editando pedido existente que se pasó como parámetro');
        print('  - ID: ${widget.pedidoExistente!.id}');
        print('  - Items: ${widget.pedidoExistente!.items.length}');
        print('  - Estado: ${widget.pedidoExistente!.estado}');

        pedidoExistente = widget.pedidoExistente;
        esPedidoExistente = true;

        // Cargar productos del pedido existente en la lista local
        productosMesa = [];
        print(
          '📋 Cargando ${pedidoExistente!.items.length} items del pedido existente',
        );

        for (var item in pedidoExistente!.items) {
          // ✅ CORREGIDO: Limpiar ID malformado antes de buscar
          String cleanProductoId = item.productoId;
          if (cleanProductoId.contains('_')) {
            // ID malformado con timestamp, extraer ID original (primeros 24 caracteres)
            cleanProductoId = cleanProductoId.substring(0, 24);
            print(
              '🔧 ID malformado detectado: ${item.productoId} → limpiado a: $cleanProductoId',
            );
          }

          // Buscar el producto completo en la lista de productos disponibles
          Producto? productoObj = productos.firstWhere(
            (p) => p.id == cleanProductoId,
            orElse: () => _getProductoFromItem(
              item.producto,
              productoId: cleanProductoId,
              forceNonNull: true,
            )!,
          );

          print(
            '📦 Cargando producto: ${productoObj.nombre} (ID limpio: $cleanProductoId) - Imagen: ${productoObj.imagenUrl ?? "Sin imagen"}',
          );

          // Crear una copia del producto con la cantidad y notas del item
          final productoParaMesa = Producto(
            id: cleanProductoId, // ✅ Usar ID limpio en lugar del malformado
            nombre: productoObj.nombre,
            precio: item.precio,
            costo: productoObj.costo,
            utilidad: productoObj.utilidad,
            descripcion: productoObj.descripcion,
            categoria: productoObj.categoria,
            tieneVariantes: productoObj.tieneVariantes,
            imagenUrl: productoObj.imagenUrl,
            ingredientesDisponibles: item.ingredientesSeleccionados,
            cantidad: item.cantidad,
            nota: item.notas,
          );
          productosMesa.add(productoParaMesa);

          // Inicializar el mapa de pagados como activos (true) ya que son productos existentes
          productoPagado[cleanProductoId] = true; // ✅ Usar ID limpio
        }

        // Si el pedido existente tiene cliente, cargarlo
        if (pedidoExistente!.cliente != null &&
            pedidoExistente!.cliente!.isNotEmpty) {
          clienteController.text = pedidoExistente!.cliente!;
          clienteSeleccionado = pedidoExistente!.cliente!;
        }

        // Guardar referencia de productos originales para control de permisos
        productosOriginales = List.from(productosMesa);
        cantidadProductosOriginales = productosMesa.length;

        print(
          '✅ Pedido existente cargado como parámetro. Items: ${productosMesa.length}',
        );
      }
      // Si no hay pedido pasado como parámetro pero la mesa está ocupada, buscar pedido activo
      else if (widget.mesa.ocupada) {
        try {
          print(
            '🔍 Mesa ocupada detectada. Buscando pedido activo para: ${widget.mesa.nombre}',
          );
          final pedidosService = PedidoService();
          final pedidosActivos = await pedidosService.getPedidosByMesa(
            widget.mesa.nombre,
          );

          // Buscar el pedido activo (no pagado/cancelado)
          final pedidoActivo = pedidosActivos
              .where((p) => p.estado == EstadoPedido.activo)
              .toList();

          if (pedidoActivo.isNotEmpty) {
            pedidoExistente = pedidoActivo.first;
            esPedidoExistente = true;

            // Cargar productos del pedido existente en la lista local
            productosMesa = [];
            for (var item in pedidoExistente!.items) {
              // ✅ CORREGIDO: Limpiar ID malformado antes de buscar
              String cleanProductoId = item.productoId;
              if (cleanProductoId.contains('_')) {
                // ID malformado con timestamp, extraer ID original (primeros 24 caracteres)
                cleanProductoId = cleanProductoId.substring(0, 24);
                print(
                  '🔧 ID malformado detectado en mesa ocupada: ${item.productoId} → limpiado a: $cleanProductoId',
                );
              }

              // Buscar el producto completo en la lista de productos disponibles
              Producto? productoObj = productos.firstWhere(
                (p) => p.id == cleanProductoId,
                orElse: () => _getProductoFromItem(
                  item.producto,
                  productoId: cleanProductoId,
                  forceNonNull: true,
                )!,
              );

              print(
                '📦 Cargando producto de mesa ocupada: ${productoObj.nombre} (ID limpio: $cleanProductoId) - Imagen: ${productoObj.imagenUrl ?? "Sin imagen"}',
              );

              final productoParaMesa = Producto(
                id: cleanProductoId, // ✅ Usar ID limpio
                nombre: productoObj.nombre,
                precio: item.precio,
                costo: productoObj.costo,
                utilidad: productoObj.utilidad,
                descripcion: productoObj.descripcion,
                categoria: productoObj.categoria,
                tieneVariantes: productoObj.tieneVariantes,
                imagenUrl: productoObj.imagenUrl,
                ingredientesDisponibles: item.ingredientesSeleccionados,
                cantidad: item.cantidad,
                nota: item.notas,
              );
              productosMesa.add(productoParaMesa);

              // Inicializar el mapa de pagados como activos (true) para productos existentes
              productoPagado[cleanProductoId] = true; // ✅ Usar ID limpio
            }

            // Si el pedido existente tiene cliente, cargarlo
            if (pedidoExistente!.cliente != null &&
                pedidoExistente!.cliente!.isNotEmpty) {
              clienteController.text = pedidoExistente!.cliente!;
              clienteSeleccionado = pedidoExistente!.cliente!;
            }

            // Guardar referencia de productos originales para control de permisos
            productosOriginales = List.from(productosMesa);
            cantidadProductosOriginales = productosMesa.length;

            print('✅ Pedido existente cargado. Items: ${productosMesa.length}');
            print(
              '📝 Productos originales guardados: ${productosOriginales.length}',
            );
          } else {
            print('ℹ️ No se encontró pedido activo, creando nuevo pedido');
            esPedidoExistente = false;

            // Clone existing products from mesa for local editing (fallback)
            if (widget.mesa.productos.isNotEmpty) {
              productosMesa = List.from(widget.mesa.productos);
            }
          }
        } catch (e) {
          print('⚠️ Error cargando pedido existente: $e');
          esPedidoExistente = false;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error cargando pedidos de la mesa'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }

          // Fallback: usar productos de la mesa
          if (widget.mesa.productos.isNotEmpty) {
            productosMesa = List.from(widget.mesa.productos);
          }
        }
      } else {
        // ✅ COMENTADO: Log de mesa disponible removido
        // print('ℹ️ Mesa disponible, creando nuevo pedido');
        esPedidoExistente = false;
        productosMesa = [];
      }

      setState(() {
        productosDisponibles = productos;
        categorias = categoriasData ?? [];
        // Establecer la categoría como "Todos" por defecto
        categoriaSelecionadaId = null;
        _resetearPaginacion();
        isLoading = false;
        _productosFiltered = null; // Reset filtered products on load
        _actualizarProductosVista(); // ✅ Actualizar cache de vista
      });

      // Ya no es necesaria esta verificación ya que siempre queremos mostrar todos los productos
      // pero mantenemos la búsqueda si hay texto en el campo
      if (busquedaController.text.isNotEmpty) {
        _searchProductosAPI(busquedaController.text);
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error al cargar datos: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _agregarProducto(Producto producto) async {
    // --- LÓGICA CORREGIDA: Agrupar productos iguales con mismas características ---
    // Buscar producto existente con mismas características (ID y notas vacías por ahora)

    // Verificamos si es un menú ejecutivo
    bool esEjecutivo = producto.nombre.toLowerCase().contains('ejecutivo');

    // Buscar un producto existente que coincida por ID
    int index = productosMesa.indexWhere(
      (p) =>
          p.id == producto.id &&
          (p.nota == null ||
              p.nota!.isEmpty), // Solo agrupar productos sin notas especiales
    );

    // Si es un ejecutivo y ya hay uno igual en la mesa con carne seleccionada
    if (esEjecutivo &&
        index != -1 &&
        productosCarneMap.containsKey(productosMesa[index].id)) {
      // Encontramos un ejecutivo igual, incrementar cantidad reutilizando la selección de carne
      setState(() {
        productosMesa[index].cantidad++;
        _calcularTotal();
      });
      return;
    }

    // Si no es ejecutivo pero encontramos un producto igual, incrementar cantidad normalmente
    if (!esEjecutivo && index != -1) {
      setState(() {
        productosMesa[index].cantidad++;
        _calcularTotal();
      });
      return;
    }

    // --- Si no existe, seguir con la lógica original para selección de ingredientes/variantes ---
    String? notasEspeciales;
    String? productoCarneId;
    List<String> ingredientesSeleccionados = [];

    bool tieneIngredientesOpcionales =
        producto.ingredientesOpcionales.isNotEmpty;
    bool soloTieneRequeridos =
        producto.ingredientesRequeridos.isNotEmpty &&
        producto.ingredientesOpcionales.isEmpty;

    if (!tieneIngredientesOpcionales &&
        !soloTieneRequeridos &&
        (producto.tieneIngredientes || producto.esCombo)) {
      try {
        final ingredientesRequeridos = await _productoService
            .getIngredientesRequeridosCombo(producto.id);
        final ingredientesOpcionales = await _productoService
            .getIngredientesOpcionalesCombo(producto.id);
        if (ingredientesRequeridos.isNotEmpty ||
            ingredientesOpcionales.isNotEmpty) {
          final productoConIngredientes = producto.copyWith(
            ingredientesRequeridos: ingredientesRequeridos,
            ingredientesOpcionales: ingredientesOpcionales,
          );
          return _agregarProducto(productoConIngredientes);
        }
      } catch (e) {
        // Continuar sin ingredientes si hay error
      }
    }

    Producto productoFinal = producto;

    if (tieneIngredientesOpcionales) {
      final resultadoIngredientes = await _mostrarDialogoSeleccionIngredientes(
        producto,
      );
      if (resultadoIngredientes != null) {
        // Verificar si son múltiples productos
        if (resultadoIngredientes['multiple'] == true &&
            resultadoIngredientes['productos'] != null) {
          // Procesar múltiples productos recursivamente
          List<Map<String, dynamic>> productos =
              List<Map<String, dynamic>>.from(
                resultadoIngredientes['productos'],
              );

          for (var productoData in productos) {
            // Crear un producto temporal con los ingredientes de este producto específico
            List<String> ingredientesEsteProducto = List<String>.from(
              productoData['ingredientes'],
            );
            String? notasEsteProducto = productoData['notas'];
            Producto productoEsteItem =
                productoData['producto_actualizado'] as Producto;
            String? ingredienteOpcional = productoData['ingredienteOpcional'];

            // Crear nota específica para este producto
            String notaFinal = notasEsteProducto ?? '';
            // Comentado: No mostrar ingredientes opcionales en las notas
            // if (ingredienteOpcional != null) {
            //   if (notaFinal.isNotEmpty) {
            //     notaFinal = '$notaFinal - Con $ingredienteOpcional';
            //   } else {
            //     notaFinal = 'Con $ingredienteOpcional';
            //   }
            // }

            // Crear Producto para la mesa
            final productoParaMesa = Producto(
              id: productoEsteItem.id,
              nombre: productoEsteItem.nombre,
              precio: productoEsteItem.precio,
              costo: productoEsteItem.costo,
              impuestos: productoEsteItem.impuestos,
              utilidad: productoEsteItem.utilidad,
              tieneVariantes: productoEsteItem.tieneVariantes,
              estado: productoEsteItem.estado,
              imagenUrl: productoEsteItem.imagenUrl,
              categoria: productoEsteItem.categoria,
              descripcion: productoEsteItem.descripcion,
              nota: notaFinal,
              cantidad: 1,
              ingredientesDisponibles: ingredientesEsteProducto,
              ingredientesRequeridos: productoEsteItem.ingredientesRequeridos,
              ingredientesOpcionales: productoEsteItem.ingredientesOpcionales,
              tieneIngredientes: productoEsteItem.tieneIngredientes,
              tipoProducto: productoEsteItem.tipoProducto,
            );

            print(
              '🍽️ Producto múltiple agregado: ${productoEsteItem.nombre} con $ingredienteOpcional',
            );

            // Agregar a la mesa
            setState(() {
              productosMesa.add(productoParaMesa);
              productoPagado[productoParaMesa.id] = true;
              _calcularTotal();
            });
          }
          return; // Terminar aquí porque ya procesamos todos los productos
        } else {
          // Producto único (caso tradicional)
          ingredientesSeleccionados =
              resultadoIngredientes['ingredientes'] as List<String>;
          notasEspeciales = resultadoIngredientes['notas'] as String?;
          if (resultadoIngredientes.containsKey('producto_actualizado')) {
            productoFinal =
                resultadoIngredientes['producto_actualizado'] as Producto;
          }
        }
      } else {
        return;
      }
    } else if (soloTieneRequeridos) {
      for (var ingrediente in productoFinal.ingredientesRequeridos) {
        ingredientesSeleccionados.add(ingrediente.ingredienteId);
      }
    }

    if (productoFinal.tieneVariantes) {
      bool esAsadoCombinado = productoFinal.nombre.toLowerCase().contains(
        'asado combinado',
      );
      bool esEjecutivo = productoFinal.nombre.toLowerCase().contains(
        'ejecutivo',
      );
      if (esAsadoCombinado || esEjecutivo || productoFinal.tieneVariantes) {
        List<String>? opcionesPersonalizadas;
        if (productoFinal.nombre.toLowerCase().contains('chuzo')) {
          opcionesPersonalizadas = ['Pollo', 'Res', 'Cerdo'];
        } else if (productoFinal.nombre.toLowerCase().contains(
          'asado combinado',
        )) {
          opcionesPersonalizadas = ['Res', 'Cerdo'];
        } else if (productoFinal.nombre.toLowerCase().contains('ejecutivo')) {
          opcionesPersonalizadas = [
            'Res',
            'Cerdo',
            'Pollo',
            'Pechuga',
            'Chicharrón',
          ];
        }
        final resultado = await _mostrarDialogoOpciones(
          productoFinal,
          opcionesPersonalizadas ?? [],
        );
        if (resultado is Map<String, dynamic>) {
          String? notasVariantes = resultado['nota'];
          if (notasEspeciales != null && notasVariantes != null) {
            notasEspeciales = '$notasEspeciales - $notasVariantes';
          } else if (notasVariantes != null) {
            notasEspeciales = notasVariantes;
          }
          productoCarneId = resultado['productoId'];
          if (resultado['cantidad'] != null && resultado['cantidad'] > 1) {
            int cantidadSeleccionada = resultado['cantidad'] as int;
            notasEspeciales =
                "$notasEspeciales (Cantidad: $cantidadSeleccionada)";
          }
          if (resultado['observaciones'] != null &&
              resultado['observaciones'].toString().isNotEmpty) {
            notasEspeciales =
                "$notasEspeciales - ${resultado['observaciones']}";
          }
        } else if (resultado is String) {
          if (notasEspeciales != null) {
            notasEspeciales = '$notasEspeciales - $resultado';
          } else {
            notasEspeciales = resultado;
          }
        }
        if (notasEspeciales == null && ingredientesSeleccionados.isEmpty) {
          return;
        }
      }
    }

    setState(() {
      Producto nuevoProd = Producto(
        id: productoFinal.id,
        nombre: productoFinal.nombre,
        precio: productoFinal.precio,
        costo: productoFinal.costo,
        impuestos: productoFinal.impuestos,
        utilidad: productoFinal.utilidad,
        tieneVariantes: productoFinal.tieneVariantes,
        estado: productoFinal.estado,
        imagenUrl: productoFinal.imagenUrl,
        categoria: productoFinal.categoria,
        descripcion: productoFinal.descripcion,
        nota: notasEspeciales,
        cantidad: 1,
        ingredientesDisponibles: ingredientesSeleccionados,
        ingredientesRequeridos: productoFinal.ingredientesRequeridos,
        ingredientesOpcionales: productoFinal.ingredientesOpcionales,
        tieneIngredientes: productoFinal.tieneIngredientes,
        tipoProducto: productoFinal.tipoProducto,
      );
      productosMesa.add(nuevoProd);
      productoPagado[nuevoProd.id] = true;
      if (productoCarneId != null) {
        productosCarneMap[nuevoProd.id] = productoCarneId;
      }
      _calcularTotal();
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
      // Actualizar el total después de modificar la lista de productos
      _calcularTotal();
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
    // Prevenir múltiples clicks rápidos - timeout de 2 segundos
    final now = DateTime.now();
    if (lastSaveAttempt != null &&
        now.difference(lastSaveAttempt!).inSeconds < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Espere un momento antes de intentar guardar nuevamente',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (isSaving) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Guardando pedido, por favor espere...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    lastSaveAttempt = now;

    try {
      setState(() {
        isLoading = true;
        isSaving = true;
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
          isSaving = false;
        });
        return;
      }

      // ✅ NUEVA VALIDACIÓN SIMPLIFICADA: Todos los productos son "combo" con comportamiento diferente
      Map<String, List<String>> ingredientesPorItem = {};
      Map<String, int> cantidadPorProducto = {};

      for (var producto in productosMesa) {
        List<String> ingredientesIds = [];

        print('🔍 PROCESANDO PRODUCTO: ${producto.nombre}');
        print('   - Tipo: ${producto.tipoProducto}');
        print(
          '   - Ingredientes requeridos: ${producto.ingredientesRequeridos.length}',
        );
        print(
          '   - Ingredientes opcionales: ${producto.ingredientesOpcionales.length}',
        );
        print(
          '   - Ingredientes disponibles (seleccionados): ${producto.ingredientesDisponibles.length}',
        );
        print('🔍 VERIFICACIÓN DE CONSERVACIÓN:');
        print(
          '   - ingredientesRequeridos conservados: ${producto.ingredientesRequeridos.map((i) => i.ingredienteNombre)}',
        );
        print(
          '   - ingredientesOpcionales conservados: ${producto.ingredientesOpcionales.map((i) => i.ingredienteNombre)}',
        );
        print(
          '   - ingredientesDisponibles (seleccionados): ${producto.ingredientesDisponibles}',
        );

        // ✅ ESTRATEGIA SIMPLIFICADA: Todos son "combo" pero con lógica diferente

        // 1. SIEMPRE agregar ingredientes REQUERIDOS (se consumen automáticamente)
        for (var ingredienteReq in producto.ingredientesRequeridos) {
          ingredientesIds.add(ingredienteReq.ingredienteId);
          print(
            '   + REQUERIDO: ${ingredienteReq.ingredienteNombre} (${ingredienteReq.ingredienteId})',
          );
        }

        // 2. Para ingredientes OPCIONALES:
        if (producto.ingredientesOpcionales.isNotEmpty) {
          // Si hay ingredientes opcionales, solo agregar los seleccionados
          print('   🌟 Producto CON opcionales - Solo agregar seleccionados');
          for (var ing in producto.ingredientesDisponibles) {
            final opcional = producto.ingredientesOpcionales.where((i) {
              // Comparar por ID directo
              if (i.ingredienteId == ing) return true;
              // Comparar por nombre exacto
              if (i.ingredienteNombre == ing) return true;
              // Comparar por nombre con precio (ej: "Carne (+$2000)")
              final nombreConPrecio = i.precioAdicional > 0
                  ? '${i.ingredienteNombre} (+\$${i.precioAdicional.toStringAsFixed(0)})'
                  : i.ingredienteNombre;
              if (nombreConPrecio == ing) return true;
              return false;
            });
            if (opcional.isNotEmpty) {
              ingredientesIds.add(opcional.first.ingredienteId);
              print(
                '   + OPCIONAL SELECCIONADO: ${opcional.first.ingredienteNombre} (${opcional.first.ingredienteId}) [SERÁ DESCONTADO DEL INVENTARIO]',
              );
            } else {
              // Podría ser un ID directo
              ingredientesIds.add(ing);
              print('   + DIRECTO: $ing [SERÁ DESCONTADO DEL INVENTARIO]');
            }
          }
        } else {
          // Si NO hay ingredientes opcionales, es un producto "simple"
          // (Solo requeridos, ya agregados arriba)
          print('   ✨ Producto SIN opcionales - Solo ingredientes requeridos');
        }

        // ✅ VERIFICACIÓN CRÍTICA: Todos los ingredientes deben ser descontados igual
        print('   🎯 RESUMEN PARA INVENTARIO:');
        print(
          '      - Total ingredientes a descontar: ${ingredientesIds.length}',
        );
        print('      - IDs que se enviarán al inventario: $ingredientesIds');
        print(
          '      - TODOS estos ingredientes deben ser descontados por igual',
        );

        print('   ✅ Total ingredientes finales: ${ingredientesIds.length}');
        print('   ✅ IDs: $ingredientesIds');

        ingredientesPorItem[producto.id] = ingredientesIds;
        cantidadPorProducto[producto.id] = producto.cantidad;
      } // Validar stock disponible antes de crear el pedido
      final validacionStock = await InventarioService()
          .validarStockAntesDePedido(ingredientesPorItem, cantidadPorProducto);

      if (!validacionStock['stockSuficiente']) {
        setState(() {
          isLoading = false;
          isSaving = false;
        });

        // ✅ COMENTADO: Mensaje de stock insuficiente removido por solicitud del usuario
        // Ya no se muestra el diálogo molesto - el inventario se procesa correctamente
        print(
          'ℹ️ Validación de stock falló, pero continuando con el pedido...',
        );

        // ✅ CONTINUAR directamente con la creación del pedido sin mostrar error
        await _continuarConCreacionPedido();
        return; // Salir aquí para evitar procesamiento duplicado
      }

      // Si hay alertas de stock bajo pero suficiente, mostrar advertencia
      if (validacionStock['alertas'] != null &&
          (validacionStock['alertas'] as List).isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Algunos ingredientes tienen stock bajo'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Continuar con la lógica original del pedido
      await _continuarConCreacionPedido();
    } catch (e) {
      setState(() {
        isLoading = false;
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar pedido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ EXTRAÍDO: Lógica principal de creación de pedido
  Future<void> _continuarConCreacionPedido() async {
    String? clienteFinal = clienteSeleccionado;

    // Si es un domicilio y no hay cliente, pedir el lugar de destino
    if (widget.mesa.nombre.toUpperCase() == 'DOMICILIO' &&
        (clienteSeleccionado == null || clienteSeleccionado!.isEmpty)) {
      final lugarDomicilio = await _pedirLugarDomicilio();

      if (lugarDomicilio == null || lugarDomicilio.isEmpty) {
        // El usuario canceló
        setState(() {
          isLoading = false;
          isSaving = false;
        });
        return;
      }

      clienteFinal = lugarDomicilio;
    }

    // Obtener el usuario actual (lo movemos aquí para usarlo en los items)
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final meseroActual = userProvider.userName ?? 'Usuario Desconocido';

    // Crear los items del pedido
    List<ItemPedido> items = productosMesa.map((producto) {
      // ✅ ESTRATEGIA SIMPLIFICADA: Todos son "combo" con lógica unificada
      List<String> ingredientesIds = [];

      print('📦 CREANDO ITEM PARA: ${producto.nombre}');

      // 1. SIEMPRE agregar ingredientes REQUERIDOS
      for (var ingredienteReq in producto.ingredientesRequeridos) {
        ingredientesIds.add(ingredienteReq.ingredienteId);
        print('   + Item REQUERIDO: ${ingredienteReq.ingredienteNombre}');
      }

      // 2. Para ingredientes OPCIONALES, solo los seleccionados
      if (producto.ingredientesOpcionales.isNotEmpty) {
        print('   🌟 Item CON opcionales - Solo seleccionados');
        for (var ing in producto.ingredientesDisponibles) {
          final opcional = producto.ingredientesOpcionales.where(
            (i) => i.ingredienteId == ing || i.ingredienteNombre == ing,
          );
          if (opcional.isNotEmpty) {
            ingredientesIds.add(opcional.first.ingredienteId);
            print(
              '   + Item OPCIONAL: ${opcional.first.ingredienteNombre} [SERÁ DESCONTADO]',
            );
          } else {
            ingredientesIds.add(ing);
            print('   + Item DIRECTO: $ing [SERÁ DESCONTADO]');
          }
        }
      } else {
        print('   ✨ Item SIN opcionales - Solo requeridos');
      }

      print('   📦 Total ingredientes en item: ${ingredientesIds.length}');
      return ItemPedido(
        productoId: producto.id,
        cantidad: producto.cantidad,
        precioUnitario: producto.precio,
        notas: producto.nota, // Pasar las notas con opciones específicas
        ingredientesSeleccionados: ingredientesIds,
        productoNombre: producto.nombre,
        agregadoPor: userProvider.userName ?? 'Usuario Desconocido',
        fechaAgregado: DateTime.now(),
      );
    }).toList();

    // ✅ CORREGIDO: Calcular total usando ItemPedido.subtotal según la guía
    double total = items.fold(0.0, (sum, item) => sum + item.subtotal,
    );

    // Determinar el tipo de pedido basado en la mesa
    TipoPedido tipoPedido = TipoPedido.normal;
    if (widget.mesa.nombre.toUpperCase() == 'DOMICILIO') {
      tipoPedido = TipoPedido.domicilio;
    }

    Pedido pedidoFinal;

    if (esPedidoExistente && pedidoExistente != null) {
      // ACTUALIZAR PEDIDO EXISTENTE
      print('🔄 Actualizando pedido existente: ${pedidoExistente!.id}');

      final pedidoActualizado = Pedido(
        id: pedidoExistente!.id, // Mantener el ID existente
        fecha: pedidoExistente!.fecha, // Mantener la fecha original
        tipo: pedidoExistente!.tipo, // Mantener el tipo original
        mesa: widget.mesa.nombre,
        mesero: pedidoExistente!.mesero, // Mantener el mesero original
        items: items,
        total: total,
        estado: EstadoPedido.activo,
        notas: observacionesController.text.trim().isEmpty
            ? ""
            : observacionesController.text.trim(),
        cliente:
            clienteFinal ??
            pedidoExistente!
                .cliente, // Usar cliente existente si no hay uno nuevo
      );

      // Actualizar el pedido en el backend
      pedidoFinal = await PedidoService().updatePedido(pedidoActualizado);

      print('✅ Pedido actualizado correctamente');
    } else {
      // CREAR NUEVO PEDIDO
      print('🆕 Creando nuevo pedido para mesa: ${widget.mesa.nombre}');

      final nuevoPedido = Pedido(
        id: '',
        fecha: DateTime.now(),
        tipo: tipoPedido,
        mesa: widget.mesa.nombre,
        mesero: meseroActual,
        items: items,
        total: total,
        estado: EstadoPedido.activo,
        notas: observacionesController.text.trim().isEmpty
            ? ""
            : observacionesController.text.trim(),
        cliente: clienteFinal,
      );

      // Crear el pedido en el backend
      pedidoFinal = await PedidoService().createPedido(nuevoPedido);

      print('✅ Nuevo pedido creado correctamente');
      print(
        '📊 Pedido registrado para ventas - ID: ${pedidoFinal.id}, Total: ${formatCurrency(total)}',
      );
    }

    // Descontar productos de carne del inventario si existen
    await _descontarCarnesDelInventario();

    // Verificar si es una mesa especial
    final mesasEspeciales = ['DOMICILIO', 'CAJA', 'MESA AUXILIAR'];
    bool esMesaEspecial = mesasEspeciales.contains(
      widget.mesa.nombre.toUpperCase(),
    );

    if (esMesaEspecial) {
      // Para mesas especiales, los pedidos se guardan como individuales
      // Asegurar que cada pedido mantiene su estado independiente
      print(
        '✅ Mesa especial: ${widget.mesa.nombre} - Pedido guardado como individual',
      );
      print('📝 ID del pedido: ${pedidoFinal.id}');
      print('💰 Total del pedido: ${formatCurrency(total)}');

      // NO crear factura automática para permitir pedidos múltiples independientes
      _mostrarMensajeExito(pedidoFinal.id, total);
    } else {
      // Para mesas normales, actualizar el estado de la mesa
      widget.mesa.ocupada = true;
      widget.mesa.total = total;
      await _mesaService.updateMesa(widget.mesa);

      _mostrarMensajeExito(pedidoFinal.id, total);
    }

    setState(() {
      isLoading = false;
      isSaving = false;
    });

    // ✅ Regresar INMEDIATAMENTE a la pantalla anterior (Mesas) para mejor UX
    // No esperar a que se recargue el caché
    Navigator.of(context).pop(true);

    // ✅ OPTIMIZACIÓN: Invalidar caché EN SEGUNDO PLANO después de navegar
    // Esto evita el delay de 10 segundos al guardar el pedido
    Future.delayed(Duration.zero, () async {
      try {
        final datosProvider = Provider.of<DatosCacheProvider>(
          context,
          listen: false,
        );
        // Forzar actualización de productos por si cambió inventario
        await datosProvider.forceRefreshProductos();
        print('✅ Cache invalidado en segundo plano después de guardar pedido');
      } catch (e) {
        print('⚠️ Error invalidando caché en segundo plano: $e');
      }
    });
  }

  void _mostrarMensajeExito(String pedidoId, double total) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pedido #$pedidoId guardado exitosamente - Total: \$${total.toStringAsFixed(0)}',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Color(0xFFFF6B00);
    final Color bgDark = Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          '${widget.mesa.nombre} - ${esPedidoExistente ? 'Agregar productos' : 'Nuevo pedido'}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        elevation: 0,
        actions: [
          // Cache status indicator
          CacheHelpers.buildCacheStatus(context),
          // Refresh button with cache logic
          CacheHelpers.buildRefreshButton(
            context,
            onPressed: () async {
              await _loadData();
            },
          ),
          IconButton(
            icon: Icon(Icons.category),
            tooltip: 'Gestionar Categorías',
            onPressed: () async {
              await Navigator.pushNamed(context, '/categorias');
              if (mounted) {
                await _loadData();
              }
            },
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

    // Detectar si es móvil
    final isMovil = MediaQuery.of(context).size.width < 768;

    if (isMovil) {
      // Layout móvil con pestañas
      return _buildMobileLayout();
    } else {
      // Layout desktop/tablet con 2 columnas
      return Row(
        children: [
          // Panel izquierdo - Productos disponibles
          Expanded(
            flex: 3, // Aumentado de 2 a 3 para dar más espacio a las imágenes
            child: Column(
              children: [
                // Barra de búsqueda
                Padding(
                  padding: EdgeInsets.all(16),
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
                    // No necesitamos onChanged ya que usamos el listener en initState
                  ),
                ),

                // Caja de observaciones del pedido
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: observacionesController,
                    style: TextStyle(color: textLight),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Observaciones del pedido...',
                      hintStyle: TextStyle(color: textLight.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.note_add, color: primary),
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
                  ),
                ),

                // Campo del cliente para mesas especiales
                if ([
                  'DOMICILIO',
                  'CAJA',
                  'MESA AUXILIAR',
                ].contains(widget.mesa.nombre.toUpperCase()))
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: clienteController,
                      style: TextStyle(color: textLight),
                      decoration: InputDecoration(
                        hintText: 'Nombre del cliente...',
                        hintStyle: TextStyle(color: textLight.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.person, color: primary),
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
                          clienteSeleccionado = value.trim().isNotEmpty
                              ? value.trim()
                              : null;
                        });
                      },
                    ),
                  ),

                // Filtro de categorías - Scroll horizontal con 2 filas
                Container(
                  height: 110, // Altura para mostrar 2 filas
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  child: Scrollbar(
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: _buildCategoriaGridColumns()),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                // Lista de productos disponibles
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          // ✅ OPTIMIZACIÓN: Usar delegado con extent máximo para mejor rendimiento
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent:
                                    MediaQuery.of(context).size.width > 1200
                                    ? 300 // Máximo 300px por tarjeta en desktop
                                    : MediaQuery.of(context).size.width > 800
                                    ? 250 // 250px en tablet
                                    : 180, // 180px en móvil
                                childAspectRatio: 1.0,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          // ✅ OPTIMIZACIÓN: Cachear lista filtrada para evitar recálculos
                          itemCount: _productosVista.length,
                          itemBuilder: (context, index) {
                            return _buildProductoDisponible(
                              _productosVista[index],
                            );
                          },
                          // ✅ OPTIMIZACIÓN: Agregar caching para mejor scroll
                          cacheExtent: 500, // Pre-render 500px adicionales
                        ),
                      ),

                      // Botón "Ver más" si hay más productos disponibles
                      if (categoriaSelecionadaId != null &&
                          !_mostrandoTodos &&
                          _todosProductosFiltrados.length >
                              _productosVista.length)
                        Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _actualizarProductosVista(cargarMas: true);
                              });
                            },
                            icon: Icon(Icons.expand_more),
                            label: Text(
                              'Ver más productos (${_todosProductosFiltrados.length - _productosVista.length} restantes)',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFFF6B00),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Panel derecho - Productos en el pedido
          Container(
            width:
                370, // Aumentado de 350 a 370 para mejor legibilidad del texto
            decoration: BoxDecoration(
              color: cardBg.withOpacity(0.3),
              border: Border(
                left: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
              ),
            ),
            child: Column(
              children: [
                // Encabezado del pedido
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12), // Reducido de 16 a 12
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    'PEDIDO - ${widget.mesa.nombre}',
                    style: TextStyle(
                      color: primary,
                      fontSize: 14, // Reducido de 16 a 14
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Lista de productos en el pedido
                if (productosMesa.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(8), // Reducido de 12 a 8
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mensaje informativo para usuarios no admin con pedidos existentes
                          if (!Provider.of<UserProvider>(
                                context,
                                listen: false,
                              ).isAdmin &&
                              esPedidoExistente &&
                              cantidadProductosOriginales > 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6, // Reducido el padding
                                vertical: 2, // Reducido el padding
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  8,
                                ), // Reducido el radio
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue,
                                    size: 12, // Reducido el tamaño del ícono
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Solo agregar nuevos',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize:
                                          9, // Reducido el tamaño de fuente
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          SizedBox(height: 6), // Reducido el espaciado

                          Expanded(
                            // Hacer scrollable la lista de productos
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  ...productosMesa.map(
                                    (producto) =>
                                        _buildProductoEnPedido(producto),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Divider(
                            color: textLight.withOpacity(0.3),
                            height: 12,
                          ), // Reducido la altura

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total:',
                                style: TextStyle(
                                  color: textLight,
                                  fontSize: 14, // Reducido el tamaño de fuente
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                formatCurrency(_calcularTotal()),
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 18, // Reducido el tamaño de fuente
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 48, // Reducido de 64 a 48
                            color: textLight.withOpacity(0.3),
                          ),
                          SizedBox(height: 12), // Reducido de 16 a 12
                          Text(
                            'No hay productos\nen el pedido',
                            style: TextStyle(
                              color: textLight.withOpacity(0.5),
                              fontSize: 14, // Reducido de 16 a 14
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Botón de guardar en la parte inferior del panel derecho
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12), // Reducido de 16 a 12
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: (isLoading || isSaving)
                        ? null
                        : () => _guardarPedido(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                      ), // Reducido de 16 a 12
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          8,
                        ), // Reducido de 10 a 8
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSaving)
                          SizedBox(
                            width: 18, // Reducido de 20 a 18
                            height: 18, // Reducido de 20 a 18
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        else
                          Icon(Icons.save, size: 18), // Reducido de 20 a 18
                        SizedBox(width: 6), // Reducido de 8 a 6
                        Flexible(
                          // Añadido Flexible para evitar overflow
                          child: Text(
                            isSaving
                                ? 'Guardando...'
                                : (esPedidoExistente
                                      ? 'Actualizar' // Texto más corto
                                      : 'Guardar'), // Texto más corto
                            style: TextStyle(
                              fontSize: 14, // Reducido el tamaño de fuente
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow
                                .ellipsis, // Evitar overflow de texto
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  // Nuevo método para layout móvil con pestañas
  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Barra de pestañas
          Container(
            color: Color(0xFF252525),
            child: TabBar(
              labelColor: Color(0xFFFF6B00),
              unselectedLabelColor: Color(0xFFE0E0E0),
              indicatorColor: Color(0xFFFF6B00),
              tabs: [
                Tab(icon: Icon(Icons.restaurant_menu), text: 'Productos'),
                Tab(
                  icon: Icon(Icons.shopping_cart),
                  text: 'Pedido (${productosMesa.length})',
                ),
              ],
            ),
          ),
          // Contenido de las pestañas
          Expanded(
            child: TabBarView(
              children: [
                // Pestaña 1: Lista de productos
                _buildProductsTab(),
                // Pestaña 2: Carrito/Pedido
                _buildCartTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pestaña de productos para móvil
  Widget _buildProductsTab() {
    final Color primary = Color(0xFFFF6B00);
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);

    return Column(
      children: [
        // Barra de búsqueda
        Padding(
          padding: EdgeInsets.all(16),
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
          ),
        ),

        // Campo del cliente para mesas especiales
        if ([
          'DOMICILIO',
          'CAJA',
          'MESA AUXILIAR',
        ].contains(widget.mesa.nombre.toUpperCase()))
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: clienteController,
              style: TextStyle(color: textLight),
              decoration: InputDecoration(
                hintText: 'Nombre del cliente...',
                hintStyle: TextStyle(color: textLight.withOpacity(0.5)),
                prefixIcon: Icon(Icons.person, color: primary),
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
            ),
          ),

        // Lista de categorías - Scroll horizontal con 2 filas
        if (categorias.isNotEmpty)
          Container(
            height: 110, // Altura para 2 filas en móvil
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _buildCategoriaGridColumnsMobile()),
              ),
            ),
          ),

        // Lista de productos
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 columnas para móvil
                    childAspectRatio: 1.1, // Proporción más cuadrada para móvil
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _productosVista.length,
                  itemBuilder: (context, index) {
                    return _buildProductoDisponible(_productosVista[index]);
                  },
                ),
              ),

              // Botón "Ver más" si hay más productos disponibles
              if (categoriaSelecionadaId != null &&
                  !_mostrandoTodos &&
                  _todosProductosFiltrados.length > _productosVista.length)
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _actualizarProductosVista(cargarMas: true);
                      });
                    },
                    icon: Icon(Icons.expand_more),
                    label: Text(
                      'Ver más (${_todosProductosFiltrados.length - _productosVista.length} restantes)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Pestaña del carrito para móvil
  Widget _buildCartTab() {
    final Color primary = Color(0xFFFF6B00);
    final Color textLight = Color(0xFFE0E0E0);

    return Column(
      children: [
        // Encabezado del pedido
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(color: primary.withOpacity(0.3), width: 1),
            ),
          ),
          child: Text(
            'PEDIDO - ${widget.mesa.nombre}',
            style: TextStyle(
              color: primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Lista de productos en el pedido
        Expanded(
          child: productosMesa.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No hay productos\nen el pedido',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    children: [
                      ...productosMesa.map(
                        (producto) => _buildProductoEnPedido(producto),
                      ),
                    ],
                  ),
                ),
        ),

        // Total y botón de guardar
        if (productosMesa.isNotEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF252525),
              border: Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
              ),
            ),
            child: Column(
              children: [
                // Total
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Botón de guardar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : _guardarPedido,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      disabledBackgroundColor: primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            esPedidoExistente
                                ? 'Actualizar Pedido'
                                : 'Guardar Pedido',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Método de filtrado local optimizado usando DatosCacheProvider (fallback para cuando la API no está disponible)
  List<Producto> _filtrarProductosLocal() {
    // Obtener productos frescos del provider en lugar de usar productosDisponibles
    final datosProvider = Provider.of<DatosCacheProvider>(
      context,
      listen: false,
    );
    final productosCache = datosProvider.productos ?? [];

    // Si no hay filtros, devolver todos los productos (desde caché)
    if (filtro.isEmpty && categoriaSelecionadaId == null) {
      return productosCache;
    }

    return productosCache.where((producto) {
      // Filtrado por nombre mejorado - busca coincidencias parciales en nombre
      // También busca coincidencias en descripción, categoría y otros campos relevantes
      bool matchesNombre = false;
      if (filtro.isEmpty) {
        matchesNombre = true;
      } else {
        // Dividir la búsqueda en palabras clave y verificar si todas están en alguna parte
        final palabrasClave = filtro
            .toLowerCase()
            .split(' ')
            .where((palabra) => palabra.trim().isNotEmpty)
            .toList();

        if (palabrasClave.isEmpty) {
          matchesNombre = true;
        } else {
          // Verificar si todas las palabras clave están contenidas en el nombre
          final nombreLower = producto.nombre.toLowerCase();
          final descripcionLower = producto.descripcion?.toLowerCase() ?? '';
          final categoriaLower = producto.categoria?.nombre.toLowerCase() ?? '';

          matchesNombre = palabrasClave.every(
            (palabra) =>
                nombreLower.contains(palabra) ||
                descripcionLower.contains(palabra) ||
                categoriaLower.contains(palabra),
          );
        }
      }

      // Filtrado por categoría
      bool matchesCategoria =
          categoriaSelecionadaId == null ||
          producto.categoria?.id == categoriaSelecionadaId;

      return matchesNombre && matchesCategoria;
    }).toList();
  }

  // ✅ OPTIMIZADA: Implementación que usa cache para evitar recálculos
  List<Producto> _filtrarProductos() {
    // Si hay productos filtrados por la API, aplicar también el filtro de categoría
    final productos = _productosFiltered ?? productosDisponibles;
    if (categoriaSelecionadaId == null) return productos;
    return productos
        .where((producto) => producto.categoria?.id == categoriaSelecionadaId)
        .toList();
  }

  // Variables para manejar paginación
  List<Producto> _todosProductosFiltrados = [];
  int _paginaActual = 1;
  int _productosPorPagina = 10;
  bool _mostrandoTodos = false;

  // ✅ MEJORADO: Actualizar cache de productos para vista con paginación
  void _actualizarProductosVista({bool cargarMas = false}) {
    // Primero obtener todos los productos filtrados
    _todosProductosFiltrados = _filtrarProductos();

    // Implementar paginación: mostrar productos según página actual
    if (categoriaSelecionadaId != null && !_mostrandoTodos) {
      // Si hay una categoría seleccionada, aplicar paginación
      int itemsToShow = _paginaActual * _productosPorPagina;

      // Si se están cargando más, incrementar página
      if (cargarMas) {
        _paginaActual++;
        itemsToShow = _paginaActual * _productosPorPagina;
      }

      // Limitar a la cantidad disponible
      if (itemsToShow > _todosProductosFiltrados.length) {
        itemsToShow = _todosProductosFiltrados.length;
        _mostrandoTodos = true;
      }

      _productosVista = _todosProductosFiltrados.take(itemsToShow).toList();
    } else {
      // Si no hay categoría seleccionada o se están mostrando todos, mostrar todos
      _productosVista = _todosProductosFiltrados;
      _mostrandoTodos = true;
    }

    // Log de diagnóstico
    print(
      '📊 Productos filtrados: ${_todosProductosFiltrados.length}, mostrados: ${_productosVista.length}, página: $_paginaActual',
    );
  }

  // Resetear paginación al cambiar categoría o búsqueda
  void _resetearPaginacion() {
    _paginaActual = 1;
    _mostrandoTodos = false;
  }

  double _calcularTotal() {
    // ✅ CORREGIDO: Crear ItemPedido temporales para cálculo correcto usando subtotal
    final itemsTemporales = productosMesa
        .map(
          (producto) => ItemPedido(
            productoId: producto.id,
            cantidad: producto.cantidad,
            precioUnitario: producto.precio,
            productoNombre: producto.nombre,
          ),
        )
        .toList();

    double total = itemsTemporales.fold(0.0, (sum, item) {
      // Solo incluir productos activos (no tachados) en el total
      if (productoPagado[item.productoId] != false) {
        return sum + item.subtotal; // ✅ Usar subtotal según la guía
      }
      return sum;
    });
    setState(() {}); // Forzar actualización de la UI
    return total;
  }

  Widget _buildProductoDisponible(Producto producto) {
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);
    final Color primary = Color(0xFFFF6B00);

    // Categoría etiqueta
    final String categoriaText = producto.categoria?.nombre ?? 'Sin categoría';

    return GestureDetector(
      onTap: () async {
        // Si el producto tiene ingredientes opcionales, usar la función completa que maneja múltiples
        if (producto.ingredientesOpcionales.isNotEmpty) {
          // ✅ ARREGLADO: Usar la función _agregarProducto que maneja múltiples correctamente
          await _agregarProducto(producto);
        } else {
          // Si no tiene ingredientes opcionales, usar la lógica normal
          await _agregarProducto(producto);
        }
      },
      child: Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Imagen del producto
            Expanded(
              flex: 5, // Mayor espacio para la imagen
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(6),
                child: _buildProductImage(
                  producto.imagenUrl,
                  producto: producto,
                ),
              ),
            ),
            // Información del producto (categoría, nombre, precio)
            Expanded(
              flex: 2, // Menos espacio para el texto
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Etiqueta de categoría
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      categoriaText,
                      style: TextStyle(
                        color: primary,
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Nombre del producto
                  Text(
                    producto.nombre,
                    style: TextStyle(
                      color: textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Precio
                  Text(
                    formatCurrency(producto.precio),
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(
    String? imagenUrl, {
    Producto? producto,
    double? width,
    double? height,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        // 🖼️ Usar imagen simple si producto es null o tiene URL
        child: producto != null
            ? LazyProductImageWidget(
                producto: producto,
                width: width ?? 60,
                height: height ?? 60,
                fit: BoxFit.cover,
                backendBaseUrl: EndpointsConfig.baseUrl,
              )
            : ImagenProductoWidget(
                urlRemota: imagenUrl != null
                    ? _imageService.getImageUrl(imagenUrl)
                    : null,
                width: width ?? double.infinity,
                height: height ?? double.infinity,
                fit: BoxFit.cover,
                backendBaseUrl: EndpointsConfig.baseUrl,
              ),
      ),
    );
  }

  Widget _buildProductoEnPedido(Producto producto) {
    final Color textLight = Color(0xFFE0E0E0);
    final Color primary = Color(0xFFFF6B00);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Determinar si este producto puede ser eliminado
    bool puedeEliminar = userProvider.isAdmin;
    bool esProductoOriginal = false;

    // Si no es admin y es un pedido existente, verificar si el producto era original
    if (!userProvider.isAdmin && esPedidoExistente) {
      int indexActual = productosMesa.indexOf(producto);
      if (indexActual >= 0 && indexActual < cantidadProductosOriginales) {
        puedeEliminar = false; // No puede eliminar productos originales
        esProductoOriginal = true;
      } else {
        puedeEliminar = true; // Puede eliminar productos nuevos que agregó
        esProductoOriginal = false;
      }
    } else if (!userProvider.isAdmin && !esPedidoExistente) {
      // Si no es admin pero está creando un pedido nuevo, puede eliminar cualquier producto
      puedeEliminar = true;
      esProductoOriginal = false;
    }

    // Inicializar el estado de pago si no existe
    productoPagado.putIfAbsent(producto.id, () => true);

    // Detectar si es móvil para ajustar el layout
    final isMovil = MediaQuery.of(context).size.width < 768;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(isMovil ? 12 : 8),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primary.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Imagen pequeña del producto
              Container(
                margin: EdgeInsets.only(right: 8),
                child: _buildProductImage(
                  producto.imagenUrl,
                  producto: producto,
                  width: isMovil ? 50 : 40,
                  height: isMovil ? 50 : 40,
                ),
              ),

              // Información del producto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            producto.nombre,
                            style: TextStyle(
                              color: textLight,
                              fontSize: isMovil ? 16 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: isMovil ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Indicadores visuales (solo desktop)
                        if (!userProvider.isAdmin &&
                            esPedidoExistente &&
                            !isMovil)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            margin: EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: esProductoOriginal
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              esProductoOriginal ? 'Guardado' : 'Nuevo',
                              style: TextStyle(
                                color: esProductoOriginal
                                    ? Colors.blue
                                    : Colors.orange,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (producto.nota != null && producto.nota!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          producto.nota!,
                          style: TextStyle(
                            color: productoPagado[producto.id]!
                                ? primary.withOpacity(0.7)
                                : primary.withOpacity(0.3),
                            fontSize: isMovil ? 12 : 11,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: isMovil ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isMovil ? 12 : 8),

          // Controles de cantidad y precio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Controles de cantidad
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle,
                      color: (productoPagado[producto.id]! && puedeEliminar)
                          ? Colors.red
                          : Colors.grey.withOpacity(0.3),
                    ),
                    onPressed: (productoPagado[producto.id]! && puedeEliminar)
                        ? () => _eliminarProducto(producto)
                        : null,
                    iconSize: isMovil ? 24 : 20,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMovil ? 16 : 12,
                      vertical: isMovil ? 8 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${producto.cantidad}',
                      style: TextStyle(
                        color: textLight,
                        fontSize: isMovil ? 18 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.green),
                    onPressed: () {
                      // Incrementar cantidad del producto existente en lugar de añadir uno nuevo
                      // Esto mantendrá los ingredientes opcionales ya seleccionados
                      setState(() {
                        producto.cantidad++;
                        _calcularTotal();
                      });
                    },
                    iconSize: isMovil ? 24 : 20,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),

              // Precio - ✅ CORREGIDO: Crear ItemPedido temporal para subtotal correcto
              Builder(
                builder: (context) {
                  final itemTemporal = ItemPedido(
                    productoId: producto.id,
                    cantidad: producto.cantidad,
                    precioUnitario: producto.precio,
                    productoNombre: producto.nombre,
                  );
                  return Text(
                    formatCurrency(
                      itemTemporal.subtotal,
                    ), // ✅ Usar subtotal según la guía
                    style: TextStyle(
                      color: productoPagado[producto.id]!
                          ? primary
                          : primary.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: isMovil ? 18 : 13,
                    ),
                  );
                },
              ),
            ],
          ),

          // Switch de admin en móvil (abajo)
          if (userProvider.isAdmin && isMovil)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Producto activo:',
                    style: TextStyle(color: textLight, fontSize: 14),
                  ),
                  Switch(
                    value: productoPagado[producto.id]!,
                    onChanged: (bool value) {
                      setState(() {
                        productoPagado[producto.id] = value;
                        _calcularTotal();
                      });
                    },
                    activeThumbColor: primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> _pedirLugarDomicilio() async {
    final TextEditingController nombreController = TextEditingController();

    return await showDialog<String>(
      context: context,
      barrierDismissible: false, // No permitir cerrar tocando fuera
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF252525),
          title: Text(
            'Lugar de Domicilio',
            style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa el lugar de destino para este domicilio:',
                style: TextStyle(color: Color(0xFFE0E0E0).withOpacity(0.8)),
              ),
              SizedBox(height: 16),
              TextField(
                controller: nombreController,
                style: TextStyle(color: Color(0xFFE0E0E0)),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ej: Casa Juan, Oficina ABC, Calle 123...',
                  hintStyle: TextStyle(
                    color: Color(0xFFE0E0E0).withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: Color(0xFF252525).withOpacity(0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Color(0xFFFF6B00).withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFFF6B00), width: 2),
                  ),
                  prefixIcon: Icon(Icons.location_on, color: Color(0xFFFF6B00)),
                ),
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFFE0E0E0).withOpacity(0.7)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final texto = nombreController.text.trim();
                if (texto.isNotEmpty) {
                  Navigator.of(context).pop(texto);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Por favor ingresa un lugar de destino'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF6B00),
                foregroundColor: Colors.white,
              ),
              child: Text('Continuar'),
            ),
          ],
        );
      },
    );
  }

  // Genera columnas con 2 filas de categorías (Desktop)
  List<Widget> _buildCategoriaGridColumns() {
    List<Widget> allCategories = [];

    // Agregar opción "Todos"
    allCategories.add(
      _buildCategoriaChip(
        nombre: 'Todos',
        isSelected: categoriaSelecionadaId == null,
        onTap: () => setState(() {
          categoriaSelecionadaId = null;
          _resetearPaginacion();
          _actualizarProductosVista();
        }),
      ),
    );

    // Agregar todas las categorías
    allCategories.addAll(
      categorias.map(
        (categoria) => _buildCategoriaChip(
          nombre: categoria.nombre,
          imagenUrl: categoria.imagenUrl,
          isSelected: categoriaSelecionadaId == categoria.id,
          onTap: () => setState(() {
            categoriaSelecionadaId = categoria.id;
            _resetearPaginacion();
            _actualizarProductosVista();
          }),
        ),
      ),
    );

    // Dividir en 2 filas y crear columnas
    List<Widget> columns = [];
    int itemsPerColumn = 2; // 2 filas

    for (int i = 0; i < allCategories.length; i += itemsPerColumn) {
      List<Widget> columnItems = allCategories
          .skip(i)
          .take(itemsPerColumn)
          .toList();

      // Si solo hay un elemento en la columna, agregar un espaciador
      if (columnItems.length == 1) {
        columnItems.add(SizedBox(height: 50));
      }

      columns.add(
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: columnItems,
          ),
        ),
      );
    }

    return columns;
  }

  // Genera columnas con 2 filas de categorías (Mobile)
  List<Widget> _buildCategoriaGridColumnsMobile() {
    List<Widget> allCategories = [];

    // Agregar opción "Todos"
    allCategories.add(
      _buildCategoriaChipMobile(
        nombre: 'Todos',
        isSelected: categoriaSelecionadaId == null,
        onTap: () => setState(() {
          categoriaSelecionadaId = null;
          _resetearPaginacion();
          _actualizarProductosVista();
        }),
      ),
    );

    // Agregar todas las categorías
    allCategories.addAll(
      categorias.map(
        (categoria) => _buildCategoriaChipMobile(
          nombre: categoria.nombre,
          imagenUrl: categoria.imagenUrl,
          isSelected: categoriaSelecionadaId == categoria.id,
          onTap: () => setState(() {
            categoriaSelecionadaId = categoria.id;
            _resetearPaginacion();
            _actualizarProductosVista();
          }),
        ),
      ),
    );

    // Dividir en 2 filas y crear columnas
    List<Widget> columns = [];
    int itemsPerColumn = 2; // 2 filas

    for (int i = 0; i < allCategories.length; i += itemsPerColumn) {
      List<Widget> columnItems = allCategories
          .skip(i)
          .take(itemsPerColumn)
          .toList();

      // Si solo hay un elemento en la columna, agregar un espaciador
      if (columnItems.length == 1) {
        columnItems.add(SizedBox(height: 50));
      }

      columns.add(
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: columnItems,
          ),
        ),
      );
    }

    return columns;
  }

  // Widget helper para categorías en móvil
  Widget _buildCategoriaChipMobile({
    required String nombre,
    String? imagenUrl,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primary = Color(0xFFFF6B00);
    final cardBg = Color(0xFF2A2A2A);
    final textLight = Color(0xFFB0B0B0);

    return Container(
      margin: EdgeInsets.only(bottom: 4, right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primary : cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? primary : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Text(
            nombre,
            style: TextStyle(
              color: isSelected ? Colors.white : textLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // Widget para chips de categoría con imagen circular
  Widget _buildCategoriaChip({
    required String nombre,
    String? imagenUrl,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primary = Color(0xFFFF6B00);
    final cardBg = Color(0xFF2A2A2A);
    final textLight = Color(0xFFB0B0B0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primary : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Imagen circular o icono
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.3),
              ),
              child: ClipOval(
                child: imagenUrl != null && imagenUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _imageService.getImageUrl(imagenUrl),
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Icon(
                          Icons.restaurant_menu,
                          color: isSelected ? Colors.white : textLight,
                          size: 18,
                        ),
                        placeholder: (context, url) => Icon(
                          Icons.restaurant_menu,
                          color: isSelected ? Colors.white : textLight,
                          size: 18,
                        ),
                      )
                    : Icon(
                        nombre == 'Todas' ? Icons.apps : Icons.restaurant_menu,
                        color: isSelected ? Colors.white : textLight,
                        size: 18,
                      ),
              ),
            ),
            SizedBox(width: 8),
            // Texto de la categoría
            Text(
              nombre,
              style: TextStyle(
                color: isSelected ? Colors.white : textLight,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
