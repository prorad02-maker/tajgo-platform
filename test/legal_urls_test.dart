import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/core/legal/legal_documents.dart';

void main() {
  test('production legal URLs use the canonical tajgo.ru HTTPS set', () {
    expect(LegalDocuments.privacyUrl, 'https://tajgo.ru/privacy');
    expect(LegalDocuments.termsUrl, 'https://tajgo.ru/terms');
    expect(LegalDocuments.supportUrl, 'https://tajgo.ru/support');
    expect(
      LegalDocuments.accountDeletionUrl,
      'https://tajgo.ru/account-deletion',
    );
    for (final url in [
      LegalDocuments.privacyUrl,
      LegalDocuments.termsUrl,
      LegalDocuments.supportUrl,
      LegalDocuments.accountDeletionUrl,
    ]) {
      final uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.host, 'tajgo.ru');
      expect(url, isNot(contains('localhost')));
      expect(url, isNot(contains('example.invalid')));
    }
    expect(LegalDocuments.privacy.publicUrl, LegalDocuments.privacyUrl);
    expect(LegalDocuments.terms.publicUrl, LegalDocuments.termsUrl);
  });
}
