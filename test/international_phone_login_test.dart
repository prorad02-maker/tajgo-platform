import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/app/tajgo_theme.dart';
import 'package:tajgo/core/services/auth_service.dart';
import 'package:tajgo/features/auth/phone_auth_screen.dart';

import 'support/ui_fixture.dart';

class _Auth extends FixtureAuth {
  final requested = <String>[];
  @override
  Future<PhoneCodeSession> requestPhoneCode({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    requested.add(phoneNumber);
    return PhoneCodeSession.codeSent(verificationId: 'isolated-phone-input');
  }
}

void main() {
  test('explicit international prefixes are preserved', () {
    expect(normalizeLoginPhone('+7 (900) 000-00-01'), '+79000000001');
    expect(normalizeLoginPhone('+992 92 123 45 67'), '+992921234567');
    expect(normalizeLoginPhone('+44 7700 900123'), '+447700900123');
  });

  test('existing local Tajik number input still works', () {
    expect(normalizeLoginPhone('92 123 45 67'), '+992921234567');
    expect(normalizeLoginPhone('992921234567'), '+992921234567');
  });

  test('incomplete, oversized or malformed numbers are never truncated', () {
    for (final input in [
      '',
      '+7',
      '+7900000000',
      '+790000000012',
      '+99292123',
      '+0123456789',
      '+1234567890123456',
      '++79000000001',
      '7+9000000001',
      '92+1234567',
      '+7 extension 123',
      '79670000001',
    ]) {
      expect(normalizeLoginPhone(input), isNull, reason: input);
    }
  });

  for (final phone in ['+79000000001', '+992921234567']) {
    testWidgets('phone screen submits $phone without changing its country', (
      tester,
    ) async {
      final fixture = UiFixture();
      final auth = _Auth();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        fixture.wrap(
          MaterialApp(
            theme: TajGoTheme.light,
            home: const PhoneAuthScreen(allowAnonymousFallback: false),
          ),
          authService: auth,
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.enterText(field, '');
      expect(tester.widget<TextField>(field).controller?.text, isEmpty);
      await tester.enterText(field, phone);
      expect(tester.widget<TextField>(field).controller?.text, phone);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(auth.requested, [phone]);
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.labelText,
        'SMS-код',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
