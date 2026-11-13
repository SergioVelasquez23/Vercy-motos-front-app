import 'package:flutter/material.dart';
import '../widgets/common/error_retry_view.dart';

/// Carga una pantalla importada con `deferred as` y la construye cuando el
/// código ya está descargado.
///
/// Uso en el router:
/// ```dart
/// import '../screens/x_screen.dart' deferred as x;
/// GoRoute(path: '/x', builder: (c, s) => DeferredScreen(
///   loader: x.loadLibrary,
///   builder: () => x.XScreen(),
/// ));
/// ```
/// Así el código de cada pantalla (y los paquetes pesados que solo ella usa,
/// como pdf/excel) se baja la primera vez que se navega a ella y no al abrir
/// la app.
///
/// Requisito: ninguna otra parte de la app puede importar esa pantalla con un
/// `import` normal, o el compilador la deja en el bundle principal.
class DeferredScreen extends StatefulWidget {
  final Future<void> Function() loader;
  final Widget Function() builder;

  const DeferredScreen({super.key, required this.loader, required this.builder});

  /// Loaders que ya terminaron: evita el parpadeo del spinner al volver a una
  /// pantalla que ya se había descargado.
  static final Set<Future<void> Function()> _cargados = {};

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _future;

  bool get _yaCargado => DeferredScreen._cargados.contains(widget.loader);

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  Future<void> _cargar() async {
    await widget.loader();
    DeferredScreen._cargados.add(widget.loader);
  }

  @override
  Widget build(BuildContext context) {
    if (_yaCargado) return widget.builder();

    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
          return widget.builder();
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: ErrorRetryView(
              title: 'No se pudo cargar la pantalla',
              message: 'Revisa tu conexión e inténtalo de nuevo.',
              onRetry: () => setState(() => _future = _cargar()),
            ),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
