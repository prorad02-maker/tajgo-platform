import 'package:flutter/widgets.dart';

import '../constants/tajgo_colors.dart';

/// TajGo elevation tokens — минимальные мягкие тени в фирменном ink-оттенке.
class TajGoShadows {
  const TajGoShadows._();

  static const Color _ink = TajGoColors.ink;

  /// Без тени.
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Тонкая тень для карточек в списках.
  static List<BoxShadow> get sm => [
    BoxShadow(
      color: _ink.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  /// Стандартная тень основной карточки.
  static List<BoxShadow> get md => [
    BoxShadow(
      color: _ink.withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  /// Приподнятая тень для акцентных/активных карточек.
  static List<BoxShadow> get lg => [
    BoxShadow(
      color: _ink.withValues(alpha: 0.12),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];

  /// Тень для закреплённых панелей (корзина, checkout bar) — сверху.
  static List<BoxShadow> get bar => [
    BoxShadow(
      color: _ink.withValues(alpha: 0.10),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];
}
