import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/core/config/app_environment.dart';
import 'package:tajgo/core/config/feature_flags.dart';
import 'package:tajgo/core/design/tajgo_money.dart';

void main() {
  group('TajGoMoney', () {
    test('целые суммы выводятся без дробной части', () {
      expect(TajGoMoney.format(15), '15 сомони');
      expect(TajGoMoney.format(0), '0 сомони');
      expect(TajGoMoney.format(1200), '1200 сомони');
    });

    test('дробные суммы используют запятую и не оставляют хвостовых нулей', () {
      expect(TajGoMoney.format(12.5), '12,5 сомони');
      expect(TajGoMoney.format(12.50), '12,5 сомони');
      expect(TajGoMoney.format(12.0), '12 сомони');
    });

    test('amount не добавляет единицу', () {
      expect(TajGoMoney.amount(15), '15');
      expect(TajGoMoney.amount(7.5), '7,5');
    });

    test('никогда не показывает TJS/₽/\$ и не падает на NaN/Infinity', () {
      final text = TajGoMoney.format(42);
      expect(text.contains('TJS'), isFalse);
      expect(text.contains('₽'), isFalse);
      expect(text.contains(r'$'), isFalse);
      expect(TajGoMoney.format(double.nan), '0 сомони');
      expect(TajGoMoney.format(double.infinity), '0 сомони');
    });
  });

  group('FeatureFlags', () {
    test('debug открывает demo-инструменты и анонимный вход', () {
      final flags = FeatureFlags.forEnvironment(AppEnvironment.debug);
      expect(flags.demoTools, isTrue);
      expect(flags.anonymousDemoLogin, isTrue);
      expect(flags.diagnostics, isTrue);
    });

    test('production прячет demo-инструменты, анонимный вход и диагностику', () {
      final flags = FeatureFlags.forEnvironment(AppEnvironment.production);
      expect(flags.demoTools, isFalse);
      expect(flags.anonymousDemoLogin, isFalse);
      expect(flags.diagnostics, isFalse);
      expect(flags.previewData, isFalse);
    });

    test('pilot показывает диагностику, но не demo-инструменты', () {
      final flags = FeatureFlags.forEnvironment(AppEnvironment.pilot);
      expect(flags.diagnostics, isTrue);
      expect(flags.demoTools, isFalse);
      expect(flags.anonymousDemoLogin, isFalse);
    });

    test('ключевые продуктовые функции включены во всех средах', () {
      for (final env in AppEnvironment.values) {
        final flags = FeatureFlags.forEnvironment(env);
        expect(flags.marketplace, isTrue, reason: env.label);
        expect(flags.customPrice, isTrue, reason: env.label);
        expect(flags.merchantApplications, isTrue, reason: env.label);
      }
    });

    test('App Check выключен по умолчанию во всех средах (owner-driven rollout)', () {
      for (final env in AppEnvironment.values) {
        expect(
          FeatureFlags.forEnvironment(env).appCheck,
          isFalse,
          reason: env.label,
        );
      }
    });
  });
}
