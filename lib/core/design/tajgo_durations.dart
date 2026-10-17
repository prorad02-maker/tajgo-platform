/// TajGo motion tokens — плавные переходы 200–300 мс.
class TajGoDurations {
  const TajGoDurations._();

  /// 120 мс — микро-обратная связь (нажатие, ripple).
  static const Duration fast = Duration(milliseconds: 120);

  /// 200 мс — стандартный переход элемента.
  static const Duration base = Duration(milliseconds: 200);

  /// 250 мс — переход карточек/панелей.
  static const Duration medium = Duration(milliseconds: 250);

  /// 300 мс — крупные переходы (bottom sheet, смена секции).
  static const Duration slow = Duration(milliseconds: 300);
}
