import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';

/// Код подтверждения получения: 4 цифры в отдельных ячейках + подсказка.
class TajGoConfirmationCode extends StatelessWidget {
  const TajGoConfirmationCode({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: code
            .split('')
            .map(
              (digit) => Container(
                width: 46,
                height: 54,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: TajGoColors.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  digit,
                  style: const TextStyle(
                    color: TajGoColors.darkGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 8),
      const Text(
        'Назовите этот код курьеру при получении',
        style: TextStyle(color: TajGoColors.muted, fontSize: 13),
      ),
    ],
  );
}
