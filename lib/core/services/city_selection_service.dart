import 'package:shared_preferences/shared_preferences.dart';

import '../config/service_area_config.dart';

class CitySelectionService {
  CitySelectionService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'selected_service_city_v2';
  final SharedPreferencesAsync _preferences;

  Future<ServiceAreaConfig> load() async =>
      ServiceAreaRegistry.byId(await _preferences.getString(_key)) ??
      ServiceAreaRegistry.khujand;

  Future<void> save(ServiceAreaConfig city) async {
    if (!city.enabled) throw ArgumentError.value(city.id, 'city', 'disabled');
    await _preferences.setString(_key, city.id);
  }
}
