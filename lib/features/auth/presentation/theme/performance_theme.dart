import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Performance Studio is scoped to authentication until subsequent review.
abstract final class PerformanceTheme {
  static const ink = Color(0xFF11172B);
  static const cobalt = Color(0xFF3154EC);
  static const lime = Color(0xFFD6F47A);
  static const canvas = Color(0xFFF5F5F1);

  static ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(seedColor: cobalt, brightness: brightness)
            .copyWith(
      primary: dark ? const Color(0xFFB9C4FF) : cobalt,
      onPrimary: dark ? ink : Colors.white,
      surface: dark ? const Color(0xFF1C2339) : Colors.white,
      onSurface: dark ? const Color(0xFFF2F3FA) : ink,
      onSurfaceVariant:
          dark ? const Color(0xFFB9C0D3) : const Color(0xFF596174),
      outline: dark ? const Color(0xFF8590AB) : const Color(0xFF7C8496),
      outlineVariant: dark ? const Color(0xFF394158) : const Color(0xFFDCE0EA),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final radius = BorderRadius.circular(16);
    return base.copyWith(
      scaffoldBackgroundColor: dark ? ink : canvas,
      textTheme: base.textTheme.copyWith(
        displaySmall: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            height: 1.06,
            letterSpacing: -1.8,
            color: scheme.onSurface),
        headlineMedium: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.8,
            color: scheme.onSurface),
        titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: scheme.onSurface),
        titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: scheme.onSurface),
        bodyLarge: TextStyle(
            fontSize: 16, height: 1.5, color: scheme.onSurfaceVariant),
        bodyMedium: TextStyle(
            fontSize: 14, height: 1.5, color: scheme.onSurfaceVariant),
        labelLarge: TextStyle(
            fontSize: 15,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: scheme.error, width: 2)),
        errorMaxLines: 3,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: scheme.inverseSurface,
          contentTextStyle: TextStyle(color: scheme.onInverseSurface)),
    );
  }
}

abstract final class StudioSpace {
  static const double small = 8;
  static const double medium = 16;
  static const double large = 24;
  static const double section = 32;
  static const double formWidth = 440;
  static const double contentWidth = 1160;
}

class PerformanceScope extends StatelessWidget {
  const PerformanceScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final dark = brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor:
            dark ? PerformanceTheme.ink : PerformanceTheme.canvas,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: Theme(data: PerformanceTheme.theme(brightness), child: child),
    );
  }
}
