import 'package:flutter/widgets.dart';

class NewOrderMapLayout {
  const NewOrderMapLayout._();

  static double panelHeight(
    Size size, {
    required bool details,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final base = details
        ? (size.height * 0.40).clamp(300.0, 340.0)
        : (size.height * 0.34).clamp(250.0, 300.0);
    final scale = textScaler.scale(14) / 14;
    if (scale <= 1.3) return base;
    return (base * scale / 1.3).clamp(
      base,
      (size.height - 180).clamp(base, double.infinity),
    );
  }

  static double visibleMapRatio(Size size, {required bool details}) =>
      (size.height - panelHeight(size, details: details)) / size.height;
}

/// Forces the map screen to keep viewport-sized constraints even when every
/// visible control is positioned over the map.
class NewOrderMapStack extends StatelessWidget {
  const NewOrderMapStack({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Stack(fit: StackFit.expand, children: children),
  );
}
