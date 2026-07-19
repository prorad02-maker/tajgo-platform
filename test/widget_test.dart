import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tajgo/core/models/courier_offer.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
import 'package:tajgo/core/models/app_user.dart';
import 'package:tajgo/core/models/courier_application.dart';
import 'package:tajgo/core/services/account_migration_service.dart';
import 'package:tajgo/core/services/account_mode_service.dart';
import 'package:tajgo/core/services/auth_service.dart';
import 'package:tajgo/core/services/courier_application_repository.dart';
import 'package:tajgo/core/services/courier_offer_repository.dart';
import 'package:tajgo/core/services/courier_order_eligibility.dart';
import 'package:tajgo/core/services/external_navigator_service.dart';
import 'package:tajgo/core/services/pricing.dart';
import 'package:tajgo/core/services/role_preference_service.dart';
import 'package:tajgo/features/map/models/place_suggestion.dart';
import 'package:tajgo/features/map/models/tajgo_route.dart';
import 'package:tajgo/features/map/services/address_normalizer.dart';
import 'package:tajgo/features/map/services/direct_route_provider.dart';
import 'package:tajgo/features/map/services/navigation_instruction_formatter.dart';
import 'package:tajgo/features/map/services/route_cache.dart';
import 'package:tajgo/features/map/services/road_route_provider.dart';
import 'package:tajgo/features/map/services/route_progress_service.dart';
import 'package:tajgo/features/map/services/route_sanity_service.dart';
import 'package:tajgo/features/map/services/routing_config.dart';
import 'package:tajgo/features/map/utils/route_display_formatter.dart';
import 'package:tajgo/features/map/utils/map_address_formatter.dart';
import 'package:tajgo/features/map/utils/new_order_map_layout.dart';
import 'package:tajgo/features/map/screens/new_order_map_screen.dart';
import 'package:tajgo/features/map/services/route_service.dart';
import 'package:tajgo/features/map/services/routing_health_monitor.dart';
import 'package:tajgo/features/map/services/map_performance_monitor.dart';
import 'package:tajgo/features/map/services/delivery_map_intelligence_service.dart';
import 'package:tajgo/features/auth/phone_auth_screen.dart';
import 'package:tajgo/features/startup/intent_selection_screen.dart';
import 'package:tajgo/features/startup/startup_decision.dart';

void main() {
  group('v0.9 Pilot Core offline acceptance', () {
    test('1 role onboarding нужен старому пользователю без выбора', () {
      final user = AppUser.fromMap({
        'displayName': 'Рахим',
        'profileComplete': true,
        'onboardingCompleted': false,
      }, uid: 'owner');
      expect(
        resolveStartupDestination(authenticated: true, profile: user),
        StartupDestination.roleOnboarding,
      );
    });

    test('2 role persistence сохраняет exact keys', () async {
      final service = RolePreferenceService(storage: _TestRoleStore());
      await service.save(AppUserRole.courier);
      final snapshot = await service.load();
      expect(snapshot.selectedRole, AppUserRole.courier);
      expect(snapshot.onboardingCompleted, isTrue);
    });

    test('3 walking удалён из UI и legacy fallback bicycle', () {
      expect(
        CourierTransport.values,
        isNot(contains(CourierTransport.walking)),
      );
      expect(CourierTransport.normalize('walking'), CourierTransport.bicycle);
      expect(routeModeFromString('foot'), RouteMode.bicycle);
      expect(routeModeFromString('pedestrian'), RouteMode.bicycle);
    });

    test('4 расстояние 999 м доступно', () {
      expect(
        const CourierOrderEligibilityService().canAcceptDistance(999),
        isTrue,
      );
    });

    test('5 расстояние 1000 и 1001 м недоступно', () {
      const service = CourierOrderEligibilityService();
      expect(service.canAcceptDistance(1000), isFalse);
      expect(service.canAcceptDistance(1001), isFalse);
    });

    test('6 устаревший GPS отклоняется', () {
      final now = DateTime(2026, 1, 1, 12);
      final result = const CourierOrderEligibilityService().evaluate(
        courierLocation: LatLng(40.2833, 69.6222),
        locationUpdatedAt: now.subtract(const Duration(seconds: 16)),
        accuracyMeters: 10,
        pickup: const LatLng(40.2834, 69.6222),
        hasActiveOrder: false,
        now: now,
      );
      expect(result.issue, CourierEligibilityIssue.locationStale);
    });

    test('7 один активный заказ блокирует принятие', () {
      final now = DateTime(2026, 1, 1, 12);
      final result = const CourierOrderEligibilityService().evaluate(
        courierLocation: const LatLng(40.2833, 69.6222),
        locationUpdatedAt: now,
        accuracyMeters: 10,
        pickup: const LatLng(40.2834, 69.6222),
        hasActiveOrder: true,
        now: now,
      );
      expect(result.issue, CourierEligibilityIssue.activeOrder);
    });

    test('8 custom price принимает только целые TJS не ниже минимума', () {
      expect(
        validateClientPrice(rawValue: '9', recommendedPrice: 12).isValid,
        isFalse,
      );
      expect(
        validateClientPrice(rawValue: '12.5', recommendedPrice: 12).isValid,
        isFalse,
      );
      expect(
        validateClientPrice(
          rawValue: '24',
          recommendedPrice: 12,
        ).requiresConfirmation,
        isTrue,
      );
    });

    test('9 повторное offer обновляется без роста счётчика', () {
      expect(shouldIncrementOffersCount(null), isTrue);
      expect(shouldIncrementOffersCount('rejected'), isTrue);
      expect(shouldIncrementOffersCount('pending'), isFalse);
      expect(
        isCourierOfferPriceValid(proposedPrice: 15, clientPrice: 15),
        isTrue,
      );
    });

    test('10 offer выбирается только у свободного курьера', () {
      expect(
        canSelectCourierOffer(
          orderStatus: 'waitingOffers',
          offerStatus: CourierOfferStatus.pending,
          courierBusy: false,
          expired: false,
        ),
        isTrue,
      );
    });

    test('11 остальные pending offers закрываются', () {
      expect(
        offerStatusAfterSelection(
          current: CourierOfferStatus.pending,
          selected: false,
        ),
        CourierOfferStatus.rejected,
      );
      expect(
        offerStatusAfterSelection(
          current: CourierOfferStatus.pending,
          selected: true,
        ),
        CourierOfferStatus.accepted,
      );
    });

    test('12 navigator URI ведёт к точкам A и B', () {
      final a = navigatorUri(
        ExternalNavigator.yandex,
        const LatLng(40.28, 69.62),
      );
      final b = navigatorUri(
        ExternalNavigator.yandex,
        const LatLng(40.29, 69.63),
      );
      expect(a.toString(), contains('lat_to=40.28'));
      expect(b.toString(), contains('lon_to=69.63'));
      expect(a, isNot(b));
    });

    test('13 navigator fallback использует безопасный geo URI', () {
      final uri = navigatorFallbackUri(const LatLng(40.28, 69.62));
      expect(uri.scheme, 'geo');
      expect(uri.toString(), isNot(contains('phone')));
      expect(uri.toString(), isNot(contains('code')));
    });

    test('14 старый waiting совместим с waitingOffers', () {
      expect(isWaitingOrderStatus('waiting'), isTrue);
      expect(isWaitingOrderStatus('waitingOffers'), isTrue);
      expect(orderStatusFromString('waitingOffers'), OrderStatus.waiting);
    });

    test('15 двойное принятие не проходит', () {
      expect(
        canSelectCourierOffer(
          orderStatus: 'waitingOffers',
          offerStatus: CourierOfferStatus.pending,
          courierBusy: true,
          expired: false,
        ),
        isFalse,
      );
      expect(
        canSelectCourierOffer(
          orderStatus: 'accepted',
          offerStatus: CourierOfferStatus.pending,
          courierBusy: false,
          expired: false,
        ),
        isFalse,
      );
    });
  });

  test('legacy customer account migrates without deleting fields', () {
    final patch = buildLegacyAccountPatch({
      'role': 'customer',
      'activeOrderId': 'order-1',
      'rating': 4.9,
    }, courierExists: false);
    expect(patch['roles'], ['customer']);
    expect(patch['courierStatus'], CourierStatus.none);
    expect(patch['courierOnboardingCompleted'], isFalse);
    expect(patch.containsKey('activeOrderId'), isFalse);
    expect(patch.containsKey('rating'), isFalse);
  });

  test('legacy courier account is approved on the same uid', () {
    final patch = buildLegacyAccountPatch({
      'role': 'customer',
      'earnings': 100,
    }, courierExists: true);
    expect(patch['roles'], ['customer', 'courier']);
    expect(patch['courierStatus'], CourierStatus.approved);
    expect(patch.containsKey('earnings'), isFalse);

    final user = AppUser.fromMap({
      ...patch,
      'profileComplete': true,
    }, uid: 'u1');
    expect(user.uid, 'u1');
    expect(resolveAccountMode(user), ResolvedAccountMode.courier);

    final partiallyMigrated = buildLegacyAccountPatch({
      'role': 'customer',
      'roles': ['customer'],
    }, courierExists: true);
    expect(partiallyMigrated['roles'], ['customer', 'courier']);
  });

  test('startup router respects profile completion, mode and approval', () {
    expect(
      resolveStartupDestination(authenticated: false),
      StartupDestination.intent,
    );
    expect(
      resolveStartupDestination(authenticated: true),
      StartupDestination.profileCompletion,
    );

    AppUser user({required String mode, required String status}) =>
        AppUser.fromMap({
          'displayName': 'Фаррух',
          'profileComplete': true,
          'roles': ['customer', if (status == 'approved') 'courier'],
          'lastMode': mode,
          'courierStatus': status,
          'courierOnboardingCompleted': true,
          'onboardingCompleted': true,
        }, uid: 'same-uid');

    expect(
      resolveStartupDestination(
        authenticated: true,
        profile: user(mode: 'customer', status: 'none'),
      ),
      StartupDestination.customerHome,
    );
    expect(
      resolveStartupDestination(
        authenticated: true,
        profile: user(mode: 'courier', status: 'approved'),
      ),
      StartupDestination.courierHome,
    );
    expect(
      resolveStartupDestination(
        authenticated: true,
        profile: user(mode: 'courier', status: 'pending'),
      ),
      StartupDestination.customerHome,
    );

    final needsOnboarding = AppUser.fromMap({
      'displayName': 'Фаррух',
      'profileComplete': true,
      'roles': ['customer', 'courier'],
      'lastMode': 'courier',
      'courierStatus': 'approved',
      'courierOnboardingCompleted': false,
      'onboardingCompleted': true,
    }, uid: 'same-uid');
    expect(
      resolveStartupDestination(authenticated: true, profile: needsOnboarding),
      StartupDestination.courierOnboarding,
    );
  });

  test('phone normalization and anonymous-link policy are safe', () {
    expect(normalizeTajikPhone('+992 92 123 45 67'), '+992921234567');
    expect(normalizeTajikPhone('92123'), isNull);
    expect(authLinkDecision(isAnonymous: true), AuthLinkDecision.linkAnonymous);
    expect(
      authLinkDecision(
        isAnonymous: true,
        firebaseErrorCode: 'credential-already-in-use',
      ),
      AuthLinkDecision.conflict,
    );
  });

  test('new account model keeps modes on the same uid', () {
    final user = AppUser.fromMap({
      'phoneNumber': '+992921234567',
      'displayName': 'Фаррух',
      'roles': ['customer', 'courier'],
      'lastMode': 'courier',
      'courierStatus': 'approved',
      'phoneVerified': true,
      'profileComplete': true,
      'courierOnboardingCompleted': true,
    }, uid: 'one-account');
    expect(user.uid, 'one-account');
    expect(user.phoneVerified, isTrue);
    expect(user.profileComplete, isTrue);
    expect(user.courierApproved, isTrue);
    expect(resolveAccountMode(user), ResolvedAccountMode.courier);
    expect(user.uid, 'one-account');
  });

  test('customer starts a persistent courier draft', () {
    final draft = CourierApplication.empty(
      uid: 'customer-1',
      displayName: 'Фаррух',
      phoneNumber: '+992921234567',
    );
    expect(draft.status, CourierStatus.draft);
    expect(draft.uid, 'customer-1');
    expect(draft.toDraftMap()['status'], CourierStatus.draft);
    expect(draft.toDraftMap()['verificationMethod'], 'personalMeeting');
  });

  test('completed draft can become pending without granting courier mode', () {
    final application = CourierApplication.fromMap({
      'displayName': 'Фаррух',
      'phoneNumber': '+992921234567',
      'status': 'draft',
      'currentStep': 4,
      'transport': 'electric_bike',
      'documentType': 'passport',
      'documentNumber': 'A12345',
      'termsAccepted': true,
      'dataConsent': true,
    }, uid: 'customer-1');
    expect(application.canSubmit, isTrue);

    final pending = AppUser.fromMap({
      'displayName': 'Фаррух',
      'profileComplete': true,
      'roles': ['customer'],
      'lastMode': 'courier',
      'courierStatus': 'pending',
    }, uid: 'customer-1');
    expect(pending.courierApproved, isFalse);
    expect(pending.canUseCourierMode, isFalse);
    expect(resolveAccountMode(pending), ResolvedAccountMode.customer);

    final approvedBeforeOnboarding = AppUser.fromMap({
      'displayName': 'Фаррух',
      'profileComplete': true,
      'roles': ['customer', 'courier'],
      'lastMode': 'customer',
      'courierStatus': 'approved',
      'courierOnboardingCompleted': false,
    }, uid: 'customer-1');
    expect(approvedBeforeOnboarding.courierApproved, isTrue);
    expect(approvedBeforeOnboarding.canUseCourierMode, isFalse);

    final afterOnboarding = AppUser.fromMap({
      'displayName': 'Фаррух',
      'profileComplete': true,
      'roles': ['customer', 'courier'],
      'lastMode': 'courier',
      'courierStatus': 'approved',
      'courierOnboardingCompleted': true,
    }, uid: 'customer-1');
    expect(afterOnboarding.canUseCourierMode, isTrue);
    expect(resolveAccountMode(afterOnboarding), ResolvedAccountMode.courier);
  });

  test('approve keeps customer role and does not duplicate legacy courier', () {
    expect(approvedCourierRoles(['customer']), ['customer', 'courier']);
    expect(approvedCourierRoles(['customer', 'courier']), [
      'customer',
      'courier',
    ]);
    expect(
      approvedCourierOnboardingCompleted(
        existingValue: null,
        courierProfileExists: false,
      ),
      isFalse,
    );
    expect(
      approvedCourierOnboardingCompleted(
        existingValue: null,
        courierProfileExists: true,
      ),
      isTrue,
    );

    final application = CourierApplication.empty(
      uid: 'courier-1',
      displayName: 'Фаррух',
      phoneNumber: '+992921234567',
    );
    final data = buildApprovedCourierData(
      uid: 'courier-1',
      application: application,
      existing: const {
        'activeOrderId': 'active-7',
        'earningsToday': 55,
        'ordersToday': 4,
        'rating': 4.8,
      },
    );
    expect(data['activeOrderId'], 'active-7');
    expect(data['earningsToday'], 55);
    expect(data['ordersToday'], 4);
    expect(data['rating'], 4.8);
  });

  test('reject and suspend keep customer access', () {
    AppUser account(String status) => AppUser.fromMap({
      'displayName': 'Фаррух',
      'profileComplete': true,
      'roles': ['customer', 'courier'],
      'lastMode': 'courier',
      'courierStatus': status,
      'courierOnboardingCompleted': true,
    }, uid: 'same-account');

    expect(
      resolveAccountMode(account('rejected')),
      ResolvedAccountMode.customer,
    );
    expect(
      resolveAccountMode(account('suspended')),
      ResolvedAccountMode.customer,
    );
    expect(account('suspended').roles, contains('customer'));

    final suspension = buildSuspendedCourierPatch('server-time');
    expect(suspension['isOnline'], isFalse);
    expect(suspension['online'], isFalse);
    expect(suspension.containsKey('activeOrderId'), isFalse);
  });

  test('admin courier action contains immutable audit identities', () {
    final log = buildCourierAdminLog(
      action: 'rejectCourier',
      targetUid: 'courier-1',
      adminUid: 'admin-1',
      reason: 'Нужно уточнить документ',
      createdAt: 'server-time',
    );
    expect(log['targetUid'], 'courier-1');
    expect(log['adminUid'], 'admin-1');
    expect(log['reason'], 'Нужно уточнить документ');
    expect(log['createdAt'], 'server-time');
  });

  testWidgets('intent screen has customer/courier intents but no admin', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: IntentSelectionScreen()));
    expect(find.text('Как вы хотите использовать TajGo?'), findsOneWidget);
    expect(find.text('Я клиент'), findsOneWidget);
    expect(find.text('Я курьер'), findsOneWidget);
    expect(find.text('Продолжить как клиент'), findsOneWidget);
    expect(find.text('Продолжить как курьер'), findsOneWidget);
  });

  testWidgets('customer role action is visible without admin action', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: IntentSelectionScreen()));
    expect(find.text('Продолжить как клиент'), findsOneWidget);
    expect(find.text('Продолжить как администратор'), findsNothing);
  });

  testWidgets('courier role action does not expose admin selection', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: IntentSelectionScreen()));
    expect(find.text('Продолжить как курьер'), findsOneWidget);
    expect(find.text('Продолжить как администратор'), findsNothing);
  });

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

  test('debug anonymous order сохраняет явный тестовый признак', () {
    const order = TajGoOrder(
      id: 'test-1',
      customerId: 'anonymous-uid',
      customerName: 'Тестировщик',
      status: OrderStatus.waiting,
      type: 'package',
      city: 'Худжанд',
      fromText: 'A',
      toText: 'B',
      price: 10,
      currency: 'TJS',
      isTestOrder: true,
    );
    expect(order.toCreateMap()['isTestOrder'], isTrue);
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

  test('direct route не округляет 30 метров до нуля', () {
    const provider = DirectRouteProvider();
    final route = provider.buildSync(
      from: const LatLng(40.2833, 69.6222),
      to: const LatLng(40.28357, 69.6222),
      mode: RouteMode.bicycle,
    );
    expect(route.distanceKm * 1000, closeTo(30, 1));
    expect(formatRouteDistance(route.distanceKm), '30 м');
    expect(route.etaMinutes, 1);
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
    expect(cache.get(from, to, RouteMode.scooter), isNull);
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

  test('distance formatter сохраняет точность в метрах', () {
    expect(formatDistanceMeters(5), 'менее 10 м');
    expect(formatDistanceMeters(30), '30 м');
    expect(formatDistanceMeters(400), '400 м');
    expect(formatDistanceMeters(1200), '1.2 км');
    expect(formatDistanceMeters(5, directBaselineMeters: 300), '300 м');
    expect(formatDistanceMeters(0, directBaselineMeters: 30), '30 м');
  });

  test('route sanity заменяет невозможную дистанцию на direct fallback', () {
    const sanity = RouteSanityService();
    const from = LatLng(40.2800, 69.6200);
    const to = LatLng(40.2827, 69.6200);

    TajGoRoute road(double distanceKm, List<LatLng> points) => TajGoRoute(
      points: points,
      distanceKm: distanceKm,
      etaMinutes: 1,
      isRoadRouteApproximation: false,
      providerName: 'osrm',
      routeQuality: RouteQuality.road,
      createdAt: DateTime.now().toUtc(),
    );

    final zero = sanity.sanitize(
      candidate: road(0, const [from, to]),
      from: from,
      to: to,
      mode: RouteMode.bicycle,
    );
    expect(zero.usedFallback, isTrue);
    expect(zero.route.distanceKm, greaterThan(0.25));

    final fiveMeters = sanity.sanitize(
      candidate: road(0.005, const [from, to]),
      from: from,
      to: to,
      mode: RouteMode.bicycle,
    );
    expect(fiveMeters.usedFallback, isTrue);

    final implausiblyLong = sanity.sanitize(
      candidate: road(2, const [from, to]),
      from: from,
      to: to,
      mode: RouteMode.bicycle,
    );
    expect(implausiblyLong.usedFallback, isTrue);

    final emptyGeometry = sanity.sanitize(
      candidate: road(0.3, const [from]),
      from: from,
      to: to,
      mode: RouteMode.bicycle,
    );
    expect(emptyGeometry.usedFallback, isTrue);

    final missing = sanity.sanitize(
      candidate: null,
      from: from,
      to: to,
      mode: RouteMode.bicycle,
    );
    expect(missing.usedFallback, isTrue);

    final validRoad = sanity.sanitize(
      candidate: road(0.35, const [from, to]),
      from: from,
      to: to,
      mode: RouteMode.bicycle,
    );
    expect(validRoad.providerAccepted, isTrue);
    expect(validRoad.route.routeQuality, RouteQuality.road);

    final directCandidate = const DirectRouteProvider().buildSync(
      from: from,
      to: to,
      mode: RouteMode.bicycle,
    );
    final validFallback = sanity.sanitize(
      candidate: directCandidate,
      from: from,
      to: to,
      mode: RouteMode.bicycle,
    );
    expect(validFallback.usedFallback, isTrue);
    expect(validFallback.providerAccepted, isFalse);
    expect(validFallback.route.routeQuality, RouteQuality.directFallback);
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

  test('Plus Code никогда не становится главным адресом', () {
    final plusCode = formatMapAddress('7JP6+86G, Худжанд');
    expect(plusCode.primary, 'Точка на карте');
    expect(plusCode.secondary, contains('7JP6+86G'));

    final street = formatMapAddress('ул. Исмоили Сомони, 54, Худжанд');
    expect(street.primary, 'ул. Исмоили Сомони');
    expect(street.secondary, '54, Худжанд');

    final current = formatMapAddress('Точка на карте', currentLocation: true);
    expect(current.primary, 'Ваше местоположение');
    expect(current.secondary, 'Худжанд');

    final human = formatMapAddress(
      '7JM5+9C8, ул. Асири, Худжанд, Таджикистан, Худжанд',
    );
    expect(human.primary, 'ул. Асири');
    expect(human.secondary, 'Худжанд');
  });

  test('collapsed карта занимает больше половины экрана 360x800', () {
    const size = Size(360, 800);
    expect(NewOrderMapLayout.panelHeight(size, details: false), 272);
    expect(
      NewOrderMapLayout.visibleMapRatio(size, details: false),
      greaterThanOrEqualTo(0.5),
    );
  });

  testWidgets('collapsed panel не переполняется на 360x800 и text scale 1.3', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pump(Brightness brightness) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            textScaler: const TextScaler.linear(1.3),
            platformBrightness: brightness,
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: buildNewOrderPointPanelForTest(),
            ),
          ),
        ),
      ),
    );

    await pump(Brightness.light);
    expect(tester.takeException(), isNull);
    expect(find.text('Подтвердить точку забора'), findsOneWidget);

    await pump(Brightness.dark);
    expect(tester.takeException(), isNull);
    expect(find.text('Подтвердить точку забора'), findsOneWidget);
  });

  testWidgets('v1.0.3 map viewport remains visible on 360x800', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(body: buildNewOrderEmergencyMapLayoutForTest()),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(FlutterMap), findsOneWidget);

    final mapRect = tester.getRect(
      find.byKey(const ValueKey('new-order-map-viewport')),
    );
    final panelRect = tester.getRect(
      find.byKey(const ValueKey('new-order-map-bottom-panel')),
    );
    final gpsRect = tester.getRect(
      find.byKey(const ValueKey('new-order-map-gps')),
    );
    final confirmRect = tester.getRect(
      find.byKey(const ValueKey('new-order-map-confirm')),
    );

    expect(mapRect, const Rect.fromLTWH(0, 0, 360, 800));
    expect(panelRect.top, 528);
    expect(panelRect.bottom, 800);
    expect(panelRect.height, lessThanOrEqualTo(300));
    expect(gpsRect.bottom, lessThan(panelRect.top));
    expect(panelRect.contains(confirmRect.center), isTrue);
    expect(find.text('Использовать моё местоположение'), findsNothing);
  });

  testWidgets(
    'details A/B показывает маршрут, GPS и bottom panel без overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(body: buildNewOrderDetailsMapLayoutForTest()),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.textContaining('400 м · ≈ 3 мин'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('new-order-map-route-overview')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('new-order-map-gps')), findsOneWidget);
      expect(find.textContaining('Откуда: ул. Асири'), findsOneWidget);
      expect(find.textContaining('7JM5+9C8'), findsNothing);
      expect(find.text('Использовать моё местоположение'), findsNothing);
      expect(find.text('GPS'), findsNothing);
      expect(find.byType(Banner), findsNothing);

      final panelRect = tester.getRect(
        find.byKey(const ValueKey('new-order-map-bottom-panel')),
      );
      final routeRect = tester.getRect(
        find.byKey(const ValueKey('new-order-map-route-overview')),
      );
      final gpsRect = tester.getRect(
        find.byKey(const ValueKey('new-order-map-gps')),
      );
      expect(panelRect.top, 480);
      expect(panelRect.bottom, 800);
      expect(routeRect.bottom, lessThan(panelRect.top));
      expect(gpsRect.bottom, lessThan(panelRect.top));
    },
  );
}

class _TestRoleStore implements RolePreferenceStorage {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;
}
