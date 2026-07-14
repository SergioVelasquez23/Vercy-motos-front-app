import 'package:flutter/material.dart';
import '../models/pedido.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';

class EliminarPedidosScreen extends StatefulWidget {
  const EliminarPedidosScreen({Key? key}) : super(key: key);

  @override
  State<EliminarPedidosScreen> createState() => _EliminarPedidosScreenState();
}

class _EliminarPedidosScreenState extends State<EliminarPedidosScreen> {
  final PedidoService _pedidoService = PedidoService();
  final TextEditingController _idController = TextEditingController();

  List<Pedido> _pedidosHoy = [];
  Set<String> _selectedIds = {};
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarPedidosHoy();
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _cargarPedidosHoy() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pedidos = await _pedidoService.getPedidosHoy();
      // Filtrar solo los pagados (facturados)
      final facturados = pedidos
          .where((p) => p.estado == EstadoPedido.pagado)
          .toList();
      // Ordenar por fecha descendente
      facturados.sort((a, b) => b.fecha.compareTo(a.fecha));

      setState(() {
        _pedidosHoy = facturados;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = errorMessage(e);
      });
    }
  }

  Future<void> _eliminarPedidoPorId() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese un ID de pedido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final motivo = await _confirmarEliminacion([id]);
    if (motivo == null) return;

    setState(() => _isDeleting = true);

    try {
      await _pedidoService.eliminarPedidoPagado(
        id,
        motivoEliminacion: motivo.isNotEmpty ? motivo : null,
      );
      _idController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido $id eliminado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      _cargarPedidosHoy();
    } catch (e) {
      showErrorDialog(context, 'Error al eliminar: ${errorMessage(e)}');
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  Future<void> _eliminarSeleccionados() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione al menos un pedido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final motivo = await _confirmarEliminacion(_selectedIds.toList());
    if (motivo == null) return;

    setState(() => _isDeleting = true);

    int eliminados = 0;
    int errores = 0;
    final ids = List<String>.from(_selectedIds);

    for (final id in ids) {
      try {
        await _pedidoService.eliminarPedidoPagado(
          id,
          motivoEliminacion: motivo.isNotEmpty ? motivo : null,
        );
        eliminados++;
      } catch (e) {
        errores++;
      }
    }

    setState(() {
      _isDeleting = false;
      _selectedIds.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errores == 0
              ? '$eliminados pedido(s) eliminado(s) exitosamente'
              : '$eliminados eliminado(s), $errores con error',
        ),
        backgroundColor: errores == 0 ? Colors.green : Colors.orange,
      ),
    );

    _cargarPedidosHoy();
  }

  Future<String?> _confirmarEliminacion(List<String> ids) {
    final motivoController = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(
              'Confirmar eliminacion',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta accion eliminara permanentemente ${ids.length} pedido(s) de la base de datos.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta accion NO se puede deshacer. El dinero sera revertido de la caja.',
                      style: TextStyle(
                        color: Colors.red.shade300,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (ids.length <= 5) ...[
              const SizedBox(height: 12),
              Text(
                'IDs:',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...ids.map(
                (id) => Text(
                  '  - ${id.length > 20 ? '${id.substring(0, 20)}...' : id}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              maxLines: 3,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Razón de la eliminación (opcional)',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                hintText: 'Ej: Pedido duplicado, error en facturación...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.5),
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, motivoController.text.trim());
            },
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Eliminar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 20),
          // Eliminar por ID manual
          _buildEliminarPorId(),
          const SizedBox(height: 20),
          // Toolbar de acciones
          _buildToolbar(),
          const SizedBox(height: 12),
          // Lista de pedidos
          Expanded(child: _buildListaPedidos()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.delete_sweep, color: onSurface, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eliminar Pedidos Facturados',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pedidos facturados de hoy: ${_pedidosHoy.length}',
                  style: TextStyle(
                    color: onSurface.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Botón refrescar
          IconButton(
            onPressed: _isLoading ? null : _cargarPedidosHoy,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onSurface,
                    ),
                  )
                : Icon(Icons.refresh, color: onSurface),
            tooltip: 'Refrescar',
          ),
        ],
      ),
    );
  }

  Widget _buildEliminarPorId() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _idController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Pegar ID del pedido para eliminar...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.3),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onSubmitted: (_) => _eliminarPedidoPorId(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isDeleting ? null : _eliminarPedidoPorId,
            icon: _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete, size: 18),
            label: const Text('Eliminar por ID'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        // Seleccionar todos
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              if (_selectedIds.length == _pedidosHoy.length) {
                _selectedIds.clear();
              } else {
                _selectedIds = _pedidosHoy.map((p) => p.id).toSet();
              }
            });
          },
          icon: Icon(
            _selectedIds.length == _pedidosHoy.length && _pedidosHoy.isNotEmpty
                ? Icons.deselect
                : Icons.select_all,
            size: 18,
          ),
          label: Text(
            _selectedIds.length == _pedidosHoy.length && _pedidosHoy.isNotEmpty
                ? 'Deseleccionar todo'
                : 'Seleccionar todo',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.3)),
          ),
        ),
        const SizedBox(width: 12),
        // Contador de seleccion
        if (_selectedIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_selectedIds.length} seleccionado(s)',
              style: TextStyle(
                color: Colors.red.shade300,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        const Spacer(),
        // Eliminar seleccionados
        if (_selectedIds.isNotEmpty)
          ElevatedButton.icon(
            onPressed: _isDeleting ? null : _eliminarSeleccionados,
            icon: _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_sweep, size: 18),
            label: Text('Eliminar ${_selectedIds.length} pedido(s)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildListaPedidos() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarPedidosHoy,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_pedidosHoy.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              'No hay pedidos facturados hoy',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 18),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header de tabla
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 48), // Checkbox
                Expanded(
                  flex: 3,
                  child: Text(
                    'ID',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Cliente',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Items',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Pago',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Hora',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 50), // Acciones
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista
          Expanded(
            child: ListView.separated(
              itemCount: _pedidosHoy.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1),
              ),
              itemBuilder: (context, index) {
                final pedido = _pedidosHoy[index];
                final isSelected = _selectedIds.contains(pedido.id);
                return _buildPedidoRow(pedido, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper para formato 12 horas
  String _formatHora12h(DateTime dt) {
    final hour24 = dt.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  Widget _buildPedidoRow(Pedido pedido, bool isSelected) {
    final hora = _formatHora12h(pedido.fecha);
    final fechaPago = pedido.fechaPago != null
        ? _formatHora12h(pedido.fechaPago!)
        : hora;

    return Container(
      color: isSelected ? Colors.red.withOpacity(0.08) : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(pedido.id);
            } else {
              _selectedIds.add(pedido.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 48,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds.add(pedido.id);
                      } else {
                        _selectedIds.remove(pedido.id);
                      }
                    });
                  },
                  activeColor: Colors.red,
                ),
              ),
              // ID (número de factura o código interno)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pedido.numeroFactura != null)
                      SelectableText(
                        pedido.numeroFactura!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    SelectableText(
                      pedido.id,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(
                          alpha: pedido.numeroFactura != null ? 0.4 : 1.0,
                        ),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // Cliente
              Expanded(
                flex: 2,
                child: Text(
                  pedido.cliente ?? 'CONSUMIDOR FINAL',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Items
              Expanded(
                flex: 1,
                child: Text(
                  '${pedido.items.length}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
                ),
              ),
              // Total
              Expanded(
                flex: 1,
                child: Text(
                  CurrencyUtils.format(pedido.total),
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Forma pago
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    pedido.formaPago ?? 'N/A',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // Hora
              Expanded(
                flex: 2,
                child: Text(
                  fechaPago,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
                ),
              ),
              // Acción eliminar individual
              SizedBox(
                width: 50,
                child: IconButton(
                  onPressed: _isDeleting
                      ? null
                      : () async {
                          final motivo = await _confirmarEliminacion([
                            pedido.id,
                          ]);
                          if (motivo != null) {
                            setState(() => _isDeleting = true);
                            try {
                              await _pedidoService.eliminarPedidoPagado(
                                pedido.id,
                                motivoEliminacion: motivo.isNotEmpty
                                    ? motivo
                                    : null,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Pedido eliminado'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _cargarPedidosHoy();
                            } catch (e) {
                              showErrorDialog(context, errorMessage(e));
                            } finally {
                              setState(() => _isDeleting = false);
                            }
                          }
                        },
                  icon: Icon(
                    Icons.delete,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  tooltip: 'Eliminar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
