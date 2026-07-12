import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';

class TajGoOrderProgress extends StatelessWidget {
  const TajGoOrderProgress({
    super.key,
    required this.currentStep,
    this.labels = const [
      'Принят',
      'На месте',
      'Забрал',
      'Доставляю',
      'Доставлено',
    ],
  });

  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(labels.length, (index) {
      final reached = index <= currentStep;
      final current = index == currentStep;
      return Expanded(
        child: Column(
          children: [
            Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: reached
                          ? TajGoColors.green
                          : const Color(0xFFD8E5D3),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: current ? 18 : 14,
                  height: current ? 18 : 14,
                  decoration: BoxDecoration(
                    color: reached
                        ? TajGoColors.green
                        : const Color(0xFFD8E5D3),
                    shape: BoxShape.circle,
                    border: current
                        ? Border.all(color: TajGoColors.mint, width: 4)
                        : null,
                  ),
                ),
                if (index < labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index < currentStep
                          ? TajGoColors.green
                          : const Color(0xFFD8E5D3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              labels[index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: reached ? TajGoColors.darkGreen : TajGoColors.muted,
                fontSize: 9,
                fontWeight: current ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }),
  );
}
