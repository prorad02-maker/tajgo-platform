import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/app_user.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../auth/phone_auth_screen.dart';
import '../courier/courier_application_status_screen.dart';
import '../courier/courier_home_screen.dart';
import '../customer/customer_home_screen.dart';

class RoleOnboardingScreen extends StatefulWidget {
  const RoleOnboardingScreen({super.key});

  @override
  State<RoleOnboardingScreen> createState() => _RoleOnboardingScreenState();
}

class _RoleOnboardingScreenState extends State<RoleOnboardingScreen> {
  bool _busy = false;

  Future<void> _select(String role) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final scope = TajGoScope.of(context);
      await scope.rolePreferenceService.save(role);
      final firebaseUser = scope.authService.currentUser;
      if (!mounted) return;
      if (firebaseUser == null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PhoneAuthScreen(initialIntent: role),
          ),
        );
        return;
      }
      await scope.userRepository.completeRoleOnboarding(firebaseUser.uid, role);
      final profile = await scope.userRepository.getUser(firebaseUser.uid);
      if (!mounted) return;
      final target = role == AppUserRole.customer
          ? const CustomerHomeScreen()
          : profile?.canUseCourierMode == true
          ? const CourierHomeScreen()
          : CourierApplicationStatusScreen(
              status: profile?.courierStatus ?? CourierStatus.draft,
            );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => target),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить выбор. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TajGo')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 14),
          const Text(
            'Как вы хотите использовать TajGo?',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          const Text(
            'Выберите основной режим. Позже его можно изменить в настройках.',
            style: TextStyle(color: TajGoColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 26),
          _RoleCard(
            icon: Icons.inventory_2_rounded,
            title: 'Я клиент',
            subtitle: 'Заказывайте доставку, еду, продукты и цветы.',
            buttonLabel: 'Продолжить как клиент',
            busy: _busy,
            onPressed: () => _select(AppUserRole.customer),
          ),
          const SizedBox(height: 14),
          _RoleCard(
            icon: Icons.delivery_dining_rounded,
            title: 'Я курьер',
            subtitle: 'Получайте заказы рядом и зарабатывайте в удобное время.',
            buttonLabel: 'Продолжить как курьер',
            busy: _busy,
            onPressed: () => _select(AppUserRole.courier),
          ),
          const SizedBox(height: 18),
          const Text(
            'Режим администратора назначается владельцем TajGo и здесь не отображается.',
            textAlign: TextAlign.center,
            style: TextStyle(color: TajGoColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: TajGoColors.mint,
            child: Icon(icon, color: TajGoColors.darkGreen, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: TajGoColors.muted)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onPressed,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    ),
  );
}
