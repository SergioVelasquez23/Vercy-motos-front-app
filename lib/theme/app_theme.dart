import 'package:flutter/material.dart';

/// Clase que contiene todos los colores y estilos de la aplicación
/// para mantener consistencia visual en toda la app
/// PALETA VERCY MOTOS: Azul, Morado, Blanco, Metal y Negro
class AppTheme {
  // ===== COLORES PRINCIPALES - VERCY MOTOS =====
  static const Color backgroundDark = Color(0xFF000000); // Negro
  static const Color surfaceDark = Color(0xFF1A1A1A); // Negro suave
  static const Color cardBg = Color(0xFF212121); // Gris oscuro
  static const Color cardElevated = Color(0xFF2C2C2C); // Gris oscuro elevado

  // ===== COLORES DE TEXTO =====
  static const Color textPrimary = Color(0xFFFFFFFF); // Blanco
  static const Color textSecondary = Color(0xFFE0E0E0); // Blanco suave
  static const Color textMuted = Color(0xFF757575); // Metal/Gris
  static const Color textDark = Color(0xFFFFFFFF); // Blanco para fondos oscuros
  static const Color textLight = Color(0xFFE8E8E8); // Gris muy claro

  // ===== COLORES DE ACENTO - VERCY MOTOS =====
  static const Color primary = Color(0xFF2196F3); // Azul principal
  static const Color primaryLight = Color(0xFF64B5F6); // Azul claro
  static const Color primaryDark = Color(0xFF1976D2); // Azul oscuro
  static const Color secondary = Color(0xFF9C27B0); // Morado
  static const Color secondaryLight = Color(0xFFBA68C8); // Morado claro
  static const Color secondaryDark = Color(0xFF7B1FA2); // Morado oscuro
  static const Color metal = Color(0xFF757575); // Metal/Gris
  static const Color metalLight = Color(0xFF9E9E9E); // Metal claro
  static const Color white = Color(0xFFFFFFFF); // Blanco puro

  // ===== COLORES DE ESTADO =====
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3); // Azul
  static const Color accent = Color(0xFF9C27B0); // Morado

  // ===== GRADIENTES =====
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary], // Azul a Morado
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryDark], // Morado gradiente
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [cardBg, cardBg], // Gradiente eliminado, color plano
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===== SOMBRAS =====
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get primaryShadow => [
    BoxShadow(
      color: primary.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // ===== BORDES REDONDEADOS =====
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  // ===== ESPACIADO =====
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // ===== ESTILOS DE TEXTO =====
  static const TextStyle headlineLarge = TextStyle(
    color: textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const TextStyle headlineMedium = TextStyle(
    color: textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    color: textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    color: textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    color: textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static const TextStyle bodySmall = TextStyle(
    color: textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static const TextStyle labelLarge = TextStyle(
    color: textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle labelMedium = TextStyle(
    color: textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  // ===== DECORACIONES DE CONTENEDOR =====
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(radiusMedium),
    border: Border.all(color: Color(0xFF404040), width: 1),
    boxShadow: cardShadow,
  );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(radiusLarge),
    border: Border.all(color: primary.withOpacity(0.3), width: 1.5),
    boxShadow: elevatedShadow,
  );

  static BoxDecoration get inputDecoration => BoxDecoration(
    color: surfaceDark,
    borderRadius: BorderRadius.circular(radiusMedium),
    border: Border.all(color: Color(0xFF404040), width: 1),
  );

  // ===== ESTILOS DE BOTÓN =====
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(
      horizontal: spacingLarge,
      vertical: spacingMedium,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    ),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  static ButtonStyle get secondaryButtonStyle => TextButton.styleFrom(
    foregroundColor: textSecondary,
    padding: const EdgeInsets.symmetric(
      horizontal: spacingLarge,
      vertical: spacingMedium,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    ),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  );

  // ===== UTILIDADES =====
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'activo':
      case 'disponible':
      case 'completado':
        return success;
      case 'ocupado':
      case 'ocupada':
      case 'pendiente':
        return warning;
      case 'error':
      case 'cancelado':
        return error;
      case 'info':
        return info;
      default:
        return textMuted;
    }
  }

  static EdgeInsetsGeometry get defaultPadding =>
      const EdgeInsets.all(spacingMedium);

  static EdgeInsetsGeometry get largePadding =>
      const EdgeInsets.all(spacingLarge);

  static EdgeInsetsGeometry get smallPadding =>
      const EdgeInsets.all(spacingSmall);
}

/// Extension para agregar métodos útiles a BuildContext
extension ThemeExtension on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;

  // Espaciado responsive
  double get responsivePadding => isMobile
      ? 16
      : isTablet
      ? 24
      : 32;
  double get responsiveRadius => isMobile ? 12 : 16;

  // Columnas responsive para grids
  int get responsiveColumns => isMobile
      ? 2
      : isTablet
      ? 3
      : 5;

  // Tamaños de fuente responsive
  double get responsiveFontSize => isMobile ? 14 : 16;
  double get responsiveHeadlineSize => isMobile ? 20 : 24;
}
