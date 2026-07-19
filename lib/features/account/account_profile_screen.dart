import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/app_user.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../courier/courier_application_status_screen.dart';
import '../courier/courier_home_screen.dart';
import '../courier/courier_onboarding_screen.dart';
import '../customer/customer_home_screen.dart';
import '../startup/intent_selection_screen.dart';
import 'settings_screen.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AccountProfileScreen(currentMode: AppUserRole.customer);
}

class CourierProfileScreen extends StatelessWidget {
  const CourierProfileScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AccountProfileScreen(currentMode: AppUserRole.courier);
}

class AccountProfileScreen extends StatelessWidget {
  const AccountProfileScreen({super.key, required this.currentMode});
  final String currentMode;

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final firebaseUser = scope.authService.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: FutureBuilder<AppUser?>(
        future: scope.userRepository.getUser(firebaseUser.uid),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: TajGoColors.mint,
                child: Text(
                  user.displayName.trim().isEmpty
                      ? 'T'
                      : user.displayName.trim().characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: TajGoColors.darkGreen,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                user.phoneNumber ?? 'Тестовый вход · номер не подтверждён',
                textAlign: TextAlign.center,
                style: const TextStyle(color: TajGoColors.muted),
              ),
              if (kDebugMode && !user.phoneVerified)
                const Center(child: Chip(label: Text('Тест · демо-вход'))),
              const SizedBox(height: 16),
              _Tile(
                icon: Icons.swap_horiz_rounded,
                title: currentMode == AppUserRole.courier
                    ? 'Перейти в режим клиента'
                    : user.courierApproved
                    ? 'Перейти в режим курьера'
                    : 'Зарабатывать с TajGo',
                onTap: () => _switchMode(context, user),
              ),
              _Tile(
                icon: Icons.history_rounded,
                title: 'История заказов',
                onTap: () => _soon(context),
              ),
              _Tile(
                icon: Icons.favorite_rounded,
                title: 'Избранные адреса',
                onTap: () => _soon(context),
              ),
              if (currentMode == AppUserRole.courier)
                _Tile(
                  icon: Icons.school_outlined,
                  title: 'Как это работает',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const CourierOnboardingScreen(),
                    ),
                  ),
                ),
              _Tile(
                icon: Icons.settings_rounded,
                title: 'Настройки',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(currentMode: currentMode),
                  ),
                ),
              ),
              _Tile(
                icon: Icons.help_outline_rounded,
                title: 'Помощь',
                onTap: () => _soon(context),
              ),
              _Tile(
                icon: Icons.privacy_tip_outlined,
                title: 'Политика конфиденциальности',
                onTap: () => _soon(context),
              ),
              _Tile(
                icon: Icons.logout_rounded,
                title: 'Выйти',
                onTap: () => _signOut(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _switchMode(BuildContext context, AppUser user) async {
    final scope = TajGoScope.of(context);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Сменить режим?'),
          content: Text(
            currentMode == AppUserRole.courier
                ? 'Перейти в интерфейс клиента?'
                : 'Перейти в интерфейс курьера?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Перейти'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      if (currentMode == AppUserRole.courier) {
        final courier = await scope.courierRepository.getCourier(user.uid);
        if (courier?.activeOrderId != null || courier?.isBusy == true) {
          throw StateError('Сначала завершите текущий заказ.');
        }
        try {
          await scope.courierRepository.setOnline(
            uid: user.uid,
            online: false,
            name: user.displayName,
            city: user.city,
            phoneNumber: user.phoneNumber,
          );
        } catch (_) {}
        await scope.accountModeService.switchToCustomer();
        if (!context.mounted) return;
        _replaceRoot(context, const CustomerHomeScreen());
        return;
      }
      if (await scope.orderRepository.hasActiveOrder(user.uid)) {
        throw StateError('Сначала завершите текущий заказ.');
      }
      if (!context.mounted) return;
      if (!user.courierApproved) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                CourierApplicationStatusScreen(status: user.courierStatus),
          ),
        );
        return;
      }
      if (!user.courierOnboardingCompleted) {
        _replaceRoot(
          context,
          const CourierApplicationStatusScreen(status: 'approved'),
        );
        return;
      }
      await scope.accountModeService.switchToCourier();
      if (context.mounted) _replaceRoot(context, const CourierHomeScreen());
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось переключить режим. Проверьте связь и попробуйте снова.',
          ),
        ),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Заказы сохранятся — войдите этим же номером, чтобы увидеть их снова.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser?.uid;
    if (currentMode == AppUserRole.courier && uid != null) {
      try {
        final profile = await scope.userRepository.getUser(uid);
        await scope.courierRepository.setOnline(
          uid: uid,
          online: false,
          name: profile?.displayName ?? 'Курьер',
          city: profile?.city ?? 'Худжанд',
          phoneNumber: profile?.phoneNumber,
        );
      } catch (_) {}
    }
    await scope.authService.signOut();
    if (context.mounted) _replaceRoot(context, const IntentSelectionScreen());
  }

  void _replaceRoot(BuildContext context, Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => screen),
      (_) => false,
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Раздел готовится к пилоту TajGo.')),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: TajGoColors.darkGreen),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
