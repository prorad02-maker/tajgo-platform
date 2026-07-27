import assert from "node:assert/strict";
import test from "node:test";
import {
  CoreError,
  canCourierTransition,
  commandDocumentId,
  evaluateCourierEligibility,
  hashDeliveryCode,
  haversineDistanceMeters,
  notificationLeaksSensitiveData,
  offerReceivedNotification,
  orderStatusNotification,
  validateOfferPrice,
  verifyDeliveryCode,
} from "../../src/domain";

const origin = {latitude: 40.2833, longitude: 69.6222};

function pointNorthAt(meters: number) {
  return {
    latitude: origin.latitude + (meters / 6_371_000) * (180 / Math.PI),
    longitude: origin.longitude,
  };
}

for (const [meters, allowed] of [
  [0, true],
  [500, true],
  [998, true],
  [999, true],
  [999.99, true],
  [1000, false],
  [1000.01, false],
  [1001, false],
] as const) {
  test(`server radius ${meters} m => ${allowed ? "allowed" : "denied"}`, () => {
    const now = new Date("2026-07-26T10:00:00.000Z");
    const result = evaluateCourierEligibility({
      isOnline: true,
      activeOrderId: null,
      isBusy: false,
      courierLocation: origin,
      pickupLocation: pointNorthAt(meters),
      locationUpdatedAt: new Date(now.getTime() - 1000),
      locationAccuracy: 5,
      now,
    });
    assert.equal(result.allowed, allowed);
    assert.ok(
      Math.abs((result.distanceMeters ?? 0) - meters) < 0.02,
      `distance was ${result.distanceMeters}`,
    );
  });
}

test("server radius rejects stale GPS", () => {
  const now = new Date("2026-07-26T10:00:00.000Z");
  const result = evaluateCourierEligibility({
    isOnline: true,
    activeOrderId: null,
    isBusy: false,
    courierLocation: origin,
    pickupLocation: origin,
    locationUpdatedAt: new Date(now.getTime() - 31_000),
    locationAccuracy: 5,
    now,
  });
  assert.equal(result.allowed, false);
  assert.equal(result.reason, "stale-location");
});

test("server radius rejects missing GPS", () => {
  const result = evaluateCourierEligibility({
    isOnline: true,
    activeOrderId: null,
    isBusy: false,
    courierLocation: null,
    pickupLocation: origin,
    locationUpdatedAt: null,
    locationAccuracy: null,
    now: new Date(),
  });
  assert.equal(result.reason, "missing-location");
});

test("server radius rejects invalid coordinates", () => {
  const result = evaluateCourierEligibility({
    isOnline: true,
    activeOrderId: null,
    isBusy: false,
    courierLocation: {latitude: 100, longitude: 0},
    pickupLocation: origin,
    locationUpdatedAt: new Date(),
    locationAccuracy: 5,
    now: new Date(),
  });
  assert.equal(result.reason, "invalid-location");
});

test("server radius rejects poor accuracy", () => {
  const now = new Date();
  const result = evaluateCourierEligibility({
    isOnline: true,
    activeOrderId: null,
    isBusy: false,
    courierLocation: origin,
    pickupLocation: origin,
    locationUpdatedAt: now,
    locationAccuracy: 50.01,
    now,
  });
  assert.equal(result.reason, "poor-accuracy");
});

test("haversine validates coordinate ranges", () => {
  assert.throws(
    () =>
      haversineDistanceMeters(
        {latitude: 91, longitude: 0},
        origin,
      ),
    CoreError,
  );
});

test("delivery code uses salted scrypt and constant-time comparison", () => {
  const secret = hashDeliveryCode("2468", "fixed-salt");
  assert.equal(verifyDeliveryCode("2468", secret), true);
  assert.equal(verifyDeliveryCode("2469", secret), false);
  assert.equal(secret.hash.includes("2468"), false);
});

test("canonical courier transitions reject skipped states", () => {
  assert.equal(canCourierTransition("accepted", "arrivedPickup"), true);
  assert.equal(canCourierTransition("arrivedPickup", "pickedUp"), true);
  assert.equal(canCourierTransition("pickedUp", "delivered"), true);
  assert.equal(canCourierTransition("waitingOffers", "completed"), false);
  assert.equal(canCourierTransition("accepted", "completed"), false);
});

test("offer price must be integer and respect customer price", () => {
  assert.doesNotThrow(() =>
    validateOfferPrice({
      proposedPrice: 20,
      clientPrice: 20,
      priceNegotiable: true,
    }),
  );
  assert.doesNotThrow(() =>
    validateOfferPrice({
      proposedPrice: 21,
      clientPrice: 20,
      priceNegotiable: true,
    }),
  );
  assert.throws(
    () =>
      validateOfferPrice({
        proposedPrice: 19,
        clientPrice: 20,
        priceNegotiable: true,
      }),
    CoreError,
  );
  assert.throws(
    () =>
      validateOfferPrice({
        proposedPrice: 20.5,
        clientPrice: 20,
        priceNegotiable: true,
      }),
    CoreError,
  );
});

test("idempotency document id is stable and scoped by actor/command", () => {
  const first = commandDocumentId("u1", "create", "request-123456");
  assert.equal(first, commandDocumentId("u1", "create", "request-123456"));
  assert.notEqual(first, commandDocumentId("u2", "create", "request-123456"));
  assert.notEqual(first, commandDocumentId("u1", "select", "request-123456"));
});

test("order notification never leaks code, phone or address", () => {
  const notification = orderStatusNotification("pickedUp", "order-1");
  assert.ok(notification != null);
  assert.equal(notification.data.type, "order");
  assert.equal(notification.data.orderId, "order-1");
  assert.equal(
    notificationLeaksSensitiveData(notification, {
      code: "4321",
      phone: "+992900112233",
      address: "ул. Ленина 1",
    }),
    false,
  );
});

test("offer notification is privacy-safe and unknown status yields null", () => {
  const offer = offerReceivedNotification("order-2");
  assert.equal(offer.data.orderId, "order-2");
  assert.equal(
    notificationLeaksSensitiveData(offer, {code: "0000", phone: "+992"}),
    false,
  );
  assert.equal(orderStatusNotification("waitingOffers", "x"), null);
});
