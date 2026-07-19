import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class RolePreferenceSnapshot {
  const RolePreferenceSnapshot({
    required this.selectedRole,
    required this.onboardingCompleted,
  });

  final String? selectedRole;
  final bool onboardingCompleted;
}

class RolePreferenceService {
  RolePreferenceService({
    SharedPreferencesAsync? preferences,
    RolePreferenceStorage? storage,
  }) : _storage =
           storage ??
           SharedPreferencesRoleStorage(
             preferences ?? SharedPreferencesAsync(),
           );

  static const selectedRoleKey = 'selectedRole';
  static const onboardingCompletedKey = 'onboardingCompleted';

  final RolePreferenceStorage _storage;

  Future<RolePreferenceSnapshot> load() async {
    final role = await _storage.getString(selectedRoleKey);
    final completed = await _storage.getBool(onboardingCompletedKey) ?? false;
    return RolePreferenceSnapshot(
      selectedRole: AppUserRole.userModes.contains(role) ? role : null,
      onboardingCompleted: completed,
    );
  }

  Future<void> save(String role) async {
    if (!AppUserRole.userModes.contains(role)) {
      throw ArgumentError.value(role, 'role');
    }
    await _storage.setString(selectedRoleKey, role);
    await _storage.setBool(onboardingCompletedKey, true);
  }

  Future<void> clear() async {
    await _storage.remove(selectedRoleKey);
    await _storage.remove(onboardingCompletedKey);
  }
}

abstract interface class RolePreferenceStorage {
  Future<String?> getString(String key);
  Future<bool?> getBool(String key);
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
}

class SharedPreferencesRoleStorage implements RolePreferenceStorage {
  SharedPreferencesRoleStorage(this._preferences);
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);
  @override
  Future<bool?> getBool(String key) => _preferences.getBool(key);
  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);
  @override
  Future<void> setBool(String key, bool value) =>
      _preferences.setBool(key, value);
  @override
  Future<void> remove(String key) => _preferences.remove(key);
}
