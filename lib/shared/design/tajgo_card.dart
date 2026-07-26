import 'package:flutter/material.dart';

import '../../core/design/tajgo_design.dart';

/// Единая карточка TajGo — белая поверхность, мягкая тень, скругление 20.
class TajGoCard extends StatelessWidget {
  const TajGoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(TajGoSpacing.lg),
    this.margin,
    this.color,
    this.borderColor,
    this.radius,
    this.shadows,
    this.accent = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double? radius;
  final List<BoxShadow>? shadows;

  /// Акцентная карточка (например, активный заказ) — mint-фон и рамка.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius ?? TajGoRadius.lg);
    final content = AnimatedContainer(
      duration: TajGoDurations.base,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (accent ? TajGoColors.mint : TajGoColors.card),
        borderRadius: borderRadius,
        border: borderColor != null || accent
            ? Border.all(
                color: borderColor ?? TajGoColors.green.withValues(alpha: 0.35),
              )
            : null,
        boxShadow: shadows ?? (accent ? TajGoShadows.sm : TajGoShadows.md),
      ),
      child: child,
    );

    if (onTap == null) {
      return Container(margin: margin, child: content);
    }
    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      ),
    );
  }
}
