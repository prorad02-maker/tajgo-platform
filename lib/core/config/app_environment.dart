import 'package:flutter/foundation.dart';

/// Среда исполнения приложения TajGo.
///
/// Определяется на этапе сборки через `--dart-define=TAJGO_ENV=...`.
/// Если явно не задана — `debug` в debug-сборке, иначе `production`.
enum AppEnvironment {
  debug,
  pilot,
  production;

  static const String _defineKey = 'TAJGO_ENV';

  /// Разрешает среду из dart-define с безопасным значением по умолчанию.
  static AppEnvironment resolve() {
    const raw = String.fromEnvironment(_defineKey);
    switch (raw.trim().toLowerCase()) {
      case 'debug':
        return AppEnvironment.debug;
      case 'pilot':
      case 'staging':
        return AppEnvironment.pilot;
      case 'production':
      case 'prod':
      case 'release':
        return AppEnvironment.production;
      default:
        return kReleaseMode ? AppEnvironment.production : AppEnvironment.debug;
    }
  }

  bool get isDebug => this == AppEnvironment.debug;
  bool get isPilot => this == AppEnvironment.pilot;
  bool get isProduction => this == AppEnvironment.production;

  /// Не-production среды (debug/pilot) — где допустимы диагностика и т.п.
  bool get isNonProduction => this != AppEnvironment.production;

  String get label => switch (this) {
    AppEnvironment.debug => 'debug',
    AppEnvironment.pilot => 'pilot',
    AppEnvironment.production => 'production',
  };
}
