import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_order.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../../shared/widgets/tajgo_badge.dart';
import '../courier/courier_home_screen.dart';
import '../map/screens/new_order_map_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  void _openOrder(BuildContext context, [String type = 'package']) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NewOrderMapScreen(initialType: type)),
    );
  }

  void _showSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скоро на платформе TajGo 💚')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser!.uid;
    const services = {
      'package': '📦\nПосылка',
      'food': '🍔\nЕда',
      'shops': '🛒\nМагазины',
      'pharmacy': '💊\nАптеки',
      'flowers': '🌸\nЦветы',
      'docs': '📄\nДокументы',
    };

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _PlatformHeader(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                StreamBuilder<TajGoOrder?>(
                  stream: scope.orderRepository.activeOrderStream(uid),
                  builder: (context, snapshot) => snapshot.data == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ActiveOrder(order: snapshot.data!),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TajGoColors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: TajGoColors.lime, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '🚚 Доставка',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TajGoBadge(
                            text: 'Активно',
                            background: TajGoColors.mint,
                            foreground: TajGoColors.darkGreen,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Посылки · Еда · Аптеки · Документы',
                        style: TextStyle(color: TajGoColors.muted),
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        childAspectRatio: 1.15,
                        children: services.entries
                            .map(
                              (entry) => InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _openOrder(context, entry.key),
                                child: Center(
                                  child: Text(
                                    entry.value,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      FilledButton(
                        onPressed: () => _openOrder(context),
                        child: const Text('Заказать доставку'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SoonCard(
                        icon: '🚕',
                        title: 'Такси',
                        subtitle: 'Поездки по городу',
                        onTap: () => _showSoon(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SoonCard(
                        icon: '💳',
                        title: 'Кошелёк',
                        subtitle: 'Оплата и бонусы',
                        onTap: () => _showSoon(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CourierHomeScreen(),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Text('🚴', style: TextStyle(fontSize: 32)),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Стать курьером',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Зарабатывайте с TajGo — свободный график',
                                  style: TextStyle(color: TajGoColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformHeader extends StatelessWidget {
  const _PlatformHeader();
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.paddingOf(context).top + 20,
      20,
      28,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [TajGoColors.darkGreen, TajGoColors.green],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📍 Худжанд',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 10),
        Text(
          'TajGo — платформа вашего города 💚',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ActiveOrder extends StatelessWidget {
  const _ActiveOrder({required this.order});
  final TajGoOrder order;

  Future<void> _reportNotReceived(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Вы уверены?'),
        content: const Text(
          'Сообщить, что заказ не был получен? Курьер останется заблокирован до проверки.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Не получил'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await TajGoScope.of(context).orderRepository.reportNotReceived(order.id);
    }
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (order.status) {
      OrderStatus.waiting => '🔎 Ищем курьера...',
      OrderStatus.accepted when order.arrivedAtPickupAt != null =>
        '📍 Курьер на месте',
      OrderStatus.accepted => '🚴 Курьер принял заказ',
      OrderStatus.pickedUp => '📦 Везём заказ',
      OrderStatus.delivered => 'Подтвердите получение',
      OrderStatus.disputed => '⚠️ Разбираемся',
      _ => '',
    };
    return Card(
      color: TajGoColors.mint,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TajGoBadge(
              text: title,
              background: TajGoColors.darkGreen,
              foreground: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              '${order.fromText} → ${order.toText}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('${order.price} ${order.currency}'),
            if (order.status == OrderStatus.pickedUp &&
                order.confirmationCode != null) ...[
              const SizedBox(height: 14),
              Text(
                'Код получения: ${order.confirmationCode}',
                style: const TextStyle(
                  color: TajGoColors.darkGreen,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Text(
                'Назовите его курьеру при получении',
                style: TextStyle(color: TajGoColors.muted),
              ),
            ],
            if (order.status == OrderStatus.delivered) ...[
              const SizedBox(height: 14),
              const Text(
                'Курьер передал заказ?',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _run(
                        context,
                        () => TajGoScope.of(
                          context,
                        ).orderRepository.confirmReceived(order.id),
                      ),
                      child: const Text('✅ Получил'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        _run(context, () => _reportNotReceived(context)),
                    child: const Text('Не получил'),
                  ),
                ],
              ),
            ],
            if (order.status == OrderStatus.disputed) ...[
              const SizedBox(height: 12),
              const Text(
                'Мы разбираемся с вашей доставкой.',
                style: TextStyle(color: TajGoColors.error),
              ),
            ],
            if (order.status == OrderStatus.waiting)
              TextButton(
                onPressed: () async {
                  try {
                    await TajGoScope.of(
                      context,
                    ).orderRepository.cancelOrder(order.id);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$error')));
                    }
                  }
                },
                child: const Text('Отменить'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SoonCard extends StatelessWidget {
  const _SoonCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String icon, title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.7,
    child: Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 25)),
                  const TajGoBadge(
                    text: 'скоро',
                    background: TajGoColors.soonBg,
                    foreground: TajGoColors.soonText,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                subtitle,
                style: const TextStyle(color: TajGoColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
