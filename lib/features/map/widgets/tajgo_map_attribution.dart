import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/tajgo_colors.dart';

class TajGoMapAttribution extends StatelessWidget {
  const TajGoMapAttribution({
    super.key,
    this.alignment = Alignment.bottomRight,
  });
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: SafeArea(
      minimum: const EdgeInsets.all(4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Material(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: () async {
              try {
                await launchUrl(
                  Uri.https('www.openstreetmap.org', '/copyright'),
                );
              } catch (_) {}
            },
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 10,
                  color: TajGoColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
