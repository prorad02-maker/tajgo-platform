import {
  createHash,
  randomBytes,
  randomInt,
  scryptSync,
  timingSafeEqual,
} from "node:crypto";
import {GeoPoint, Timestamp} from "firebase-admin/firestore";

export type ErrorCode =
  | "unauthenticated"
  | "permission-denied"
  | "invalid-argument"
  | "failed-precondition"
  | "already-exists"
  | "not-found"
  | "aborted"
  | "resource-exhausted";

export class CoreError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = "CoreError";
  }
}

export interface Principal {
  uid: string;
  token: Record<string, unknown>;
}

export interface Coordinate {
  latitude: number;
  longitude: number;
}

export interface CourierEligibilityInput {
  isOnline: boolean;
  activeOrderId: unknown;
  isBusy: boolean;
  courierLocation: Coordinate | null;
  pickupLocation: Coordinate | null;
  locationUpdatedAt: Date | null;
  locationAccuracy: number | null;
  now: Date;
  radiusMeters?: number;
  maxAgeSeconds?: number;
  maxAccuracyMeters?: number;
}

export interface CourierEligibilityResult {
  allowed: boolean;
  distanceMeters: number | null;
  reason:
    | "ok"
    | "offline"
    | "busy"
    | "missing-location"
    | "invalid-location"
    | "stale-location"
    | "poor-accuracy"
    | "outside-radius";
}

export const DEFAULT_ACCEPT_RADIUS_METERS = 1000;
export const MAX_LOCATION_AGE_SECONDS = 30;
export const MAX_LOCATION_ACCURACY_METERS = 50;
export const ACTION_RADIUS_METERS = 2000;
export const MINIMUM_DELIVERY_PRICE = 10;
export const OFFER_LIFETIME_SECONDS = 5 * 60;
export const MAX_CODE_ATTEMPTS = 5;

export function asRecord(value: unknown): Record<string, unknown> {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new CoreError("invalid-argument", "Некорректный формат запроса.");
  }
  return value as Record<string, unknown>;
}

export function requiredString(
  data: Record<string, unknown>,
  key: string,
  options: {min?: number; max?: number; pattern?: RegExp} = {},
): string {
  const value = data[key];
  if (typeof value !== "string") {
    throw new CoreError("invalid-argument", `Поле ${key} обязательно.`);
  }
  const trimmed = value.trim();
  const min = options.min ?? 1;
  const max = options.max ?? 500;
  if (
    trimmed.length < min ||
    trimmed.length > max ||
    (options.pattern != null && !options.pattern.test(trimmed))
  ) {
    throw new CoreError("invalid-argument", `Поле ${key} заполнено неверно.`);
  }
  return trimmed;
}

export function optionalString(
  data: Record<string, unknown>,
  key: string,
  max = 500,
): string | null {
  const value = data[key];
  if (value == null) return null;
  if (typeof value !== "string" || value.trim().length > max) {
    throw new CoreError("invalid-argument", `Поле ${key} заполнено неверно.`);
  }
  return value.trim();
}

export function requiredNumber(
  data: Record<string, unknown>,
  key: string,
  options: {min?: number; max?: number; integer?: boolean} = {},
): number {
  const value = data[key];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new CoreError("invalid-argument", `Поле ${key} обязательно.`);
  }
  if (
    value < (options.min ?? -Number.MAX_VALUE) ||
    value > (options.max ?? Number.MAX_VALUE) ||
    (options.integer === true && !Number.isInteger(value))
  ) {
    throw new CoreError("invalid-argument", `Поле ${key} заполнено неверно.`);
  }
  return value;
}

export function requiredIdempotencyKey(
  data: Record<string, unknown>,
): string {
  return requiredString(data, "idempotencyKey", {
    min: 12,
    max: 128,
    pattern: /^[A-Za-z0-9._:-]+$/,
  });
}

export function parseCoordinate(value: unknown, field: string): Coordinate {
  if (value instanceof GeoPoint) {
    return validateCoordinate(
      {latitude: value.latitude, longitude: value.longitude},
      field,
    );
  }
  const data = asRecord(value);
  const latitude = data.latitude ?? data.lat;
  const longitude = data.longitude ?? data.lng;
  if (typeof latitude !== "number" || typeof longitude !== "number") {
    throw new CoreError("invalid-argument", `Координаты ${field} неверны.`);
  }
  return validateCoordinate({latitude, longitude}, field);
}

export function coordinateFromStored(value: unknown): Coordinate | null {
  try {
    return parseCoordinate(value, "location");
  } catch (_) {
    return null;
  }
}

export function validateCoordinate(
  value: Coordinate,
  field = "location",
): Coordinate {
  if (
    !Number.isFinite(value.latitude) ||
    !Number.isFinite(value.longitude) ||
    value.latitude < -90 ||
    value.latitude > 90 ||
    value.longitude < -180 ||
    value.longitude > 180
  ) {
    throw new CoreError("invalid-argument", `Координаты ${field} неверны.`);
  }
  return value;
}

export function toGeoPoint(value: Coordinate): GeoPoint {
  return new GeoPoint(value.latitude, value.longitude);
}

export function dateFromStored(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

export function haversineDistanceMeters(
  from: Coordinate,
  to: Coordinate,
): number {
  validateCoordinate(from);
  validateCoordinate(to);
  const radians = (degrees: number): number => (degrees * Math.PI) / 180;
  const earthRadiusMeters = 6_371_000;
  const deltaLat = radians(to.latitude - from.latitude);
  const deltaLng = radians(to.longitude - from.longitude);
  const fromLat = radians(from.latitude);
  const toLat = radians(to.latitude);
  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(fromLat) * Math.cos(toLat) * Math.sin(deltaLng / 2) ** 2;
  return (
    earthRadiusMeters *
    2 *
    Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a)))
  );
}

export function evaluateCourierEligibility(
  input: CourierEligibilityInput,
): CourierEligibilityResult {
  if (!input.isOnline) {
    return {allowed: false, distanceMeters: null, reason: "offline"};
  }
  if (input.activeOrderId != null || input.isBusy) {
    return {allowed: false, distanceMeters: null, reason: "busy"};
  }
  if (input.courierLocation == null || input.pickupLocation == null) {
    return {
      allowed: false,
      distanceMeters: null,
      reason: "missing-location",
    };
  }
  try {
    validateCoordinate(input.courierLocation);
    validateCoordinate(input.pickupLocation);
  } catch (_) {
    return {
      allowed: false,
      distanceMeters: null,
      reason: "invalid-location",
    };
  }
  if (input.locationUpdatedAt == null) {
    return {
      allowed: false,
      distanceMeters: null,
      reason: "missing-location",
    };
  }
  const ageMs = input.now.getTime() - input.locationUpdatedAt.getTime();
  const maxAgeMs =
    (input.maxAgeSeconds ?? MAX_LOCATION_AGE_SECONDS) * 1000;
  if (ageMs < -5000 || ageMs > maxAgeMs) {
    return {
      allowed: false,
      distanceMeters: null,
      reason: "stale-location",
    };
  }
  const accuracy = input.locationAccuracy;
  if (
    accuracy == null ||
    !Number.isFinite(accuracy) ||
    accuracy < 0 ||
    accuracy > (input.maxAccuracyMeters ?? MAX_LOCATION_ACCURACY_METERS)
  ) {
    return {
      allowed: false,
      distanceMeters: null,
      reason: "poor-accuracy",
    };
  }
  const distanceMeters = haversineDistanceMeters(
    input.courierLocation,
    input.pickupLocation,
  );
  const allowed =
    distanceMeters < (input.radiusMeters ?? DEFAULT_ACCEPT_RADIUS_METERS);
  return {
    allowed,
    distanceMeters,
    reason: allowed ? "ok" : "outside-radius",
  };
}

export function assertCourierEligibility(
  input: CourierEligibilityInput,
): number {
  const result = evaluateCourierEligibility(input);
  if (!result.allowed) {
    const message = {
      offline: "Сначала выйдите на линию.",
      busy: "Сначала завершите активный заказ.",
      "missing-location": "Не удалось получить свежую позицию курьера.",
      "invalid-location": "Координаты курьера или заказа неверны.",
      "stale-location": "Позиция курьера устарела. Обновите GPS.",
      "poor-accuracy": "Точность GPS недостаточна.",
      "outside-radius": "Заказ находится дальше допустимого радиуса.",
      ok: "Операция недоступна.",
    }[result.reason];
    throw new CoreError("failed-precondition", message, {
      reason: result.reason,
    });
  }
  return result.distanceMeters ?? 0;
}

export const waitingOrderStatuses = new Set([
  "draft",
  "waiting",
  "waitingOffers",
]);

export const activeDeliveryStatuses = new Set([
  "courierSelected",
  "accepted",
  "arrivedPickup",
  "pickedUp",
  "arrivedDropoff",
  "delivered",
  "disputed",
]);

export const terminalOrderStatuses = new Set(["completed", "cancelled"]);

const courierTransitions: Record<string, Set<string>> = {
  accepted: new Set(["arrivedPickup"]),
  arrivedPickup: new Set(["pickedUp"]),
  pickedUp: new Set(["arrivedDropoff", "delivered"]),
  arrivedDropoff: new Set(["delivered"]),
};

export function canCourierTransition(from: string, to: string): boolean {
  return courierTransitions[from]?.has(to) ?? false;
}

export function normalizeStoredStatus(value: unknown): string {
  if (typeof value !== "string") return "waitingOffers";
  return (
    {
      waiting: "waitingOffers",
      draft: "waitingOffers",
      courierSelected: "accepted",
    }[value] ?? value
  );
}

export function validateOfferPrice(input: {
  proposedPrice: number;
  clientPrice: number;
  priceNegotiable: boolean;
}): void {
  const {proposedPrice, clientPrice, priceNegotiable} = input;
  if (
    !Number.isInteger(proposedPrice) ||
    proposedPrice < MINIMUM_DELIVERY_PRICE
  ) {
    throw new CoreError(
      "invalid-argument",
      `Минимальная цена — ${MINIMUM_DELIVERY_PRICE} TJS.`,
    );
  }
  if (
    (priceNegotiable && proposedPrice < clientPrice) ||
    (!priceNegotiable && proposedPrice !== clientPrice)
  ) {
    throw new CoreError(
      "failed-precondition",
      priceNegotiable
        ? "Цена курьера не может быть ниже цены клиента."
        : "Для этого заказа установлена фиксированная цена.",
    );
  }
}

export interface DeliveryCodeSecret {
  salt: string;
  hash: string;
}

export function generateDeliveryCode(): string {
  return randomInt(0, 10_000).toString().padStart(4, "0");
}

export function hashDeliveryCode(
  code: string,
  salt = randomBytes(16).toString("hex"),
): DeliveryCodeSecret {
  if (!/^\d{4}$/.test(code)) {
    throw new CoreError("invalid-argument", "Код должен содержать 4 цифры.");
  }
  return {
    salt,
    hash: scryptSync(code, salt, 32).toString("hex"),
  };
}

export function verifyDeliveryCode(
  code: string,
  secret: DeliveryCodeSecret,
): boolean {
  if (!/^\d{4}$/.test(code)) return false;
  const expected = Buffer.from(secret.hash, "hex");
  const actual = scryptSync(code, secret.salt, expected.length);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

export function commandDocumentId(
  uid: string,
  command: string,
  idempotencyKey: string,
): string {
  return createHash("sha256")
    .update(`${uid}:${command}:${idempotencyKey}`)
    .digest("hex");
}

export function deterministicOrderId(
  uid: string,
  command: string,
  idempotencyKey: string,
): string {
  return createHash("sha256")
    .update(`order:${uid}:${command}:${idempotencyKey}`)
    .digest("hex")
    .slice(0, 32);
}

export function suggestedDeliveryPrice(distanceKm: number): number {
  return Math.max(
    MINIMUM_DELIVERY_PRICE,
    Math.round(7 + 3 * distanceKm),
  );
}

export function deliveryEtaMinutes(distanceKm: number): number {
  return Math.max(1, Math.ceil((distanceKm / 18) * 60) + 5);
}
