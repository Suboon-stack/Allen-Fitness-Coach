import 'package:allen/fitness/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Compatibility names for existing auth widgets; all styling is centralized.
abstract final class StudioSpace {
  static const double small = AppSpacing.sm;
  static const double medium = AppSpacing.md;
  static const double large = AppSpacing.lg;
  static const double section = AppSpacing.xl;
  static const double formWidth = AppLayout.formWidth;
  static const double contentWidth = AppLayout.wideWidth;
}

class PerformanceScope extends StatelessWidget {
  const PerformanceScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AppThemeScope(child: child);
}
