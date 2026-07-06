import 'package:flutter/material.dart';

import '../core/theme/tajgo_colors.dart';
import '../widgets/role_card.dart';
import 'courier_screen.dart';
import 'info_screen.dart';

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите роль')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'TajGo+ подстроится под вашу задачу.',
            style: TextStyle(
              color: TajGoColors.ink,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Начинаем с Худжанда и постепенно расширяемся по Таджикистану.',
            style: TextStyle(color: TajGoColors.muted, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 24),
          RoleCard(
            icon: Icons.person_rounded,
            title: 'Клиент',
            subtitle: 'Заказать доставку документов, еды или посылки',
            color: TajGoColors.green,
            onTap: () => _openInfo(
              context,
              'Клиент',
              'Скоро здесь будет создание заказа по Худжанду.',
            ),
          ),
          const SizedBox(height: 14),
          RoleCard(
            icon: Icons.electric_bike_rounded,
            title: 'Курьер',
            subtitle: 'Выйти на линию пешком или на электробайке',
            color: TajGoColors.darkGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CourierScreen()),
              );
            },
          ),
          const SizedBox(height: 14),
          RoleCard(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Админ',
            subtitle: 'Проверять курьеров, документы и заказы',
            color: TajGoColors.gold,
            onTap: () => _openInfo(
              context,
              'Админ',
              'Скоро здесь будет панель управления TajGo+.',
            ),
          ),
        ],
      ),
    );
  }

  void _openInfo(BuildContext context, String title, String text) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InfoScreen(title: title, text: text)),
    );
  }
}
