import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.city,
    required this.language,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String role;
  final String city;
  final String language;
  final DateTime? createdAt;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: data['uid'] as String? ?? doc.id,
      name: data['name'] as String? ?? 'Пользователь',
      role: data['role'] as String? ?? 'customer',
      city: data['city'] as String? ?? 'Худжанд',
      language: data['language'] as String? ?? 'ru',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
