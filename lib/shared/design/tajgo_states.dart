import 'package:flutter/material.dart';

import '../../core/design/tajgo_design.dart';

import '../../shared/widgets/tajgo_state_view.dart';

/// Пустое состояние — иконка, заголовок, пояснение и опциональное действие.
class TajGoEmptyState extends StatelessWidget {
  const TajGoEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => TajGoStateView(
    icon: icon,
    title: title,
    message: message ?? '',
    onRetry: onAction,
    actionLabel: actionLabel ?? 'Продолжить',
  );
}

/// Состояние ошибки — дружелюбный текст без технических деталей и «Повторить».
class TajGoErrorState extends StatelessWidget {
  const TajGoErrorState({
    super.key,
    this.title = 'Что-то пошло не так',
    this.message = 'Не удалось загрузить данные. Проверьте связь и повторите.',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => TajGoStateView(
    icon: Icons.cloud_off_rounded,
    title: title,
    message: message,
    onRetry: onRetry,
    actionLabel: 'Повторить',
  );
}

/// Плейсхолдер-скелетон одной строки/блока с мягкой пульсацией.
class TajGoLoadingSkeleton extends StatefulWidget {
  const TajGoLoadingSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = TajGoRadius.sm,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<TajGoLoadingSkeleton> createState() => _TajGoLoadingSkeletonState();
}

class _TajGoLoadingSkeletonState extends State<TajGoLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 0.9).animate(_controller),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: TajGoColors.ink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Скелетон карточки для списков (партнёры/товары/заказы) на время загрузки.
class TajGoCardSkeleton extends StatelessWidget {
  const TajGoCardSkeleton({super.key, this.lines = 2, this.hasLeading = true});

  final int lines;
  final bool hasLeading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: TajGoSpacing.screenH,
        vertical: TajGoSpacing.sm,
      ),
      padding: const EdgeInsets.all(TajGoSpacing.lg),
      decoration: BoxDecoration(
        color: TajGoColors.card,
        borderRadius: TajGoRadius.lgAll,
        boxShadow: TajGoShadows.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLeading) ...[
            const TajGoLoadingSkeleton(
              height: 56,
              width: 56,
              radius: TajGoRadius.md,
            ),
            const SizedBox(width: TajGoSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines; i++) ...[
                  TajGoLoadingSkeleton(width: i == 0 ? 160 : double.infinity),
                  if (i != lines - 1) const SizedBox(height: TajGoSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Баннер отсутствия сети — тонкая полоса поверх контента.
class TajGoOfflineBanner extends StatelessWidget {
  const TajGoOfflineBanner({
    super.key,
    this.message = 'Нет подключения к интернету',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: TajGoColors.warning.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(
        horizontal: TajGoSpacing.lg,
        vertical: TajGoSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: TajGoIconSizes.sm,
            color: Color(0xFF92600A),
          ),
          const SizedBox(width: TajGoSpacing.sm),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF92600A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
