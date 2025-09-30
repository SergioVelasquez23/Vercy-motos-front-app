import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/admin_panel_screen.dart';

class AdminKeySequenceDetector extends StatefulWidget {
  final Widget child;

  const AdminKeySequenceDetector({super.key, required this.child});

  @override
  State<AdminKeySequenceDetector> createState() =>
      _AdminKeySequenceDetectorState();
}

class _AdminKeySequenceDetectorState extends State<AdminKeySequenceDetector> {
  final List<LogicalKeyboardKey> _pressedKeys = [];
  final List<LogicalKeyboardKey> _secretSequence = [
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyM,
    LogicalKeyboardKey.keyI,
    LogicalKeyboardKey.keyN,
  ];

  bool _sequenceActive = false;
  DateTime? _lastKeyPress;

  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();

      // Si han pasado más de 2 segundos desde la última tecla, reiniciar secuencia
      if (_lastKeyPress != null &&
          now.difference(_lastKeyPress!) > Duration(seconds: 2)) {
        _pressedKeys.clear();
        _sequenceActive = false;
      }

      _lastKeyPress = now;

      // Agregar la tecla presionada
      _pressedKeys.add(event.logicalKey);

      // Mantener solo las últimas teclas necesarias
      if (_pressedKeys.length > _secretSequence.length) {
        _pressedKeys.removeAt(0);
      }

      // Verificar si coincide con la secuencia secreta
      if (_pressedKeys.length == _secretSequence.length) {
        bool matches = true;
        for (int i = 0; i < _secretSequence.length; i++) {
          if (_pressedKeys[i] != _secretSequence[i]) {
            matches = false;
            break;
          }
        }

        if (matches) {
          _openAdminPanel();
          _pressedKeys.clear();
          _sequenceActive = false;
        }
      }

      // Visual feedback para desarrollo (opcional)
      if (mounted) {
        setState(() {
          _sequenceActive = _pressedKeys.isNotEmpty;
        });
      }
    }
  }

  void _openAdminPanel() {
    // Mostrar confirmación de acceso
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[900],
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.white),
            SizedBox(width: 8),
            Text(
              '🔧 Acceso Administrativo',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Has activado el panel de administración.\n\n'
          '⚠️ Esta área contiene herramientas poderosas que pueden eliminar datos.\n\n'
          '¿Deseas continuar?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminPanelScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Acceder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _onKeyEvent(event);
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          widget.child,

          // Indicador visual opcional (solo para desarrollo)
          if (_sequenceActive)
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '🔧',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Versión alternativa: Detector basado en gestos táctiles para móviles
class AdminGestureDetector extends StatefulWidget {
  final Widget child;

  const AdminGestureDetector({super.key, required this.child});

  @override
  State<AdminGestureDetector> createState() => _AdminGestureDetectorState();
}

class _AdminGestureDetectorState extends State<AdminGestureDetector> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _onTap() {
    final now = DateTime.now();

    // Si han pasado más de 3 segundos desde el último tap, reiniciar contador
    if (_lastTap != null && now.difference(_lastTap!) > Duration(seconds: 3)) {
      _tapCount = 0;
    }

    _lastTap = now;
    _tapCount++;

    // Secuencia secreta: 7 taps rápidos en la esquina superior derecha
    if (_tapCount >= 7) {
      _openAdminPanel();
      _tapCount = 0;
    }
  }

  void _openAdminPanel() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdminPanelScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Área invisible en la esquina superior derecha para detectar taps
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: _onTap,
            child: Container(
              width: 50,
              height: 50,
              color: Colors.transparent,
              child: _tapCount > 0
                  ? Center(
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$_tapCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
