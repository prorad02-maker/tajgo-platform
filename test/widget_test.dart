import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
import 'package:tajgo/core/services/pricing.dart';
import 'package:tajgo/features/map/models/place_suggestion.dart';
import 'package:tajgo/features/map/models/tajgo_route.dart';
import 'package:tajgo/features/map/services/address_normalizer.dart';
import 'package:tajgo/features/map/services/direct_route_provider.dart';
import 'package:tajgo/features/map/services/route_cache.dart';

void main() {
  test('неизвестный статус заказа считается ожидающим', () {
    expect(orderStatusFromString('legacy'), OrderStatus.waiting);
    expect(orderStatusToString(OrderStatus.pickedUp), 'pickedUp');
  });

  test('расчёт расстояния, времени и цены', () {
    final distance = distanceKm(
      const LatLng(40.2833, 69.6222),
      const LatLng(40.2833, 69.6322),
    );
    expect(distance, closeTo(0.8, 0.2));
    expect(etaMinutes(2.5), 14);
    expect(courierNavigationEtaMinutes(3), 10);
    expect(suggestedPrice(0), 10);
    expect(suggestedPrice(1), 10);
    expect(suggestedPrice(2.5), 15);
    expect(suggestedPrice(10), 37);
  });

  test('комментарий попадает в данные заказа только когда он не пустой', () {
    const withComment = TajGoOrder(
      id: '1',
      customerId: 'c1',
      customerName: 'Клиент',
      status: OrderStatus.waiting,
      type: 'package',
      city: 'Худжанд',
      fromText: 'A',
      toText: 'B',
      price: 15,
      currency: 'TJS',
      comment: 'Подъезд 2, этаж 3',
    );
    expect(withComment.toCreateMap()['comment'], 'Подъезд 2, этаж 3');

    const withoutComment = TajGoOrder(
      id: '2',
      customerId: 'c1',
      customerName: 'Клиент',
      status: OrderStatus.waiting,
      type: 'package',
      city: 'Худжанд',
      fromText: 'A',
      toText: 'B',
      price: 15,
      currency: 'TJS',
    );
    expect(withoutComment.toCreateMap().containsKey('comment'), isFalse);
  });

  test('код подтверждения и гео-гейт', () {
    final code = generateConfirmationCode(Random(7));
    expect(code, hasLength(4));
    expect(int.tryParse(code), isNotNull);
    expect(withinActionRadius(2), isTrue);
    expect(withinActionRadius(2.01), isFalse);
  });

  test('поисковый запрос адреса нормализуется', () {
    const normalizer = AddressNormalizer();
    expect(normalizer.normalizeQuery('  УЛ.   Сомони '), 'улица сомони');
    expect(normalizer.normalizeQuery('пр Сомони'), 'проспект сомони');
    expect(normalizer.normalizeQuery('д 12'), 'дом 12');
    expect(normalizer.normalizeQuery('KHujand center'), 'худжанд center');
  });

  test('локальные aliases повышают соответствие места', () {
    const normalizer = AddressNormalizer();
    const place = PlaceSuggestion(
      id: 'p1',
      title: 'Панчшанбе',
      subtitle: 'Ориентир',
      shortTitle: 'Панчшанбе',
      address: 'Худжанд',
      lat: 40.28,
      lng: 69.62,
      source: 'local',
      confidence: 1,
      category: 'landmark',
      aliases: ['панч', 'базар панчшанбе'],
    );
    expect(normalizer.scoreMatch('панч', place), 1);
    expect(normalizer.buildShortAddress(place), 'Панчшанбе');
  });

  test('direct route остаётся безопасным fallback', () {
    const provider = DirectRouteProvider();
    final route = provider.buildSync(
      from: const LatLng(40.2833, 69.6222),
      to: const LatLng(40.2933, 69.6322),
      mode: RouteMode.bicycle,
    );
    expect(route.points, hasLength(2));
    expect(route.routeQuality, RouteQuality.directFallback);
    expect(route.isRoadRouteApproximation, isTrue);
    expect(route.distanceKm, greaterThan(0));
    expect(route.etaMinutes, greaterThan(0));
  });

  test('route cache использует округлённые координаты и mode', () {
    final cache = RouteCache();
    const from = LatLng(40.28331, 69.62221);
    const almostSameFrom = LatLng(40.28334, 69.62224);
    const to = LatLng(40.2933, 69.6322);
    final route = TajGoRoute(
      points: const [from, to],
      distanceKm: 2,
      etaMinutes: 8,
      isRoadRouteApproximation: false,
      providerName: 'test',
      routeQuality: RouteQuality.road,
      createdAt: DateTime.now().toUtc(),
    );
    cache.put(from, to, RouteMode.bicycle, route);
    expect(cache.get(almostSameFrom, to, RouteMode.bicycle), same(route));
    expect(cache.get(from, to, RouteMode.walking), isNull);
  });

  test('gazetteer metadata сохраняется в PlaceSuggestion', () {
    final place = PlaceSuggestion.fromJson({
      'id': 'market_1',
      'title': 'Демо рынок',
      'shortTitle': 'Рынок',
      'address': 'Худжанд',
      'lat': 40.28,
      'lng': 69.62,
      'category': 'market',
      'district': 'Демо',
      'verified': false,
      'popularity': 90,
    });
    expect(place.category, 'market');
    expect(place.district, 'Демо');
    expect(place.verified, isFalse);
    expect(place.popularity, 90);
  });
}
