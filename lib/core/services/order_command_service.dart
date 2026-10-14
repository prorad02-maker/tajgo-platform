import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef OrderCommandTransport =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

/// Server rollout is opt-in. Existing server orders always use the server;
/// infrastructure failures never fall back to an unrestricted client write.
class OrderCommandService {
  OrderCommandService({
    this.enabled = const bool.fromEnvironment('TAJGO_SERVER_COMMANDS_ENABLED'),
    OrderCommandTransport? transport,
    SharedPreferencesAsync? preferences,
    String? Function()? currentUid,
  }) : _transport = transport ?? _call,
       _preferences = preferences ?? SharedPreferencesAsync(),
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final bool enabled;
  final OrderCommandTransport _transport;
  final SharedPreferencesAsync _preferences;
  final String? Function() _currentUid;
  final Map<String, Future<Map<String, dynamic>>> _inFlight = {};

  static Future<Map<String, dynamic>> _call(Map<String, dynamic> data) async {
    final functions = FirebaseFunctions.instanceFor(
      region: const String.fromEnvironment(
        'TAJGO_FUNCTIONS_REGION',
        defaultValue: 'europe-west1',
      ),
    );
    final result = await functions
        .httpsCallable(
          'orderCommand',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call<Map<String, dynamic>>(data);
    return result.data;
  }

  Future<bool> handlesOrder(FirebaseFirestore db, String orderId) async =>
      (await db.collection('orders').doc(orderId).get())
          .data()?['commandVersion'] ==
      'server-v1';

  Future<Map<String, dynamic>> run(
    String action,
    Map<String, dynamic> payload,
  ) {
    final uid = _currentUid();
    if (uid == null) throw StateError('Войдите в аккаунт.');
    final body = <String, dynamic>{...payload, 'action': action};
    final key =
        'tajgo_order_command_${sha256.convert(utf8.encode('$uid:${jsonEncode(_canonical(body))}'))}';
    return _inFlight.putIfAbsent(key, () {
      final request = _execute(key, uid, body);
      request.then<void>(
        (_) {
          _inFlight.remove(key);
        },
        onError: (Object _, StackTrace _) {
          _inFlight.remove(key);
        },
      );
      return request;
    });
  }

  Future<Map<String, dynamic>> _execute(
    String key,
    String uid,
    Map<String, dynamic> body,
  ) async {
    var requestId = await _preferences.getString(key);
    if (requestId == null) {
      final random = Random.secure();
      requestId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await _preferences.setString(key, requestId);
    }
    if (_currentUid() != uid) {
      throw StateError('Аккаунт изменился. Повторите действие.');
    }
    try {
      final result = await _transport({...body, 'requestId': requestId});
      // A local storage failure after server success must not turn a successful
      // order into a failed UI action. Retaining the ID is safe for retries.
      try {
        await _preferences.remove(key);
      } catch (_) {}
      return result;
    } on FirebaseFunctionsException catch (error) {
      if (const {
        'invalid-argument',
        'permission-denied',
        'unauthenticated',
        'failed-precondition',
        'not-found',
        'already-exists',
        'resource-exhausted',
      }.contains(error.code)) {
        try {
          await _preferences.remove(key);
        } catch (_) {}
        throw StateError(error.message ?? 'Не удалось выполнить действие.');
      }
      rethrow;
    }
  }

  static Object? _canonical(Object? value) {
    if (value is Map<String, dynamic>) {
      final keys = value.keys.toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }
}
