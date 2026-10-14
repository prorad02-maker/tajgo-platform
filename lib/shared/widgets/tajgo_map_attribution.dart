import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

class TajGoMapAttribution extends StatelessWidget {
  const TajGoMapAttribution({super.key});
  Future<void> _open(BuildContext context, String url) async {
    try {
      if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      /* Show the same useful error for missing browsers. */
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть ссылку. Проверьте интернет.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => RichAttributionWidget(
    attributions: [
      TextSourceAttribution(
        '© OpenStreetMap contributors',
        onTap: () => _open(context, 'https://www.openstreetmap.org/copyright'),
      ),
      TextSourceAttribution(
        'Исправить карту',
        onTap: () => _open(context, 'https://www.openstreetmap.org/fixthemap'),
      ),
      TextSourceAttribution(
        'Маршруты: FOSSGIS / OSRM',
        onTap: () =>
            _open(context, 'https://routing.openstreetmap.de/about.html'),
      ),
    ],
  );
}
