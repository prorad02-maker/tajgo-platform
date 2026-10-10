import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/tajgo_colors.dart';

Future<void> _openLink(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Не удалось открыть ссылку. Попробуйте позже.'),
      ),
    );
  }
}

Uri? _httpsLink(String value) {
  final uri = Uri.tryParse(value);
  return uri?.scheme == 'https' && uri!.host.isNotEmpty && uri.userInfo.isEmpty
      ? uri
      : null;
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final support = _httpsLink(
      const String.fromEnvironment('TAJGO_SUPPORT_URL'),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Помощь')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InfoHeader(
            icon: Icons.help_outline_rounded,
            title: 'Поможем разобраться',
            message:
                'Ответы на частые вопросы о заказах, адресах и работе курьера.',
          ),
          const SizedBox(height: 16),
          const _Answer(
            title: 'Как правильно выбрать адрес?',
            message:
                'Найдите улицу или место через поиск, проверьте точку на карте и подтвердите её. Кнопка редактирования позволяет добавить номер дома, подъезд или ориентир, сохранив выбранные координаты.',
          ),
          const _Answer(
            title: 'Почему маршрут показан пунктиром?',
            message:
                'Дорожный маршрут временно недоступен. Пунктир показывает предварительное направление; расстояние и время приблизительные. Курьер может открыть адрес в выбранном навигаторе.',
          ),
          const _Answer(
            title: 'Как отменить заказ?',
            message:
                'Откройте активный заказ. Отмена доступна, пока курьер не выбран. Если курьер уже принят, используйте поддержку, когда её контакт доступен ниже.',
          ),
          const _Answer(
            title: 'Кому сообщать код получения?',
            message:
                'Сообщите четырёхзначный код назначенному курьеру после получения заказа. До передачи посылки код сообщать не нужно.',
          ),
          const _Answer(
            title: 'Заказ отмечен доставленным, но я его не получил',
            message:
                'Откройте заказ и нажмите «Не получил». Заказ перейдёт в спорный статус для проверки администратором.',
          ),
          const _Answer(
            title: 'Курьер не может отправить предложение',
            message:
                'Проверьте одобрение аккаунта и включите режим «На линии». Геолокация должна быть свежей и точной; точка забора должна находиться ближе одного километра. Сначала завершите другой активный заказ.',
          ),
          if (support != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openLink(context, support),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('Связаться с поддержкой'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Describes implemented data flows. The owner's official policy is a separate
/// configured document rather than invented legal text inside the application.
class PrivacyInfoScreen extends StatelessWidget {
  const PrivacyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final policy = _httpsLink(
      const String.fromEnvironment('TAJGO_PRIVACY_POLICY_URL'),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Данные и конфиденциальность')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InfoHeader(
            icon: Icons.privacy_tip_outlined,
            title: 'Ваши данные в TajGo',
            message:
                'Какие данные используются при входе, заказе и работе курьера.',
          ),
          const SizedBox(height: 16),
          const _Answer(
            title: 'Номер телефона и имя',
            message:
                'Номер используется для входа через Firebase Authentication. Имя сохраняется в профиле и заказе.',
          ),
          const _Answer(
            title: 'Адреса и координаты',
            message:
                'Выбранные адреса и координаты сохраняются в заказе для доставки. При построении дорожного маршрута координаты передаются настроенному сервису маршрутов. Подложка карты загружается с OpenStreetMap.',
          ),
          const _Answer(
            title: 'Местоположение курьера',
            message:
                'В режиме «На линии» приложение публикует местоположение курьера для карты и отслеживания доставки. Разрешение на геолокацию управляется в настройках телефона.',
          ),
          const _Answer(
            title: 'Анкета курьера',
            message:
                'Анкета, номер документа и статус проверки доступны владельцу аккаунта и администратору. Проверка оригиналов документов в текущем процессе проводится при личной встрече.',
          ),
          const _Answer(
            title: 'Избранные и недавние адреса',
            message:
                'Эти адреса хранятся локально на устройстве. Сохранённый адрес можно удалить в разделе «Избранные адреса».',
          ),
          if (policy != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openLink(context, policy),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Политика конфиденциальности'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoHeader extends StatelessWidget {
  const _InfoHeader({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    color: TajGoColors.mint,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36, color: TajGoColors.darkGreen),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    ),
  );
}

class _Answer extends StatelessWidget {
  const _Answer({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(message)],
    ),
  );
}
