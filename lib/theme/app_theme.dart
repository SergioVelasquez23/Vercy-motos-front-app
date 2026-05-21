import 'package:flutter/material.dart';

/// Paleta y estilos centrales de Vercy Motos.
///
/// Tonos suavizados (azul #3B82F6, morado #8B5CF6) y soporte para modo oscuro.
/// Las constantes [primary], [secondary], etc. siguen los nombres históricos
/// para no romper widgets existentes — internamente apuntan a la paleta nueva.
///
/// Para componentes nuevos, preferir `Theme.of(context).colorScheme.X` para
/// que respondan automáticamente al modo claro/oscuro.
class AppTheme {
  // ===== PALETA CLARA (suavizada) =====
  static const Color primary = Color(0xFF3B82F6); // Azul (antes 0xFF2196F3)
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF2563EB);

  static const Color secondary = Color(0xFF8B5CF6); // Morado (antes 0xFF9C27B0)
  static const Color secondaryLight = Color(0xFFA78BFA);
  static const Color secondaryDark = Color(0xFF7C3AED);

  // Superficies modo claro
  // Scaffold un toque más gris (slate-100) para que las cards blancas destaquen.
  static const Color backgroundDark = Color(0xFFEEF2F7);
  static const Color surfaceDark = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardElevated = Color(0xFFFAFAFA);
  static const Color white = Color(0xFFFFFFFF);

  // Bordes con contraste visible para modo claro.
  // [borderLight]  separadores muy sutiles (filas de listas, divisores).
  // [borderStrong] bordes de cards / inputs / tablas — bien visibles sobre blanco.
  static const Color borderLight = Color(0xFFCBD5E1); // slate-300
  static const Color borderStrong = Color(0xFF94A3B8); // slate-400

  // Texto modo claro
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDark = Color(0xFF000000);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color metal = Color(0xFF64748B);
  static const Color metalLight = Color(0xFF94A3B8);

  // Estado (tonos menos saturados)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color accent = Color(0xFF8B5CF6);

  // ===== PALETA OSCURA =====
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkCardElevated = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFE2E8F0);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextMuted = Color(0xFF94A3B8);
  static const Color darkPrimary = Color(0xFF60A5FA);
  static const Color darkSecondary = Color(0xFFA78BFA);

  // ===== GRADIENTES =====
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [cardBg, cardBg],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===== SOMBRAS =====
  // Sombras más densas para que las cards "floten" sobre el scaffold gris.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.14),
      blurRadius: 16,
      offset: const Offset(0, 5),
    ),
  ];

  static List<BoxShadow> get primaryShadow => [
    BoxShadow(
      color: primary.withOpacity(0.2),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  // ===== TOKENS =====
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // ===== TEXTOS =====
  static const TextStyle headlineLarge = TextStyle(
    color: textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    color: textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
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

  // ===== DECORACIONES =====
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(radiusMedium),
    border: Border.all(color: borderLight, width: 1.2),
    boxShadow: cardShadow,
  );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(radiusLarge),
    border: Border.all(color: primary.withOpacity(0.25), width: 1.2),
    boxShadow: elevatedShadow,
  );

  static BoxDecoration get inputDecoration => BoxDecoration(
    color: surfaceDark,
    borderRadius: BorderRadius.circular(radiusMedium),
    border: Border.all(color: borderLight, width: 1.2),
  );

  // ===== BOTONES =====
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

  // ===== THEMEDATA =====
  /// ThemeData para modo claro. Usar en `MaterialApp.theme`.
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: backgroundDark,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: textPrimary,
      error: error,
      onError: Colors.white,
    ),
    cardColor: cardBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      bodySmall: TextStyle(color: textMuted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        color: textSecondary,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: textMuted),
      floatingLabelStyle: const TextStyle(
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: borderLight, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: borderLight, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        side: const BorderSide(color: borderLight, width: 1.2),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: borderLight,
      thickness: 1,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
        side: const BorderSide(color: borderLight, width: 1.2),
      ),
    ),
  );

  /// ThemeData para modo oscuro.
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: darkPrimary,
    scaffoldBackgroundColor: darkBackground,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      onPrimary: Color(0xFF0F172A),
      secondary: darkSecondary,
      onSecondary: Color(0xFF0F172A),
      surface: darkSurface,
      onSurface: darkTextPrimary,
      error: error,
      onError: Colors.white,
    ),
    cardColor: darkCard,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: darkTextPrimary),
      bodyMedium: TextStyle(color: darkTextSecondary),
      bodySmall: TextStyle(color: darkTextMuted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      labelStyle: const TextStyle(
        color: darkTextSecondary,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: darkTextMuted),
      floatingLabelStyle: const TextStyle(
        color: darkPrimary,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: darkPrimary, width: 2),
      ),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: darkTextPrimary),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
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

  double get responsivePadding => isMobile
      ? 16
      : isTablet
      ? 24
      : 32;
  double get responsiveRadius => isMobile ? 12 : 16;

  int get responsiveColumns => isMobile
      ? 2
      : isTablet
      ? 3
      : 5;

  double get responsiveFontSize => isMobile ? 14 : 16;
  double get responsiveHeadlineSize => isMobile ? 20 : 24;
}
