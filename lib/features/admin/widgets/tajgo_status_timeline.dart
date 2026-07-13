import 'package:flutter/material.dart';

import '../../../core/constants/tajgo_colors.dart';

class TajGoTimelineEntry {
  const TajGoTimelineEntry(this.label, this.time, {this.details});
  final String label;
  final DateTime time;
  final String? details;
}

class TajGoStatusTimeline extends StatelessWidget {
  const TajGoStatusTimeline({super.key, required this.entries});
  final List<TajGoTimelineEntry> entries;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < entries.length; index++)
        _TimelineRow(
          entry: entries[index],
          isLast: index == entries.length - 1,
        ),
    ],
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.isLast});
  final TajGoTimelineEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: TajGoColors.green,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: TajGoColors.mint)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  _time(entry.time),
                  style: const TextStyle(
                    color: TajGoColors.muted,
                    fontSize: 12,
                  ),
                ),
                if (entry.details != null) Text(entry.details!),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  String _time(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
