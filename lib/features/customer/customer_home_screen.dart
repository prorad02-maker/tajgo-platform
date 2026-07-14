import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_order.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../../shared/widgets/tajgo_badge.dart';
import '../../shared/widgets/tajgo_order_history_tile.dart';
import '../admin/admin_home_screen.dart';
import '../account/account_profile_screen.dart';
import '../auth/phone_auth_screen.dart';
import '../courier/courier_home_screen.dart';
import '../courier/courier_application_status_screen.dart';
import '../demo/demo_tools_screen.dart';
import '../map/screens/new_order_map_screen.dart';
import 'order_tracking_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  Future<void> _openOrder(
    BuildContext context, [
    String type = 'package',
  ]) async {
    final scope = TajGoScope.of(context);
    final firebaseUser = scope.authService.currentUser;
    final profile = firebaseUser == null
        ? null
        : await scope.userRepository.getUser(firebaseUser.uid);
    if (!context.mounted) return;
    if (firebaseUser == null ||
        (!kDebugMode && profile?.phoneVerified != true)) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const PhoneAuthScreen(allowAnonymousFallback: false),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NewOrderMapScreen(initialType: type)),
    );
  }

  Future<void> _openCourierIntent(BuildContext context) async {
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser!.uid;
    final user = await scope.userRepository.getUser(uid);
    if (!context.mounted) return;
    if (user?.courierApproved == true) {
      try {
        await scope.accountModeService.switchToCourier();
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const CourierHomeScreen()),
          (_) => false,
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось открыть режим курьера. Попробуйте ещё раз.',
            ),
          ),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CourierApplicationStatusScreen(
            status: user?.courierStatus ?? 'none',
          ),
        ),
      );
    }
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
    const services = <String, (IconData, String)>{
      'package': (Icons.inventory_2_rounded, 'Посылка'),
      'food': (Icons.fastfood_rounded, 'Еда'),
      'shops': (Icons.shopping_cart_rounded, 'Магазины'),
      'pharmacy': (Icons.local_pharmacy_rounded, 'Аптеки'),
      'flowers': (Icons.local_florist_rounded, 'Цветы'),
      'docs': (Icons.description_rounded, 'Документы'),
    };

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _PlatformHeader(),
          if (scope.authService.currentUser?.isAnonymous == true && kDebugMode)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Chip(label: Text('Тест · демо-вход')),
            ),
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
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: services.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisExtent: 112,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                        itemBuilder: (context, index) {
                          final entry = services.entries.elementAt(index);
                          return _ServiceTile(
                            icon: entry.value.$1,
                            label: entry.value.$2,
                            onTap: () => _openOrder(context, entry.key),
                          );
                        },
                      ),
                      FilledButton(
                        onPressed: () => _openOrder(context),
                        child: const Text('Заказать доставку'),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<List<TajGoOrder>>(
                  stream: scope.orderRepository.recentOrdersStream(uid),
                  builder: (context, snapshot) {
                    final orders = snapshot.data ?? const <TajGoOrder>[];
                    if (orders.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Мои заказы',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...orders.map(
                            (order) => TajGoOrderHistoryTile(order: order),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SoonCard(
                        icon: Icons.local_taxi_rounded,
                        title: 'Такси',
                        subtitle: 'Поездки по городу',
                        onTap: () => _showSoon(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SoonCard(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Кошелёк',
                        subtitle: 'Оплата и бонусы',
                        onTap: () => _showSoon(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder(
                  future: scope.userRepository.getUser(uid),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final (title, subtitle) = switch (user?.courierStatus) {
                      'pending' => (
                        'Заявка на проверке',
                        'Клиентский режим доступен без ограничений',
                      ),
                      'rejected' => (
                        'Заявка требует внимания',
                        'Откройте статус и посмотрите следующий шаг',
                      ),
                      'suspended' => (
                        'Режим курьера приостановлен',
                        'Откройте статус заявки',
                      ),
                      'approved' => (
                        'Перейти в режим курьера',
                        'Принимать заказы и выходить на линию',
                      ),
                      _ => (
                        'Стать курьером',
                        'Зарабатывайте с TajGo — свободный график',
                      ),
                    };
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openCourierIntent(context),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              const _IconBubble(
                                icon: Icons.delivery_dining_rounded,
                                size: 56,
                                iconSize: 34,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        color: TajGoColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                FutureBuilder(
                  future: scope.userRepository.getUser(uid),
                  builder: (context, snapshot) {
                    final isAdmin = snapshot.data?.role == 'admin';
                    if (!isAdmin && !kDebugMode) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        _ManagementCard(
                          icon: Icons.admin_panel_settings_rounded,
                          title: '🛠 Управление TajGo',
                          badge: kDebugMode && !isAdmin ? 'debug' : 'admin',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminHomeScreen(),
                            ),
                          ),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 10),
                          _ManagementCard(
                            icon: Icons.science_rounded,
                            title: 'Тест · Demo Tools',
                            badge: 'debug',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DemoToolsScreen(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: TajGoColors.darkGreen, width: 1.5),
      borderRadius: BorderRadius.circular(18),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: TajGoColors.mint,
        child: Icon(icon, color: TajGoColors.darkGreen),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TajGoBadge(
            text: badge,
            background: TajGoColors.lime,
            foreground: TajGoColors.ink,
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    ),
  );
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '📍 Худжанд',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Профиль',
              color: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CustomerProfileScreen(),
                ),
              ),
              icon: const Icon(Icons.account_circle_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _greeting(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'TajGo — платформа вашего города',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    ),
  );

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Доброе утро 💚';
    }
    if (hour >= 12 && hour < 17) {
      return 'Добрый день 💚';
    }
    if (hour >= 17 && hour < 23) {
      return 'Добрый вечер 💚';
    }
    return 'Доброй ночи 💚';
  }
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TajGoBadge(
                    text: title,
                    background: TajGoColors.darkGreen,
                    foreground: Colors.white,
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: TajGoColors.darkGreen,
                  ),
                ],
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
  final IconData icon;
  final String title, subtitle;
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
                  _IconBubble(icon: icon, size: 50, iconSize: 30),
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

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IconBubble(icon: icon),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: TajGoColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, this.size = 56, this.iconSize = 32});

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: TajGoColors.secondaryBtn,
      borderRadius: BorderRadius.circular(size * 0.34),
    ),
    child: Icon(icon, size: iconSize, color: TajGoColors.darkGreen),
  );
}
