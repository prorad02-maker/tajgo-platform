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
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final step = currentStep.clamp(0, labels.length - 1);
    return Semantics(
      label: 'Этап ${step + 1} из ${labels.length}: ${labels[step]}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              labels.length,
              (index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == labels.length - 1 ? 0 : 5,
                  ),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= step
                          ? TajGoColors.darkGreen
                          : const Color(0xFFE0E9E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${step + 1} / ${labels.length}  ·  ${labels[step]}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: TajGoColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
