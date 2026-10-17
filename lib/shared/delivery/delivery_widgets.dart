import 'package:flutter/material.dart';
import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_order.dart';

String deliveryStatusLabel(OrderStatus status) => switch (status) {
  OrderStatus.waiting => 'Ищем курьера',
  OrderStatus.accepted => 'Курьер назначен',
  OrderStatus.pickedUp => 'В пути',
  OrderStatus.delivered => 'У получателя',
  OrderStatus.completed => 'Доставлено',
  OrderStatus.cancelled => 'Отменён',
  OrderStatus.disputed => 'На проверке',
  OrderStatus.unknown => 'Обновляем статус',
};

class DeliveryPill extends StatelessWidget {
  const DeliveryPill({
    super.key,
    required this.label,
    this.icon,
    this.warning = false,
  });
  final String label;
  final IconData? icon;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFF4DF) : const Color(0xFFEDF5EF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 16,
            color: warning ? const Color(0xFF805C13) : TajGoColors.deepGreen,
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: warning ? const Color(0xFF805C13) : TajGoColors.deepGreen,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class DeliveryRouteStops extends StatelessWidget {
  const DeliveryRouteStops({
    super.key,
    required this.from,
    required this.to,
    this.maxLines = 2,
    this.compact = false,
  });
  final String from, to;
  final int? maxLines;
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _stop('A', 'Откуда', from, false),
      Padding(
        padding: const EdgeInsets.only(left: 13),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: compact ? 10 : 14,
            width: 1.5,
            color: const Color(0xFFD5E3D9),
          ),
        ),
      ),
      _stop('B', 'Куда', to, true),
    ],
  );
  Widget _stop(String marker, String label, String address, bool destination) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: destination ? TajGoColors.mint : TajGoColors.deepGreen,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              marker,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: destination ? TajGoColors.deepGreen : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact)
                  Text(
                    label,
                    style: const TextStyle(
                      color: TajGoColors.muted,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  address.trim().isEmpty ? 'Адрес уточняется' : address,
                  maxLines: maxLines,
                  overflow: maxLines == null ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

/// Scrollable details keep the next action accessible above the system inset.
class DeliverySheet extends StatelessWidget {
  const DeliverySheet({super.key, required this.child, this.footer});
  final Widget child;
  final Widget? footer;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available =
        media.size.height - media.viewInsets.bottom - media.padding.top;
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: available * 0.60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5E0D8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: child,
                ),
              ),
              if (footer != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFEDF1EE))),
                  ),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeliveryPrimaryAction extends StatelessWidget {
  const DeliveryPrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: TajGoColors.deepGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: busy ? null : onPressed,
      child: Semantics(
        liveRegion: busy,
        label: busy ? '$label. Выполняется' : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy) ...[
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
            ] else if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
