import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../providers/datos_cache_provider.dart';

/// Pantalla de arranque de la app (mientras se restaura la sesion y se decide a que ruta ir).
///
/// Se ve IGUAL que el cargador del navegador de web/index.html (mismo fondo, logo, nombre y barra,
/// en la misma posicion): el navegador lo muestra mientras descarga Flutter y, cuando esta pantalla
/// dibuja su primer cuadro, retira el suyo con un fundido. Por eso aqui no hay animacion de entrada:
/// el logo ya estaba en pantalla y no debe desaparecer y volver a aparecer.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _barController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 400), _initializeApp);
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Inicialización y animación mínima en paralelo
    await Future.wait([
      userProvider.initializeFromStorage(),
      Future.delayed(const Duration(milliseconds: 700)),
    ]);

    if (!mounted) return;

    if (userProvider.isAuthenticated) {
      final cacheProvider =
          Provider.of<DatosCacheProvider>(context, listen: false);
      await cacheProvider.initialize();
      cacheProvider.warmupProductos();

      // El refresh inicial y el auto-refresh de notificaciones se arrancan
      // en AppShell.initState() (cubre también el caso de recargar el
      // navegador ya logueado en una ruta protegida, que salta este splash).
    }

    if (!mounted) return;

    if (userProvider.isAuthenticated) {
      // Este correo es de uso exclusivo de la pantalla simplificada de stock
      // (ver editar_stock_simple_screen.dart) — nunca debe caer en pedidos ni
      // en el dashboard normal, ni siquiera al recargar el navegador.
      if (userProvider.userEmail?.trim().toLowerCase() == 'francia@gmail.com') {
        context.go('/editar-stock');
      } else if (userProvider.isOnlyAsesor) {
        context.go('/asesor-pedidos');
      } else {
        context.go('/dashboard');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SplashView(pulse: _pulseController, bar: _barController);
  }
}

/// Parte visual de la pantalla de arranque (sin logica), para poder probarla aparte.
class SplashView extends StatelessWidget {
  final Animation<double> pulse;
  final Animation<double> bar;

  const SplashView({super.key, required this.pulse, required this.bar});

  static const Color _fondo = Color(0xFF0F172A);
  static const Color _fondoClaro = Color(0xFF1E293B);
  static const Color _azul = Color(0xFF3B82F6);
  static const Color _azulClaro = Color(0xFF60A5FA);
  static const Color _violeta = Color(0xFF8B5CF6);
  static const Color _violetaClaro = Color(0xFFA78BFA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.16),
            radius: 1.0,
            colors: [_fondoClaro, _fondo],
            stops: [0.0, 0.76],
          ),
        ),
        child: Semantics(
          label: 'Cargando',
          liveRegion: true,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) => _LogoCard(
                    resplandor: Curves.easeInOut.transform(pulse.value),
                  ),
                ),
                const SizedBox(height: 30),
                // El espaciado de letras deja un hueco tras la ultima letra: se compensa a la izquierda.
                Padding(
                  padding: const EdgeInsets.only(left: 8.32),
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [_azulClaro, _violetaClaro],
                    ).createShader(rect),
                    child: const Text(
                      'VERCY MOTOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8.32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gestión inteligente de tu negocio',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 40),
                _BarraDeCarga(progreso: bar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo sobre una tarjeta blanca (el logo es oscuro y con fondo transparente) con un resplandor
/// azul-violeta que respira suavemente.
class _LogoCard extends StatelessWidget {
  /// 0 = resplandor minimo, 1 = maximo.
  final double resplandor;

  const _LogoCard({required this.resplandor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 128,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12 + 0.04 * resplandor),
        ),
        boxShadow: [
          BoxShadow(
            color: SplashView._azul.withValues(alpha: 0.18 + 0.18 * resplandor),
            blurRadius: 40 + 6 * resplandor,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: SplashView._violeta.withValues(alpha: 0.10 + 0.12 * resplandor),
            blurRadius: 90 + 20 * resplandor,
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/vercy_logo_cuadrado.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.two_wheeler,
          color: SplashView._azul,
          size: 64,
        ),
      ),
    );
  }
}

/// Barra fina con un destello azul-violeta que la recorre de izquierda a derecha.
class _BarraDeCarga extends StatelessWidget {
  final Animation<double> progreso;

  const _BarraDeCarga({required this.progreso});

  static const double _ancho = 168;
  static const double _alto = 3;
  static const double _tramo = _ancho * 0.42;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_alto),
      child: Container(
        width: _ancho,
        height: _alto,
        color: Colors.white.withValues(alpha: 0.10),
        child: AnimatedBuilder(
          animation: progreso,
          builder: (context, _) {
            final t = const Cubic(0.65, 0, 0.35, 1).transform(progreso.value);
            final izquierda = -_tramo + t * (_ancho + _tramo);
            return Stack(
              children: [
                Positioned(
                  left: izquierda,
                  top: 0,
                  bottom: 0,
                  width: _tramo,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_alto),
                      gradient: const LinearGradient(
                        colors: [SplashView._azul, SplashView._violeta],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
