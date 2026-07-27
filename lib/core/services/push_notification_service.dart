import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/customer/order_tracking_screen.dart';

/// Background-обработчик FCM. Отдельный isolate; никакой обработки чувствительных
/// данных — систему уведомление рисует сама.
@pragma('vm:entry-point')
Future<void> tajgoFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // Намеренно no-op: payload не содержит секретов; показ — на стороне ОС.
}

/// Клиентский FCM: инициализация, разрешение по требованию, хранение токенов и
/// навигация по тапу. За feature-флагом `notifications`, graceful fallback —
/// отсутствие настройки FCM в проекте не ломает приложение.
///
/// Backend-триггеры отправки (Cloud Functions) — DEPLOY_REQUIRED, см.
/// docs/V1_8_FCM_ARCHITECTURE.md.
class PushNotificationService {
  PushNotificationService(this._messaging, this._db);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  bool _initialized = false;

  Future<void> initialize({
    required bool enabled,
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (!enabled || _initialized) return;
    _initialized = true;
    try {
      FirebaseMessaging.onBackgroundMessage(
        tajgoFirebaseMessagingBackgroundHandler,
      );
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _handleTap(message, navigatorKey),
      );
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleTap(initial, navigatorKey);
      FirebaseMessaging.onMessage.listen(_onForeground);
    } catch (error) {
      debugPrint('FCM init skipped: $error');
    }
  }

  /// Запрашивает разрешение и регистрирует токен (вызывать после
  /// pre-permission объяснения, не на старте).
  Future<bool> enableForUser(String uid) async {
    try {
      final settings = await _messaging.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return false;
      final token = await _messaging.getToken();
      if (token != null) await _storeToken(uid, token);
      _messaging.onTokenRefresh.listen((next) => _storeToken(uid, next));
      return true;
    } catch (error) {
      debugPrint('FCM enable skipped: $error');
      return false;
    }
  }

  /// Деактивирует токен на logout (не удаляет — backend перестаёт слать).
  Future<void> disableForUser(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _tokenDoc(uid, token).set({
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // graceful
    }
  }

  Future<void> _storeToken(String uid, String token) async {
    try {
      await _tokenDoc(uid, token).set({
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('FCM token store skipped: $error');
    }
  }

  DocumentReference<Map<String, dynamic>> _tokenDoc(String uid, String token) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('notification_tokens')
          .doc(token);

  void _onForeground(RemoteMessage message) {
    // Foreground: система баннер не показывает — можно логировать/обновлять UI.
    // Данные экранов приходят через Firestore-стримы, поэтому здесь no-op.
    debugPrint('FCM foreground: ${message.messageId}');
  }

  void _handleTap(RemoteMessage message, GlobalKey<NavigatorState> key) {
    final data = message.data;
    final type = data['type'];
    final orderId = data['orderId'];
    if (type == 'order' && orderId is String && orderId.isNotEmpty) {
      key.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => OrderTrackingScreen(orderId: orderId),
        ),
      );
    }
  }
}
