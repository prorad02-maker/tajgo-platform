import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.role,
    required this.city,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    this.phoneNumber,
  });

  final String uid;
  final String? phoneNumber;
  final String displayName;
  final String role;
  final String city;
  final String language;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Legacy alias used by the existing Customer/Courier MVP screens.
  String get name => displayName;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: data['uid'] as String? ?? doc.id,
      phoneNumber: data['phoneNumber'] as String?,
      displayName:
          data['displayName'] as String? ??
          data['name'] as String? ??
          'Пользователь',
      role: data['role'] as String? ?? 'customer',
      city: data['city'] as String? ?? 'Худжанд',
      language: data['language'] as String? ?? 'ru',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

abstract final class AppUserRole {
  static const customer = 'customer';
  static const courier = 'courier';
  static const admin = 'admin';

  static const values = {customer, courier, admin};
}
