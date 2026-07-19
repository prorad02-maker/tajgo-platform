import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.role,
    required this.roles,
    required this.lastMode,
    required this.courierStatus,
    required this.phoneVerified,
    required this.profileComplete,
    required this.courierOnboardingCompleted,
    this.onboardingCompleted = true,
    this.selectedRole = AppUserRole.customer,
    required this.city,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    this.phoneNumber,
    this.photoUrl,
  });

  final String uid;
  final String? phoneNumber;
  final String displayName;
  final String? photoUrl;
  final String role;
  final List<String> roles;
  final String lastMode;
  final String courierStatus;
  final bool phoneVerified;
  final bool profileComplete;
  final bool courierOnboardingCompleted;
  final bool onboardingCompleted;
  final String selectedRole;
  final String city;
  final String language;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get name => displayName;
  bool get isAdmin => role == AppUserRole.admin;
  bool get courierApproved =>
      roles.contains(AppUserRole.courier) &&
      courierStatus == CourierStatus.approved;
  bool get canUseCourierMode => courierApproved && courierOnboardingCompleted;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser.fromMap(doc.data() ?? const {}, uid: doc.id);

  factory AppUser.fromMap(Map<String, dynamic> data, {required String uid}) {
    final legacyRole = data['role'] as String? ?? AppUserRole.customer;
    final legacyCourier =
        legacyRole == AppUserRole.courier ||
        data['isCourier'] == true ||
        data['courierMode'] == true;
    final rawRoles = (data['roles'] as List?)
        ?.whereType<String>()
        .where(AppUserRole.userModes.contains)
        .toSet();
    final roles = <String>{AppUserRole.customer, ...?rawRoles};
    if (rawRoles == null && legacyCourier) roles.add(AppUserRole.courier);
    final phone = data['phoneNumber'] as String?;
    final displayName =
        data['displayName'] as String? ??
        data['name'] as String? ??
        'Пользователь';
    return AppUser(
      uid: data['uid'] as String? ?? uid,
      phoneNumber: phone,
      displayName: displayName,
      photoUrl: data['photoUrl'] as String?,
      role: legacyRole,
      roles: roles.toList(growable: false),
      lastMode: _safeMode(
        data['lastMode'] as String? ??
            data['targetRole'] as String? ??
            (legacyCourier ? AppUserRole.courier : AppUserRole.customer),
      ),
      courierStatus:
          data['courierStatus'] as String? ??
          (legacyCourier ? CourierStatus.approved : CourierStatus.none),
      phoneVerified:
          data['phoneVerified'] as bool? ?? phone?.isNotEmpty == true,
      profileComplete:
          data['profileComplete'] as bool? ??
          (displayName.trim().isNotEmpty && displayName != 'Пользователь'),
      courierOnboardingCompleted:
          data['courierOnboardingCompleted'] as bool? ?? legacyCourier,
      onboardingCompleted:
          data['onboardingCompleted'] as bool? ?? data.containsKey('role'),
      selectedRole: _safeMode(
        data['selectedRole'] as String? ??
            data['targetRole'] as String? ??
            legacyRole,
      ),
      city: data['city'] as String? ?? 'Худжанд',
      language: data['language'] as String? ?? 'ru',
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static String _safeMode(String mode) =>
      mode == AppUserRole.courier ? AppUserRole.courier : AppUserRole.customer;

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };
}

abstract final class AppUserRole {
  static const customer = 'customer';
  static const courier = 'courier';
  static const admin = 'admin';
  static const userModes = {customer, courier};
  static const values = {customer, courier, admin};
}

abstract final class CourierStatus {
  static const none = 'none';
  static const draft = 'draft';
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const suspended = 'suspended';
  static const values = {none, draft, pending, approved, rejected, suspended};
}
