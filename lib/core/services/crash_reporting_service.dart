import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'safe_diagnostics.dart';

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
        crashlytics.recordError(
          'flutter:${SafeDiagnostics.errorCode(details.exception)}',
          details.stack,
          fatal: false,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(
          'platform:${SafeDiagnostics.errorCode(error)}',
          stack,
          fatal: true,
        );
        return true;
      };
    } catch (error) {
      SafeDiagnostics.log(
        'CRASHLYTICS_INIT_SKIPPED',
        fields: {'code': SafeDiagnostics.errorCode(error)},
      );
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
        'recorded:${SafeDiagnostics.errorCode(error)}',
        stack,
        reason: reason,
        fatal: false,
      );
    } catch (_) {
      // graceful no-op
    }
  }
}
