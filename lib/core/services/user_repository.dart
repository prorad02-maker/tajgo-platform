import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> ensureUser({
    required String uid,
    String? phoneNumber,
    String? displayName,
    bool phoneVerified = false,
    String initialMode = AppUserRole.customer,
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
      final existingRoles = (existing['roles'] as List?)
          ?.whereType<String>()
          .toSet();
      final roles = <String>{AppUserRole.customer, ...?existingRoles};
      final mode = initialMode == AppUserRole.courier
          ? AppUserRole.courier
          : AppUserRole.customer;
      final data = <String, dynamic>{
        'uid': uid,
        'phoneNumber': phoneNumber ?? existing['phoneNumber'],
        'displayName': resolvedName,
        'name': resolvedName,
        'photoUrl': existing['photoUrl'],
        'roles': roles.toList(),
        // Courier intent starts an application; it never grants courier mode.
        'lastMode': existing['lastMode'] ?? AppUserRole.customer,
        'phoneVerified':
            existing['phoneVerified'] == true ||
            phoneVerified ||
            phoneNumber?.isNotEmpty == true,
        'profileComplete': existing['profileComplete'] ?? false,
        'courierStatus':
            existing['courierStatus'] ??
            (mode == AppUserRole.courier
                ? CourierStatus.draft
                : CourierStatus.none),
        'targetRole': existing['targetRole'] ?? mode,
        // Legacy mirror. Admin is never overwritten by a user mode.
        'role': existing['role'] == AppUserRole.admin
            ? AppUserRole.admin
            : existing['role'] ?? AppUserRole.customer,
        'city': existing['city'] ?? 'Худжанд',
        'language': existing['language'] ?? 'ru',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!snapshot.exists) data['createdAt'] = FieldValue.serverTimestamp();
      transaction.set(ref, data, SetOptions(merge: true));
    });
  }

  Future<void> completeProfile({
    required String uid,
    required String displayName,
    String? photoUrl,
    required String initialIntent,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError('Имя не может быть пустым.');
    final courierIntent = initialIntent == AppUserRole.courier;
    final ref = _db.collection('users').doc(uid);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final existing = snapshot.data() ?? const <String, dynamic>{};
      final roles = <String>{
        AppUserRole.customer,
        ...?(existing['roles'] as List?)?.whereType<String>(),
      };
      final previousStatus =
          existing['courierStatus'] as String? ?? CourierStatus.none;
      final approved = previousStatus == CourierStatus.approved;
      final status = approved
          ? CourierStatus.approved
          : courierIntent
          ? CourierStatus.draft
          : previousStatus;
      final previousRole = existing['role'] as String?;
      transaction.set(ref, {
        'displayName': name,
        'name': name,
        if (photoUrl?.trim().isNotEmpty == true) 'photoUrl': photoUrl!.trim(),
        'roles': roles.toList(growable: false),
        'lastMode': approved
            ? existing['lastMode'] ?? AppUserRole.courier
            : AppUserRole.customer,
        'profileComplete': true,
        'courierStatus': status,
        'role': previousRole == AppUserRole.admin
            ? AppUserRole.admin
            : approved
            ? previousRole ?? AppUserRole.courier
            : AppUserRole.customer,
        'targetRole': courierIntent
            ? AppUserRole.courier
            : existing['targetRole'] ?? AppUserRole.customer,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> setLastMode(String uid, String mode) async {
    if (!AppUserRole.userModes.contains(mode)) {
      throw ArgumentError.value(mode, 'mode');
    }
    final user = await getUser(uid);
    if (user == null) throw StateError('Профиль пользователя не найден.');
    if (mode == AppUserRole.courier && !user.courierApproved) {
      throw StateError('Режим курьера доступен после одобрения заявки.');
    }
    await _db.collection('users').doc(uid).update({
      'lastMode': mode,
      if (!user.isAdmin) 'role': mode,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  Stream<AppUser?> userStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  Future<void> setAdminRoleForTesting(String uid) async {
    if (!kDebugMode) {
      throw StateError('Тестовое изменение роли доступно только в debug.');
    }
    await _db.collection('users').doc(uid).update({
      'role': AppUserRole.admin,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
