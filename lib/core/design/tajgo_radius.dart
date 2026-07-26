import 'package:flutter/widgets.dart';

/// TajGo corner radius scale (16–20 для основных поверхностей).
class TajGoRadius {
  const TajGoRadius._();

  /// 8 px — мелкие чипы, badge.
  static const double xs = 8;

  /// 12 px — поля ввода, компактные элементы.
  static const double sm = 12;

  /// 16 px — карточки, кнопки, основные поверхности.
  static const double md = 16;

  /// 20 px — крупные карточки, bottom sheet.
  static const double lg = 20;

  /// 28 px — верх модальных bottom sheet.
  static const double xl = 28;

  /// Полностью скруглённый (pill).
  static const double pill = 999;

  static BorderRadius get xsAll => BorderRadius.circular(xs);
  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get pillAll => BorderRadius.circular(pill);

  /// Верхние скругления для bottom sheet.
  static const BorderRadius sheetTop = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );
}
