import {createHash} from "node:crypto";

export type QuoteConfidence = "low" | "medium" | "high";
export type DeliveryTransportMode = "bicycle" | "scooter" | "driving";

export interface PricingProfile {
  id: string;
  cityId: string;
  taxiReferenceMultiplier: number;
  minimumDeliveryPrice: number;
  minimumCourierPayout: number;
  platformMinimumMargin: number;
  fallbackBasePrice: number;
  fallbackPerKm: number;
  fallbackPerMinute: number;
  surgeFactor: number;
}

export interface DeliveryQuoteInput {
  cityId: string;
  distanceMeters: number;
  durationSeconds: number;
  transportMode: DeliveryTransportMode;
}

export interface DeliveryQuoteResult {
  priceTjs: number;
  currency: "TJS";
  confidence: QuoteConfidence;
  source: string;
  pricingProfileId: string;
  pricingVersion: "delivery-quote-v3";
}

export interface TaxiObservation {
  cityId: string;
  provider: string;
  pickupBucket: string;
  dropoffBucket: string;
  distanceMeters: number;
  durationSeconds: number;
  quotedPrice: number;
  currency: "TJS";
  observedAt: Date;
  /** ISO weekday: Monday=1 ... Sunday=7. */
  dayOfWeek: number;
  /** Local Tajikistan hour, 0...23. */
  localHour: number;
  sourceType: string;
  quality: number;
}

export interface TaxiReferenceSelection {
  priceTjs: number;
  sampleCount: number;
  confidence: number;
  confidenceLevel: QuoteConfidence;
  source: string;
}

const base = {
  taxiReferenceMultiplier: 0.5,
  minimumDeliveryPrice: 10,
  minimumCourierPayout: 7,
  platformMinimumMargin: 3,
  fallbackBasePrice: 7,
  fallbackPerKm: 3,
  fallbackPerMinute: 0,
  surgeFactor: 1,
};

export const PRICING_PROFILES: Record<string, PricingProfile> = {
  khujand: {id: "delivery_khujand_v3", cityId: "khujand", ...base},
  dushanbe: {id: "delivery_dushanbe_v3", cityId: "dushanbe", ...base},
};

const MAX_DISTANCE_METERS = 100_000;
const MAX_DURATION_SECONDS = 24 * 60 * 60;
const MAX_OBSERVED_PRICE_TJS = 10_000;
const MAX_OBSERVATION_AGE_MS = 45 * 86_400_000;
const MAX_FUTURE_SKEW_MS = 5 * 60_000;

function finiteInRange(value: number, min: number, max: number): boolean {
  return Number.isFinite(value) && value >= min && value <= max;
}

export function pricingProfile(cityId: string): PricingProfile {
  const profile = PRICING_PROFILES[cityId];
  if (profile == null) throw new Error(`Unsupported city: ${cityId}`);
  validatePricingProfile(profile);
  return profile;
}

export function validatePricingProfile(profile: PricingProfile): void {
  const values = [
    profile.minimumDeliveryPrice,
    profile.minimumCourierPayout,
    profile.platformMinimumMargin,
    profile.fallbackBasePrice,
    profile.fallbackPerKm,
    profile.fallbackPerMinute,
  ];
  if (values.some((value) => !finiteInRange(value, 0, 10_000)) ||
      !finiteInRange(profile.taxiReferenceMultiplier, 0.01, 1) ||
      !finiteInRange(profile.surgeFactor, 0.5, 3)) {
    throw new Error("Invalid pricing profile.");
  }
}

export function detectServiceCity(point: {latitude: number; longitude: number}): string | null {
  if (point.latitude >= 40.20 && point.latitude <= 40.36 &&
      point.longitude >= 69.50 && point.longitude <= 69.76) return "khujand";
  if (point.latitude >= 38.44 && point.latitude <= 38.68 &&
      point.longitude >= 68.68 && point.longitude <= 68.93) return "dushanbe";
  return null;
}

/** Tajikistan uses UTC+05:00 without a seasonal offset. */
export function tajikLocalParts(at: Date): {isoWeekday: number; hour: number} {
  const shifted = new Date(at.getTime() + 5 * 60 * 60 * 1000);
  const sundayZero = shifted.getUTCDay();
  return {isoWeekday: sundayZero === 0 ? 7 : sundayZero, hour: shifted.getUTCHours()};
}

export function isValidTaxiObservation(item: TaxiObservation, now: Date): boolean {
  const ageMs = now.getTime() - item.observedAt.getTime();
  return item.currency === "TJS" &&
    item.cityId.length > 0 && item.provider.trim().length > 0 &&
    finiteInRange(item.distanceMeters, 1, MAX_DISTANCE_METERS) &&
    finiteInRange(item.durationSeconds, 1, MAX_DURATION_SECONDS) &&
    finiteInRange(item.quotedPrice, 1, MAX_OBSERVED_PRICE_TJS) &&
    finiteInRange(item.quality, 0.1, 1) &&
    Number.isInteger(item.dayOfWeek) && item.dayOfWeek >= 1 && item.dayOfWeek <= 7 &&
    Number.isInteger(item.localHour) && item.localHour >= 0 && item.localHour <= 23 &&
    Number.isFinite(item.observedAt.getTime()) &&
    ageMs >= -MAX_FUTURE_SKEW_MS && ageMs <= MAX_OBSERVATION_AGE_MS;
}

function observationKey(item: TaxiObservation): string {
  return [
    item.cityId,
    item.provider.trim().toLowerCase(),
    item.pickupBucket.trim().toLowerCase(),
    item.dropoffBucket.trim().toLowerCase(),
    Math.round(item.distanceMeters / 50),
    Math.round(item.durationSeconds / 30),
    item.quotedPrice.toFixed(2),
    Math.floor(item.observedAt.getTime() / 300_000),
  ].join("|");
}

export function selectTaxiReference(input: {
  observations: TaxiObservation[];
  cityId: string;
  distanceMeters: number;
  durationSeconds: number;
  at: Date;
  minimumSamples?: number;
}): TaxiReferenceSelection | null {
  validateRouteMetrics(input.distanceMeters, input.durationSeconds);
  const minimumSamples = input.minimumSamples ?? 3;
  if (!Number.isInteger(minimumSamples) || minimumSamples < 3) return null;
  const seen = new Set<string>();
  const providerCounts = new Map<string, number>();
  const candidates = input.observations.filter((item) => {
    if (item.cityId !== input.cityId || !isValidTaxiObservation(item, input.at)) return false;
    const key = observationKey(item);
    if (seen.has(key)) return false;
    const provider = item.provider.trim().toLowerCase();
    const count = providerCounts.get(provider) ?? 0;
    if (count >= 10) return false;
    const distanceRatio = item.distanceMeters / Math.max(input.distanceMeters, 1);
    const durationRatio = item.durationSeconds / Math.max(input.durationSeconds, 1);
    if (distanceRatio < 0.55 || distanceRatio > 1.8 ||
        durationRatio < 0.4 || durationRatio > 2.2) return false;
    seen.add(key);
    providerCounts.set(provider, count + 1);
    return true;
  });
  if (candidates.length < minimumSamples) return null;
  const units = candidates
    .map((item) => item.quotedPrice / item.distanceMeters)
    .sort((a, b) => a - b);
  const median = units[Math.floor(units.length / 2)]!;
  const filtered = candidates.filter((item) => {
    const unit = item.quotedPrice / item.distanceMeters;
    return unit >= median * 0.5 && unit <= median * 2;
  });
  if (filtered.length < minimumSamples) return null;
  const local = tajikLocalParts(input.at);
  let weighted = 0;
  let weightTotal = 0;
  for (const item of filtered) {
    const ageDays = Math.max(0, input.at.getTime() - item.observedAt.getTime()) / 86_400_000;
    const recency = 1 / (1 + ageDays / 14);
    const hourDistance = Math.abs(item.localHour - local.hour);
    const hourWeight = 1 / (1 + Math.min(hourDistance, 24 - hourDistance) / 4);
    const dayWeight = item.dayOfWeek === local.isoWeekday ? 1.2 : 1;
    const weight = recency * hourWeight * dayWeight * item.quality;
    weighted += item.quotedPrice * weight;
    weightTotal += weight;
  }
  if (!Number.isFinite(weightTotal) || weightTotal <= 0) return null;
  const score = Math.min(1, filtered.length / 8) *
    Math.min(1, weightTotal / filtered.length);
  const confidenceLevel: QuoteConfidence = score >= 0.7 ? "high" :
    score >= 0.4 ? "medium" : "low";
  return {
    priceTjs: weighted / weightTotal,
    sampleCount: filtered.length,
    confidence: score,
    confidenceLevel,
    source: "existing_database_observations",
  };
}

export function validateRouteMetrics(distanceMeters: number, durationSeconds: number): void {
  if (!finiteInRange(distanceMeters, 0, MAX_DISTANCE_METERS) ||
      !finiteInRange(durationSeconds, 0, MAX_DURATION_SECONDS)) {
    throw new Error("Invalid route metrics.");
  }
}

/** Canonical TJS rounding: apply surge after all floors, then round upward to 1 TJS. */
export function roundTjs(value: number): number {
  if (!finiteInRange(value, 0, 1_000_000)) throw new Error("Invalid TJS value.");
  return Math.ceil(value - Number.EPSILON);
}

export function calculateDeliveryQuote(input: {
  profile: PricingProfile;
  distanceMeters: number;
  durationSeconds: number;
  taxiReference?: TaxiReferenceSelection | null;
}): DeliveryQuoteResult {
  const {profile} = input;
  validatePricingProfile(profile);
  validateRouteMetrics(input.distanceMeters, input.durationSeconds);
  const reference = input.taxiReference;
  if (reference != null && !finiteInRange(reference.priceTjs, 1, MAX_OBSERVED_PRICE_TJS)) {
    throw new Error("Invalid taxi reference.");
  }
  const fallback = profile.fallbackBasePrice +
    profile.fallbackPerKm * input.distanceMeters / 1000 +
    profile.fallbackPerMinute * input.durationSeconds / 60;
  const marketTarget = reference == null ?
    fallback : reference.priceTjs * profile.taxiReferenceMultiplier;
  const price = roundTjs(Math.max(
    marketTarget,
    profile.minimumDeliveryPrice,
    profile.minimumCourierPayout + profile.platformMinimumMargin,
  ) * profile.surgeFactor);
  return {
    priceTjs: price,
    currency: "TJS",
    confidence: reference?.confidenceLevel ?? "low",
    source: reference?.source ?? "city_fallback",
    pricingProfileId: profile.id,
    pricingVersion: "delivery-quote-v3",
  };
}

export function deliveryInputFingerprint(input: {
  cityId: string;
  pickup: {latitude: number; longitude: number};
  dropoff: {latitude: number; longitude: number};
  transportMode: DeliveryTransportMode;
}): string {
  const coordinate = (value: number): string => value.toFixed(6);
  return createHash("sha256").update([
    "delivery-quote-v3",
    input.cityId,
    input.transportMode,
    coordinate(input.pickup.latitude),
    coordinate(input.pickup.longitude),
    coordinate(input.dropoff.latitude),
    coordinate(input.dropoff.longitude),
  ].join("|")).digest("hex");
}
