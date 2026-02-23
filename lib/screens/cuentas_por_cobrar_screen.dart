import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cuenta_por_cobrar.dart';
import '../models/pedido.dart';
import '../models/api_response.dart';
import '../services/cartera_service.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../widgets/vercy_sidebar_layout.dart';

class CuentasPorCobrarScreen extends StatefulWidget {
  const CuentasPorCobrarScreen({Key? key}) : super(key: key);

  @override
  State<CuentasPorCobrarScreen> createState() => _CuentasPorCobrarScreenState();
}

class _CuentasPorCobrarScreenState extends State<CuentasPorCobrarScreen> {
  final CarteraService _carteraService = CarteraService();
  final PedidoService _pedidoService = PedidoService();

  List<CuentaPorCobrar> cuentas = [];
  List<CuentaPorCobrar> cuentasFiltradas = [];
  List<Pedido> deudas = []; // ✅ Deudas de facturación
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
      // Cargar cuentas tradicionales y deudas de facturación en paralelo
      final results = await Future.wait([
        _carteraService.getCuentasPorCobrar(),
        _pedidoService.getPedidosDeuda(),
      ]);

      final cuentasResponse = results[0] as ApiResponse<List<CuentaPorCobrar>>;
      final deudasList = results[1] as List<Pedido>;

      if (cuentasResponse.isSuccess) {
        setState(() {
          cuentas = cuentasResponse.data ?? [];
          deudas = deudasList;
          _aplicarFiltros();
          isLoading = false;
        });
      } else {
        setState(() {
          error = cuentasResponse.message;
          deudas = deudasList; // Cargar deudas aunque fallen las cuentas
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
        backgroundColor: Colors.white,
        title: Text(
          'Registrar Abono - ${cuenta.clienteNombre}',
          style: TextStyle(color: Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo pendiente: ${CurrencyUtils.format(cuenta.saldoPendiente)}',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: montoController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.black87),
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
                    backgroundColor: AppTheme.error,
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
            backgroundColor: AppTheme.primary,
          ),
        );
        await _cargarCuentas();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.message}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: AppTheme.error,
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
          const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
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
    if (cuentasFiltradas.isEmpty && deudas.isEmpty) {
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
            Text('No se encontraron cuentas por cobrar ni deudas'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarCuentas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount:
            1 +
            (deudas.isNotEmpty ? 1 : 0) +
            deudas.length +
            (cuentasFiltradas.isNotEmpty ? 1 : 0) +
            cuentasFiltradas.length,
        itemBuilder: (context, index) {
          int currentIndex = index;

          // 1. Header de resumen
          if (currentIndex == 0) {
            return _buildResumenHeader();
          }
          currentIndex--;

          // 2. Sección de Deudas de Facturación
          if (deudas.isNotEmpty) {
            if (currentIndex == 0) {
              return _buildSeccionHeader(
                'Deudas de Facturación',
                deudas.length,
                Icons.sticky_note_2,
                AppTheme.secondary,
              );
            }
            currentIndex--;

            if (currentIndex < deudas.length) {
              return _buildDeudaCard(deudas[currentIndex]);
            }
            currentIndex -= deudas.length;
          }

          // 3. Sección de Cuentas por Cobrar tradicionales
          if (cuentasFiltradas.isNotEmpty) {
            if (currentIndex == 0) {
              return _buildSeccionHeader(
                'Cuentas por Cobrar',
                cuentasFiltradas.length,
                Icons.receipt_long,
                AppTheme.primaryLight,
              );
            }
            currentIndex--;

            if (currentIndex < cuentasFiltradas.length) {
              return _buildCuentaCard(cuentasFiltradas[currentIndex]);
            }
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildResumenHeader() {
    final totalCuentas = cuentasFiltradas.fold<double>(
      0,
      (sum, cuenta) => sum + cuenta.saldoPendiente,
    );

    final totalDeudas = deudas.fold<double>(
      0,
      (sum, deuda) => sum + deuda.total,
    );

    final total = totalCuentas + totalDeudas;

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
                  AppTheme.primary,
                ),
                _buildResumenItem(
                  'Cuentas',
                  '${cuentasFiltradas.length + deudas.length}',
                  Icons.receipt,
                  AppTheme.primaryLight,
                ),
                _buildResumenItem(
                  'Vencidas',
                  '$vencidas',
                  Icons.warning,
                  AppTheme.error,
                ),
                _buildResumenItem(
                  'Próximas',
                  '$proximasVencer',
                  Icons.schedule,
                  AppTheme.secondary,
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
        estadoColor = AppTheme.error;
        estadoIcon = Icons.warning;
        break;
      case EstadoCuenta.PENDIENTE:
        estadoColor = cuenta.proximaAVencer
            ? AppTheme.secondary
            : AppTheme.primary;
        estadoIcon = cuenta.proximaAVencer ? Icons.schedule : Icons.pending;
        break;
      case EstadoCuenta.ABONADA:
        estadoColor = AppTheme.primaryLight;
        estadoIcon = Icons.payment;
        break;
      case EstadoCuenta.PAGADA:
        estadoColor = AppTheme.primary;
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
                    color: estadoColor.withOpacity(0.1),
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
                        ).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primary,
                        ),
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
                backgroundColor: AppTheme.surfaceDark,
                valueColor: AlwaysStoppedAnimation<Color>(
                  cuenta.porcentajePagado >= 100
                      ? AppTheme.primary
                      : AppTheme.secondary,
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
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.white,
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

  Widget _buildSeccionHeader(
    String titulo,
    int cantidad,
    IconData icono,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              '$cantidad',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeudaCard(Pedido deuda) {
    final diasDesdeCreacion = DateTime.now().difference(deuda.fecha).inDays;
    final bool esReciente = diasDesdeCreacion <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.secondary.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con cliente y badge de deuda
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              deuda.cliente ?? 'Sin cliente',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pedido #${deuda.id.substring(0, 8)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.secondary.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 14,
                        color: AppTheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'DEUDA',
                        style: TextStyle(
                          color: AppTheme.secondary,
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

            // Información de fecha y productos
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(deuda.fecha),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 12),
                Icon(Icons.shopping_cart, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${deuda.items.length} item(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (esReciente) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NUEVA',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Total de la deuda
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.secondary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Adeudado:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    CurrencyUtils.format(deuda.total),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
            ),

            if (deuda.notas != null && deuda.notas!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        deuda.notas!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _verDetalleDeuda(deuda),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Ver Detalle'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _pagarDeuda(deuda),
                  icon: const Icon(Icons.payment),
                  label: const Text('Pagar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verDetalleDeuda(Pedido deuda) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Row(
          children: [
            Icon(Icons.sticky_note_2, color: AppTheme.secondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detalle de Deuda',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetalleRow('Cliente:', deuda.cliente ?? 'Sin cliente'),
              _buildDetalleRow(
                'Fecha:',
                DateFormat('dd/MM/yyyy HH:mm').format(deuda.fecha),
              ),
              _buildDetalleRow('Pedido:', '#${deuda.id.substring(0, 8)}'),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Productos:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ...deuda.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.cantidad}x ${item.productoNombre}',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                      Text(
                        CurrencyUtils.format(item.subtotal),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    CurrencyUtils.format(deuda.total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Future<void> _pagarDeuda(Pedido deuda) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Row(
          children: [
            Icon(Icons.payment, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              'Confirmar Pago',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Confirma el pago de esta deuda?',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Cliente: ${deuda.cliente ?? "Sin cliente"}',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${CurrencyUtils.format(deuda.total)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('Confirmar Pago'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      setState(() => isLoading = true);

      // Actualizar el pedido a estado pagado
      deuda.estado = EstadoPedido.pagado;
      await _pedidoService.updatePedido(deuda);

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Deuda pagada exitosamente')),
            ],
          ),
          backgroundColor: AppTheme.primary,
        ),
      );

      // Recargar las listas
      await _cargarCuentas();
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar el pago: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
