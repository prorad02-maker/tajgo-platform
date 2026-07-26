import 'package:flutter/material.dart';

import '../../core/models/marketplace_cart.dart';
import '../../shared/design/tajgo_components.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../account/account_profile_screen.dart';
import 'tabs/customer_cart_tab.dart';
import 'tabs/customer_home_tab.dart';
import 'tabs/customer_orders_tab.dart';
import 'tabs/marketplace_search_tab.dart';

/// Клиентская оболочка: постоянная нижняя навигация из 5 разделов.
///
/// Состояние табов сохраняется через [IndexedStack]. Повторное нажатие активной
/// вкладки прокручивает её вверх. Системная «назад» с любой вкладки возвращает
/// на «Главная», и только с «Главная» закрывает приложение.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  static const int _tabCount = 5;

  late int _index = widget.initialIndex.clamp(0, _tabCount - 1);
  late final List<ScrollController> _controllers = List.generate(
    _tabCount,
    (_) => ScrollController(),
  );

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onSelect(int next) {
    if (next == _index) {
      _scrollActiveToTop();
      return;
    }
    setState(() => _index = next);
  }

  /// Переключить на конкретную вкладку из дочерних экранов (например, «Оформить»).
  void _goToTab(int index) => setState(() => _index = index.clamp(0, _tabCount - 1));

  void _scrollActiveToTop() {
    final controller = _controllers[_index];
    if (!controller.hasClients) return;
    controller.animateTo(
      0,
      duration: TajGoDurations.medium,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = TajGoScope.of(context).marketplaceCart;
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            CustomerHomeTab(
              scrollController: _controllers[0],
              onOpenSearch: () => _goToTab(1),
              onOpenCart: () => _goToTab(3),
            ),
            MarketplaceSearchTab(scrollController: _controllers[1]),
            CustomerOrdersTab(scrollController: _controllers[2]),
            CustomerCartTab(
              scrollController: _controllers[3],
              onBrowse: () => _goToTab(0),
            ),
            const CustomerProfileScreen(),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: cart,
          builder: (context, _) => NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _onSelect,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Главная',
              ),
              const NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.search_rounded),
                label: 'Поиск',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Заказы',
              ),
              NavigationDestination(
                icon: _CartIcon(cart: cart, selected: false),
                selectedIcon: _CartIcon(cart: cart, selected: true),
                label: 'Корзина',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Профиль',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.cart, required this.selected});

  final MarketplaceCart cart;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final count = cart.itemKinds;
    final icon = Icon(
      selected ? Icons.shopping_cart_rounded : Icons.shopping_cart_outlined,
    );
    if (count == 0) return icon;
    return Badge(
      label: Text('$count'),
      backgroundColor: TajGoColors.green,
      child: icon,
    );
  }
}
