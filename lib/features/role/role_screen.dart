import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../auth/phone_auth_screen.dart';
import '../courier/courier_home_screen.dart';
import '../customer/customer_home_screen.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  bool _phonePromptScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = TajGoScope.of(context).authService.currentUser;
    if (_phonePromptScheduled || user?.isAnonymous != true) {
      return;
    }
    _phonePromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPhoneAuth());
  }

  Future<void> _openPhoneAuth() async {
    if (!mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PhoneAuthScreen()));
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = TajGoScope.of(context).authService.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('TajGo+')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Выберите режим',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'В демоверсии можно проверить клиентский и курьерский сценарии.',
            style: TextStyle(color: TajGoColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 24),
          if (user?.isAnonymous == true) ...[
            Card(
              color: TajGoColors.mint,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: TajGoColors.darkGreen,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Защитите профиль входом по телефону',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: _openPhoneAuth,
                      child: const Text('Войти'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ] else if (user?.phoneNumber != null) ...[
            Text(
              'Вы вошли как ${user!.phoneNumber}',
              style: const TextStyle(
                color: TajGoColors.darkGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
          ],
          _RoleTile(
            icon: Icons.person_rounded,
            title: 'Клиент',
            subtitle: 'Создать доставку на карте и следить за заказом',
            onTap: () => _open(context, const CustomerHomeScreen()),
          ),
          const SizedBox(height: 14),
          _RoleTile(
            icon: Icons.electric_bike_rounded,
            title: 'Курьер',
            subtitle: 'Выйти на линию, принять и выполнить заказ',
            onTap: () => _open(context, const CourierHomeScreen()),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: TajGoColors.green.withValues(alpha: 0.12),
                child: Icon(icon, color: TajGoColors.green, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: TajGoColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
