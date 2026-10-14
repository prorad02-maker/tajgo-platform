import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderNotification {
  const OrderNotification({
    required this.orderId,
    required this.recipientId,
    required this.kind,
    required this.eventId,
  });
  final String orderId, recipientId, kind, eventId;
  static const titles = <String, String>{
    'assigned': 'Курьер выбран',
    'selected': 'Вас выбрали для доставки',
    'arrived': 'Курьер прибыл',
    'pickedUp': 'Заказ в пути',
    'delivered': 'Заказ доставлен',
    'completed': 'Заказ завершён',
    'cancelled': 'Заказ отменён',
    'disputed': 'Заказ на проверке',
    'reassigned': 'Снова ищем курьера',
    'removed': 'Назначение изменилось',
    'offer': 'Новое предложение курьера',
  };
  String get title => titles[kind] ?? 'Заказ обновлён';
  static OrderNotification? parse(Map<String, dynamic> data) {
    bool id(Object? value) =>
        value is String && RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(value);
    if (data['type'] != 'order' ||
        !id(data['orderId']) ||
        !id(data['recipientId']) ||
        !id(data['eventId']) ||
        !titles.containsKey(data['kind'])) {
      return null;
    }
    return OrderNotification(
      orderId: data['orderId'] as String,
      recipientId: data['recipientId'] as String,
      kind: data['kind'] as String,
      eventId: data['eventId'] as String,
    );
  }
}

abstract interface class OrderMessagingPort {
  Future<void> autoInit(bool enabled);
  Future<bool> permission({bool request = false});
  Future<String?> token();
  Future<void> deleteToken();
  Future<OrderNotification?> initialMessage();
  Stream<String> get tokenRefresh;
  Stream<OrderNotification> get foreground;
  Stream<OrderNotification> get opened;
}

class FirebaseOrderMessaging implements OrderMessagingPort {
  FirebaseMessaging get _sdk => FirebaseMessaging.instance;
  @override
  Future<void> autoInit(bool enabled) => _sdk.setAutoInitEnabled(enabled);
  @override
  Future<bool> permission({bool request = false}) async {
    final value = request
        ? await _sdk.requestPermission()
        : await _sdk.getNotificationSettings();
    return value.authorizationStatus == AuthorizationStatus.authorized ||
        value.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() => _sdk.getToken();
  @override
  Future<void> deleteToken() => _sdk.deleteToken();
  @override
  Future<OrderNotification?> initialMessage() async =>
      OrderNotification.parse((await _sdk.getInitialMessage())?.data ?? {});
  @override
  Stream<String> get tokenRefresh => _sdk.onTokenRefresh;
  Stream<OrderNotification> _map(Stream<RemoteMessage> values) => values
      .map((value) => OrderNotification.parse(value.data))
      .where((value) => value != null)
      .cast<OrderNotification>();
  @override
  Stream<OrderNotification> get foreground => _map(FirebaseMessaging.onMessage);
  @override
  Stream<OrderNotification> get opened =>
      _map(FirebaseMessaging.onMessageOpenedApp);
}

typedef NotificationDeviceTransport =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

/// Consent is per account on this phone. The server owns token associations;
/// an obsolete registration/sign-out cannot change a newer account's device.
class OrderNotificationService extends ChangeNotifier {
  OrderNotificationService({
    OrderMessagingPort? messaging,
    NotificationDeviceTransport? transport,
    SharedPreferencesAsync? preferences,
    String? Function()? currentUid,
    this.authChanges,
    bool? supported,
    this.allowed = true,
  }) : _messaging = messaging ?? FirebaseOrderMessaging(),
       _transport = transport ?? _call,
       _preferences = preferences ?? SharedPreferencesAsync(),
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       supported =
           supported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  final OrderMessagingPort _messaging;
  final NotificationDeviceTransport _transport;
  final SharedPreferencesAsync _preferences;
  final String? Function() _currentUid;
  final Stream<String?>? authChanges;
  final bool supported;
  final bool allowed;
  final _foreground = StreamController<OrderNotification>.broadcast();
  final _opened = StreamController<OrderNotification>.broadcast();
  final _seen = <String>{};
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void>? _initializing;
  Future<void> _queue = Future<void>.value();
  String? _uid, _token, _registrationId, _registeredUid;
  int _revision = 0;
  int get sessionRevision => _revision;
  bool _consent = false,
      _permitted = false,
      _busy = false,
      _ready = false,
      _disposed = false;
  bool _configured = false;
  OrderNotification? _pending;
  String? error;
  bool get enabled =>
      allowed &&
      _consent &&
      _permitted &&
      _registeredUid == _currentUid() &&
      _registeredUid != null;
  bool get busy => _busy;
  bool get permissionDenied => _consent && !_permitted;
  Stream<OrderNotification> get foreground => _foreground.stream;
  Stream<OrderNotification> get opened => _opened.stream;
  static String preferenceKey(String uid) => 'tajgo.notifications.$uid.enabled';
  static Future<Map<String, dynamic>> _call(Map<String, dynamic> data) async {
    final result =
        await FirebaseFunctions.instanceFor(
              region: const String.fromEnvironment(
                'TAJGO_FUNCTIONS_REGION',
                defaultValue: 'europe-west1',
              ),
            )
            .httpsCallable(
              'notificationDevice',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 10),
              ),
            )
            .call<Map<String, dynamic>>(data);
    return result.data;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int revision, String? uid) =>
      !_disposed && revision == _revision && uid == _currentUid();
  Future<void> _enqueue(Future<void> Function() operation) {
    _queue = _queue.then((_) => operation()).catchError((Object _) {
      if (!_disposed) {
        error =
            'Не удалось подключить уведомления. Проверьте интернет и повторите.';
        _changed();
      }
    });
    return _queue;
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    if (!supported || _disposed) return;
    _uid = _currentUid();
    _subscriptions.add(
      (authChanges ??
              FirebaseAuth.instance.authStateChanges().map((user) => user?.uid))
          .listen((uid) {
            if (uid == _uid) return;
            _uid = uid;
            _revision++;
            _ready = false;
            _registeredUid = null;
            _consent = false;
            if (_pending?.recipientId != uid) _pending = null;
            _changed();
            unawaited(refresh());
          }),
    );
    try {
      await _messaging.autoInit(false);
      if (_disposed) return;
      _configured = true;
      _subscriptions.add(
        _messaging.tokenRefresh.listen(
          (_) => unawaited(refresh()),
          onError: (Object _) {},
        ),
      );
      _subscriptions.add(
        _messaging.foreground.listen((message) {
          if (enabled &&
              message.recipientId == _currentUid() &&
              _seen.add(message.eventId)) {
            if (_seen.length > 100) _seen.remove(_seen.first);
            _foreground.add(message);
          }
        }, onError: (Object _) {}),
      );
      _subscriptions.add(
        _messaging.opened.listen(_open, onError: (Object _) {}),
      );
      final message = await _messaging.initialMessage().timeout(
        const Duration(seconds: 5),
      );
      if (message != null) _open(message);
      await refresh();
    } catch (_) {
      _configured = false;
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();
      _initializing = null;
      error = 'Не удалось подключить уведомления. Повторите в настройках.';
      _changed();
    }
  }

  void _open(OrderNotification message) {
    if (_disposed) return;
    final uid = _currentUid();
    // Auth restoration can follow the cold-start message. Keep it until the
    // account is known; the auth listener discards another account's message.
    if (uid == null) {
      _pending = message;
      return;
    }
    if (message.recipientId != uid) return;
    if (_ready) {
      _opened.add(message);
    } else {
      _pending = message;
    }
  }

  void navigationReady() {
    if (_disposed) return;
    _ready = true;
    final message = _pending;
    _pending = null;
    if (message != null) _open(message);
  }

  Future<void> refresh() {
    if (!supported || _disposed) return Future<void>.value();
    if (!_configured) return initialize();
    final revision = _revision, uid = _currentUid();
    return _enqueue(() => _sync(revision, uid));
  }

  Future<void> _sync(int revision, String? uid, {bool request = false}) async {
    if (!_current(revision, uid)) return;
    error = null;
    final consent =
        allowed &&
        uid != null &&
        await _preferences.getBool(preferenceKey(uid)) == true;
    if (!_current(revision, uid)) return;
    _consent = consent;
    final permitted =
        consent &&
        await _messaging
            .permission(request: request)
            .timeout(const Duration(seconds: 10));
    if (!_current(revision, uid)) return;
    _permitted = permitted;
    if (!consent || !permitted) {
      await _detach(uid);
      _changed();
      return;
    }
    await _messaging.autoInit(true);
    if (!_current(revision, uid)) return;
    final token = await _messaging.token().timeout(const Duration(seconds: 10));
    if (!_current(revision, uid)) return;
    if (token == null || token.isEmpty) {
      throw StateError('Notification token unavailable');
    }
    final registrationId = List.generate(
      16,
      (_) => Random.secure().nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final response = await _transport({
      'accountId': uid,
      'token': token,
      'registrationId': registrationId,
      'platform': 'android',
      'enabled': true,
    });
    if (!_current(revision, uid)) return;
    if (response['accountId'] != uid || response['registered'] != true) {
      throw StateError('Notification registration rejected');
    }
    _token = token;
    _registrationId = registrationId;
    _registeredUid = uid;
    _changed();
  }

  Future<void> setEnabled(bool value) async {
    final uid = _currentUid();
    if (!supported || !allowed || uid == null || _busy || _disposed) return;
    _busy = true;
    _changed();
    final revision = ++_revision;
    try {
      await _preferences.setBool(preferenceKey(uid), value);
      if (!_current(revision, uid)) return;
      await _enqueue(() => _sync(revision, uid, request: value));
    } catch (_) {
      error = 'Не удалось сохранить настройку. Попробуйте ещё раз.';
    } finally {
      _busy = false;
      _changed();
    }
  }

  Future<void> _detach(String? uid) async {
    final token = _token,
        registrationId = _registrationId,
        owner = _registeredUid;
    _token = null;
    _registrationId = null;
    _registeredUid = null;
    final tasks = <Future<void>>[
      _messaging.autoInit(false).timeout(const Duration(seconds: 3)),
      _messaging.deleteToken().timeout(const Duration(seconds: 3)),
    ];
    if (token != null &&
        registrationId != null &&
        owner != null &&
        owner == uid &&
        uid == _currentUid()) {
      tasks.add(
        _transport({
          'accountId': owner,
          'token': token,
          'registrationId': registrationId,
          'platform': 'android',
          'enabled': false,
        }).then<void>((_) {}),
      );
    }
    await Future.wait(tasks);
  }

  Future<void> beforeSignOut() async {
    final uid = _currentUid();
    if (!supported || uid == null) return;
    _revision++;
    _consent = false;
    _ready = false;
    _pending = null;
    _changed();
    try {
      await _preferences.setBool(preferenceKey(uid), false);
      await _detach(uid).timeout(const Duration(seconds: 6));
    } catch (_) {
      /* Token deletion/re-registration also prevents stale ownership. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_foreground.close());
    unawaited(_opened.close());
    super.dispose();
  }
}
