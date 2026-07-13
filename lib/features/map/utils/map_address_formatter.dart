class MapAddressPresentation {
  const MapAddressPresentation(this.primary, this.secondary);

  final String primary;
  final String secondary;
}

MapAddressPresentation formatMapAddress(
  String raw, {
  String? fallback,
  bool currentLocation = false,
}) {
  if (currentLocation) {
    return const MapAddressPresentation('Ваше местоположение', 'Худжанд');
  }
  final value = raw.trim();
  final technical = containsPlusCode(value);
  if (value.isEmpty ||
      value == 'Определяем адрес...' ||
      value == 'Точка забора' ||
      value == 'Введите адрес') {
    return MapAddressPresentation(
      value.isEmpty ? 'Точка на карте' : value,
      'Худжанд',
    );
  }
  if (value == 'Точка на карте' || technical) {
    final detail = technical
        ? value
        : (fallback?.trim().isNotEmpty == true ? fallback!.trim() : 'Худжанд');
    return MapAddressPresentation('Точка на карте', detail);
  }
  final parts = value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  final primary = parts.isEmpty ? 'Точка на карте' : parts.first;
  final secondary = parts.length > 1 ? parts.skip(1).join(', ') : 'Худжанд';
  return MapAddressPresentation(primary, secondary);
}

bool containsPlusCode(String value) => RegExp(
  r'\b[23456789CFGHJMPQRVWX]{4,}\+[23456789CFGHJMPQRVWX]{2,}\b',
  caseSensitive: false,
).hasMatch(value);
