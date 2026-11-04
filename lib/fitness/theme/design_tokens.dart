import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF101827);
  static const surface = Color(0xFF1C2940);
  static const primary = Color(0xFF315CF5);
  static const secondary = Color(0xFFAFC4FF);
  static const text = Color(0xFFF2F5FA);
  static const textSecondary = Color(0xFFB2BED0);
  static const surfaceLow = Color(0xFF162238);
  static const surfaceHigh = Color(0xFF253650);
  static const surfaceHighest = Color(0xFF2C405E);
  static const selectedSurface = Color(0xFF253C6C);
  static const outline = Color(0xFF8396B4);
  static const divider = Color(0xFF40526E);
  static const disabledSurface = Color(0xFF26354C);
  static const disabledText = Color(0xFFA8B6CC);
  // Semantic feedback, not additional brand accents.
  static const error = Color(0xFFFFB4AB);
  static const errorSurface = Color(0xFF4B2029);
  static const onError = Color(0xFFFFDAD6);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double page = 20;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppLayout {
  static const double formWidth = 440;
  static const double contentWidth = 720;
  static const double wideWidth = 1160;
}

abstract final class AppRadii {
  static const double control = 12;
  static const double panel = 12;
}

abstract final class AppType {
  static const double wordmark = 22;
  static const double heading = 32;
  static const double section = 24;
  static const double title = 20;
  static const double body = 16;
  static const double supporting = 14;
  static const double caption = 12;
}
