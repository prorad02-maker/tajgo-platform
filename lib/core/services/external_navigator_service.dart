import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum ExternalNavigator { tajgo, yandex, google, twoGis, system }

class NavigatorPreference {
  const NavigatorPreference({
    this.navigator = ExternalNavigator.tajgo,
    this.askEveryTime = false,
    this.openAutomaticallyAfterAccept = false,
  });

  final ExternalNavigator navigator;
  final bool askEveryTime;
  final bool openAutomaticallyAfterAccept;
}

class ExternalNavigatorService {
  ExternalNavigatorService([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _navigatorKey = 'preferredNavigator';
  static const _askKey = 'askEveryTime';
  static const _automaticKey = 'openAutomaticallyAfterAccept';
  final SharedPreferencesAsync _preferences;

  Future<NavigatorPreference> load() async {
    final raw = await _preferences.getString(_navigatorKey);
    return NavigatorPreference(
      navigator: ExternalNavigator.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => ExternalNavigator.tajgo,
      ),
      askEveryTime: await _preferences.getBool(_askKey) ?? false,
      openAutomaticallyAfterAccept:
          await _preferences.getBool(_automaticKey) ?? false,
    );
  }

  Future<void> save(NavigatorPreference value) async {
    await _preferences.setString(_navigatorKey, value.navigator.name);
    await _preferences.setBool(_askKey, value.askEveryTime);
    await _preferences.setBool(
      _automaticKey,
      value.openAutomaticallyAfterAccept,
    );
  }

  Future<bool> open({
    required ExternalNavigator navigator,
    required LatLng destination,
  }) async {
    if (navigator == ExternalNavigator.tajgo) return false;
    final primary = navigatorUri(navigator, destination);
    if (await canLaunchUrl(primary) &&
        await launchUrl(primary, mode: LaunchMode.externalApplication)) {
      return true;
    }
    final fallback = navigatorFallbackUri(destination);
    return launchUrl(fallback, mode: LaunchMode.externalApplication);
  }
}

Uri navigatorUri(
  ExternalNavigator navigator,
  LatLng point,
) => switch (navigator) {
  ExternalNavigator.yandex => Uri.parse(
    'yandexnavi://build_route_on_map?lat_to=${point.latitude}&lon_to=${point.longitude}',
  ),
  ExternalNavigator.google => Uri.parse(
    'google.navigation:q=${point.latitude},${point.longitude}&mode=b',
  ),
  ExternalNavigator.twoGis => Uri.parse(
    'dgis://2gis.ru/routeSearch/rsType/bike/to/${point.longitude},${point.latitude}',
  ),
  ExternalNavigator.system => navigatorFallbackUri(point),
  ExternalNavigator.tajgo => Uri(),
};

Uri navigatorFallbackUri(LatLng point) => Uri.parse(
  'geo:${point.latitude},${point.longitude}?q=${point.latitude},${point.longitude}',
);
