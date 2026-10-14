import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/authoritative_command_service.dart';
import '../../../core/services/order_repository.dart';
import '../models/tajgo_route.dart';
import 'route_provider.dart';

class ServerRoadRouteProvider implements RouteProvider {
  const ServerRoadRouteProvider(this.commands);
  final AuthoritativeCommandService commands;
  @override
  String get name => 'server-road';
  @override
  Future<TajGoRoute> buildRoute({
    required LatLng from,
    required LatLng to,
    required RouteMode mode,
  }) async {
    final response = await commands.call('getRoadRoute', {
      'pickup': {'latitude': from.latitude, 'longitude': from.longitude},
      'dropoff': {'latitude': to.latitude, 'longitude': to.longitude},
      'transportMode': mode == RouteMode.car ? 'driving' : mode.name,
    });
    final quote = ServerDeliveryQuote(
      status: 'route',
      authoritative: true,
      distanceMeters: (response['distanceMeters'] as num?)?.toDouble(),
      durationSeconds: (response['durationSeconds'] as num?)?.toDouble(),
      routeSource: response['provider'] as String?,
      geometry: ServerDeliveryQuote.parseGeometry(response['geometry']),
    );
    final route = quote.roadRoute(
      GeoPoint(from.latitude, from.longitude),
      GeoPoint(to.latitude, to.longitude),
    );
    if (route == null) {
      throw const TajGoCommandException(
        code: 'unavailable',
        message: 'Дорожный маршрут временно недоступен.',
        retryable: true,
      );
    }
    return route;
  }
}
