import 'dart:async';

import 'package:flutter/material.dart';

/// Bounds the initial tile wait while keeping the map and address controls usable.
/// The map removes this widget as soon as its first real tile has loaded.
class TajGoMapLoadingStatus extends StatefulWidget {
  const TajGoMapLoadingStatus({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  State<TajGoMapLoadingStatus> createState() => _TajGoMapLoadingStatusState();
}

class _TajGoMapLoadingStatusState extends State<TajGoMapLoadingStatus> {
  Timer? _timeout;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _unavailable = true);
    });
  }

  void _retry() {
    setState(() => _unavailable = false);
    _startTimeout();
    widget.onRetry();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_unavailable)
                  const Icon(Icons.wifi_off_rounded, size: 20)
                else
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _unavailable ? 'Карта недоступна' : 'Загружаем карту…',
                  ),
                ),
              ],
            ),
            if (_unavailable)
              TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
          ],
        ),
      ),
    ),
  );
}
