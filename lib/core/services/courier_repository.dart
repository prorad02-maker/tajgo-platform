import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/tajgo_courier.dart';
import '../models/tajgo_order.dart';
import 'courier_order_eligibility.dart';
import 'pricing.dart';

class CourierRepository {
  CourierRepository(this._db);

  final FirebaseFirestore _db;
  final Map<String, _PublishedLocation> _lastPublishedLocations = {};
  final Map<String, Future<void>> _locationWrites = {};

  static const _locationWriteInterval = Duration(seconds: 7);
  static const _significantMovementMeters = 15.0;

  Stream<TajGoCourier?> courierStream(String uid) => _db
      .collection('couriers')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? TajGoCourier.fromDoc(doc) : null);

  Future<TajGoCourier?> getCourier(String uid) async {
    final doc = await _db.collection('couriers').doc(uid).get();
    return doc.exists ? TajGoCourier.fromDoc(doc) : null;
  }

  Stream<TajGoCourier?> publicCourierStream(String uid) => _db
      .collection('courier_public')
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
      .where('status', whereIn: const ['waiting', 'waitingOffers'])
      .limit(50)
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
      .collection('courier_public')
      .where('isOnline', isEqualTo: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(TajGoCourier.fromDoc)
            .where((courier) => courier.location != null)
            .toList(),
      );

  Future<void> ensureCourierProfile({
    required String uid,
    required String displayName,
    String? phoneNumber,
    String city = 'Худжанд',
  }) => _db.runTransaction((transaction) async {
    final ref = _db.collection('couriers').doc(uid);
    final publicRef = _db.collection('courier_public').doc(uid);
    final userRef = _db.collection('users').doc(uid);
    final snapshots = await Future.wait([
      transaction.get(userRef),
      transaction.get(ref),
    ]);
    final account = snapshots[0].data();
    if (account?['courierStatus'] != 'approved' ||
        account?['courierOnboardingCompleted'] != true) {
      throw StateError('Курьерский режим недоступен до одобрения заявки.');
    }
    final doc = snapshots[1];
    final existing = doc.data() ?? const <String, dynamic>{};
    final online =
        existing['isOnline'] as bool? ?? existing['online'] as bool? ?? false;
    transaction.set(ref, {
      'uid': uid,
      'phoneNumber': phoneNumber ?? existing['phoneNumber'],
      'displayName': displayName,
      // Legacy fields keep the live v0.4.0 queries and UI working.
      'name': displayName,
      'city': city,
      'isOnline': online,
      'online': online,
      'rating': existing['rating'] ?? 5.0,
      'score': existing['score'] ?? 100,
      'transport': existing['transport'] ?? 'bicycle',
      'earningsToday': existing['earningsToday'] ?? 0,
      'ordersToday': existing['ordersToday'] ?? 0,
      'activeOrderId': existing['activeOrderId'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    transaction.set(publicRef, {
      'uid': uid,
      'displayName': displayName,
      'name': displayName,
      'isOnline': online,
      'online': online,
      'rating': existing['rating'] ?? 5.0,
      'transport': existing['transport'] ?? 'electric_bike',
      if (existing['location'] != null) 'location': existing['location'],
      if (existing['locationUpdatedAt'] != null)
        'locationUpdatedAt': existing['locationUpdatedAt'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });

  Future<void> setOnline({
    required String uid,
    required bool online,
    required String name,
    required String city,
    String? phoneNumber,
  }) => _db.runTransaction((transaction) async {
    final ref = _db.collection('couriers').doc(uid);
    final publicRef = _db.collection('courier_public').doc(uid);
    final userRef = _db.collection('users').doc(uid);
    final snapshots = await Future.wait([
      transaction.get(userRef),
      transaction.get(ref),
    ]);
    final account = snapshots[0].data();
    if (account?['courierStatus'] != 'approved' ||
        account?['courierOnboardingCompleted'] != true) {
      throw StateError('Курьерский режим недоступен до одобрения заявки.');
    }
    final doc = snapshots[1];
    final data = <String, dynamic>{
      'uid': uid,
      'phoneNumber': phoneNumber,
      'displayName': name,
      'name': name,
      'city': city,
      'isOnline': online,
      'online': online,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!doc.exists) {
      data.addAll({
        'rating': 5.0,
        'score': 100,
        'transport': 'bicycle',
        'earningsToday': 0,
        'ordersToday': 0,
        'activeOrderId': null,
      });
    }
    transaction.set(ref, data, SetOptions(merge: true));
    transaction.set(publicRef, {
      'uid': uid,
      'displayName': name,
      'name': name,
      'isOnline': online,
      'online': online,
      'rating': doc.data()?['rating'] ?? 5.0,
      'transport': doc.data()?['transport'] ?? 'electric_bike',
      if (doc.data()?['location'] != null) 'location': doc.data()?['location'],
      if (doc.data()?['locationUpdatedAt'] != null)
        'locationUpdatedAt': doc.data()?['locationUpdatedAt'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });

  Future<void> updateLocation({
    required String uid,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
    bool force = false,
  }) async {
    final pendingWrite = _locationWrites[uid];
    if (pendingWrite != null) {
      return pendingWrite;
    }
    final now = DateTime.now();
    final previous = _lastPublishedLocations[uid];
    if (!force && previous != null) {
      final elapsed = now.difference(previous.writtenAt);
      final moved = _distanceMeters(
        previous.latitude,
        previous.longitude,
        latitude,
        longitude,
      );
      if (elapsed < _locationWriteInterval &&
          moved < _significantMovementMeters) {
        return;
      }
    }

    final write = _writeLocation(
      uid: uid,
      latitude: latitude,
      longitude: longitude,
      heading: heading,
      speed: speed,
      accuracy: accuracy,
    );
    _locationWrites[uid] = write;
    try {
      await write;
      _lastPublishedLocations[uid] = _PublishedLocation(
        latitude: latitude,
        longitude: longitude,
        writtenAt: now,
      );
    } finally {
      _locationWrites.remove(uid);
    }
  }

  Future<void> _writeLocation({
    required String uid,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
  }) async {
    final location = GeoPoint(latitude, longitude);
    final privateRef = _db.collection('couriers').doc(uid);
    final publicRef = _db.collection('courier_public').doc(uid);
    final coreData = <String, dynamic>{
      'location': location,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final telemetryData = <String, dynamic>{
      ...coreData,
      if (heading != null && heading.isFinite && heading >= 0)
        'heading': heading,
      if (speed != null && speed.isFinite && speed >= 0) 'speed': speed,
      if (accuracy != null && accuracy.isFinite && accuracy >= 0)
        'locationAccuracy': accuracy,
    };

    Future<void> commit(Map<String, dynamic> data) async {
      final batch = _db.batch();
      batch.set(privateRef, data, SetOptions(merge: true));
      batch.set(publicRef, data, SetOptions(merge: true));
      await batch.commit();
    }

    try {
      await commit(telemetryData);
    } on FirebaseException catch (error) {
      // Previously deployed rules may not know the optional navigation
      // telemetry fields yet. Keep live GPS working until the new rules are
      // deployed, then richer heading/speed data starts flowing automatically.
      if (error.code != 'permission-denied') rethrow;
      await commit(coreData);
    }
  }

  double _distanceMeters(
    double fromLatitude,
    double fromLongitude,
    double toLatitude,
    double toLongitude,
  ) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = fromLatitude * math.pi / 180;
    final lat2 = toLatitude * math.pi / 180;
    final deltaLat = (toLatitude - fromLatitude) * math.pi / 180;
    final deltaLng = (toLongitude - fromLongitude) * math.pi / 180;
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> declineOrder({
    required String orderId,
    required String courierId,
  }) => _db.collection('orders').doc(orderId).update({
    'declinedBy': FieldValue.arrayUnion([courierId]),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Временный dev-reset для разблокировки курьера во время тестирования.
  Future<void> resetActiveOrderForTesting({required String courierId}) async {
    if (!kDebugMode) {
      throw StateError('Dev-reset доступен только в debug-сборке.');
    }
    await _db.runTransaction((transaction) async {
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
          'status': 'waitingOffers',
          'courierId': FieldValue.delete(),
          'courierName': FieldValue.delete(),
          'selectedCourierId': FieldValue.delete(),
          'selectedOfferId': FieldValue.delete(),
          'finalPrice': FieldValue.delete(),
          'acceptedAt': FieldValue.delete(),
          'arrivedAtPickupAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> acceptOrder({
    required String orderId,
    required String courierId,
  }) => _db.runTransaction((transaction) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final courierRef = _db.collection('couriers').doc(courierId);
    final orderDoc = await transaction.get(orderRef);
    final courierDoc = await transaction.get(courierRef);
    final courier = courierDoc.data();
    final order = orderDoc.data();
    if (courier == null || order == null) {
      throw StateError('Заказ или профиль курьера не найден.');
    }
    final pickup = order['fromLocation'] as GeoPoint?;
    final location = courier['location'] as GeoPoint?;
    if (pickup == null) throw StateError('У заказа не указана точка забора.');
    final eligibility = const CourierOrderEligibilityService().evaluate(
      courierLocation: location == null
          ? null
          : LatLng(location.latitude, location.longitude),
      locationUpdatedAt: (courier['locationUpdatedAt'] as Timestamp?)?.toDate(),
      accuracyMeters: (courier['locationAccuracy'] as num?)?.toDouble(),
      pickup: LatLng(pickup.latitude, pickup.longitude),
      hasActiveOrder:
          courier['activeOrderId'] != null || courier['isBusy'] == true,
    );
    if (!eligibility.allowed) throw StateError(eligibility.message);
    if (!{'waiting', 'waitingOffers'}.contains(order['status']) ||
        order['courierId'] != null ||
        order['selectedCourierId'] != null) {
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
      'isBusy': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });

  Future<void> markArrived({
    required String orderId,
    required String courierId,
    double? distanceToPointKm,
  }) async {
    _checkDistance(distanceToPointKm, 'точки забора');
    await _db.runTransaction((transaction) async {
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
  }

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
        'isBusy': false,
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
    if (kilometers == null) {
      throw StateError(
        'Не удалось определить GPS. Разрешите геолокацию и повторите.',
      );
    }
    if (withinActionRadius(kilometers)) {
      return;
    }
    throw StateError(
      'Вы слишком далеко от $pointName (${kilometers.toStringAsFixed(1)} км). '
      'Подойдите ближе.',
    );
  }
}

class _PublishedLocation {
  const _PublishedLocation({
    required this.latitude,
    required this.longitude,
    required this.writtenAt,
  });

  final double latitude;
  final double longitude;
  final DateTime writtenAt;
}
