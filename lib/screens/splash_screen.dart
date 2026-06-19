import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../providers/datos_cache_provider.dart';
import '../providers/notificaciones_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _spinnerController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _glowPulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 400), _initializeApp);
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.initializeFromStorage();

    if (!mounted) return;

    if (userProvider.isAuthenticated) {
      final cacheProvider =
          Provider.of<DatosCacheProvider>(context, listen: false);
      await cacheProvider.initialize();
      cacheProvider.warmupProductos();

      final notifProvider =
          Provider.of<NotificacionesProvider>(context, listen: false);
      notifProvider.refresh();
      notifProvider.startAutoRefresh();
    }

    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    if (userProvider.isAuthenticated) {
      if (userProvider.isOnlyAsesor) {
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
    _logoController.dispose();
    _pulseController.dispose();
    _spinnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.4,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo con glow
              AnimatedBuilder(
                animation: Listenable.merge(
                    [_logoController, _pulseController]),
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: _GlowLogo(pulse: _glowPulse.value),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Nombre de la app
              FadeTransition(
                opacity: _logoOpacity,
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF60A5FA), Color(0xFFA78BFA)],
                      ).createShader(bounds),
                      child: const Text(
                        'VERCY MOTOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Gestión inteligente de tu negocio',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Spinner de carga
              AnimatedBuilder(
                animation: _spinnerController,
                builder: (context, child) {
                  return Column(
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CustomPaint(
                          painter: _ArcSpinnerPainter(
                            progress: _spinnerController.value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Cargando...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowLogo extends StatelessWidget {
  final double pulse;
  const _GlowLogo({required this.pulse});

  @override
  Widget build(BuildContext context) {
    const double logoSize = 160;
    const double borderRadius = 32.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow exterior difuminado
        Container(
          width: logoSize + 40,
          height: logoSize + 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius + 20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.18 * pulse),
                blurRadius: 60,
                spreadRadius: 20,
              ),
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.14 * pulse),
                blurRadius: 80,
                spreadRadius: 30,
              ),
            ],
          ),
        ),

        // Anillo exterior animado
        Container(
          width: logoSize + 16,
          height: logoSize + 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius + 8),
            border: Border.all(
              color: const Color(0xFF60A5FA).withOpacity(0.25 * pulse),
              width: 1.5,
            ),
          ),
        ),

        // Logo con bordes redondeados
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.3 * pulse),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.asset(
              'assets/images/vercylogo.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF1E293B),
                child: const Icon(
                  Icons.two_wheeler,
                  color: Color(0xFF60A5FA),
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArcSpinnerPainter extends CustomPainter {
  final double progress;
  _ArcSpinnerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Track
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Arc gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradientPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF3B82F6)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const arcLength = math.pi * 1.3;
    final startAngle = progress * 2 * math.pi - math.pi / 2;

    canvas.drawArc(rect, startAngle, arcLength, false, gradientPaint);
  }

  @override
  bool shouldRepaint(_ArcSpinnerPainter old) => old.progress != progress;
}
