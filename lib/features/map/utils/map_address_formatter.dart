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
  if (_isPlaceholder(value)) {
    return MapAddressPresentation(
      value.isEmpty ? 'Точка на карте' : value,
      'Худжанд',
    );
  }

  final normalized = normalizeHumanAddress(value);
  final humanParts = _parts(
    normalized,
  ).where((part) => !containsPlusCode(part)).toList();
  final onlyGenericLocality =
      containsPlusCode(value) && humanParts.every(_isGenericLocality);
  if (humanParts.isEmpty || onlyGenericLocality) {
    final detail = containsPlusCode(value)
        ? value
        : (fallback?.trim().isNotEmpty == true ? fallback!.trim() : 'Худжанд');
    return MapAddressPresentation('Точка на карте', detail);
  }
  return MapAddressPresentation(
    humanParts.first,
    humanParts.length > 1 ? humanParts.skip(1).join(', ') : 'Худжанд',
  );
}

String formatPrimaryAddress(String raw) => formatMapAddress(raw).primary;

String formatSecondaryAddress(String raw) => formatMapAddress(raw).secondary;

String hidePlusCodeAsPrimary(String raw) {
  final presentation = formatMapAddress(raw);
  return presentation.primary;
}

String removeDuplicateCity(String raw) {
  final seen = <String>{};
  return _parts(raw)
      .where((part) {
        final key = part.toLowerCase().replaceAll('.', '').trim();
        if (seen.contains(key)) return false;
        seen.add(key);
        return true;
      })
      .join(', ');
}

String normalizeHumanAddress(String raw) {
  final deduplicated = removeDuplicateCity(raw);
  final parts = _parts(deduplicated);
  final withoutCountry = parts
      .where((part) => part.toLowerCase() != 'таджикистан')
      .toList();
  final human = withoutCountry
      .where((part) => !containsPlusCode(part))
      .toList();
  return (human.isNotEmpty ? human : withoutCountry).join(', ');
}

bool containsPlusCode(String value) => RegExp(
  r'\b[23456789CFGHJMPQRVWX]{4,}\+[23456789CFGHJMPQRVWX]{2,}\b',
  caseSensitive: false,
).hasMatch(value);

bool _isPlaceholder(String value) =>
    value.isEmpty ||
    value == 'Определяем адрес...' ||
    value == 'Точка забора' ||
    value == 'Введите адрес';

List<String> _parts(String raw) => raw
    .split(',')
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();

bool _isGenericLocality(String value) {
  final normalized = value.toLowerCase().replaceAll('.', '').trim();
  return normalized == 'худжанд' || normalized == 'таджикистан';
}
