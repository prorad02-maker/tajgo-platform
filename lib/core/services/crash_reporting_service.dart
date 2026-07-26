import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Тонкая обёртка над Crashlytics с безопасной инициализацией.
///
/// Никогда не логируем чувствительные данные (код получения, полный телефон,
/// полный адрес, токены). При отсутствии настройки Crashlytics в проекте
/// инициализация тихо пропускается, приложение не падает.
class CrashReportingService {
  const CrashReportingService();

  /// Подключает глобальные обработчики ошибок Flutter/Isolate к Crashlytics.
  Future<void> initialize({required bool enabled}) async {
    if (!enabled) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(true);

      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        previousOnError?.call(details);
        crashlytics.recordFlutterError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (error) {
      debugPrint('Crashlytics init skipped: $error');
    }
  }

  /// Ручная запись нефатальной ошибки (без чувствительных данных).
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool enabled = true,
  }) async {
    if (!enabled) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: false,
      );
    } catch (_) {
      // graceful no-op
    }
  }
}
