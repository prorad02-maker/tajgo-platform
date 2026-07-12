import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';

/// Баннер «Курьер найден!» — показывается родителем на несколько секунд
/// при переходе заказа в accepted.
class TajGoCourierBanner extends StatelessWidget {
  const TajGoCourierBanner({super.key, required this.name, this.rating});

  final String name;
  final double? rating;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    elevation: 8,
    shadowColor: const Color(0x33123D1F),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: TajGoColors.mint,
            child: Text('🚴', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Курьер найден!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              Text(
                rating == null ? name : '$name · ⭐ $rating',
                style: const TextStyle(color: TajGoColors.muted, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
