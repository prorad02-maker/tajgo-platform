import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajgo/app/tajgo_theme.dart';
import 'package:tajgo/core/models/app_user.dart';
import 'package:tajgo/core/models/marketplace_cart.dart';
import 'package:tajgo/core/models/marketplace_partner.dart';
import 'package:tajgo/core/models/marketplace_product.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
import 'package:tajgo/core/services/marketplace_repository.dart';
import 'package:tajgo/features/account/help_screen.dart';
import 'package:tajgo/features/account/order_history_screen.dart';
import 'package:tajgo/features/account/saved_places_screen.dart';
import 'package:tajgo/features/map/models/place_suggestion.dart';
import 'package:tajgo/features/map/services/saved_places_service.dart';
import 'package:tajgo/features/marketplace/marketplace_checkout_screen.dart';
import 'package:tajgo/features/marketplace/marketplace_partners_screen.dart';
import 'package:tajgo/features/marketplace/partner_catalog_screen.dart';
import 'package:tajgo/shared/widgets/tajgo_state_view.dart';

const partner = MarketplacePartner(
  id: 'shop',
  name: 'Магазин у дома',
  category: 'groceries',
  address: 'Худжанд, улица Сомони, 54',
  location: GeoPoint(40.2833, 69.6222),
  deliveryFee: 0,
  minimumOrder: 0,
);
const product = MarketplaceProduct(
  id: 'apple',
  partnerId: 'shop',
  name: 'Свежие яблоки из местного сада',
  description: 'Отборные сезонные яблоки, цена указана за килограмм.',
  unit: 'kg',
  price: 19.29,
  oldPrice: 25,
);
const order = TajGoOrder(
  id: 'order',
  customerId: 'customer',
  customerName: 'Клиент',
  status: OrderStatus.delivered,
  type: 'package',
  city: 'Худжанд',
  fromText: 'Худжанд, проспект Исмоила Сомони, 54',
  toText: 'Худжанд, улица Гагарина, 12, второй подъезд',
  price: 22,
  currency: 'TJS',
);

// Only a stream test double: production code never subclasses SDK queries.
// ignore: subtype_of_sealed_class
class _Query implements CollectionReference<Map<String, dynamic>> {
  _Query(this.source);
  final Stream<QuerySnapshot<Map<String, dynamic>>> source;
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => this;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => this.source;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Database implements FirebaseFirestore {
  _Database(this.source);
  final Stream<QuerySnapshot<Map<String, dynamic>>> source;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Query(source);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _EmptySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Catalog implements MarketplaceRepository {
  int partnerLoads = 0;
  bool failFirst = false;
  @override
  Stream<List<MarketplacePartner>> partnersStream({String? category}) {
    partnerLoads++;
    return failFirst && partnerLoads == 1
        ? Stream.error(
            FirebaseException(plugin: 'firestore', code: 'unavailable'),
          )
        : Stream.value([partner]);
  }

  @override
  Stream<List<MarketplaceProduct>> productsStream(
    String partnerId, {
    bool includeHidden = false,
    bool previewFallback = false,
  }) => Stream.value([product]);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Saved extends SavedPlacesService {
  _Saved() : super(preferences: _Preferences());
  final places = <PlaceSuggestion>[
    const PlaceSuggestion(
      id: 'home',
      title: 'Дом',
      shortTitle: 'Дом',
      subtitle: 'Худжанд',
      address: 'Сомони, 54',
      lat: 40.28,
      lng: 69.62,
      source: 'favorite',
      confidence: 1,
      category: 'address',
    ),
  ];
  @override
  Future<List<PlaceSuggestion>> load() async => List.of(places);
  @override
  Future<void> remove(PlaceSuggestion place) async =>
      places.removeWhere((item) => item.id == place.id);
}

class _Preferences implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _screen(
  WidgetTester tester,
  Widget child, {
  double scale = 1.4,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: TajGoTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final destination = Platform.environment['TAJGO_UI_OUTPUT'];
  if (destination == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory(destination)..createSync(recursive: true);
    File(
      '${folder.path}${Platform.pathSeparator}$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final fontDirectory = Platform.environment['TAJGO_UI_FONTS'];
    if (fontDirectory == null) return;
    final font = FontLoader('Roboto');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-bold.ttf',
      'roboto-black.ttf',
    ]) {
      font.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$fontDirectory${Platform.pathSeparator}$name',
            ).readAsBytesSync(),
          ),
        ),
      );
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$fontDirectory${Platform.pathSeparator}materialicons-regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
  });
  test(
    'release catalog propagates failures instead of offering sample shops',
    () async {
      final error = FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
      );
      final repository = MarketplaceRepository(_Database(Stream.error(error)));
      await expectLater(repository.partnersStream(), emitsError(same(error)));
      final empty = MarketplaceRepository(
        _Database(Stream.value(_EmptySnapshot())),
      );
      expect(await empty.partnersStream().first, isEmpty);
      final preview = MarketplaceRepository(
        _Database(Stream.error(error)),
        allowPreview: true,
      );
      expect(await preview.partnersStream().first, isNotEmpty);
    },
  );

  test('cart uses the same minimum fee and half cent rounding as checkout', () {
    final cart = MarketplaceCart();
    cart.add(
      partner,
      const MarketplaceProduct(
        id: 'low',
        partnerId: 'shop',
        name: 'Яблоки',
        price: 0.29,
        unit: 'kg',
      ),
    );
    expect(cart.subtotal, 0.15);
    expect(cart.deliveryFee, 10);
    expect(cart.total, 10.15);
  });

  test('invalid partner replacement preserves the original cart', () {
    final cart = MarketplaceCart()..add(partner, product);
    expect(
      () => cart.replacePartner(
        partner,
        const MarketplaceProduct(
          id: 'wrong',
          partnerId: 'other',
          name: 'Чужой товар',
          price: 20,
        ),
      ),
      throwsStateError,
    );
    expect(cart.lines.single.product.id, product.id);
  });

  test('client quantity does not exceed server checkout limit', () {
    final cart = MarketplaceCart()..add(partner, product);
    for (var i = 0; i < 250; i++) {
      cart.increment(product.id);
    }
    expect(cart.lines.single.quantity, 100);
    expect(() => cart.add(partner, product), throwsStateError);
  });

  test('completed disputes cannot block another customer order', () {
    expect(order.isActive, isTrue);
    final settledDispute = TajGoOrder(
      id: 'settled',
      customerId: 'customer',
      customerName: 'Клиент',
      status: OrderStatus.disputed,
      type: 'package',
      city: 'Худжанд',
      fromText: 'A',
      toText: 'B',
      price: 20,
      currency: 'TJS',
      completedAt: DateTime(2026, 1, 1),
    );
    expect(settledDispute.isActive, isFalse);
  });

  testWidgets('partner loading can recover after an outage', (tester) async {
    final repository = _Catalog()..failFirst = true;
    await _screen(
      tester,
      MarketplacePartnersScreen(category: 'groceries', repository: repository),
    );
    expect(find.text('Не удалось загрузить партнёров'), findsOneWidget);
    await tester.tap(find.text('Попробовать снова'));
    await tester.pumpAndSettle();
    expect(find.text(partner.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'product prices and cart controls fit small screens with large text',
    (tester) async {
      final cart = MarketplaceCart()..add(partner, product);
      await _screen(
        tester,
        PartnerCatalogScreen(
          partner: partner,
          repository: _Catalog(),
          cart: cart,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Добавить').first);
      await tester.pump();
      expect(cart.lines.single.quantity, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('checkout shows a consistent amount and removable items', (
    tester,
  ) async {
    final cart = MarketplaceCart()..add(partner, product);
    final key = GlobalKey();
    await _screen(
      tester,
      RepaintBoundary(
        key: key,
        child: MarketplaceCheckoutScreen(cart: cart),
      ),
    );
    expect(find.text('Оформить · 19.65 TJS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, key, 'checkout');
    await tester.tap(find.byTooltip('Удалить').first);
    await tester.pumpAndSettle();
    expect(find.text('Корзина пока пуста'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history recovers from errors and its status badge wraps', (
    tester,
  ) async {
    var calls = 0;
    final key = GlobalKey();
    await _screen(
      tester,
      RepaintBoundary(
        key: key,
        child: OrderHistoryScreen(
          currentMode: AppUserRole.customer,
          loadOrders: () => ++calls == 1
              ? Stream.error(StateError('Нет связи.'))
              : Stream.value([order]),
        ),
      ),
      scale: 2,
    );
    await tester.tap(find.text('Попробовать снова'));
    await tester.pumpAndSettle();
    expect(find.text('Ожидает подтверждения'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, key, 'history');
  });

  testWidgets('favorite addresses can be deleted from the profile section', (
    tester,
  ) async {
    final service = _Saved();
    await _screen(tester, SavedPlacesScreen(service: service));
    expect(find.text('Дом'), findsOneWidget);
    await tester.tap(find.byTooltip('Удалить адрес'));
    await tester.pumpAndSettle();
    expect(find.text('Сохраните важные адреса'), findsOneWidget);
    expect(service.places, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('help and data information remain readable at large text sizes', (
    tester,
  ) async {
    await _screen(tester, const HelpScreen(), scale: 2);
    await tester.tap(find.text('Как правильно выбрать адрес?'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _screen(tester, const PrivacyInfoScreen(), scale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error feedback scrolls when the keyboard leaves little room', (
    tester,
  ) async {
    await _screen(
      tester,
      const Scaffold(
        body: SizedBox(
          height: 180,
          child: TajGoStateView(
            icon: Icons.cloud_off,
            title: 'Не удалось загрузить данные',
            message: 'Проверьте соединение и повторите попытку.',
          ),
        ),
      ),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
