import 'package:flutter/material.dart';

import '../../core/design/tajgo_design.dart';

/// Единый скаффолд TajGo: фирменный светлый фон, безопасные зоны и
/// опциональная закреплённая нижняя панель (корзина, checkout bar).
class TajGoScaffold extends StatelessWidget {
  const TajGoScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.resizeToAvoidBottomInset = true,
    this.padBody = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;

  /// Закреплённая нижняя панель поверх body (не часть навигации).
  final Widget? bottomBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final bool resizeToAvoidBottomInset;

  /// Если true — оборачивает body в стандартный горизонтальный отступ экрана.
  final bool padBody;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (padBody) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: TajGoSpacing.screenH),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? TajGoColors.background,
      appBar: appBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom && bottomBar == null,
        child: bottomBar == null
            ? content
            : Column(
                children: [
                  Expanded(child: content),
                  SafeArea(
                    top: false,
                    bottom: safeAreaBottom,
                    child: bottomBar!,
                  ),
                ],
              ),
      ),
    );
  }
}
