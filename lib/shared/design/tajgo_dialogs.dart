import 'package:flutter/material.dart';

import '../../core/design/tajgo_design.dart';
import 'tajgo_buttons.dart';

/// Показывает единый TajGo bottom sheet (скруглённый верх, фирменный фон).
Future<T?> showTajGoBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: TajGoColors.card,
    barrierColor: TajGoColors.ink.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(borderRadius: TajGoRadius.sheetTop),
    builder: (context) => _TajGoSheetWrapper(child: builder(context)),
  );
}

class _TajGoSheetWrapper extends StatelessWidget {
  const _TajGoSheetWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: TajGoSpacing.md),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: TajGoColors.ink.withValues(alpha: 0.15),
              borderRadius: TajGoRadius.pillAll,
            ),
          ),
          const SizedBox(height: TajGoSpacing.sm),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Единое подтверждение действия. Возвращает `true` при подтверждении.
Future<bool> showTajGoConfirmation({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Подтвердить',
  String cancelLabel = 'Отмена',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: TajGoColors.card,
      shape: RoundedRectangleBorder(borderRadius: TajGoRadius.lgAll),
      title: Text(title, style: TajGoTypography.subtitle),
      content: message == null
          ? null
          : Text(message, style: TajGoTypography.body),
      actionsPadding: const EdgeInsets.fromLTRB(
        TajGoSpacing.lg,
        0,
        TajGoSpacing.lg,
        TajGoSpacing.lg,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: TajGoColors.muted),
          child: Text(cancelLabel),
        ),
        TajGoPrimaryButton(
          label: confirmLabel,
          expand: false,
          backgroundColor: destructive ? TajGoColors.error : TajGoColors.lime,
          foregroundColor: destructive ? Colors.white : TajGoColors.ink,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}
