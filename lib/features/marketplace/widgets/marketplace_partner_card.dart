import 'package:flutter/material.dart';

import '../../../core/models/marketplace_partner.dart';
import '../../../shared/design/tajgo_components.dart';

/// Сетевое изображение с плейсхолдером — для логотипов/обложек каталога.
class MarketplaceThumb extends StatelessWidget {
  const MarketplaceThumb({
    super.key,
    required this.imageUrl,
    this.size = 60,
    this.icon = Icons.storefront_rounded,
    this.radius = TajGoRadius.md,
  });

  final String imageUrl;
  final double size;
  final IconData icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TajGoColors.secondaryBtn,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: TajGoColors.darkGreen, size: size * 0.42),
    );
    if (imageUrl.trim().isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}

/// Единая карточка партнёра каталога.
class MarketplacePartnerCard extends StatelessWidget {
  const MarketplacePartnerCard({
    super.key,
    required this.partner,
    required this.onTap,
    this.distanceKm,
    this.margin = const EdgeInsets.symmetric(
      horizontal: TajGoSpacing.screenH,
      vertical: TajGoSpacing.sm,
    ),
  });

  final MarketplacePartner partner;
  final VoidCallback onTap;
  final double? distanceKm;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return TajGoCard(
      margin: margin,
      onTap: onTap,
      padding: const EdgeInsets.all(TajGoSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarketplaceThumb(imageUrl: partner.imageUrl),
          const SizedBox(width: TajGoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        partner.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TajGoTypography.subtitle,
                      ),
                    ),
                    const SizedBox(width: TajGoSpacing.sm),
                    partner.isOpen
                        ? const TajGoStatusChip(
                            label: 'Открыто',
                            tone: TajGoStatusTone.success,
                          )
                        : const TajGoStatusChip(
                            label: 'Закрыто',
                            tone: TajGoStatusTone.neutral,
                          ),
                  ],
                ),
                const SizedBox(height: TajGoSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: TajGoIconSizes.sm,
                      color: TajGoColors.warning,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      partner.rating.toStringAsFixed(1),
                      style: TajGoTypography.label.copyWith(
                        color: TajGoColors.ink,
                      ),
                    ),
                    const SizedBox(width: TajGoSpacing.sm),
                    Icon(
                      Icons.schedule_rounded,
                      size: TajGoIconSizes.sm,
                      color: TajGoColors.muted,
                    ),
                    const SizedBox(width: 2),
                    Text('${partner.preparationMinutes} мин',
                        style: TajGoTypography.label),
                    if (distanceKm != null) ...[
                      const SizedBox(width: TajGoSpacing.sm),
                      const Icon(
                        Icons.near_me_rounded,
                        size: TajGoIconSizes.sm,
                        color: TajGoColors.muted,
                      ),
                      const SizedBox(width: 2),
                      Text('${distanceKm!.toStringAsFixed(1)} км',
                          style: TajGoTypography.label),
                    ],
                  ],
                ),
                const SizedBox(height: TajGoSpacing.xs),
                Text(
                  _meta(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TajGoTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _meta() {
    final parts = <String>[
      'Доставка ${TajGoMoney.format(partner.deliveryFee)}',
      if (partner.minimumOrder > 0)
        'мин. ${TajGoMoney.format(partner.minimumOrder)}',
    ];
    return parts.join(' · ');
  }
}
