import type {AuthoritativeRouteRequest, AuthoritativeRouteResolver, AuthoritativeRouteResult} from "./core";
import {haversineDistanceMeters} from "./domain";

type Options = {
  fetcher?: typeof fetch;
  now?: () => number;
  timeoutMs?: number;
  endpoints?: Partial<Record<AuthoritativeRouteRequest["transportMode"], string>>;
  beforeRequest?: (request: AuthoritativeRouteRequest, endpoint: URL) => Promise<boolean>;
};
/** OSRM metrics and geometry are resolved on the server, outside transactions.
 * Public bike data is also the pilot approximation for electric scooters;
 * dedicated production profiles can be configured independently per mode. */
export function createRoadRouteResolver(options: Options = {}): AuthoritativeRouteResolver {
  const fetcher = options.fetcher ?? fetch;
  const now = options.now ?? Date.now;
  const cache = new Map<string, {expires: number; route: AuthoritativeRouteResult}>();
  const pending = new Map<string, Promise<AuthoritativeRouteResult | null>>();
  const endpoints = {
    bicycle: process.env.TAJGO_OSRM_BICYCLE_URL ?? "https://routing.openstreetmap.de/routed-bike/route/v1/driving",
    scooter: process.env.TAJGO_OSRM_SCOOTER_URL ?? "https://routing.openstreetmap.de/routed-bike/route/v1/driving",
    driving: process.env.TAJGO_OSRM_DRIVING_URL ?? "https://routing.openstreetmap.de/routed-car/route/v1/driving",
    ...options.endpoints,
  };
  async function resolve(request: AuthoritativeRouteRequest): Promise<AuthoritativeRouteResult | null> {
    try {
      const base = new URL(endpoints[request.transportMode]);
      if (base.protocol !== "https:" || base.username || base.password || base.hash || !base.hostname) return null;
      const coordinate = (value: {latitude: number; longitude: number}) => `${value.longitude.toFixed(6)},${value.latitude.toFixed(6)}`;
      base.pathname = `${base.pathname.replace(/\/$/, "")}/${coordinate(request.pickup)};${coordinate(request.dropoff)}`;
      base.searchParams.set("overview", "full"); base.searchParams.set("geometries", "geojson"); base.searchParams.set("steps", "false");
      if (options.beforeRequest && !await options.beforeRequest(request, base)) return null;
      const response = await fetcher(base, {signal: AbortSignal.timeout(options.timeoutMs ?? 8000),
        headers: {"User-Agent": "TajGo/1.8.1 (+https://github.com/prorad02-maker/tajgo-platform)"}});
      if (!response.ok || !response.body) return null;
      const reader = response.body.getReader();
      const chunks: Uint8Array[] = []; let length = 0;
      for (;;) {
        const {done, value} = await reader.read();
        if (done) break;
        length += value.byteLength;
        if (length > 1048576) {await reader.cancel(); return null;}
        chunks.push(value);
      }
      const body = JSON.parse(Buffer.concat(chunks).toString("utf8"));
      const route = body.routes?.[0];
      if (body.code !== "Ok" || !route || !Number.isFinite(route.distance) || !Number.isFinite(route.duration) ||
          route.distance <= 0 || route.distance > 100000 || route.duration <= 0 || route.duration > 86400 || route.distance / route.duration > 80 ||
          !Array.isArray(route.geometry?.coordinates) || route.geometry.coordinates.length < 2) return null;
      const points: {latitude: number; longitude: number}[] = [];
      for (const pair of route.geometry.coordinates) {
        if (!Array.isArray(pair) || pair.length < 2 || !Number.isFinite(pair[0]) || !Number.isFinite(pair[1]) ||
            Math.abs(pair[0]) > 180 || Math.abs(pair[1]) > 90) return null;
        points.push({latitude: pair[1], longitude: pair[0]});
      }
      if (haversineDistanceMeters(points[0]!, request.pickup) > 500 || haversineDistanceMeters(points[points.length - 1]!, request.dropoff) > 500) return null;
      // Keep large route payloads within callable/Firestore limits, preserving ends.
      const step = Math.max(1, Math.ceil(points.length / 2048));
      const geometry = points.filter((_, index) => index % step === 0 || index === points.length - 1);
      return {distanceMeters: route.distance, durationSeconds: route.duration,
        provider: request.transportMode === "scooter" ? "osrm-bike-scooter-pilot" : `osrm-${request.transportMode}`,
        transportMode: request.transportMode, geometry};
    } catch (_) {return null;}
  }
  return async request => {
    for (const point of [request.pickup, request.dropoff]) {
      if (!Number.isFinite(point.latitude) || !Number.isFinite(point.longitude) || Math.abs(point.latitude) > 90 || Math.abs(point.longitude) > 180) return null;
    }
    const key = `${request.cityId}:${request.transportMode}:${request.pickup.latitude.toFixed(6)},${request.pickup.longitude.toFixed(6)}:${request.dropoff.latitude.toFixed(6)},${request.dropoff.longitude.toFixed(6)}`;
    const cached = cache.get(key);
    if (cached && cached.expires > now()) return cached.route;
    const inProgress = pending.get(key); if (inProgress) return inProgress;
    const operation = resolve(request).then(route => {
      if (route) {
        if (cache.size >= 64) cache.delete(cache.keys().next().value!);
        cache.set(key, {expires: now() + 90000, route});
      }
      return route;
    });
    pending.set(key, operation);
    try {return await operation;} finally {if (pending.get(key) === operation) pending.delete(key);}
  };
}
