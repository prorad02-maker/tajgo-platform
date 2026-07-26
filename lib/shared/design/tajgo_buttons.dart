import 'package:flutter/material.dart';

import '../../core/design/tajgo_design.dart';

/// Основная кнопка действия TajGo (одна на экран).
///
/// Фирменный акцентный фон, тёмный текст, поддержка иконки и состояния загрузки.
class TajGoPrimaryButton extends StatelessWidget {
  const TajGoPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? TajGoColors.ink;
    final child = loading
        ? SizedBox(
            height: TajGoIconSizes.md,
            width: TajGoIconSizes.md,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: TajGoIconSizes.md),
                const SizedBox(width: TajGoSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TajGoTypography.button,
                ),
              ),
            ],
          );

    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor ?? TajGoColors.lime,
        foregroundColor: fg,
        disabledBackgroundColor: (backgroundColor ?? TajGoColors.lime)
            .withValues(alpha: 0.45),
        disabledForegroundColor: fg.withValues(alpha: 0.7),
        minimumSize: const Size.fromHeight(TajGoSpacing.touchTarget),
        shape: RoundedRectangleBorder(borderRadius: TajGoRadius.mdAll),
      ),
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Вторичная кнопка TajGo — приглушённый зелёный тон, для второстепенных действий.
class TajGoSecondaryButton extends StatelessWidget {
  const TajGoSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: TajGoColors.darkGreen,
        backgroundColor: TajGoColors.secondaryBtn,
        minimumSize: const Size.fromHeight(TajGoSpacing.touchTarget),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: TajGoRadius.mdAll),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: TajGoIconSizes.md),
            const SizedBox(width: TajGoSpacing.sm),
          ],
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
