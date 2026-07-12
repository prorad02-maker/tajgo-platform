import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tajgo_courier.dart';
import '../models/tajgo_order.dart';
import 'pricing.dart';

class CourierRepository {
  CourierRepository(this._db);

  final FirebaseFirestore _db;

  Stream<TajGoCourier?> courierStream(String uid) => _db
      .collection('couriers')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? TajGoCourier.fromDoc(doc) : null);

  Stream<TajGoOrder?> orderStream(String orderId) => _db
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((doc) => doc.exists ? TajGoOrder.fromDoc(doc) : null);

  Stream<List<TajGoOrder>> waitingOrdersStream() => _db
      .collection('orders')
      .where('status', isEqualTo: 'waiting')
      .limit(10)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(TajGoOrder.fromDoc).toList());

  Stream<List<TajGoOrder>> activeCourierOrdersStream(String courierId) => _db
      .collection('orders')
      .where('courierId', isEqualTo: courierId)
      .limit(5)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(TajGoOrder.fromDoc)
            .where(
              (order) =>
                  order.status == OrderStatus.accepted ||
                  order.status == OrderStatus.pickedUp ||
                  order.status == OrderStatus.delivered,
            )
            .toList(),
      );

  Stream<List<TajGoCourier>> onlineCouriersStream() => _db
      .collection('couriers')
      .where('online', isEqualTo: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(TajGoCourier.fromDoc)
            .where((courier) => courier.location != null)
            .toList(),
      );

  Future<void> setOnline({
    required String uid,
    required bool online,
    required String name,
    required String city,
  }) => _db.runTransaction((transaction) async {
    final ref = _db.collection('couriers').doc(uid);
    final doc = await transaction.get(ref);
    final data = <String, dynamic>{
      'uid': uid,
      'name': name,
      'city': city,
      'online': online,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!doc.exists) {
      data.addAll({
        'rating': 5.0,
        'score': 100,
        'transport': 'electric_bike',
        'earningsToday': 0,
        'ordersToday': 0,
        'activeOrderId': null,
      });
    }
    transaction.set(ref, data, SetOptions(merge: true));
  });

  Future<void> updateLocation({
    required String uid,
    required double latitude,
    required double longitude,
  }) => _db.collection('couriers').doc(uid).set({
    'location': GeoPoint(latitude, longitude),
    'locationUpdatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> declineOrder({
    required String orderId,
    required String courierId,
  }) => _db.collection('orders').doc(orderId).update({
    'declinedBy': FieldValue.arrayUnion([courierId]),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Временный dev-reset для разблокировки курьера во время тестирования.
  Future<void> resetActiveOrderForTesting({required String courierId}) =>
      _db.runTransaction((transaction) async {
        final courierRef = _db.collection('couriers').doc(courierId);
        final courierDoc = await transaction.get(courierRef);
        final orderId = courierDoc.data()?['activeOrderId'] as String?;
        if (orderId == null) {
          throw StateError('У курьера нет активного тестового заказа.');
        }

        final orderRef = _db.collection('orders').doc(orderId);
        final orderDoc = await transaction.get(orderRef);

        transaction.update(courierRef, {
          'activeOrderId': null,
          'isBusy': false,
          'currentOrderId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (orderDoc.exists) {
          transaction.update(orderRef, {
            'status': 'waiting',
            'courierId': FieldValue.delete(),
            'courierName': FieldValue.delete(),
            'acceptedAt': FieldValue.delete(),
            'arrivedAtPickupAt': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

  Future<void> acceptOrder({
    required String orderId,
    required String courierId,
  }) => _db.runTransaction((transaction) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final courierRef = _db.collection('couriers').doc(courierId);
    final orderDoc = await transaction.get(orderRef);
    final courierDoc = await transaction.get(courierRef);
    if (courierDoc.data()?['activeOrderId'] != null) {
      throw StateError('Сначала завершите текущий заказ.');
    }
    if (orderDoc.data()?['status'] != 'waiting') {
      throw StateError('Заказ уже забрал другой курьер.');
    }
    transaction.update(orderRef, {
      'status': 'accepted',
      'courierId': courierId,
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    transaction.set(courierRef, {
      'activeOrderId': orderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });

  Future<void> markArrived({
    required String orderId,
    required String courierId,
  }) => _db.runTransaction((transaction) async {
    final ref = _db.collection('orders').doc(orderId);
    final doc = await transaction.get(ref);
    final data = doc.data();
    if (data?['status'] != 'accepted' || data?['courierId'] != courierId) {
      throw StateError('Отметить прибытие для этого заказа нельзя.');
    }
    transaction.update(ref, {
      'arrivedAtPickupAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  Future<void> markPickedUp({
    required String orderId,
    required String courierId,
    double? distanceToPointKm,
  }) async {
    _checkDistance(distanceToPointKm, 'точки забора');
    await _transition(
      orderId: orderId,
      courierId: courierId,
      from: 'accepted',
      to: 'pickedUp',
    );
  }

  Future<void> markDelivered({
    required String orderId,
    required String courierId,
    double? distanceToPointKm,
  }) async {
    _checkDistance(distanceToPointKm, 'точки доставки');
    await _transition(
      orderId: orderId,
      courierId: courierId,
      from: 'pickedUp',
      to: 'delivered',
    );
  }

  Future<void> completeWithCode({
    required String orderId,
    required String courierId,
    required String code,
    double? distanceToPointKm,
  }) async {
    _checkDistance(distanceToPointKm, 'точки доставки');
    await _db.runTransaction((transaction) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final courierRef = _db.collection('couriers').doc(courierId);
      final orderDoc = await transaction.get(orderRef);
      final data = orderDoc.data();
      if (data?['status'] != 'pickedUp' || data?['courierId'] != courierId) {
        throw StateError('Завершить этот заказ сейчас нельзя.');
      }
      final expectedCode = data?['confirmationCode'] as String?;
      if (expectedCode != null && code.trim() != expectedCode) {
        throw StateError('Код не совпадает. Уточните код у клиента.');
      }
      transaction.update(orderRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(courierRef, {
        'activeOrderId': null,
        'earningsToday': FieldValue.increment((data?['price'] ?? 0) as num),
        'ordersToday': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _transition({
    required String orderId,
    required String courierId,
    required String from,
    required String to,
  }) => _db.runTransaction((transaction) async {
    final ref = _db.collection('orders').doc(orderId);
    final doc = await transaction.get(ref);
    final data = doc.data();
    if (data?['status'] != from || data?['courierId'] != courierId) {
      throw StateError('Недопустимый переход статуса заказа.');
    }
    transaction.update(ref, {
      'status': to,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  void _checkDistance(double? kilometers, String pointName) {
    if (kilometers == null || withinActionRadius(kilometers)) {
      return;
    }
    throw StateError(
      'Вы слишком далеко от $pointName (${kilometers.toStringAsFixed(1)} км). '
      'Подойдите ближе.',
    );
  }
}
