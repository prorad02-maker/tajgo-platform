/// TajGo spacing scale — сетка 8 px.
///
/// Единый источник отступов для всех экранов. Не хардкодить пиксели в виджетах —
/// использовать эти токены, чтобы вертикальный ритм оставался единым.
class TajGoSpacing {
  const TajGoSpacing._();

  /// 2 px — микро-зазор (иконка↔текст в плотных строках).
  static const double xxs = 2;

  /// 4 px — половина шага сетки.
  static const double xs = 4;

  /// 8 px — базовый шаг сетки.
  static const double sm = 8;

  /// 12 px — компактный внутренний отступ карточек/полей.
  static const double md = 12;

  /// 16 px — стандартный отступ экрана и карточек.
  static const double lg = 16;

  /// 20 px — крупный внутренний отступ / расстояние между секциями.
  static const double xl = 20;

  /// 24 px — отступ между крупными блоками.
  static const double xxl = 24;

  /// 32 px — большой вертикальный разрыв (empty state, заголовки).
  static const double xxxl = 32;

  /// Горизонтальный отступ экрана по умолчанию.
  static const double screenH = lg;

  /// Вертикальный отступ экрана по умолчанию.
  static const double screenV = lg;

  /// Минимальный удобный размер зоны нажатия (touch target).
  static const double touchTarget = 48;
}
