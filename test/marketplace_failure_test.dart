import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/core/services/authoritative_command_service.dart';
import 'package:tajgo/core/services/marketplace_repository.dart';

class EmptySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
}

// A stream-only SDK test double; no production query subclasses are created.
// ignore: subtype_of_sealed_class
class CatalogQuery extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  CatalogQuery([this.error]);
  final Object? error;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) return this;
    if (invocation.memberName == #snapshots) {
      return error == null
          ? Stream<QuerySnapshot<Map<String, dynamic>>>.value(EmptySnapshot())
          : Stream<QuerySnapshot<Map<String, dynamic>>>.error(error!);
    }
    return super.noSuchMethod(invocation);
  }
}

class CatalogDatabase extends Fake implements FirebaseFirestore {
  CatalogDatabase({Object? error}) : query = CatalogQuery(error);
  final CatalogQuery query;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => query;
}

class UnusedCommands extends Fake implements AuthoritativeCommandService {}

void main() {
  test(
    'empty production catalog stays empty instead of displaying sample shops',
    () async {
      final repo = MarketplaceRepository(CatalogDatabase(), UnusedCommands());
      expect(await repo.partnersStream().first, isEmpty);
    },
  );
  test(
    'preview shops require explicit opt-in and remain marked as preview',
    () async {
      final repo = MarketplaceRepository(CatalogDatabase(), UnusedCommands());
      final preview = await repo.partnersStream(allowPreview: true).first;
      expect(preview, isNotEmpty);
      expect(preview.every((shop) => shop.isPreview), isTrue);
    },
  );
  test(
    'catalog failure reaches the UI even when previews are allowed',
    () async {
      final failure = StateError('Permission or network failure');
      final db = CatalogDatabase(error: failure);
      final repo = MarketplaceRepository(db, UnusedCommands());
      await expectLater(
        repo.partnersStream(allowPreview: true),
        emitsError(same(failure)),
      );
    },
  );
  test(
    'product search failure reaches the UI instead of becoming no results',
    () async {
      final failure = StateError('Network failure');
      final db = CatalogDatabase(error: failure);
      final repo = MarketplaceRepository(db, UnusedCommands());
      await expectLater(
        repo.publishedProductsStream(),
        emitsError(same(failure)),
      );
    },
  );
}
