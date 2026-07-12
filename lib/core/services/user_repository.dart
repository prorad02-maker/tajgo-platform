import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> ensureUser({required String uid}) async {
    final ref = _db.collection('users').doc(uid);
    if ((await ref.get()).exists) return;
    await ref.set({
      'uid': uid,
      'name': 'Пользователь',
      'role': 'customer',
      'city': 'Худжанд',
      'language': 'ru',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }
}
