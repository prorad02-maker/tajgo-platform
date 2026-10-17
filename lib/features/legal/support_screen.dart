import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal/legal_documents.dart';
import '../../shared/design/tajgo_components.dart';

/// Экран поддержки: как получить помощь, частые вопросы, контакт.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const List<(String, String)> _faq = [
    (
      'Как отправить посылку?',
      'На главной нажмите «Отправить посылку», укажите точки A и B, назначьте '
          'цену и опубликуйте заказ. Курьеры предложат свои условия.',
    ),
    (
      'Как отследить заказ?',
      'Откройте вкладку «Заказы» или карточку активного заказа — там статус, '
          'курьер на карте и код получения.',
    ),
    (
      'Что такое код получения?',
      'Это код, который вы называете курьеру при передаче заказа. Курьер его не '
          'видит — так подтверждается доставка именно вам.',
    ),
    (
      'Как стать курьером?',
      'В профиле выберите «Зарабатывать с TajGo» и заполните заявку. После '
          'проверки администратором откроется режим курьера.',
    ),
  ];

  Future<void> _email(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: LegalDocuments.supportEmail,
      query: 'subject=Поддержка TajGo',
    );
    final ok = await canLaunchUrl(uri) && await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Напишите нам: ${LegalDocuments.supportEmail}')),
      );
    }
  }

  Future<void> _openSupportPage() => launchUrl(
    Uri.parse(LegalDocuments.supportUrl),
    mode: LaunchMode.externalApplication,
  );

  @override
  Widget build(BuildContext context) {
    return TajGoScaffold(
      appBar: const TajGoAppBar(title: 'Поддержка'),
      body: ListView(
        padding: const EdgeInsets.all(TajGoSpacing.lg),
        children: [
          TajGoCard(
            padding: const EdgeInsets.all(TajGoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Нужна помощь?', style: TajGoTypography.subtitle),
                const SizedBox(height: TajGoSpacing.xs),
                Text(
                  'Напишите нам — ответим и поможем с заказом, оплатой или '
                  'аккаунтом.',
                  style: TajGoTypography.body,
                ),
                const SizedBox(height: TajGoSpacing.md),
                TajGoPrimaryButton(
                  label: 'Написать в поддержку',
                  icon: Icons.mail_outline_rounded,
                  expand: false,
                  onPressed: () => _email(context),
                ),
                const SizedBox(height: TajGoSpacing.sm),
                TextButton.icon(
                  onPressed: _openSupportPage,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Открыть tajgo.ru/support'),
                ),
              ],
            ),
          ),
          const TajGoSectionHeader(title: 'Частые вопросы'),
          ..._faq.map(
            (item) => TajGoCard(
              margin: const EdgeInsets.symmetric(
                horizontal: 0,
                vertical: TajGoSpacing.xs,
              ),
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                shape: const Border(),
                title: Text(item.$1, style: TajGoTypography.bodyStrong),
                childrenPadding: const EdgeInsets.fromLTRB(
                  TajGoSpacing.lg,
                  0,
                  TajGoSpacing.lg,
                  TajGoSpacing.lg,
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(item.$2, style: TajGoTypography.body),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
