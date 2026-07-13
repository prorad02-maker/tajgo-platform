import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/tajgo_courier.dart';
import '../models/tajgo_order.dart';

class AdminRepository {
  AdminRepository(this._db);

  final FirebaseFirestore _db;

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
  }) => _adminAction(
    () => _db.runTransaction((transaction) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);
      final data = orderDoc.data();
      const allowed = {
        'waiting',
        'accepted',
        'pickedUp',
        'delivered',
        'disputed',
      };
      if (!orderDoc.exists || !allowed.contains(data?['status'])) {
        throw StateError('Этот заказ уже нельзя отменить.');
      }
      transaction.update(orderRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledReason': reason.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final courierId = data?['courierId'] as String?;
      if (courierId != null) {
        transaction.update(_db.collection('couriers').doc(courierId), {
          'activeOrderId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      _writeLog(
        transaction,
        action: 'cancelOrder',
        adminId: adminId,
        orderId: orderId,
        details: reason.trim(),
      );
    }),
  );

  Future<void> returnToWaiting({
    required String orderId,
    required String adminId,
  }) => _adminAction(
    () => _db.runTransaction((transaction) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);
      final data = orderDoc.data();
      const allowed = {'accepted', 'pickedUp', 'delivered', 'disputed'};
      if (!orderDoc.exists || !allowed.contains(data?['status'])) {
        throw StateError('Вернуть этот заказ в waiting нельзя.');
      }
      final courierId = data?['courierId'] as String?;
      transaction.update(orderRef, {
        'status': 'waiting',
        'courierId': FieldValue.delete(),
        'acceptedAt': FieldValue.delete(),
        'arrivedAtPickupAt': FieldValue.delete(),
        'pickedUpAt': FieldValue.delete(),
        'deliveredAt': FieldValue.delete(),
        'disputedAt': FieldValue.delete(),
        'declinedBy': <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (courierId != null) {
        transaction.update(_db.collection('couriers').doc(courierId), {
          'activeOrderId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      _writeLog(
        transaction,
        action: 'returnToWaiting',
        adminId: adminId,
        orderId: orderId,
      );
    }),
  );

  Future<void> completeManually({
    required String orderId,
    required String adminId,
  }) => _adminAction(
    () => _db.runTransaction((transaction) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);
      final data = orderDoc.data();
      const allowed = {'pickedUp', 'delivered', 'disputed'};
      if (!orderDoc.exists || !allowed.contains(data?['status'])) {
        throw StateError('Завершить этот заказ вручную нельзя.');
      }
      final courierId = data?['courierId'] as String?;
      if (courierId == null) {
        throw StateError('У заказа нет назначенного курьера.');
      }
      transaction.update(orderRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'manuallyCompletedBy': adminId,
        if (data?['status'] == 'disputed') 'resolvedBy': adminId,
        if (data?['status'] == 'disputed')
          'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(_db.collection('couriers').doc(courierId), {
        'activeOrderId': null,
        'earningsToday': FieldValue.increment((data?['price'] ?? 0) as num),
        'ordersToday': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _writeLog(
        transaction,
        action: 'completeManually',
        adminId: adminId,
        orderId: orderId,
        courierId: courierId,
      );
    }),
  );

  Future<void> markDisputed({
    required String orderId,
    required String adminId,
    required String reason,
  }) => _adminAction(
    () => _db.runTransaction((transaction) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);
      final data = orderDoc.data();
      const allowed = {'accepted', 'pickedUp', 'delivered', 'completed'};
      if (!orderDoc.exists || !allowed.contains(data?['status'])) {
        throw StateError('Пометить этот заказ спорным нельзя.');
      }
      transaction.update(orderRef, {
        'status': 'disputed',
        'disputedAt': FieldValue.serverTimestamp(),
        'adminNote': reason.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _writeLog(
        transaction,
        action: 'markDisputed',
        adminId: adminId,
        orderId: orderId,
        details: reason.trim(),
      );
    }),
  );

  Future<void> forceOffline({
    required String courierId,
    required String adminId,
  }) => _adminAction(
    () => _db.runTransaction((transaction) async {
      final privateRef = _db.collection('couriers').doc(courierId);
      final publicRef = _db.collection('courier_public').doc(courierId);
      final courierDoc = await transaction.get(privateRef);
      if (!courierDoc.exists) {
        throw StateError('Курьер не найден.');
      }
      final update = {
        'isOnline': false,
        'online': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.update(privateRef, update);
      transaction.set(publicRef, update, SetOptions(merge: true));
      _writeLog(
        transaction,
        action: 'forceOffline',
        adminId: adminId,
        courierId: courierId,
      );
    }),
  );

  Future<void> clearActiveOrder({
    required String courierId,
    required String adminId,
  }) => _adminAction(
    () => _db.runTransaction((transaction) async {
      final courierRef = _db.collection('couriers').doc(courierId);
      final courierDoc = await transaction.get(courierRef);
      if (!courierDoc.exists ||
          (courierDoc.data()?['activeOrderId'] as String?) == null) {
        throw StateError('У курьера нет активного заказа.');
      }
      transaction.update(courierRef, {
        'activeOrderId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _writeLog(
        transaction,
        action: 'clearActiveOrder',
        adminId: adminId,
        courierId: courierId,
      );
    }),
  );

  Future<void> setAdminNote({
    required String orderId,
    required String adminId,
    required String note,
  }) => _adminAction(
    () => _db.runTransaction((transaction) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);
      if (!orderDoc.exists) throw StateError('Заказ не найден.');
      transaction.update(orderRef, {
        'adminNote': note.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _writeLog(
        transaction,
        action: 'setAdminNote',
        adminId: adminId,
        orderId: orderId,
        details: note.trim(),
      );
    }),
  );

  Future<int> cancelWaitingTestOrders({required String adminId}) async {
    final snapshot = await _db
        .collection('orders')
        .where('status', isEqualTo: 'waiting')
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
    await _adminAction(
      () => _db.runTransaction((transaction) async {
        final documents = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final ref in refs) {
          documents.add(await transaction.get(ref));
        }
        for (final doc in documents) {
          if (doc.data()?['status'] == 'waiting') {
            transaction.update(doc.reference, {
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelledReason': 'Debug cleanup',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
        _writeLog(
          transaction,
          action: 'cancelOrder',
          adminId: adminId,
          details: 'Debug cleanup: ${refs.length} waiting test orders',
        );
      }),
    );
    return refs.length;
  }

  void _writeLog(
    Transaction transaction, {
    required String action,
    required String adminId,
    String? orderId,
    String? courierId,
    String? details,
  }) {
    final log = <String, dynamic>{
      'action': action,
      'adminId': adminId,
      if (details != null && details.isNotEmpty) 'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (orderId != null) log['orderId'] = orderId;
    if (courierId != null) log['courierId'] = courierId;
    transaction.set(_db.collection('admin_logs').doc(), log);
  }

  Future<void> _adminAction(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw StateError(
          'Действие не выполнено: не хватает прав. '
          'Требуется обновление правил безопасности.',
        );
      }
      rethrow;
    }
  }
}
