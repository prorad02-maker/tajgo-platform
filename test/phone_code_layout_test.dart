import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/app/tajgo_theme.dart';
import 'package:tajgo/core/services/auth_service.dart';
import 'package:tajgo/features/auth/phone_auth_screen.dart';

import 'support/ui_fixture.dart';

class _Auth extends FixtureAuth {
  @override
  Future<PhoneCodeSession> requestPhoneCode({
    required String phoneNumber,
    int? forceResendingToken,
  }) async => PhoneCodeSession.codeSent(verificationId: 'isolated-layout-test');
}

void main() {
  testWidgets(
    'SMS actions wrap on a narrow phone with large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        fixture.wrap(
          MaterialApp(
            theme: TajGoTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 280),
              ),
              child: child!,
            ),
            home: const PhoneAuthScreen(allowAnonymousFallback: false),
          ),
          authService: _Auth(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '+992900000001');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.labelText,
        'SMS-код',
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Изменить номер'));
      await tester.tap(find.text('Изменить номер'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.labelText,
        'Номер телефона',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
