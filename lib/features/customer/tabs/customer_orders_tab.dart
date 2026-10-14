import 'package:flutter/material.dart';

import '../../../core/models/tajgo_order.dart';
import '../../../shared/design/tajgo_components.dart';
import '../../../shared/widgets/tajgo_order_history_tile.dart';
import '../../../shared/widgets/tajgo_scope.dart';
import '../widgets/active_order_card.dart';

enum _OrdersFilter { all, active, completed, cancelled }

/// Вкладка «Заказы»: активные / завершённые / отменённые / спорные,
/// custom и catalog, с фильтрами и человеческими статусами.
class CustomerOrdersTab extends StatefulWidget {
  const CustomerOrdersTab({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<CustomerOrdersTab> createState() => _CustomerOrdersTabState();
}

class _CustomerOrdersTabState extends State<CustomerOrdersTab> {
  _OrdersFilter _filter = _OrdersFilter.all;

  bool _matches(TajGoOrder order) => switch (_filter) {
    _OrdersFilter.all => true,
    _OrdersFilter.active => order.isActive,
    _OrdersFilter.completed => order.status == OrderStatus.completed,
    _OrdersFilter.cancelled => order.status == OrderStatus.cancelled,
  };

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser!.uid;

    return TajGoScaffold(
      appBar: const TajGoAppBar(title: 'Мои заказы'),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: StreamBuilder<List<TajGoOrder>>(
              stream: scope.orderRepository.customerOrdersStream(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const TajGoErrorState();
                }
                if (!snapshot.hasData) {
                  return ListView(
                    controller: widget.scrollController,
                    children: const [
                      TajGoCardSkeleton(),
                      TajGoCardSkeleton(),
                      TajGoCardSkeleton(),
                    ],
                  );
                }
                final all = snapshot.data!;
                final active = all
                    .where((o) => o.isActive)
                    .toList(growable: false);
                final filtered = all.where(_matches).toList(growable: false);
                if (filtered.isEmpty) {
                  return TajGoEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _filter == _OrdersFilter.all
                        ? 'Заказов пока нет'
                        : 'Здесь пусто',
                    message: 'Ваши заказы появятся здесь.',
                  );
                }
                return ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.only(bottom: TajGoSpacing.xxl),
                  children: [
                    if (_filter == _OrdersFilter.all && active.isNotEmpty) ...[
                      const TajGoSectionHeader(title: 'Активные'),
                      ...active.map(
                        (o) => ActiveOrderCard(
                          order: o,
                          margin: const EdgeInsets.symmetric(
                            horizontal: TajGoSpacing.screenH,
                            vertical: TajGoSpacing.xs,
                          ),
                        ),
                      ),
                      const TajGoSectionHeader(title: 'История'),
                      ...filtered
                          .where((o) => !o.isActive)
                          .map((o) => TajGoOrderHistoryTile(order: o)),
                    ] else
                      ...filtered.map((o) => TajGoOrderHistoryTile(order: o)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    const labels = {
      _OrdersFilter.all: 'Все',
      _OrdersFilter.active: 'Активные',
      _OrdersFilter.completed: 'Завершённые',
      _OrdersFilter.cancelled: 'Отменённые',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: TajGoSpacing.screenH,
        vertical: TajGoSpacing.sm,
      ),
      child: Row(
        children: _OrdersFilter.values
            .map((f) {
              return Padding(
                padding: const EdgeInsets.only(right: TajGoSpacing.sm),
                child: ChoiceChip(
                  label: Text(labels[f]!),
                  selected: f == _filter,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: TajGoColors.mint,
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
