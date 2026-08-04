import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/core/services/safe_diagnostics.dart';

void main() {
  test('diagnostic redaction removes common PII and secrets', () {
    const input =
        'uid=user-123 phone=+992 92 123 45 67 '
        'point=40.28331,69.62221 support=user@example.com '
        'Bearer abc.def.ghi token=fcm-secret code=4321';
    final safe = SafeDiagnostics.redactText(input);

    expect(safe, isNot(contains('user-123')));
    expect(safe, isNot(contains('+992')));
    expect(safe, isNot(contains('40.28331')));
    expect(safe, isNot(contains('user@example.com')));
    expect(safe, isNot(contains('abc.def.ghi')));
    expect(safe, isNot(contains('fcm-secret')));
    expect(safe, isNot(contains('4321')));
    expect(safe, contains('[REDACTED]'));
  });
}
