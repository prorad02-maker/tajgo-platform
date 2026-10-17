import 'package:flutter/material.dart';

import '../../core/models/marketplace_partner.dart';
import '../../shared/design/tajgo_components.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'partner_catalog_screen.dart';
import 'widgets/marketplace_partner_card.dart';

enum _PartnerSort { smart, rating, faster }

class MarketplacePartnersScreen extends StatefulWidget {
  const MarketplacePartnersScreen({super.key, required this.category});

  final String category;

  @override
  State<MarketplacePartnersScreen> createState() =>
      _MarketplacePartnersScreenState();
}

class _MarketplacePartnersScreenState extends State<MarketplacePartnersScreen> {
  bool _openOnly = false;
  _PartnerSort _sort = _PartnerSort.smart;
  Stream<List<MarketplacePartner>>? _partners;
  Stream<List<MarketplacePartner>> _load() {
    final scope = TajGoScope.of(context);
    return scope.marketplaceRepository.partnersStream(
      category: widget.category,
      allowPreview: scope.featureFlags.previewData,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _partners ??= _load();
  }

  List<MarketplacePartner> _apply(List<MarketplacePartner> input) {
    var list = input.where((p) => !_openOnly || p.isOpen).toList();
    switch (_sort) {
      case _PartnerSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case _PartnerSort.faster:
        list.sort(
          (a, b) => a.preparationMinutes.compareTo(b.preparationMinutes),
        );
      case _PartnerSort.smart:
        list.sort((a, b) {
          final open = (b.isOpen ? 1 : 0).compareTo(a.isOpen ? 1 : 0);
          if (open != 0) return open;
          return a.sortOrder.compareTo(b.sortOrder);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final flags = TajGoScope.of(context).featureFlags;
    return TajGoScaffold(
      appBar: TajGoAppBar(title: marketplaceCategoryLabel(widget.category)),
      body: StreamBuilder<List<MarketplacePartner>>(
        stream: _partners,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return TajGoErrorState(
              title: 'Не удалось загрузить партнёров',
              onRetry: () => setState(() => _partners = _load()),
              message: 'Проверьте интернет и повторите.',
            );
          }
          if (!snapshot.hasData) {
            return ListView(
              children: const [
                TajGoCardSkeleton(),
                TajGoCardSkeleton(),
                TajGoCardSkeleton(),
                TajGoCardSkeleton(),
              ],
            );
          }
          final raw = snapshot.data!
              .where((p) => !p.isPreview || flags.previewData)
              .toList();
          if (raw.isEmpty) {
            return const TajGoEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Заведений пока нет',
              message: 'Выберите другую категорию или зайдите позже.',
            );
          }
          final preview = raw.any((p) => p.isPreview);
          final partners = _apply(raw);
          return Column(
            children: [
              _filters(),
              if (preview) _previewBanner(),
              Expanded(
                child: partners.isEmpty
                    ? const TajGoEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Ничего не найдено',
                        message: 'Измените фильтр.',
                      )
                    : ListView(
                        padding: const EdgeInsets.only(
                          top: TajGoSpacing.xs,
                          bottom: TajGoSpacing.xxl,
                        ),
                        children: partners
                            .map(
                              (partner) => MarketplacePartnerCard(
                                partner: partner,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        PartnerCatalogScreen(partner: partner),
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: TajGoSpacing.screenH,
        vertical: TajGoSpacing.sm,
      ),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Открыто'),
            selected: _openOnly,
            onSelected: (v) => setState(() => _openOnly = v),
            selectedColor: TajGoColors.mint,
          ),
          const SizedBox(width: TajGoSpacing.sm),
          ChoiceChip(
            label: const Text('По рейтингу'),
            selected: _sort == _PartnerSort.rating,
            onSelected: (_) => setState(() => _sort = _PartnerSort.rating),
            selectedColor: TajGoColors.mint,
          ),
          const SizedBox(width: TajGoSpacing.sm),
          ChoiceChip(
            label: const Text('Быстрее'),
            selected: _sort == _PartnerSort.faster,
            onSelected: (_) => setState(() => _sort = _PartnerSort.faster),
            selectedColor: TajGoColors.mint,
          ),
        ],
      ),
    );
  }

  Widget _previewBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: TajGoSpacing.screenH,
        vertical: TajGoSpacing.xs,
      ),
      padding: const EdgeInsets.all(TajGoSpacing.md),
      decoration: BoxDecoration(
        color: TajGoColors.warning.withValues(alpha: 0.15),
        borderRadius: TajGoRadius.smAll,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: TajGoIconSizes.md,
            color: Color(0xFF92600A),
          ),
          const SizedBox(width: TajGoSpacing.sm),
          const Expanded(
            child: Text(
              'Пока база заполняется, показываем временные примеры. '
              'Их нельзя заказать.',
              style: TextStyle(
                color: Color(0xFF92600A),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Публичная обёртка изображения каталога (используется экраном партнёра).
class MarketplaceImage extends StatelessWidget {
  const MarketplaceImage({
    super.key,
    required this.imageUrl,
    required this.icon,
  });

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
