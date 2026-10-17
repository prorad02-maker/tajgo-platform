import 'package:flutter/material.dart';
import '../../core/constants/tajgo_colors.dart';

/// A code is only shown to the customer, at the handoff step.
class TajGoConfirmationCode extends StatelessWidget {
  const TajGoConfirmationCode({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          for (var index = 0; index < code.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: TajGoColors.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  code[index],
                  style: const TextStyle(
                    color: TajGoColors.deepGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 10),
      const Text(
        'Назовите этот код курьеру при получении',
        style: TextStyle(color: TajGoColors.muted, fontSize: 13),
      ),
    ],
  );
}
