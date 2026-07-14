import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class AccountMigrationService {
  AccountMigrationService(this._db);

  final FirebaseFirestore _db;

  Future<void> migrate(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    final courierRef = _db.collection('couriers').doc(uid);
    final snapshots = await Future.wait([userRef.get(), courierRef.get()]);
    final user = snapshots[0];
    if (!user.exists) return;
    final patch = buildLegacyAccountPatch(
      user.data() ?? const {},
      courierExists: snapshots[1].exists,
    );
    if (patch.isEmpty) return;
    await userRef.set({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
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
