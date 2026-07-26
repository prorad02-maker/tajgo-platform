import 'package:flutter/material.dart';

import '../../core/models/merchant_application.dart';
import '../../shared/design/tajgo_components.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'merchant_application_form_screen.dart';

/// Точка входа «Подключить свой магазин»: показывает статус заявки или форму.
class MerchantApplicationScreen extends StatelessWidget {
  const MerchantApplicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser!.uid;
    return TajGoScaffold(
      appBar: const TajGoAppBar(title: 'Мой магазин'),
      body: StreamBuilder<MerchantApplication?>(
        stream: scope.merchantApplicationRepository.myApplicationStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final application = snapshot.data;
          if (application == null) {
            return _IntroView(onStart: () => _openForm(context));
          }
          return _StatusView(application: application);
        },
      ),
    );
  }

  static void _openForm(BuildContext context, {MerchantApplication? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MerchantApplicationFormScreen(existing: existing),
      ),
    );
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TajGoSpacing.lg),
      children: [
        TajGoCard(
          padding: const EdgeInsets.all(TajGoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.storefront_rounded,
                color: TajGoColors.green,
                size: TajGoIconSizes.hero,
              ),
              const SizedBox(height: TajGoSpacing.md),
              Text('Подключите свой магазин', style: TajGoTypography.title),
              const SizedBox(height: TajGoSpacing.sm),
              Text(
                'Продавайте еду, продукты или цветы через TajGo. Заполните '
                'заявку — мы проверим её и свяжемся с вами.',
                style: TajGoTypography.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: TajGoSpacing.lg),
        TajGoPrimaryButton(label: 'Заполнить заявку', onPressed: onStart),
      ],
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.application});
  final MerchantApplication application;

  TajGoStatusTone get _tone => switch (application.status) {
    MerchantStatus.approved ||
    MerchantStatus.convertedToPartner => TajGoStatusTone.success,
    MerchantStatus.needsInfo => TajGoStatusTone.warning,
    MerchantStatus.rejected ||
    MerchantStatus.withdrawn => TajGoStatusTone.danger,
    _ => TajGoStatusTone.info,
  };

  Future<void> _withdraw(BuildContext context) async {
    final ok = await showTajGoConfirmation(
      context: context,
      title: 'Отозвать заявку?',
      message: 'Вы сможете подать её заново позже.',
      confirmLabel: 'Отозвать',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await TajGoScope.of(context).merchantApplicationRepository.withdraw();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отозвать. Повторите.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResubmit = application.status == MerchantStatus.rejected ||
        application.status == MerchantStatus.withdrawn;
    return ListView(
      padding: const EdgeInsets.all(TajGoSpacing.lg),
      children: [
        TajGoCard(
          padding: const EdgeInsets.all(TajGoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      application.storeName.isEmpty
                          ? 'Заявка магазина'
                          : application.storeName,
                      style: TajGoTypography.title,
                    ),
                  ),
                  TajGoStatusChip(
                    label: MerchantStatus.label(application.status),
                    tone: _tone,
                  ),
                ],
              ),
              const SizedBox(height: TajGoSpacing.sm),
              Text(
                _statusHint(application.status),
                style: TajGoTypography.body,
              ),
              if (application.adminNote?.isNotEmpty == true) ...[
                const SizedBox(height: TajGoSpacing.md),
                Container(
                  padding: const EdgeInsets.all(TajGoSpacing.md),
                  decoration: BoxDecoration(
                    color: TajGoColors.soonBg,
                    borderRadius: TajGoRadius.smAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: TajGoIconSizes.md, color: TajGoColors.muted),
                      const SizedBox(width: TajGoSpacing.sm),
                      Expanded(
                        child: Text(
                          application.adminNote!,
                          style: TajGoTypography.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: TajGoSpacing.lg),
        if (application.needsInfo)
          TajGoPrimaryButton(
            label: 'Обновить заявку',
            onPressed: () => MerchantApplicationScreen._openForm(
              context,
              existing: application,
            ),
          )
        else if (application.status == MerchantStatus.draft)
          TajGoPrimaryButton(
            label: 'Продолжить заполнение',
            onPressed: () => MerchantApplicationScreen._openForm(
              context,
              existing: application,
            ),
          )
        else if (canResubmit)
          TajGoPrimaryButton(
            label: 'Подать заявку заново',
            onPressed: () => MerchantApplicationScreen._openForm(context),
          ),
        if (application.canWithdraw) ...[
          const SizedBox(height: TajGoSpacing.sm),
          TajGoSecondaryButton(
            label: 'Отозвать заявку',
            onPressed: () => _withdraw(context),
          ),
        ],
      ],
    );
  }

  static String _statusHint(String status) => switch (status) {
    MerchantStatus.draft => 'Черновик сохранён. Завершите и отправьте заявку.',
    MerchantStatus.submitted => 'Заявка отправлена. Мы скоро её рассмотрим.',
    MerchantStatus.underReview => 'Заявка на рассмотрении администратором.',
    MerchantStatus.needsInfo => 'Нужны уточнения — обновите заявку.',
    MerchantStatus.approved => 'Заявка одобрена. Скоро подключим магазин.',
    MerchantStatus.rejected => 'Заявка отклонена. Можно подать заново.',
    MerchantStatus.convertedToPartner => 'Магазин подключён к TajGo.',
    MerchantStatus.withdrawn => 'Заявка отозвана. Можно подать заново.',
    _ => '',
  };
}
