import assert from "node:assert/strict";
import {after, before, beforeEach, test} from "node:test";
import {deleteApp, initializeApp} from "firebase-admin/app";
import {
  Firestore,
  GeoPoint,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {TajGoAuthoritativeCore} from "../../src/core";
import {CoreError, Principal, hashDeliveryCode} from "../../src/domain";

const now = new Date("2026-07-26T08:00:00.000Z");
const customer = principal("customer-1", "customer");
const customer2 = principal("customer-2", "customer");
const courier = principal("courier-1", "courier");
const courier2 = principal("courier-2", "courier");

let db: Firestore;
let app: ReturnType<typeof initializeApp>;
let core: TajGoAuthoritativeCore;

function principal(uid: string, role: string): Principal {
  return {
    uid,
    token: {
      role,
      phone_number: `+9929000${uid.replace(/\D/g, "").padStart(4, "0")}`,
    },
  };
}

async function clearDatabase(): Promise<void> {
  const collections = await db.listCollections();
  await Promise.all(
    collections.map((collectionRef) => db.recursiveDelete(collectionRef)),
  );
}

async function seedUser(
  actor: Principal,
  role: "customer" | "courier" | "admin",
): Promise<void> {
  await db.collection("users").doc(actor.uid).set({
    uid: actor.uid,
    role,
    roles: role === "courier" ? ["customer", "courier"] : ["customer"],
    courierStatus: role === "courier" ? "approved" : "none",
    phoneNumber: actor.token.phone_number,
    phoneVerified: true,
    displayName: actor.uid,
    updatedAt: Timestamp.fromDate(now),
  });
}

async function seedCourier(
  actor: Principal,
  overrides: Record<string, unknown> = {},
): Promise<void> {
  await seedUser(actor, "courier");
  await db.collection("couriers").doc(actor.uid).set({
    uid: actor.uid,
    displayName: actor.uid,
    isOnline: true,
    online: true,
    activeOrderId: null,
    currentOrderId: null,
    isBusy: false,
    location: new GeoPoint(40.2800, 69.6200),
    locationUpdatedAt: Timestamp.fromDate(now),
    locationAccuracy: 10,
    earningsToday: 0,
    ordersToday: 0,
    ...overrides,
  });
}

async function seedWaitingOrder(
  orderId: string,
  owner: Principal,
  overrides: Record<string, unknown> = {},
): Promise<void> {
  await db.collection("orders").doc(orderId).set({
    customerId: owner.uid,
    customerName: owner.uid,
    status: "waitingOffers",
    orderType: "customDelivery",
    fromLocation: new GeoPoint(40.2802, 69.6201),
    toLocation: new GeoPoint(40.2900, 69.6300),
    fromText: "A",
    toText: "B",
    clientPrice: 25,
    price: 25,
    priceNegotiable: true,
    offersCount: 0,
    createdAt: Timestamp.fromDate(now),
    updatedAt: Timestamp.fromDate(now),
    ...overrides,
  });
}

async function seedPendingOffer(
  orderId: string,
  actor: Principal,
  price = 25,
): Promise<void> {
  await db
    .collection("orders")
    .doc(orderId)
    .collection("offers")
    .doc(actor.uid)
    .set({
      orderId,
      courierId: actor.uid,
      courierName: actor.uid,
      proposedPrice: price,
      status: "pending",
      expiresAt: Timestamp.fromMillis(now.getTime() + 10 * 60 * 1000),
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    });
}

before(() => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "Integration tests must run through the Firestore emulator.",
  );
  app = initializeApp({projectId: "demo-tajgo"});
  db = getFirestore(app);
  core = new TajGoAuthoritativeCore(db, () => now, () => "4321");
});

beforeEach(async () => {
  await clearDatabase();
});

after(async () => {
  await clearDatabase();
  await deleteApp(app);
});

test("duplicate custom-order request creates exactly one order", async () => {
  await seedUser(customer, "customer");
  const data = {
    idempotencyKey: "same-create-request",
    fromText: "Pickup",
    toText: "Dropoff",
    type: "parcel",
    clientPrice: 25,
    fromLocation: {latitude: 40.2800, longitude: 69.6200},
    toLocation: {latitude: 40.2900, longitude: 69.6300},
  };
  const [first, second] = await Promise.all([
    core.createCustomDeliveryOrder({principal: customer, data}),
    core.createCustomDeliveryOrder({principal: customer, data}),
  ]);
  assert.equal(first.orderId, second.orderId);
  const orders = await db.collection("orders").get();
  assert.equal(orders.size, 1);
  const commands = await db
    .collection("command_results")
    .where("command", "==", "createCustomDeliveryOrder")
    .get();
  assert.equal(commands.size, 1);
});

test("callable wrapper rejects an unauthenticated request", async () => {
  const response = await fetch(
    "http://127.0.0.1:5001/demo-tajgo/europe-west1/createCustomDeliveryOrder",
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({data: {}}),
    },
  );
  const payload = (await response.json()) as {
    error?: {status?: string; message?: string};
  };
  assert.equal(payload.error?.status, "UNAUTHENTICATED");
  assert.ok(payload.error?.message);
});

test("customer role cannot submit a courier offer", async () => {
  await seedUser(customer, "customer");
  await seedWaitingOrder("role-order", customer2);
  await assert.rejects(
    core.submitCourierOffer({
      principal: customer,
      data: {
        orderId: "role-order",
        proposedPrice: 25,
        idempotencyKey: "invalid-role-offer-0001",
      },
    }),
    (error: unknown) =>
      error instanceof CoreError && error.code === "permission-denied",
  );
});

test("customer cannot select an offer for somebody else's order", async () => {
  await Promise.all([
    seedUser(customer, "customer"),
    seedUser(customer2, "customer"),
    seedCourier(courier),
  ]);
  await seedWaitingOrder("foreign-owner-order", customer2);
  await seedPendingOffer("foreign-owner-order", courier);
  await assert.rejects(
    core.selectCourierOffer({
      principal: customer,
      data: {
        orderId: "foreign-owner-order",
        offerId: courier.uid,
        idempotencyKey: "foreign-owner-select-0001",
      },
    }),
    (error: unknown) =>
      error instanceof CoreError && error.code === "permission-denied",
  );
});

test("offer submission rejects an order in an invalid status", async () => {
  await seedCourier(courier);
  await seedWaitingOrder("completed-order", customer, {status: "completed"});
  await assert.rejects(
    core.submitCourierOffer({
      principal: courier,
      data: {
        orderId: "completed-order",
        proposedPrice: 25,
        idempotencyKey: "invalid-status-offer-0001",
      },
    }),
    (error: unknown) =>
      error instanceof CoreError && error.code === "failed-precondition",
  );
});

function deletionCore(sink: string[]): TajGoAuthoritativeCore {
  return new TajGoAuthoritativeCore(
    db,
    () => now,
    () => "4321",
    async (uid) => {
      sink.push(uid);
    },
  );
}

test("deleteAccountRequest anonymizes profile and records request", async () => {
  await seedUser(customer, "customer");
  const deleted: string[] = [];
  const result = await deletionCore(deleted).deleteAccountRequest({
    principal: customer,
    data: {idempotencyKey: "delete-account-0001", reason: "не нужно"},
  });
  assert.equal(result.status, "deleted");
  assert.deepEqual(deleted, [customer.uid]);

  const user = (await db.collection("users").doc(customer.uid).get()).data();
  assert.equal(user?.deleted, true);
  assert.equal(user?.displayName, "Удалённый пользователь");
  assert.equal(user?.phoneNumber, null);
  assert.equal(user?.phoneVerified, false);
  assert.equal(user?.role, "deleted");

  const request = (
    await db.collection("account_deletion_requests").doc(customer.uid).get()
  ).data();
  assert.equal(request?.status, "completed");
  assert.equal(request?.uid, customer.uid);

  const logs = await db
    .collection("admin_logs")
    .where("action", "==", "account.delete.self")
    .get();
  assert.equal(logs.size, 1);
});

test("deleteAccountRequest is blocked while an order is active", async () => {
  await seedUser(customer, "customer");
  await seedWaitingOrder("blocking-order", customer);
  const deleted: string[] = [];
  await assert.rejects(
    deletionCore(deleted).deleteAccountRequest({
      principal: customer,
      data: {idempotencyKey: "delete-blocked-0001"},
    }),
    (error: unknown) =>
      error instanceof CoreError && error.code === "failed-precondition",
  );
  const user = (await db.collection("users").doc(customer.uid).get()).data();
  assert.notEqual(user?.deleted, true);
  assert.equal(deleted.length, 0);
});

test("deleteAccountRequest removes courier presence and public doc", async () => {
  await seedCourier(courier);
  await db.collection("courier_public").doc(courier.uid).set({
    uid: courier.uid,
    isOnline: true,
    displayName: courier.uid,
  });
  const deleted: string[] = [];
  await deletionCore(deleted).deleteAccountRequest({
    principal: courier,
    data: {idempotencyKey: "delete-courier-0001"},
  });
  const courierDoc = (
    await db.collection("couriers").doc(courier.uid).get()
  ).data();
  assert.equal(courierDoc?.deleted, true);
  assert.equal(courierDoc?.isOnline, false);
  const publicDoc = await db
    .collection("courier_public")
    .doc(courier.uid)
    .get();
  assert.equal(publicDoc.exists, false);
});

test("deleteAccountRequest is idempotent for the same key", async () => {
  await seedUser(customer, "customer");
  const deleted: string[] = [];
  const core2 = deletionCore(deleted);
  const data = {idempotencyKey: "delete-idem-0001"};
  await core2.deleteAccountRequest({principal: customer, data});
  await core2.deleteAccountRequest({principal: customer, data});
  const commands = await db
    .collection("command_results")
    .where("command", "==", "deleteAccountRequest")
    .get();
  assert.equal(commands.size, 1);
});

test("busy courier cannot submit an offer", async () => {
  await seedCourier(courier, {
    activeOrderId: "existing-order",
    currentOrderId: "existing-order",
    isBusy: true,
  });
  await seedWaitingOrder("busy-courier-order", customer);
  await assert.rejects(
    core.submitCourierOffer({
      principal: courier,
      data: {
        orderId: "busy-courier-order",
        proposedPrice: 25,
        idempotencyKey: "busy-courier-offer-0001",
      },
    }),
    (error: unknown) =>
      error instanceof CoreError &&
      error.code === "failed-precondition" &&
      error.details?.reason === "busy",
  );
});

test("two customers cannot assign the same courier concurrently", async () => {
  await Promise.all([
    seedUser(customer, "customer"),
    seedUser(customer2, "customer"),
    seedCourier(courier),
  ]);
  await Promise.all([
    seedWaitingOrder("order-a", customer),
    seedWaitingOrder("order-b", customer2),
  ]);
  await Promise.all([
    seedPendingOffer("order-a", courier),
    seedPendingOffer("order-b", courier),
  ]);

  const outcomes = await Promise.allSettled([
    core.selectCourierOffer({
      principal: customer,
      data: {
        orderId: "order-a",
        offerId: courier.uid,
        idempotencyKey: "select-order-a-0001",
      },
    }),
    core.selectCourierOffer({
      principal: customer2,
      data: {
        orderId: "order-b",
        offerId: courier.uid,
        idempotencyKey: "select-order-b-0001",
      },
    }),
  ]);
  assert.equal(
    outcomes.filter((outcome) => outcome.status === "fulfilled").length,
    1,
  );
  assert.equal(
    outcomes.filter((outcome) => outcome.status === "rejected").length,
    1,
  );
  const assigned = (
    await db.collection("orders").where("status", "==", "accepted").get()
  ).docs;
  assert.equal(assigned.length, 1);
  const courierDoc = await db.collection("couriers").doc(courier.uid).get();
  assert.equal(courierDoc.data()?.activeOrderId, assigned[0]?.id);
  assert.equal(courierDoc.data()?.isBusy, true);
});

test("one order cannot select two couriers concurrently", async () => {
  await Promise.all([
    seedUser(customer, "customer"),
    seedCourier(courier),
    seedCourier(courier2),
  ]);
  await seedWaitingOrder("contested-order", customer, {offersCount: 2});
  await Promise.all([
    seedPendingOffer("contested-order", courier, 25),
    seedPendingOffer("contested-order", courier2, 30),
  ]);

  const outcomes = await Promise.allSettled([
    core.selectCourierOffer({
      principal: customer,
      data: {
        orderId: "contested-order",
        offerId: courier.uid,
        idempotencyKey: "select-courier-1",
      },
    }),
    core.selectCourierOffer({
      principal: customer,
      data: {
        orderId: "contested-order",
        offerId: courier2.uid,
        idempotencyKey: "select-courier-2",
      },
    }),
  ]);
  assert.equal(
    outcomes.filter((outcome) => outcome.status === "fulfilled").length,
    1,
  );
  const order = await db.collection("orders").doc("contested-order").get();
  assert.equal(order.data()?.status, "accepted");
  const couriers = await db
    .collection("couriers")
    .where("activeOrderId", "==", "contested-order")
    .get();
  assert.equal(couriers.size, 1);
});

test("delivery code rejects a wrong value and completes only once", async () => {
  await seedCourier(courier, {
    activeOrderId: "delivery-order",
    currentOrderId: "delivery-order",
    isBusy: true,
    location: new GeoPoint(40.2900, 69.6300),
  });
  await seedWaitingOrder("delivery-order", customer, {
    status: "delivered",
    courierId: courier.uid,
    selectedCourierId: courier.uid,
    finalPrice: 35,
    price: 35,
  });
  const secret = hashDeliveryCode("4321", "fixed-test-salt");
  await Promise.all([
    db.collection("order_secrets").doc("delivery-order").set({
      orderId: "delivery-order",
      customerId: customer.uid,
      salt: secret.salt,
      hash: secret.hash,
      failedAttempts: 0,
      locked: false,
    }),
    db.collection("order_customer_codes").doc("delivery-order").set({
      orderId: "delivery-order",
      customerId: customer.uid,
      code: "4321",
    }),
  ]);

  await assert.rejects(
    core.completeDeliveryWithCode({
      principal: courier,
      data: {
        orderId: "delivery-order",
        code: "1111",
        idempotencyKey: "wrong-code-0001",
      },
    }),
    (error: unknown) =>
      error instanceof CoreError &&
      error.code === "failed-precondition" &&
      error.details?.reason === "invalid-code",
  );
  const attempted = await db
    .collection("order_secrets")
    .doc("delivery-order")
    .get();
  assert.equal(attempted.data()?.failedAttempts, 1);

  const data = {
    orderId: "delivery-order",
    code: "4321",
    idempotencyKey: "correct-code",
  };
  const first = await core.completeDeliveryWithCode({
    principal: courier,
    data,
  });
  const repeated = await core.completeDeliveryWithCode({
    principal: courier,
    data,
  });
  assert.deepEqual(repeated, first);
  const [order, courierDoc, secrets, codes] = await Promise.all([
    db.collection("orders").doc("delivery-order").get(),
    db.collection("couriers").doc(courier.uid).get(),
    db.collection("order_secrets").doc("delivery-order").get(),
    db.collection("order_customer_codes").doc("delivery-order").get(),
  ]);
  assert.equal(order.data()?.status, "completed");
  assert.equal(courierDoc.data()?.activeOrderId, null);
  assert.equal(courierDoc.data()?.isBusy, false);
  assert.equal(courierDoc.data()?.ordersToday, 1);
  assert.equal(courierDoc.data()?.earningsToday, 35);
  assert.equal(secrets.exists, false);
  assert.equal(codes.exists, false);
});

test("catalog checkout reports changed prices then stores server totals", async () => {
  await seedUser(customer, "customer");
  await db.collection("partners").doc("partner-1").set({
    name: "Real shop",
    address: "Khujand",
    category: "products",
    isActive: true,
    isOpen: true,
    isPublished: true,
    isTest: false,
    isPreview: false,
    minimumOrder: 20,
    deliveryFee: 12,
    location: new GeoPoint(40.2800, 69.6200),
  });
  await db.collection("products").doc("product-1").set({
    partnerId: "partner-1",
    name: "Milk",
    price: 15,
    unit: "item",
    hidden: false,
    isAvailable: true,
    isPublished: true,
    isTest: false,
  });
  const base = {
    partnerId: "partner-1",
    deliveryAddress: "Customer address",
    deliveryLocation: {latitude: 40.2900, longitude: 69.6300},
  };
  await assert.rejects(
    core.createCatalogOrder({
      principal: customer,
      data: {
        ...base,
        items: [
          {productId: "product-1", quantity: 2, knownUnitPrice: 10},
        ],
        idempotencyKey: "catalog-stale-price",
      },
    }),
    (error: unknown) =>
      error instanceof CoreError &&
      error.code === "failed-precondition" &&
      error.details?.reason === "price-changed" &&
      (error.details.currentPrices as Record<string, number>)["product-1"] ===
        15,
  );

  const result = await core.createCatalogOrder({
    principal: customer,
    data: {
      ...base,
      items: [{productId: "product-1", quantity: 2, knownUnitPrice: 15}],
      idempotencyKey: "catalog-current-price",
    },
  });
  assert.equal(result.subtotal, 30);
  assert.equal(result.deliveryFee, 12);
  assert.equal(result.total, 42);
  const order = await db.collection("orders").doc(String(result.orderId)).get();
  assert.equal(order.data()?.subtotal, 30);
  assert.equal(order.data()?.total, 42);
  assert.equal(order.data()?.currency, "TJS");
  assert.equal(order.data()?.items[0].unitPrice, 15);
});

test("preview catalog is blocked by the backend", async () => {
  await seedUser(customer, "customer");
  await db.collection("partners").doc("preview-partner").set({
    name: "Preview",
    address: "Khujand",
    category: "food",
    isActive: true,
    isOpen: true,
    isPublished: true,
    isTest: true,
    isPreview: true,
    minimumOrder: 0,
    deliveryFee: 10,
    location: new GeoPoint(40.2800, 69.6200),
  });
  await db.collection("products").doc("preview-product").set({
    partnerId: "preview-partner",
    name: "Preview item",
    price: 10,
    unit: "item",
    hidden: false,
    isAvailable: true,
    isPublished: true,
    isTest: true,
  });
  await assert.rejects(
    core.createCatalogOrder({
      principal: customer,
      data: {
        partnerId: "preview-partner",
        deliveryAddress: "Customer address",
        deliveryLocation: {latitude: 40.2900, longitude: 69.6300},
        items: [
          {
            productId: "preview-product",
            quantity: 1,
            knownUnitPrice: 10,
          },
        ],
        idempotencyKey: "preview-checkout",
      },
    }),
    (error: unknown) =>
      error instanceof CoreError &&
      error.details?.reason === "preview-blocked",
  );
});
