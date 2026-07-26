import 'package:flutter/material.dart';

import '../core/constants/tajgo_colors.dart';
import '../core/design/tajgo_radius.dart';
import '../core/design/tajgo_spacing.dart';
import '../core/design/tajgo_typography.dart';

class TajGoTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: TajGoColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TajGoColors.green,
        primary: TajGoColors.green,
        secondary: TajGoColors.lime,
        surface: TajGoColors.card,
        error: TajGoColors.error,
      ),
    );

    return base.copyWith(
      textTheme: TajGoTypography.toTextTheme().apply(
        bodyColor: TajGoColors.ink,
        displayColor: TajGoColors.ink,
        fontFamily: 'Roboto',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TajGoColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: TajGoColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: TajGoColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TajGoColors.lime,
          foregroundColor: TajGoColors.ink,
          minimumSize: const Size.fromHeight(TajGoSpacing.touchTarget),
          shape: RoundedRectangleBorder(borderRadius: TajGoRadius.mdAll),
          textStyle: TajGoTypography.button,
        ),
      ),
      cardTheme: CardThemeData(
        color: TajGoColors.card,
        elevation: 6,
        shadowColor: TajGoColors.ink.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: TajGoRadius.lgAll),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: TajGoRadius.smAll),
      ),
    );
  }
}
