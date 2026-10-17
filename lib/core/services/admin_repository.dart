import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/tajgo_courier.dart';
import '../models/tajgo_order.dart';
import 'authoritative_command_service.dart';

class AdminRepository {
  AdminRepository(this._db, this._commands);

  final FirebaseFirestore _db;
  final AuthoritativeCommandService _commands;

  Stream<List<TajGoOrder>> ordersStream({int limit = 100}) => _db
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(TajGoOrder.fromDoc).toList());

  Stream<List<TajGoOrder>> todayOrdersStream() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return _db
        .collection('orders')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(midnight),
        )
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TajGoOrder.fromDoc).toList());
  }

  Stream<TajGoOrder?> orderStream(String orderId) => _db
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.exists ? TajGoOrder.fromDoc(doc) : null);

  Stream<List<TajGoCourier>> couriersStream() =>
      _db.collection('couriers').limit(100).snapshots().map((snapshot) {
        final couriers = snapshot.docs.map(TajGoCourier.fromDoc).toList();
        couriers.sort((a, b) {
          if (a.online != b.online) return a.online ? -1 : 1;
          final aUpdated =
              a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bUpdated =
              b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bUpdated.compareTo(aUpdated);
        });
        return couriers;
      });

  Future<AppUser?> user(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  Future<TajGoCourier?> courier(String uid) async {
    final doc = await _db.collection('couriers').doc(uid).get();
    return doc.exists ? TajGoCourier.fromDoc(doc) : null;
  }

  Future<void> cancelOrder({
    required String orderId,
    required String adminId,
    required String reason,
  }) async {
    await _commands.call('adminCancelOrder', {
      'orderId': orderId,
      'reason': reason.trim(),
      'idempotencyKey': TajGoIdempotencyKey.create(
        'admin-cancel-$orderId-$adminId',
      ),
    });
  }

  Future<void> returnToWaiting({
    required String orderId,
    required String adminId,
  }) async {
    await _commands.call('adminResolveDispute', {
      'orderId': orderId,
      'resolution': 'returnToWaiting',
      'reason': 'Возвращено администратором в ленту',
      'idempotencyKey': TajGoIdempotencyKey.create(
        'admin-return-$orderId-$adminId',
      ),
    });
  }

  Future<void> completeManually({
    required String orderId,
    required String adminId,
  }) async {
    await _commands.call('adminResolveDispute', {
      'orderId': orderId,
      'resolution': 'complete',
      'reason': 'Завершено администратором после проверки',
      'idempotencyKey': TajGoIdempotencyKey.create(
        'admin-complete-$orderId-$adminId',
      ),
    });
  }

  Future<void> markDisputed({
    required String orderId,
    required String adminId,
    required String reason,
  }) async {
    await _commands.call('adminResolveDispute', {
      'orderId': orderId,
      'resolution': 'markDisputed',
      'reason': reason.trim(),
      'idempotencyKey': TajGoIdempotencyKey.create(
        'admin-dispute-$orderId-$adminId',
      ),
    });
  }

  Future<void> forceOffline({
    required String courierId,
    required String adminId,
  }) async {
    await _commands.call('adminSetCourierOffline', {'courierId': courierId});
  }

  Future<void> clearActiveOrder({
    required String courierId,
    required String adminId,
  }) async {
    await _commands.call('adminReleaseCourier', {
      'courierId': courierId,
      'resolution': 'returnToWaiting',
      'reason': 'Курьер освобождён администратором',
      'idempotencyKey': TajGoIdempotencyKey.create(
        'admin-release-$courierId-$adminId',
      ),
    });
  }

  Future<void> setAdminNote({
    required String orderId,
    required String adminId,
    required String note,
  }) async {
    await _commands.call('adminSetOrderNote', {
      'orderId': orderId,
      'note': note.trim(),
      'idempotencyKey': TajGoIdempotencyKey.create(
        'admin-note-$orderId-$adminId',
      ),
    });
  }

  Future<void> migrateLegacyDeliveryCode({
    required String orderId,
    required String adminId,
  }) async {
    await _commands.call('adminMigrateLegacyDeliveryCode', {
      'orderId': orderId,
      'idempotencyKey': TajGoIdempotencyKey.stable(
        'admin-migrate-code',
        [orderId, adminId],
      ),
    });
  }

  Future<int> cancelWaitingTestOrders({required String adminId}) async {
    final snapshot = await _db
        .collection('orders')
        .where('status', whereIn: const ['waiting', 'waitingOffers'])
        .limit(100)
        .get();
    final refs = snapshot.docs
        .where(
          (doc) =>
              (doc.data()['comment'] as String? ?? '').startsWith('[TEST]'),
        )
        .map((doc) => doc.reference)
        .toList();
    if (refs.isEmpty) return 0;
    var cancelled = 0;
    for (final ref in refs) {
      try {
        await cancelOrder(
          orderId: ref.id,
          adminId: adminId,
          reason: 'Debug cleanup',
        );
        cancelled += 1;
      } on TajGoCommandException {
        // A concurrent test cleanup may already have closed this order.
      }
    }
    return cancelled;
  }

}
