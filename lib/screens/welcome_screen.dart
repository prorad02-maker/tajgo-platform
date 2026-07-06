import 'package:flutter/material.dart';

import '../core/theme/tajgo_colors.dart';
import '../widgets/tajgo_badge.dart';
import 'role_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TajGoColors.green,
              TajGoColors.darkGreen,
              TajGoColors.softGreen,
            ],
            stops: [0.0, 0.58, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TopPill(
                      icon: Icons.location_on_rounded,
                      text: 'Худжанд',
                    ),
                    _TopPill(
                      icon: Icons.electric_bike_rounded,
                      text: 'Эко-доставка',
                    ),
                  ],
                ),
                const Spacer(),
                const TajGoBadge(size: 132),
                const SizedBox(height: 28),
                const Text(
                  'TajGo+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Доставка по Худжанду\nбыстрее, проще и честнее',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                const _ServicesPanel(),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: TajGoColors.green,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RoleScreen()),
                    );
                  },
                  child: const Text('Начать'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Первый запуск: город Худжанд',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesPanel extends StatelessWidget {
  const _ServicesPanel();

  @override
  Widget build(BuildContext context) {
    final services = [
      ('📄', 'Документы'),
      ('📦', 'Посылки'),
      ('🍔', 'Еда'),
      ('🛒', 'Покупки'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: services.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${item.$1} ${item.$2}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
