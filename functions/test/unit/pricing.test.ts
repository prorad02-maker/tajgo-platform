import assert from "node:assert/strict";
import test from "node:test";
import {
  TaxiObservation,
  calculateDeliveryQuote,
  detectServiceCity,
  pricingProfile,
  selectTaxiReference,
} from "../../src/pricing";

function observation(price: number, at: Date, cityId = "khujand"): TaxiObservation {
  return {
    cityId,
    provider: "market-observation",
    pickupBucket: "a",
    dropoffBucket: "b",
    distanceMeters: 5000,
    durationSeconds: 1200,
    quotedPrice: price,
    currency: "TJS",
    observedAt: at,
    dayOfWeek: at.getDay(),
    localHour: at.getHours(),
    sourceType: "existingDatabase",
    quality: 1,
  };
}

test("pricing multiplier and economic floors", () => {
  const profile = pricingProfile("khujand");
  assert.equal(calculateDeliveryQuote({
    profile,
    distanceMeters: 5000,
    durationSeconds: 1200,
    taxiReference: {priceTjs: 40, sampleCount: 5, confidence: 0.9, source: "db"},
  }).priceTjs, 20);
  assert.equal(calculateDeliveryQuote({
    profile,
    distanceMeters: 100,
    durationSeconds: 60,
    taxiReference: {priceTjs: 4, sampleCount: 5, confidence: 0.9, source: "db"},
  }).priceTjs, 10);
});

test("insufficient samples return fallback signal", () => {
  const now = new Date("2026-08-04T12:00:00Z");
  assert.equal(selectTaxiReference({
    observations: [observation(30, now)],
    cityId: "khujand",
    distanceMeters: 5000,
    durationSeconds: 1200,
    at: now,
  }), null);
});

test("recent samples beat stale samples and outlier is rejected", () => {
  const now = new Date("2026-08-04T12:00:00Z");
  const selected = selectTaxiReference({
    observations: [
      observation(30, now),
      observation(31, new Date("2026-08-03T12:00:00Z")),
      observation(29, new Date("2026-08-02T12:00:00Z")),
      observation(20, new Date("2025-01-01T12:00:00Z")),
      observation(500, now),
      observation(5, now, "dushanbe"),
    ],
    cityId: "khujand",
    distanceMeters: 5000,
    durationSeconds: 1200,
    at: now,
  });
  assert.ok(selected != null);
  assert.ok(selected.priceTjs > 27 && selected.priceTjs < 32);
  assert.equal(selected.sampleCount, 4);
});

test("client price manipulation is absent from quote inputs", () => {
  const quote = calculateDeliveryQuote({
    profile: pricingProfile("dushanbe"),
    distanceMeters: 4000,
    durationSeconds: 900,
  });
  assert.equal(quote.priceTjs, 19);
  assert.equal(quote.source, "city_fallback");
});

test("service city detection separates Khujand, Dushanbe, and outside", () => {
  assert.equal(detectServiceCity({latitude: 40.2833, longitude: 69.6222}), "khujand");
  assert.equal(detectServiceCity({latitude: 38.5598, longitude: 68.7870}), "dushanbe");
  assert.equal(detectServiceCity({latitude: 39, longitude: 70}), null);
});
