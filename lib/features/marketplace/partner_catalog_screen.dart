import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/marketplace_cart.dart';
import '../../core/models/marketplace_partner.dart';
import '../../core/models/marketplace_product.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'marketplace_checkout_screen.dart';
import 'marketplace_partners_screen.dart';

class PartnerCatalogScreen extends StatelessWidget {
  const PartnerCatalogScreen({super.key, required this.partner});

  final MarketplacePartner partner;

  Future<void> _add(BuildContext context, MarketplaceProduct product) async {
    final cart = TajGoScope.of(context).marketplaceCart;
    try {
      cart.add(partner, product);
    } on MarketplaceCartConflict catch (conflict) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Начать новую корзину?'),
          content: Text(
            'Сейчас в корзине товары «${conflict.partnerName}». Очистить её и начать заказ у «${partner.name}»?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Оставить'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Очистить и добавить'),
            ),
          ],
        ),
      );
      if (replace == true) cart.replacePartner(partner, product);
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
    final scope = TajGoScope.of(context);
    final cart = scope.marketplaceCart;
    return Scaffold(
      appBar: AppBar(title: Text(partner.name)),
      body: StreamBuilder<List<MarketplaceProduct>>(
        stream: scope.marketplaceRepository.productsStream(
          partner.id,
          previewFallback: partner.isPreview,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Не удалось загрузить товары. Попробуйте позже.'),
            );
          }
          final products = snapshot.data ?? const <MarketplaceProduct>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _PartnerHeader(partner: partner),
              if (partner.isPreview) ...[
                const SizedBox(height: 10),
                const Card(
                  color: Color(0xFFFFF8E1),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Это временный пример ассортимента. Администратор может '
                      'загрузить готовые примеры в Firestore или заменить их '
                      'реальными заведениями.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (products.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('У этого партнёра пока нет товаров.'),
                  ),
                )
              else
                ...products.map(
                  (product) => _ProductCard(
                    product: product,
                    partnerOpen: partner.isOpen,
                    cart: cart,
                    onAdd: () => _add(context, product),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: cart,
        builder: (context, _) {
          if (cart.isEmpty || cart.partner?.id != partner.id) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            minimum: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const MarketplaceCheckoutScreen(),
                ),
              ),
              icon: const Icon(Icons.shopping_cart_rounded),
              label: Text(
                'Корзина · ${cart.itemKinds} поз. · ${cart.total} TJS',
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PartnerHeader extends StatelessWidget {
  const _PartnerHeader({required this.partner});

  final MarketplacePartner partner;

  @override
  Widget build(BuildContext context) => Card(
    color: TajGoColors.mint,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            partner.description.isEmpty ? partner.address : partner.description,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${partner.address} · ~${partner.preparationMinutes} мин · '
            'минимум ${partner.minimumOrder} TJS · '
            'доставка ${partner.deliveryFee} TJS',
            style: const TextStyle(color: TajGoColors.muted, fontSize: 12),
          ),
          if (!partner.isOpen) ...[
            const SizedBox(height: 8),
            Text(
              'Сейчас закрыто${partner.workingHours.isEmpty ? '' : ' · ${partner.workingHours}'}',
              style: const TextStyle(
                color: TajGoColors.warning,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.partnerOpen,
    required this.cart,
    required this.onAdd,
  });

  final MarketplaceProduct product;
  final bool partnerOpen;
  final MarketplaceCart cart;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final enabled = partnerOpen && product.isAvailable;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: MarketplaceImage(
                imageUrl: product.imageUrl,
                icon: Icons.shopping_bag_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (product.description.isNotEmpty)
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: TajGoColors.muted),
                    ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        '${product.price} TJS / ${marketplaceUnitLabel(product.unit)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (product.oldPrice != null) ...[
                        const SizedBox(width: 7),
                        Text(
                          '${product.oldPrice}',
                          style: const TextStyle(
                            color: TajGoColors.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!product.isAvailable)
                    const Text(
                      'Закончилось',
                      style: TextStyle(color: TajGoColors.warning),
                    ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: cart,
              builder: (context, _) {
                final matchingCart = cart.partner?.id == product.partnerId;
                final line = matchingCart
                    ? cart.lines
                          .where((line) => line.product.id == product.id)
                          .firstOrNull
                    : null;
                if (line == null) {
                  return IconButton.filledTonal(
                    tooltip: 'Добавить',
                    onPressed: enabled ? onAdd : null,
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Добавить',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 34,
                      ),
                      onPressed: enabled
                          ? () => cart.increment(product.id)
                          : null,
                      icon: const Icon(Icons.add_circle_rounded),
                    ),
                    Text(
                      _productQuantity(line.quantity),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    IconButton(
                      tooltip: 'Уменьшить',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 34,
                      ),
                      onPressed: () => cart.decrement(product.id),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _productQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
