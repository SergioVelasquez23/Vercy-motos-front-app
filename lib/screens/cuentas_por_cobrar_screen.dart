import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cuenta_por_cobrar.dart';
import '../services/cartera_service.dart';
import '../utils/currency_utils.dart';
import '../widgets/vercy_sidebar_layout.dart';
import '../dialogs/dialogo_confirmacion.dart';

class CuentasPorCobrarScreen extends StatefulWidget {
  const CuentasPorCobrarScreen({Key? key}) : super(key: key);

  @override
  State<CuentasPorCobrarScreen> createState() => _CuentasPorCobrarScreenState();
}

class _CuentasPorCobrarScreenState extends State<CuentasPorCobrarScreen> {
  final CarteraService _carteraService = CarteraService();

  List<CuentaPorCobrar> cuentas = [];
  List<CuentaPorCobrar> cuentasFiltradas = [];
  bool isLoading = true;
  String? error;
  EstadoCuenta? filtroEstado;
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
      final response = await _carteraService.getCuentasPorCobrar();
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
    List<CuentaPorCobrar> resultado = List.from(cuentas);

    // Filtro por estado
    if (filtroEstado != null) {
      resultado = resultado
          .where((cuenta) => cuenta.estado == filtroEstado)
          .toList();
    }

    // Filtro por búsqueda
    if (busqueda.isNotEmpty) {
      resultado = resultado.where((cuenta) {
        return cuenta.clienteNombre.toLowerCase().contains(
              busqueda.toLowerCase(),
            ) ||
            cuenta.facturaId.toLowerCase().contains(busqueda.toLowerCase());
      }).toList();
    }

    // Ordenar por fecha de vencimiento
    resultado.sort((a, b) => a.fechaVencimiento.compareTo(b.fechaVencimiento));

    setState(() {
      cuentasFiltradas = resultado;
    });
  }

  Future<void> _registrarAbono(CuentaPorCobrar cuenta) async {
    final TextEditingController montoController = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Registrar Abono - ${cuenta.clienteNombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo pendiente: ${CurrencyUtils.format(cuenta.saldoPendiente)}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: montoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto del abono',
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
              if (monto != null &&
                  monto > 0 &&
                  monto <= cuenta.saldoPendiente) {
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
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _procesarAbono(cuenta, result);
    }
  }

  Future<void> _procesarAbono(CuentaPorCobrar cuenta, double monto) async {
    try {
      final response = await _carteraService.registrarAbonoCuentaPorCobrar(
        cuentaId: cuenta.id!,
        montoAbono: monto,
        observaciones: 'Abono registrado desde aplicación',
      );
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abono registrado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarCuentas();
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
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return VercySidebarLayout(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cuentas por Cobrar'),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cargarCuentas,
            ),
          ],
        ),
        body: Column(
          children: [
            // Filtros y búsqueda
            Container(
              color: const Color(0xFF1976D2),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Campo de búsqueda
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por cliente o factura...',
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
                        _buildFiltroChip('Pendientes', EstadoCuenta.PENDIENTE),
                        const SizedBox(width: 8),
                        _buildFiltroChip('Vencidas', EstadoCuenta.VENCIDA),
                        const SizedBox(width: 8),
                        _buildFiltroChip('Abonadas', EstadoCuenta.ABONADA),
                        const SizedBox(width: 8),
                        _buildFiltroChip('Pagadas', EstadoCuenta.PAGADA),
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

  Widget _buildFiltroChip(String label, EstadoCuenta? estado) {
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
      checkmarkColor: const Color(0xFF1976D2),
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
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text('No se encontraron cuentas por cobrar'),
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

    final vencidas = cuentasFiltradas.where((c) => c.estaVencida).length;
    final proximasVencer = cuentasFiltradas
        .where((c) => c.proximaAVencer)
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
                  Icons.attach_money,
                  Colors.green,
                ),
                _buildResumenItem(
                  'Cuentas',
                  '${cuentasFiltradas.length}',
                  Icons.receipt,
                  Colors.blue,
                ),
                _buildResumenItem(
                  'Vencidas',
                  '$vencidas',
                  Icons.warning,
                  Colors.red,
                ),
                _buildResumenItem(
                  'Próximas',
                  '$proximasVencer',
                  Icons.schedule,
                  Colors.orange,
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

  Widget _buildCuentaCard(CuentaPorCobrar cuenta) {
    Color? estadoColor;
    IconData estadoIcon;

    switch (cuenta.estado) {
      case EstadoCuenta.VENCIDA:
        estadoColor = Colors.red;
        estadoIcon = Icons.warning;
        break;
      case EstadoCuenta.PENDIENTE:
        estadoColor = cuenta.proximaAVencer ? Colors.orange : Colors.blue;
        estadoIcon = cuenta.proximaAVencer ? Icons.schedule : Icons.pending;
        break;
      case EstadoCuenta.ABONADA:
        estadoColor = Colors.green;
        estadoIcon = Icons.payment;
        break;
      case EstadoCuenta.PAGADA:
        estadoColor = Colors.green;
        estadoIcon = Icons.check_circle;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con cliente y estado
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cuenta.clienteNombre,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Factura: ${cuenta.facturaId}',
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
                        cuenta.estado.displayName,
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
                    if (cuenta.montoAbonado > 0)
                      Text(
                        'Abonado: ${CurrencyUtils.format(cuenta.montoAbonado)}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.green),
                      ),
                  ],
                ),
                Text(
                  CurrencyUtils.format(cuenta.saldoPendiente),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: estadoColor,
                  ),
                ),
              ],
            ),

            // Barra de progreso si hay abonos
            if (cuenta.montoAbonado > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: cuenta.porcentajePagado / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  cuenta.porcentajePagado >= 100 ? Colors.green : Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${cuenta.porcentajePagado.toStringAsFixed(1)}% pagado',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

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

            // Botones de acción
            if (cuenta.estado != EstadoCuenta.PAGADA &&
                cuenta.saldoPendiente > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (cuenta.clienteTelefono != null)
                    TextButton.icon(
                      onPressed: () {
                        // Aquí podrías implementar funcionalidad de WhatsApp
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Funcionalidad de WhatsApp próximamente',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.message),
                      label: const Text('WhatsApp'),
                    ),
                  ElevatedButton.icon(
                    onPressed: () => _registrarAbono(cuenta),
                    icon: const Icon(Icons.payment),
                    label: const Text('Registrar Abono'),
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
