import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../courier/courier_home_screen.dart';
import '../customer/customer_home_screen.dart';

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
