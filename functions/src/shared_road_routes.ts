import {createHash} from "node:crypto";
import {Firestore, Timestamp} from "firebase-admin/firestore";
import type {AuthoritativeRouteRequest, AuthoritativeRouteResolver, AuthoritativeRouteResult} from "./core";
import {createRoadRouteResolver} from "./road_routes";

export function routeKey(request: AuthoritativeRouteRequest): string {
  return createHash("sha256").update([request.cityId, request.transportMode,
    request.pickup.latitude.toFixed(6), request.pickup.longitude.toFixed(6),
    request.dropoff.latitude.toFixed(6), request.dropoff.longitude.toFixed(6)].join(":")).digest("hex");
}
/** Shared cache and public request budget cover both callable endpoints.
 * Own OSRM endpoints are independent of the public pilot request budget. */
export function createSharedRoadRoutes(db: Firestore, now = Date.now, overrides: Parameters<typeof createRoadRouteResolver>[0] = {}): AuthoritativeRouteResolver {
  const resolve = createRoadRouteResolver({...overrides, now, beforeRequest: async (_, endpoint) => {
    if (endpoint.hostname !== "routing.openstreetmap.de") return true;
    const budget = db.collection("_routing_limits").doc("fossgis-public");
    return db.runTransaction(async transaction => {
      const timestamp = now();
      const previous = (await transaction.get(budget)).data();
      if (Number(previous?.nextAllowedAt ?? 0) > timestamp) return false;
      transaction.set(budget, {nextAllowedAt: timestamp + 1100});
      return true;
    }, {maxAttempts: 8});
  }});
  return async request => {
    const ref = db.collection("_road_route_cache").doc(routeKey(request));
    const saved = (await ref.get()).data();
    if (saved?.expiresAt instanceof Timestamp && saved.expiresAt.toMillis() > now()) {
      return saved.route as AuthoritativeRouteResult;
    }
    const route = await resolve(request);
    if (route) await ref.set({route, expiresAt: Timestamp.fromMillis(now() + 90000)});
    return route;
  };
}
