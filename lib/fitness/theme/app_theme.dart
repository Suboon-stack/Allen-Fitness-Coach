import 'package:flutter/material.dart';

class AppTheme {
  static const forest = Color(0xFF145C46);
  static const mint = Color(0xFFA8E6CF);

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: forest,
      brightness: brightness,
    ).copyWith(
      primary: dark ? mint : forest,
      onPrimary: dark ? const Color(0xFF103B2D) : Colors.white,
      secondaryContainer: dark ? const Color(0xFF23483A) : mint,
      onSecondaryContainer: const Color(0xFF103B2D),
      surface: dark ? const Color(0xFF1B2B23) : Colors.white,
      onSurface: dark ? const Color(0xFFE8F0EB) : const Color(0xFF17221D),
      onSurfaceVariant:
          dark ? const Color(0xFFB0BDB5) : const Color(0xFF59675F),
      outlineVariant: dark ? const Color(0xFF3B5044) : const Color(0xFFDCE5DF),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor:
          dark ? const Color(0xFF111E17) : const Color(0xFFF7F9F7),
      textTheme: base.textTheme.copyWith(
        headlineLarge: TextStyle(
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: scheme.onSurface),
        headlineSmall: TextStyle(
            fontSize: 24,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface),
        titleLarge: TextStyle(
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface),
        titleMedium: TextStyle(
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface),
        bodyMedium: TextStyle(
            fontSize: 14, height: 1.5, color: scheme.onSurfaceVariant),
      ),
      appBarTheme: AppBarTheme(
          backgroundColor:
              dark ? const Color(0xFF111E17) : const Color(0xFFF7F9F7),
          foregroundColor: scheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surface,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.outlineVariant))),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }

  static ThemeData get legacyTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1C1C1E),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFEBEBF5),
        secondary: Color(0xFF2C2C2E),
        tertiary: Color(0xFF3A3A3C),
        surface: Color(0xFF2C2C2E),
        inversePrimary: Color(0xFF8E8E93),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2C2C2E),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFFEBEBF5)),
        titleTextStyle: TextStyle(
          color: Color(0xFFEBEBF5),
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardColor: const Color(0xFF2C2C2E),
      dividerColor: const Color(0xFF3A3A3C),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFEBEBF5)),
        bodyMedium: TextStyle(color: Color(0xFF8E8E93)),
      ),
    );
  }
}
