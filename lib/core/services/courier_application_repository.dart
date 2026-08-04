import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/courier_application.dart';
import 'authoritative_command_service.dart';

class CourierApplicationRepository {
  CourierApplicationRepository(this._db, AuthoritativeCommandService commands)
    : _commands = commands,
      _adminCommands = CourierAdminCommandService(commands);

  final FirebaseFirestore _db;
  final AuthoritativeCommandService _commands;
  final CourierAdminCommandService _adminCommands;

  DocumentReference<Map<String, dynamic>> _application(String uid) =>
      _db.collection('courier_applications').doc(uid);

  Stream<CourierApplication?> applicationStream(String uid) => _application(uid)
      .snapshots()
      .map((doc) => doc.exists ? CourierApplication.fromDoc(doc) : null);

  Future<CourierApplication?> get(String uid) async {
    final doc = await _application(uid).get();
    return doc.exists ? CourierApplication.fromDoc(doc) : null;
  }

  Stream<List<CourierApplication>> applicationsStream() => _db
      .collection('courier_applications')
      .orderBy('updatedAt', descending: true)
      .limit(200)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(CourierApplication.fromDoc)
            .toList(growable: false),
      );

  Stream<int> pendingCountStream() => _db
      .collection('courier_applications')
      .where('status', isEqualTo: CourierStatus.pending)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.size);

  Future<void> saveDraft(CourierApplication application) => _guard(
    () => _db.runTransaction((transaction) async {
      final appRef = _application(application.uid);
      final userRef = _db.collection('users').doc(application.uid);
      final snapshots = await Future.wait([
        transaction.get(appRef),
        transaction.get(userRef),
      ]);
      final existing = snapshots[0];
      final existingStatus = existing.data()?['status'] as String?;
      if (existingStatus == CourierStatus.pending ||
          existingStatus == CourierStatus.approved ||
          existingStatus == CourierStatus.suspended) {
        throw StateError('Эту заявку сейчас нельзя редактировать.');
      }
      transaction.set(appRef, {
        ...application.toDraftMap(),
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.update(userRef, {
        'courierStatus': CourierStatus.draft,
        'targetRole': AppUserRole.courier,
        'lastMode': AppUserRole.customer,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }),
  );

  Future<void> submit(String uid) => _guard(
    () => _db.runTransaction((transaction) async {
      final appRef = _application(uid);
      final userRef = _db.collection('users').doc(uid);
      final snapshots = await Future.wait([
        transaction.get(appRef),
        transaction.get(userRef),
      ]);
      final appDoc = snapshots[0];
      if (!appDoc.exists) throw StateError('Сначала заполните анкету.');
      final application = CourierApplication.fromDoc(appDoc);
      if (!application.canSubmit) {
        throw StateError('Проверьте обязательные поля и согласия.');
      }
      if (application.status != CourierStatus.draft &&
          application.status != CourierStatus.rejected) {
        throw StateError('Заявка уже отправлена.');
      }
      transaction.update(appRef, {
        'status': CourierStatus.pending,
        'currentStep': 4,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, {
        'courierStatus': CourierStatus.pending,
        'targetRole': AppUserRole.courier,
        'lastMode': AppUserRole.customer,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }),
  );

  Future<void> reopenRejected(String uid) => _guard(
    () => _db.runTransaction((transaction) async {
      final appRef = _application(uid);
      final userRef = _db.collection('users').doc(uid);
      final appDoc = await transaction.get(appRef);
      if (appDoc.data()?['status'] != CourierStatus.rejected) {
        throw StateError('Заявка не требует исправления.');
      }
      transaction.update(appRef, {
        'status': CourierStatus.draft,
        'currentStep': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, {
        'courierStatus': CourierStatus.draft,
        'lastMode': AppUserRole.customer,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }),
  );

  Future<void> completeOnboarding(String uid) async {
    await _commands.call('completeCourierOnboarding', {
      'idempotencyKey': TajGoIdempotencyKey.stable(
        'complete-courier-onboarding',
        [uid],
      ),
    });
  }

  Future<void> approve({required String uid}) => _adminCommands.approve(uid);

  Future<void> reject({required String uid, required String reason}) =>
      _adminCommands.reject(uid, reason);

  Future<void> suspend({required String uid, required String reason}) =>
      _adminCommands.suspend(uid, reason);

  Future<void> restore({required String uid}) => _adminCommands.restore(uid);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw StateError(
          'Не хватает прав для заявок курьеров. '
          'Нужно проверить и опубликовать новые Firestore Rules.',
        );
      }
      rethrow;
    }
  }
}

class CourierAdminCommandService {
  CourierAdminCommandService(this._commands);

  final AuthoritativeCommandService _commands;

  Future<void> approve(String uid) => _call('adminApproveCourier', uid: uid);

  Future<void> reject(String uid, String reason) =>
      _call('adminRejectCourier', uid: uid, reason: reason);

  Future<void> suspend(String uid, String reason) =>
      _call('adminSuspendCourier', uid: uid, reason: reason);

  Future<void> restore(String uid) => _call('adminRestoreCourier', uid: uid);

  Future<void> _call(
    String command, {
    required String uid,
    String? reason,
  }) async {
    final trimmedReason = reason?.trim();
    await _commands.call(command, {
      'courierId': uid,
      'idempotencyKey': TajGoIdempotencyKey.create('$command-$uid'),
      if (trimmedReason?.isNotEmpty == true) 'reason': trimmedReason,
    });
  }
}
