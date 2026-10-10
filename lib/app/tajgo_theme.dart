import 'package:flutter/material.dart';

import '../core/constants/tajgo_colors.dart';

class TajGoTheme {
  static ThemeData get light {
    final typography = ThemeData(useMaterial3: true).textTheme.apply(
      bodyColor: TajGoColors.ink,
      displayColor: TajGoColors.ink,
      fontFamily: 'Roboto',
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: TajGoColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TajGoColors.green,
        primary: TajGoColors.darkGreen,
        onPrimary: Colors.white,
        secondary: TajGoColors.lime,
        onSecondary: TajGoColors.ink,
        surface: TajGoColors.card,
        onSurface: TajGoColors.ink,
        error: TajGoColors.error,
      ),
      textTheme: typography.copyWith(
        titleLarge: typography.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        titleMedium: typography.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: typography.bodyLarge?.copyWith(height: 1.35),
        bodyMedium: typography.bodyMedium?.copyWith(height: 1.35),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: TajGoColors.card,
        indicatorColor: TajGoColors.mint,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? TajGoColors.darkGreen
                : TajGoColors.muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TajGoColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TajGoColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: TajGoColors.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD5DDD8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TajGoColors.darkGreen, width: 2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TajGoColors.darkGreen,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TajGoColors.darkGreen,
          minimumSize: const Size(48, 48),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TajGoColors.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'Roboto',
        ),
        actionTextColor: TajGoColors.lime,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TajGoColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TajGoColors.background,
        surfaceTintColor: Colors.transparent,
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
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFamily: 'Roboto',
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color.fromRGBO(18, 48, 30, 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
