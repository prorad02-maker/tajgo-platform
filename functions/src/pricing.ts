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
  dayOfWeek: number;
  localHour: number;
  sourceType: string;
  quality: number;
}

export interface TaxiReferenceSelection {
  priceTjs: number;
  sampleCount: number;
  confidence: number;
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
  khujand: {id: "delivery_khujand_v2", cityId: "khujand", ...base},
  dushanbe: {id: "delivery_dushanbe_v2", cityId: "dushanbe", ...base},
};

export function pricingProfile(cityId: string): PricingProfile {
  const profile = PRICING_PROFILES[cityId];
  if (profile == null) throw new Error(`Unsupported city: ${cityId}`);
  return profile;
}

export function detectServiceCity(point: {latitude: number; longitude: number}): string | null {
  if (point.latitude >= 40.20 && point.latitude <= 40.36 &&
      point.longitude >= 69.50 && point.longitude <= 69.76) return "khujand";
  if (point.latitude >= 38.44 && point.latitude <= 38.68 &&
      point.longitude >= 68.68 && point.longitude <= 68.93) return "dushanbe";
  return null;
}

export function selectTaxiReference(input: {
  observations: TaxiObservation[];
  cityId: string;
  distanceMeters: number;
  durationSeconds: number;
  at: Date;
  minimumSamples?: number;
}): TaxiReferenceSelection | null {
  const minimumSamples = input.minimumSamples ?? 3;
  const candidates = input.observations.filter((item) => {
    if (item.cityId !== input.cityId || item.currency !== "TJS" || item.quotedPrice <= 0) return false;
    const distanceRatio = item.distanceMeters / Math.max(input.distanceMeters, 1);
    const durationRatio = item.durationSeconds / Math.max(input.durationSeconds, 1);
    return distanceRatio >= 0.55 && distanceRatio <= 1.8 && durationRatio >= 0.4 && durationRatio <= 2.2;
  });
  if (candidates.length < minimumSamples) return null;
  const units = candidates
    .map((item) => item.quotedPrice / Math.max(item.distanceMeters, 1))
    .sort((a, b) => a - b);
  const median = units[Math.floor(units.length / 2)]!;
  const filtered = candidates.filter((item) => {
    const unit = item.quotedPrice / Math.max(item.distanceMeters, 1);
    return unit >= median * 0.45 && unit <= median * 2.2;
  });
  if (filtered.length < minimumSamples) return null;
  let weighted = 0;
  let weightTotal = 0;
  for (const item of filtered) {
    const ageDays = Math.abs(input.at.getTime() - item.observedAt.getTime()) / 86_400_000;
    const recency = 1 / (1 + ageDays / 14);
    const hourDistance = Math.abs(item.localHour - input.at.getHours());
    const hourWeight = 1 / (1 + Math.min(hourDistance, 24 - hourDistance) / 4);
    const dayWeight = item.dayOfWeek === input.at.getDay() ? 1.2 : 1;
    const weight = recency * hourWeight * dayWeight * Math.min(1, Math.max(0.1, item.quality));
    weighted += item.quotedPrice * weight;
    weightTotal += weight;
  }
  return {
    priceTjs: weighted / weightTotal,
    sampleCount: filtered.length,
    confidence: Math.min(1, filtered.length / 8) * Math.min(1, weightTotal / filtered.length),
    source: "existing_database_observations",
  };
}

export function calculateDeliveryQuote(input: {
  profile: PricingProfile;
  distanceMeters: number;
  durationSeconds: number;
  taxiReference?: TaxiReferenceSelection | null;
}): {priceTjs: number; currency: "TJS"; confidence: "low" | "medium" | "high"; source: string} {
  const {profile} = input;
  const fallback = profile.fallbackBasePrice +
    profile.fallbackPerKm * input.distanceMeters / 1000 +
    profile.fallbackPerMinute * input.durationSeconds / 60;
  const marketTarget = input.taxiReference == null ?
    fallback : input.taxiReference.priceTjs * profile.taxiReferenceMultiplier;
  const price = Math.ceil(Math.max(
    marketTarget,
    profile.minimumDeliveryPrice,
    profile.minimumCourierPayout + profile.platformMinimumMargin,
  ) * profile.surgeFactor);
  const confidence = input.taxiReference == null ? "low" :
    input.taxiReference.confidence >= 0.7 ? "high" : "medium";
  return {
    priceTjs: price,
    currency: "TJS",
    confidence,
    source: input.taxiReference?.source ?? "city_fallback",
  };
}
