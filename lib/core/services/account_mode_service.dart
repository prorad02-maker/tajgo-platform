import '../models/app_user.dart';
import 'auth_service.dart';
import 'user_repository.dart';
import 'role_preference_service.dart';

enum ResolvedAccountMode { customer, courier }

class AccountModeService {
  AccountModeService(this._auth, this._users, this._rolePreferences);

  final AuthService _auth;
  final UserRepository _users;
  final RolePreferenceService _rolePreferences;

  Future<void> switchToCustomer() => _switch(AppUserRole.customer);

  Future<void> switchToCourier() => _switch(AppUserRole.courier);

  ResolvedAccountMode resolveStartupMode(AppUser user) =>
      resolveAccountMode(user);

  Future<void> _switch(String mode) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Сначала войдите в TajGo.');
    await _users.setLastMode(uid, mode);
    await _rolePreferences.save(mode);
  }
}

ResolvedAccountMode resolveAccountMode(AppUser user) {
  if (user.lastMode == AppUserRole.courier && user.courierApproved) {
    return ResolvedAccountMode.courier;
  }
  return ResolvedAccountMode.customer;
}
