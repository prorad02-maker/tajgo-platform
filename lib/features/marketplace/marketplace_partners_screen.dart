import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/marketplace_partner.dart';
import '../../core/services/marketplace_repository.dart';
import '../../core/services/user_error_message.dart';
import '../../core/utils/money_formatter.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../../shared/widgets/tajgo_state_view.dart';
import 'partner_catalog_screen.dart';

class MarketplacePartnersScreen extends StatefulWidget {
  const MarketplacePartnersScreen({
    super.key,
    required this.category,
    this.repository,
  });

  final String category;
  final MarketplaceRepository? repository;

  @override
  State<MarketplacePartnersScreen> createState() =>
      _MarketplacePartnersScreenState();
}

class _MarketplacePartnersScreenState extends State<MarketplacePartnersScreen> {
  Stream<List<MarketplacePartner>>? _partners;

  MarketplaceRepository get _repository =>
      widget.repository ?? TajGoScope.of(context).marketplaceRepository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _partners ??= _repository.partnersStream(category: widget.category);
  }

  @override
  void didUpdateWidget(MarketplacePartnersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category ||
        oldWidget.repository != widget.repository) {
      _partners = _repository.partnersStream(category: widget.category);
    }
  }

  void _retry() => setState(() {
    _partners = _repository.partnersStream(category: widget.category);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(marketplaceCategoryLabel(widget.category))),
      body: StreamBuilder<List<MarketplacePartner>>(
        stream: _partners,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return TajGoStateView(
              icon: Icons.cloud_off_rounded,
              title: 'Не удалось загрузить партнёров',
              message: userErrorMessage(snapshot.error),
              onRetry: _retry,
            );
          }
          final partners = snapshot.data ?? const <MarketplacePartner>[];
          if (partners.isEmpty) {
            return TajGoStateView(
              icon: Icons.storefront_rounded,
              title: 'Партнёры скоро появятся',
              message: 'Мы подключаем проверенные места Худжанда.',
              onRetry: _retry,
              actionLabel: 'Обновить',
            );
          }
          final preview = partners.any((partner) => partner.isPreview);
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: partners.length + (preview ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (preview && index == 0) {
                return const Card(
                  color: Color(0xFFFFF8E1),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Пока база заполняется, показываем временные '
                            'примеры заведений Худжанда.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final partner = partners[index - (preview ? 1 : 0)];
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
                          icon: _categoryIcon(partner.category),
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
                                      maxLines: 2,
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
                                          'доставка ${formatMoney(partner.deliveryFee.clamp(10, 100000))} TJS'
                                    : 'Закрыто · ${partner.workingHours}',
                                style: TextStyle(
                                  color: partner.isOpen
                                      ? TajGoColors.darkGreen
                                      : TajGoColors.muted,
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

IconData _categoryIcon(String category) => switch (category) {
  'food' => Icons.restaurant_rounded,
  'groceries' => Icons.shopping_basket_rounded,
  'flowers' => Icons.local_florist_rounded,
  _ => Icons.storefront_rounded,
};

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
