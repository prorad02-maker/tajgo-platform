import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/tajgo_courier.dart';
import '../models/tajgo_order.dart';
import 'authoritative_command_service.dart';

class CourierRepository {
  CourierRepository(this._db, this._commands);

  final FirebaseFirestore _db;
  final AuthoritativeCommandService _commands;
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
  }) async {
    await _commands.call('ensureCourierProfile', {
      'idempotencyKey': TajGoIdempotencyKey.stable('ensure-courier-profile', [
        uid,
      ]),
    });
  }

  Future<void> setOnline({
    required String uid,
    required bool online,
    required String name,
    required String city,
    String? phoneNumber,
  }) async {
    final existing = await _db.collection('couriers').doc(uid).get();
    if (!existing.exists) {
      await ensureCourierProfile(
        uid: uid,
        displayName: name,
        phoneNumber: phoneNumber,
        city: city,
      );
    }
    await _db.runTransaction((transaction) async {
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
      if (!doc.exists) {
        throw StateError('Профиль курьера не найден.');
      }
      final data = <String, dynamic>{
        'isOnline': online,
        'online': online,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.update(ref, data);
      transaction.set(publicRef, {
        'isOnline': online,
        'online': online,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

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

  /// Emulator-only recovery for test orders. Production orders are never
  /// reset by the mobile client.
  Future<void> resetActiveOrderForTesting({required String courierId}) async {
    if (!kDebugMode) {
      throw StateError('Dev-reset доступен только в debug-сборке.');
    }
    await _commands.call('resetTestOrderForCourier', {
      'idempotencyKey': TajGoIdempotencyKey.create(
        'reset-test-order-$courierId',
      ),
    });
  }

  Future<void> markArrived({
    required String orderId,
    required String courierId,
    double? distanceToPointKm,
  }) async {
    await _commands.call('updateDeliveryStatus', {
      'orderId': orderId,
      'action': 'arrivedPickup',
      'idempotencyKey': TajGoIdempotencyKey.stable('arrived-pickup', [
        orderId,
        courierId,
      ]),
    });
  }

  Future<void> markPickedUp({
    required String orderId,
    required String courierId,
    double? distanceToPointKm,
  }) async {
    await _commands.call('updateDeliveryStatus', {
      'orderId': orderId,
      'action': 'pickedUp',
      'idempotencyKey': TajGoIdempotencyKey.stable('picked-up', [
        orderId,
        courierId,
      ]),
    });
  }

  Future<void> markDelivered({
    required String orderId,
    required String courierId,
    double? distanceToPointKm,
  }) async {
    await _commands.call('updateDeliveryStatus', {
      'orderId': orderId,
      'action': 'delivered',
      'idempotencyKey': TajGoIdempotencyKey.stable('delivered', [
        orderId,
        courierId,
      ]),
    });
  }

  Future<void> completeWithCode({
    required String orderId,
    required String courierId,
    required String code,
    double? distanceToPointKm,
  }) async {
    await _commands.call('completeDeliveryWithCode', {
      'orderId': orderId,
      'code': code.trim(),
      'idempotencyKey': TajGoIdempotencyKey.create(
        'complete-code-$orderId-$courierId',
      ),
    });
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
