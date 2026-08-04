class MapProviderConfig {
  const MapProviderConfig({
    required this.tileUrlTemplate,
    required this.attribution,
    required this.userAgentPackageName,
    required this.pilotOnly,
  });

  final String tileUrlTemplate;
  final String attribution;
  final String userAgentPackageName;
  final bool pilotOnly;

  static const attributionText = '© OpenStreetMap contributors';

  static const current = MapProviderConfig(
    tileUrlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: attributionText,
    userAgentPackageName: 'tj.tajgo.app',
    pilotOnly: true,
  );
}
