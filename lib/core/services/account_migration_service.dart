import '../models/app_user.dart';
import 'authoritative_command_service.dart';

class AccountMigrationService {
  AccountMigrationService(this._commands);

  final AuthoritativeCommandService _commands;

  Future<void> migrate(String uid) => _commands.call('ensureUserProfile', {
    'idempotencyKey': TajGoIdempotencyKey.stable('legacy-account-migrate', [
      uid,
    ]),
  });
}

Map<String, dynamic> buildLegacyAccountPatch(
  Map<String, dynamic> data, {
  required bool courierExists,
}) {
  final patch = <String, dynamic>{};
  final legacyRole = data['role'] as String? ?? AppUserRole.customer;
  final legacyCourier =
      courierExists ||
      legacyRole == AppUserRole.courier ||
      data['isCourier'] == true ||
      data['courierMode'] == true;

  final currentRoles = (data['roles'] as List?)
      ?.whereType<String>()
      .where(AppUserRole.userModes.contains)
      .toSet();
  final migratedRoles = <String>{
    AppUserRole.customer,
    ...?currentRoles,
    if (legacyCourier) AppUserRole.courier,
  };
  if (currentRoles == null ||
      !currentRoles.containsAll(migratedRoles) ||
      !migratedRoles.containsAll(currentRoles)) {
    patch['roles'] = migratedRoles.toList(growable: false);
  }
  if (data['lastMode'] == null) {
    patch['lastMode'] = legacyCourier
        ? AppUserRole.courier
        : AppUserRole.customer;
  }
  if (data['courierStatus'] == null) {
    patch['courierStatus'] = legacyCourier
        ? CourierStatus.approved
        : CourierStatus.none;
  }
  if (data['phoneVerified'] == null) {
    patch['phoneVerified'] =
        (data['phoneNumber'] as String?)?.trim().isNotEmpty == true;
  }
  if (data['profileComplete'] == null) {
    final name = data['displayName'] as String? ?? data['name'] as String?;
    patch['profileComplete'] = name?.trim().isNotEmpty == true;
  }
  if (data['courierOnboardingCompleted'] == null) {
    patch['courierOnboardingCompleted'] = legacyCourier;
  }
  return patch;
}
