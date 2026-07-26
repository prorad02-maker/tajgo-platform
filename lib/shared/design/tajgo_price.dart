import 'package:flutter/material.dart';

import '../../core/design/tajgo_design.dart';
import '../../core/design/tajgo_money.dart';

/// Отображение цены в сомони с опциональной старой (зачёркнутой) ценой.
class TajGoPrice extends StatelessWidget {
  const TajGoPrice({
    super.key,
    required this.value,
    this.oldValue,
    this.style,
    this.color,
    this.compact = false,
  });

  final num value;
  final num? oldValue;
  final TextStyle? style;
  final Color? color;

  /// Компактный вид — без единицы «сомони» рядом (для плотных строк).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final baseStyle = (style ?? TajGoTypography.subtitle).copyWith(
      color: color ?? TajGoColors.ink,
    );
    final showOld = oldValue != null && oldValue! > value;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          compact ? TajGoMoney.amount(value) : TajGoMoney.format(value),
          style: baseStyle,
        ),
        if (showOld) ...[
          const SizedBox(width: TajGoSpacing.sm),
          Text(
            TajGoMoney.amount(oldValue!),
            style: TajGoTypography.caption.copyWith(
              decoration: TextDecoration.lineThrough,
              color: TajGoColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}
