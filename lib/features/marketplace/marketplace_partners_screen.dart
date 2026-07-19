import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/marketplace_partner.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'partner_catalog_screen.dart';

class MarketplacePartnersScreen extends StatelessWidget {
  const MarketplacePartnersScreen({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final repository = TajGoScope.of(context).marketplaceRepository;
    return Scaffold(
      appBar: AppBar(title: Text(marketplaceCategoryLabel(category))),
      body: StreamBuilder<List<MarketplacePartner>>(
        stream: repository.partnersStream(category: category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _Message(
              icon: Icons.cloud_off_rounded,
              title: 'Не удалось загрузить партнёров',
              subtitle: 'Проверьте интернет и Firestore Rules.',
            );
          }
          final partners = snapshot.data ?? const <MarketplacePartner>[];
          if (partners.isEmpty) {
            return const _Message(
              icon: Icons.storefront_rounded,
              title: 'Партнёры скоро появятся',
              subtitle: 'Мы подключаем проверенные места Худжанда.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: partners.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final partner = partners[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PartnerCatalogScreen(partner: partner),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 104,
                        height: 112,
                        child: _MarketplaceImage(
                          imageUrl: partner.imageUrl,
                          icon: Icons.storefront_rounded,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
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
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '★ ${partner.rating.toStringAsFixed(1)}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                partner.description.isEmpty
                                    ? partner.address
                                    : partner.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: TajGoColors.muted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                partner.isOpen
                                    ? 'Открыто · ~${partner.preparationMinutes} мин · '
                                          'доставка ${partner.deliveryFee} TJS'
                                    : 'Закрыто · ${partner.workingHours}',
                                style: TextStyle(
                                  color: partner.isOpen
                                      ? TajGoColors.darkGreen
                                      : TajGoColors.warning,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: TajGoColors.green),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: TajGoColors.muted),
          ),
        ],
      ),
    ),
  );
}

class MarketplaceImage extends StatelessWidget {
  const MarketplaceImage({
    super.key,
    required this.imageUrl,
    required this.icon,
  });

  final String imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      _MarketplaceImage(imageUrl: imageUrl, icon: icon);
}

class _MarketplaceImage extends StatelessWidget {
  const _MarketplaceImage({required this.imageUrl, required this.icon});

  final String imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: TajGoColors.mint,
      child: Center(child: Icon(icon, size: 38, color: TajGoColors.darkGreen)),
    );
    if (imageUrl.trim().isEmpty) return fallback;
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const ColoredBox(
              color: TajGoColors.mint,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
    );
  }
}
