import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import 'authoritative_command_service.dart';

class UserRepository {
  UserRepository(this._db, this._commands);
  final FirebaseFirestore _db;
  final AuthoritativeCommandService _commands;

  Future<void> ensureUser({
    required String uid,
    String? phoneNumber,
    String? displayName,
    bool phoneVerified = false,
    String initialMode = AppUserRole.customer,
  }) async {
    await _commands.call('ensureUserProfile', {
      'initialIntent': initialMode,
      if (displayName?.trim().isNotEmpty == true)
        'displayName': displayName!.trim(),
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
    await _commands.call('completeUserProfile', {
      'displayName': name,
      if (photoUrl?.trim().isNotEmpty == true) 'photoUrl': photoUrl!.trim(),
      'initialIntent': initialIntent,
      'idempotencyKey': TajGoIdempotencyKey.create('complete-profile-$uid'),
    });
  }

  Future<void> setLastMode(String uid, String mode) async {
    if (!AppUserRole.userModes.contains(mode)) {
      throw ArgumentError.value(mode, 'mode');
    }
    await _commands.call('switchAccountMode', {
      'targetMode': mode,
      'idempotencyKey': TajGoIdempotencyKey.create('switch-mode-$uid-$mode'),
    });
  }

  Future<void> completeRoleOnboarding(String uid, String role) async {
    if (!AppUserRole.userModes.contains(role)) {
      throw ArgumentError.value(role, 'role');
    }
    final user = await getUser(uid);
    if (user == null) throw StateError('Профиль пользователя не найден.');
    await _commands.call('completeUserProfile', {
      'displayName': user.displayName,
      if (user.photoUrl?.isNotEmpty == true) 'photoUrl': user.photoUrl,
      'initialIntent': role,
      'idempotencyKey': TajGoIdempotencyKey.create(
        'role-onboarding-$uid-$role',
      ),
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

  /// Запрос на удаление аккаунта через authoritative Function.
  ///
  /// Backend анонимизирует профиль и presence, запрещает удаление при активном
  /// заказе и best-effort удаляет Firebase Auth-пользователя. Возвращает статус.
  Future<Map<String, dynamic>> deleteAccountRequest({
    required String uid,
    String? reason,
  }) {
    return _commands.call('deleteAccountRequest', {
      'idempotencyKey': TajGoIdempotencyKey.create('delete-account-$uid'),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<void> setAdminRoleForTesting(String uid) async {
    throw StateError(
      'Роль admin назначается владельцем через Firebase по документированной процедуре.',
    );
  }
}
