import 'package:flutter/material.dart';

import '../../core/models/marketplace_partner.dart';
import '../../core/models/merchant_application.dart';
import '../../core/services/authoritative_command_service.dart';
import '../../shared/design/tajgo_components.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'widgets/admin_access_gate.dart';

/// Детали заявки магазина + действия администратора (через Functions).
class AdminMerchantApplicationDetailsScreen extends StatefulWidget {
  const AdminMerchantApplicationDetailsScreen({
    super.key,
    required this.applicationId,
  });

  final String applicationId;

  @override
  State<AdminMerchantApplicationDetailsScreen> createState() =>
      _AdminMerchantApplicationDetailsScreenState();
}

class _AdminMerchantApplicationDetailsScreenState
    extends State<AdminMerchantApplicationDetailsScreen> {
  bool _busy = false;

  Future<void> _review(String action, {bool needMessage = false}) async {
    String? message;
    if (needMessage) {
      message = await _askMessage(
        action == 'reject' ? 'Причина отклонения' : 'Что уточнить',
      );
      if (message == null) return;
    }
    await _run(
      () => TajGoScope.of(context).merchantApplicationRepository.review(
        applicationId: widget.applicationId,
        action: action,
        message: message,
      ),
    );
  }

  Future<void> _convert() async {
    final ok = await showTajGoConfirmation(
      context: context,
      title: 'Создать магазин?',
      message:
          'Будет создан неопубликованный черновик партнёра. Опубликовать его '
          'можно в разделе «Партнёры и товары».',
      confirmLabel: 'Создать',
    );
    if (!ok) return;
    await _run(
      () => TajGoScope.of(
        context,
      ).merchantApplicationRepository.convert(widget.applicationId),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on TajGoCommandException catch (error) {
      _snack(error.message);
    } catch (_) {
      _snack('Не удалось выполнить действие. Повторите.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askMessage(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Сообщение заявителю'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
    controller.dispose();
    return (result == null || result.isEmpty) ? null : result;
  }

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = TajGoScope.of(context).merchantApplicationRepository;
    return AdminAccessGate(
      child: TajGoScaffold(
        appBar: const TajGoAppBar(title: 'Заявка магазина'),
        body: StreamBuilder<MerchantApplication?>(
          stream: repo.applicationStream(widget.applicationId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final a = snapshot.data;
            if (a == null) {
              return const TajGoEmptyState(
                icon: Icons.help_outline_rounded,
                title: 'Заявка не найдена',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(TajGoSpacing.lg),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.storeName.isEmpty ? 'Без названия' : a.storeName,
                        style: TajGoTypography.title,
                      ),
                    ),
                    TajGoStatusChip(
                      label: MerchantStatus.label(a.status),
                      tone: _tone(a.status),
                    ),
                  ],
                ),
                const SizedBox(height: TajGoSpacing.md),
                TajGoCard(
                  padding: const EdgeInsets.all(TajGoSpacing.lg),
                  child: Column(
                    children: [
                      _row('Категория', marketplaceCategoryLabel(a.category)),
                      _row('Владелец', a.ownerName),
                      _row('Телефон', a.phone),
                      if (a.extraContact.isNotEmpty)
                        _row('Доп. контакт', a.extraContact),
                      _row('Адрес', a.address),
                      if (a.location != null)
                        _row(
                          'Координаты',
                          '${a.location!.latitude.toStringAsFixed(5)}, '
                              '${a.location!.longitude.toStringAsFixed(5)}',
                        ),
                      if (a.workingHours.isNotEmpty)
                        _row('График', a.workingHours),
                      _row('Мин. заказ', TajGoMoney.format(a.minimumOrder)),
                      _row('Доставка', MerchantDeliveryMode.label(a.deliveryMode)),
                      if (a.description.isNotEmpty)
                        _row('Описание', a.description),
                      if (a.comment.isNotEmpty) _row('Комментарий', a.comment),
                      if (a.convertedPartnerId != null)
                        _row('Партнёр', a.convertedPartnerId!),
                    ],
                  ),
                ),
                if (a.adminNote?.isNotEmpty == true) ...[
                  const SizedBox(height: TajGoSpacing.md),
                  Text(
                    'Сообщение заявителю: ${a.adminNote}',
                    style: TajGoTypography.caption,
                  ),
                ],
                const SizedBox(height: TajGoSpacing.lg),
                ..._actions(a),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _actions(MerchantApplication a) {
    final buttons = <Widget>[];
    void add(Widget w) =>
        buttons.addAll([w, const SizedBox(height: TajGoSpacing.sm)]);

    if (a.status == MerchantStatus.submitted) {
      add(TajGoPrimaryButton(
        label: 'Взять в работу',
        loading: _busy,
        onPressed: _busy ? null : () => _review('take'),
      ));
    }
    if (a.status == MerchantStatus.submitted ||
        a.status == MerchantStatus.underReview) {
      add(TajGoPrimaryButton(
        label: 'Одобрить',
        loading: _busy,
        onPressed: _busy ? null : () => _review('approve'),
      ));
      add(TajGoSecondaryButton(
        label: 'Запросить данные',
        onPressed: _busy ? null : () => _review('needsInfo', needMessage: true),
      ));
    }
    if (a.status == MerchantStatus.submitted ||
        a.status == MerchantStatus.underReview ||
        a.status == MerchantStatus.needsInfo) {
      add(TajGoSecondaryButton(
        label: 'Отклонить',
        onPressed: _busy ? null : () => _review('reject', needMessage: true),
      ));
    }
    if (a.status == MerchantStatus.approved) {
      add(TajGoPrimaryButton(
        label: 'Создать магазин (черновик партнёра)',
        icon: Icons.add_business_rounded,
        loading: _busy,
        onPressed: _busy ? null : _convert,
      ));
    }
    return buttons;
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: TajGoSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TajGoTypography.caption),
        ),
        Expanded(
          child: Text(value.isEmpty ? '—' : value, style: TajGoTypography.body),
        ),
      ],
    ),
  );

  static TajGoStatusTone _tone(String status) => switch (status) {
    MerchantStatus.approved ||
    MerchantStatus.convertedToPartner => TajGoStatusTone.success,
    MerchantStatus.needsInfo => TajGoStatusTone.warning,
    MerchantStatus.rejected ||
    MerchantStatus.withdrawn => TajGoStatusTone.danger,
    _ => TajGoStatusTone.info,
  };
}
