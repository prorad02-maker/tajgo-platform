import 'package:flutter/material.dart';

import '../../shared/design/tajgo_components.dart';
import '../account/account_profile_screen.dart';
import '../map/screens/new_order_map_screen.dart';
import 'tabs/customer_orders_tab.dart';

/// Delivery-only customer shell. Future verticals are intentionally absent.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  static const _tabCount = 3;
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

  void _select(int next) {
    if (next == _index) {
      final controller = _controllers[_index];
      if (controller.hasClients) {
        controller.animateTo(
          0,
          duration: TajGoDurations.medium,
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _index == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _index != 0) setState(() => _index = 0);
    },
    child: Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const NewOrderMapScreen(),
          CustomerOrdersTab(scrollController: _controllers[1]),
          const CustomerProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Доставка',
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
    ),
  );
}
