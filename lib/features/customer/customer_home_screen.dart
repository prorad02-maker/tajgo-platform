import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/tajgo_order.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../../shared/widgets/tajgo_order_history_tile.dart';
import '../account/account_profile_screen.dart';
import '../auth/phone_auth_screen.dart';
import '../map/screens/new_order_map_screen.dart';
import '../marketplace/marketplace_partners_screen.dart';
import 'order_tracking_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _tab = 0;

  Future<void> _openOrder() async {
    final scope = TajGoScope.of(context);
    final firebaseUser = scope.authService.currentUser;
    final profile = firebaseUser == null
        ? null
        : await scope.userRepository.getUser(firebaseUser.uid);
    if (!mounted) return;
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
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const NewOrderMapScreen(initialType: 'package'),
      ),
    );
  }

  Future<void> _openMarketplace(String category) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => MarketplacePartnersScreen(category: category),
    ),
  );

  void _selectTab(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const CustomerProfileScreen()),
      );
      return;
    }
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser!.uid;
    return Scaffold(
      body: _tab == 0 ? _home(scope, uid) : _orders(scope, uid),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Заказы',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  Widget _home(TajGoScope scope, String uid) => CustomScrollView(
    slivers: [
      SliverAppBar(
        pinned: true,
        expandedHeight: 150,
        backgroundColor: TajGoColors.darkGreen,
        foregroundColor: Colors.white,
        title: const Text('Худжанд'),
        actions: [
          IconButton(
            tooltip: 'Профиль',
            onPressed: () => _selectTab(2),
            icon: const Icon(Icons.account_circle_rounded),
          ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 58,
              20,
              18,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [TajGoColors.darkGreen, TajGoColors.green],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _greeting(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  '📍 Текущая локация определяется при создании заказа',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList.list(
          children: [
            StreamBuilder<TajGoOrder?>(
              stream: scope.orderRepository.activeOrderStream(uid),
              builder: (context, snapshot) => snapshot.data == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ActiveOrderCard(order: snapshot.data!),
                    ),
            ),
            Card(
              color: TajGoColors.darkGreen,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _openOrder,
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: TajGoColors.darkGreen,
                          size: 32,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Отправить посылку',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Укажите маршрут и назначьте свою цену.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Партнёры рядом',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CategoryCard(
                    icon: Icons.restaurant_rounded,
                    title: 'Еда',
                    onTap: () => _openMarketplace('food'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CategoryCard(
                    icon: Icons.shopping_basket_rounded,
                    title: 'Продукты',
                    onTap: () => _openMarketplace('groceries'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CategoryCard(
                    icon: Icons.local_florist_rounded,
                    title: 'Цветы',
                    onTap: () => _openMarketplace('flowers'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Последние заказы',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<TajGoOrder>>(
              stream: scope.orderRepository.recentOrdersStream(uid),
              builder: (context, snapshot) {
                final orders = snapshot.data ?? const <TajGoOrder>[];
                if (orders.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Завершённые доставки появятся здесь.'),
                    ),
                  );
                }
                return Column(
                  children: orders
                      .map((order) => TajGoOrderHistoryTile(order: order))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    ],
  );

  Widget _orders(TajGoScope scope, String uid) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Мои заказы',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        StreamBuilder<TajGoOrder?>(
          stream: scope.orderRepository.activeOrderStream(uid),
          builder: (context, snapshot) => snapshot.data == null
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Активного заказа нет.'),
                  ),
                )
              : _ActiveOrderCard(order: snapshot.data!),
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<TajGoOrder>>(
          stream: scope.orderRepository.recentOrdersStream(uid),
          builder: (context, snapshot) => Column(
            children: (snapshot.data ?? const <TajGoOrder>[])
                .map((order) => TajGoOrderHistoryTile(order: order))
                .toList(growable: false),
          ),
        ),
      ],
    ),
  );

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, color: TajGoColors.darkGreen, size: 30),
            const SizedBox(height: 7),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ),
  );
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});

  final TajGoOrder order;

  @override
  Widget build(BuildContext context) => Card(
    color: TajGoColors.mint,
    child: ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OrderTrackingScreen(orderId: order.id),
        ),
      ),
      leading: const CircleAvatar(
        backgroundColor: TajGoColors.darkGreen,
        child: Icon(Icons.delivery_dining_rounded, color: Colors.white),
      ),
      title: Text(
        order.status == OrderStatus.waiting
            ? 'Ждём предложения курьеров'
            : 'Активная доставка',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text('${order.fromText} → ${order.toText}', maxLines: 2),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}
