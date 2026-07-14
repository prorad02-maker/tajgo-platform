import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/app_user.dart';
import '../../core/models/courier_application.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../customer/customer_home_screen.dart';
import 'application/become_courier_screen.dart';
import 'application/courier_application_flow_screen.dart';
import 'courier_home_screen.dart';
import 'courier_onboarding_screen.dart';

class CourierApplicationStatusScreen extends StatelessWidget {
  const CourierApplicationStatusScreen({super.key, this.status = 'draft'});
  final String status;

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser!.uid;
    return StreamBuilder<CourierApplication?>(
      stream: scope.courierApplicationRepository.applicationStream(uid),
      builder: (context, appSnapshot) => FutureBuilder<AppUser?>(
        future: scope.userRepository.getUser(uid),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData &&
              userSnapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = userSnapshot.data;
          final application = appSnapshot.data;
          final currentStatus =
              application?.status ?? user?.courierStatus ?? status;
          final content = _content(currentStatus, application);
          return Scaffold(
            appBar: AppBar(title: const Text('Зарабатывать с TajGo')),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 28),
                  Icon(content.icon, size: 76, color: TajGoColors.darkGreen),
                  const SizedBox(height: 20),
                  Text(
                    content.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (content.reason != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: TajGoColors.soonBg,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Причина: ${content.reason}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () =>
                        _primary(context, currentStatus, user, application),
                    child: Text(content.action),
                  ),
                  if (currentStatus == CourierStatus.pending &&
                      application != null)
                    TextButton(
                      onPressed: () => _showApplication(context, application),
                      child: const Text('Мои данные'),
                    ),
                  if (currentStatus != CourierStatus.pending &&
                      currentStatus != CourierStatus.suspended)
                    TextButton(
                      onPressed: () => _customer(context),
                      child: Text(
                        currentStatus == CourierStatus.approved
                            ? 'Пока остаться в режиме клиента'
                            : 'Перейти в режим клиента',
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  _StatusContent _content(
    String currentStatus,
    CourierApplication? application,
  ) => switch (currentStatus) {
    CourierStatus.pending => const _StatusContent(
      icon: Icons.hourglass_top_rounded,
      title: 'Заявка на проверке 🕐',
      message:
          'Мы проверяем данные — обычно это быстро. Пока вы можете пользоваться TajGo как клиент.',
      action: 'Перейти в режим клиента',
    ),
    CourierStatus.approved => const _StatusContent(
      icon: Icons.celebration_rounded,
      title: 'Вы приняты! 🎉',
      message:
          'Курьерский режим открыт. Осталось короткое знакомство — около минуты.',
      action: 'Открыть режим курьера',
    ),
    CourierStatus.rejected => _StatusContent(
      icon: Icons.edit_note_rounded,
      title: 'Нужно исправить данные',
      message: 'Исправьте анкету и отправьте снова — мы посмотрим ещё раз.',
      reason: application?.rejectionReason ?? 'Причина не указана',
      action: 'Исправить и отправить снова',
    ),
    CourierStatus.suspended => _StatusContent(
      icon: Icons.pause_circle_outline_rounded,
      title: 'Курьерский режим приостановлен',
      message:
          'Вы не можете выходить на линию, но клиентский режим и заказы сохранены. Свяжитесь с поддержкой TajGo.',
      reason: application?.suspensionReason ?? 'Уточните у поддержки',
      action: 'Перейти в режим клиента',
    ),
    _ => _StatusContent(
      icon: Icons.assignment_rounded,
      title: application == null
          ? 'Станьте курьером TajGo'
          : 'Продолжите анкету',
      message: application == null
          ? 'Свободный график, маршруты в приложении и понятный доход.'
          : 'Черновик сохранён. Продолжите с места, где остановились.',
      action: application == null ? 'Узнать подробнее' : 'Продолжить анкету',
    ),
  };

  Future<void> _primary(
    BuildContext context,
    String currentStatus,
    AppUser? user,
    CourierApplication? application,
  ) async {
    if (currentStatus == CourierStatus.pending ||
        currentStatus == CourierStatus.suspended) {
      _customer(context);
      return;
    }
    if (currentStatus == CourierStatus.approved) {
      if (user?.courierOnboardingCompleted != true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const CourierOnboardingScreen(),
          ),
        );
      } else {
        await TajGoScope.of(context).accountModeService.switchToCourier();
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const CourierHomeScreen()),
          (_) => false,
        );
      }
      return;
    }
    if (currentStatus == CourierStatus.rejected && application != null) {
      try {
        await TajGoScope.of(
          context,
        ).courierApplicationRepository.reopenRejected(application.uid);
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error is StateError ? error.message : '$error'),
          ),
        );
        return;
      }
    }
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => application == null
            ? const BecomeCourierScreen()
            : CourierApplicationFlowScreen(
                initialApplication: CourierApplication.fromMap({
                  ...application.toDraftMap(),
                  'history': application.history,
                  'rejectionReason': application.rejectionReason,
                }, uid: application.uid),
              ),
      ),
    );
  }

  void _customer(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const CustomerHomeScreen()),
      (_) => false,
    );
  }

  void _showApplication(BuildContext context, CourierApplication application) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Отправленная анкета',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          ListTile(
            title: const Text('Имя'),
            subtitle: Text(application.displayName),
          ),
          ListTile(
            title: const Text('Телефон'),
            subtitle: Text(application.phoneNumber ?? '—'),
          ),
          ListTile(
            title: const Text('Транспорт'),
            subtitle: Text(CourierTransport.label(application.transport)),
          ),
          ListTile(
            title: const Text('Документ'),
            subtitle: Text(
              '${CourierDocumentType.label(application.documentType)} · ${application.documentNumber}',
            ),
          ),
          ListTile(
            title: const Text('Зона'),
            subtitle: Text('${application.city} · ${application.workDistrict}'),
          ),
          ListTile(
            title: const Text('Фото'),
            subtitle: Text(
              application.verificationMethod == 'personalMeeting'
                  ? 'Проверка при личной встрече'
                  : 'Storage upload',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusContent {
  const _StatusContent({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    this.reason,
  });
  final IconData icon;
  final String title;
  final String message;
  final String action;
  final String? reason;
}
