import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/place_suggestion.dart';

class SavedPlacesService {
  SavedPlacesService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'tajgo_saved_places_v1';
  static const _limit = 50;
  final SharedPreferencesAsync _preferences;

  Future<List<PlaceSuggestion>> load() async {
    try {
      final raw = await _preferences.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => PlaceSuggestion.fromJson(json, source: 'favorite'))
          .where((place) => place.lat != 0 || place.lng != 0)
          .take(_limit)
          .toList();
    } catch (_) {
      await _preferences.remove(_key);
      return const [];
    }
  }

  Future<bool> isFavorite(PlaceSuggestion place) async {
    final saved = await load();
    return saved.any((item) => _samePlace(item, place));
  }

  Future<bool> toggleFavorite(PlaceSuggestion place) async {
    final saved = await load();
    final exists = saved.any((item) => _samePlace(item, place));
    final next = saved.where((item) => !_samePlace(item, place)).toList();
    if (!exists) next.insert(0, place.copyWith(source: 'favorite'));
    await _preferences.setString(
      _key,
      jsonEncode(next.take(_limit).map((item) => item.toJson()).toList()),
    );
    return !exists;
  }

  Future<void> remove(PlaceSuggestion place) async {
    final saved = await load();
    final next = saved.where((item) => !_samePlace(item, place));
    await _preferences.setString(
      _key,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  bool _samePlace(PlaceSuggestion a, PlaceSuggestion b) =>
      a.id.isNotEmpty && b.id.isNotEmpty
      ? a.id == b.id
      : (a.lat - b.lat).abs() < 0.00001 && (a.lng - b.lng).abs() < 0.00001;
}
