import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/app/tajgo_theme.dart';
import 'package:tajgo/features/map/widgets/tajgo_map_loading_status.dart';

void main() {
  testWidgets('missing tiles offer a retry instead of loading indefinitely', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: TajGoMapLoadingStatus(onRetry: () => retries++)),
        ),
      ),
    );
    expect(find.text('Загружаем карту…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('Карта недоступна'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    expect(retries, 1);
    expect(find.text('Загружаем карту…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading status disappears on success and does not reappear later',
    (tester) async {
      final loaded = ValueNotifier(false);
      addTearDown(loaded.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: loaded,
              builder: (_, ready, child) => ready
                  ? const Text('Карта загружена')
                  : TajGoMapLoadingStatus(onRetry: () {}),
            ),
          ),
        ),
      );
      loaded.value = true;
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Карта загружена'), findsOneWidget);
      expect(find.text('Карта недоступна'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'map retry remains readable on a narrow screen at large text size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: TajGoTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TajGoMapLoadingStatus(onRetry: () {}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('Повторить'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
