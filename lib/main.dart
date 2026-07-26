import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/tajgo_app.dart';
import 'core/config/feature_flags.dart';
import 'core/services/app_check_service.dart';
import 'core/services/crash_reporting_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  final flags = FeatureFlags.resolve();
  const crashReporting = CrashReportingService();

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Наблюдаемость и защита клиента — за флагами, с graceful fallback.
      // Отсутствие настройки в Firebase Console не должно ломать запуск.
      await crashReporting.initialize(enabled: flags.crashReporting);
      await const AppCheckService().activate(enabled: flags.appCheck);

      runApp(TajGoApp(featureFlags: flags));
    },
    (error, stack) {
      crashReporting.recordError(
        error,
        stack,
        reason: 'uncaught-zone-error',
        enabled: flags.crashReporting,
      );
    },
  );
}
