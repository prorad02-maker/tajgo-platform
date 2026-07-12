import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tajgo_courier.dart';
import '../models/tajgo_order.dart';

class CourierRepository {
  CourierRepository(this._db);
  final FirebaseFirestore _db;

  Stream<TajGoCourier?> courierStream(String uid) => _db
      .collection('couriers')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? TajGoCourier.fromDoc(doc) : null);
  Stream<List<TajGoOrder>> waitingOrdersStream() => _db
      .collection('orders')
      .where('status', isEqualTo: 'waiting')
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map(TajGoOrder.fromDoc).toList());

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

  Future<void> updateLocation({
    required String uid,
    required double latitude,
    required double longitude,
  }) => _db.collection('couriers').doc(uid).set({
    'location': GeoPoint(latitude, longitude),
    'locationUpdatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  Stream<List<TajGoOrder>> activeCourierOrdersStream(String courierId) => _db
      .collection('orders')
      .where('courierId', isEqualTo: courierId)
      .limit(5)
      .snapshots()
      .map(
        (s) => s.docs
            .map(TajGoOrder.fromDoc)
            .where(
              (o) =>
                  o.status == OrderStatus.accepted ||
                  o.status == OrderStatus.pickedUp,
            )
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
      });
    }
    transaction.set(ref, data, SetOptions(merge: true));
  });

  Future<void> declineOrder({
    required String orderId,
    required String courierId,
  }) => _db.collection('orders').doc(orderId).update({
    'declinedBy': FieldValue.arrayUnion([courierId]),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  Future<void> acceptOrder({
    required String orderId,
    required String courierId,
  }) => _transition(
    orderId: orderId,
    courierId: courierId,
    from: 'waiting',
    to: 'accepted',
    accepting: true,
  );
  Future<void> markPickedUp({
    required String orderId,
    required String courierId,
  }) => _transition(
    orderId: orderId,
    courierId: courierId,
    from: 'accepted',
    to: 'pickedUp',
  );
  Future<void> markDelivered({
    required String orderId,
    required String courierId,
  }) => _transition(
    orderId: orderId,
    courierId: courierId,
    from: 'pickedUp',
    to: 'delivered',
  );

  Future<void> _transition({
    required String orderId,
    required String courierId,
    required String from,
    required String to,
    bool accepting = false,
  }) => _db.runTransaction((transaction) async {
    final ref = _db.collection('orders').doc(orderId);
    final doc = await transaction.get(ref);
    final data = doc.data();
    if (data?['status'] != from ||
        (!accepting && data?['courierId'] != courierId)) {
      throw StateError(
        accepting
            ? 'Заказ уже забрал другой курьер.'
            : 'Недопустимый переход статуса заказа.',
      );
    }
    transaction.update(ref, {
      'status': to,
      'courierId': courierId,
      if (accepting) 'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (to == 'delivered') {
      transaction.update(_db.collection('couriers').doc(courierId), {
        'earningsToday': FieldValue.increment((data?['price'] ?? 0) as num),
      });
    }
  });
}
