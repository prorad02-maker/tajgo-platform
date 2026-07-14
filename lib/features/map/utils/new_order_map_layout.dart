import 'package:flutter/widgets.dart';

class NewOrderMapLayout {
  const NewOrderMapLayout._();

  static double panelHeight(Size size, {required bool details}) {
    if (details) return (size.height * 0.40).clamp(300.0, 340.0);
    return (size.height * 0.34).clamp(250.0, 300.0);
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
