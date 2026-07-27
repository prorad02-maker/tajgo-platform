import 'app_environment.dart';

/// Флаги функциональности TajGo.
///
/// Флаги выводятся из [AppEnvironment] с безопасными значениями по умолчанию.
/// Отдельные флаги можно переопределить через `--dart-define` (например
/// `--dart-define=TAJGO_ROUTING_ENABLED=true`) для контролируемого rollout.
///
/// Правило релиза: незавершённая функция либо закончена, либо выключена флагом.
/// Debug-инструменты (demo tools, anonymous-вход) доступны только в debug.
class FeatureFlags {
  const FeatureFlags({
    required this.environment,
    required this.marketplace,
    required this.customPrice,
    required this.merchantApplications,
    required this.notifications,
    required this.crashReporting,
    required this.diagnostics,
    required this.adminImport,
    required this.previewData,
    required this.appCheck,
    required this.publicPilotRouting,
    required this.demoTools,
    required this.anonymousDemoLogin,
  });

  final AppEnvironment environment;

  /// Marketplace (Еда/Продукты/Цветы).
  final bool marketplace;

  /// Своя цена клиента и offers.
  final bool customPrice;

  /// Заявки магазинов на подключение.
  final bool merchantApplications;

  /// Push-уведомления (FCM). При отсутствии настройки Console — graceful no-op.
  final bool notifications;

  /// Crashlytics-отчёты. Graceful no-op если не настроено.
  final bool crashReporting;

  /// Экран диагностики (скрыт в production).
  final bool diagnostics;

  /// Импорт прайса в админке.
  final bool adminImport;

  /// Показ preview/demo-каталога при пустом реальном каталоге.
  final bool previewData;

  /// Активация App Check provider (enforcement НЕ включается автоматически).
  final bool appCheck;

  /// Использование публичного pilot-роутинга (OSRM/GraphHopper endpoint).
  final bool publicPilotRouting;

  /// Demo Tools (только debug).
  final bool demoTools;

  /// Анонимный demo-вход (только debug).
  final bool anonymousDemoLogin;

  /// Разбор bool-переопределения из dart-define.
  static bool _override(String key, bool fallback) {
    const notSet = '__unset__';
    final raw = String.fromEnvironment(key, defaultValue: notSet);
    if (raw == notSet) return fallback;
    final value = raw.trim().toLowerCase();
    return value == 'true' || value == '1' || value == 'yes' || value == 'on';
  }

  /// Собирает набор флагов для заданной среды с учётом dart-define.
  factory FeatureFlags.forEnvironment(AppEnvironment env) {
    final isDebug = env.isDebug;
    final nonProd = env.isNonProduction;
    return FeatureFlags(
      environment: env,
      marketplace: _override('TAJGO_FF_MARKETPLACE', true),
      customPrice: _override('TAJGO_FF_CUSTOM_PRICE', true),
      merchantApplications: _override('TAJGO_FF_MERCHANT_APPS', true),
      notifications: _override('TAJGO_FF_NOTIFICATIONS', true),
      crashReporting: _override('TAJGO_FF_CRASH', !isDebug),
      diagnostics: _override('TAJGO_FF_DIAGNOSTICS', nonProd),
      adminImport: _override('TAJGO_FF_ADMIN_IMPORT', true),
      previewData: _override('TAJGO_FF_PREVIEW_DATA', nonProd),
      // App Check выключен по умолчанию во всех средах: включается через
      // --dart-define=TAJGO_FF_APP_CHECK=true только после регистрации
      // приложений и включения App Check API в Console (иначе SDK спамит 403).
      appCheck: _override('TAJGO_FF_APP_CHECK', false),
      publicPilotRouting: _override('TAJGO_ROUTING_ENABLED', false),
      demoTools: isDebug && _override('TAJGO_FF_DEMO_TOOLS', true),
      anonymousDemoLogin: isDebug && _override('TAJGO_FF_ANON_LOGIN', true),
    );
  }

  /// Флаги для текущей сборки.
  factory FeatureFlags.resolve() =>
      FeatureFlags.forEnvironment(AppEnvironment.resolve());
}
