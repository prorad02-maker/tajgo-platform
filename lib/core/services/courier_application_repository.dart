import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/courier_application.dart';

class CourierApplicationRepository {
  CourierApplicationRepository(this._db);

  final FirebaseFirestore _db;

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

  Future<void> completeOnboarding(String uid) => _guard(
    () => _db.runTransaction((transaction) async {
      final userRef = _db.collection('users').doc(uid);
      final userDoc = await transaction.get(userRef);
      final user = userDoc.data();
      final roles = (user?['roles'] as List? ?? const [])
          .whereType<String>()
          .toSet();
      if (user?['courierStatus'] != CourierStatus.approved ||
          !roles.contains(AppUserRole.courier)) {
        throw StateError('Курьерский режим ещё не одобрен.');
      }
      transaction.update(userRef, {
        'courierOnboardingCompleted': true,
        'lastMode': AppUserRole.courier,
        'role': AppUserRole.courier,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }),
  );

  Future<void> approve({
    required String uid,
    required String adminUid,
  }) => _guard(() async {
    final now = DateTime.now().toUtc();
    await _db.runTransaction((transaction) async {
      final appRef = _application(uid);
      final userRef = _db.collection('users').doc(uid);
      final courierRef = _db.collection('couriers').doc(uid);
      final publicRef = _db.collection('courier_public').doc(uid);
      final snapshots = await Future.wait([
        transaction.get(appRef),
        transaction.get(userRef),
        transaction.get(courierRef),
      ]);
      final appDoc = snapshots[0];
      final userDoc = snapshots[1];
      final courierDoc = snapshots[2];
      if (!appDoc.exists || appDoc.data()?['status'] != CourierStatus.pending) {
        throw StateError('Одобрить можно только заявку на проверке.');
      }
      if (!userDoc.exists) throw StateError('Профиль пользователя не найден.');
      final app = CourierApplication.fromDoc(appDoc);
      final user = userDoc.data()!;
      final courier = courierDoc.data() ?? const <String, dynamic>{};
      final roles = approvedCourierRoles(
        (user['roles'] as List? ?? const []).whereType<String>(),
      );
      transaction.update(appRef, {
        'status': CourierStatus.approved,
        'reviewedBy': adminUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'resolvedBy': adminUid,
        'resolvedAt': FieldValue.serverTimestamp(),
        'suspensionReason': FieldValue.delete(),
        'history': FieldValue.arrayUnion([
          courierDecisionHistoryEntry(
            action: 'approveCourier',
            adminUid: adminUid,
            at: now,
          ),
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, {
        'roles': roles.toList(growable: false),
        'courierStatus': CourierStatus.approved,
        'courierOnboardingCompleted': approvedCourierOnboardingCompleted(
          existingValue: user['courierOnboardingCompleted'],
          courierProfileExists: courierDoc.exists,
        ),
        'lastMode': AppUserRole.customer,
        if (user['role'] != AppUserRole.admin) 'role': AppUserRole.customer,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final privateData = buildApprovedCourierData(
        uid: uid,
        application: app,
        existing: courier,
      );
      transaction.set(courierRef, {
        ...privateData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(publicRef, {
        'uid': uid,
        'displayName': app.displayName,
        'name': app.displayName,
        'isOnline': false,
        'online': false,
        'rating': courier['rating'] ?? 5.0,
        'transport': app.transport,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _writeDecisionLog(
        transaction,
        action: 'approveCourier',
        uid: uid,
        adminUid: adminUid,
      );
    });
  });

  Future<void> reject({
    required String uid,
    required String adminUid,
    required String reason,
  }) => _decision(
    uid: uid,
    adminUid: adminUid,
    reason: reason,
    expectedStatus: CourierStatus.pending,
    nextStatus: CourierStatus.rejected,
    action: 'rejectCourier',
  );

  Future<void> suspend({
    required String uid,
    required String adminUid,
    required String reason,
  }) => _guard(() async {
    final trimmed = _requiredReason(reason);
    final now = DateTime.now().toUtc();
    await _db.runTransaction((transaction) async {
      final appRef = _application(uid);
      final userRef = _db.collection('users').doc(uid);
      final courierRef = _db.collection('couriers').doc(uid);
      final publicRef = _db.collection('courier_public').doc(uid);
      final snapshots = await Future.wait([
        transaction.get(appRef),
        transaction.get(userRef),
        transaction.get(courierRef),
      ]);
      if (snapshots[1].data()?['courierStatus'] != CourierStatus.approved) {
        throw StateError('Приостановить можно только одобренного курьера.');
      }
      final user = snapshots[1].data()!;
      transaction.set(appRef, {
        'uid': uid,
        'displayName':
            snapshots[0].data()?['displayName'] ??
            user['displayName'] ??
            user['name'] ??
            'Курьер',
        'phoneNumber': user['phoneNumber'],
        'status': CourierStatus.suspended,
        'suspensionReason': trimmed,
        'reviewedBy': adminUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (!snapshots[0].exists) 'createdAt': FieldValue.serverTimestamp(),
        'history': FieldValue.arrayUnion([
          courierDecisionHistoryEntry(
            action: 'suspendCourier',
            adminUid: adminUid,
            reason: trimmed,
            at: now,
          ),
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.update(userRef, {
        'courierStatus': CourierStatus.suspended,
        'lastMode': AppUserRole.customer,
        if (user['role'] != AppUserRole.admin) 'role': AppUserRole.customer,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (snapshots[2].exists) {
        transaction.update(
          courierRef,
          buildSuspendedCourierPatch(FieldValue.serverTimestamp()),
        );
      }
      transaction.set(
        publicRef,
        buildSuspendedCourierPatch(FieldValue.serverTimestamp()),
        SetOptions(merge: true),
      );
      _writeDecisionLog(
        transaction,
        action: 'suspendCourier',
        uid: uid,
        adminUid: adminUid,
        reason: trimmed,
      );
    });
  });

  Future<void> restore({required String uid, required String adminUid}) =>
      _decision(
        uid: uid,
        adminUid: adminUid,
        expectedStatus: CourierStatus.suspended,
        nextStatus: CourierStatus.approved,
        action: 'reinstateCourier',
      );

  Future<void> _decision({
    required String uid,
    required String adminUid,
    required String expectedStatus,
    required String nextStatus,
    required String action,
    String? reason,
  }) => _guard(() async {
    final trimmed = reason == null ? null : _requiredReason(reason);
    final now = DateTime.now().toUtc();
    await _db.runTransaction((transaction) async {
      final appRef = _application(uid);
      final userRef = _db.collection('users').doc(uid);
      final snapshots = await Future.wait([
        transaction.get(appRef),
        transaction.get(userRef),
      ]);
      if (!snapshots[0].exists ||
          snapshots[0].data()?['status'] != expectedStatus) {
        throw StateError('Статус заявки уже изменился. Обновите экран.');
      }
      final user = snapshots[1].data();
      transaction.update(appRef, {
        'status': nextStatus,
        'reviewedBy': adminUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (nextStatus == CourierStatus.rejected) 'rejectionReason': trimmed,
        if (nextStatus == CourierStatus.approved)
          'suspensionReason': FieldValue.delete(),
        'history': FieldValue.arrayUnion([
          courierDecisionHistoryEntry(
            action: action,
            adminUid: adminUid,
            reason: trimmed,
            at: now,
          ),
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, {
        'courierStatus': nextStatus,
        'lastMode': AppUserRole.customer,
        if (user?['role'] != AppUserRole.admin) 'role': AppUserRole.customer,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _writeDecisionLog(
        transaction,
        action: action,
        uid: uid,
        adminUid: adminUid,
        reason: trimmed,
      );
    });
  });

  void _writeDecisionLog(
    Transaction transaction, {
    required String action,
    required String uid,
    required String adminUid,
    String? reason,
  }) {
    transaction.set(
      _db.collection('admin_logs').doc(),
      buildCourierAdminLog(
        action: action,
        targetUid: uid,
        adminUid: adminUid,
        reason: reason,
        createdAt: FieldValue.serverTimestamp(),
      ),
    );
  }

  String _requiredReason(String reason) {
    final trimmed = reason.trim();
    if (trimmed.length < 3) {
      throw StateError('Укажите понятную причину — минимум 3 символа.');
    }
    return trimmed;
  }

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

Map<String, dynamic> buildApprovedCourierData({
  required String uid,
  required CourierApplication application,
  required Map<String, dynamic> existing,
}) => {
  'uid': uid,
  'phoneNumber': application.phoneNumber ?? existing['phoneNumber'],
  'displayName': application.displayName,
  'name': application.displayName,
  'city': application.city,
  'isOnline': false,
  'online': false,
  'rating': existing['rating'] ?? 5.0,
  'score': existing['score'] ?? 100,
  'transport': application.transport,
  'earningsToday': existing['earningsToday'] ?? 0,
  'ordersToday': existing['ordersToday'] ?? 0,
  'activeOrderId': existing['activeOrderId'],
};

List<String> approvedCourierRoles(Iterable<String> existing) => <String>{
  AppUserRole.customer,
  ...existing.where(AppUserRole.userModes.contains),
  AppUserRole.courier,
}.toList(growable: false);

bool approvedCourierOnboardingCompleted({
  required Object? existingValue,
  required bool courierProfileExists,
}) => existingValue == true || courierProfileExists;

/// Suspension only takes the courier off line. Active delivery state must be
/// preserved so an administrator can resolve it explicitly instead of losing
/// an order silently.
Map<String, dynamic> buildSuspendedCourierPatch(Object updatedAt) => {
  'isOnline': false,
  'online': false,
  'updatedAt': updatedAt,
};

Map<String, dynamic> buildCourierAdminLog({
  required String action,
  required String targetUid,
  required String adminUid,
  required Object createdAt,
  String? reason,
}) => {
  'action': action,
  'targetUid': targetUid,
  'courierId': targetUid,
  'adminUid': adminUid,
  'adminId': adminUid,
  if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim(),
  if (reason?.trim().isNotEmpty == true) 'details': reason!.trim(),
  'createdAt': createdAt,
};

Map<String, dynamic> courierDecisionHistoryEntry({
  required String action,
  required String adminUid,
  required DateTime at,
  String? reason,
}) => {
  'action': action,
  'adminUid': adminUid,
  if (reason?.isNotEmpty == true) 'reason': reason,
  'at': Timestamp.fromDate(at),
};
