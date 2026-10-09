import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
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