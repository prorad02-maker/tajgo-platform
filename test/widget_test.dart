import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
import 'package:tajgo/core/services/pricing.dart';
import 'package:tajgo/features/map/models/place_suggestion.dart';
import 'package:tajgo/features/map/models/tajgo_route.dart';
import 'package:tajgo/features/map/services/address_normalizer.dart';
import 'package:tajgo/features/map/services/direct_route_provider.dart';
import 'package:tajgo/features/map/services/navigation_instruction_formatter.dart';
import 'package:tajgo/features/map/services/route_cache.dart';
import 'package:tajgo/features/map/services/road_route_provider.dart';
import 'package:tajgo/features/map/services/route_progress_service.dart';
import 'package:tajgo/features/map/services/routing_config.dart';
import 'package:tajgo/features/map/utils/route_display_formatter.dart';
import 'package:tajgo/features/map/services/route_service.dart';
import 'package:tajgo/features/map/services/routing_health_monitor.dart';
import 'package:tajgo/features/map/services/map_performance_monitor.dart';
import 'package:tajgo/features/map/services/delivery_map_intelligence_service.dart';

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

  test('русские инструкции форматируют основные манёвры', () {
    const formatter = NavigationInstructionFormatter();
    expect(
      formatter.format(
        maneuverType: 'turn',
        modifier: 'right',
        streetName: '',
        distanceMeters: 200,
      ),
      'Через 200 м поверните направо',
    );
    expect(
      formatter.format(
        maneuverType: 'turn',
        modifier: 'left',
        streetName: 'улицу Сомони',
        distanceMeters: 50,
      ),
      'Через 50 м поверните налево на улицу Сомони',
    );
    expect(
      formatter.format(
        maneuverType: 'uturn',
        modifier: '',
        streetName: '',
        distanceMeters: 30,
      ),
      'Через 30 м развернитесь, когда будет безопасно',
    );
  });

  test('route progress считает остаток и отклонение без сети', () {
    final route = TajGoRoute(
      points: const [
        LatLng(40.2800, 69.6200),
        LatLng(40.2900, 69.6200),
        LatLng(40.3000, 69.6200),
      ],
      distanceKm: 2.22,
      etaMinutes: 10,
      isRoadRouteApproximation: false,
      providerName: 'test',
      routeQuality: RouteQuality.road,
      createdAt: DateTime.now().toUtc(),
    );
    const service = RouteProgressService(offRouteThresholdMeters: 150);
    final progress = service.calculateProgress(
      route,
      const LatLng(40.2900, 69.6201),
    );
    expect(progress.remainingDistanceKm, closeTo(1.11, 0.08));
    expect(progress.routeCompletionPercent, closeTo(50, 5));
    expect(progress.isOffRoute, isFalse);
    expect(
      service.detectOffRoute(route, const LatLng(40.2900, 69.6230)),
      isTrue,
    );
  });

  test('OSRM sample разбирает геометрию, ETA и steps', () {
    final provider = RoadRouteProvider(
      config: const RoutingConfig(
        enabled: true,
        providerType: RoutingProviderType.osrm,
        baseUrl: 'https://routing.invalid',
        apiKey: '',
        timeout: Duration(seconds: 2),
        mode: RouteMode.bicycle,
        debugLogging: false,
        profileOverride: 'driving',
      ),
    );
    final route = provider.parseResponse({
      'routes': [
        {
          'distance': 1600,
          'duration': 480,
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [69.6200, 40.2800],
              [69.6250, 40.2850],
              [69.6300, 40.2900],
            ],
          },
          'legs': [
            {
              'steps': [
                {
                  'distance': 500,
                  'duration': 120,
                  'name': 'проспект Сомони',
                  'maneuver': {
                    'type': 'depart',
                    'modifier': 'straight',
                    'location': [69.6200, 40.2800],
                  },
                },
                {
                  'distance': 1100,
                  'duration': 360,
                  'name': 'улицу Гагарина',
                  'maneuver': {
                    'type': 'turn',
                    'modifier': 'right',
                    'location': [69.6250, 40.2850],
                  },
                },
              ],
            },
          ],
        },
      ],
    });
    expect(route.routeQuality, RouteQuality.road);
    expect(route.points, hasLength(3));
    expect(route.distanceKm, 1.6);
    expect(route.etaMinutes, 8);
    expect(route.steps, hasLength(2));
    expect(route.steps.last.instructionRu, contains('направо'));
    expect(route.steps.last.streetName, 'улицу Гагарина');
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

  test('routing config валидирует production endpoint', () {
    const missingUrl = RoutingConfig(
      enabled: true,
      providerType: RoutingProviderType.osrm,
      baseUrl: '',
      apiKey: '',
      timeout: Duration(seconds: 7),
      mode: RouteMode.bicycle,
      debugLogging: false,
    );
    expect(missingUrl.isConfigured, isFalse);
    expect(missingUrl.validationIssues, contains('ROUTING_BASE_URL не задан'));

    const valid = RoutingConfig(
      enabled: true,
      providerType: RoutingProviderType.osrm,
      baseUrl: 'https://routing.example.tj',
      apiKey: '',
      timeout: Duration(seconds: 7),
      mode: RouteMode.bicycle,
      debugLogging: false,
    );
    expect(valid.isConfigured, isTrue);
    expect(valid.validationIssues, isEmpty);
  });

  test('OSRM request builder использует lng,lat и обязательные параметры', () {
    final provider = RoadRouteProvider(
      config: const RoutingConfig(
        enabled: true,
        providerType: RoutingProviderType.osrm,
        baseUrl: 'https://routing.example.tj',
        apiKey: '',
        timeout: Duration(seconds: 7),
        mode: RouteMode.bicycle,
        debugLogging: false,
        profileOverride: 'driving',
      ),
    );
    final uri = provider.buildRequestUri(
      from: const LatLng(40.2833, 69.6222),
      to: const LatLng(40.2933, 69.6322),
      mode: RouteMode.bicycle,
    );
    expect(
      uri.path,
      contains('/route/v1/driving/69.6222,40.2833;69.6322,40.2933'),
    );
    expect(uri.queryParameters['geometries'], 'geojson');
    expect(uri.queryParameters['steps'], 'true');
  });

  test('provider disabled даёт fallback и обновляет health', () async {
    const config = RoutingConfig(
      enabled: false,
      providerType: RoutingProviderType.osrm,
      baseUrl: '',
      apiKey: '',
      timeout: Duration(seconds: 7),
      mode: RouteMode.bicycle,
      debugLogging: false,
    );
    final road = RoadRouteProvider(config: config);
    final health = RoutingHealthMonitor(config);
    final performance = MapPerformanceMonitor();
    final service = RouteService(
      roadProvider: road,
      healthMonitor: health,
      performanceMonitor: performance,
    );
    final route = await service.buildRoute(
      from: const LatLng(40.2833, 69.6222),
      to: const LatLng(40.2933, 69.6322),
      mode: RouteMode.bicycle,
    );
    expect(route.routeQuality, RouteQuality.directFallback);
    expect(route.qualityLabel, 'Маршрут предварительный');
    expect(health.snapshot.fallbacks, 1);
    expect(performance.snapshot.routeBuilds, 1);
  });

  test('partner и pinned metadata проходят JSON roundtrip', () {
    final place = PlaceSuggestion.fromJson({
      'id': 'partner_1',
      'title': 'Партнёр TajGo',
      'shortTitle': 'Партнёр',
      'address': 'Худжанд',
      'lat': 40.28,
      'lng': 69.62,
      'category': 'shop',
      'partnerId': 'business_1',
      'isPartner': true,
      'pinned': true,
      'tags': ['partner', 'pickup'],
    });
    final restored = PlaceSuggestion.fromJson(place.toJson());
    expect(restored.isPartner, isTrue);
    expect(restored.isPinned, isTrue);
    expect(restored.partnerId, 'business_1');
    expect(restored.tags, contains('pickup'));
  });

  test('delivery intelligence переключает следующую цель A на B', () {
    const service = DeliveryMapIntelligenceService();
    const pickup = TajGoOrder(
      id: 'o1',
      customerId: 'c1',
      customerName: 'Клиент',
      status: OrderStatus.accepted,
      type: 'package',
      city: 'Худжанд',
      fromText: 'A',
      toText: 'B',
      price: 15,
      currency: 'TJS',
      comment: 'Вход со двора',
    );
    final pickupInfo = service.forOrder(pickup);
    expect(pickupInfo.targetLabel, 'A · Забрать');
    expect(pickupInfo.showConfirmationCode, isFalse);

    const dropoffInfoOrder = TajGoOrder(
      id: 'o1',
      customerId: 'c1',
      customerName: 'Клиент',
      status: OrderStatus.pickedUp,
      type: 'package',
      city: 'Худжанд',
      fromText: 'A',
      toText: 'B',
      price: 15,
      currency: 'TJS',
      comment: 'Вход со двора',
    );
    final dropoffInfo = service.forOrder(dropoffInfoOrder);
    expect(dropoffInfo.targetLabel, 'B · Доставить');
    expect(dropoffInfo.showConfirmationCode, isTrue);
  });

  test('distance formatter не показывает 0.0 км', () {
    expect(formatRouteDistance(0.03), '30 м');
    expect(formatRouteDistance(0.4), '400 м');
    expect(formatRouteDistance(1.2), '1.2 км');
  });

  test('route display quality честно отличает road от fallback', () {
    final road = TajGoRoute(
      points: const [LatLng(40.28, 69.62), LatLng(40.29, 69.63)],
      distanceKm: 1.2,
      etaMinutes: 6,
      isRoadRouteApproximation: false,
      providerName: 'osrm',
      routeQuality: RouteQuality.road,
      createdAt: DateTime.now().toUtc(),
    );
    final fallback = TajGoRoute(
      points: const [LatLng(40.28, 69.62), LatLng(40.29, 69.63)],
      distanceKm: 1,
      etaMinutes: 5,
      isRoadRouteApproximation: true,
      providerName: 'direct',
      routeQuality: RouteQuality.directFallback,
      createdAt: DateTime.now().toUtc(),
    );
    final providerError = TajGoRoute(
      points: const [LatLng(40.28, 69.62), LatLng(40.29, 69.63)],
      distanceKm: 1,
      etaMinutes: 5,
      isRoadRouteApproximation: true,
      providerName: 'direct',
      routeQuality: RouteQuality.providerError,
      errorMessage: 'technical detail',
      createdAt: DateTime.now().toUtc(),
    );
    expect(formatRouteQuality(road), 'Маршрут построен');
    expect(formatRouteQuality(fallback), 'Маршрут предварительный');
    expect(formatRouteQuality(providerError), 'Маршрут предварительный');
    expect(formatRouteQuality(null), 'Маршрут предварительный');
  });
}
