import 'package:flutter/material.dart';

import '../constants/tajgo_colors.dart';

/// TajGo typography scale.
///
/// Единый набор текстовых стилей. Основной текст — тёмный ink на светлом фоне.
/// Семейство наследуется из темы (сейчас Roboto — полная поддержка кириллицы).
class TajGoTypography {
  const TajGoTypography._();

  static const Color _ink = TajGoColors.ink;
  static const Color _muted = TajGoColors.muted;

  /// Крупный заголовок экрана / hero-суммы.
  static const TextStyle display = TextStyle(
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w900,
    color: _ink,
  );

  /// Заголовок раздела / крупной карточки.
  static const TextStyle title = TextStyle(
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w800,
    color: _ink,
  );

  /// Подзаголовок / название партнёра, товара.
  static const TextStyle subtitle = TextStyle(
    fontSize: 17,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: _ink,
  );

  /// Основной текст.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: _ink,
  );

  /// Акцентный основной текст (важные строки).
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: _ink,
  );

  /// Вторичный/пояснительный текст.
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: _muted,
  );

  /// Мелкая подпись (метки, единицы).
  static const TextStyle label = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: _muted,
  );

  /// Текст основной кнопки действия.
  static const TextStyle button = TextStyle(
    fontSize: 16,
    height: 1.1,
    fontWeight: FontWeight.w800,
  );

  /// Собирает Material [TextTheme] из токенов для применения в теме.
  static TextTheme toTextTheme() {
    return const TextTheme(
      displaySmall: display,
      titleLarge: title,
      titleMedium: subtitle,
      bodyLarge: bodyStrong,
      bodyMedium: body,
      bodySmall: caption,
      labelSmall: label,
    );
  }
}
