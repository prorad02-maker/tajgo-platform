import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/app_user.dart';
import '../auth/phone_auth_screen.dart';

class IntentSelectionScreen extends StatelessWidget {
  const IntentSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TajGo')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          const Text(
            'Что вы хотите сделать?',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text(
            'Начните с нужного действия — остальное можно изменить позже.',
            style: TextStyle(color: TajGoColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 28),
          _IntentCard(
            icon: Icons.inventory_2_rounded,
            title: 'Заказать доставку',
            subtitle: 'Отправить посылку, документы, еду или покупки',
            onTap: () => _open(context, AppUserRole.customer),
          ),
          const SizedBox(height: 14),
          _IntentCard(
            icon: Icons.delivery_dining_rounded,
            title: 'Зарабатывать с TajGo',
            subtitle: 'Принимать заказы и доставлять по городу',
            onTap: () => _open(context, AppUserRole.courier),
          ),
        ],
      ),
    ),
  );

  void _open(BuildContext context, String intent) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhoneAuthScreen(initialIntent: intent),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({
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
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 29,
              backgroundColor: TajGoColors.mint,
              child: Icon(icon, color: TajGoColors.darkGreen, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
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
