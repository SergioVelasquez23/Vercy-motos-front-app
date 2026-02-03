import 'package:flutter/material.dart';
import '../models/resumen_cartera.dart';
import '../models/cuenta_por_cobrar.dart';
import '../models/cuenta_por_pagar.dart';
import '../models/gasto_programado.dart';
import '../services/cartera_service.dart';
import '../utils/currency_utils.dart';
import '../widgets/vercy_sidebar_layout.dart';
import 'cuentas_por_cobrar_screen.dart';
import 'cuentas_por_pagar_screen.dart';
import 'gastos_programados_screen.dart';
import 'alertas_screen.dart';

class CarteraScreen extends StatefulWidget {
  const CarteraScreen({Key? key}) : super(key: key);

  @override
  State<CarteraScreen> createState() => _CarteraScreenState();
}

class _CarteraScreenState extends State<CarteraScreen> {
  final CarteraService _carteraService = CarteraService();

  ResumenCartera? resumen;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await _carteraService.getResumenCartera();
      if (response.isSuccess) {
        setState(() {
          resumen = response.data;
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

  @override
  Widget build(BuildContext context) {
    return VercySidebarLayout(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de Cartera'),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AlertasScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cargarResumen,
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? _buildErrorWidget()
            : _buildContent(),
      ),
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
            'Error al cargar datos',
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
            onPressed: _cargarResumen,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _cargarResumen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen principal
            _buildResumenCard(),
            const SizedBox(height: 16),

            // Alertas importantes
            if (resumen?.tieneAlertas == true) ...[
              _buildAlertasCard(),
              const SizedBox(height: 16),
            ],

            // Accesos rápidos
            _buildAccesosRapidos(),
            const SizedBox(height: 16),

            // Próximos vencimientos
            _buildProximosVencimientos(),
            const SizedBox(height: 16),

            // Gastos del mes
            _buildGastosDelMes(),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de Cartera',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Flujo neto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: resumen?.flujoPositivo == true
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Flujo Neto Estimado',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    CurrencyUtils.format(resumen?.flujoNetoEstimado ?? 0),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: resumen?.flujoPositivo == true
                          ? Colors.green[700]
                          : Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Métricas principales
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Por Cobrar',
                    resumen?.totalPorCobrar ?? 0,
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Por Pagar',
                    resumen?.totalPorPagar ?? 0,
                    Icons.money_off,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Gastos Mes',
                    resumen?.gastosProgramadosMes ?? 0,
                    Icons.receipt,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Liquidez Est.',
                    resumen?.liquidezEstimada ?? 0,
                    Icons.account_balance_wallet,
                    resumen?.liquidezEstimada != null &&
                            resumen!.liquidezEstimada >= 0
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    double value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          Text(
            CurrencyUtils.formatShort(value),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertasCard() {
    return Card(
      elevation: 4,
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text(
                  'Alertas Importantes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (resumen != null && resumen!.cuentasVencidas > 0)
              _buildAlertaItem(
                '${resumen!.cuentasVencidas} cuentas vencidas',
                Icons.schedule,
                Colors.red,
              ),

            if (resumen != null && resumen!.proveedoresDescuentoRiesgo > 0)
              _buildAlertaItem(
                '${resumen!.proveedoresDescuentoRiesgo} descuentos en riesgo',
                Icons.local_offer,
                Colors.orange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertaItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildAccesosRapidos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accesos Rápidos',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildAccesoCard(
                'Cuentas por Cobrar',
                Icons.account_balance,
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CuentasPorCobrarScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAccesoCard(
                'Cuentas por Pagar',
                Icons.payment,
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CuentasPorPagarScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildAccesoCard(
                'Gastos Programados',
                Icons.schedule,
                Colors.blue,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GastosProgramadosScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAccesoCard(
                'Alertas',
                Icons.notifications,
                Colors.purple,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AlertasScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccesoCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProximosVencimientos() {
    if (resumen?.cuentasProximasVencer == null ||
        resumen!.cuentasProximasVencer!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Próximos Vencimientos',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ...resumen!.cuentasProximasVencer!
            .take(3)
            .map(
              (cuenta) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[100],
                    child: Icon(Icons.schedule, color: Colors.orange[700]),
                  ),
                  title: Text(cuenta.clienteNombre),
                  subtitle: Text('Vence en ${cuenta.diasVencimiento} días'),
                  trailing: Text(
                    CurrencyUtils.format(cuenta.saldoPendiente),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildGastosDelMes() {
    if (resumen?.gastosProximosPagar == null ||
        resumen!.gastosProximosPagar!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gastos Próximos',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ...resumen!.gastosProximosPagar!
            .take(3)
            .map(
              (gasto) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(gasto.categoria.icon),
                  ),
                  title: Text(gasto.nombre),
                  subtitle: Text(gasto.categoria.displayName),
                  trailing: Text(
                    CurrencyUtils.format(gasto.montoEstimado),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
