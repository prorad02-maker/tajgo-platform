import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tajgo/core/config/service_area_config.dart';
import 'package:tajgo/core/pricing/delivery_pricing.dart';
import 'package:tajgo/core/pricing/taxi_observation.dart';
import 'package:tajgo/features/map/models/map_session_state.dart';
import 'package:tajgo/features/map/screens/new_order_map_screen.dart';

class _MemoryObservationRepository implements TaxiObservationRepository {
  const _MemoryObservationRepository(this.values);
  final List<TaxiPriceObservation> values;

  @override
  Future<List<TaxiPriceObservation>> observationsForCity(String cityId) async =>
      values.where((item) => item.cityId == cityId).toList();
}

TaxiPriceObservation _observation({
  required double price,
  required DateTime at,
  String city = 'khujand',
  int distance = 5000,
}) => TaxiPriceObservation(
  cityId: city,
  provider: 'market-observation',
  pickupBucket: 'a',
  dropoffBucket: 'b',
  distanceMeters: distance,
  durationSeconds: 1200,
  quotedPrice: price,
  observedAt: at,
  dayOfWeek: at.weekday,
  localHour: at.hour,
  sourceType: TaxiObservationSource.existingDatabase,
);

void main() {
  group('multi-city service areas', () {
    test('detects Khujand, Dushanbe, and outside', () {
      expect(
        ServiceAreaRegistry.detect(const LatLng(40.2833, 69.6222))?.id,
        'khujand',
      );
      expect(
        ServiceAreaRegistry.detect(const LatLng(38.5598, 68.7870))?.id,
        'dushanbe',
      );
      expect(ServiceAreaRegistry.detect(const LatLng(39.0, 70.0)), isNull);
    });

    test('manual/last city fallback is stable', () {
      expect(
        ServiceAreaRegistry.resolve(lastCityId: 'dushanbe').id,
        'dushanbe',
      );
      expect(ServiceAreaRegistry.resolve(lastCityId: 'unknown').id, 'khujand');
    });
  });

  group('location and camera state', () {
    final now = DateTime.utc(2026, 8, 4, 12);

    test('stale and poor fixes are not authoritative', () {
      expect(
        LocationFixQuality.evaluate(
          timestamp: now.subtract(const Duration(minutes: 3)),
          accuracyMeters: 10,
          now: now,
        ).state,
        LocationAvailability.stale,
      );
      expect(
        LocationFixQuality.evaluate(
          timestamp: now,
          accuracyMeters: 90,
          now: now,
        ).state,
        LocationAvailability.poorAccuracy,
      );
    });

    test('user gesture owns camera until explicit recenter', () {
      final owned = const CameraOwnership().onUserGesture();
      expect(owned.permitsAutomaticMove, isFalse);
      expect(owned.requestRecenter().permitsAutomaticMove, isTrue);
      expect(
        owned.requestRecenter().consumeMove().permitsAutomaticMove,
        isFalse,
      );
    });

    test('latest request gate rejects stale route response', () {
      final gate = LatestRequestGate();
      final first = gate.begin();
      final second = gate.begin();
      expect(gate.isCurrent(first), isFalse);
      expect(gate.isCurrent(second), isTrue);
    });
  });

  group('delivery quote engine', () {
    test('uses multiplier but enforces delivery and economic floors', () {
      const engine = DeliveryQuoteEngine();
      final market = engine.quote(
        profile: DeliveryPricingProfiles.khujand,
        distanceKm: 4,
        durationMinutes: 15,
        taxiReference: const TaxiReference(
          priceTjs: 40,
          source: 'observations',
          confidence: QuoteConfidence.high,
          sampleCount: 5,
        ),
      );
      expect(market.priceTjs, 20);
      final floor = engine.quote(
        profile: DeliveryPricingProfiles.khujand,
        distanceKm: .1,
        durationMinutes: 1,
        taxiReference: const TaxiReference(
          priceTjs: 4,
          source: 'observations',
          confidence: QuoteConfidence.high,
          sampleCount: 5,
        ),
      );
      expect(floor.priceTjs, 10);
    });

    test('city profiles remain independently configurable', () {
      expect(DeliveryPricingProfiles.khujand.cityId, 'khujand');
      expect(DeliveryPricingProfiles.dushanbe.cityId, 'dushanbe');
      expect(
        DeliveryPricingProfiles.dushanbe.id,
        isNot(DeliveryPricingProfiles.khujand.id),
      );
    });
  });

  test('taxi reference rejects outlier and separates cities', () async {
    final now = DateTime.utc(2026, 8, 4, 12);
    final provider = ExistingDatabaseTaxiPriceProvider(
      _MemoryObservationRepository([
        _observation(price: 28, at: now),
        _observation(price: 30, at: now.subtract(const Duration(days: 1))),
        _observation(price: 29, at: now.subtract(const Duration(days: 2))),
        _observation(price: 500, at: now),
        _observation(price: 10, at: now, city: 'dushanbe'),
      ]),
    );
    final selected = await provider.referenceFor(
      cityId: 'khujand',
      distanceMeters: 5000,
      durationSeconds: 1200,
      at: now,
    );
    expect(selected, isNotNull);
    expect(selected!.priceTjs, inInclusiveRange(27, 31));
    expect(selected.sampleCount, 3);
  });

  test('customer shell exposes delivery only', () {
    final source = File(
      'lib/features/customer/customer_shell.dart',
    ).readAsStringSync();
    expect(source, contains('NewOrderMapScreen'));
    expect(source, isNot(contains('MarketplaceSearchTab')));
    expect(source, isNot(contains('CustomerCartTab')));
    expect(source.toLowerCase(), isNot(contains('taxi')));
  });

  test('all map viewports use centralized tiles and attribution', () {
    final mapFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains('TileLayer('));
    for (final file in mapFiles) {
      final source = file.readAsStringSync();
      expect(
        source,
        contains('MapProviderConfig.current.tileUrlTemplate'),
        reason: file.path,
      );
      expect(source, contains('RichAttributionWidget'), reason: file.path);
    }
  });

  testWidgets('route+quote card exposes delivery CTA without taxi provider', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildNewOrderDetailsPanelForTest())),
    );
    expect(find.text('Оформить доставку'), findsOneWidget);
    expect(find.textContaining('Maxim'), findsNothing);
    expect(find.textContaining('Такси'), findsNothing);
    expect(find.textContaining('Суперапп'), findsNothing);
  });
}
