import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'safe_diagnostics.dart';

/// Активация Firebase App Check.
///
/// Enforcement НЕ включается здесь — это делается в Firebase Console после
/// staged rollout. Клиент лишь регистрирует attestation provider. В debug
/// используется debug-provider, в остальных средах — Play Integrity / App Attest.
///
/// Любая ошибка активации проглатывается: приложение продолжает работать даже
/// если App Check не настроен в проекте.
class AppCheckService {
  const AppCheckService();

  Future<void> activate({required bool enabled}) async {
    if (!enabled) return;
    try {
      // Не держим цикл фонового обновления токена: при отключённом App Check API
      // это приводит к повторяющимся 403 / "too many attempts".
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(false);
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestProvider(),
      );
    } catch (error, stack) {
      SafeDiagnostics.log(
        'APP_CHECK_ACTIVATION_SKIPPED',
        fields: {'code': SafeDiagnostics.errorCode(error)},
        stackTrace: stack,
      );
    }
  }
}
