import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_tokens.dart';

export 'design_tokens.dart';

class AppTheme {
  static final ThemeData midnightTheme = _midnight();
  // Compatibility aliases: reviewed screens intentionally use the same navy
  // identity under both system brightness settings.
  static ThemeData get darkTheme => midnightTheme;
  static ThemeData get lightTheme => midnightTheme;

  static const systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData _midnight() {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.text,
      primaryContainer: AppColors.selectedSurface,
      onPrimaryContainer: AppColors.text,
      secondary: AppColors.secondary,
      onSecondary: AppColors.background,
      secondaryContainer: AppColors.selectedSurface,
      onSecondaryContainer: AppColors.text,
      tertiary: AppColors.secondary,
      onTertiary: AppColors.background,
      tertiaryContainer: AppColors.selectedSurface,
      onTertiaryContainer: AppColors.text,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surfaceLow,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.surfaceHighest,
      surfaceDim: AppColors.background,
      surfaceBright: AppColors.surfaceHighest,
      outline: AppColors.outline,
      outlineVariant: AppColors.divider,
      error: AppColors.error,
      onError: AppColors.background,
      errorContainer: AppColors.errorSurface,
      onErrorContainer: AppColors.onError,
      inverseSurface: AppColors.text,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.primary,
      surfaceTint: Colors.transparent,
    );
    final base = ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        materialTapTargetSize: MaterialTapTargetSize.padded);
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control));
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.outline));
    final foreground = WidgetStateProperty.resolveWith<Color>((states) =>
        states.contains(WidgetState.disabled)
            ? AppColors.disabledText
            : AppColors.text);
    const buttonText =
        TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
            fontSize: AppType.heading,
            height: 1.15,
            letterSpacing: -.6,
            fontWeight: FontWeight.w700,
            color: AppColors.text),
        headlineMedium: const TextStyle(
            fontSize: AppType.heading,
            height: 1.15,
            letterSpacing: -.6,
            fontWeight: FontWeight.w700,
            color: AppColors.text),
        headlineSmall: const TextStyle(
            fontSize: AppType.section,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: AppColors.text),
        titleLarge: const TextStyle(
            fontSize: AppType.title,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: AppColors.text),
        titleMedium: const TextStyle(
            fontSize: AppType.body,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: AppColors.text),
        bodyLarge: const TextStyle(
            fontSize: AppType.body,
            height: 1.5,
            color: AppColors.textSecondary),
        bodyMedium: const TextStyle(
            fontSize: AppType.supporting,
            height: 1.5,
            color: AppColors.textSecondary),
        bodySmall: const TextStyle(
            fontSize: AppType.caption,
            height: 1.5,
            color: AppColors.textSecondary),
        labelLarge: const TextStyle(
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: AppColors.text),
      ),
      appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: systemOverlay),
      filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? AppColors.disabledSurface
                : AppColors.primary),
        foregroundColor: foreground,
        textStyle: const WidgetStatePropertyAll(buttonText),
        shape: WidgetStatePropertyAll(shape),
        elevation: const WidgetStatePropertyAll(0),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? AppColors.disabledText
                : AppColors.secondary),
        side: WidgetStateProperty.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? AppColors.divider
                : AppColors.outline)),
        textStyle: const WidgetStatePropertyAll(buttonText),
        shape: WidgetStatePropertyAll(shape),
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: AppColors.secondary,
        disabledForegroundColor: AppColors.disabledText,
        minimumSize: const Size(48, 48),
        textStyle: buttonText,
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle:
            WidgetStateTextStyle.resolveWith((states) => TextStyle(
                color: states.contains(WidgetState.error)
                    ? AppColors.error
                    : states.contains(WidgetState.focused)
                        ? AppColors.secondary
                        : AppColors.textSecondary)),
        border: border,
        enabledBorder: border,
        disabledBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.secondary, width: 2)),
        errorBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.error, width: 2)),
        errorStyle: const TextStyle(color: AppColors.error, height: 1.5),
        errorMaxLines: 3,
        suffixIconColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? AppColors.disabledText
                : AppColors.textSecondary),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return states.contains(WidgetState.selected)
                ? AppColors.selectedSurface
                : AppColors.disabledSurface;
          }
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surface;
        }),
        // RawChip resolves a stateful color, not a stateful TextStyle.
        labelStyle: TextStyle(
          color: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.disabled) &&
                !states.contains(WidgetState.selected)) {
              return AppColors.disabledText;
            }
            return states.contains(WidgetState.selected)
                ? AppColors.text
                : AppColors.textSecondary;
          }),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        side: WidgetStateBorderSide.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? states.contains(WidgetState.selected)
                    ? AppColors.outline
                    : AppColors.divider
                : states.contains(WidgetState.selected)
                    ? AppColors.secondary
                    : AppColors.outline)),
        shape: shape, checkmarkColor: AppColors.text,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: 0, pressElevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.secondary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.secondary,
          dividerColor: AppColors.divider,
          labelStyle: TextStyle(fontWeight: FontWeight.w600)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: AppColors.selectedSurface,
        indicatorShape: shape,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? AppColors.text
                : AppColors.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.text
                : AppColors.textSecondary)),
      ),
      listTileTheme: const ListTileThemeData(
          textColor: AppColors.text,
          iconColor: AppColors.textSecondary,
          selectedColor: AppColors.secondary,
          selectedTileColor: AppColors.selectedSurface),
      drawerTheme: const DrawerThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent),
      cardTheme: CardThemeData(
          color: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.panel),
              side: const BorderSide(color: AppColors.divider))),
      dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.panel))),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.secondary,
          linearTrackColor: AppColors.surfaceHigh,
          circularTrackColor: AppColors.surfaceHigh),
      dividerTheme: const DividerThemeData(color: AppColors.divider),
      snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.surfaceHighest,
          contentTextStyle: TextStyle(color: AppColors.text),
          actionTextColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating),
      textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.secondary,
          selectionHandleColor: AppColors.secondary,
          selectionColor: AppColors.primary.withValues(alpha: .45)),
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

/// A staged boundary: reviewed routes share Midnight; other routes retain the
/// app's legacy theme until their own design milestone.
class AppThemeScope extends StatelessWidget {
  const AppThemeScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemOverlay,
        child: Theme(data: AppTheme.midnightTheme, child: child),
      );
}
