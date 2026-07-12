import 'package:flutter/material.dart';

import '../core/constants/tajgo_colors.dart';

class TajGoTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: TajGoColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TajGoColors.green,
        primary: TajGoColors.green,
        secondary: TajGoColors.lime,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TajGoColors.background,
        surfaceTintColor: Colors.transparent,
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
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 6,
        shadowColor: const Color.fromRGBO(18, 48, 30, 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
