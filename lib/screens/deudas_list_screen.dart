import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deuda.dart';
import '../services/deuda_service.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../widgets/common/screen_header.dart';

class DeudasListScreen extends StatefulWidget {
  const DeudasListScreen({super.key});

  @override
  State<DeudasListScreen> createState() => _DeudasListScreenState();
}

class _DeudasListScreenState extends State<DeudasListScreen>
    with SingleTickerProviderStateMixin {
  final DeudaService _service = DeudaService();
  late TabController _tabController;

  List<Deuda> _todas = [];
  List<Deuda> _activas = [];
  List<Deuda> _vencidas = [];
  bool _isLoading = false;
  String _busqueda = '';
  Map<String, dynamic> _stats = {'totalDeudas': 0.0, 'deudasActivas': 0, 'deudasVencidas': 0};

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.listarDeudas(),
      _service.listarDeudasActivas(),
      _service.listarDeudasVencidas(),
      _service.obtenerEstadisticas(),
    ]);
    if (!mounted) return;
    setState(() {
      _todas = results[0] as List<Deuda>;
      _activas = results[1] as List<Deuda>;
      _vencidas = results[2] as List<Deuda>;
      _stats = results[3] as Map<String, dynamic>;
      _isLoading = false;
    });
  }

  List<Deuda> _filtrar(List<Deuda> lista) {
    if (_busqueda.isEmpty) return lista;
    final q = _busqueda.toLowerCase();
    return lista.where((d) =>
        d.cliente.toLowerCase().contains(q) ||
        (d.pedidoId?.toLowerCase().contains(q) ?? false) ||
        (d.notas?.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenHeader(
          icon: Icons.account_balance_wallet,
          title: 'Cartera de Deudas',
          badge: '${_activas.length} activas',
          badgeColor: _vencidas.isNotEmpty ? AppTheme.error : AppTheme.primary,
          actions: [
            ScreenHeaderAction.iconOnly(
              icon: Icons.refresh,
              tooltip: 'Actualizar',
              onPressed: _cargar,
            ),
          ],
        ),
        _buildStats(),
        _buildSearch(),
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: AppTheme.primary,
          tabs: [
            Tab(text: 'Todas (${_todas.length})'),
            Tab(text: 'Activas (${_activas.length})'),
            Tab(text: 'Vencidas (${_vencidas.length})'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLista(_filtrar(_todas)),
                    _buildLista(_filtrar(_activas)),
                    _buildLista(_filtrar(_vencidas)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final total = _stats['totalDeudas'] as double? ?? 0.0;
    final activas = _stats['deudasActivas'] as int? ?? 0;
    final vencidas = _stats['deudasVencidas'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          _statChip('Total Pendiente', CurrencyUtils.format(total), AppTheme.error),
          _divider(),
          _statChip('Activas', '$activas', AppTheme.primary),
          _divider(),
          _statChip('Vencidas', '$vencidas', AppTheme.warning),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1));

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Buscar por cliente, pedido...',
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: AppTheme.primary),
          suffixIcon: _busqueda.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(() => _busqueda = ''); })
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (v) => setState(() => _busqueda = v),
      ),
    );
  }

  Widget _buildLista(List<Deuda> deudas) {
    if (deudas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('Sin deudas', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: deudas.length,
      itemBuilder: (ctx, i) => _DeudaCard(
        deuda: deudas[i],
        onPagar: () => _mostrarModalPago(deudas[i]),
        onDetalle: () => _mostrarDetalle(deudas[i]),
      ),
    );
  }

  void _mostrarModalPago(Deuda deuda) {
    // Capturar todo antes del async gap
    final userName = Provider.of<UserProvider>(context, listen: false).userName ?? 'admin';
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => _PagoDialog(
        deuda: deuda,
        onPagar: (monto, medioPago, recibidoPor, notas) async {
          final result = await _service.registrarPago(
            deudaId: deuda.id!,
            monto: monto,
            medioPago: medioPago,
            recibidoPor: recibidoPor.isNotEmpty ? recibidoPor : userName,
            notas: notas,
          );
          if (!mounted) return;
          nav.pop();
          messenger.showSnackBar(SnackBar(
            content: Text(result['success'] == true
                ? 'Pago registrado correctamente'
                : (result['message'] ?? 'Error al registrar pago')),
            backgroundColor: result['success'] == true ? AppTheme.success : AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ));
          if (result['success'] == true) _cargar();
        },
      ),
    );
  }

  void _mostrarDetalle(Deuda deuda) {
    showDialog(
      context: context,
      builder: (ctx) => _DetalleDialog(deuda: deuda, service: _service),
    );
  }
}

// ─── Card de deuda ───────────────────────────────────────────────────────────

class _DeudaCard extends StatelessWidget {
  final Deuda deuda;
  final VoidCallback onPagar;
  final VoidCallback onDetalle;

  const _DeudaCard({required this.deuda, required this.onPagar, required this.onDetalle});

  @override
  Widget build(BuildContext context) {
    final vencida = deuda.estaVencida;
    final color = vencida ? AppTheme.error : (deuda.activa ? AppTheme.primary : Colors.grey);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _badge(vencida ? 'VENCIDA' : (deuda.activa ? 'ACTIVA' : 'INACTIVA'), color),
                const SizedBox(width: 8),
                if (deuda.id != null)
                  Text('#${deuda.id}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.info_outline, size: 20), onPressed: onDetalle, color: AppTheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(deuda.cliente, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            if (deuda.pedidoId != null) ...[
              const SizedBox(height: 4),
              Text('Pedido: ${deuda.pedidoId}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _montoCol('Total', deuda.montoTotal, Theme.of(context).colorScheme.onSurface)),
                Expanded(child: _montoCol('Pagado', deuda.montoPagado, AppTheme.success)),
                Expanded(child: _montoCol('Pendiente', deuda.montoDeuda, AppTheme.error)),
              ],
            ),
            if (deuda.fechaVencimiento != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 14, color: vencida ? AppTheme.error : Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    'Vence: ${_fmt(deuda.fechaVencimiento!)}',
                    style: TextStyle(color: vencida ? AppTheme.error : Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12, fontWeight: vencida ? FontWeight.w600 : FontWeight.normal),
                  ),
                ],
              ),
            ],
            if (deuda.activa && deuda.estado != EstadoDeuda.pagada) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: deuda.id != null ? onPagar : null,
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Registrar pago'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Widget _montoCol(String label, double monto, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
      Text(CurrencyUtils.formatShort(monto), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ],
  );

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─── Modal de pago ───────────────────────────────────────────────────────────

class _PagoDialog extends StatefulWidget {
  final Deuda deuda;
  final Future<void> Function(double monto, String medioPago, String recibidoPor, String? notas) onPagar;

  const _PagoDialog({required this.deuda, required this.onPagar});

  @override
  State<_PagoDialog> createState() => _PagoDialogState();
}

class _PagoDialogState extends State<_PagoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _recibidoPorCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String _medioPago = 'Efectivo';
  bool _loading = false;

  static const _medios = ['Efectivo', 'Transferencia', 'Tarjeta débito', 'Tarjeta crédito', 'Cheque', 'Nequi', 'Daviplata'];

  @override
  void initState() {
    super.initState();
    _montoCtrl.text = widget.deuda.montoDeuda.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _recibidoPorCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendiente = widget.deuda.montoDeuda;

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.payment, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Registrar pago', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info deuda
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    _infoRow('Cliente', widget.deuda.cliente),
                    _infoRow('Total deuda', CurrencyUtils.format(widget.deuda.montoTotal)),
                    _infoRow('Ya pagado', CurrencyUtils.format(widget.deuda.montoPagado)),
                    _infoRow('Pendiente', CurrencyUtils.format(pendiente), bold: true, color: AppTheme.error),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Monto
              TextFormField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Monto a pagar *',
                  prefixText: '\$',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                validator: (v) {
                  final m = double.tryParse(v ?? '');
                  if (m == null || m <= 0) return 'Ingrese un monto válido';
                  if (m > pendiente) return 'No puede superar \$${pendiente.toStringAsFixed(0)}';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Medio de pago
              DropdownButtonFormField<String>(
                value: _medioPago,
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Medio de pago *',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                items: _medios.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _medioPago = v ?? _medioPago),
              ),
              const SizedBox(height: 12),

              // Recibido por
              TextFormField(
                controller: _recibidoPorCtrl,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Recibido por (opcional)',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              const SizedBox(height: 12),

              // Notas
              TextFormField(
                controller: _notasCtrl,
                maxLines: 2,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Notas (opcional)',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirmar pago'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await widget.onPagar(
      double.parse(_montoCtrl.text),
      _medioPago,
      _recibidoPorCtrl.text.trim(),
      _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );
    if (mounted) setState(() => _loading = false);
  }

  Widget _infoRow(String label, String value, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
        Text(value, style: TextStyle(color: color ?? Theme.of(context).colorScheme.onSurface, fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
      ],
    ),
  );
}

// ─── Dialog de detalle de deuda ──────────────────────────────────────────────

class _DetalleDialog extends StatefulWidget {
  final Deuda deuda;
  final DeudaService service;

  const _DetalleDialog({required this.deuda, required this.service});

  @override
  State<_DetalleDialog> createState() => _DetalleDialogState();
}

class _DetalleDialogState extends State<_DetalleDialog> {
  List<PagoDeuda> _pagos = [];
  bool _loadingPagos = true;

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  Future<void> _cargarPagos() async {
    if (widget.deuda.id == null) { setState(() => _loadingPagos = false); return; }
    final pagos = await widget.service.obtenerHistorialPagos(widget.deuda.id!);
    if (mounted) setState(() { _pagos = pagos; _loadingPagos = false; });
  }

  @override
  Widget build(BuildContext context) {
    final deuda = widget.deuda;
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Detalle deuda ${deuda.id != null ? "#${deuda.id}" : ""}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16))),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info principal
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                ),
                child: Column(
                  children: [
                    _row(context, 'Cliente', deuda.cliente),
                    if (deuda.pedidoId != null) _row(context, 'Pedido', deuda.pedidoId!),
                    _row(context, 'Total', CurrencyUtils.format(deuda.montoTotal), bold: true),
                    _row(context, 'Pagado', CurrencyUtils.format(deuda.montoPagado), color: AppTheme.success),
                    _row(context, 'Pendiente', CurrencyUtils.format(deuda.montoDeuda), color: AppTheme.error, bold: true),
                    if (deuda.fechaVencimiento != null)
                      _row(context, 'Vencimiento', _fmt(deuda.fechaVencimiento!), color: deuda.estaVencida ? AppTheme.error : null),
                    if (deuda.notas != null) _row(context, 'Notas', deuda.notas!),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Barra de progreso
              if (deuda.montoPagado > 0) ...[
                Text('Progreso de pago', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (deuda.porcentajePagado / 100).clamp(0, 1),
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    deuda.porcentajePagado >= 100 ? AppTheme.success : AppTheme.primary,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text('${deuda.porcentajePagado.toStringAsFixed(1)}%', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
              ],

              // Historial de pagos
              Text('Historial de pagos', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              if (_loadingPagos)
                const Center(child: CircularProgressIndicator())
              else if (_pagos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
                  ),
                  child: const Center(child: Text('Sin pagos registrados')),
                )
              else
                ...(_pagos.map((p) => _PagoItem(pago: p))),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
        Flexible(child: Text(value, style: TextStyle(color: color ?? Theme.of(context).colorScheme.onSurface, fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: 13), textAlign: TextAlign.end)),
      ],
    ),
  );

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _PagoItem extends StatelessWidget {
  final PagoDeuda pago;
  const _PagoItem({required this.pago});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.check_circle_outline, color: AppTheme.success, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CurrencyUtils.format(pago.monto), style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${pago.formaPago} · ${pago.procesadoPor}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                if (pago.notas != null) Text(pago.notas!, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${pago.fecha.day.toString().padLeft(2, '0')}/${pago.fecha.month.toString().padLeft(2, '0')}/${pago.fecha.year}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
