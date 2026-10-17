import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tajgo/features/map/models/tajgo_route.dart';
import 'package:tajgo/features/map/services/route_provider.dart';
import 'package:tajgo/features/map/services/route_service.dart';
import 'package:tajgo/features/map/widgets/tajgo_road_route_layer.dart';

class ControlledRoutes implements RouteProvider {
  final requests = <(LatLng, LatLng, Completer<TajGoRoute>)>[];
  @override
  String get name => 'controlled';
  @override
  Future<TajGoRoute> buildRoute({
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
  }) {
    final response = Completer<TajGoRoute>();
    requests.add((from, to, response));
    return response.future;
  }

  void complete(int index) {
    final (from, to, response) = requests[index];
    response.complete(
      TajGoRoute(
        points: [from, LatLng(from.latitude, to.longitude), to],
        distanceKm: 4,
        etaMinutes: 15,
        isRoadRouteApproximation: false,
        providerName: name,
        routeQuality: RouteQuality.road,
        createdAt: DateTime.utc(2026),
      ),
    );
  }
}

void main() {
  const from = LatLng(40.2833, 69.6222);
  const to = LatLng(40.2933, 69.6322);
  Widget map(RouteService service, {LatLng end = to}) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 280,
        child: FlutterMap(
          options: const MapOptions(initialCenter: from, initialZoom: 13),
          children: [
            TajGoRoadRouteLayer(from: from, to: end, routeService: service),
          ],
        ),
      ),
    ),
  );
  testWidgets(
    'failed admin road lookup shows retry and never a straight line',
    (tester) async {
      final provider = ControlledRoutes();
      final service = RouteService(serverProvider: provider);
      await tester.pumpWidget(map(service));
      expect(find.text('Строим маршрут…'), findsOneWidget);
      provider.requests.single.$3.completeError(
        StateError('Network unavailable'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Маршрут недоступен'), findsOneWidget);
      expect(find.byType(PolylineLayer), findsNothing);
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      expect(provider.requests.length, 2);
      provider.complete(1);
      await tester.pumpAndSettle();
      expect(find.text('Маршрут недоступен'), findsNothing);
      final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(layer.polylines.single.points.length, 3);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'switching orders hides late geometry from the previous selection',
    (tester) async {
      final provider = ControlledRoutes();
      final service = RouteService(serverProvider: provider);
      await tester.pumpWidget(map(service));
      const next = LatLng(40.3033, 69.6422);
      await tester.pumpWidget(map(service, end: next));
      provider.complete(0);
      await tester.pump();
      expect(find.byType(PolylineLayer), findsNothing);
      provider.complete(1);
      await tester.pumpAndSettle();
      final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(layer.polylines.single.points.last, next);
      expect(tester.takeException(), isNull);
    },
  );
}
