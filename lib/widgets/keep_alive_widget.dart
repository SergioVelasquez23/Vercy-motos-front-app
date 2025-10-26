import 'package:flutter/material.dart';
import 'dart:async';
import '../services/keep_alive_service.dart';

/// Widget para mostrar el estado del servicio Keep-Alive
/// Permite activar/desactivar el servicio y ver estadísticas
class KeepAliveWidget extends StatefulWidget {
  const KeepAliveWidget({Key? key}) : super(key: key);

  @override
  _KeepAliveWidgetState createState() => _KeepAliveWidgetState();
}

class _KeepAliveWidgetState extends State<KeepAliveWidget> {
  final KeepAliveService _keepAliveService = KeepAliveService();
  Timer? _updateTimer;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _updateStatus();

    // Actualizar el estado cada 30 segundos
    _updateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _updateStatus();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _updateStatus() {
    setState(() {
      _isActive = _keepAliveService.isActive;
    });
  }

  void _toggleKeepAlive() {
    if (_isActive) {
      _keepAliveService.stopKeepAlive();
    } else {
      _keepAliveService.startKeepAlive();
    }
    _updateStatus();
  }

  void _forcePing() async {
    await _keepAliveService.forcePing();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ping forzado enviado'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _isActive ? Icons.wifi : Icons.wifi_off,
                  color: _isActive ? Colors.green : Colors.grey,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Keep-Alive Backend',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Spacer(),
                Switch(
                  value: _isActive,
                  onChanged: (value) => _toggleKeepAlive(),
                  activeColor: Colors.green,
                ),
              ],
            ),

            SizedBox(height: 8),

            Text(
              _isActive
                  ? '🟢 Servicio activo - Backend manteniéndose despierto'
                  : '🔴 Servicio inactivo - Backend puede dormirse',
              style: TextStyle(
                color: _isActive ? Colors.green : Colors.orange,
                fontSize: 12,
              ),
            ),

            if (_isActive) ...[
              SizedBox(height: 8),
              Text(
                'Ping automático cada 10 minutos',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],

            SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isActive)
                  TextButton.icon(
                    onPressed: _forcePing,
                    icon: Icon(Icons.send, size: 16),
                    label: Text('Ping Manual', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),

                SizedBox(width: 8),

                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Keep-Alive Info'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🎯 Propósito:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Evita que Render duerma el backend por inactividad.\n',
                            ),

                            Text(
                              '⏱️ Frecuencia:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('Ping cada 10 minutos automáticamente.\n'),

                            Text(
                              '💡 Recomendación:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Mantener activo durante horarios de operación del restaurante.',
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Entendido'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text('Info', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
