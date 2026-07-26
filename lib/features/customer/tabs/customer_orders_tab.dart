import 'package:flutter/material.dart';

import '../../../core/models/tajgo_order.dart';
import '../../../shared/design/tajgo_components.dart';
import '../../../shared/widgets/tajgo_order_history_tile.dart';
import '../../../shared/widgets/tajgo_scope.dart';
import '../widgets/active_order_card.dart';

/// Вкладка «Заказы»: активный заказ и история (завершённые/отменённые).
class CustomerOrdersTab extends StatelessWidget {
  const CustomerOrdersTab({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser!.uid;

    return TajGoScaffold(
      appBar: const TajGoAppBar(title: 'Мои заказы'),
      body: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: StreamBuilder<TajGoOrder?>(
              stream: scope.orderRepository.activeOrderStream(uid),
              builder: (context, snapshot) {
                if (snapshot.data == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TajGoSpacing.screenH,
                    TajGoSpacing.md,
                    TajGoSpacing.screenH,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Активный заказ', style: TajGoTypography.title),
                      const SizedBox(height: TajGoSpacing.sm),
                      ActiveOrderCard(order: snapshot.data!),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<TajGoOrder>>(
              stream: scope.orderRepository.recentOrdersStream(uid),
              builder: (context, snapshot) {
                final orders = snapshot.data ?? const <TajGoOrder>[];
                if (orders.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: TajGoSpacing.xxxl),
                    child: TajGoEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Заказов пока нет',
                      message: 'Завершённые доставки появятся здесь.',
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TajGoSectionHeader(title: 'История'),
                    ...orders.map(
                      (order) => TajGoOrderHistoryTile(order: order),
                    ),
                    const SizedBox(height: TajGoSpacing.xxl),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
