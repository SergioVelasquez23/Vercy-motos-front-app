import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gasto_programado.dart';
import '../services/cartera_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';

class GastosProgramadosScreen extends StatefulWidget {
  const GastosProgramadosScreen({Key? key}) : super(key: key);

  @override
  State<GastosProgramadosScreen> createState() =>
      _GastosProgramadosScreenState();
}

class _GastosProgramadosScreenState extends State<GastosProgramadosScreen> {
  final CarteraService _carteraService = CarteraService();

  List<GastoProgramado> gastos = [];
  List<GastoProgramado> gastosFiltrados = [];
  bool isLoading = true;
  String? error;
  CategoriaGasto? filtroCategoria;
  EstadoGastoProgramado? filtroEstado;
  bool soloActivos = true;
  String busqueda = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarGastos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarGastos() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await _carteraService.getGastosProgramados();
      if (response.isSuccess) {
        setState(() {
          gastos = response.data ?? [];
          _aplicarFiltros();
          isLoading = false;
        });
      } else {
        setState(() {
          error = response.message;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = errorMessage(e);
        isLoading = false;
      });
    }
  }

  void _aplicarFiltros() {
    List<GastoProgramado> resultado = List.from(gastos);

    // Filtro por activos
    if (soloActivos) {
      resultado = resultado.where((gasto) => gasto.activo).toList();
    }

    // Filtro por categoría
    if (filtroCategoria != null) {
      resultado = resultado
          .where((gasto) => gasto.categoria == filtroCategoria)
          .toList();
    }

    // Filtro por estado
    if (filtroEstado != null) {
      resultado = resultado
          .where((gasto) => gasto.estado == filtroEstado)
          .toList();
    }

    // Filtro por búsqueda
    if (busqueda.isNotEmpty) {
      resultado = resultado.where((gasto) {
        return gasto.nombre.toLowerCase().contains(busqueda.toLowerCase());
      }).toList();
    }

    // Ordenar: primero los vencidos, luego por próxima fecha
    resultado.sort((a, b) {
      if (a.estaVencido && !b.estaVencido) return -1;
      if (!a.estaVencido && b.estaVencido) return 1;
      if (a.proximoAPagar && !b.proximoAPagar) return -1;
      if (!a.proximoAPagar && b.proximoAPagar) return 1;

      if (a.proximaFecha == null && b.proximaFecha == null) return 0;
      if (a.proximaFecha == null) return 1;
      if (b.proximaFecha == null) return -1;

      return a.proximaFecha!.compareTo(b.proximaFecha!);
    });

    setState(() {
      gastosFiltrados = resultado;
    });
  }

  Future<void> _mostrarFormularioCrear() async {
    await showDialog(
      context: context,
      builder: (context) => const _FormularioGastoProgramado(),
    );
    _cargarGastos(); // Recargar después de crear
  }

  Future<void> _marcarComoPagado(GastoProgramado gasto) async {
    final TextEditingController montoController = TextEditingController();
    montoController.text = gasto.montoEstimado.toString();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Marcar como Pagado - ${gasto.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monto estimado: ${CurrencyUtils.format(gasto.montoEstimado)}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: montoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto real pagado',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final monto = double.tryParse(montoController.text);
              if (monto != null && monto > 0) {
                Navigator.pop(context, monto);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingrese un monto válido'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Marcar Pagado'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _procesarPago(gasto, result);
    }
  }

  Future<void> _procesarPago(GastoProgramado gasto, double montoReal) async {
    try {
      final response = await _carteraService.marcarGastoComoPagado(
        gasto.id!,
        montoReal,
      );
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto marcado como pagado'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarGastos();
      } else {
        showErrorDialog(context, response.message);
      }
    } catch (e) {
      showErrorDialog(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Gastos Programados'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cargarGastos,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _mostrarFormularioCrear,
          backgroundColor: AppTheme.primary,
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            // Filtros y búsqueda
            Container(
              color: AppTheme.primary,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Campo de búsqueda
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar gastos...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      busqueda = value;
                      _aplicarFiltros();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Filtros por categoría
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Solo Activos'),
                          selected: soloActivos,
                          onSelected: (selected) {
                            setState(() {
                              soloActivos = selected;
                              _aplicarFiltros();
                            });
                          },
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          selectedColor: Colors.white,
                          checkmarkColor: AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        _buildCategoriaChip('Todos', null),
                        const SizedBox(width: 8),
                        _buildCategoriaChip(
                          CategoriaGasto.serviciosPublicos.icon + ' Servicios',
                          CategoriaGasto.serviciosPublicos,
                        ),
                        const SizedBox(width: 8),
                        _buildCategoriaChip(
                          CategoriaGasto.nomina.icon + ' Nómina',
                          CategoriaGasto.nomina,
                        ),
                        const SizedBox(width: 8),
                        _buildCategoriaChip(
                          CategoriaGasto.impuestos.icon + ' Impuestos',
                          CategoriaGasto.impuestos,
                        ),
                        const SizedBox(width: 8),
                        _buildCategoriaChip(
                          CategoriaGasto.otros.icon + ' Otros',
                          CategoriaGasto.otros,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de gastos
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? _buildErrorWidget()
                  : _buildGastosList(),
            ),
          ], // cierra children del Column
        ), // cierra Column del body
    ); // cierra Scaffold
  }

  Widget _buildCategoriaChip(String label, CategoriaGasto? categoria) {
    final isSelected = filtroCategoria == categoria;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          filtroCategoria = selected ? categoria : null;
          _aplicarFiltros();
        });
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Colors.white,
      checkmarkColor: AppTheme.primary,
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error al cargar gastos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _cargarGastos,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildGastosList() {
    if (gastosFiltrados.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No se encontraron gastos programados'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarGastos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: gastosFiltrados.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildResumenHeader();
          }

          final gasto = gastosFiltrados[index - 1];
          return _buildGastoCard(gasto);
        },
      ),
    );
  }

  Widget _buildResumenHeader() {
    final totalEstimado = gastosFiltrados.fold<double>(
      0,
      (sum, gasto) => sum + gasto.montoEstimado,
    );

    final vencidos = gastosFiltrados.where((g) => g.estaVencido).length;
    final proximos = gastosFiltrados.where((g) => g.proximoAPagar).length;
    final pendientes = gastosFiltrados
        .where((g) => g.estado == EstadoGastoProgramado.activo)
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResumenItem(
                  'Total',
                  CurrencyUtils.formatShort(totalEstimado),
                  Icons.receipt,
                  AppTheme.primary,
                ),
                _buildResumenItem(
                  'Gastos',
                  '${gastosFiltrados.length}',
                  Icons.schedule,
                  Colors.blue,
                ),
                _buildResumenItem(
                  'Pendientes',
                  '$pendientes',
                  Icons.pending,
                  Colors.orange,
                ),
                _buildResumenItem(
                  '¡Urgentes!',
                  '${vencidos + proximos}',
                  Icons.warning,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildGastoCard(GastoProgramado gasto) {
    Color? estadoColor;
    IconData estadoIcon;

    if (gasto.estaVencido) {
      estadoColor = Colors.red;
      estadoIcon = Icons.warning;
    } else if (gasto.proximoAPagar) {
      estadoColor = Colors.orange;
      estadoIcon = Icons.schedule;
    } else {
      switch (gasto.estado) {
        case EstadoGastoProgramado.activo:
          estadoColor = Colors.blue;
          estadoIcon = Icons.pending;
          break;
        case EstadoGastoProgramado.pausado:
          estadoColor = Colors.green;
          estadoIcon = Icons.check_circle;
          break;
        case EstadoGastoProgramado.inactivo:
          estadoColor = Colors.red;
          estadoIcon = Icons.warning;
          break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con nombre y estado
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      gasto.categoria == CategoriaGasto.serviciosPublicos
                      ? Colors.blue[100]
                      : gasto.categoria == CategoriaGasto.nomina
                      ? Colors.green[100]
                      : gasto.categoria == CategoriaGasto.impuestos
                      ? Colors.purple[100]
                      : Colors.grey[100],
                  child: Text(
                    gasto.categoria.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gasto.nombre,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${gasto.categoria.displayName} • ${gasto.frecuencia.displayName}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: estadoColor?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(estadoIcon, size: 14, color: estadoColor),
                      const SizedBox(width: 4),
                      Text(
                        gasto.estaVencido
                            ? '¡Vencido!'
                            : gasto.proximoAPagar
                            ? '¡Próximo!'
                            : gasto.estado.displayName,
                        style: TextStyle(
                          color: estadoColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Alerta si está vencido o próximo
            if (gasto.estaVencido || gasto.proximoAPagar) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gasto.estaVencido ? Colors.red[50] : Colors.orange[50],
                  border: Border.all(
                    color: gasto.estaVencido ? Colors.red : Colors.orange,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      gasto.estaVencido ? Icons.warning : Icons.schedule,
                      color: gasto.estaVencido ? Colors.red : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        gasto.estaVencido
                            ? '¡Este gasto está vencido!'
                            : '¡Gasto próximo a vencer!',
                        style: TextStyle(
                          color: gasto.estaVencido ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Información de monto y fecha
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monto estimado:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      CurrencyUtils.format(gasto.montoEstimado),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: estadoColor,
                      ),
                    ),
                    if (gasto.fechaUltimoPago != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Último pago: ${CurrencyUtils.format(gasto.montoUltimoPago ?? 0)}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.green),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(gasto.fechaUltimoPago!),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.green),
                      ),
                    ],
                  ],
                ),
                if (gasto.proximaFecha != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Próxima fecha:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(gasto.proximaFecha!),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (gasto.proximaFecha!.isAfter(DateTime.now()))
                        Text(
                          'En ${gasto.proximaFecha!.difference(DateTime.now()).inDays} días',
                          style: TextStyle(fontSize: 12, color: estadoColor),
                        ),
                    ],
                  ),
              ],
            ),

            // Configuración de frecuencia
            if (gasto.frecuencia == FrecuenciaGasto.mensual &&
                gasto.diaDelMes != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Se paga el día ${gasto.diaDelMes} de cada mes',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],

            if (gasto.frecuencia == FrecuenciaGasto.quincenal &&
                gasto.diasQuincena != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Se paga los días ${gasto.diasQuincena!.join(' y ')} de cada mes',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],

            // Botones de acción
            if (gasto.estado == EstadoGastoProgramado.activo) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _marcarComoPagado(gasto),
                    icon: const Icon(Icons.payment),
                    label: const Text('Marcar Pagado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Formulario para crear nuevo gasto programado
class _FormularioGastoProgramado extends StatefulWidget {
  const _FormularioGastoProgramado();

  @override
  State<_FormularioGastoProgramado> createState() =>
      __FormularioGastoProgramadoState();
}

class __FormularioGastoProgramadoState
    extends State<_FormularioGastoProgramado> {
  final _formKey = GlobalKey<FormState>();
  final CarteraService _carteraService = CarteraService();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _diaDelMesController = TextEditingController();

  CategoriaGasto categoria = CategoriaGasto.serviciosPublicos;
  FrecuenciaGasto frecuencia = FrecuenciaGasto.mensual;
  List<int> diasQuincena = [15, 30];
  bool isSubmitting = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _montoController.dispose();
    _diaDelMesController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final gasto = GastoProgramado(
        nombre: _nombreController.text,
        categoria: categoria,
        frecuencia: frecuencia,
        montoEstimado: double.parse(_montoController.text),
        diaDelMes: frecuencia == FrecuenciaGasto.mensual
            ? int.tryParse(_diaDelMesController.text)
            : null,
        diasQuincena: frecuencia == FrecuenciaGasto.quincenal
            ? diasQuincena
            : null,
      );

      final response = await _carteraService.crearGastoProgramado(gasto);
      if (response.isSuccess) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto programado creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        showErrorDialog(context, response.message);
      }
    } catch (e) {
      showErrorDialog(context, errorMessage(e));
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Gasto Programado'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del gasto',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<CategoriaGasto>(
                  value: categoria,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                  items: CategoriaGasto.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text('${cat.icon} ${cat.displayName}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      categoria = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<FrecuenciaGasto>(
                  value: frecuencia,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia',
                    border: OutlineInputBorder(),
                  ),
                  items: [FrecuenciaGasto.mensual, FrecuenciaGasto.quincenal]
                      .map((freq) {
                        return DropdownMenuItem(
                          value: freq,
                          child: Text(freq.displayName),
                        );
                      })
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      frecuencia = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _montoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto estimado',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Campo requerido';
                    if (double.tryParse(value!) == null)
                      return 'Monto inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                if (frecuencia == FrecuenciaGasto.mensual)
                  TextFormField(
                    controller: _diaDelMesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Día del mes (1-31)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Campo requerido';
                      final num = int.tryParse(value!);
                      if (num == null || num < 1 || num > 31) {
                        return 'Día inválido (1-31)';
                      }
                      return null;
                    },
                  ),

                if (frecuencia == FrecuenciaGasto.quincenal)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Días de quincena:'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Día 15'),
                                value: diasQuincena.contains(15),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      if (!diasQuincena.contains(15))
                                        diasQuincena.add(15);
                                    } else {
                                      diasQuincena.remove(15);
                                    }
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Día 30'),
                                value: diasQuincena.contains(30),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      if (!diasQuincena.contains(30))
                                        diasQuincena.add(30);
                                    } else {
                                      diasQuincena.remove(30);
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: isSubmitting ? null : _guardar,
          child: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
