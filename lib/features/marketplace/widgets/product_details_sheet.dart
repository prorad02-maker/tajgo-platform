import 'package:flutter/material.dart';

import '../../../core/models/marketplace_cart.dart';
import '../../../core/models/marketplace_product.dart';
import '../../../shared/design/tajgo_components.dart';
import '../marketplace_partners_screen.dart';

/// Детали товара в bottom sheet: изображение, описание, цена, количество и
/// добавление в корзину.
Future<void> showProductDetailsSheet({
  required BuildContext context,
  required MarketplaceProduct product,
  required MarketplaceCart cart,
  required bool enabled,
  required VoidCallback onAdd,
}) {
  return showTajGoBottomSheet<void>(
    context: context,
    builder: (context) => _ProductDetails(
      product: product,
      cart: cart,
      enabled: enabled,
      onAdd: onAdd,
    ),
  );
}

class _ProductDetails extends StatelessWidget {
  const _ProductDetails({
    required this.product,
    required this.cart,
    required this.enabled,
    required this.onAdd,
  });

  final MarketplaceProduct product;
  final MarketplaceCart cart;
  final bool enabled;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TajGoSpacing.lg,
        TajGoSpacing.sm,
        TajGoSpacing.lg,
        TajGoSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: TajGoRadius.lgAll,
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: MarketplaceImage(
                imageUrl: product.imageUrl,
                icon: Icons.shopping_bag_rounded,
              ),
            ),
          ),
          const SizedBox(height: TajGoSpacing.md),
          Text(product.name, style: TajGoTypography.title),
          const SizedBox(height: TajGoSpacing.xs),
          Row(
            children: [
              TajGoPrice(
                value: product.price,
                oldValue: product.oldPrice,
                style: TajGoTypography.title.copyWith(
                  color: TajGoColors.darkGreen,
                ),
              ),
              Text(
                ' / ${marketplaceUnitLabel(product.unit)}',
                style: TajGoTypography.caption,
              ),
            ],
          ),
          if (product.description.isNotEmpty) ...[
            const SizedBox(height: TajGoSpacing.md),
            Text(product.description, style: TajGoTypography.body),
          ],
          if (!product.isAvailable) ...[
            const SizedBox(height: TajGoSpacing.md),
            const TajGoStatusChip(
              label: 'Закончилось',
              tone: TajGoStatusTone.warning,
            ),
          ],
          const SizedBox(height: TajGoSpacing.lg),
          AnimatedBuilder(
            animation: cart,
            builder: (context, _) {
              final inCart = cart.partner?.id == product.partnerId;
              final line = inCart
                  ? cart.lines
                        .where((l) => l.product.id == product.id)
                        .firstOrNull
                  : null;
              if (line == null) {
                return TajGoPrimaryButton(
                  label: 'Добавить в корзину',
                  icon: Icons.add_shopping_cart_rounded,
                  onPressed: enabled
                      ? () {
                          onAdd();
                          Navigator.of(context).maybePop();
                        }
                      : null,
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => cart.decrement(product.id),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Text(
                    line.quantity == line.quantity.roundToDouble()
                        ? '${line.quantity.toInt()} ${marketplaceUnitLabel(product.unit)}'
                        : '${line.quantity.toStringAsFixed(1)} ${marketplaceUnitLabel(product.unit)}',
                    style: TajGoTypography.subtitle,
                  ),
                  IconButton.filledTonal(
                    onPressed: enabled
                        ? () => cart.increment(product.id)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
