import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors from HTML design prototypes
  static const Color primaryBrandColor = Color(0xFF00478D);
  static const Color backgroundLight = Color(0xFFFBF8FE);
  static const Color backgroundDark = Color(0xFF0F0F1A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF00478D),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF005EB8),
        onPrimaryContainer: Color(0xFFC8DAFF),
        secondary: Color(0xFF565E71),
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFDAE2F9),
        onSecondaryContainer: Color(0xFF5C6478),
        tertiary: Color(0xFF643C49),
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFF7E5361),
        onTertiaryContainer: Color(0xFFFFCDDB),
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF93000A),
        surface: Color(0xFFFBF8FE),
        onSurface: Color(0xFF1B1B1F),
        surfaceDim: Color(0xFFDCD9DE),
        surfaceBright: Color(0xFFFBF8FE),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Color(0xFFF6F2F8),
        surfaceContainer: Color(0xFFF0EDF2),
        surfaceContainerHigh: Color(0xFFEAE7ED),
        surfaceContainerHighest: Color(0xFFE4E1E7),
        onSurfaceVariant: Color(0xFF424752),
        outline: Color(0xFF727783),
        outlineVariant: Color(0xFFC2C6D4),
      ),
      scaffoldBackgroundColor: backgroundLight,
      cardTheme: CardThemeData(
        color: const Color(0xFFFBF8FE),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFC2C6D4), width: 0.5),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF0EDF2),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1B1B1F)),
        titleTextStyle: TextStyle(
          color: Color(0xFF00478D),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBrandColor,
        brightness: Brightness.dark,
      ).copyWith(
        surface: backgroundDark,
        onSurface: Colors.white,
        primary: const Color(0xFF005EB8),
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundDark,
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A2E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.15), width: 0.5),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
