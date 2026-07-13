import '../models/place_suggestion.dart';

class AddressNormalizer {
  const AddressNormalizer();

  static const _wordAliases = <String, String>{
    'ул': 'улица',
    'ул.': 'улица',
    'пр': 'проспект',
    'пр.': 'проспект',
    'пр-т': 'проспект',
    'д': 'дом',
    'д.': 'дом',
    'г': 'город',
    'г.': 'город',
    'khujand': 'худжанд',
    'khodjent': 'худжанд',
    'panch': 'панчшанбе',
    'panj': 'панчшанбе',
  };

  String normalizeQuery(String input) {
    final cleaned = input
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[,;]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .map((word) => _wordAliases[word] ?? word)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double scoreMatch(String query, PlaceSuggestion place) {
    final normalized = normalizeQuery(query);
    if (normalized.isEmpty) return 0.5;
    final candidates = [
      place.title,
      place.shortTitle,
      place.address,
      ...place.aliases,
    ].map(normalizeQuery).where((value) => value.isNotEmpty);

    var best = 0.0;
    for (final candidate in candidates) {
      if (candidate == normalized) {
        best = 1;
      } else if (candidate.startsWith(normalized)) {
        best = best < 0.9 ? 0.9 : best;
      } else if (candidate.contains(normalized)) {
        best = best < 0.78 ? 0.78 : best;
      } else {
        final queryWords = normalized.split(' ').toSet();
        final candidateWords = candidate.split(' ').toSet();
        final common = queryWords.intersection(candidateWords).length;
        if (common > 0) {
          final score = common / queryWords.length * 0.7;
          best = score > best ? score : best;
        }
      }
    }
    return best;
  }

  String buildShortAddress(PlaceSuggestion place) {
    final value = place.shortTitle.trim();
    if (value.isNotEmpty) return value;
    final address = place.address.trim();
    if (address.isEmpty) return 'Точка на карте';
    return address.split(',').first.trim();
  }
}
