import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_partner.dart';
import '../../../core/models/marketplace_product.dart';
import '../../../shared/design/tajgo_components.dart';
import '../../../shared/widgets/tajgo_scope.dart';
import '../../marketplace/marketplace_partners_screen.dart';
import '../../marketplace/partner_catalog_screen.dart';
import '../../marketplace/widgets/marketplace_partner_card.dart';

/// Вкладка «Поиск»: единый поиск по заведениям, товарам и категориям каталога.
///
/// Это не поиск адресов карты — у карты свой поиск. Результаты фильтруются на
/// клиенте по опубликованным партнёрам/товарам с debounce.
class MarketplaceSearchTab extends StatefulWidget {
  const MarketplaceSearchTab({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<MarketplaceSearchTab> createState() => _MarketplaceSearchTabState();
}

class _MarketplaceSearchTabState extends State<MarketplaceSearchTab> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _recent = <String>[];

  Timer? _debounce;
  String _query = '';

  List<MarketplacePartner> _partners = const [];
  List<MarketplaceProduct> _products = const [];
  StreamSubscription<List<MarketplacePartner>>? _partnersSub;
  StreamSubscription<List<MarketplaceProduct>>? _productsSub;
  bool _partnersFailed = false, _productsFailed = false;
  bool _partnersLoading = true, _productsLoading = true;
  int _revision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_partnersSub != null) return;
    _subscribe();
  }

  void _subscribe() {
    final revision = ++_revision;
    unawaited(_partnersSub?.cancel());
    unawaited(_productsSub?.cancel());
    _partnersFailed = _productsFailed = false;
    _partnersLoading = _productsLoading = true;
    _partners = [];
    _products = [];
    final repo = TajGoScope.of(context).marketplaceRepository;
    _partnersSub = repo
        .partnersStream(
          allowPreview: TajGoScope.of(context).featureFlags.previewData,
        )
        .listen(
          (partners) {
            if (mounted && _revision == revision) {
              setState(() {
                _partners = partners;
                _partnersLoading = false;
                _partnersFailed = false;
              });
            }
          },
          onError: (Object _) {
            if (mounted && _revision == revision) {
              setState(() {
                _partnersFailed = true;
                _partnersLoading = false;
              });
            }
          },
        );
    _productsSub = repo.publishedProductsStream().listen(
      (products) {
        if (mounted && _revision == revision) {
          setState(() {
            _products = products;
            _productsLoading = false;
            _productsFailed = false;
          });
        }
      },
      onError: (Object _) {
        if (mounted && _revision == revision) {
          setState(() {
            _productsFailed = true;
            _productsLoading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _revision++;
    _debounce?.cancel();
    _partnersSub?.cancel();
    _productsSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = _normalize(value));
    });
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _query = _normalize(trimmed);
      _recent
        ..removeWhere((e) => e.toLowerCase() == trimmed.toLowerCase())
        ..insert(0, trimmed);
      if (_recent.length > 6) _recent.removeLast();
    });
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
  }

  void _applyTerm(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    _submit(term);
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  Widget build(BuildContext context) {
    return TajGoScaffold(
      appBar: const TajGoAppBar(title: 'Поиск'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TajGoSpacing.screenH,
              TajGoSpacing.sm,
              TajGoSpacing.screenH,
              TajGoSpacing.sm,
            ),
            child: TajGoSearchField(
              controller: _controller,
              autofocus: false,
              onChanged: _onChanged,
              onSubmitted: _submit,
              onClear: _clear,
            ),
          ),
          Expanded(
            child: _partnersFailed || _productsFailed
                ? TajGoErrorState(
                    title: 'Не удалось загрузить каталог',
                    onRetry: () => setState(_subscribe),
                  )
                : _partnersLoading || _productsLoading
                ? ListView(
                    children: const [TajGoCardSkeleton(), TajGoCardSkeleton()],
                  )
                : _query.isEmpty
                ? _idleView()
                : _resultsView(),
          ),
        ],
      ),
    );
  }

  Widget _idleView() {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: TajGoSpacing.xxl),
      children: [
        const TajGoSectionHeader(title: 'Категории'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TajGoSpacing.screenH),
          child: Wrap(
            spacing: TajGoSpacing.sm,
            runSpacing: TajGoSpacing.sm,
            children: marketplaceCategories
                .map(
                  (c) => ActionChip(
                    label: Text(marketplaceCategoryLabel(c)),
                    backgroundColor: TajGoColors.secondaryBtn,
                    side: BorderSide.none,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MarketplacePartnersScreen(category: c),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        if (_recent.isNotEmpty) ...[
          TajGoSectionHeader(
            title: 'Недавние запросы',
            actionLabel: 'Очистить',
            onAction: () => setState(_recent.clear),
          ),
          ..._recent.map(
            (term) => ListTile(
              leading: const Icon(
                Icons.history_rounded,
                color: TajGoColors.muted,
              ),
              title: Text(term, style: TajGoTypography.body),
              onTap: () => _applyTerm(term),
            ),
          ),
        ],
      ],
    );
  }

  Widget _resultsView() {
    final partners = _partners
        .where((p) => !p.isPreview)
        .where(
          (p) =>
              _normalize(p.name).contains(_query) ||
              marketplaceCategoryLabel(
                p.category,
              ).toLowerCase().contains(_query),
        )
        .toList(growable: false);

    final partnerById = {for (final p in _partners) p.id: p};
    final products = _products
        .where((p) => partnerById.containsKey(p.partnerId))
        .where((p) => _normalize(p.name).contains(_query))
        .take(30)
        .toList(growable: false);

    final categories = marketplaceCategories
        .where(
          (c) => marketplaceCategoryLabel(c).toLowerCase().contains(_query),
        )
        .toList(growable: false);

    if (partners.isEmpty && products.isEmpty && categories.isEmpty) {
      return const TajGoEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Ничего не найдено',
        message: 'Попробуйте изменить запрос или выбрать категорию.',
      );
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: TajGoSpacing.xxl),
      children: [
        if (categories.isNotEmpty) ...[
          const TajGoSectionHeader(title: 'Категории'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TajGoSpacing.screenH,
            ),
            child: Wrap(
              spacing: TajGoSpacing.sm,
              children: categories
                  .map(
                    (c) => ActionChip(
                      label: Text(marketplaceCategoryLabel(c)),
                      backgroundColor: TajGoColors.secondaryBtn,
                      side: BorderSide.none,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MarketplacePartnersScreen(category: c),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
        if (partners.isNotEmpty) ...[
          const TajGoSectionHeader(title: 'Заведения'),
          ...partners.map(
            (partner) => MarketplacePartnerCard(
              partner: partner,
              onTap: () => _openPartner(partner),
            ),
          ),
        ],
        if (products.isNotEmpty) ...[
          const TajGoSectionHeader(title: 'Товары'),
          ...products.map(
            (product) => _ProductResultTile(
              product: product,
              partner: partnerById[product.partnerId]!,
              onTap: () => _openPartner(partnerById[product.partnerId]!),
            ),
          ),
        ],
      ],
    );
  }

  void _openPartner(MarketplacePartner partner) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => PartnerCatalogScreen(partner: partner),
    ),
  );
}

class _ProductResultTile extends StatelessWidget {
  const _ProductResultTile({
    required this.product,
    required this.partner,
    required this.onTap,
  });

  final MarketplaceProduct product;
  final MarketplacePartner partner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TajGoCard(
      margin: const EdgeInsets.symmetric(
        horizontal: TajGoSpacing.screenH,
        vertical: TajGoSpacing.xs,
      ),
      padding: const EdgeInsets.all(TajGoSpacing.sm),
      onTap: onTap,
      child: Row(
        children: [
          MarketplaceThumb(
            imageUrl: product.imageUrl,
            size: 48,
            icon: Icons.shopping_bag_rounded,
          ),
          const SizedBox(width: TajGoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TajGoTypography.bodyStrong,
                ),
                Text(
                  partner.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TajGoTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: TajGoSpacing.sm),
          TajGoPrice(value: product.price, oldValue: product.oldPrice),
        ],
      ),
    );
  }
}
