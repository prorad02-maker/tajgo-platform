import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/marketplace_partner.dart';
import '../../../core/models/tajgo_order.dart';
import '../../../shared/design/tajgo_components.dart';
import '../../../shared/widgets/tajgo_order_history_tile.dart';
import '../../../shared/widgets/tajgo_scope.dart';
import '../../auth/phone_auth_screen.dart';
import '../../map/screens/new_order_map_screen.dart';
import '../../marketplace/marketplace_partners_screen.dart';
import '../../marketplace/partner_catalog_screen.dart';
import '../../marketplace/widgets/marketplace_partner_card.dart';
import '../widgets/active_order_card.dart';

/// Вкладка «Главная»: адрес города, поиск, отправка посылки, категории,
/// активный заказ, заведения рядом и последние заказы.
class CustomerHomeTab extends StatelessWidget {
  const CustomerHomeTab({
    super.key,
    required this.scrollController,
    required this.onOpenSearch,
    required this.onOpenCart,
  });

  final ScrollController scrollController;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenCart;

  Future<void> _openParcel(BuildContext context) async {
    final scope = TajGoScope.of(context);
    final firebaseUser = scope.authService.currentUser;
    final profile = firebaseUser == null
        ? null
        : await scope.userRepository.getUser(firebaseUser.uid);
    if (!context.mounted) return;
    if (firebaseUser == null ||
        (!kDebugMode && profile?.phoneVerified != true)) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const PhoneAuthScreen(allowAnonymousFallback: false),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const NewOrderMapScreen(initialType: 'package'),
      ),
    );
  }

  void _openCategory(BuildContext context, String category) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => MarketplacePartnersScreen(category: category),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final flags = scope.featureFlags;
    final uid = scope.authService.currentUser!.uid;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(child: _header(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TajGoSpacing.screenH,
                TajGoSpacing.sm,
                TajGoSpacing.screenH,
                TajGoSpacing.xs,
              ),
              child: TajGoSearchField(readOnly: true, onTap: onOpenSearch),
            ),
          ),
          SliverToBoxAdapter(child: _parcelCard(context)),
          if (flags.marketplace)
            SliverToBoxAdapter(child: _categories(context)),
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
                  child: ActiveOrderCard(order: snapshot.data!),
                );
              },
            ),
          ),
          if (flags.marketplace) _nearbySection(context, scope),
          _recentSection(context, scope, uid),
          const SliverToBoxAdapter(child: SizedBox(height: TajGoSpacing.xxl)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TajGoSpacing.screenH,
        TajGoSpacing.md,
        TajGoSpacing.screenH,
        0,
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: TajGoColors.green),
          const SizedBox(width: TajGoSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Худжанд', style: TajGoTypography.title),
                Text(
                  'Доставка по городу',
                  style: TajGoTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parcelCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TajGoSpacing.screenH,
        TajGoSpacing.sm,
        TajGoSpacing.screenH,
        0,
      ),
      child: TajGoCard(
        color: TajGoColors.darkGreen,
        shadows: TajGoShadows.md,
        onTap: () => _openParcel(context),
        padding: const EdgeInsets.all(TajGoSpacing.lg),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.inventory_2_rounded,
                color: TajGoColors.darkGreen,
                size: 30,
              ),
            ),
            const SizedBox(width: TajGoSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Отправить посылку',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: TajGoSpacing.xxs),
                  Text(
                    'Укажите откуда и куда — назначьте свою цену',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _categories(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TajGoSpacing.screenH,
        TajGoSpacing.lg,
        TajGoSpacing.screenH,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: _CategoryCard(
              icon: Icons.restaurant_rounded,
              title: 'Еда',
              onTap: () => _openCategory(context, 'food'),
            ),
          ),
          const SizedBox(width: TajGoSpacing.sm),
          Expanded(
            child: _CategoryCard(
              icon: Icons.shopping_basket_rounded,
              title: 'Продукты',
              onTap: () => _openCategory(context, 'groceries'),
            ),
          ),
          const SizedBox(width: TajGoSpacing.sm),
          Expanded(
            child: _CategoryCard(
              icon: Icons.local_florist_rounded,
              title: 'Цветы',
              onTap: () => _openCategory(context, 'flowers'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nearbySection(BuildContext context, TajGoScope scope) {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<MarketplacePartner>>(
        stream: scope.marketplaceRepository.partnersStream(),
        builder: (context, snapshot) {
          final partners = (snapshot.data ?? const <MarketplacePartner>[])
              .where((p) => !p.isPreview || scope.featureFlags.previewData)
              .take(5)
              .toList(growable: false);
          if (partners.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TajGoSectionHeader(title: 'Заведения рядом'),
              ...partners.map(
                (partner) => MarketplacePartnerCard(
                  partner: partner,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PartnerCatalogScreen(partner: partner),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _recentSection(BuildContext context, TajGoScope scope, String uid) {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<TajGoOrder>>(
        stream: scope.orderRepository.recentOrdersStream(uid),
        builder: (context, snapshot) {
          final orders = snapshot.data ?? const <TajGoOrder>[];
          if (orders.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TajGoSectionHeader(title: 'Повторить заказ'),
              ...orders
                  .take(4)
                  .map((order) => TajGoOrderHistoryTile(order: order)),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TajGoCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(
      vertical: TajGoSpacing.lg,
      horizontal: TajGoSpacing.sm,
    ),
    child: Column(
      children: [
        Icon(icon, color: TajGoColors.darkGreen, size: TajGoIconSizes.xl),
        const SizedBox(height: TajGoSpacing.sm),
        Text(
          title,
          style: TajGoTypography.body.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
