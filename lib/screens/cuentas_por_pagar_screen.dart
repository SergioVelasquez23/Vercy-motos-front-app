import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cuenta_por_pagar.dart';
import '../models/proveedor.dart';
import '../services/cartera_service.dart';
import '../services/proveedor_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../widgets/vercy_sidebar_layout.dart';
import '../utils/logger.dart';

class CuentasPorPagarScreen extends StatefulWidget {
  const CuentasPorPagarScreen({Key? key}) : super(key: key);

  @override
  State<CuentasPorPagarScreen> createState() => _CuentasPorPagarScreenState();
}

class _CuentasPorPagarScreenState extends State<CuentasPorPagarScreen> {
  final CarteraService _carteraService = CarteraService();
  final ProveedorService _proveedorService = ProveedorService();

  List<CuentaPorPagar> cuentas = [];
  List<CuentaPorPagar> cuentasFiltradas = [];
  bool isLoading = true;
  String? error;
  EstadoCuentaPagar? filtroEstado;
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
        // Verificar alertas Telegram en segundo plano
        _carteraService.verificarAlertasCxP();
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

    // Filtro por búsqueda
    if (busqueda.isNotEmpty) {
      resultado = resultado.where((cuenta) {
        return cuenta.proveedorNombre.toLowerCase().contains(
              busqueda.toLowerCase(),
            ) ||
            cuenta.numeroFactura.toLowerCase().contains(busqueda.toLowerCase());
      }).toList();
    }

    // Ordenar por fecha de vencimiento
    resultado.sort((a, b) => a.fechaVencimiento.compareTo(b.fechaVencimiento));

    setState(() {
      cuentasFiltradas = resultado;
    });
  }

  Future<void> _registrarPago(CuentaPorPagar cuenta) async {
    final TextEditingController montoController = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(
          'Registrar Pago - ${cuenta.proveedorNombre}',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo pendiente: ${CurrencyUtils.format(cuenta.saldoPendiente)}',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            if (cuenta.tieneDescuento && !cuenta.descuentoPerdido) ...[
              const SizedBox(height: 8),
              Text(
                'Con descuento: ${CurrencyUtils.format(cuenta.montoConDescuento)}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: montoController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Monto del pago',
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
      await _procesarPago(cuenta, result);
    }
  }

  Future<void> _procesarPago(CuentaPorPagar cuenta, double monto) async {
    try {
      appLog('🔵 [PAGO CxP] Iniciando registro de pago');
      appLog('📋 Cuenta ID: ${cuenta.id}');
      appLog('💰 Monto: $monto');
      appLog('🏢 Proveedor: ${cuenta.proveedorNombre}');
      appLog('📊 Saldo pendiente antes: ${cuenta.saldoPendiente}');

      final response = await _carteraService.registrarPagoCuentaPorPagar(
        cuentaId: cuenta.id!,
        montoPago: monto,
        observaciones: 'Pago registrado desde aplicación',
      );

      appLog('📨 [PAGO CxP] Respuesta del backend:');
      appLog('✅ Success: ${response.isSuccess}');
      appLog('📝 Message: ${response.message}');
      appLog('📦 Data: ${response.data}');

      if (response.isSuccess) {
        appLog('🎉 [PAGO CxP] Pago registrado exitosamente');
        appLog(
          'ℹ️ [AUTO-ALERTA] La auto-alerta de cuenta pagada se envía automáticamente desde CarteraService',
        );
        appLog(
          '   Ver línea 335 de cartera_service.dart - allí se invoca _alertasService.enviarAlertaCuentaPagada()\n',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago registrado exitosamente'),
            backgroundColor: AppTheme.primary,
          ),
        );
        await _cargarCuentas();
      } else {
        appLog('❌ [PAGO CxP] Error al registrar pago: ${response.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.message}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      appLog('💥 [PAGO CxP] Excepción al registrar pago: $e');
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
          title: const Text('Cuentas por Pagar'),
          backgroundColor: AppTheme.warning,
          foregroundColor: AppTheme.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cargarCuentas,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _mostrarFormularioNuevaCuenta,
          backgroundColor: AppTheme.warning,
          child: Icon(Icons.add, color: AppTheme.white),
        ),
        body: Column(
          children: [
            // Filtros y búsqueda
            Container(
              color: AppTheme.warning,
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
                        _buildFiltroChip('Abonadas', EstadoCuentaPagar.ABONADA),
                        const SizedBox(width: 8),
                        _buildFiltroChip('Pagadas', EstadoCuentaPagar.PAGADA),
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
          ],
        ),
      ),
    );
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
      checkmarkColor: const Color(0xFFE65100),
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
        itemCount: 1 + cuentasFiltradas.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildResumenHeader();
          }
          return _buildCuentaCard(cuentasFiltradas[index - 1]);
        },
      ),
    );
  }

  Widget _buildResumenHeader() {
    final totalPendiente = cuentasFiltradas.fold<double>(
      0,
      (sum, cuenta) => sum + cuenta.saldoPendiente,
    );

    final vencidas = cuentasFiltradas.where((c) => c.estaVencida).length;
    final proximasVencer = cuentasFiltradas
        .where((c) => c.requiereAtencionPronto)
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
                  CurrencyUtils.format(totalPendiente),
                  Icons.attach_money,
                  AppTheme.primary,
                ),
                _buildResumenItem(
                  'Cuentas',
                  '${cuentasFiltradas.length}',
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

  Widget _buildCuentaCard(CuentaPorPagar cuenta) {
    Color estadoColor;
    IconData estadoIcon;

    switch (cuenta.estado) {
      case EstadoCuentaPagar.VENCIDA:
        estadoColor = AppTheme.error;
        estadoIcon = Icons.warning;
        break;
      case EstadoCuentaPagar.PENDIENTE:
        estadoColor = cuenta.requiereAtencionPronto
            ? AppTheme.secondary
            : AppTheme.primary;
        estadoIcon = cuenta.requiereAtencionPronto
            ? Icons.schedule
            : Icons.pending;
        break;
      case EstadoCuentaPagar.ABONADA:
        estadoColor = AppTheme.primaryLight;
        estadoIcon = Icons.payment;
        break;
      case EstadoCuentaPagar.PAGADA:
        estadoColor = AppTheme.primary;
        estadoIcon = Icons.check_circle;
        break;
    }

    final String estadoLabel;
    switch (cuenta.estado) {
      case EstadoCuentaPagar.PENDIENTE:
        estadoLabel = 'Pendiente';
        break;
      case EstadoCuentaPagar.VENCIDA:
        estadoLabel = 'Vencida';
        break;
      case EstadoCuentaPagar.PAGADA:
        estadoLabel = 'Pagada';
        break;
      case EstadoCuentaPagar.ABONADA:
        estadoLabel = 'Abonada';
        break;
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
                      if (cuenta.esRecurrente)
                        Row(
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 14,
                              color: AppTheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getFrecuenciaLabel(cuenta.frecuencia),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.secondary),
                            ),
                          ],
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
                        estadoLabel,
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primary,
                        ),
                      ),
                    if (cuenta.tieneDescuento && !cuenta.descuentoPerdido)
                      Text(
                        'Descuento: ${cuenta.porcentajeDescuento}%',
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
                value: cuenta.montoAbonado / cuenta.montoTotal,
                backgroundColor: AppTheme.surfaceDark,
                valueColor: AlwaysStoppedAnimation<Color>(
                  cuenta.montoAbonado >= cuenta.montoTotal
                      ? AppTheme.primary
                      : AppTheme.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${((cuenta.montoAbonado / cuenta.montoTotal) * 100).toStringAsFixed(1)}% pagado',
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
                      : '(${cuenta.diasRestantes} días)',
                  style: TextStyle(
                    fontSize: 12,
                    color: estadoColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Alerta de descuento próximo a perder
            if (cuenta.proximoAPerderDescuento) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.secondary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.discount,
                      size: 16,
                      color: AppTheme.secondaryLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¡Descuento próximo a vencer! ${cuenta.diasParaPerderDescuento} días restantes',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Botones de acción
            if (cuenta.estado != EstadoCuentaPagar.PAGADA &&
                cuenta.saldoPendiente > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _enviarAlertaTelegramManual(cuenta),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Alerta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondary,
                      side: const BorderSide(color: AppTheme.secondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _registrarPago(cuenta),
                    icon: const Icon(Icons.payment),
                    label: const Text('Registrar Pago'),
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

  Future<void> _mostrarFormularioNuevaCuenta() async {
    final proveedorNombreCtrl = TextEditingController();
    final numeroFacturaCtrl = TextEditingController();
    final montoTotalCtrl = TextEditingController();
    final diasVencimientoCtrl = TextEditingController(text: '30');
    final observacionesCtrl = TextEditingController();
    final porcentajeDescuentoCtrl = TextEditingController();
    final diasAvisosCtrl = TextEditingController(text: '15,7,3,1');
    final diasAvisoDescuentoCtrl = TextEditingController(text: '10,5,2,1');
    TipoCuentaPagar tipoSeleccionado = TipoCuentaPagar.facturaProveedor;
    FrecuenciaCuentaPagar frecuenciaSeleccionada = FrecuenciaCuentaPagar.unica;
    bool esRecurrente = false;
    bool tieneDescuento = false;
    bool avisosActivados = true;
    String? proveedorIdSeleccionado;
    List<Proveedor> proveedores = [];

    // Cargar proveedores
    try {
      proveedores = await _proveedorService.getProveedores();
    } catch (_) {}

    if (!mounted) return;

    final result = await showDialog<CuentaPorPagar>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Nueva Cuenta por Pagar',
                style: TextStyle(color: Colors.black87),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Proveedor - Autocompletar o escribir
                      Autocomplete<Proveedor>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return proveedores;
                          }
                          return proveedores.where(
                            (p) => p.nombre.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            ),
                          );
                        },
                        displayStringForOption: (Proveedor p) => p.nombre,
                        onSelected: (Proveedor p) {
                          proveedorIdSeleccionado = p.id;
                          proveedorNombreCtrl.text = p.nombre;
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onSubmitted) {
                              // Sincronizar con nuestro controller
                              controller.addListener(() {
                                proveedorNombreCtrl.text = controller.text;
                              });
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                style: const TextStyle(color: Colors.black87),
                                decoration: const InputDecoration(
                                  labelText: 'Proveedor *',
                                  prefixIcon: Icon(Icons.business),
                                  border: OutlineInputBorder(),
                                ),
                              );
                            },
                      ),
                      const SizedBox(height: 12),

                      // Tipo de cuenta
                      DropdownButtonFormField<TipoCuentaPagar>(
                        value: tipoSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de cuenta',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                        ),
                        items: TipoCuentaPagar.values.map((tipo) {
                          return DropdownMenuItem(
                            value: tipo,
                            child: Text(_getTipoLabel(tipo)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => tipoSeleccionado = value!);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Número de factura
                      TextField(
                        controller: numeroFacturaCtrl,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText: 'Número de factura *',
                          prefixIcon: Icon(Icons.receipt),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Monto total
                      TextField(
                        controller: montoTotalCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText: 'Monto total *',
                          prefixText: '\$ ',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Días de vencimiento
                      TextField(
                        controller: diasVencimientoCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText: 'Días de vencimiento',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Descuento
                      SwitchListTile(
                        title: const Text(
                          '¿Tiene descuento por pronto pago?',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: tieneDescuento,
                        activeColor: const Color(0xFFE65100),
                        onChanged: (value) {
                          setDialogState(() => tieneDescuento = value);
                        },
                      ),
                      if (tieneDescuento) ...[
                        TextField(
                          controller: porcentajeDescuentoCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.black87),
                          decoration: const InputDecoration(
                            labelText: 'Porcentaje de descuento (%)',
                            prefixIcon: Icon(Icons.discount),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Recurrencia
                      SwitchListTile(
                        title: const Text(
                          '¿Es recurrente?',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: esRecurrente,
                        activeColor: const Color(0xFFE65100),
                        onChanged: (value) {
                          setDialogState(() => esRecurrente = value);
                        },
                      ),
                      if (esRecurrente) ...[
                        DropdownButtonFormField<FrecuenciaCuentaPagar>(
                          value: frecuenciaSeleccionada,
                          decoration: const InputDecoration(
                            labelText: 'Frecuencia',
                            prefixIcon: Icon(Icons.repeat),
                            border: OutlineInputBorder(),
                          ),
                          items: FrecuenciaCuentaPagar.values
                              .where((f) => f != FrecuenciaCuentaPagar.unica)
                              .map((frecuencia) {
                                return DropdownMenuItem(
                                  value: frecuencia,
                                  child: Text(_getFrecuenciaLabel(frecuencia)),
                                );
                              })
                              .toList(),
                          onChanged: (value) {
                            setDialogState(
                              () => frecuenciaSeleccionada = value!,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // === CONFIGURACIÓN DE ALERTAS AUTOMÁTICAS ===
                      const Divider(height: 20),
                      const Text(
                        'Alertas automáticas por Telegram',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Activar/desactivar alertas
                      SwitchListTile(
                        title: const Text(
                          'Alertas automáticas activadas',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: avisosActivados,
                        onChanged: (value) {
                          setDialogState(() => avisosActivados = value);
                        },
                      ),
                      const SizedBox(height: 8),

                      // Días para alertas de vencimiento
                      TextField(
                        controller: diasAvisosCtrl,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText:
                              'Días para alertas (antes del vencimiento)',
                          helperText: 'Ej: 15,7,3,1',
                          prefixIcon: Icon(Icons.notifications),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Días para alertas de descuento
                      TextField(
                        controller: diasAvisoDescuentoCtrl,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText: 'Días para alertas de descuento',
                          helperText: 'Ej: 10,5,2,1',
                          prefixIcon: Icon(Icons.discount),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Observaciones
                      TextField(
                        controller: observacionesCtrl,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText: 'Observaciones',
                          prefixIcon: Icon(Icons.note),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final nombre = proveedorNombreCtrl.text.trim();
                    final factura = numeroFacturaCtrl.text.trim();
                    final monto = double.tryParse(montoTotalCtrl.text);
                    final dias = int.tryParse(diasVencimientoCtrl.text) ?? 30;

                    if (nombre.isEmpty ||
                        factura.isEmpty ||
                        monto == null ||
                        monto <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Complete los campos obligatorios (*)'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                      return;
                    }

                    final descuento = tieneDescuento
                        ? double.tryParse(porcentajeDescuentoCtrl.text) ?? 0.0
                        : 0.0;

                    // Parsear días de alertas
                    List<int> diasAvisos = [15, 7, 3, 1];
                    List<int> diasAvisoDescuento = [10, 5, 2, 1];
                    try {
                      diasAvisos = diasAvisosCtrl.text
                          .split(',')
                          .map((s) => int.parse(s.trim()))
                          .toList();
                    } catch (_) {
                      diasAvisos = [15, 7, 3, 1];
                    }
                    try {
                      diasAvisoDescuento = diasAvisoDescuentoCtrl.text
                          .split(',')
                          .map((s) => int.parse(s.trim()))
                          .toList();
                    } catch (_) {
                      diasAvisoDescuento = [10, 5, 2, 1];
                    }

                    final nuevaCuenta = CuentaPorPagar(
                      proveedorId: proveedorIdSeleccionado,
                      proveedorNombre: nombre,
                      numeroFactura: factura,
                      montoTotal: monto,
                      saldoPendiente: monto,
                      fechaVencimiento: DateTime.now().add(
                        Duration(days: dias),
                      ),
                      diasVencimiento: dias,
                      tieneDescuento: tieneDescuento,
                      porcentajeDescuento: descuento,
                      estado: EstadoCuentaPagar.PENDIENTE,
                      tipo: tipoSeleccionado,
                      frecuencia: esRecurrente
                          ? frecuenciaSeleccionada
                          : FrecuenciaCuentaPagar.unica,
                      esRecurrente: esRecurrente,
                      observaciones: observacionesCtrl.text.trim().isNotEmpty
                          ? observacionesCtrl.text.trim()
                          : null,
                      diasAvisos: diasAvisos,
                      diasAvisoDescuento: diasAvisoDescuento,
                      avisosActivados: avisosActivados,
                    );
                    Navigator.pop(context, nuevaCuenta);
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _crearCuenta(result);
    }
  }

  Future<void> _crearCuenta(CuentaPorPagar cuenta) async {
    try {
      final response = await _carteraService.crearCuentaPorPagar(cuenta);
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta por pagar creada exitosamente'),
            backgroundColor: AppTheme.primary,
          ),
        );
        // Enviar alerta Telegram de nueva CxP
        _enviarAlertaNuevaCxPTelegram(cuenta);
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

  void _enviarAlertaNuevaCxPTelegram(CuentaPorPagar cuenta) {
    Future.microtask(() async {
      try {
        await _carteraService.enviarAlertaCxPProximaVencer(cuenta);
      } catch (_) {}
    });
  }

  String _getTipoLabel(TipoCuentaPagar tipo) {
    switch (tipo) {
      case TipoCuentaPagar.arriendo:
        return 'Arriendo';
      case TipoCuentaPagar.serviciosPublicos:
        return 'Servicios Públicos';
      case TipoCuentaPagar.facturaProveedor:
        return 'Factura Proveedor';
      case TipoCuentaPagar.nomina:
        return 'Nómina';
      case TipoCuentaPagar.seguros:
        return 'Seguros';
      case TipoCuentaPagar.impuestos:
        return 'Impuestos';
      case TipoCuentaPagar.mantenimiento:
        return 'Mantenimiento';
      case TipoCuentaPagar.otros:
        return 'Otros';
    }
  }

  String _getFrecuenciaLabel(FrecuenciaCuentaPagar frecuencia) {
    switch (frecuencia) {
      case FrecuenciaCuentaPagar.unica:
        return 'Única';
      case FrecuenciaCuentaPagar.mensual:
        return 'Mensual';
      case FrecuenciaCuentaPagar.bimestral:
        return 'Bimestral';
      case FrecuenciaCuentaPagar.trimestral:
        return 'Trimestral';
      case FrecuenciaCuentaPagar.semestral:
        return 'Semestral';
      case FrecuenciaCuentaPagar.anual:
        return 'Anual';
    }
  }

  Future<void> _enviarAlertaTelegramManual(CuentaPorPagar cuenta) async {
    try {
      appLog('🔔 [ALERTA MANUAL CxP] Iniciando envío de alerta manual');
      appLog('📋 Cuenta ID: ${cuenta.id}');
      appLog('🏢 Proveedor: ${cuenta.proveedorNombre}');
      appLog('💰 Saldo pendiente: ${cuenta.saldoPendiente}');
      appLog('📅 Fecha vencimiento: ${cuenta.fechaVencimiento}');
      appLog('⏰ Está vencida: ${cuenta.estaVencida}');
      appLog('💸 Próximo a perder descuento: ${cuenta.proximoAPerderDescuento}');
      appLog('🎁 Tiene descuento: ${cuenta.tieneDescuento}');

      String tipoAlerta = '';
      if (cuenta.estaVencida) {
        tipoAlerta = 'VENCIDA';
        appLog('📤 [ALERTA] Tipo: CUENTA VENCIDA');
        appLog('📨 Enviando a: enviarAlertaCxPVencida()');
        await _carteraService.enviarAlertaCxPVencida(cuenta);
      } else if (cuenta.proximoAPerderDescuento) {
        tipoAlerta = 'DESCUENTO EN RIESGO';
        appLog('📤 [ALERTA] Tipo: DESCUENTO EN RIESGO');
        appLog('📨 Enviando a: enviarAlertaCxPDescuentoRiesgo()');
        await _carteraService.enviarAlertaCxPDescuentoRiesgo(cuenta);
      } else {
        tipoAlerta = 'PRÓXIMA A VENCER';
        appLog('📤 [ALERTA] Tipo: PRÓXIMA A VENCER');
        appLog('📨 Enviando a: enviarAlertaCxPProximaVencer()');
        await _carteraService.enviarAlertaCxPProximaVencer(cuenta);
      }

      appLog('✅ [ALERTA MANUAL CxP] Alerta enviada exitosamente');
      appLog('📧 Tipo de alerta enviada: $tipoAlerta');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alerta $tipoAlerta enviada por Telegram'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      appLog('❌ [ALERTA MANUAL CxP] Error al enviar alerta: $e');
      appLog('💥 Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar alerta: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
