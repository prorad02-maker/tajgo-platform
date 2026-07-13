import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/place_suggestion.dart';

class RecentPlacesService {
  RecentPlacesService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'tajgo_recent_places_v1';
  static const _limit = 10;
  final SharedPreferencesAsync _preferences;

  Future<List<PlaceSuggestion>> load() async {
    try {
      final raw = await _preferences.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => PlaceSuggestion.fromJson(item, source: 'recent'))
          .where((place) => place.lat != 0 || place.lng != 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(PlaceSuggestion place, {required String type}) async {
    final places = await load();
    final unique = places
        .where(
          (item) =>
              (item.lat - place.lat).abs() > 0.00001 ||
              (item.lng - place.lng).abs() > 0.00001,
        )
        .toList();
    unique.insert(0, place.copyWith(source: 'recent'));
    final encoded = unique
        .take(_limit)
        .map((item) => item.toJson(type: type, usedAt: DateTime.now().toUtc()))
        .toList();
    await _preferences.setString(_key, jsonEncode(encoded));
  }
}
