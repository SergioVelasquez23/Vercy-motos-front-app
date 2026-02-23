import 'package:flutter/material.dart';
import '../models/alerta_notificacion.dart';
import '../services/alertas_service.dart';
import '../services/cartera_service.dart';

class AlertasScreen extends StatefulWidget {
  const AlertasScreen({Key? key}) : super(key: key);

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen>
    with TickerProviderStateMixin {
  final AlertasService _alertasService = AlertasService();
  final CarteraService _carteraService = CarteraService();

  late TabController _tabController;
  EstadoMicroservicio? estadoMicroservicio;
  Map<String, dynamic>? configuracionCompleta;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarEstadoCompleto();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarEstadoCompleto() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Cargar configuración completa del microservicio
      final configResponse = await _alertasService.getConfiguracionCompleta();
      if (configResponse.isSuccess) {
        configuracionCompleta = configResponse.data;

        // Extraer estado del microservicio
        if (configuracionCompleta?['conectividad'] != null) {
          estadoMicroservicio = EstadoMicroservicio.fromJson(
            configuracionCompleta!['conectividad'],
          );
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error de conexión: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _verificarAlertas() async {
    try {
      final response = await _carteraService.verificarAlertas();
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.data ?? 'Verificación iniciada'),
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
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema de Alertas'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarEstadoCompleto,
          ),
          IconButton(
            icon: const Icon(Icons.notification_important),
            onPressed: _verificarAlertas,
            tooltip: 'Verificar alertas manualmente',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Estado'),
            Tab(icon: Icon(Icons.science), text: 'Pruebas'),
            Tab(icon: Icon(Icons.settings), text: 'Configuración'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _buildErrorWidget()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEstadoTab(),
                _buildPruebasTab(),
                _buildConfiguracionTab(),
              ],
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
            'Error al cargar estado',
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
            onPressed: _cargarEstadoCompleto,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoTab() {
    return RefreshIndicator(
      onRefresh: _cargarEstadoCompleto,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado general del microservicio
            _buildEstadoMicroservicioCard(),
            const SizedBox(height: 16),

            // Canales disponibles
            _buildCanalesDisponiblesCard(),
            const SizedBox(height: 16),

            // Tipos de alerta soportados
            _buildTiposAlertaCard(),
            const SizedBox(height: 16),

            // Acciones rápidas
            _buildAccionesRapidasCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoMicroservicioCard() {
    final bool operativo = estadoMicroservicio?.estaOperativo ?? false;

    return Card(
      elevation: 4,
      color: operativo ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  operativo ? Icons.check_circle : Icons.error,
                  color: operativo ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Microservicio de Alertas',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        operativo ? 'Operativo' : 'No disponible',
                        style: TextStyle(
                          color: operativo
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (estadoMicroservicio != null) ...[
              const SizedBox(height: 16),
              _buildDetalleItem('Estado', estadoMicroservicio!.status),
              _buildDetalleItem(
                'Disponible',
                estadoMicroservicio!.disponible ? 'Sí' : 'No',
              ),
              if (estadoMicroservicio!.url != null)
                _buildDetalleItem('URL', estadoMicroservicio!.url!),
              if (estadoMicroservicio!.mensaje != null)
                _buildDetalleItem('Mensaje', estadoMicroservicio!.mensaje!),
              _buildDetalleItem(
                'Última verificación',
                _formatDateTime(estadoMicroservicio!.timestamp),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCanalesDisponiblesCard() {
    final canales = estadoMicroservicio?.canalesDisponibles ?? [];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Canales de Notificación',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (canales.isEmpty)
              const Text('No hay información de canales disponibles')
            else
              ...canales.map((canal) => _buildCanalItem(canal)),
          ],
        ),
      ),
    );
  }

  Widget _buildCanalItem(String canal) {
    IconData icon;
    Color color;
    String descripcion;

    switch (canal.toUpperCase()) {
      case 'WHATSAPP':
        icon = Icons.message;
        color = Colors.green;
        descripcion = 'Mensajes de WhatsApp';
        break;
      case 'EMAIL':
        icon = Icons.email;
        color = Colors.blue;
        descripcion = 'Correo electrónico';
        break;
      case 'BOTH':
        icon = Icons.notifications;
        color = Colors.purple;
        descripcion = 'WhatsApp y Email';
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
        descripcion = canal;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(descripcion),
        ],
      ),
    );
  }

  Widget _buildTiposAlertaCard() {
    final tipos = estadoMicroservicio?.tiposAlerta ?? [];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipos de Alerta Soportados',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (tipos.isEmpty)
              const Text('No hay información de tipos de alerta')
            else
              ...tipos.map((tipo) => _buildTipoAlertaItem(tipo)),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoAlertaItem(String tipo) {
    IconData icon;
    Color color;
    String descripcion;

    switch (tipo.toUpperCase()) {
      case 'STOCK':
        icon = Icons.inventory;
        color = Colors.orange;
        descripcion = 'Alertas de stock bajo';
        break;
      case 'FACTURA':
        icon = Icons.receipt;
        color = Colors.blue;
        descripcion = 'Facturas próximas a vencer';
        break;
      case 'DEUDA':
        icon = Icons.warning;
        color = Colors.red;
        descripcion = 'Deudas vencidas';
        break;
      default:
        icon = Icons.notification_important;
        color = Colors.purple;
        descripcion = tipo;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(descripcion),
        ],
      ),
    );
  }

  Widget _buildAccionesRapidasCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones Rápidas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _verificarAlertas,
                    icon: const Icon(Icons.search),
                    label: const Text('Verificar Alertas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _cargarEstadoCompleto,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar Estado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPruebasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pruebas de Conectividad y Alertas',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Prueba de conectividad
          _buildPruebaCard(
            'Conectividad',
            'Verifica si el microservicio está disponible',
            Icons.wifi,
            Colors.blue,
            () => _ejecutarPruebaConectividad(),
          ),

          const SizedBox(height: 12),

          // Prueba de alerta de stock
          _buildPruebaCard(
            'Alerta de Stock',
            'Envía una alerta de prueba de stock bajo',
            Icons.inventory,
            Colors.orange,
            () => _ejecutarPruebaStock(),
          ),

          const SizedBox(height: 12),

          // Prueba de alerta de factura
          _buildPruebaCard(
            'Alerta de Factura',
            'Envía una alerta de prueba de factura por vencer',
            Icons.receipt,
            Colors.green,
            () => _ejecutarPruebaFactura(),
          ),

          const SizedBox(height: 12),

          // Prueba de alerta de deuda
          _buildPruebaCard(
            'Alerta de Deuda',
            'Envía una alerta de prueba de deuda vencida',
            Icons.warning,
            Colors.red,
            () => _ejecutarPruebaDeuda(),
          ),

          const SizedBox(height: 12),

          // Prueba de alerta de gastos
          _buildPruebaCard(
            'Alerta de Gastos',
            'Envía una alerta de prueba de gasto realizado',
            Icons.attach_money,
            Colors.purple,
            () => _ejecutarPruebaGasto(),
          ),

          const SizedBox(height: 12),

          // Prueba de alerta de cuentas por pagar
          _buildPruebaCard(
            'Alerta de CxP',
            'Envía una alerta de prueba de cuenta por pagar',
            Icons.receipt_long,
            Colors.indigo,
            () => _ejecutarPruebaCxP(),
          ),

          const SizedBox(height: 24),

          // Ejecutar todas las pruebas
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _ejecutarTodasLasPruebas,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Ejecutar Todas las Pruebas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPruebaCard(
    String titulo,
    String descripcion,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    descripcion,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              child: const Text('Probar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfiguracionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuración del Sistema',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (configuracionCompleta != null)
            ...configuracionCompleta!.entries.map(
              (entry) => _buildConfiguracionSection(entry.key, entry.value),
            )
          else
            const Center(child: Text('No hay configuración disponible')),
        ],
      ),
    );
  }

  Widget _buildConfiguracionSection(String titulo, dynamic contenido) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          titulo.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildContenidoConfiguracion(contenido),
          ),
        ],
      ),
    );
  }

  Widget _buildContenidoConfiguracion(dynamic contenido) {
    if (contenido is Map<String, dynamic>) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contenido.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    '${entry.key}:',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(child: Text(entry.value?.toString() ?? 'null')),
              ],
            ),
          );
        }).toList(),
      );
    } else if (contenido is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contenido.map((item) => Text('• $item')).toList(),
      );
    } else {
      return Text(contenido?.toString() ?? 'null');
    }
  }

  Widget _buildDetalleItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Métodos para ejecutar pruebas
  Future<void> _ejecutarPruebaConectividad() async {
    try {
      final response = await _alertasService.verificarConectividad();
      _mostrarResultadoPrueba(
        'Conectividad',
        response.isSuccess,
        response.isSuccess ? 'Conectividad exitosa' : response.message,
      );
    } catch (e) {
      _mostrarResultadoPrueba('Conectividad', false, 'Error: $e');
    }
  }

  Future<void> _ejecutarPruebaStock() async {
    try {
      final response = await _alertasService.probarAlertaStock();
      _mostrarResultadoPrueba(
        'Stock',
        response.isSuccess,
        response.data ?? response.message ?? 'Prueba completada',
      );
    } catch (e) {
      _mostrarResultadoPrueba('Stock', false, 'Error: $e');
    }
  }

  Future<void> _ejecutarPruebaFactura() async {
    try {
      final response = await _alertasService.probarAlertaFactura();
      _mostrarResultadoPrueba(
        'Factura',
        response.isSuccess,
        response.data ?? response.message ?? 'Prueba completada',
      );
    } catch (e) {
      _mostrarResultadoPrueba('Factura', false, 'Error: $e');
    }
  }

  Future<void> _ejecutarPruebaDeuda() async {
    try {
      final response = await _alertasService.probarAlertaDeuda();
      _mostrarResultadoPrueba(
        'Deuda',
        response.isSuccess,
        response.data ?? response.message ?? 'Prueba completada',
      );
    } catch (e) {
      _mostrarResultadoPrueba('Deuda', false, 'Error: $e');
    }
  }

  Future<void> _ejecutarPruebaGasto() async {
    try {
      final response = await _alertasService.probarAlertaGasto();
      _mostrarResultadoPrueba(
        'Gastos',
        response.isSuccess,
        response.data ?? response.message ?? 'Prueba completada',
      );
    } catch (e) {
      _mostrarResultadoPrueba('Gastos', false, 'Error: $e');
    }
  }

  Future<void> _ejecutarPruebaCxP() async {
    try {
      final response = await _alertasService.probarAlertaCxP();
      _mostrarResultadoPrueba(
        'Cuentas por Pagar',
        response.isSuccess,
        response.data ?? response.message ?? 'Prueba completada',
      );
    } catch (e) {
      _mostrarResultadoPrueba('Cuentas por Pagar', false, 'Error: $e');
    }
  }

  Future<void> _ejecutarTodasLasPruebas() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Ejecutando todas las pruebas...'),
          ],
        ),
      ),
    );

    try {
      final response = await _alertasService.ejecutarTodasLasPruebas();
      Navigator.pop(context); // Cerrar el diálogo de carga

      if (response.isSuccess && response.data != null) {
        _mostrarResultadosCompletos(response.data!);
      } else {
        _mostrarResultadoPrueba('Todas las pruebas', false, response.message);
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarResultadoPrueba('Todas las pruebas', false, 'Error: $e');
    }
  }

  void _mostrarResultadoPrueba(String prueba, bool exitosa, String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              exitosa ? Icons.check_circle : Icons.error,
              color: exitosa ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text('Resultado: $prueba'),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarResultadosCompletos(Map<String, dynamic> resultados) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resultados de Todas las Pruebas'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: resultados.entries.map((entry) {
                final value = entry.value;
                final bool exitosa = value is Map
                    ? (value['success'] ?? value['exitoso'] ?? false)
                    : false;
                final String mensaje = value is Map
                    ? (value['message'] ?? value['mensaje'] ?? 'Sin mensaje')
                    : value.toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      exitosa ? Icons.check_circle : Icons.error,
                      color: exitosa ? Colors.green : Colors.red,
                    ),
                    title: Text(entry.key.toUpperCase()),
                    subtitle: Text(mensaje),
                  ),
                );
              }).toList(),
            ),
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
}
