import 'package:flutter/material.dart';

import 'tajgo_colors.dart';

class TajGoTheme {
  TajGoTheme._();

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: TajGoColors.green,
      primary: TajGoColors.green,
      secondary: TajGoColors.gold,
      tertiary: TajGoColors.redAccent,
      surface: TajGoColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: TajGoColors.softGreen,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: TajGoColors.softGreen,
        foregroundColor: TajGoColors.ink,
        titleTextStyle: TextStyle(
          color: TajGoColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: TajGoColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
      ),
    );
  }
}
