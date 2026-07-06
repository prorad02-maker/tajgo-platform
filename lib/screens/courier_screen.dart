import 'package:flutter/material.dart';

import '../core/theme/tajgo_colors.dart';
import '../widgets/action_tile.dart';
import '../widgets/stat_card.dart';

class CourierScreen extends StatelessWidget {
  const CourierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TajGo+ Курьер')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _CourierHero(),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatCard(title: 'Заказы', value: '0')),
              SizedBox(width: 12),
              Expanded(child: StatCard(title: 'Доход', value: '0 TJS')),
            ],
          ),
          SizedBox(height: 16),
          ActionTile(
            icon: Icons.verified_user_rounded,
            title: 'Проверка курьера',
            subtitle: 'Паспорт, селфи и фото электробайка',
          ),
          ActionTile(
            icon: Icons.radio_button_checked_rounded,
            title: 'Выйти на линию',
            subtitle: 'Будет доступно после проверки документов',
          ),
          ActionTile(
            icon: Icons.battery_charging_full_rounded,
            title: 'Электробайк',
            subtitle: 'Позже учтём заряд и запас хода',
          ),
          ActionTile(
            icon: Icons.route_rounded,
            title: 'Маршрут',
            subtitle: 'Скоро подключим карту и адреса Худжанда',
          ),
        ],
      ),
    );
  }
}

class _CourierHero extends StatelessWidget {
  const _CourierHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TajGoColors.green, TajGoColors.darkGreen],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📍 Худжанд', style: TextStyle(color: Colors.white70, fontSize: 16)),
          SizedBox(height: 8),
          Text(
            'Готов выйти на линию?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'TajGo+ начинает с пеших курьеров и электробайков. Это дешевле машины и лучше подходит для коротких доставок по городу.',
            style: TextStyle(color: Colors.white, fontSize: 15, height: 1.42),
          ),
        ],
      ),
    );
  }
}
