import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajgo/core/services/order_command_service.dart';

class _Preferences implements SharedPreferencesAsync {
  _Preferences({this.failRemove = false});
  final values = <String, String>{};
  final bool failRemove;

  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async {
    if (failRemove) throw StateError('storage unavailable');
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test(
    'ambiguous network failure survives restart with the same request ID',
    () async {
      final preferences = _Preferences();
      final requests = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> transport(Map<String, dynamic> data) async {
        requests.add(data);
        if (requests.length == 1) throw TimeoutException('response lost');
        return {'orderId': 'order'};
      }

      OrderCommandService service() => OrderCommandService(
        preferences: preferences,
        currentUid: () => 'customer',
        transport: transport,
      );
      await expectLater(
        service().run('create', {'price': 20}),
        throwsA(isA<TimeoutException>()),
      );
      expect(await service().run('create', {'price': 20}), {
        'orderId': 'order',
      });
      expect(requests[1]['requestId'], requests[0]['requestId']);
      expect(preferences.values, isEmpty);
    },
  );

  test('simultaneous identical requests use one transport call', () async {
    final response = Completer<Map<String, dynamic>>();
    var calls = 0;
    final service = OrderCommandService(
      preferences: _Preferences(),
      currentUid: () => 'customer',
      transport: (_) {
        calls++;
        return response.future;
      },
    );
    final first = service.run('select', {
      'orderId': 'order',
      'offerId': 'courier',
    });
    final second = service.run('select', {
      'offerId': 'courier',
      'orderId': 'order',
    });
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    response.complete({'orderId': 'order'});
    expect(await first, await second);
  });

  test(
    'nested payload key order cannot bypass persistent deduplication',
    () async {
      final preferences = _Preferences();
      final ids = <String>[];
      final service = OrderCommandService(
        preferences: preferences,
        currentUid: () => 'customer',
        transport: (data) async {
          ids.add(data['requestId'] as String);
          throw TimeoutException('lost response');
        },
      );
      await expectLater(
        service.run('create', {
          'dropoff': {'address': 'Дом', 'latitude': 40.2},
        }),
        throwsA(isA<TimeoutException>()),
      );
      await expectLater(
        service.run('create', {
          'dropoff': {'latitude': 40.2, 'address': 'Дом'},
        }),
        throwsA(isA<TimeoutException>()),
      );
      expect(ids[0], ids[1]);
    },
  );

  test('pending commands are isolated by account', () async {
    var uid = 'first';
    final ids = <String>[];
    final service = OrderCommandService(
      preferences: _Preferences(),
      currentUid: () => uid,
      transport: (data) async {
        ids.add(data['requestId'] as String);
        throw TimeoutException('lost response');
      },
    );
    await expectLater(
      service.run('create', {'price': 20}),
      throwsA(isA<TimeoutException>()),
    );
    uid = 'second';
    await expectLater(
      service.run('create', {'price': 20}),
      throwsA(isA<TimeoutException>()),
    );
    expect(ids[0], isNot(ids[1]));
  });

  test('server success remains successful when local cleanup fails', () async {
    final preferences = _Preferences(failRemove: true);
    final ids = <String>[];
    final service = OrderCommandService(
      preferences: preferences,
      currentUid: () => 'customer',
      transport: (data) async {
        ids.add(data['requestId'] as String);
        return {'orderId': 'order'};
      },
    );
    expect(await service.run('create', {'price': 20}), {'orderId': 'order'});
    expect(await service.run('create', {'price': 20}), {'orderId': 'order'});
    expect(ids[0], ids[1]);
  });

  test(
    'explicit server rejection releases the request for a corrected retry',
    () async {
      final preferences = _Preferences();
      final service = OrderCommandService(
        preferences: preferences,
        currentUid: () => 'customer',
        transport: (_) async => throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Цена товара изменилась.',
        ),
      );
      await expectLater(
        service.run('checkout', {'partnerId': 'shop'}),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Цена товара изменилась.',
          ),
        ),
      );
      expect(preferences.values, isEmpty);
    },
  );
}
