import 'package:flutter/widgets.dart';

class NewOrderMapLayout {
  const NewOrderMapLayout._();

  static double panelHeight(Size size, {required bool details}) {
    if (details) return (size.height * 0.48).clamp(360.0, 420.0);
    return (size.height * 0.34).clamp(250.0, 300.0);
  }

  static double visibleMapRatio(Size size, {required bool details}) =>
      (size.height - panelHeight(size, details: details)) / size.height;
}
