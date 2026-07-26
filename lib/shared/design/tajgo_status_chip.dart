import 'package:flutter/material.dart';

import '../../core/design/tajgo_design.dart';

/// Тон статуса — задаёт цветовую семантику чипа.
enum TajGoStatusTone { neutral, info, success, warning, danger }

/// Компактный чип статуса. Смысл кодируется не только цветом, но и текстом
/// (и опциональной иконкой) — требование доступности.
class TajGoStatusChip extends StatelessWidget {
  const TajGoStatusChip({
    super.key,
    required this.label,
    this.tone = TajGoStatusTone.neutral,
    this.icon,
  });

  final String label;
  final TajGoStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TajGoSpacing.md,
        vertical: TajGoSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: TajGoRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: TajGoIconSizes.sm, color: fg),
            const SizedBox(width: TajGoSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static (Color, Color) _colors(TajGoStatusTone tone) {
    switch (tone) {
      case TajGoStatusTone.neutral:
        return (TajGoColors.soonBg, TajGoColors.soonText);
      case TajGoStatusTone.info:
        return (const Color(0xFFE0EAFE), const Color(0xFF1D4ED8));
      case TajGoStatusTone.success:
        return (TajGoColors.mint, TajGoColors.darkGreen);
      case TajGoStatusTone.warning:
        return (const Color(0xFFFEF3C7), const Color(0xFF92600A));
      case TajGoStatusTone.danger:
        return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
    }
  }
}
