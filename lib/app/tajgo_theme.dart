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
        primary: TajGoColors.darkGreen,
        secondary: TajGoColors.lime,
        onSecondary: TajGoColors.ink,
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
          fontFamily: 'Roboto',
          color: TajGoColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TajGoColors.lime,
          foregroundColor: TajGoColors.ink,
          minimumSize: const Size(0, TajGoSpacing.touchTarget),
          shape: RoundedRectangleBorder(borderRadius: TajGoRadius.mdAll),
          textStyle: TajGoTypography.button.copyWith(fontFamily: 'Roboto'),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TajGoColors.darkGreen,
          textStyle: TajGoTypography.button.copyWith(fontFamily: 'Roboto'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TajGoColors.darkGreen,
          minimumSize: const Size(0, TajGoSpacing.touchTarget),
          shape: RoundedRectangleBorder(borderRadius: TajGoRadius.mdAll),
          textStyle: TajGoTypography.button.copyWith(fontFamily: 'Roboto'),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: TajGoTypography.bodyStrong.copyWith(fontFamily: 'Roboto'),
        unselectedLabelStyle: TajGoTypography.body.copyWith(
          fontFamily: 'Roboto',
        ),
        labelColor: TajGoColors.darkGreen,
        unselectedLabelColor: TajGoColors.muted,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: TajGoColors.card,
        indicatorColor: TajGoColors.mint,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TajGoColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: TajGoColors.muted),
        border: OutlineInputBorder(borderRadius: TajGoRadius.mdAll),
        enabledBorder: OutlineInputBorder(
          borderRadius: TajGoRadius.mdAll,
          borderSide: const BorderSide(color: Color(0xFFCCDCCF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TajGoRadius.mdAll,
          borderSide: const BorderSide(color: TajGoColors.darkGreen, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: TajGoColors.card,
        elevation: 0,
        shadowColor: TajGoColors.ink.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: TajGoRadius.lgAll,
          side: const BorderSide(color: Color(0xFFDFEADF)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: TajGoRadius.smAll),
      ),
    );
  }
}
