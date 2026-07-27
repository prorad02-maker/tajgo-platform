import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/features/startup/app_router.dart';

void main() {
  testWidgets(
    'ошибка загрузки профиля показывается отдельно; retry не возвращает Future в setState',
    (tester) async {
      var calls = 0;
      Future<StartupState> resolver(BuildContext _) async {
        calls++;
        throw Exception('profile load failed');
      }

      await tester.pumpWidget(
        MaterialApp(home: AppStartupRouter(resolver: resolver)),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(
        find.text('Вход выполнен, но не удалось загрузить профиль'),
        findsOneWidget,
      );
      // Не должно быть формулировки провала входа.
      expect(find.text('Не удалось войти'), findsNothing);

      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();

      // Ключевая проверка бага: setState не получил async-колбэк.
      expect(tester.takeException(), isNull);
      expect(calls, 2);
    },
  );

  testWidgets(
    'двойной тап retry не запускает параллельные запросы',
    (tester) async {
      var calls = 0;
      final completers = <Completer<StartupState>>[];
      Future<StartupState> resolver(BuildContext _) {
        calls++;
        final completer = Completer<StartupState>();
        completers.add(completer);
        return completer.future;
      }

      await tester.pumpWidget(
        MaterialApp(home: AppStartupRouter(resolver: resolver)),
      );
      await tester.pump(); // post-frame -> первый resolve (pending)
      expect(calls, 1);

      completers[0].completeError(Exception('fail'));
      await tester.pumpAndSettle();
      expect(find.text('Повторить'), findsOneWidget);

      // Два тапа в одном кадре: второй должен быть заблокирован guard'ом.
      await tester.tap(find.text('Повторить'));
      await tester.tap(find.text('Повторить'), warnIfMissed: false);
      await tester.pump();
      expect(calls, 2);

      completers[1].completeError(Exception('fail again'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
