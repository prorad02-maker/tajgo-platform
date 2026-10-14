import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
import 'package:tajgo/core/services/authoritative_command_service.dart';
import 'package:tajgo/core/services/compatible_command_gateway.dart';
import 'package:tajgo/core/services/order_command_service.dart';
import 'package:tajgo/core/services/order_repository.dart';
import 'package:tajgo/core/services/courier_repository.dart';
import 'package:tajgo/features/map/models/tajgo_route.dart';
import 'package:tajgo/features/map/services/server_road_route_provider.dart';

class Gateway implements AuthoritativeCommandGateway {
  final calls = <(String, Map<String, dynamic>)>[];
  Map<String, dynamic> result = {};
  @override
  String get region => 'europe-west1';
  @override
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, dynamic> data,
  ) async {
    calls.add((command, data));
    return result;
  }
}

class NoAccessFirestore extends Fake implements FirebaseFirestore {}

class Preferences implements SharedPreferencesAsync {
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('weak GPS is rejected before any write or metadata fallback', () async {
    final repository = CourierRepository(
      NoAccessFirestore(),
      AuthoritativeCommandService(Gateway()),
    );
    await expectLater(
      repository.updateLocation(
        uid: 'courier',
        latitude: 40.28,
        longitude: 69.62,
        accuracy: 300,
      ),
      throwsStateError,
    );
    await expectLater(
      repository.updateLocation(
        uid: 'courier',
        latitude: double.nan,
        longitude: 69.62,
        accuracy: 20,
      ),
      throwsStateError,
    );
  });
  test('idempotency keys preserve boundaries and use 128-bit hashes', () {
    final first = TajGoIdempotencyKey.stable('command', ['a:b', 'c']);
    final second = TajGoIdempotencyKey.stable('command', ['a', 'b:c']);
    expect(first, isNot(second));
    expect(first, matches(RegExp(r'^command-[a-f0-9]{32}-request$')));
    expect(first, TajGoIdempotencyKey.stable('command', ['a:b', 'c']));
  });
  const from = GeoPoint(40.2833, 69.6222), to = GeoPoint(40.2933, 69.6322);
  const geometry = [from, GeoPoint(40.288, 69.619), to];
  test('server quote retains road bends, distance and duration', () {
    const quote = ServerDeliveryQuote(
      status: 'ready',
      authoritative: true,
      geometry: geometry,
      distanceMeters: 3200,
      durationSeconds: 780,
    );
    final route = quote.roadRoute(from, to)!;
    expect(route.points.length, 3);
    expect(route.points[1], const LatLng(40.288, 69.619));
    expect(route.distanceKm, 3.2);
    expect(route.etaMinutes, 13);
    expect(route.routeQuality, RouteQuality.road);
  });
  test(
    'wrong endpoints and invalid metrics cannot be shown as a road route',
    () {
      const wrong = ServerDeliveryQuote(
        status: 'ready',
        authoritative: true,
        geometry: [GeoPoint(0, 0), GeoPoint(1, 1)],
        distanceMeters: 3200,
        durationSeconds: 780,
      );
      expect(wrong.roadRoute(from, to), isNull);
      const invalid = ServerDeliveryQuote(
        status: 'ready',
        authoritative: true,
        geometry: geometry,
        distanceMeters: double.nan,
        durationSeconds: 780,
      );
      expect(invalid.roadRoute(from, to), isNull);
      expect(
        ServerDeliveryQuote.parseGeometry([
          {'latitude': 91, 'longitude': 69},
          {'latitude': 40, 'longitude': 69},
        ]),
        isEmpty,
      );
    },
  );
  test(
    'server provider sends courier mode and rejects missing geometry',
    () async {
      final gateway = Gateway();
      final provider = ServerRoadRouteProvider(
        AuthoritativeCommandService(gateway),
      );
      await expectLater(
        provider.buildRoute(
          from: const LatLng(40.2833, 69.6222),
          to: const LatLng(40.2933, 69.6322),
          mode: RouteMode.car,
        ),
        throwsA(isA<TajGoCommandException>()),
      );
      expect(gateway.calls.single.$1, 'getRoadRoute');
      expect(gateway.calls.single.$2['transportMode'], 'driving');
    },
  );
  test(
    'existing server-v1 order actions retain the old endpoint and schema',
    () async {
      final gateway = Gateway();
      final legacyCalls = <Map<String, dynamic>>[];
      final legacy = OrderCommandService(
        currentUid: () => 'customer',
        preferences: Preferences(),
        transport: (data) async {
          legacyCalls.add(data);
          return {'orderId': 'order'};
        },
      );
      final compatible = CompatibleCommandGateway(
        gateway,
        legacy,
        (_) async => 'server-v1',
      );
      await compatible.call('selectCourierOffer', {
        'orderId': 'order',
        'offerId': 'courier',
        'idempotencyKey': 'new-format',
      });
      await compatible.call('updateDeliveryStatus', {
        'orderId': 'order',
        'action': 'customerConfirm',
      });
      await compatible.call('adminResolveDispute', {
        'orderId': 'order',
        'resolution': 'markDisputed',
        'reason': 'Проверка',
      });
      expect(legacyCalls.map((c) => c['action']), [
        'select',
        'confirm',
        'adminDispute',
      ]);
      expect(legacyCalls.first['offerId'], 'courier');
      expect(legacyCalls.first.containsKey('idempotencyKey'), isFalse);
      expect(legacyCalls.every((c) => c['requestId'] is String), isTrue);
      expect(gateway.calls, isEmpty);
    },
  );
  test('new orders and route requests keep the canonical endpoint', () async {
    final gateway = Gateway();
    final compatible = CompatibleCommandGateway(
      gateway,
      OrderCommandService(preferences: Preferences()),
      (_) async => null,
    );
    await compatible.call('selectCourierOffer', {
      'orderId': 'current',
      'offerId': 'courier',
    });
    await compatible.call('getRoadRoute', {
      'pickup': {'latitude': 40, 'longitude': 69},
    });
    expect(gateway.calls.map((c) => c.$1), [
      'selectCourierOffer',
      'getRoadRoute',
    ]);
  });
  test(
    'a failed legacy request never falls through to the new order endpoint',
    () async {
      final gateway = Gateway();
      final legacy = OrderCommandService(
        currentUid: () => 'customer',
        preferences: Preferences(),
        transport: (_) async => throw StateError('Сеть недоступна'),
      );
      final compatible = CompatibleCommandGateway(
        gateway,
        legacy,
        (_) async => 'server-v1',
      );
      await expectLater(
        compatible.call('cancelWaitingOrder', {'orderId': 'order'}),
        throwsStateError,
      );
      expect(gateway.calls, isEmpty);
    },
  );
  test('a settled dispute does not hide a newer active delivery', () {
    final settled = TajGoOrder(
      id: 'order',
      customerId: 'customer',
      customerName: 'Клиент',
      status: OrderStatus.disputed,
      type: 'package',
      city: 'Худжанд',
      fromText: 'A',
      toText: 'B',
      price: 20,
      currency: 'TJS',
      completedAt: DateTime.utc(2026),
    );
    expect(settled.isActive, isFalse);
    expect(orderStatusFromString('unrecognized-status'), OrderStatus.unknown);
  });
}
