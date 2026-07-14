import 'package:flutter/material.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/courier_application.dart';
import '../../../shared/widgets/tajgo_scope.dart';
import 'courier_application_flow_screen.dart';

class BecomeCourierScreen extends StatelessWidget {
  const BecomeCourierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Стать курьером')),
      body: FutureBuilder(
        future: Future.wait([
          scope.userRepository.getUser(uid),
          scope.courierApplicationRepository.get(uid),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data![0] as AppUser?;
          final application = snapshot.data![1] as CourierApplication?;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(
                Icons.delivery_dining_rounded,
                size: 82,
                color: TajGoColors.darkGreen,
              ),
              const SizedBox(height: 18),
              const Text(
                'Зарабатывайте с TajGo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 22),
              const _Benefit(
                icon: Icons.schedule_rounded,
                text: 'Свободный график — выходите на линию, когда удобно',
              ),
              const _Benefit(
                icon: Icons.map_rounded,
                text: 'Маршруты и навигация прямо в приложении',
              ),
              const _Benefit(
                icon: Icons.payments_rounded,
                text: 'Доход за заказ виден до того, как вы его приняли',
              ),
              const _Benefit(
                icon: Icons.verified_user_rounded,
                text: 'Короткая проверка — для безопасности и репутации',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: user == null
                    ? null
                    : () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => CourierApplicationFlowScreen(
                            initialApplication:
                                application ??
                                CourierApplication.empty(
                                  uid: uid,
                                  displayName: user.displayName,
                                  phoneNumber: user.phoneNumber,
                                ),
                          ),
                        ),
                      ),
                child: Text(
                  application == null
                      ? 'Заполнить анкету — 3 минуты'
                      : 'Продолжить анкету',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'До одобрения вы продолжаете пользоваться TajGo как клиент.',
                textAlign: TextAlign.center,
                style: TextStyle(color: TajGoColors.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: TajGoColors.mint,
        child: Icon(icon, color: TajGoColors.darkGreen),
      ),
      title: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}
