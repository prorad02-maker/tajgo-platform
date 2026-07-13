import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/place_suggestion.dart';

class RecentPlacesService {
  RecentPlacesService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'tajgo_recent_places_v1';
  static const _limit = 20;
  final SharedPreferencesAsync _preferences;

  Future<List<PlaceSuggestion>> load({String? type}) async {
    try {
      final raw = await _preferences.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      final places =
          decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => PlaceSuggestion.fromJson(item, source: 'recent'))
              .where((place) => place.lat != 0 || place.lng != 0)
              .where((place) => type == null || place.recentType == type)
              .toList()
            ..sort(
              (a, b) => (b.usedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    a.usedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                  ),
            );
      return places.take(_limit).toList();
    } catch (_) {
      await _preferences.remove(_key);
      return const [];
    }
  }

  Future<void> save(PlaceSuggestion place, {required String type}) async {
    final places = await load();
    final unique = places
        .where(
          (item) =>
              item.recentType != type ||
              (item.lat - place.lat).abs() > 0.00001 ||
              (item.lng - place.lng).abs() > 0.00001,
        )
        .toList();
    unique.insert(
      0,
      place.copyWith(
        source: 'recent',
        usedAt: DateTime.now().toUtc(),
        recentType: type,
      ),
    );
    final encoded = unique
        .take(_limit)
        .map(
          (item) => item.toJson(
            type: item.recentType ?? type,
            usedAt: item.usedAt ?? DateTime.now().toUtc(),
          ),
        )
        .toList();
    await _preferences.setString(_key, jsonEncode(encoded));
  }
}
