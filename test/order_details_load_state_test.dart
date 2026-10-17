import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/shared/widgets/order_details_load_state.dart';

void main() {
  test('order snapshot resolves every terminal state', () {
    expect(
      resolveOrderDetailsLoadState<int>(
        const AsyncSnapshot<int?>.nothing().inState(ConnectionState.waiting),
      ),
      OrderDetailsLoadState.loading,
    );
    expect(
      resolveOrderDetailsLoadState(
        const AsyncSnapshot<int?>.withData(ConnectionState.active, 7),
      ),
      OrderDetailsLoadState.success,
    );
    expect(
      resolveOrderDetailsLoadState<int>(
        const AsyncSnapshot.withData(ConnectionState.active, null),
      ),
      OrderDetailsLoadState.notFound,
    );
    expect(
      resolveOrderDetailsLoadState<int>(
        AsyncSnapshot.withError(
          ConnectionState.active,
          StateError('permission-denied'),
        ),
      ),
      OrderDetailsLoadState.error,
    );
  });

  testWidgets('terminal error shows retry and leaves spinner', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderDetailsTerminalView(
            notFound: false,
            onRetry: () => retries++,
            onBack: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Не удалось загрузить заказ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('order-details-retry')));
    expect(retries, 1);
  });

  testWidgets('not-found state is finite and retryable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderDetailsTerminalView(
            notFound: true,
            onRetry: () {},
            onBack: () {},
          ),
        ),
      ),
    );

    expect(find.text('Заказ не найден'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
