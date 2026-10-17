import 'package:flutter/material.dart';

import '../../../shared/design/tajgo_components.dart';
import '../../../shared/widgets/tajgo_scope.dart';
import '../../marketplace/marketplace_checkout_screen.dart';

/// Вкладка «Корзина». Пустая корзина показывает приглашение к каталогу,
/// заполненная — полноценный экран корзины и оформления (одна корзина = один
/// партнёр). Реагирует на изменения корзины в реальном времени.
class CustomerCartTab extends StatelessWidget {
  const CustomerCartTab({
    super.key,
    required this.scrollController,
    required this.onBrowse,
  });

  final ScrollController scrollController;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final cart = TajGoScope.of(context).marketplaceCart;
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        if (cart.isEmpty) {
          return TajGoScaffold(
            appBar: const TajGoAppBar(title: 'Корзина'),
            body: ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: TajGoSpacing.xxxl * 2),
                TajGoEmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Корзина пуста',
                  message:
                      'Выберите заведение и добавьте товары — они появятся здесь.',
                  actionLabel: 'Посмотреть каталог',
                  onAction: onBrowse,
                ),
              ],
            ),
          );
        }
        return const MarketplaceCheckoutScreen();
      },
    );
  }
}
