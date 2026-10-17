import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:tajgo/core/models/courier_offer.dart';
import 'package:tajgo/core/models/tajgo_courier.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
import 'package:tajgo/features/courier/courier_home_screen.dart';
import 'package:tajgo/features/courier/courier_order_screen.dart';
import 'package:tajgo/features/customer/order_tracking_screen.dart';
import 'package:tajgo/features/customer/tabs/customer_orders_tab.dart';
import 'package:tajgo/features/map/models/tajgo_route.dart';
import 'package:tajgo/features/map/services/tajgo_location_service.dart';
import 'package:tajgo/shared/widgets/tajgo_confirmation_code.dart';
import 'package:tajgo/shared/widgets/tajgo_order_card.dart';
import 'support/ui_capture.dart';
import 'support/ui_fixture.dart';

TajGoOrder delivery({
  OrderStatus status = OrderStatus.accepted,
  bool arrived = false,
}) => TajGoOrder(
  id: 'design-order',
  customerId: 'customer',
  customerName: 'Мадина',
  courierId: status == OrderStatus.waiting ? null : 'courier',
  status: status,
  type: 'package',
  city: 'Худжанд',
  fromText: 'Проспект Исмоили Сомони, дом 54, магазин у центрального входа',
  toText: 'Улица Гагарина, дом 12, второй подъезд, квартира 24',
  price: 25,
  finalPrice: 32,
  currency: 'TJS',
  distanceKm: 3.4,
  etaMinutes: 14,
  fromLocation: const GeoPoint(40.2833, 69.6222),
  toLocation: const GeoPoint(40.29, 69.64),
  comment: 'Позвоните у шлагбаума. Домофон не работает, встретим у подъезда.',
  confirmationCode: '7391',
  commandVersion: 'server-v1',
  arrivedAtPickupAt: arrived ? DateTime(2026, 10, 18) : null,
);
const courier = TajGoCourier(
  uid: 'courier',
  displayName: 'Рахим Саидов',
  city: 'Худжанд',
  isOnline: true,
  rating: 4.9,
  transport: 'bicycle',
  earningsToday: 140,
  ordersToday: 7,
  location: GeoPoint(40.2833, 69.6222),
);
const offer = CourierOffer(
  id: 'offer',
  orderId: 'design-order',
  courierId: 'courier',
  courierName: 'Рахим Саидов',
  courierRating: 4.9,
  courierTransport: 'electric_bike',
  courierDistanceMeters: 320,
  proposedPrice: 32,
  originalClientPrice: 25,
  status: CourierOfferStatus.pending,
);
final road = TajGoRoute(
  points: const [LatLng(40.2833, 69.6222), LatLng(40.29, 69.64)],
  distanceKm: 3.4,
  etaMinutes: 14,
  isRoadRouteApproximation: false,
  providerName: 'fixture',
  routeQuality: RouteQuality.road,
  createdAt: DateTime(2026, 10, 18),
);

class GoodLocation extends Fake implements TajGoLocationService {
  @override
  Future<Position> determineCurrentPosition() async => Position(
    latitude: 40.2833,
    longitude: 69.6222,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  @override
  Stream<Position> positionStream() => const Stream.empty();
}

Widget mapAndPanel(Widget panel) => Scaffold(
  body: Column(
    children: [
      const Expanded(
        child: ColoredBox(
          key: ValueKey('map-area'),
          color: Color(0xFFEDF2EE),
          child: SizedBox.expand(),
        ),
      ),
      panel,
    ],
  ),
);
CourierDeliveryPanel courierPanel({
  OrderStatus status = OrderStatus.accepted,
  bool arrived = false,
  bool geoAvailable = true,
  double directDistance = .03,
  bool busy = false,
  VoidCallback? onPrimary,
  VoidCallback? onNavigate,
  VoidCallback? onClient,
}) => CourierDeliveryPanel(
  order: delivery(status: status, arrived: arrived),
  target: const LatLng(40.2833, 69.6222),
  distance: 3.4,
  directDistance: directDistance,
  etaMinutes: 14,
  geoAvailable: geoAvailable,
  geoError: geoAvailable ? null : 'denied',
  route: road,
  routeLoading: false,
  offRoute: false,
  isNearTarget: directDistance < .1,
  gpsWeak: false,
  onFixLocation: () {},
  busy: busy,
  onNavigate: onNavigate ?? () {},
  onClient: onClient ?? () {},
  onPrimary: onPrimary ?? () {},
);
DeliveryTrackingPanel trackingPanel({
  OrderStatus status = OrderStatus.accepted,
  bool busy = false,
  VoidCallback? onConfirm,
  VoidCallback? onNotReceived,
  VoidCallback? onCancel,
}) => DeliveryTrackingPanel(
  order: delivery(status: status),
  courier: status == OrderStatus.waiting ? null : courier,
  busy: busy,
  onCancel: onCancel ?? () {},
  onConfirm: onConfirm ?? () {},
  onNotReceived: onNotReceived ?? () {},
  onDone: () {},
  step: status == OrderStatus.accepted ? 1 : 3,
  title: switch (status) {
    OrderStatus.waiting => 'Ищем курьера',
    OrderStatus.accepted => 'Курьер едет за заказом',
    OrderStatus.pickedUp => 'Заказ у курьера',
    OrderStatus.delivered => 'Заказ доставлен?',
    _ => 'Доставлено',
  },
  subtitle: status == OrderStatus.delivered
      ? 'Подтвердите получение'
      : 'Следите за доставкой на карте',
  route: road,
  routeLoading: false,
  liveDistanceKm: 1.2,
  liveEtaMinutes: 6,
  courierLocationUpdatedAt: DateTime.now(),
  courierNearby: false,
  onShowRoute: () {},
  onRetryRoute: () {},
);

void main() {
  setUpAll(loadUiFonts);
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'delivery order card keeps final price and opens on tap at scale $scale',
      (tester) async {
        final fixture = UiFixture();
        addTearDown(fixture.dispose);
        var opened = false;
        await pumpUi(
          tester,
          fixture,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TajGoOrderCard(order: delivery(), onTap: () => opened = true),
              ],
            ),
          ),
          width: 320,
          height: 640,
          scale: scale,
        );
        expect(find.text('32 сомони'), findsOneWidget);
        expect(find.text('25 сомони'), findsNothing);
        expect(find.byType(TajGoConfirmationCode), findsNothing);
        await tester.tap(find.text('Посылка'));
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
        await captureUi(tester, 'delivery-card-${scale.toInt()}x');
      },
    );
    testWidgets(
      'courier next action stays pinned with long addresses at scale $scale',
      (tester) async {
        final fixture = UiFixture();
        addTearDown(fixture.dispose);
        var confirmed = 0, navigated = 0, called = 0;
        await pumpUi(
          tester,
          fixture,
          mapAndPanel(
            courierPanel(
              onPrimary: () => confirmed++,
              onNavigate: () => navigated++,
              onClient: () => called++,
            ),
          ),
          width: 320,
          height: 568,
          scale: scale,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('map-area'))).height,
          greaterThanOrEqualTo(568 * .39),
        );
        await tester.tap(find.text('Я на месте'));
        await tester.tap(find.text('Навигатор'));
        await tester.tap(
          scale > 1 ? find.byTooltip('Клиент') : find.text('Клиент'),
        );
        expect([confirmed, navigated, called], [1, 1, 1]);
        expect(find.byType(TajGoConfirmationCode), findsNothing);
        expect(tester.takeException(), isNull);
        await captureUi(tester, 'courier-pickup-${scale.toInt()}x');
      },
    );
    testWidgets(
      'customer handoff actions are visible without scrolling at scale $scale',
      (tester) async {
        final fixture = UiFixture();
        addTearDown(fixture.dispose);
        var confirmed = false, reported = false;
        await pumpUi(
          tester,
          fixture,
          mapAndPanel(
            trackingPanel(
              status: OrderStatus.delivered,
              onConfirm: () => confirmed = true,
              onNotReceived: () => reported = true,
            ),
          ),
          width: 320,
          height: 568,
          scale: scale,
        );
        await tester.tap(find.text('Подтвердить получение'));
        await tester.tap(find.text('Не получил'));
        expect(confirmed && reported, isTrue);
        expect(tester.takeException(), isNull);
        await captureUi(tester, 'customer-delivered-${scale.toInt()}x');
      },
    );
    testWidgets(
      'courier offers keep selection and secondary actions reachable at scale $scale',
      (tester) async {
        final fixture = UiFixture();
        addTearDown(fixture.dispose);
        var selected = false, rejected = false, map = false;
        await pumpUi(
          tester,
          fixture,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DeliveryCourierOfferCard(
                  offer: offer,
                  onSelect: () => selected = true,
                  onReject: () => rejected = true,
                  onShowMap: () => map = true,
                ),
              ],
            ),
          ),
          width: 320,
          height: 640,
          scale: scale,
        );
        for (final label in ['Выбрать курьера', 'Отклонить', 'На карте']) {
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
        }
        expect(find.text('Велосипед'), findsOneWidget);
        expect(find.text('electric_bike'), findsNothing);
        expect(selected && rejected && map, isTrue);
        expect(tester.takeException(), isNull);
        await captureUi(tester, 'courier-offer-${scale.toInt()}x');
      },
    );
  }
  testWidgets('GPS and distance requirements still disable courier handoff', (
    tester,
  ) async {
    final fixture = UiFixture();
    addTearDown(fixture.dispose);
    var presses = 0;
    for (final scenario in [
      (true, 3.0, false),
      (false, .03, false),
      (true, .03, true),
    ]) {
      await pumpUi(
        tester,
        fixture,
        mapAndPanel(
          courierPanel(
            status: OrderStatus.pickedUp,
            geoAvailable: scenario.$1,
            directDistance: scenario.$2,
            busy: scenario.$3,
            onPrimary: () => presses++,
          ),
        ),
        width: 320,
        height: 568,
        scale: 2,
      );
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Передал заказ'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      if (!scenario.$3) {
        final reason = find.text(
          scenario.$1 ? 'Подойдите ближе к точке' : 'Нужна геолокация',
        );
        expect(
          tester.getRect(reason).bottom,
          lessThan(tester.getRect(find.text('Передал заказ')).top),
        );
      }
      expect(find.byType(TajGoConfirmationCode), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(presses, 0);
  });
  testWidgets('arrival advances presentation while preserving pickup action', (
    tester,
  ) async {
    final fixture = UiFixture();
    addTearDown(fixture.dispose);
    var picked = false;
    await pumpUi(
      tester,
      fixture,
      mapAndPanel(courierPanel(arrived: true, onPrimary: () => picked = true)),
    );
    await tester.tap(find.text('Забрал заказ'));
    expect(picked, isTrue);
    expect(find.text('Заберите заказ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'private customer code remains readable and absent from courier screen',
    (tester) async {
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      fixture.orders.deliveryCode = '4826';
      await pumpUi(
        tester,
        fixture,
        mapAndPanel(trackingPanel(status: OrderStatus.pickedUp)),
        width: 320,
        height: 640,
        scale: 2,
      );
      await tester.ensureVisible(find.byType(TajGoConfirmationCode));
      await tester.pump();
      expect(
        tester
            .widget<TajGoConfirmationCode>(find.byType(TajGoConfirmationCode))
            .code,
        '4826',
      );
      for (final digit in '4826'.split('')) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byType(TajGoConfirmationCode),
            matching: find.text(digit),
          ),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'customer-code-2x');
      await pumpUi(
        tester,
        fixture,
        mapAndPanel(courierPanel(status: OrderStatus.pickedUp)),
      );
      expect(find.byType(TajGoConfirmationCode), findsNothing);
      await captureUi(tester, 'courier-dropoff-1x');
    },
  );
  testWidgets('customer busy state disables both confirmation and dispute', (
    tester,
  ) async {
    final fixture = UiFixture();
    addTearDown(fixture.dispose);
    await pumpUi(
      tester,
      fixture,
      mapAndPanel(trackingPanel(status: OrderStatus.delivered, busy: true)),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Не получил'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed offers can recover and cancellation stays pinned', (
    tester,
  ) async {
    final fixture = UiFixture();
    addTearDown(fixture.dispose);
    fixture.offers.fail = true;
    var cancelled = false;
    await pumpUi(
      tester,
      fixture,
      mapAndPanel(
        trackingPanel(
          status: OrderStatus.waiting,
          onCancel: () => cancelled = true,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Повторить'));
    expect(find.text('Ждём предложения курьеров'), findsNothing);
    fixture.offers.fail = false;
    fixture.offers.offers = [offer];
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(fixture.offers.subscriptions, 2);
    expect(find.byType(DeliveryCourierOfferCard), findsOneWidget);
    await tester.tap(find.text('Отменить заказ'));
    expect(cancelled, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'courier feed reports a network failure and recovers with retry',
    (tester) async {
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      fixture.courier.cachedCourier = courier;
      fixture.locationOverride = GoodLocation();
      fixture.courier.waitingFail = true;
      await pumpUi(tester, fixture, const CourierHomeScreen());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Повторить').first);
      expect(find.text('Не удалось загрузить заказы'), findsWidgets);
      expect(find.textContaining('PRIVATE'), findsNothing);
      fixture.courier.waitingFail = false;
      fixture.courier.waitingOrders = [delivery(status: OrderStatus.waiting)];
      await tester.tap(find.text('Повторить').first);
      await tester.pumpAndSettle();
      expect(find.text('Предложить доставку'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'courier-feed-1x');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('customer orders use the new route card with current delivery', (
    tester,
  ) async {
    final fixture = UiFixture();
    addTearDown(fixture.dispose);
    fixture.orders.orders = [delivery()];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpUi(
      tester,
      fixture,
      CustomerOrdersTab(scrollController: controller),
    );
    await tester.pumpAndSettle();
    expect(find.text('32 сомони'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureUi(tester, 'customer-orders-1x');
    await tester.tap(find.text('Активные').first);
    await tester.pumpAndSettle();
    expect(find.byType(TajGoOrderCard), findsOneWidget);
    expect(find.text('32 сомони'), findsOneWidget);
  });
  testWidgets('tracking shows courier identity and live arrival estimate', (
    tester,
  ) async {
    final fixture = UiFixture();
    addTearDown(fixture.dispose);
    await pumpUi(tester, fixture, mapAndPanel(trackingPanel()));
    expect(find.text('Рахим Саидов'), findsOneWidget);
    expect(find.text('До цели 1.2 км · ≈ 6 мин'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureUi(tester, 'customer-tracking-1x');
  });
}
