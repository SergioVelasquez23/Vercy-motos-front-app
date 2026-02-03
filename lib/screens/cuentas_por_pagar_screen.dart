import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cuenta_por_pagar.dart';
import '../services/cartera_service.dart';
import '../utils/currency_utils.dart';
import '../widgets/vercy_sidebar_layout.dart';

class CuentasPorPagarScreen extends StatefulWidget {
  const CuentasPorPagarScreen({Key? key}) : super(key: key);

  @override
  State<CuentasPorPagarScreen> createState() => _CuentasPorPagarScreenState();
}

class _CuentasPorPagarScreenState extends State<CuentasPorPagarScreen> {
  final CarteraService _carteraService = CarteraService();

  List<CuentaPorPagar> cuentas = [];
  List<CuentaPorPagar> cuentasFiltradas = [];
  bool isLoading = true;
  String? error;
  EstadoCuentaPagar? filtroEstado;
  bool soloConDescuento = false;
  String busqueda = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarCuentas() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await _carteraService.getCuentasPorPagar();
      if (response.isSuccess) {
        setState(() {
          cuentas = response.data ?? [];
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
        error = 'Error de conexión: $e';
        isLoading = false;
      });
    }
  }

  void _aplicarFiltros() {
    List<CuentaPorPagar> resultado = List.from(cuentas);

    // Filtro por estado
    if (filtroEstado != null) {
      resultado = resultado
          .where((cuenta) => cuenta.estado == filtroEstado)
          .toList();
    }

    // Filtro por descuento
    if (soloConDescuento) {
      resultado = resultado.where((cuenta) => cuenta.tieneDescuento).toList();
    }

    // Filtro por búsqueda
    if (busqueda.isNotEmpty) {
      resultado = resultado.where((cuenta) {
        return cuenta.proveedorNombre.toLowerCase().contains(
              busqueda.toLowerCase(),
            ) ||
            cuenta.numeroFactura.toLowerCase().contains(busqueda.toLowerCase());
      }).toList();
    }

    // Ordenar: primero los que van a perder descuento, luego por fecha de vencimiento
    resultado.sort((a, b) {
      if (a.proximoAPerderDescuento && !b.proximoAPerderDescuento) return -1;
      if (!a.proximoAPerderDescuento && b.proximoAPerderDescuento) return 1;
      return a.fechaVencimiento.compareTo(b.fechaVencimiento);
    });

    setState(() {
      cuentasFiltradas = resultado;
    });
  }

  Future<void> _mostrarFormularioCrear() async {
    await showDialog(
      context: context,
      builder: (context) => const _FormularioCuentaPorPagar(),
    );
    _cargarCuentas(); // Recargar después de crear
  }

  @override
  Widget build(BuildContext context) {
    return VercySidebarLayout(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cuentas por Pagar'),
          backgroundColor: const Color(0xFFFF9800),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cargarCuentas,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _mostrarFormularioCrear,
          backgroundColor: const Color(0xFFFF9800),
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            // Filtros y búsqueda
            Container(
              color: const Color(0xFFFF9800),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Campo de búsqueda
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por proveedor o factura...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
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

                  // Filtros por estado
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFiltroChip('Todos', null),
                        const SizedBox(width: 8),
                        _buildFiltroChip(
                          'Pendientes',
                          EstadoCuentaPagar.PENDIENTE,
                        ),
                        const SizedBox(width: 8),
                        _buildFiltroChip('Vencidas', EstadoCuentaPagar.VENCIDA),
                        const SizedBox(width: 8),
                        _buildFiltroChip('Pagadas', EstadoCuentaPagar.PAGADA),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Con Descuento'),
                          selected: soloConDescuento,
                          onSelected: (selected) {
                            setState(() {
                              soloConDescuento = selected;
                              _aplicarFiltros();
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Colors.white,
                          checkmarkColor: const Color(0xFFFF9800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de cuentas
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? _buildErrorWidget()
                  : _buildCuentasList(),
            ),
          ], // cierra children del Column
        ), // cierra Column del body
      ), // cierra Scaffold
    ); // cierra VercySidebarLayout
  }

  Widget _buildFiltroChip(String label, EstadoCuentaPagar? estado) {
    final isSelected = filtroEstado == estado;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          filtroEstado = selected ? estado : null;
          _aplicarFiltros();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.white,
      checkmarkColor: const Color(0xFFFF9800),
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
            'Error al cargar cuentas',
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
            onPressed: _cargarCuentas,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildCuentasList() {
    if (cuentasFiltradas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No se encontraron cuentas por pagar'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarCuentas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cuentasFiltradas.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildResumenHeader();
          }

          final cuenta = cuentasFiltradas[index - 1];
          return _buildCuentaCard(cuenta);
        },
      ),
    );
  }

  Widget _buildResumenHeader() {
    final total = cuentasFiltradas.fold<double>(
      0,
      (sum, cuenta) => sum + cuenta.saldoPendiente,
    );

    final conDescuento = cuentasFiltradas.where((c) => c.tieneDescuento).length;
    final proximasPerder = cuentasFiltradas
        .where((c) => c.proximoAPerderDescuento)
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
                  CurrencyUtils.format(total),
                  Icons.payments,
                  const Color(0xFFFF9800),
                ),
                _buildResumenItem(
                  'Cuentas',
                  '${cuentasFiltradas.length}',
                  Icons.receipt,
                  Colors.blue,
                ),
                _buildResumenItem(
                  'Con Desc.',
                  '$conDescuento',
                  Icons.local_offer,
                  Colors.green,
                ),
                _buildResumenItem(
                  '¡Riesgo!',
                  '$proximasPerder',
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

  Widget _buildCuentaCard(CuentaPorPagar cuenta) {
    Color? estadoColor;
    IconData estadoIcon;

    if (cuenta.proximoAPerderDescuento) {
      estadoColor = Colors.red;
      estadoIcon = Icons.warning;
    } else {
      switch (cuenta.estado) {
        case EstadoCuentaPagar.VENCIDA:
          estadoColor = Colors.red;
          estadoIcon = Icons.warning;
          break;
        case EstadoCuentaPagar.PENDIENTE:
          estadoColor = Colors.orange;
          estadoIcon = Icons.pending;
          break;
        case EstadoCuentaPagar.PAGADA:
          estadoColor = Colors.green;
          estadoIcon = Icons.check_circle;
          break;
        default:
          estadoColor = Colors.blue;
          estadoIcon = Icons.payment;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con proveedor y estado
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cuenta.proveedorNombre,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Factura: ${cuenta.numeroFactura}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (cuenta.tieneDescuento)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cuenta.proximoAPerderDescuento
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_offer,
                          size: 12,
                          color: cuenta.proximoAPerderDescuento
                              ? Colors.red
                              : Colors.green,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${cuenta.porcentajeDescuento}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: cuenta.proximoAPerderDescuento
                                ? Colors.red
                                : Colors.green,
                          ),
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
                        cuenta.proximoAPerderDescuento
                            ? '¡Desc. Riesgo!'
                            : cuenta.estado.displayName,
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

            // Alerta de descuento en riesgo
            if (cuenta.proximoAPerderDescuento) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¡Descuento del ${cuenta.porcentajeDescuento}% se pierde en ${cuenta.diasParaPerderDescuento} días!',
                        style: const TextStyle(
                          color: Colors.red,
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

            // Información de montos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: ${CurrencyUtils.format(cuenta.montoTotal)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (cuenta.tieneDescuento && !cuenta.descuentoPerdido)
                      Text(
                        'Con descuento: ${CurrencyUtils.format(cuenta.montoConDescuento)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (cuenta.tieneDescuento)
                      Text(
                        'Ahorro: ${CurrencyUtils.format(cuenta.montoDescuento)}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.green),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyUtils.format(cuenta.saldoPendiente),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: estadoColor,
                      ),
                    ),
                    if (cuenta.tieneDescuento &&
                        cuenta.fechaLimiteDescuento != null)
                      Text(
                        'Desc. hasta: ${DateFormat('dd/MM').format(cuenta.fechaLimiteDescuento!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cuenta.proximoAPerderDescuento
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Fecha de vencimiento
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: estadoColor),
                const SizedBox(width: 4),
                Text(
                  'Vence: ${DateFormat('dd/MM/yyyy').format(cuenta.fechaVencimiento)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Text(
                  cuenta.estaVencida
                      ? '(${cuenta.diasVencimiento.abs()} días vencida)'
                      : '(${cuenta.diasVencimiento} días)',
                  style: TextStyle(
                    fontSize: 12,
                    color: estadoColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Formulario para crear nueva cuenta por pagar
class _FormularioCuentaPorPagar extends StatefulWidget {
  const _FormularioCuentaPorPagar();

  @override
  State<_FormularioCuentaPorPagar> createState() =>
      __FormularioCuentaPorPagarState();
}

class __FormularioCuentaPorPagarState extends State<_FormularioCuentaPorPagar> {
  final _formKey = GlobalKey<FormState>();
  final CarteraService _carteraService = CarteraService();

  final TextEditingController _proveedorController = TextEditingController();
  final TextEditingController _facturaController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _diasVencimientoController =
      TextEditingController();
  final TextEditingController _porcentajeDescuentoController =
      TextEditingController();
  final TextEditingController _diasDescuentoController =
      TextEditingController();

  bool tieneDescuento = false;
  bool isSubmitting = false;

  @override
  void dispose() {
    _proveedorController.dispose();
    _facturaController.dispose();
    _montoController.dispose();
    _diasVencimientoController.dispose();
    _porcentajeDescuentoController.dispose();
    _diasDescuentoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final cuenta = CuentaPorPagar(
        proveedorId:
            'temp', // Esto debería venir de una selección de proveedores
        proveedorNombre: _proveedorController.text,
        numeroFactura: _facturaController.text,
        montoTotal: double.parse(_montoController.text),
        saldoPendiente: double.parse(_montoController.text),
        fechaVencimiento: DateTime.now().add(
          Duration(days: int.parse(_diasVencimientoController.text)),
        ),
        diasVencimiento: int.parse(_diasVencimientoController.text),
        tieneDescuento: tieneDescuento,
        porcentajeDescuento: tieneDescuento
            ? double.parse(_porcentajeDescuentoController.text)
            : 0,
        estado: EstadoCuentaPagar.PENDIENTE,
      );

      final response = await _carteraService.crearCuentaPorPagar(cuenta);
      if (response.isSuccess) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta por pagar creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Cuenta por Pagar'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _proveedorController,
                  decoration: const InputDecoration(
                    labelText: 'Proveedor',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _facturaController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Factura',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _montoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto Total',
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

                TextFormField(
                  controller: _diasVencimientoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Días para vencimiento',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Campo requerido';
                    if (int.tryParse(value!) == null) return 'Número inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                CheckboxListTile(
                  title: const Text('Tiene descuento por pronto pago'),
                  value: tieneDescuento,
                  onChanged: (value) {
                    setState(() {
                      tieneDescuento = value ?? false;
                    });
                  },
                ),

                if (tieneDescuento) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _porcentajeDescuentoController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Porcentaje descuento',
                            suffixText: '%',
                            border: OutlineInputBorder(),
                          ),
                          validator: tieneDescuento
                              ? (value) {
                                  if (value?.isEmpty == true)
                                    return 'Campo requerido';
                                  final num = double.tryParse(value!);
                                  if (num == null || num <= 0 || num > 100) {
                                    return 'Porcentaje inválido';
                                  }
                                  return null;
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _diasDescuentoController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Días descuento',
                            border: OutlineInputBorder(),
                          ),
                          validator: tieneDescuento
                              ? (value) {
                                  if (value?.isEmpty == true)
                                    return 'Campo requerido';
                                  if (int.tryParse(value!) == null)
                                    return 'Número inválido';
                                  return null;
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
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
