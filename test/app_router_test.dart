import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/features/startup/app_router.dart';
import 'package:tajgo/features/startup/startup_decision.dart';

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
        MaterialApp(
          home: AppStartupRouter(
            resolver: resolver,
            authUidStream: Stream<String?>.empty(),
            initialUid: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(
        find.text('Вход выполнен, но не удалось загрузить профиль'),
        findsOneWidget,
      );
      expect(find.text('Не удалось войти'), findsNothing);

      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(calls, 2);
    },
  );

  testWidgets('двойной тап retry не запускает параллельные запросы', (
    tester,
  ) async {
    var calls = 0;
    final completers = <Completer<StartupState>>[];
    Future<StartupState> resolver(BuildContext _) {
      calls++;
      final completer = Completer<StartupState>();
      completers.add(completer);
      return completer.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: AppStartupRouter(
          resolver: resolver,
          authUidStream: Stream<String?>.empty(),
          initialUid: null,
        ),
      ),
    );
    await tester.pump();
    expect(calls, 1);

    completers[0].completeError(Exception('fail'));
    await tester.pumpAndSettle();
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.tap(find.text('Повторить'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 2);

    completers[1].completeError(Exception('fail again'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'router пере-резолвит (загрузка профиля) при authStateChanges null -> User',
    (tester) async {
      final auth = StreamController<String?>();
      var resolveCount = 0;
      Future<StartupState> resolver(BuildContext _) async {
        resolveCount++;
        return const StartupState(StartupDestination.intent, null);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: AppStartupRouter(
            resolver: resolver,
            authUidStream: auth.stream,
            initialUid: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // initial: uid == null -> экран входа.
      expect(resolveCount, 1);
      expect(
        find.text('Как вы хотите использовать TajGo?'),
        findsOneWidget,
      );

      // authStateChanges emits User -> повторный resolve (profile load).
      auth.add('1P8Lfe9olBPYhuDioMy6S9injjJ2');
      await tester.pumpAndSettle();
      expect(resolveCount, 2);

      await auth.close();
    },
  );

  testWidgets(
    'две эмиссии authStateChanges не загружают профиль параллельно',
    (tester) async {
      final auth = StreamController<String?>();
      var resolveCount = 0;
      final completers = <Completer<StartupState>>[];
      Future<StartupState> resolver(BuildContext _) {
        resolveCount++;
        final completer = Completer<StartupState>();
        completers.add(completer);
        return completer.future;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: AppStartupRouter(
            resolver: resolver,
            authUidStream: auth.stream,
            initialUid: null,
          ),
        ),
      );
      await tester.pump(); // первичный resolve (pending)
      expect(resolveCount, 1);

      // Два эмита одного User, пока первый resolve ещё в полёте.
      auth.add('uidX');
      auth.add('uidX');
      await tester.pump();
      expect(resolveCount, 1); // guard: без параллельного resolve

      completers[0].complete(const StartupState(StartupDestination.intent, null));
      await tester.pump();
      expect(resolveCount, 2); // ровно один коалесцированный повтор, не два

      completers[1].complete(const StartupState(StartupDestination.intent, null));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await auth.close();
    },
  );
}
