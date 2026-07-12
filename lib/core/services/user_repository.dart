import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> ensureUser({
    required String uid,
    String? phoneNumber,
    String? displayName,
  }) async {
    final ref = _db.collection('users').doc(uid);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final existing = snapshot.data() ?? const <String, dynamic>{};
      final resolvedName = displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : existing['displayName'] as String? ??
                existing['name'] as String? ??
                'Пользователь';
      final data = <String, dynamic>{
        'uid': uid,
        'phoneNumber': phoneNumber ?? existing['phoneNumber'],
        'displayName': resolvedName,
        // Keep the legacy field until all v0.4 screens are migrated.
        'name': resolvedName,
        'role': existing['role'] as String? ?? AppUserRole.customer,
        'city': existing['city'] as String? ?? 'Худжанд',
        'language': existing['language'] as String? ?? 'ru',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!snapshot.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      transaction.set(ref, data, SetOptions(merge: true));
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }
}
