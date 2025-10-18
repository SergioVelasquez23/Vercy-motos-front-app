import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mesa.dart';
import '../widgets/imagen_producto_widget.dart';
import '../config/endpoints_config.dart';
import '../services/image_service.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/pedido.dart';
import '../models/item_pedido.dart';
import '../services/producto_service.dart';
import '../services/mesa_service.dart';
import '../services/pedido_service.dart';
import '../services/inventario_service.dart';
// import '../services/ingrediente_service.dart'; // Ahora se usa desde cache
import '../models/movimiento_inventario.dart';
import '../models/inventario.dart';
import '../models/ingrediente.dart';
import '../models/tipo_mesa.dart';
import '../providers/user_provider.dart';
import '../providers/datos_cache_provider.dart';
import '../utils/format_utils.dart';

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
  // final IngredienteService _ingredienteService = IngredienteService(); // Ahora se usa desde cache
  final ImageService _imageService = ImageService();

  // Estados de carga directa sin caché (reemplazado por cache provider)
  // bool _isLoadingProductos = false;
  // bool _isLoadingCategorias = false;
  // bool _isLoadingIngredientes = false;

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
  List<Ingrediente> ingredientes =
      []; // Lista de ingredientes para conversión ID -> nombre

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
  TextEditingController observacionesPedidoController = TextEditingController();
  TextEditingController comandoTextoController = TextEditingController();
  String filtro = '';
  String? categoriaSelecionadaId;

  // ✅ NUEVAS VARIABLES: Controlar visibilidad de campos opcionales
  bool _mostrarObservaciones = false;
  bool _mostrarComandos = false;

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

  // ========== SISTEMA DE COMANDOS DE TEXTO ==========

  // Diccionario de comandos (abreviación -> nombre del producto) - EXPANDIDO CON TODAS LAS VARIACIONES
  final Map<String, String> _comandosProductos = {
    // Sopas (múltiples variaciones)
    'S': 'Porción de Sopa',
    's': 'Porción de Sopa',
    'sopa': 'Porción de Sopa',
    'SOPA': 'Porción de Sopa',
    'Sopa': 'Porción de Sopa',
    'sopita': 'Porción de Sopa',
    'SOPITA': 'Porción de Sopa',
    'Sopita': 'Porción de Sopa',
    'sancocho': 'Sancocho Tri',
    'SANCOCHO': 'Sancocho Tri',
    'Sancocho': 'Sancocho Tri',
    'sanc': 'Sancocho Tri',
    'SANC': 'Sancocho Tri',
    'ajiaco': 'Ajiaco',
    'AJIACO': 'Ajiaco',
    'Ajiaco': 'Ajiaco',
    'aji': 'Ajiaco',
    'AJI': 'Ajiaco',
    'mondongo': 'Mondongo',
    'MONDONGO': 'Mondongo',
    'Mondongo': 'Mondongo',
    'mond': 'Mondongo',
    'MOND': 'Mondongo',

    // Frijoles (múltiples variaciones)
    'F': 'Porción de Frijol',
    'f': 'Porción de Frijol',
    'frijol': 'Porción de Frijol',
    'FRIJOL': 'Porción de Frijol',
    'Frijol': 'Porción de Frijol',
    'frijoles': 'Porción de Frijol',
    'FRIJOLES': 'Porción de Frijol',
    'Frijoles': 'Porción de Frijol',
    'frij': 'Porción de Frijol',
    'FRIJ': 'Porción de Frijol',
    'cazuela': 'Cazuela de Frijoles',
    'CAZUELA': 'Cazuela de Frijoles',
    'Cazuela': 'Cazuela de Frijoles',
    'caz': 'Cazuela de Frijoles',
    'CAZ': 'Cazuela de Frijoles',

    // Ejecutivos (múltiples variaciones)
    'E': 'Ejecutivo',
    'e': 'Ejecutivo',
    'EJ': 'Ejecutivo',
    'ej': 'Ejecutivo',
    'Ej': 'Ejecutivo',
    'ejecutivo': 'Ejecutivo',
    'EJECUTIVO': 'Ejecutivo',
    'Ejecutivo': 'Ejecutivo',
    'ejec': 'Ejecutivo',
    'EJEC': 'Ejecutivo',
    'Ejec': 'Ejecutivo',
    'menu': 'Ejecutivo',
    'MENU': 'Ejecutivo',
    'Menu': 'Ejecutivo',
    'menú': 'Ejecutivo',
    'MENÚ': 'Ejecutivo',
    'Menú': 'Ejecutivo',
    'plato ejecutivo': 'Ejecutivo',
    'PLATO EJECUTIVO': 'Ejecutivo',
    'Plato Ejecutivo': 'Ejecutivo',

    // Bandeja Paisa (múltiples variaciones)
    'P': 'Bandeja Paisa',
    'p': 'Bandeja Paisa',
    'paisa': 'Bandeja Paisa',
    'PAISA': 'Bandeja Paisa',
    'Paisa': 'Bandeja Paisa',
    'paisano': 'Bandeja Paisa',
    'PAISANO': 'Bandeja Paisa',
    'Paisano': 'Bandeja Paisa',
    'bandeja paisa': 'Bandeja Paisa',
    'BANDEJA PAISA': 'Bandeja Paisa',
    'Bandeja Paisa': 'Bandeja Paisa',
    'bandeja': 'Bandeja Paisa',
    'BANDEJA': 'Bandeja Paisa',
    'Bandeja': 'Bandeja Paisa',
    'band': 'Bandeja Paisa',
    'BAND': 'Bandeja Paisa',

    // Churrasco (múltiples variaciones)
    'C': 'Churrasco',
    'c': 'Churrasco',
    'churrasco': 'Churrasco',
    'CHURRASCO': 'Churrasco',
    'Churrasco': 'Churrasco',
    'churrascó': 'Churrasco',
    'CHURRASCÓ': 'Churrasco',
    'Churrascó': 'Churrasco',
    'churr': 'Churrasco',
    'CHURR': 'Churrasco',
    'chur': 'Churrasco',
    'CHUR': 'Churrasco',

    // Otros platos principales con abreviaciones
    'anca': 'Punta de anca',
    'ANCA': 'Punta de anca',
    'Anca': 'Punta de anca',
    'punta': 'Punta de anca',
    'PUNTA': 'Punta de anca',
    'Punta': 'Punta de anca',
    'punta anca': 'Punta de anca',
    'PUNTA ANCA': 'Punta de anca',
    'sobra': 'Sobrebarriga criolla o dorada',
    'SOBRA': 'Sobrebarriga criolla o dorada',
    'sobrebarriga': 'Sobrebarriga criolla o dorada',
    'SOBREBARRIGA': 'Sobrebarriga criolla o dorada',
    'Sobrebarriga': 'Sobrebarriga criolla o dorada',
    'sobre': 'Sobrebarriga criolla o dorada',
    'SOBRE': 'Sobrebarriga criolla o dorada',

    // Carnes con abreviaciones
    'pollo': 'Pechuga a la plancha',
    'POLLO': 'Pechuga a la plancha',
    'Pollo': 'Pechuga a la plancha',
    'poll': 'Pechuga a la plancha',
    'POLL': 'Pechuga a la plancha',
    'pechuga': 'Pechuga a la plancha',
    'PECHUGA': 'Pechuga a la plancha',
    'Pechuga': 'Pechuga a la plancha',
    'pech': 'Pechuga a la plancha',
    'PECH': 'Pechuga a la plancha',
    'milanesa pollo': 'Milanesa de pollo',
    'MILANESA POLLO': 'Milanesa de pollo',
    'mila pollo': 'Milanesa de pollo',
    'MILA POLLO': 'Milanesa de pollo',
    'milanesa cerdo': 'Milanesa de cerdo',
    'MILANESA CERDO': 'Milanesa de cerdo',
    'mila cerdo': 'Milanesa de cerdo',
    'MILA CERDO': 'Milanesa de cerdo',
    'mila': 'Milanesa de pollo',
    'MILA': 'Milanesa de pollo',
    'higado': 'Higado encebollado o a la plancha',
    'HIGADO': 'Higado encebollado o a la plancha',
    'hígado': 'Higado encebollado o a la plancha',
    'HÍGADO': 'Higado encebollado o a la plancha',
    'Hígado': 'Higado encebollado o a la plancha',

    // Pescados con abreviaciones
    'mojarra': 'Mojarra',
    'MOJARRA': 'Mojarra',
    'Mojarra': 'Mojarra',
    'moj': 'Mojarra',
    'MOJ': 'Mojarra',
    'salmon': 'Salmon',
    'SALMON': 'Salmon',
    'salmón': 'Salmon',
    'SALMÓN': 'Salmon',
    'Salmón': 'Salmon',
    'sal': 'Salmon',
    'SAL': 'Salmon',
    'trucha': 'Trucha',
    'TRUCHA': 'Trucha',
    'Trucha': 'Trucha',
    'tru': 'Trucha',
    'TRU': 'Trucha',
    'mariscos': 'Cazuela de Mariscos',
    'MARISCOS': 'Cazuela de Mariscos',
    'Mariscos': 'Cazuela de Mariscos',
    'mari': 'Cazuela de Mariscos',
    'MARI': 'Cazuela de Mariscos',

    // Asados con abreviaciones
    'asado res': 'Asada de res',
    'ASADO RES': 'Asada de res',
    'asado cerdo': 'Asada de cerdo',
    'ASADO CERDO': 'Asada de cerdo',
    'asado mixto': 'Asado mixto',
    'ASADO MIXTO': 'Asado mixto',
    'asado': 'Asado combinado (res o cerdo)',
    'ASADO': 'Asado combinado (res o cerdo)',
    'Asado': 'Asado combinado (res o cerdo)',
    'asa': 'Asado combinado (res o cerdo)',
    'ASA': 'Asado combinado (res o cerdo)',
    'combinado': 'Asado combinado (res o cerdo)',
    'COMBINADO': 'Asado combinado (res o cerdo)',
    'Combinado': 'Asado combinado (res o cerdo)',
    'comb': 'Asado combinado (res o cerdo)',
    'COMB': 'Asado combinado (res o cerdo)',
    'costillas': 'Costillas de cerdo en BBQ',
    'COSTILLAS': 'Costillas de cerdo en BBQ',
    'Costillas': 'Costillas de cerdo en BBQ',
    'cost': 'Costillas de cerdo en BBQ',
    'COST': 'Costillas de cerdo en BBQ',
    'bbq': 'Costillas de cerdo en BBQ',
    'BBQ': 'Costillas de cerdo en BBQ',

    // Picadas con abreviaciones
    'picada duo': 'Picada duo',
    'PICADA DUO': 'Picada duo',
    'Picada Duo': 'Picada duo',
    'picada familiar': 'Picada familiar',
    'PICADA FAMILIAR': 'Picada familiar',
    'Picada Familiar': 'Picada familiar',
    'picada': 'Picada duo',
    'PICADA': 'Picada duo',
    'Picada': 'Picada duo',
    'pic': 'Picada duo',
    'PIC': 'Picada duo',
    'duo': 'Picada duo',
    'DUO': 'Picada duo',
    'Duo': 'Picada duo',
    'familiar': 'Picada familiar',
    'FAMILIAR': 'Picada familiar',
    'Familiar': 'Picada familiar',
    'fam': 'Picada familiar',
    'FAM': 'Picada familiar',

    // Chuzos con abreviaciones
    'chuzo': 'Chuzo',
    'CHUZO': 'Chuzo',
    'Chuzo': 'Chuzo',
    'chuz': 'Chuzo',
    'CHUZ': 'Chuzo',
    'chuzito': 'Chuzo',
    'CHUZITO': 'Chuzo',
    'Chuzito': 'Chuzo',

    // Desayunos con abreviaciones
    'desayuno': 'Desayuno básico',
    'DESAYUNO': 'Desayuno básico',
    'Desayuno': 'Desayuno básico',
    'des': 'Desayuno básico',
    'DES': 'Desayuno básico',
    'desayuno proteina': 'DESAYUNO CON PROTEINA',
    'DESAYUNO PROTEINA': 'DESAYUNO CON PROTEINA',
    'Desayuno Proteina': 'DESAYUNO CON PROTEINA',
    'des prot': 'DESAYUNO CON PROTEINA',
    'DES PROT': 'DESAYUNO CON PROTEINA',
    'infantil': 'Menú Infantil',
    'INFANTIL': 'Menú Infantil',
    'Infantil': 'Menú Infantil',
    'inf': 'Menú Infantil',
    'INF': 'Menú Infantil',
    'niño': 'Menú Infantil',
    'NIÑO': 'Menú Infantil',

    // Bebidas frías con abreviaciones
    'G': 'Cocacola',
    'g': 'Cocacola',
    'gaseosa': 'Cocacola',
    'GASEOSA': 'Cocacola',
    'Gaseosa': 'Cocacola',
    'gas': 'Cocacola',
    'GAS': 'Cocacola',
    'coca': 'Cocacola',
    'COCA': 'Cocacola',
    'Coca': 'Cocacola',
    'cocacola': 'Cocacola',
    'COCACOLA': 'Cocacola',
    'zero': 'Cocacola zero',
    'ZERO': 'Cocacola zero',
    'Zero': 'Cocacola zero',
    'colombiana': 'Colombiana',
    'COLOMBIANA': 'Colombiana',
    'Colombiana': 'Colombiana',
    'col': 'Colombiana',
    'COL': 'Colombiana',
    'manzana': 'Manzana postobon',
    'MANZANA': 'Manzana postobon',
    'Manzana': 'Manzana postobon',
    'manz': 'Manzana postobon',
    'MANZ': 'Manzana postobon',
    'uva': 'Uva postobon',
    'UVA': 'Uva postobon',
    'Uva': 'Uva postobon',
    'naranja': 'Naranaja postobon',
    'NARANJA': 'Naranaja postobon',
    'Naranja': 'Naranaja postobon',
    'nar': 'Naranaja postobon',
    'NAR': 'Naranaja postobon',
    'tamarindo': 'Tamarindo',
    'TAMARINDO': 'Tamarindo',
    'Tamarindo': 'Tamarindo',
    'tam': 'Tamarindo',
    'TAM': 'Tamarindo',
    'bretaña': 'Bretaña',
    'BRETAÑA': 'Bretaña',
    'Bretaña': 'Bretaña',
    'bret': 'Bretaña',
    'BRET': 'Bretaña',

    // Jugos con abreviaciones
    'J': 'Jugo Natural Agua',
    'j': 'Jugo Natural Agua',
    'jugo': 'Jugo Natural Agua',
    'JUGO': 'Jugo Natural Agua',
    'Jugo': 'Jugo Natural Agua',
    'jug': 'Jugo Natural Agua',
    'JUG': 'Jugo Natural Agua',
    'jugo leche': 'Jugo Natural en Leche',
    'JUGO LECHE': 'Jugo Natural en Leche',
    'Jugo Leche': 'Jugo Natural en Leche',
    'jugo agua': 'Jugo Natural Agua',
    'JUGO AGUA': 'Jugo Natural Agua',
    'Jugo Agua': 'Jugo Natural Agua',
    'jarra jugo': 'Jarra de Jugo en Agua',
    'JARRA JUGO': 'Jarra de Jugo en Agua',
    'Jarra Jugo': 'Jarra de Jugo en Agua',
    'jarra': 'Jarra de Jugo en Agua',
    'JARRA': 'Jarra de Jugo en Agua',
    'Jarra': 'Jarra de Jugo en Agua',
    'jarr': 'Jarra de Jugo en Agua',
    'JARR': 'Jarra de Jugo en Agua',
    'limonada': 'Limonada natural',
    'LIMONADA': 'Limonada natural',
    'Limonada': 'Limonada natural',
    'limo': 'Limonada natural',
    'LIMO': 'Limonada natural',
    'Limo': 'Limonada natural',
    'lim': 'Limonada natural',
    'LIM': 'Limonada natural',
    'limonada coco': 'Limonada de Coco',
    'LIMONADA COCO': 'Limonada de Coco',
    'Limonada Coco': 'Limonada de Coco',
    'limo coco': 'Limonada de Coco',
    'LIMO COCO': 'Limonada de Coco',
    'limonada panela': 'Limonada de Panela',
    'LIMONADA PANELA': 'Limonada de Panela',
    'Limonada Panela': 'Limonada de Panela',
    'limo panela': 'Limonada de Panela',
    'LIMO PANELA': 'Limonada de Panela',

    // Agua con abreviaciones
    'A': 'Botella de Agua',
    'a': 'Botella de Agua',
    'agua': 'Botella de Agua',
    'AGUA': 'Botella de Agua',
    'Agua': 'Botella de Agua',
    'agua gas': 'Agua con Gas',
    'AGUA GAS': 'Agua con Gas',
    'Agua Gas': 'Agua con Gas',
    'agua con gas': 'Agua con Gas',
    'AGUA CON GAS': 'Agua con Gas',
    'Agua Con Gas': 'Agua con Gas',

    // Cervezas con abreviaciones
    'B': 'Club Colombia Dorada',
    'b': 'Club Colombia Dorada',
    'cerveza': 'Club Colombia Dorada',
    'CERVEZA': 'Club Colombia Dorada',
    'Cerveza': 'Club Colombia Dorada',
    'cerv': 'Club Colombia Dorada',
    'CERV': 'Club Colombia Dorada',
    'club': 'Club Colombia Dorada',
    'CLUB': 'Club Colombia Dorada',
    'Club': 'Club Colombia Dorada',
    'club negra': 'Club negra',
    'CLUB NEGRA': 'Club negra',
    'Club Negra': 'Club negra',
    'club roja': 'Club Colombia Roja',
    'CLUB ROJA': 'Club Colombia Roja',
    'Club Roja': 'Club Colombia Roja',
    'poker': 'Poker',
    'POKER': 'Poker',
    'Poker': 'Poker',
    'pok': 'Poker',
    'POK': 'Poker',
    'corona': 'Cerveza Coronita',
    'CORONA': 'Cerveza Coronita',
    'Corona': 'Cerveza Coronita',
    'coronita': 'Cerveza Coronita',
    'CORONITA': 'Cerveza Coronita',
    'Coronita': 'Cerveza Coronita',
    'cor': 'Cerveza Coronita',
    'COR': 'Cerveza Coronita',

    // Bebidas calientes con abreviaciones
    'cafe': 'Cafe con Leche',
    'CAFE': 'Cafe con Leche',
    'Cafe': 'Cafe con Leche',
    'café': 'Cafe con Leche',
    'CAFÉ': 'Cafe con Leche',
    'Café': 'Cafe con Leche',
    'tinto': 'Tinto',
    'TINTO': 'Tinto',
    'Tinto': 'Tinto',
    'tin': 'Tinto',
    'TIN': 'Tinto',
    'chocolate': 'Chocolate',
    'CHOCOLATE': 'Chocolate',
    'Chocolate': 'Chocolate',
    'choc': 'Chocolate',
    'CHOC': 'Chocolate',
    'milo': 'Milo Caliente',
    'MILO': 'Milo Caliente',
    'Milo': 'Milo Caliente',
    'aromatica': 'Aromática',
    'AROMATICA': 'Aromática',
    'aromática': 'Aromática',
    'AROMÁTICA': 'Aromática',
    'Aromática': 'Aromática',
    'arom': 'Aromática',
    'AROM': 'Aromática',
    'chai': 'TE CHAI',
    'CHAI': 'TE CHAI',
    'Chai': 'TE CHAI',

    // Acompañamientos con abreviaciones
    'arepa': 'Entrada de arepas',
    'AREPA': 'Entrada de arepas',
    'Arepa': 'Entrada de arepas',
    'arep': 'Entrada de arepas',
    'AREP': 'Entrada de arepas',
    'patacon': 'Patacón',
    'PATACON': 'Patacón',
    'patacón': 'Patacón',
    'PATACÓN': 'Patacón',
    'Patacón': 'Patacón',
    'pat': 'Patacón',
    'PAT': 'Patacón',
    'patacones': 'Patacones con Hogao',
    'PATACONES': 'Patacones con Hogao',
    'Patacones': 'Patacones con Hogao',
    'pats': 'Patacones con Hogao',
    'PATS': 'Patacones con Hogao',
    'papas': 'Papas a la Francesa',
    'PAPAS': 'Papas a la Francesa',
    'Papas': 'Papas a la Francesa',
    'papa': 'Papas a la Francesa',
    'PAPA': 'Papas a la Francesa',
    'yuca': 'Porción de papa salada',
    'YUCA': 'Porción de papa salada',
    'Yuca': 'Porción de papa salada',
    'arroz': 'Porción de arroz',
    'ARROZ': 'Porción de arroz',
    'Arroz': 'Porción de arroz',
    'arr': 'Porción de arroz',
    'ARR': 'Porción de arroz',
    'ensalada': 'Porción Ensalada',
    'ENSALADA': 'Porción Ensalada',
    'Ensalada': 'Porción Ensalada',
    'ens': 'Porción Ensalada',
    'ENS': 'Porción Ensalada',
    'aguacate': 'Porción de aguacate',
    'AGUACATE': 'Porción de aguacate',
    'Aguacate': 'Porción de aguacate',
    'agu': 'Porción de aguacate',
    'AGU': 'Porción de aguacate',
    'huevo': 'Huevo',
    'HUEVO': 'Huevo',
    'Huevo': 'Huevo',
    'hue': 'Huevo',
    'HUE': 'Huevo',

    // Adiciones con abreviaciones
    'carne': 'Adicion de carne',
    'CARNE': 'Adicion de carne',
    'Carne': 'Adicion de carne',
    'car': 'Adicion de carne',
    'CAR': 'Adicion de carne',
    'chorizo': 'Adicion de chorizo',
    'CHORIZO': 'Adicion de chorizo',
    'Chorizo': 'Adicion de chorizo',
    'chor': 'Adicion de chorizo',
    'CHOR': 'Adicion de chorizo',
    'chicharron': 'Entrada de Chicharrón',
    'CHICHARRON': 'Entrada de Chicharrón',
    'chicharrón': 'Entrada de Chicharrón',
    'CHICHARRÓN': 'Entrada de Chicharrón',
    'Chicharrón': 'Entrada de Chicharrón',
    'chich': 'Entrada de Chicharrón',
    'CHICH': 'Entrada de Chicharrón',
    'chunchulla': 'Entrada de chunchulla',
    'CHUNCHULLA': 'Entrada de chunchulla',
    'Chunchulla': 'Entrada de chunchulla',
    'chun': 'Entrada de chunchulla',
    'CHUN': 'Entrada de chunchulla',

    // Postres con abreviaciones
    'postre': 'Postre',
    'POSTRE': 'Postre',
    'Postre': 'Postre',
    'post': 'Postre',
    'POST': 'Postre',
    'helado': 'Helado',
    'HELADO': 'Helado',
    'Helado': 'Helado',
    'hel': 'Helado',
    'HEL': 'Helado',
    'torta': 'TORTA CASERA',
    'TORTA': 'TORTA CASERA',
    'Torta': 'TORTA CASERA',
    'tort': 'TORTA CASERA',
    'TORT': 'TORTA CASERA',
    'mazamorra': 'Mazamorra con panela',
    'MAZAMORRA': 'Mazamorra con panela',
    'Mazamorra': 'Mazamorra con panela',
    'maza': 'Mazamorra con panela',
    'MAZA': 'Mazamorra con panela',

    // Otros con abreviaciones
    'empaque': 'EMPAQUE PEQUEÑO',
    'EMPAQUE': 'EMPAQUE PEQUEÑO',
    'Empaque': 'EMPAQUE PEQUEÑO',
    'emp': 'EMPAQUE PEQUEÑO',
    'EMP': 'EMPAQUE PEQUEÑO',
    'domicilio': 'Domicilio',
    'DOMICILIO': 'Domicilio',
    'Domicilio': 'Domicilio',
    'dom': 'Domicilio',
    'DOM': 'Domicilio',
    'especial': 'PLATO PADRE',
    'ESPECIAL': 'PLATO PADRE',
    'Especial': 'PLATO PADRE',
    'esp': 'PLATO PADRE',
    'ESP': 'PLATO PADRE',
    'almuerzo': 'Almuerzo de la Casa',
    'ALMUERZO': 'Almuerzo de la Casa',
    'Almuerzo': 'Almuerzo de la Casa',
    'alm': 'Almuerzo de la Casa',
    'ALM': 'Almuerzo de la Casa',
  };

  // Diccionario de carnes para ejecutivos (expandido con todos los tipos disponibles)
  final Map<String, String> _carnesEjecutivos = {
    // Carnes principales
    'cerdo': 'Cerdo Ejecutivo',
    'res': 'Res ejecutiva',
    'pollo': 'Pechuga a la plancha',
    'pechuga': 'Pechuga a la plancha',
    'chicharron': 'Chicharrón',
    'chicharrón': 'Chicharrón',
    'carne molida': 'Carne molida',
    'molida': 'Carne molida',
    'chorizo': 'Chorizos',
    'chorizos': 'Chorizos',
    'mojarra': 'Mojarra ejecutiva',
    'higado': 'Hígado ejecutivo',
    'hígado': 'Hígado ejecutivo',
    'tilapia': 'Tilapia',
    'trucha': 'Trucha',
    'muslo': 'Muslo',

    // Alias y variaciones
    'pescado': 'Mojarra ejecutiva',
    'ave': 'Pechuga a la plancha',
    'puerco': 'Cerdo Ejecutivo',
    'ternera': 'Res ejecutiva',
    'carne': 'Res ejecutiva',
    'mixto': 'cerdo y res', // Caso especial para múltiples carnes
  };

  // ✅ NUEVO: Diccionario completo de opciones para TODOS los productos con opciones
  final Map<String, Map<String, dynamic>> _opcionesProductos = {
    // Ejecutivos
    'Ejecutivo': {
      'obligatorias': <String>[],
      'opcionales': [
        'Res ejecutiva',
        'Cerdo Ejecutivo',
        'Chicharrón',
        'Carne molida',
        'Chorizos',
        'Pechuga a la plancha',
        'Mojarra ejecutiva',
        'Hígado ejecutivo',
        'Tilapia',
        'Trucha',
        'Muslo',
      ],
    },

    // Desayuno con proteína
    'DESAYUNO CON PROTEINA': {
      'obligatorias': <String>[],
      'opcionales': [
        'Chicharrón',
        'Chorizos',
        'Carne molida',
        'Res ejecutiva',
        'Cerdo Ejecutivo',
        'Pechuga a la plancha',
      ],
    },

    // Bandeja Paisa
    'Bandeja Paisa': {
      'obligatorias': ['Chicharrón', 'Chorizos', 'Carne molida'],
      'opcionales': <String>[],
    },

    // Cazuela de Frijoles
    'Cazuela de Frijoles': {
      'obligatorias': ['Chicharrón', 'Carne molida'],
      'opcionales': <String>[],
    },

    // Asado combinado
    'Asado combinado (res o cerdo)': {
      'obligatorias': ['Chorizos'],
      'opcionales': ['Res Carta', 'Cerdo Carta'],
    },

    // Chuzos
    'Chuzo': {
      'obligatorias': <String>[],
      'opcionales': [
        'Res ejecutiva',
        'Cerdo Ejecutivo',
        'Pechuga a la plancha',
      ],
    },

    // Asado mixto
    'Asado mixto': {
      'obligatorias': ['Chorizos', 'Cerdo Ejecutivo', 'Res ejecutiva'],
      'opcionales': <String>[],
    },

    // Picadas
    'Picada duo': {
      'obligatorias': [
        'Chorizos',
        'Cerdo Ejecutivo',
        'Res ejecutiva',
        'Morcilla',
        'Chunchulla',
        'Chicharrón',
      ],
      'opcionales': <String>[],
    },

    'Picada familiar': {
      'obligatorias': [
        'Chorizos',
        'Morcilla',
        'Chicharrón',
        'Pechuga a la plancha',
        'Res ejecutiva',
        'Chunchulla',
        'Cerdo Ejecutivo',
      ],
      'opcionales': <String>[],
    },

    // Adiciones
    'Adicion de carne': {
      'obligatorias': <String>[],
      'opcionales': [
        'Chicharrón',
        'Res ejecutiva',
        'Cerdo Ejecutivo',
        'Carne molida',
        'Pechuga a la plancha',
        'Mojarra ejecutiva',
      ],
    },

    // Productos con opciones únicas obligatorias
    'Adicion de chorizo': {
      'obligatorias': ['Chorizos'],
      'opcionales': <String>[],
    },

    'Entrada de Chicharrón': {
      'obligatorias': ['Chicharrón'],
      'opcionales': <String>[],
    },

    'Entrada de chunchulla': {
      'obligatorias': ['Chunchulla'],
      'opcionales': <String>[],
    },

    'Menú Infantil': {
      'obligatorias': ['Pechuga a la plancha'],
      'opcionales': <String>[],
    },

    // Productos con bebidas específicas
    'Agua con Gas': {
      'obligatorias': ['Agua con gas'],
      'opcionales': <String>[],
    },

    'Botella de Agua': {
      'obligatorias': ['Agua en Botella'],
      'opcionales': <String>[],
    },

    'JUGO DEL VALLE': {
      'obligatorias': ['JUGO DEL VALLE'],
      'opcionales': <String>[],
    },

    'Jugo cajita': {
      'obligatorias': ['Jugo en caja'],
      'opcionales': <String>[],
    },

    'Colombiana': {
      'obligatorias': ['Colombiana Postobon'],
      'opcionales': <String>[],
    },

    // Carnes específicas
    'Churrasco': {
      'obligatorias': ['Churrasco'],
      'opcionales': <String>[],
    },

    'Punta de anca': {
      'obligatorias': ['Punta de ancaa'],
      'opcionales': <String>[],
    },

    'Milanesa de pollo': {
      'obligatorias': ['Pechuga a la plancha'],
      'opcionales': <String>[],
    },

    'Sobrebarriga criolla o dorada': {
      'obligatorias': ['Sobrebarriga'],
      'opcionales': <String>[],
    },

    'Milanesa de cerdo': {
      'obligatorias': ['Cerdo Ejecutivo'],
      'opcionales': <String>[],
    },

    'Higado encebollado o a la plancha': {
      'obligatorias': ['Higado Carta'],
      'opcionales': <String>[],
    },

    'Pechuga a la plancha': {
      'obligatorias': ['Pechuga a la plancha'],
      'opcionales': <String>[],
    },

    'Asada de res': {
      'obligatorias': ['Res Carta'],
      'opcionales': <String>[],
    },

    'Asada de cerdo': {
      'obligatorias': ['Cerdo Carta'],
      'opcionales': <String>[],
    },

    'Costillas de cerdo en BBQ': {
      'obligatorias': ['Costilla Cerdo'],
      'opcionales': <String>[],
    },

    'Plato de chorizos': {
      'obligatorias': ['Chorizos'],
      'opcionales': <String>[],
    },

    // Pescados
    'Cazuela de Mariscos': {
      'obligatorias': ['Cazuela de mariscos'],
      'opcionales': <String>[],
    },

    'Mojarra': {
      'obligatorias': ['Mojarra Carta'],
      'opcionales': <String>[],
    },

    'Salmon': {
      'obligatorias': ['Salmón'],
      'opcionales': <String>[],
    },

    'Trucha': {
      'obligatorias': ['Trucha'],
      'opcionales': <String>[],
    },

    // Licores y bebidas alcohólicas
    'Cocacola zero': {
      'obligatorias': ['Coca Cola Zero'],
      'opcionales': <String>[],
    },

    'Tamarindo': {
      'obligatorias': ['Tamarindo postobon'],
      'opcionales': <String>[],
    },

    'Manzana postobon': {
      'obligatorias': ['Manzana Postobon'],
      'opcionales': <String>[],
    },

    'Bretaña': {
      'obligatorias': ['Bretaña postobon'],
      'opcionales': <String>[],
    },

    'Naranaja postobon': {
      'obligatorias': ['Naranja Postobon'],
      'opcionales': <String>[],
    },

    'Uva postobon': {
      'obligatorias': ['Uva Postobon'],
      'opcionales': <String>[],
    },

    'Cocacola': {
      'obligatorias': ['Coca Cola'],
      'opcionales': <String>[],
    },

    // Cervezas y licores
    'Club negra': {
      'obligatorias': ['Club colombia Negra'],
      'opcionales': <String>[],
    },

    'Cerveza Coronita': {
      'obligatorias': ['Coronita'],
      'opcionales': <String>[],
    },

    'Club Colombia Dorada': {
      'obligatorias': ['Club colombia'],
      'opcionales': <String>[],
    },

    'Club Colombia Roja': {
      'obligatorias': ['Club roja'],
      'opcionales': <String>[],
    },

    'Cola y Pola': {
      'obligatorias': ['Cola y Pola'],
      'opcionales': <String>[],
    },

    'Poker': {
      'obligatorias': ['Poker'],
      'opcionales': <String>[],
    },
  };

  // ✅ NUEVA FUNCIÓN: Agregar producto con opciones automáticas
  /// Agrega un producto con las opciones especificadas, evitando mostrar diálogo si ya se especificaron
  Future<void> _agregarProductoConOpciones(
    String nombreProducto,
    int cantidad, {
    List<String> opcionesEspecificadas = const [],
  }) async {
    // Buscar el producto
    Producto? producto;
    try {
      producto = productosDisponibles.firstWhere(
        (p) => p.nombre.toLowerCase() == nombreProducto.toLowerCase(),
      );
    } catch (e) {
      _mostrarErrorComando('Producto "$nombreProducto" no encontrado');
      return;
    }

    // Verificar si tiene opciones configuradas
    final opcionesConfig = _opcionesProductos[nombreProducto];

    if (opcionesConfig != null) {
      final List<String> obligatorias = List<String>.from(
        opcionesConfig['obligatorias'] ?? [],
      );
      final List<String> opcionales = List<String>.from(
        opcionesConfig['opcionales'] ?? [],
      );

      // Si ya se especificaron opciones, usarlas directamente
      if (opcionesEspecificadas.isNotEmpty) {
        await _agregarProductoConOpcionesDirectas(
          producto,
          cantidad,
          opcionesEspecificadas,
        );
        return;
      }

      // Si solo tiene opciones obligatorias, agregarlas automáticamente
      if (obligatorias.isNotEmpty && opcionales.isEmpty) {
        await _agregarProductoConOpcionesDirectas(
          producto,
          cantidad,
          obligatorias,
        );
        return;
      }

      // Si tiene opciones opcionales, mostrar diálogo o usar la primera opción
      if (opcionales.isNotEmpty) {
        // Para comandos de texto, usar la primera opción disponible por defecto
        final primeraOpcion = opcionales.first;
        await _agregarProductoConOpcionesDirectas(producto, cantidad, [
          ...obligatorias,
          primeraOpcion,
        ]);
        return;
      }
    }

    // Si no tiene opciones especiales, agregar normalmente
    for (int i = 0; i < cantidad; i++) {
      await _agregarProducto(producto);
    }
  }

  /// Agrega un producto con opciones específicas directamente (SIN mostrar diálogo)
  Future<void> _agregarProductoConOpcionesDirectas(
    Producto producto,
    int cantidad,
    List<String> opciones,
  ) async {
    // Convertir nombres de opciones a IDs de ingredientes
    List<String> opcionesIds = opciones.map((nombreOpcion) {
      final ingrediente = ingredientes.firstWhere(
        (ing) => ing.nombre.toLowerCase() == nombreOpcion.toLowerCase(),
        orElse: () => Ingrediente(
          id: nombreOpcion, // Usar el nombre como ID si no se encuentra
          nombre: nombreOpcion,
          categoria: 'Sin categoría',
          cantidad: 0,
          unidad: 'unidad',
          costo: 0,
        ),
      );
      return ingrediente.id;
    }).toList();

    for (int i = 0; i < cantidad; i++) {
      // Crear producto con las opciones específicas
      final productoConOpciones = Producto(
        id: '${producto.id}_${DateTime.now().millisecondsSinceEpoch}_$i',
        nombre: producto.nombre,
        precio: producto.precio,
        costo: producto.costo,
        utilidad: producto.utilidad,
        categoria: producto.categoria,
        descripcion: producto.descripcion,
        imagenUrl: producto.imagenUrl,
        cantidad: 1,
        nota: "Opciones: ${opciones.join(', ')}", // Usar nombres para la nota
        tieneIngredientes: producto.tieneIngredientes,
        tipoProducto: producto.tipoProducto,
        // ✅ ASIGNAR LOS IDs DE OPCIONES ESPECÍFICAS
        ingredientesDisponibles: opcionesIds,
        ingredientesRequeridos: producto.ingredientesRequeridos,
        ingredientesOpcionales: producto.ingredientesOpcionales,
        impuestos: producto.impuestos,
        tieneVariantes: producto.tieneVariantes,
        estado: producto.estado,
      );

      setState(() {
        // Agregar el producto a la lista de productos de la mesa
        productosMesa.add(productoConOpciones);

        // Marcar como pagado si es mesa especial
        if (widget.mesa.tipo.nombre.toLowerCase() == 'cortesia' ||
            widget.mesa.tipo.nombre.toLowerCase() == 'consumo interno') {
          productoPagado[productoConOpciones.id] = true;
        }

        // Guardar las opciones seleccionadas para el inventario
        if (opciones.isNotEmpty) {
          productosCarneMap[productoConOpciones.id] = opciones.join(',');
        }
      });

      // Agregar observaciones si existen
      if (observacionesPedidoController.text.isNotEmpty) {
        productoConOpciones.nota =
            (productoConOpciones.nota ?? '') +
            '\nObservaciones: ${observacionesPedidoController.text}';
      }
    }

    _calcularTotal();
  }

  @override
  void initState() {
    super.initState();

    // Establecer el estado inicial basado en si hay un pedido existente
    esPedidoExistente = widget.pedidoExistente != null;

    // Cargar datos desde caché
    _cargarDatosOptimizado();

    // Configurar el controlador de búsqueda con debounce
    busquedaController.addListener(_onSearchChanged);

    // Escuchar cambios en el cache provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );
      cacheProvider.addListener(_onCacheDataChanged);
    });
  }

  // Callback cuando los datos del caché cambien
  void _onCacheDataChanged() {
    final cacheProvider = Provider.of<DatosCacheProvider>(
      context,
      listen: false,
    );

    if (cacheProvider.hasData && mounted) {
      print('🔄 Datos del caché actualizados, refrescando UI...');
      setState(() {
        productosDisponibles = cacheProvider.productos ?? [];
        categorias = cacheProvider.categorias ?? [];
        ingredientes = cacheProvider.ingredientes ?? [];
        _resetearPaginacion();
        _actualizarProductosVista();
      });
    }
  }

  @override
  void dispose() {
    // Limpiar el timer de debounce
    _debounceTimer?.cancel();
    busquedaController.removeListener(_onSearchChanged);
    busquedaController.dispose();
    clienteController.dispose();
    observacionesPedidoController.dispose();
    comandoTextoController.dispose();

    // Remover listener del cache provider
    try {
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );
      cacheProvider.removeListener(_onCacheDataChanged);
    } catch (e) {
      // Ignorar errores si el provider ya no está disponible
    }

    super.dispose();
  }

  // Método optimizado para cargar datos del caché
  Future<void> _cargarDatosOptimizado() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      print('📝 PedidoScreen: Cargando datos desde caché...');

      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );

      // Si no hay datos en caché, cargarlos
      if (!cacheProvider.hasData) {
        print('📊 Cache vacío, inicializando...');
        await cacheProvider.initialize();
      }

      // Obtener datos del caché
      final productosData = cacheProvider.productos ?? [];
      final categoriasData = cacheProvider.categorias ?? [];
      final ingredientesData = cacheProvider.ingredientes ?? [];

      // Guardar ingredientes para conversión ID -> nombre
      ingredientes = ingredientesData;

      // Inicializar el pedido existente si es necesario
      if (widget.pedidoExistente != null) {
        pedidoExistente = widget.pedidoExistente;

        // Cargar observaciones del pedido existente
        if (widget.pedidoExistente!.notas != null &&
            widget.pedidoExistente!.notas!.isNotEmpty) {
          observacionesPedidoController.text = widget.pedidoExistente!.notas!;
        }

        // Procesar productos del pedido existente
        for (var item in widget.pedidoExistente!.items) {
          final productoId = item.productoId;

          // Buscar el producto en los datos frescos
          final producto = productosData.firstWhere(
            (p) => p.id == productoId,
            orElse: () => Producto(
              id: productoId,
              nombre: item.productoNombre ?? 'Producto desconocido',
              precio: item.precioUnitario,
              costo: 0,
              utilidad: 0,
            ),
          );

          // ✅ NUEVO: Cargar información de ingredientes/carnes seleccionadas
          if (item.ingredientesSeleccionados.isNotEmpty) {
            // Si hay ingredientes seleccionados, guardar el primero como carne seleccionada
            // (asumiendo que el primer ingrediente es la carne principal)
            productosCarneMap[productoId] =
                item.ingredientesSeleccionados.first;
            print(
              '🥩 Cargada carne para ${producto.nombre}: ${item.ingredientesSeleccionados.first}',
            );
          } else if (item.notas != null &&
              item.notas!.contains('Ingredientes:')) {
            // Si la información está en las notas, extraer la primera carne
            final notasParts = item.notas!.split('Ingredientes:');
            if (notasParts.length > 1) {
              final ingredientes = notasParts[1].split(',');
              if (ingredientes.isNotEmpty) {
                final primerIngrediente = ingredientes.first.trim();
                productosCarneMap[productoId] = primerIngrediente;
                print(
                  '📝 Cargada carne desde notas para ${producto.nombre}: $primerIngrediente',
                );
              }
            }
          } else {
            print(
              '⚠️ No se encontró información de carne para ${producto.nombre}',
            );
          }

          // Copiar la información de notas/ingredientes al producto
          final productoConInfo = Producto(
            id: producto.id,
            nombre: producto.nombre,
            precio: producto.precio,
            costo: producto.costo,
            utilidad: producto.utilidad,
            categoria: producto.categoria,
            descripcion: producto.descripcion,
            imagenUrl: producto.imagenUrl,
            cantidad: item.cantidad,
            nota: item.notas, // Preservar la nota original
            tieneIngredientes: producto.tieneIngredientes,
            tipoProducto: producto.tipoProducto,
            // ✅ CORREGIDO: Usar ingredientes SELECCIONADOS del item, no los disponibles
            ingredientesDisponibles: item.ingredientesSeleccionados.isNotEmpty
                ? item.ingredientesSeleccionados
                : producto.ingredientesDisponibles,
            ingredientesRequeridos: producto.ingredientesRequeridos,
            ingredientesOpcionales: producto.ingredientesOpcionales,
            impuestos: producto.impuestos,
            tieneVariantes: producto.tieneVariantes,
            estado: producto.estado,
            ingredientesSeleccionadosCombo:
                producto.ingredientesSeleccionadosCombo,
          );

          // Agregar a la lista de productos de la mesa
          productosMesa.add(productoConInfo);

          // ✅ CORREGIDO: Inicializar productoPagado para TODOS los productos existentes
          // Los productos existentes deben estar activos (true) para ser incluidos en el total
          productoPagado[productoId] = true;
        }

        // Registrar cantidad original para comparación
        cantidadProductosOriginales = productosMesa.length;
        // Guardar copia para referencia
        productosOriginales = List.from(productosMesa);
      }

      // Actualizar listas
      setState(() {
        categorias = categoriasData;
        productosDisponibles = productosData;
        // Por defecto, seleccionar "Todos" y cargar todos los productos
        categoriaSelecionadaId = null; // null significa "Todos"
        _resetearPaginacion();
        _actualizarProductosVista(); // Actualizar la vista con todos los productos

        // ✅ CORREGIDO: Cargar cliente si existe (dentro del setState para actualizar UI)
        if (widget.pedidoExistente != null &&
            widget.pedidoExistente!.cliente != null) {
          clienteSeleccionado = widget.pedidoExistente!.cliente;
          clienteController.text = clienteSeleccionado!;
        }

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

  // Método para realizar la búsqueda de productos directo
  Future<void> _searchProductosAPI(String query) async {
    try {
      // Filtrar productos directamente desde la lista actual
      final productos = productosDisponibles;
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

  // ========== PARSER DE COMANDOS DE TEXTO ==========

  /// Procesa comandos de texto y agrega productos automáticamente
  /// Ejemplo de comandos:
  /// "1 S, 2 F" = 1 sopa, 2 frijoles
  /// "1(cerdo y res)" = 1 ejecutivo con cerdo y 1 ejecutivo con res
  /// "1 Paisa, 1 Churrasco" = 1 bandeja paisa, 1 churrasco
  Future<void> _procesarComandoTexto(String comando) async {
    if (comando.trim().isEmpty) return;

    try {
      // Limpiar y normalizar el comando
      String comandoLimpio = comando.toLowerCase().trim();

      // Dividir por comas para procesar múltiples items
      List<String> items = comandoLimpio
          .split(',')
          .map((e) => e.trim())
          .toList();

      List<String> resultados = [];

      for (String item in items) {
        final procesado = await _procesarItemComando(item);
        if (procesado.isNotEmpty) {
          resultados.addAll(procesado);
        }
      }

      if (resultados.isNotEmpty) {
        _mostrarResultadoComandos(resultados);
      } else {
        _mostrarErrorComando("No se pudo procesar el comando: $comando");
      }

      // Limpiar el campo de comando
      comandoTextoController.clear();
    } catch (e) {
      _mostrarErrorComando("Error procesando comando: $e");
    }
  }

  /// Procesa un item individual del comando
  Future<List<String>> _procesarItemComando(String item) async {
    List<String> resultados = [];

    // ✅ NUEVA LÓGICA UNIVERSAL: Detectar productos con opciones específicas
    // Ejemplos:
    // "2 EJ 1 Res 1 Cerdo" = 2 ejecutivos: 1 con res, 1 con cerdo
    // "1 Paisa Chorizo Chicharron" = 1 paisa con chorizo y chicharrón
    // "2 Desayuno Pollo" = 2 desayunos con pollo
    RegExp regexProductoConOpciones = RegExp(
      r'(\d+)\s+([a-záéíóúñü\s]+?)\s+(.+)',
      caseSensitive: false,
    );
    Match? matchProductoConOpciones = regexProductoConOpciones.firstMatch(item);

    if (matchProductoConOpciones != null) {
      int cantidadBase = int.parse(matchProductoConOpciones.group(1)!);
      String productoTexto = matchProductoConOpciones.group(2)!.trim();
      String especificacionOpciones = matchProductoConOpciones.group(3)!.trim();

      // Buscar el nombre del producto en el diccionario
      String? nombreProducto = _comandosProductos[productoTexto.toLowerCase()];
      if (nombreProducto == null) {
        // Intentar buscar por nombre completo
        nombreProducto = productosDisponibles
            .where(
              (p) =>
                  p.nombre.toLowerCase().contains(productoTexto.toLowerCase()),
            )
            .map((p) => p.nombre)
            .firstOrNull;
      }

      if (nombreProducto != null) {
        // Verificar si el producto tiene opciones configuradas
        final opcionesConfig = _opcionesProductos[nombreProducto];

        if (opcionesConfig != null) {
          // Buscar patrones de "X opcion" en la especificación
          RegExp regexCantidadOpcion = RegExp(
            r'(\d+)\s+([a-záéíóúñü\s]+?)(?=\s+\d+|$)',
            caseSensitive: false,
          );
          Iterable<Match> matches = regexCantidadOpcion.allMatches(
            especificacionOpciones,
          );

          if (matches.isNotEmpty) {
            // Hay especificaciones de opciones con cantidad
            int sumaOpciones = 0;
            List<Map<String, dynamic>> opcionesParaProcesar = [];
            
            // Primero, procesar todos los matches y verificar la suma
            for (Match match in matches) {
              int cantidadOpcion = int.parse(match.group(1)!);
              String nombreOpcion = match.group(2)!.trim();
              
              // Normalizar nombre de opción
              String opcionNormalizada = _normalizarOpcion(
                nombreOpcion,
                opcionesConfig,
              );
              
              opcionesParaProcesar.add({
                'cantidad': cantidadOpcion,
                'opcion': opcionNormalizada,
                'original': nombreOpcion,
              });
              
              sumaOpciones += cantidadOpcion;
            }
            
            // Verificar que la suma coincida con la cantidad base
            if (sumaOpciones == cantidadBase) {
              // Las cantidades coinciden, procesar cada opción
              for (var opcionData in opcionesParaProcesar) {
                await _agregarProductoConOpciones(
                  nombreProducto,
                  opcionData['cantidad'],
                  opcionesEspecificadas: [opcionData['opcion']],
                );
                resultados.add(
                  '${opcionData['cantidad']} $nombreProducto(${opcionData['opcion']})',
                );
              }
            } else {
              // Las cantidades no coinciden, mostrar error
              resultados.add(
                'ERROR: Total especificado ($cantidadBase) no coincide con suma de opciones ($sumaOpciones)',
              );
            }
            return resultados;
          } else {
            // No hay cantidades específicas, interpretar como opciones separadas por espacios
            List<String> opciones = especificacionOpciones
                .split(RegExp(r'[y,/\s]+'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();

            List<String> opcionesNormalizadas = opciones
                .map((opcion) => _normalizarOpcion(opcion, opcionesConfig))
                .toList();

            await _agregarProductoConOpciones(
              nombreProducto,
              cantidadBase,
              opcionesEspecificadas: opcionesNormalizadas,
            );
            resultados.add(
              '$cantidadBase $nombreProducto(${opcionesNormalizadas.join(', ')})',
            );
            return resultados;
          }
        } else {
          // El producto no tiene opciones configuradas, agregarlo normalmente
          await _agregarProductoConOpciones(nombreProducto, cantidadBase);
          resultados.add('$cantidadBase $nombreProducto');
          return resultados;
        }
      }
    }

    // Regex para capturar cantidad y producto en paréntesis (formato legacy)
    // Ejemplos: "1(cerdo y res)", "2(pollo)"
    RegExp regexParentesis = RegExp(r'(\d+)\s*\(([^)]+)\)');
    Match? matchParentesis = regexParentesis.firstMatch(item);
    if (matchParentesis != null) {
      int cantidad = int.parse(matchParentesis.group(1)!);
      String opciones = matchParentesis.group(2)!;

      // Asumir que es un ejecutivo si usa paréntesis
      List<String> listaOpciones = opciones
          .split(RegExp(r'[y,/]'))
          .map((e) => e.trim())
          .toList();

      for (String opcion in listaOpciones) {
        String opcionNormalizada =
            _carnesEjecutivos[opcion.toLowerCase()] ?? opcion;
        await _agregarProductoConOpciones(
          'Ejecutivo',
          cantidad,
          opcionesEspecificadas: [opcionNormalizada],
        );
        resultados.add('$cantidad Ejecutivo($opcionNormalizada)');
      }
      return resultados;
    }

    // Regex básico para productos simples
    // Ejemplos: "2 S", "1 sopa", "1 paisa"
    RegExp regexBasico = RegExp(r'(\d+)\s*(.+)');
    Match? matchBasico = regexBasico.firstMatch(item);
    if (matchBasico != null) {
      int cantidad = int.parse(matchBasico.group(1)!);
      String productoTexto = matchBasico.group(2)!.trim();

      // Buscar el producto en el diccionario
      String? nombreProducto = _comandosProductos[productoTexto];
      if (nombreProducto != null) {
        await _agregarProductoConOpciones(nombreProducto, cantidad);
        resultados.add('$cantidad $nombreProducto');
      } else {
        // Intentar búsqueda directa por nombre
        await _agregarProductoPorNombre(productoTexto, cantidad);
        resultados.add('$cantidad $productoTexto');
      }
    }

    return resultados;
  }

  /// Normaliza el nombre de una opción basándose en la configuración del producto
  String _normalizarOpcion(String opcion, Map<String, dynamic> opcionesConfig) {
    final List<String> todasLasOpciones = [
      ...List<String>.from(opcionesConfig['obligatorias'] ?? []),
      ...List<String>.from(opcionesConfig['opcionales'] ?? []),
    ];

    // Buscar coincidencia exacta primero
    String opcionLower = opcion.toLowerCase();

    // Buscar en el diccionario de carnes de ejecutivos
    String? carneNormalizada = _carnesEjecutivos[opcionLower];
    if (carneNormalizada != null &&
        todasLasOpciones.contains(carneNormalizada)) {
      return carneNormalizada;
    }

    // Buscar coincidencia parcial en las opciones disponibles
    for (String opcionDisponible in todasLasOpciones) {
      if (opcionDisponible.toLowerCase().contains(opcionLower) ||
          opcionLower.contains(opcionDisponible.toLowerCase())) {
        return opcionDisponible;
      }
    }

    // Si no encuentra, usar la primera opción disponible o la opción original
    return todasLasOpciones.isNotEmpty ? todasLasOpciones.first : opcion;
  }
  }

  /// Agrega un ejecutivo con una carne específica (EVITA mostrar diálogo)
  Future<void> _agregarEjecutivoConCarne(int cantidad, String carne) async {
    // Buscar productos ejecutivos
    final ejecutivos = productosDisponibles
        .where((p) => p.nombre.toLowerCase().contains('ejecutivo'))
        .toList();

    if (ejecutivos.isEmpty) {
      _mostrarErrorComando('No se encontró producto "Ejecutivo"');
      return;
    }

    final ejecutivo = ejecutivos.first;

    for (int i = 0; i < cantidad; i++) {
      // ✅ CREAR Producto directamente con la carne específica
      final productoConCarne = Producto(
        id: '${ejecutivo.id}_${DateTime.now().millisecondsSinceEpoch}_$i',
        nombre: ejecutivo.nombre,
        precio: ejecutivo.precio,
        costo: ejecutivo.costo,
        utilidad: ejecutivo.utilidad,
        categoria: ejecutivo.categoria,
        descripcion: ejecutivo.descripcion,
        imagenUrl: ejecutivo.imagenUrl,
        cantidad: 1,
        nota: "Carne: $carne",
        tieneIngredientes: ejecutivo.tieneIngredientes,
        tipoProducto: ejecutivo.tipoProducto,
        // ✅ ASIGNAR LA CARNE ESPECÍFICA directamente
        ingredientesDisponibles: [carne],
        ingredientesRequeridos: ejecutivo.ingredientesRequeridos,
        ingredientesOpcionales: ejecutivo.ingredientesOpcionales,
        impuestos: ejecutivo.impuestos,
        tieneVariantes: ejecutivo.tieneVariantes,
        estado: ejecutivo.estado,
      );

      setState(() {
        // Agregar el producto a la lista de productos de la mesa
        productosMesa.add(productoConCarne);

        // Marcar como pagado si es mesa especial
        if (widget.mesa.tipo.nombre.toLowerCase() == 'cortesia' ||
            widget.mesa.tipo.nombre.toLowerCase() == 'consumo interno') {
          productoPagado[productoConCarne.id] = true;
        }

        // Guardar la relación producto-carne para el inventario
        if (carne.isNotEmpty) {
          productosCarneMap[productoConCarne.id] = carne;
        }
      });

      // Agregar observaciones si existen
      if (observacionesPedidoController.text.isNotEmpty) {
        productoConCarne.nota =
            (productoConCarne.nota ?? '') +
            '\nObservaciones: ${observacionesPedidoController.text}';
      }
    }

    _calcularTotal();
  }

  /// Agrega un producto por nombre
  Future<void> _agregarProductoPorNombre(String nombre, int cantidad) async {
    // Buscar producto que coincida con el nombre
    Producto? producto;

    // Primero buscar coincidencia exacta o que contenga el nombre
    try {
      producto = productosDisponibles.firstWhere(
        (p) => p.nombre.toLowerCase().contains(nombre.toLowerCase()),
      );
    } catch (e) {
      // Si no encuentra, buscar si el nombre está contenido en algún producto
      try {
        producto = productosDisponibles.firstWhere(
          (p) => nombre.toLowerCase().contains(p.nombre.toLowerCase()),
        );
      } catch (e) {
        // ✅ ARREGLADO: No crear producto falso, solo mostrar error
        print('❌ Producto no encontrado: $nombre');
        _mostrarErrorComando(
          'Producto "$nombre" no encontrado. Solo se pueden agregar productos existentes.',
        );
        return; // No agregar nada si no existe
      }
    }

    // ✅ Si encontró el producto, agregarlo (producto ya no puede ser null aquí)
    for (int i = 0; i < cantidad; i++) {
      await _agregarProducto(producto);
    }
  }

  /// Muestra el resultado de los comandos procesados
  void _mostrarResultadoComandos(List<String> items) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Agregado: ${items.join(', ')}')),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Muestra error en el procesamiento de comandos
  void _mostrarErrorComando(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(error)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Muestra ayuda con ejemplos de comandos
  void _mostrarAyudaComandos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF252525),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFFFF6B00)),
            SizedBox(width: 8),
            Text(
              'Comandos Rápidos',
              style: TextStyle(color: Color(0xFFE0E0E0)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Usa estos comandos para agregar productos rápidamente:',
                style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
              ),
              SizedBox(height: 16),
              _buildEjemploComando(
                'Productos simples:',
                '1 S, 2 F, 1 P',
                '1 sopa, 2 frijoles, 1 paisa',
              ),
              _buildEjemploComando(
                'Ejecutivos con carnes:',
                '2 EJ 1 Res 1 Cerdo',
                '2 ejecutivos: 1 con res, 1 con cerdo',
              ),
              _buildEjemploComando(
                'Desayunos con proteína:',
                '1 Desayuno Pollo',
                '1 desayuno con pechuga',
              ),
              _buildEjemploComando(
                'Productos con múltiples opciones:',
                '1 Picada Chorizo Res Cerdo',
                '1 picada con chorizo, res y cerdo',
              ),
              _buildEjemploComando(
                'Formato en paréntesis:',
                '1(cerdo y res)',
                '1 ejecutivo con cerdo y 1 con res',
              ),
              _buildEjemploComando(
                'Bebidas automáticas:',
                '2 G, 1 Club, 1 Corona',
                '2 cocacolas, 1 club colombia, 1 coronita',
              ),
              SizedBox(height: 16),
              Text(
                'Abreviaciones disponibles:',
                style: TextStyle(
                  color: Color(0xFFFF6B00),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              _buildAbreviacion('S', 'Sopa'),
              _buildAbreviacion('F', 'Frijol'),
              _buildAbreviacion('E/EJ', 'Ejecutivo'),
              _buildAbreviacion('P', 'Bandeja Paisa'),
              _buildAbreviacion('C', 'Churrasco'),
              _buildAbreviacion('G', 'Gaseosa'),
              _buildAbreviacion('J', 'Jugo'),
              _buildAbreviacion('B', 'Cerveza'),
              _buildAbreviacion('A', 'Agua'),
              SizedBox(height: 8),
              Text(
                'Carnes para ejecutivos:',
                style: TextStyle(
                  color: Color(0xFFFF6B00),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              _buildAbreviacion('res', 'Res ejecutiva'),
              _buildAbreviacion('cerdo', 'Cerdo Ejecutivo'),
              _buildAbreviacion('pollo', 'Pechuga a la plancha'),
              _buildAbreviacion('chicharron', 'Chicharrón'),
              _buildAbreviacion('molida', 'Carne molida'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Entendido',
              style: TextStyle(color: Color(0xFFFF6B00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEjemploComando(String titulo, String comando, String resultado) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: Color(0xFFFF6B00),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comando,
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '→ $resultado',
                  style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbreviacion(String abrev, String significado) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            child: Text(
              abrev,
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '→ $significado',
            style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<dynamic> _mostrarDialogoOpciones(
    Producto producto,
    List<String> opciones,
  ) async {
    // Lista para almacenar las selecciones múltiples
    List<Map<String, dynamic>> selecciones = [];

    // Variables para la selección actual
    TextEditingController observacionesController = TextEditingController();
    String? opcionSeleccionada = opciones.isNotEmpty ? opciones.first : null;
    int cantidadSeleccionada = 1;

    final resultado = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false, // Evitar cerrar accidentalmente
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Opciones para ${producto.nombre}'),
                        if (selecciones.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            'Agregados: ${selecciones.length} productos',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.help_outline, color: Colors.blue),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('¿Cómo usar?'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '1. Selecciona una opción (ej: Res, Cerdo, Sin carne)',
                              ),
                              SizedBox(height: 8),
                              Text(
                                '2. Ajusta la cantidad si necesitas más de 1',
                              ),
                              SizedBox(height: 8),
                              Text('3. Agrega observaciones si es necesario'),
                              SizedBox(height: 8),
                              Text(
                                '4. Presiona "Agregar" para añadir a la lista',
                              ),
                              SizedBox(height: 8),
                              Text('5. Repite para agregar más opciones'),
                              SizedBox(height: 8),
                              Text('6. Presiona "Finalizar" cuando termines'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Entendido'),
                            ),
                          ],
                        ),
                      );
                    },
                    tooltip: 'Ayuda',
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mostrar selecciones previas
                    if (selecciones.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Productos agregados:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            ...selecciones
                                .map(
                                  (sel) => Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${sel['cantidad']}x ${sel['nombre']}${sel['observaciones'].toString().isNotEmpty ? ' (${sel['observaciones']})' : ''}',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            selecciones.remove(sel);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 16),
                    ],

                    // Selección actual
                    Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: Colors.blue,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Agregar nueva opción:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Puedes agregar múltiples opciones (ej: 1 res, 2 cerdo, 1 sin carne)',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    SizedBox(height: 12),

                    if (opciones.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: DropdownButton<String>(
                          value: opcionSeleccionada,
                          isExpanded: true,
                          underline: SizedBox(), // Remover la línea por defecto
                          items: opciones
                              .map(
                                (opcion) => DropdownMenuItem(
                                  value: opcion,
                                  child: Row(
                                    children: [
                                      if (opcion.toLowerCase().contains('sin'))
                                        Icon(
                                          Icons.not_interested,
                                          color: Colors.orange,
                                          size: 16,
                                        )
                                      else
                                        Icon(
                                          Icons.restaurant,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                      SizedBox(width: 8),
                                      Text(
                                        opcion,
                                        style: TextStyle(
                                          color:
                                              opcion.toLowerCase().contains(
                                                'sin',
                                              )
                                              ? Colors.orange
                                              : Colors.black,
                                          fontWeight:
                                              opcion.toLowerCase().contains(
                                                'sin',
                                              )
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              opcionSeleccionada = value;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                    ],

                    // Selector de cantidad
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Cantidad: '),
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            if (cantidadSeleccionada > 1) {
                              setDialogState(() => cantidadSeleccionada--);
                            }
                          },
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$cantidadSeleccionada',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            setDialogState(() => cantidadSeleccionada++);
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: 16),
                    TextField(
                      controller: observacionesController,
                      decoration: InputDecoration(
                        labelText: 'Observaciones (opcional)',
                        hintText: 'Ej: Sin sal, término medio, etc.',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                // Botón para agregar la selección actual
                TextButton.icon(
                  onPressed: opcionSeleccionada != null
                      ? () {
                          setDialogState(() {
                            selecciones.add({
                              'nota': opcionSeleccionada!,
                              'cantidad': cantidadSeleccionada,
                              'observaciones': observacionesController.text,
                              'productoId': producto.id,
                              'nombre': opcionSeleccionada!,
                            });
                            // Reset para siguiente selección
                            observacionesController.clear();
                            cantidadSeleccionada = 1;
                          });
                        }
                      : null,
                  icon: Icon(Icons.add, size: 18),
                  label: Text('Agregar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),

                // Botón cancelar
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text('Cancelar'),
                ),

                // Botón finalizar
                ElevatedButton.icon(
                  onPressed: selecciones.isNotEmpty
                      ? () {
                          Navigator.of(context).pop(selecciones);
                        }
                      : null,
                  icon: Icon(Icons.check, size: 18),
                  label: Text('Finalizar (${selecciones.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
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
      // ✅ COMENTADO: Log de procesamiento detallado removido
      // print('🔍 Procesando ingrediente opcional: ID="${ingrediente.ingredienteId}", Nombre="${ingrediente.ingredienteNombre}"');

      String nombreConPrecio = ingrediente.ingredienteNombre;
      if (ingrediente.precioAdicional > 0) {
        nombreConPrecio +=
            ' (+\$${ingrediente.precioAdicional.toStringAsFixed(0)})';
      }

      // ✅ COMENTADO: Log de nombre con precio removido
      // print('🔍 Nombre con precio generado: "$nombreConPrecio"');
      ingredientesOpcionales.add(nombreConPrecio);
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
                                  (ing) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          ing.ingredienteNombre,
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
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
                          // Opción 'Sin seleccionar' para ingredientes básicos
                          CheckboxListTile(
                            title: Text(
                              'Sin seleccionar',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                            value: ingredientesSeleccionados.isEmpty,
                            onChanged: (bool? value) {
                              setState(() {
                                ingredientesSeleccionados.clear();
                              });
                            },
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
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

                        // 🥩 NUEVO: Ingredientes opcionales (checkboxes - múltiples selecciones)
                        if (ingredientesOpcionales.isNotEmpty) ...[
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.restaurant,
                                      color: Colors.orange,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Selecciona múltiples carnes para ejecutivos separados',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),

                          // Lista de carnes con checkboxes múltiples
                          // Opción 'Sin seleccionar' para carnes/opciones
                          Container(
                            margin: EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: ingredientesSeleccionados.isEmpty
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: ingredientesSeleccionados.isEmpty
                                    ? Colors.orange.withOpacity(0.5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.lunch_dining,
                                    color: ingredientesSeleccionados.isEmpty
                                        ? Colors.orange
                                        : Colors.grey,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Sin seleccionar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: ingredientesSeleccionados.isEmpty
                                            ? Colors.orange
                                            : Colors.white,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              value: ingredientesSeleccionados.isEmpty,
                              activeColor: Colors.orange,
                              checkColor: Colors.white,
                              onChanged: (bool? value) {
                                setState(() {
                                  ingredientesSeleccionados.clear();
                                });
                              },
                              dense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                          ...ingredientesOpcionales.map((ingrediente) {
                            final bool isSelected = ingredientesSeleccionados
                                .contains(ingrediente);
                            return Container(
                              margin: EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.orange.withOpacity(0.5)
                                      : Colors.transparent,
                                ),
                              ),
                              child: CheckboxListTile(
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.lunch_dining,
                                      color: isSelected
                                          ? Colors.orange
                                          : Colors.grey,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ingrediente,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isSelected
                                              ? Colors.orange
                                              : Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                value: isSelected,
                                activeColor: Colors.orange,
                                checkColor: Colors.white,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      ingredientesSeleccionados.add(
                                        ingrediente,
                                      );
                                    } else {
                                      ingredientesSeleccionados.remove(
                                        ingrediente,
                                      );
                                    }
                                  });
                                },
                                dense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            );
                          }),

                          // Información de cuántos ejecutivos se crearán
                          if (ingredientesSeleccionados
                              .where(
                                (ing) => ingredientesOpcionales.contains(ing),
                              )
                              .isNotEmpty) ...[
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Se crearán ${ingredientesSeleccionados.where((ing) => ingredientesOpcionales.contains(ing)).length} ejecutivos separados',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                  onPressed:
                      (ingredientesBasicos.isEmpty &&
                          ingredientesOpcionales.isEmpty)
                      ? () {
                          // Si no hay ingredientes configurados, permitir continuar sin selección
                          Navigator.of(context).pop({
                            'ingredientes': <String>[],
                            'notas': notasController.text.isNotEmpty
                                ? notasController.text
                                : null,
                          });
                        }
                      // ✅ CORREGIDO: Habilitar botón si:
                      // - Hay ingredientes seleccionados, O
                      // - Hay ingredientes opcionales Y se seleccionó "Ninguna selección" (ingredienteOpcionalSeleccionado != null)
                      : ingredientesSeleccionados.isEmpty &&
                            ingredientesOpcionales.isEmpty
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
                  child: Text(
                    (ingredientesBasicos.isEmpty &&
                            ingredientesOpcionales.isEmpty)
                        ? 'Continuar sin ingredientes'
                        : 'Confirmar',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // ✅ ESTRATEGIA NUEVA: Convertir ingredientes opcionales seleccionados en requeridos
    if (resultado != null) {
      List<String> ingredientesFinales = List<String>.from(
        resultado['ingredientes'],
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

      // Actualizar el resultado con los ingredientes completos
      resultado['ingredientes'] = ingredientesFinales;
      resultado['producto_actualizado'] = productoActualizado;

      print('📋 RESULTADO FINAL:');
      print(
        '  - Ingredientes opcionales convertidos a requeridos: ${nuevosRequeridos.length - producto.ingredientesRequeridos.length}',
      );
      print('  - Total ingredientes requeridos: ${nuevosRequeridos.length}');
      print('  - Total ingredientes: ${ingredientesFinales.length}');
    }

    return resultado;
  }

  // 🚀 OPTIMIZACIÓN: Carga optimizada de datos para pedidos usando caché
  Future<void> _loadData() async {
    try {
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );

      // Solo mostrar loading si es necesario
      if (productosDisponibles.isEmpty) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }

      // Si no hay datos locales o en caché, cargar
      if (productosDisponibles.isEmpty ||
          categorias.isEmpty ||
          !cacheProvider.hasData) {
        print('📝 PedidoScreen: Cargando datos desde caché...');
        await _cargarDatosOptimizado();
      } else {
        // Usar datos locales existentes
        print('📝 PedidoScreen: Usando datos locales existentes');
      }

      final productos = productosDisponibles;
      final categoriasData = categorias;

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
          // ✅ CORREGIDO: Buscar el producto completo en la lista de productos disponibles
          Producto? productoObj = productos.firstWhere(
            (p) => p.id == item.productoId,
            orElse: () => _getProductoFromItem(
              item.producto,
              productoId: item.productoId,
              forceNonNull: true,
            )!,
          );

          print(
            '📦 Cargando producto: ${productoObj.nombre} (ID: ${item.productoId}) - Imagen: ${productoObj.imagenUrl ?? "Sin imagen"}',
          );

          // Crear una copia del producto con la cantidad y notas del item
          final productoParaMesa = Producto(
            id: item.productoId,
            nombre: productoObj.nombre,
            precio: item.precio,
            costo: productoObj.costo,
            utilidad: productoObj.utilidad,
            descripcion: productoObj.descripcion,
            categoria: productoObj.categoria,
            tieneVariantes: productoObj.tieneVariantes,
            imagenUrl: productoObj
                .imagenUrl, // ✅ CORREGIDO: Ahora preserva la imagen correctamente
            ingredientesDisponibles: item.ingredientesSeleccionados,
            cantidad: item.cantidad,
            nota: item.notas,
          );
          productosMesa.add(productoParaMesa);

          // Inicializar el mapa de pagados como activos (true) ya que son productos existentes
          productoPagado[productoParaMesa.id] = true;
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
              if (item.producto != null) {
                // Crear una copia del producto con la cantidad y notas del item
                final productoOriginal = _getProductoFromItem(
                  item.producto,
                  forceNonNull: true,
                )!;
                print(
                  '📦 Cargando producto de mesa ocupada: ${productoOriginal.nombre} (ID: ${productoOriginal.id}) - Imagen: ${productoOriginal.imagenUrl ?? "Sin imagen"}',
                );
                final productoParaMesa = Producto(
                  id: productoOriginal.id,
                  nombre: productoOriginal.nombre,
                  precio: item.precio,
                  costo: productoOriginal.costo,
                  utilidad: productoOriginal.utilidad,
                  descripcion: productoOriginal.descripcion,
                  categoria: productoOriginal.categoria,
                  tieneVariantes: productoOriginal.tieneVariantes,
                  imagenUrl: productoOriginal
                      .imagenUrl, // ✅ AGREGADO: Conservar la URL de la imagen
                  ingredientesDisponibles: item.ingredientesSeleccionados,
                  cantidad: item.cantidad,
                  nota: item.notas,
                );
                productosMesa.add(productoParaMesa);

                // Inicializar el mapa de pagados como activos (true) para productos existentes
                productoPagado[productoParaMesa.id] = true;
              }
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
        categorias = categoriasData;
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
        ingredientesSeleccionados =
            resultadoIngredientes['ingredientes'] as List<String>;
        notasEspeciales = resultadoIngredientes['notas'] as String?;
        if (resultadoIngredientes.containsKey('producto_actualizado')) {
          productoFinal =
              resultadoIngredientes['producto_actualizado'] as Producto;
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
          opcionesPersonalizadas = ['Sin carne', 'Pollo', 'Res', 'Cerdo'];
        } else if (productoFinal.nombre.toLowerCase().contains(
          'asado combinado',
        )) {
          opcionesPersonalizadas = ['Sin carne', 'Res', 'Cerdo'];
        } else if (productoFinal.nombre.toLowerCase().contains('ejecutivo')) {
          opcionesPersonalizadas = [
            'Sin carne',
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

        // Manejar múltiples selecciones
        if (resultado is List<Map<String, dynamic>>) {
          // Procesar cada selección por separado
          for (Map<String, dynamic> seleccion in resultado) {
            String? notasVariantes = seleccion['nota'];
            String notasCompletas = notasEspeciales ?? '';

            if (notasCompletas.isNotEmpty && notasVariantes != null) {
              notasCompletas = '$notasCompletas - $notasVariantes';
            } else if (notasVariantes != null) {
              notasCompletas = notasVariantes;
            }

            if (seleccion['observaciones'] != null &&
                seleccion['observaciones'].toString().isNotEmpty) {
              notasCompletas =
                  "$notasCompletas - ${seleccion['observaciones']}";
            }

            // Agregar cada producto individual con su cantidad
            for (int i = 0; i < (seleccion['cantidad'] as int); i++) {
              setState(() {
                Producto nuevoProd = Producto(
                  id: productoFinal.id,
                  nombre: productoFinal.nombre,
                  precio: productoFinal.precio,
                  costo: productoFinal.costo,
                  utilidad: productoFinal.utilidad,
                  categoria: productoFinal.categoria,
                  descripcion: productoFinal.descripcion,
                  imagenUrl: productoFinal.imagenUrl,
                  cantidad: 1, // Siempre 1 porque iteramos por la cantidad
                  nota: notasCompletas.isNotEmpty ? notasCompletas : null,
                  tieneIngredientes: productoFinal.tieneIngredientes,
                  tipoProducto: productoFinal.tipoProducto,
                  ingredientesDisponibles: ingredientesSeleccionados.isNotEmpty
                      ? ingredientesSeleccionados
                      : productoFinal.ingredientesDisponibles,
                  ingredientesRequeridos: productoFinal.ingredientesRequeridos,
                  ingredientesOpcionales: productoFinal.ingredientesOpcionales,
                  impuestos: productoFinal.impuestos,
                  tieneVariantes: productoFinal.tieneVariantes,
                  estado: productoFinal.estado,
                  ingredientesSeleccionadosCombo:
                      productoFinal.ingredientesSeleccionadosCombo,
                );

                productosMesa.add(nuevoProd);
                productoPagado[nuevoProd.id] = true;

                if (seleccion['productoId'] != null) {
                  productosCarneMap[nuevoProd.id] = seleccion['productoId'];
                }
              });
            }
          }

          // Calcular total una sola vez al final
          _calcularTotal();
          return; // Salir de la función ya que hemos procesado todo
        }
        // Código de compatibilidad para selección única (fallback)
        else if (resultado is Map<String, dynamic>) {
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

    // Calcular total
    double total = productosMesa.fold(
      0,
      (sum, producto) => sum + (producto.precio * producto.cantidad),
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
        notas: observacionesPedidoController.text.trim().isEmpty
            ? ""
            : observacionesPedidoController.text
                  .trim(), // Usar observaciones del pedido
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
        notas: observacionesPedidoController.text.trim().isEmpty
            ? ""
            : observacionesPedidoController.text
                  .trim(), // Usar observaciones del pedido
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

    // Regresar a la pantalla anterior y notificar que se actualizó
    Navigator.pop(context, true);
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
          // Indicador de conexión WebSocket
          Consumer<DatosCacheProvider>(
            builder: (context, cacheProvider, child) {
              return Icon(
                cacheProvider.isConnected ? Icons.wifi : Icons.wifi_off,
                color: cacheProvider.isConnected ? Colors.green : Colors.red,
                size: 20,
              );
            },
          ),
          SizedBox(width: 8),
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              final cacheProvider = Provider.of<DatosCacheProvider>(
                context,
                listen: false,
              );
              cacheProvider.recargarDatos();
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

                // ✅ NUEVO: Botones compactos para campos opcionales
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      // Botón para observaciones
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _mostrarObservaciones = !_mostrarObservaciones;
                              if (!_mostrarObservaciones) {
                                _mostrarComandos = false; // Solo uno a la vez
                              }
                            });
                          },
                          icon: Icon(
                            _mostrarObservaciones
                                ? Icons.keyboard_arrow_up
                                : Icons.note_add,
                            size: 18,
                          ),
                          label: Text(
                            'Observaciones',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mostrarObservaciones
                                ? primary
                                : cardBg,
                            foregroundColor: _mostrarObservaciones
                                ? Colors.white
                                : textLight,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Botón para comandos rápidos
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _mostrarComandos = !_mostrarComandos;
                              if (!_mostrarComandos) {
                                _mostrarObservaciones =
                                    false; // Solo uno a la vez
                              }
                            });
                          },
                          icon: Icon(
                            _mostrarComandos
                                ? Icons.keyboard_arrow_up
                                : Icons.flash_on,
                            size: 18,
                          ),
                          label: Text(
                            'Comandos',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mostrarComandos
                                ? primary
                                : cardBg,
                            foregroundColor: _mostrarComandos
                                ? Colors.white
                                : textLight,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Botón de ayuda para comandos
                      IconButton(
                        onPressed: _mostrarAyudaComandos,
                        icon: Icon(
                          Icons.help_outline,
                          color: primary.withOpacity(0.7),
                        ),
                        tooltip: 'Ver ejemplos de comandos',
                        iconSize: 20,
                      ),
                    ],
                  ),
                ),

                // ✅ Campo de observaciones (desplegable)
                if (_mostrarObservaciones)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: observacionesPedidoController,
                      style: TextStyle(color: textLight),
                      maxLines: 2,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText:
                            'Observaciones del pedido (ej: sopa poquita, sin arroz, etc.)...',
                        hintStyle: TextStyle(color: textLight.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.note_add, color: primary),
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primary),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),

                // ✅ Campo de comandos rápidos (desplegable)
                if (_mostrarComandos)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: comandoTextoController,
                      style: TextStyle(color: textLight),
                      decoration: InputDecoration(
                        hintText:
                            'Comandos: "1 S, 2 F, 1(cerdo y res), 1 Paisa"...',
                        hintStyle: TextStyle(color: textLight.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.flash_on, color: primary),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.send, color: primary),
                          onPressed: () {
                            _procesarComandoTexto(comandoTextoController.text);
                          },
                        ),
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primary),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (value) {
                        _procesarComandoTexto(value);
                      },
                    ),
                  ),

                // 🎨 MEJORADO: Filtro de categorías - Wrap con scroll vertical para PC
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.width < 768
                        ? 50
                        : 120, // Móvil: 1 fila, PC: múltiples filas
                  ),
                  margin: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ), // Reducido margen vertical
                  child: MediaQuery.of(context).size.width < 768
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.only(right: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: _buildCategoriaCompactRow(),
                          ),
                        )
                      : Scrollbar(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            padding: EdgeInsets.only(bottom: 4),
                            child: Wrap(
                              spacing: 8.0, // Espaciado horizontal entre chips
                              runSpacing:
                                  6.0, // Espaciado vertical entre filas reducido
                              children: _buildCategoriaCompactRow(),
                            ),
                          ),
                        ),
                ),

                SizedBox(height: 6), // Reducido de 12 a 6
                // Lista de productos disponibles
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                          ), // ✅ Reducido padding
                          // ✅ GRILLA MÁS COMPACTA: Más productos visibles
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent:
                                MediaQuery.of(context).size.width > 1200
                                ? 220 // ✅ Reducido de 300 a 220px en desktop
                                : MediaQuery.of(context).size.width > 800
                                ? 180 // ✅ Reducido de 250 a 180px en tablet
                                : 140, // ✅ Reducido de 180 a 140px en móvil
                            childAspectRatio:
                                0.85, // ✅ Más vertical para mostrar más filas
                            crossAxisSpacing: 8, // ✅ Reducido espaciado
                            mainAxisSpacing: 8, // ✅ Reducido espaciado
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

        // Campo de observaciones del pedido
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: observacionesPedidoController,
            style: TextStyle(color: textLight),
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              hintText:
                  'Observaciones del pedido (ej: sopa poquita, sin arroz, etc.)...',
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

        // Campo de comandos de texto rápido
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: comandoTextoController,
            style: TextStyle(color: textLight),
            decoration: InputDecoration(
              hintText: 'Comandos: "1 S, 2 F, 1(cerdo y res)"...',
              hintStyle: TextStyle(color: textLight.withOpacity(0.5)),
              prefixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on, color: primary),
                  IconButton(
                    icon: Icon(
                      Icons.help_outline,
                      color: primary.withOpacity(0.7),
                      size: 20,
                    ),
                    onPressed: _mostrarAyudaComandos,
                    tooltip: 'Ayuda',
                  ),
                ],
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.send, color: primary),
                onPressed: () {
                  _procesarComandoTexto(comandoTextoController.text);
                },
              ),
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
            onSubmitted: (value) {
              _procesarComandoTexto(value);
            },
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

  // Método de filtrado local directo (fallback para cuando la API no está disponible)
  List<Producto> _filtrarProductosLocal() {
    // Usar productos directos disponibles en memoria
    final productosData = productosDisponibles;

    // Si no hay filtros, devolver todos los productos
    if (filtro.isEmpty && categoriaSelecionadaId == null) {
      return productosData;
    }

    return productosData.where((producto) {
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
    double total = productosMesa.fold(0, (sum, producto) {
      // Solo incluir productos activos (no tachados) en el total
      bool estaActivo = productoPagado[producto.id] != false;
      if (estaActivo) {
        double subtotal = producto.precio * producto.cantidad;
        print(
          '📊 Producto ${producto.nombre}: ${producto.cantidad} x \$${producto.precio} = \$${subtotal} (Activo: $estaActivo)',
        );
        return sum + subtotal;
      } else {
        print(
          '❌ Producto ${producto.nombre}: Excluido del total (Activo: $estaActivo)',
        );
        return sum;
      }
    });
    print('💰 TOTAL CALCULADO: \$${total}');
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
        // Si el producto tiene ingredientes opcionales, siempre mostrar el diálogo y agregar como nuevo
        if (producto.ingredientesOpcionales.isNotEmpty) {
          final resultadoIngredientes =
              await _mostrarDialogoSeleccionIngredientes(producto);
          if (resultadoIngredientes != null) {
            List<String> ingredientesSeleccionados =
                resultadoIngredientes['ingredientes'] as List<String>;
            String? notasEspeciales = resultadoIngredientes['notas'] as String?;

            // 🥩 NUEVA LÓGICA: Detectar ingredientes opcionales (carnes) seleccionados
            List<String> ingredientesOpcionales = [];
            List<String> ingredientesBasicos = [];

            // Separar ingredientes opcionales de básicos
            for (String ingrediente in ingredientesSeleccionados) {
              bool esOpcional = false;
              for (var opcionalData in producto.ingredientesOpcionales) {
                String nombreConPrecio = opcionalData.ingredienteNombre;
                if (opcionalData.precioAdicional > 0) {
                  nombreConPrecio +=
                      ' (+\$${opcionalData.precioAdicional.toStringAsFixed(0)})';
                }
                if (ingrediente == nombreConPrecio) {
                  ingredientesOpcionales.add(ingrediente);
                  esOpcional = true;
                  break;
                }
              }
              if (!esOpcional) {
                ingredientesBasicos.add(ingrediente);
              }
            }

            setState(() {
              if (ingredientesOpcionales.isNotEmpty) {
                // 🚀 CREAR MÚLTIPLES EJECUTIVOS: uno por cada carne seleccionada
                int productosCreados = 0;

                for (String carneSeleccionada in ingredientesOpcionales) {
                  productosCreados++;

                  // Crear nota específica para este ejecutivo
                  String notaEjecutivo = 'Ejecutivo #$productosCreados';
                  if (carneSeleccionada.isNotEmpty) {
                    notaEjecutivo += ' - $carneSeleccionada';
                  }
                  if (ingredientesBasicos.isNotEmpty) {
                    notaEjecutivo += ' + ${ingredientesBasicos.join(', ')}';
                  }
                  if (notasEspeciales != null && notasEspeciales.isNotEmpty) {
                    notaEjecutivo += ' | $notasEspeciales';
                  }

                  // Crear el producto individual con la carne específica
                  List<String> ingredientesParaEsteProducto = [
                    carneSeleccionada,
                  ];
                  ingredientesParaEsteProducto.addAll(ingredientesBasicos);

                  Producto nuevoEjecutivo = Producto(
                    id: producto.id,
                    nombre: '${producto.nombre} #$productosCreados',
                    precio: producto.precio,
                    costo: producto.costo,
                    impuestos: producto.impuestos,
                    utilidad: producto.utilidad,
                    tieneVariantes: producto.tieneVariantes,
                    estado: producto.estado,
                    imagenUrl: producto.imagenUrl,
                    categoria: producto.categoria,
                    descripcion: producto.descripcion,
                    nota: notaEjecutivo,
                    cantidad: 1,
                    ingredientesDisponibles: ingredientesParaEsteProducto,
                    ingredientesRequeridos: producto.ingredientesRequeridos,
                    ingredientesOpcionales: producto.ingredientesOpcionales,
                    tieneIngredientes: producto.tieneIngredientes,
                    tipoProducto: producto.tipoProducto,
                  );

                  productosMesa.add(nuevoEjecutivo);
                  productoPagado[nuevoEjecutivo.id] = true;
                }

                // Mostrar mensaje de confirmación
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '¡Excelente! Se crearon $productosCreados ejecutivos separados',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                    action: SnackBarAction(
                      label: 'Ver',
                      textColor: Colors.white,
                      onPressed: () {
                        // Scroll hacia abajo para mostrar los productos agregados
                      },
                    ),
                  ),
                );

                print(
                  '✅ Creados $productosCreados ejecutivos con carnes: ${ingredientesOpcionales.join(', ')}',
                );
              } else {
                // Si no hay carnes seleccionadas, crear un solo producto normal
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
                  ingredientesRequeridos: producto.ingredientesRequeridos,
                  ingredientesOpcionales: producto.ingredientesOpcionales,
                  tieneIngredientes: producto.tieneIngredientes,
                  tipoProducto: producto.tipoProducto,
                );
                productosMesa.add(nuevoProd);
                productoPagado[nuevoProd.id] = true;
              }

              _calcularTotal();
            });
          }
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
              flex: 4, // ✅ Reducido de 5 a 4 para imagen más compacta
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(4), // ✅ Reducido de 6 a 4
                child: _buildProductImage(producto.imagenUrl),
              ),
            ),
            // Información del producto (categoría, nombre, precio)
            Expanded(
              flex: 3, // ✅ Aumentado de 2 a 3 para mejor balance
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Etiqueta de categoría
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        categoriaText,
                        style: TextStyle(
                          color: primary,
                          fontSize: 7, // ✅ Reducido de 8 a 7
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Nombre del producto
                    Text(
                      producto.nombre,
                      style: TextStyle(
                        color: textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 10, // ✅ Reducido de 11 a 10
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
                        fontSize: 11, // ✅ Reducido de 12 a 11
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(
    String? imagenUrl, {
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
        child: ImagenProductoWidget(
          urlRemota: imagenUrl != null
              ? _imageService.getImageUrl(imagenUrl)
              : null,
          width: width ?? double.infinity,
          height: height ?? double.infinity,
          fit: BoxFit.cover,
          backendBaseUrl: EndpointsConfig().baseUrl,
        ),
      ),
    );
  }

  // Función para convertir IDs de ingredientes a nombres
  String _getIngredienteNombre(String ingredienteId) {
    final ingrediente = ingredientes.firstWhere(
      (ing) => ing.id == ingredienteId,
      orElse: () => Ingrediente(
        id: ingredienteId,
        nombre: 'Ingrediente desconocido',
        categoria: 'Sin categoría',
        cantidad: 0,
        unidad: 'unidad',
        costo: 0,
      ),
    );
    return ingrediente.nombre;
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

    // Obtener ingredientes seleccionados (carne/opcion/ejecutivo)
    final List<String> seleccionados = producto.ingredientesDisponibles
        .where((ing) => ing.trim().isNotEmpty)
        .toList();

    String resumenSeleccion;
    if (seleccionados.isNotEmpty) {
      // Convertir IDs a nombres de ingredientes
      final nombresIngredientes = seleccionados
          .map((id) => _getIngredienteNombre(id))
          .toList();

      resumenSeleccion = nombresIngredientes.length == 1
          ? 'Adición: ${nombresIngredientes.first}'
          : 'Adiciones: ${nombresIngredientes.join(", ")}';
    } else {
      resumenSeleccion = 'Sin seleccionar';
    }

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
              if (!isMovil) SizedBox(width: 50),
              Container(
                margin: EdgeInsets.only(right: 8),
                child: _buildProductImage(
                  producto.imagenUrl,
                  width: isMovil ? 50 : 40,
                  height: isMovil ? 50 : 40,
                ),
              ),
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
                    // Mostrar resumen de selección de carne/opción/ingrediente
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, left: 2.0),
                      child: Text(
                        resumenSeleccion,
                        style: TextStyle(
                          color: resumenSeleccion == 'Sin seleccionar'
                              ? Colors.grey
                              : Colors.orange,
                          fontSize: 12,
                          fontStyle: resumenSeleccion == 'Sin seleccionar'
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        maxLines: 2,
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

              // Precio
              Text(
                formatCurrency(producto.precio * producto.cantidad),
                style: TextStyle(
                  color: productoPagado[producto.id]!
                      ? primary
                      : primary.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                  fontSize: isMovil ? 18 : 13,
                ),
              ),
            ],
          ),

          // Botón removido según solicitud del usuario
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

  // 🎨 NUEVA: Barra compacta de categorías - Una sola fila horizontal
  List<Widget> _buildCategoriaCompactRow() {
    List<Widget> allCategories = [];

    // Agregar opción "Todos" - más compacta
    allCategories.add(
      _buildCategoriaCompactChip(
        nombre: 'Todo',
        icon: Icons.apps,
        isSelected: categoriaSelecionadaId == null,
        onTap: () => setState(() {
          categoriaSelecionadaId = null;
          _resetearPaginacion();
          _actualizarProductosVista();
        }),
      ),
    );

    // Agregar todas las categorías de forma compacta
    allCategories.addAll(
      categorias.map(
        (categoria) => _buildCategoriaCompactChip(
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

    return allCategories;
  }

  // Genera columnas con 2 filas de categorías (Desktop) - MANTENER PARA COMPATIBILIDAD

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
  // 🎨 NUEVO: Widget compacto para categorías - Más pequeño y eficiente
  Widget _buildCategoriaCompactChip({
    required String nombre,
    String? imagenUrl,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primary = Color(0xFFFF6B00);
    final cardBg = Color(0xFF2A2A2A);
    final textLight = Color(0xFFB0B0B0);

    return Container(
      margin: EdgeInsets.only(right: 8), // Espaciado entre chips
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8, // ✅ Reducido de 10 a 8
            vertical: 4, // ✅ Reducido de 6 a 4
          ),
          decoration: BoxDecoration(
            color: isSelected ? primary : cardBg,
            borderRadius: BorderRadius.circular(12), // ✅ Reducido de 16 a 12
            border: Border.all(
              color: isSelected ? primary : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Imagen circular o icono - Más pequeño
              Container(
                width: 20, // ✅ Reducido de 24 a 20
                height: 20, // ✅ Reducido de 24 a 20
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.3),
                ),
                child: ClipOval(
                  child: imagenUrl != null && imagenUrl.isNotEmpty
                      ? Image.network(
                          _imageService.getImageUrl(imagenUrl),
                          fit: BoxFit.cover,
                          headers: {
                            'Cache-Control': 'no-cache',
                            'User-Agent': 'Flutter App',
                          },
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.restaurant_menu,
                            color: isSelected ? Colors.white : textLight,
                            size: 12, // ✅ Reducido de 14 a 12
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Icon(
                              Icons.restaurant_menu,
                              color: isSelected ? Colors.white : textLight,
                              size: 12, // ✅ Reducido de 14 a 12
                            );
                          },
                        )
                      : Icon(
                          icon ?? Icons.restaurant_menu,
                          color: isSelected ? Colors.white : textLight,
                          size: 12, // ✅ Reducido de 14 a 12
                        ),
                ),
              ),
              SizedBox(width: 4), // ✅ Reducido de 6 a 4
              // Texto de la categoría - Más compacto
              Text(
                nombre,
                style: TextStyle(
                  color: isSelected ? Colors.white : textLight,
                  fontSize: 11, // ✅ Reducido de 12 a 11
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
