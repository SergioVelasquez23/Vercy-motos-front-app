import 'package:flutter/material.dart';

/// Clase que contiene todos los colores y estilos de la aplicación
/// para mantener consistencia visual en toda la app
class AppTheme {
  // ===== COLORES PRINCIPALES =====
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color surfaceDark = Color(0xFF2A2A2A);
  static const Color cardBg = Color(0xFF313131);
  static const Color cardElevated = Color(0xFF3A3A3A);

  // ===== COLORES DE TEXTO =====
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(
    0xFFE0E0E0,
  ); // Mejorado de B0B0B0 a E0E0E0 para mejor contraste
  static const Color textMuted = Color(
    0xFFC0C0C0,
  ); // Mejorado de 808080 a C0C0C0 para mejor legibilidad
  static const Color textDark = Color(0xFFFFFFFF); // Blanco para fondos oscuros
  static const Color textLight = Color(
    0xFFE8E8E8,
  ); // Gris muy claro para excelente contraste

  // ===== COLORES DE ACENTO =====
  static const Color primary = Color(0xFFFF6B00);
  static const Color primaryLight = Color(0xFFFF8F3D);
  static const Color primaryDark = Color(0xFFE55A00);

  // ===== COLORES DE ESTADO =====
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  static const Color accent = Color(0xFF03DAC6);

  // ===== GRADIENTES =====
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [cardBg, cardElevated],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===== SOMBRAS =====
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 10),
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
    color: textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static const TextStyle labelLarge = TextStyle(
    color: textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle labelMedium = TextStyle(
    color: textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  // ===== DECORACIONES DE CONTENEDOR =====
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(radiusMedium),
    border: Border.all(color: textMuted.withOpacity(0.2), width: 1),
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
    border: Border.all(color: textMuted.withOpacity(0.3), width: 1),
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

  // ===== TEMA MATERIAL =====
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: backgroundDark,
    cardColor: cardBg,
    dividerColor: textMuted.withOpacity(0.2),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: headlineMedium,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
    textButtonTheme: TextButtonThemeData(style: secondaryButtonStyle),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: textMuted.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: textMuted.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      labelStyle: labelLarge,
      hintStyle: bodyMedium.copyWith(color: textMuted),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXLarge),
      ),
      titleTextStyle: headlineMedium,
      contentTextStyle: bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXLarge)),
      ),
    ),
  );
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
