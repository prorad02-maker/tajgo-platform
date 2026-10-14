import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajgo/app/tajgo_bootstrap.dart';
import 'package:tajgo/app/tajgo_theme.dart';
import 'package:tajgo/core/services/diagnostic_service.dart';
import 'package:tajgo/core/services/order_notification_service.dart';
import 'package:tajgo/features/account/reliability_settings_panel.dart';

// Mutable storage-failure switches exercise the SDK shutdown path.
// ignore: must_be_immutable
class Preferences implements SharedPreferencesAsync {
  final values = <String, bool>{};
  bool readFails = false, writeFails = false;
  @override
  Future<bool?> getBool(String key) async {
    if (readFails) throw StateError('read failure');
    return values[key];
  }

  @override
  Future<void> setBool(String key, bool value) async {
    if (writeFails) throw StateError('write failure');
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class Messaging implements OrderMessagingPort {
  final tokenEvents = StreamController<String>.broadcast(sync: true);
  final messages = StreamController<OrderNotification>.broadcast(sync: true);
  final taps = StreamController<OrderNotification>.broadcast(sync: true);
  final auto = <bool>[];
  bool permitted = true, deletionFails = false;
  int permissionRequests = 0, tokenRequests = 0, deletions = 0;
  String tokenValue = 'test-registration-token-aaaaaaaaaaaa';
  Future<String?> Function()? readToken;
  OrderNotification? initial;
  @override
  Future<void> autoInit(bool enabled) async {
    auto.add(enabled);
  }

  @override
  Future<bool> permission({bool request = false}) async {
    if (request) permissionRequests++;
    return permitted;
  }

  @override
  Future<String?> token() async {
    tokenRequests++;
    return readToken != null ? await readToken!() : tokenValue;
  }

  @override
  Future<void> deleteToken() async {
    deletions++;
    if (deletionFails) throw StateError('native deletion failed');
  }

  @override
  Future<OrderNotification?> initialMessage() async => initial;
  @override
  Stream<String> get tokenRefresh => tokenEvents.stream;
  @override
  Stream<OrderNotification> get foreground => messages.stream;
  @override
  Stream<OrderNotification> get opened => taps.stream;
  Future<void> close() async {
    await tokenEvents.close();
    await messages.close();
    await taps.close();
  }
}

class Diagnostics implements DiagnosticPort {
  final collections = <bool>[], records = <String>[], stacks = <StackTrace>[];
  int deletions = 0;
  bool deletionFails = false;
  @override
  Future<void> collection(bool enabled) async {
    collections.add(enabled);
  }

  @override
  Future<void> deleteUnsent() async {
    deletions++;
    if (deletionFails) throw StateError('storage failure');
  }

  @override
  Future<void> record(
    String type,
    StackTrace stack, {
    required bool fatal,
  }) async {
    records.add(type);
    stacks.add(stack);
  }
}

const notice = OrderNotification(
  orderId: 'order',
  recipientId: 'customer',
  kind: 'delivered',
  eventId: 'event-1',
);
void main() {
  late Preferences preferences;
  late Messaging messaging;
  late StreamController<String?> auth;
  late OrderNotificationService service;
  late List<Map<String, dynamic>> requests;
  String? uid;
  bool networkFails = false;
  setUp(() {
    uid = 'customer';
    networkFails = false;
    preferences = Preferences();
    messaging = Messaging();
    requests = [];
    auth = StreamController<String?>.broadcast(sync: true);
    service = OrderNotificationService(
      preferences: preferences,
      messaging: messaging,
      supported: true,
      currentUid: () => uid,
      authChanges: auth.stream,
      transport: (data) async {
        requests.add(Map.of(data));
        if (networkFails) throw TimeoutException('private backend details');
        return {
          'accountId': data['accountId'],
          'registered': data['enabled'],
          'registrationId': data['registrationId'],
        };
      },
    );
  });
  tearDown(() async {
    service.dispose();
    await auth.close();
    await messaging.close();
  });
  test('no consent means no permission prompt or token registration', () async {
    await service.initialize();
    expect(service.enabled, false);
    expect(messaging.permissionRequests, 0);
    expect(messaging.tokenRequests, 0);
    expect(requests, isEmpty);
    expect(messaging.auto, everyElement(false));
  });
  test(
    'notification payload must identify the account, order and a known event',
    () {
      expect(
        OrderNotification.parse({
          'type': 'order',
          'recipientId': 'customer',
          'orderId': '../foreign',
          'kind': 'delivered',
          'eventId': 'e',
        }),
        isNull,
      );
      expect(
        OrderNotification.parse({
          'type': 'order',
          'recipientId': 'customer',
          'orderId': 'order',
          'kind': 'unknown',
          'eventId': 'e',
        }),
        isNull,
      );
      expect(
        OrderNotification.parse({
          'type': 'order',
          'recipientId': 'customer',
          'orderId': 'order',
          'kind': 'delivered',
          'eventId': 'e',
          'title': 'PRIVATE ADDRESS',
        })!.title,
        'Заказ доставлен',
      );
    },
  );
  test(
    'permission refusal creates no device and can recover after a settings change',
    () async {
      await service.initialize();
      messaging.permitted = false;
      await service.setEnabled(true);
      expect(service.permissionDenied, true);
      expect(service.enabled, false);
      expect(requests, isEmpty);
      messaging.permitted = true;
      await service.refresh();
      expect(service.enabled, true);
      expect(requests.last['enabled'], true);
    },
  );
  test(
    'a network failure retains consent and retry registers the same account',
    () async {
      await service.initialize();
      networkFails = true;
      await service.setEnabled(true);
      expect(service.enabled, false);
      expect(service.error, isNotNull);
      expect(service.error, isNot(contains('private backend')));
      networkFails = false;
      await service.refresh();
      expect(service.enabled, true);
      expect(requests.last['accountId'], 'customer');
    },
  );
  test('token refresh replaces the registered device token', () async {
    await service.initialize();
    await service.setEnabled(true);
    messaging.tokenValue = 'test-registration-token-bbbbbbbbbbbb';
    messaging.tokenEvents.add(messaging.tokenValue);
    await service.refresh();
    expect(requests.last['token'], messaging.tokenValue);
    expect(service.enabled, true);
  });
  test(
    'logout unregisters using the active registration and disables future collection',
    () async {
      await service.initialize();
      await service.setEnabled(true);
      final registration = requests.last['registrationId'];
      await service.beforeSignOut();
      expect(service.enabled, false);
      expect(requests.last['enabled'], false);
      expect(requests.last['registrationId'], registration);
      expect(
        preferences.values[OrderNotificationService.preferenceKey('customer')],
        false,
      );
    },
  );
  test(
    'disabling notifications stops collection even if saving fails',
    () async {
      await service.initialize();
      await service.setEnabled(true);
      preferences.writeFails = true;
      await service.setEnabled(false);
      expect(service.enabled, isFalse);
      expect(messaging.auto.last, isFalse);
      expect(requests.last['enabled'], isFalse);
    },
  );
  test('logout removes the device even if saving consent fails', () async {
    await service.initialize();
    await service.setEnabled(true);
    preferences.writeFails = true;
    await service.beforeSignOut();
    expect(service.enabled, isFalse);
    expect(messaging.auto.last, isFalse);
    expect(requests.last['enabled'], isFalse);
  });
  test(
    'native token deletion failure still unregisters the server device',
    () async {
      await service.initialize();
      await service.setEnabled(true);
      messaging.deletionFails = true;
      await service.setEnabled(false);
      expect(service.enabled, false);
      expect(requests.last['enabled'], false);
    },
  );
  test(
    'an old GPS-independent registration cannot enable notifications for another account',
    () async {
      await service.initialize();
      final pendingToken = Completer<String?>(), started = Completer<void>();
      messaging.readToken = () {
        started.complete();
        return pendingToken.future;
      };
      final enabling = service.setEnabled(true);
      await started.future;
      uid = 'other';
      auth.add(uid);
      pendingToken.complete('test-old-account-token-xxxx');
      await enabling;
      await service.refresh();
      expect(service.enabled, false);
      expect(requests.where((data) => data['enabled'] == true), isEmpty);
      expect(
        preferences.values[OrderNotificationService.preferenceKey('other')],
        isNull,
      );
    },
  );
  test(
    'foreground ignores another account and suppresses duplicate events',
    () async {
      await service.initialize();
      await service.setEnabled(true);
      final seen = <OrderNotification>[];
      final subscription = service.foreground.listen(seen.add);
      messaging.messages.add(
        const OrderNotification(
          orderId: 'foreign',
          recipientId: 'other',
          kind: 'delivered',
          eventId: 'foreign-event',
        ),
      );
      messaging.messages.add(notice);
      messaging.messages.add(notice);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [notice]);
      await subscription.cancel();
    },
  );
  test('a cold-start tap survives delayed auth restoration', () async {
    uid = null;
    messaging.initial = notice;
    final opened = <OrderNotification>[];
    final subscription = service.opened.listen(opened.add);
    await service.initialize();
    service.navigationReady();
    await Future<void>.delayed(Duration.zero);
    expect(opened, isEmpty);
    uid = 'customer';
    auth.add(uid);
    service.navigationReady();
    await Future<void>.delayed(Duration.zero);
    expect(opened, [notice]);
    await subscription.cancel();
  });
  test('a delayed cold-start tap is discarded for another account', () async {
    uid = null;
    messaging.initial = notice;
    final opened = <OrderNotification>[];
    final subscription = service.opened.listen(opened.add);
    await service.initialize();
    uid = 'courier';
    auth.add(uid);
    service.navigationReady();
    await Future<void>.delayed(Duration.zero);
    expect(opened, isEmpty);
    await subscription.cancel();
  });
  test(
    'a cold-start tap waits for account navigation and stale-account taps are ignored',
    () async {
      messaging.initial = notice;
      final opened = <OrderNotification>[];
      final subscription = service.opened.listen(opened.add);
      await service.initialize();
      expect(opened, isEmpty);
      service.navigationReady();
      await Future<void>.delayed(Duration.zero);
      expect(opened, [notice]);
      uid = 'other';
      auth.add(uid);
      messaging.taps.add(notice);
      service.navigationReady();
      await service.refresh();
      expect(opened, [notice]);
      await subscription.cancel();
    },
  );
  test(
    'diagnostics are opt-in and redact exception messages and arbitrary stack text',
    () async {
      final port = Diagnostics();
      final diagnostic = DiagnosticService(
        preferences: preferences,
        port: port,
        supported: true,
        release: true,
      );
      await diagnostic.initialize();
      await diagnostic.record(
        StateError('+992900000001 PRIVATE ADDRESS'),
        StackTrace.current,
      );
      expect(port.records, isEmpty);
      expect(port.collections, [false, false]);
      await diagnostic.setEnabled(true);
      await diagnostic.record(
        StateError('+992900000001 PRIVATE ADDRESS'),
        StackTrace.fromString(
          '#0 Delivery.fail (package:tajgo/delivery.dart:12:4)\nPRIVATE ADDRESS https://example.com/?phone=992900000001',
        ),
      );
      expect(port.records, ['StateError']);
      expect(port.stacks.single.toString(), contains('delivery.dart:12:4'));
      expect(port.stacks.single.toString(), isNot(contains('PRIVATE')));
      await diagnostic.setEnabled(false);
      await diagnostic.record(StateError('private'), StackTrace.current);
      expect(port.records, hasLength(1));
      diagnostic.dispose();
    },
  );
  test(
    'failed cleanup cannot persist permission to send reports produced before consent',
    () async {
      final port = Diagnostics()..deletionFails = true;
      final diagnostic = DiagnosticService(
        preferences: preferences,
        port: port,
        supported: true,
        release: true,
      );
      await diagnostic.setEnabled(true);
      expect(diagnostic.enabled, false);
      expect(preferences.values[DiagnosticService.preferenceKey], isNull);
      expect(port.collections, isEmpty);
      diagnostic.dispose();
    },
  );
  test(
    'debug builds never upload diagnostics even with saved consent',
    () async {
      preferences.values[DiagnosticService.preferenceKey] = true;
      final port = Diagnostics();
      final diagnostic = DiagnosticService(
        preferences: preferences,
        port: port,
        supported: true,
        release: false,
      );
      await diagnostic.initialize();
      await diagnostic.record(StateError('private'), StackTrace.current);
      expect(port.collections, [false, false]);
      expect(port.records, isEmpty);
      diagnostic.dispose();
    },
  );
  test(
    'storage failure disables reporting before reading saved consent',
    () async {
      final port = Diagnostics();
      preferences.readFails = true;
      final diagnostic = DiagnosticService(
        preferences: preferences,
        port: port,
        supported: true,
        release: true,
      );
      await diagnostic.initialize();
      expect(port.collections, [false]);
      expect(diagnostic.enabled, isFalse);
      diagnostic.dispose();
    },
  );
  test(
    'turning reporting off stops the SDK even if saving consent fails',
    () async {
      final port = Diagnostics();
      final diagnostic = DiagnosticService(
        preferences: preferences,
        port: port,
        supported: true,
        release: true,
      );
      await diagnostic.setEnabled(true);
      preferences.writeFails = true;
      await diagnostic.setEnabled(false);
      expect(port.collections.last, isFalse);
      expect(diagnostic.enabled, isFalse);
      diagnostic.dispose();
    },
  );
  testWidgets(
    'startup failure shows a safe retry screen and a second attempt opens the app',
    (tester) async {
      int attempts = 0;
      final diagnostic = DiagnosticService(
        supported: false,
        preferences: preferences,
      );
      await tester.pumpWidget(
        TajGoBootstrap(
          diagnostics: diagnostic,
          initialize: () async {
            if (++attempts == 1) throw StateError('PRIVATE CONFIGURATION');
          },
          ready: const MaterialApp(
            home: Scaffold(body: Text('Приложение готово')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Не удалось запустить TajGo'), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Приложение готово'), findsOneWidget);
      expect(attempts, 2);
      await tester.pumpWidget(const SizedBox());
      diagnostic.dispose();
    },
  );
  testWidgets(
    'permission and reporting settings fit a small phone with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final diagnostic = DiagnosticService(
        port: Diagnostics(),
        preferences: preferences,
        supported: true,
        release: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: TajGoTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [
                ReliabilitySettingsPanel(
                  notifications: service,
                  diagnostics: diagnostic,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Уведомления о заказах'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      diagnostic.dispose();
    },
  );
}
