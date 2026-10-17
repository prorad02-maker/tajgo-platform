import 'package:flutter/material.dart';

import '../../core/models/marketplace_partner.dart';
import '../../core/models/merchant_application.dart';
import '../../shared/design/tajgo_components.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'admin_merchant_application_details_screen.dart';
import 'widgets/admin_access_gate.dart';

enum _MerchantFilter { newItems, inWork, needsInfo, approved, done }

/// Админ-раздел «Заявки магазинов»: фильтры и список заявок.
class AdminMerchantApplicationsScreen extends StatefulWidget {
  const AdminMerchantApplicationsScreen({super.key});

  @override
  State<AdminMerchantApplicationsScreen> createState() =>
      _AdminMerchantApplicationsScreenState();
}

class _AdminMerchantApplicationsScreenState
    extends State<AdminMerchantApplicationsScreen> {
  _MerchantFilter _filter = _MerchantFilter.newItems;

  bool _matches(MerchantApplication a) => switch (_filter) {
    _MerchantFilter.newItems => a.status == MerchantStatus.submitted,
    _MerchantFilter.inWork => a.status == MerchantStatus.underReview,
    _MerchantFilter.needsInfo => a.status == MerchantStatus.needsInfo,
    _MerchantFilter.approved => a.status == MerchantStatus.approved,
    _MerchantFilter.done =>
      a.status == MerchantStatus.convertedToPartner ||
          a.status == MerchantStatus.rejected ||
          a.status == MerchantStatus.withdrawn,
  };

  @override
  Widget build(BuildContext context) {
    final repo = TajGoScope.of(context).merchantApplicationRepository;
    return AdminAccessGate(
      child: TajGoScaffold(
        appBar: const TajGoAppBar(title: 'Заявки магазинов'),
        body: Column(
          children: [
            _filters(),
            Expanded(
              child: StreamBuilder<List<MerchantApplication>>(
                stream: repo.allApplicationsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const TajGoErrorState(
                      message: 'Нет доступа к заявкам. Проверьте admin-role.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!
                      .where(_matches)
                      .toList(growable: false);
                  if (items.isEmpty) {
                    return const TajGoEmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Пусто',
                      message: 'В этой категории заявок нет.',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.only(bottom: TajGoSpacing.xxl),
                    children: items
                        .map((a) => _card(context, a))
                        .toList(growable: false),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    const labels = {
      _MerchantFilter.newItems: 'Новые',
      _MerchantFilter.inWork: 'В работе',
      _MerchantFilter.needsInfo: 'Нужны данные',
      _MerchantFilter.approved: 'Одобрены',
      _MerchantFilter.done: 'Завершены',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: TajGoSpacing.screenH,
        vertical: TajGoSpacing.sm,
      ),
      child: Row(
        children: _MerchantFilter.values.map((f) {
          final selected = f == _filter;
          return Padding(
            padding: const EdgeInsets.only(right: TajGoSpacing.sm),
            child: ChoiceChip(
              label: Text(labels[f]!),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f),
              selectedColor: TajGoColors.mint,
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _card(BuildContext context, MerchantApplication a) {
    return MerchantApplicationAdminCard(
      application: a,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              AdminMerchantApplicationDetailsScreen(applicationId: a.id),
        ),
      ),
    );
  }
}

class MerchantApplicationAdminCard extends StatelessWidget {
  const MerchantApplicationAdminCard({
    super.key,
    required this.application,
    required this.onTap,
  });

  final MerchantApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TajGoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(TajGoSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.storeName.isEmpty
                      ? 'Без названия'
                      : application.storeName,
                  style: TajGoTypography.subtitle,
                ),
                const SizedBox(height: TajGoSpacing.xxs),
                Text(
                  '${marketplaceCategoryLabel(application.category)} · '
                  '${application.ownerName.isEmpty ? '—' : application.ownerName}',
                  style: TajGoTypography.caption,
                ),
              ],
            ),
          ),
          TajGoStatusChip(
            label: MerchantStatus.label(application.status),
            tone: _tone(application.status),
          ),
        ],
      ),
    );
  }

  static TajGoStatusTone _tone(String status) => switch (status) {
    MerchantStatus.approved ||
    MerchantStatus.convertedToPartner => TajGoStatusTone.success,
    MerchantStatus.needsInfo => TajGoStatusTone.warning,
    MerchantStatus.rejected ||
    MerchantStatus.withdrawn => TajGoStatusTone.danger,
    _ => TajGoStatusTone.info,
  };
}
