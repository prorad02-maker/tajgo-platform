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
const merchant = principal("merchant-1", "customer");
const adminActor = principal("admin-1", "admin");

function merchantData(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    storeName: "Гулхона",
    category: "flowers",
    ownerName: "Иван",
    phone: "+992900000000",
    address: "ул. Ленина 1",
    location: {latitude: 40.28, longitude: 69.62},
    deliveryMode: "tajgo",
    minimumOrder: 20,
    consent: true,
    ...overrides,
  };
}

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
  core = new TajGoAuthoritativeCore(
    db,
    () => now,
    () => "4321",
    async () => {},
    async (request) => ({
      distanceMeters: 4200,
      durationSeconds: 1100,
      provider: "test-authoritative-router",
      transportMode: request.transportMode,
    }),
  );
});

beforeEach(async () => {
  await clearDatabase();
});

after(async () => {
  await clearDatabase();
  await deleteApp(app);
});

test("first sign-in creates a profile that survives completion and another login", async () => {
  const actor = principal("first-login-1", "customer");
  const context = {principal: actor, data: {initialIntent: "customer"}};
  await Promise.all([
    core.ensureUserProfile(context),
    core.ensureUserProfile(context),
  ]);
  const userRef = db.collection("users").doc(actor.uid);
  const first = (await userRef.get()).data();
  assert.equal(first?.uid, actor.uid);
  assert.equal(first?.phoneNumber, actor.token.phone_number);
  assert.equal(first?.profileComplete, false);
  assert.equal((await db.collection("users").get()).size, 1);

  await core.completeUserProfile({
    principal: actor,
    data: {
      displayName: "Тестовый клиент",
      initialIntent: "customer",
      idempotencyKey: "complete-first-login-1",
    },
  });
  await core.acceptLegalDocuments({
    principal: actor,
    data: {privacyVersion: "1.0", termsVersion: "1.0", locale: "ru"},
  });
  await core.switchAccountMode({
    principal: actor,
    data: {targetMode: "customer", idempotencyKey: "switch-first-login-1"},
  });
  await core.ensureUserProfile(context);
  const returning = (await userRef.get()).data();
  assert.equal(returning?.displayName, "Тестовый клиент");
  assert.equal(returning?.profileComplete, true);
  assert.equal(returning?.onboardingCompleted, true);
  assert.equal(returning?.role, "customer");
  assert.equal(returning?.lastMode, "customer");
  assert.equal(returning?.legalAcceptance?.privacyVersion, "1.0");
  assert.ok(returning?.createdAt.isEqual(first?.createdAt));
});

test("profile setup preserves an existing administrator role", async () => {
  await seedUser(adminActor, "admin");
  await core.ensureUserProfile({principal: adminActor, data: {}});
  await core.completeUserProfile({
    principal: adminActor,
    data: {
      displayName: "Администратор",
      initialIntent: "customer",
      idempotencyKey: "complete-admin-profile-1",
    },
  });
  await core.ensureUserProfile({principal: adminActor, data: {}});
  const profile = (await db.collection("users").doc(adminActor.uid).get()).data();
  assert.equal(profile?.role, "admin");
  assert.equal(profile?.profileComplete, true);
});

test("profile callables require authentication", async () => {
  for (const command of [
    "ensureUserProfile", "completeUserProfile",
    "acceptLegalDocuments", "switchAccountMode",
  ]) {
    const response = await fetch(
      `http://127.0.0.1:5001/demo-tajgo/europe-west1/${command}`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({data: {}}),
      },
    );
    const payload = (await response.json()) as {error?: {status?: string}};
    assert.equal(response.status, 401, command);
    assert.equal(payload.error?.status, "UNAUTHENTICATED", command);
  }
});

test("duplicate custom-order request creates exactly one order", async () => {
  await seedUser(customer, "customer");
  const quote = await core.getDeliveryQuote({
    principal: customer,
    data: {
      pickup: {latitude: 40.2800, longitude: 69.6200},
      dropoff: {latitude: 40.2900, longitude: 69.6300},
      cityId: "khujand",
      transportMode: "bicycle",
    },
  });
  const data = {
    idempotencyKey: "same-create-request",
    quoteId: quote.quoteId,
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

test("order contact belongs only to the two assigned participants", async () => {
  await seedUser(customer, "customer"); await seedCourier(courier);
  await db.collection("orders").doc("contact-order").set({customerId: customer.uid, courierId: courier.uid, status: "accepted"});
  assert.equal((await core.getOrderContact({principal: courier, data: {orderId: "contact-order"}})).phoneNumber, customer.token.phone_number);
  assert.equal((await core.getOrderContact({principal: customer, data: {orderId: "contact-order"}})).phoneNumber, courier.token.phone_number);
  await assert.rejects(core.getOrderContact({principal: customer2, data: {orderId: "contact-order"}}), (e: unknown) => e instanceof CoreError && e.code === "permission-denied");
});
test("closed deliveries and malformed phone numbers do not expose contacts", async () => {
  await seedUser(customer, "customer"); await seedCourier(courier);
  const ref = db.collection("orders").doc("contact-order");
  await ref.set({customerId: customer.uid, courierId: courier.uid, status: "completed", completedAt: Timestamp.now()});
  await assert.rejects(core.getOrderContact({principal: courier, data: {orderId: "contact-order"}}), (e: unknown) => e instanceof CoreError && e.code === "failed-precondition");
  await ref.set({customerId: customer.uid, courierId: courier.uid, status: "accepted"});
  await db.collection("users").doc(customer.uid).update({phoneNumber: "tel:injection"});
  await assert.rejects(core.getOrderContact({principal: courier, data: {orderId: "contact-order"}}), (e: unknown) => e instanceof CoreError && e.code === "not-found");
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

test("custom order ignores manipulated client preview price", async () => {
  await seedUser(customer, "customer");
  const quote = await core.getDeliveryQuote({
    principal: customer,
    data: {
      pickup: {latitude: 40.2800, longitude: 69.6200},
      dropoff: {latitude: 40.2900, longitude: 69.6300},
      cityId: "khujand",
      transportMode: "bicycle",
    },
  });
  const result = await core.createCustomDeliveryOrder({
    principal: customer,
    data: {
      idempotencyKey: "manipulated-price",
      quoteId: quote.quoteId,
      fromText: "Pickup",
      toText: "Dropoff",
      type: "parcel",
      clientPrice: 9999,
      clientDistanceKm: 0.001,
      clientEtaMinutes: 1,
      fromLocation: {latitude: 40.2800, longitude: 69.6200},
      toLocation: {latitude: 40.2900, longitude: 69.6300},
    },
  });
  const order = (await db.collection("orders").doc(String(result.orderId)).get()).data();
  assert.ok(order != null);
  assert.notEqual(order.clientPrice, 9999);
  assert.equal(order.clientPrice, order.suggestedPrice);
  assert.equal(order.pricingVersion, "delivery-quote-v3");
  assert.equal(order.quoteId, quote.quoteId);
  assert.equal(order.distanceKm, 4.2);
  assert.equal(order.etaMinutes, 19);
});

test("quote rejects mismatched city and unavailable route stays degraded", async () => {
  await assert.rejects(
    core.getDeliveryQuote({
      principal: customer,
      data: {
        pickup: {latitude: 40.2800, longitude: 69.6200},
        dropoff: {latitude: 40.2900, longitude: 69.6300},
        cityId: "dushanbe",
        transportMode: "bicycle",
      },
    }),
    (error: unknown) =>
      error instanceof CoreError && error.details?.reason === "city-mismatch",
  );
  const degradedCore = new TajGoAuthoritativeCore(db, () => now);
  const degraded = await degradedCore.getDeliveryQuote({
    principal: customer,
    data: {
      pickup: {latitude: 40.2800, longitude: 69.6200},
      dropoff: {latitude: 40.2900, longitude: 69.6300},
      cityId: "khujand",
      transportMode: "bicycle",
      routeHint: {distanceMeters: 1},
      finalPrice: 1,
    },
  });
  assert.equal(degraded.status, "degraded");
  assert.equal(degraded.authoritative, false);
  assert.equal(degraded.quoteId, undefined);
});

test("expired and route-mismatched quotes cannot create an order", async () => {
  await seedUser(customer, "customer");
  const quote = await core.getDeliveryQuote({
    principal: customer,
    data: {
      pickup: {latitude: 40.2800, longitude: 69.6200},
      dropoff: {latitude: 40.2900, longitude: 69.6300},
      cityId: "khujand",
      transportMode: "bicycle",
    },
  });
  const base = {
    quoteId: quote.quoteId,
    fromText: "Pickup",
    toText: "Dropoff",
    type: "parcel",
    clientPrice: 9999,
    fromLocation: {latitude: 40.2800, longitude: 69.6200},
    toLocation: {latitude: 40.2910, longitude: 69.6310},
  };
  await assert.rejects(
    core.createCustomDeliveryOrder({
      principal: customer,
      data: {...base, idempotencyKey: "mismatched-quote-route"},
    }),
    (error: unknown) =>
      error instanceof CoreError && error.details?.reason === "quote-input-mismatch",
  );
  await db.collection("delivery_quotes").doc(String(quote.quoteId)).update({
    expiresAt: Timestamp.fromMillis(now.getTime() - 1),
  });
  await assert.rejects(
    core.createCustomDeliveryOrder({
      principal: customer,
      data: {
        ...base,
        idempotencyKey: "expired-quote-route",
        toLocation: {latitude: 40.2900, longitude: 69.6300},
      },
    }),
    (error: unknown) =>
      error instanceof CoreError && error.details?.reason === "quote-expired",
  );
});

test("courier admin callable rejects an unauthenticated request", async () => {
  const response = await fetch(
    "http://127.0.0.1:5001/demo-tajgo/europe-west1/adminApproveCourier",
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({
        data: {courierId: "courier-1", idempotencyKey: "unauth-approve-0001"},
      }),
    },
  );
  const payload = (await response.json()) as {error?: {status?: string}};
  assert.equal(payload.error?.status, "UNAUTHENTICATED");
});

test("courier admin decisions are backend-authorized and transition safely", async () => {
  await seedUser(adminActor, "admin");
  await seedUser(customer, "customer");
  await seedUser(customer2, "customer");
  await db.collection("courier_applications").doc(customer.uid).set({
    uid: customer.uid,
    displayName: "Pending courier",
    phoneNumber: customer.token.phone_number,
    city: "Худжанд",
    transport: "bike",
    status: "pending",
  });
  await db.collection("courier_applications").doc(customer2.uid).set({
    uid: customer2.uid,
    displayName: "Rejected courier",
    status: "pending",
  });

  await assert.rejects(
    core.adminApproveCourier({
      principal: customer,
      data: {
        courierId: customer.uid,
        idempotencyKey: "non-admin-approve-0001",
      },
    }),
    (error: unknown) =>
      error instanceof CoreError && error.code === "permission-denied",
  );
  await assert.rejects(
    core.adminApproveCourier({
      principal: adminActor,
      data: {
        courierId: customer.uid,
        idempotencyKey: "forbidden-approve-0001",
        role: "admin",
        status: "approved",
      },
    }),
    (error: unknown) =>
      error instanceof CoreError &&
      error.code === "invalid-argument" &&
      error.details?.reason === "forbidden-fields",
  );

  const approved = await core.adminApproveCourier({
    principal: adminActor,
    data: {
      courierId: customer.uid,
      idempotencyKey: "valid-approve-0001",
    },
  });
  assert.equal(approved.status, "approved");
  assert.equal(
    (await db.collection("users").doc(customer.uid).get()).data()?.role,
    "customer",
  );
  assert.deepEqual(
    (await db.collection("users").doc(customer.uid).get()).data()?.roles,
    ["customer", "courier"],
  );

  const rejected = await core.adminRejectCourier({
    principal: adminActor,
    data: {
      courierId: customer2.uid,
      reason: "Документ нечитаем",
      idempotencyKey: "valid-reject-0001",
    },
  });
  assert.equal(rejected.status, "rejected");

  const suspended = await core.adminSuspendCourier({
    principal: adminActor,
    data: {
      courierId: customer.uid,
      reason: "Нарушение правил",
      idempotencyKey: "valid-suspend-0001",
    },
  });
  assert.equal(suspended.status, "suspended");
  assert.equal(
    (await db.collection("couriers").doc(customer.uid).get()).data()?.isOnline,
    false,
  );

  const restored = await core.adminRestoreCourier({
    principal: adminActor,
    data: {
      courierId: customer.uid,
      idempotencyKey: "valid-restore-0001",
    },
  });
  assert.equal(restored.status, "approved");
  const logs = await db
    .collection("admin_logs")
    .where("courierId", "==", customer.uid)
    .get();
  assert.equal(logs.size, 3);
  assert.ok(logs.docs.every((doc) => doc.data().adminId === adminActor.uid));
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

test("deleteAccountRequest removes saved addresses", async () => {
  await seedUser(customer, "customer");
  await db
    .collection("users")
    .doc(customer.uid)
    .collection("addresses")
    .doc("addr-1")
    .set({label: "home", shortAddress: "ул. Ленина 1"});
  const deleted: string[] = [];
  const result = await deletionCore(deleted).deleteAccountRequest({
    principal: customer,
    data: {idempotencyKey: "delete-addr-0001"},
  });
  assert.ok(
    (result.anonymizedCategories as string[]).includes("saved-addresses"),
  );
  const remaining = await db
    .collection("users")
    .doc(customer.uid)
    .collection("addresses")
    .get();
  assert.equal(remaining.size, 0);
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

test("acceptLegalDocuments records versions, locale and timestamp", async () => {
  await seedUser(customer, "customer");
  const result = await core.acceptLegalDocuments({
    principal: customer,
    data: {privacyVersion: "1.0", termsVersion: "1.0", locale: "ru"},
  });
  assert.equal(result.accepted, true);
  const user = (await db.collection("users").doc(customer.uid).get()).data();
  const acceptance = user?.legalAcceptance as Record<string, unknown>;
  assert.equal(acceptance?.privacyVersion, "1.0");
  assert.equal(acceptance?.termsVersion, "1.0");
  assert.equal(acceptance?.locale, "ru");
  assert.ok(acceptance?.acceptedAt);
});

async function merchantDoc(): Promise<Record<string, unknown> | undefined> {
  return (
    await db.collection("merchant_applications").doc(merchant.uid).get()
  ).data();
}

test("merchant application lifecycle: draft->submit->needsInfo->approve->convert", async () => {
  await Promise.all([
    seedUser(merchant, "customer"),
    seedUser(adminActor, "admin"),
  ]);
  await core.saveMerchantApplicationDraft({
    principal: merchant,
    data: {storeName: "Гулхона"},
  });
  assert.equal((await merchantDoc())?.status, "draft");

  await core.submitMerchantApplication({
    principal: merchant,
    data: merchantData({idempotencyKey: "merchant-submit-0001"}),
  });
  assert.equal((await merchantDoc())?.status, "submitted");

  await core.adminReviewMerchantApplication({
    principal: adminActor,
    data: {applicationId: merchant.uid, action: "take"},
  });
  await core.adminReviewMerchantApplication({
    principal: adminActor,
    data: {
      applicationId: merchant.uid,
      action: "needsInfo",
      message: "Уточните адрес",
    },
  });
  const afterNeedsInfo = await merchantDoc();
  assert.equal(afterNeedsInfo?.status, "needsInfo");
  assert.equal(afterNeedsInfo?.adminNote, "Уточните адрес");

  await core.updateMerchantApplication({
    principal: merchant,
    data: merchantData({address: "ул. Ленина 2"}),
  });
  assert.equal((await merchantDoc())?.status, "submitted");

  await core.adminReviewMerchantApplication({
    principal: adminActor,
    data: {applicationId: merchant.uid, action: "approve"},
  });
  const convert = await core.adminConvertMerchantApplication({
    principal: adminActor,
    data: {applicationId: merchant.uid, idempotencyKey: "merchant-convert-0001"},
  });
  assert.equal((await merchantDoc())?.status, "convertedToPartner");
  const partner = (
    await db.collection("partners").doc(convert.partnerId as string).get()
  ).data();
  assert.equal(partner?.isPublished, false);
  assert.equal(partner?.isActive, false);
  assert.equal(partner?.sourceApplicationId, merchant.uid);
});

test("merchant conversion is idempotent and creates one partner", async () => {
  await Promise.all([
    seedUser(merchant, "customer"),
    seedUser(adminActor, "admin"),
  ]);
  await core.submitMerchantApplication({
    principal: merchant,
    data: merchantData({idempotencyKey: "merchant-submit-0002"}),
  });
  await core.adminReviewMerchantApplication({
    principal: adminActor,
    data: {applicationId: merchant.uid, action: "approve"},
  });
  const key = "merchant-convert-idem-0002";
  const first = await core.adminConvertMerchantApplication({
    principal: adminActor,
    data: {applicationId: merchant.uid, idempotencyKey: key},
  });
  const second = await core.adminConvertMerchantApplication({
    principal: adminActor,
    data: {applicationId: merchant.uid, idempotencyKey: key},
  });
  assert.equal(first.partnerId, second.partnerId);
  const partners = await db
    .collection("partners")
    .where("sourceApplicationId", "==", merchant.uid)
    .get();
  assert.equal(partners.size, 1);
});

test("non-admin cannot review a merchant application", async () => {
  await seedUser(merchant, "customer");
  await core.submitMerchantApplication({
    principal: merchant,
    data: merchantData({idempotencyKey: "merchant-submit-0003"}),
  });
  await assert.rejects(
    core.adminReviewMerchantApplication({
      principal: merchant,
      data: {applicationId: merchant.uid, action: "approve"},
    }),
    (error: unknown) =>
      error instanceof CoreError && error.code === "permission-denied",
  );
});

test("merchant submit requires consent", async () => {
  await seedUser(merchant, "customer");
  await assert.rejects(
    core.submitMerchantApplication({
      principal: merchant,
      data: merchantData({
        consent: false,
        idempotencyKey: "merchant-submit-0004",
      }),
    }),
    (error: unknown) =>
      error instanceof CoreError && error.code === "failed-precondition",
  );
});

test("withdraw is blocked after conversion", async () => {
  await Promise.all([
    seedUser(merchant, "customer"),
    seedUser(adminActor, "admin"),
  ]);
  await core.submitMerchantApplication({
    principal: merchant,
    data: merchantData({idempotencyKey: "merchant-submit-0005"}),
  });
  await core.adminReviewMerchantApplication({
    principal: adminActor,
    data: {applicationId: merchant.uid, action: "approve"},
  });
  await core.adminConvertMerchantApplication({
    principal: adminActor,
    data: {applicationId: merchant.uid, idempotencyKey: "merchant-convert-0005"},
  });
  await assert.rejects(
    core.withdrawMerchantApplication({principal: merchant, data: {}}),
    (error: unknown) =>
      error instanceof CoreError && error.code === "failed-precondition",
  );
});

const partnerData = {
  name: "Тестовый магазин",
  category: "food",
  address: "ул. Ленина 1",
  location: {latitude: 40.28, longitude: 69.62},
  minimumOrder: 0,
  deliveryFee: 12,
  isOpen: true,
  isActive: true,
  isPublished: true,
};

test("adminSavePartner creates a real published partner", async () => {
  await seedUser(adminActor, "admin");
  const res = await core.adminSavePartner({
    principal: adminActor,
    data: {...partnerData},
  });
  const partner = (
    await db.collection("partners").doc(res.partnerId as string).get()
  ).data();
  assert.equal(partner?.name, "Тестовый магазин");
  assert.equal(partner?.isPublished, true);
  assert.equal(partner?.isPreview, false);
  assert.equal(partner?.isTest, false);
});

test("adminSaveProduct requires an existing partner and keeps SKU", async () => {
  await seedUser(adminActor, "admin");
  await assert.rejects(
    core.adminSaveProduct({
      principal: adminActor,
      data: {partnerId: "missing", name: "P", price: 10},
    }),
    (error: unknown) =>
      error instanceof CoreError && error.code === "failed-precondition",
  );
  const partner = await core.adminSavePartner({
    principal: adminActor,
    data: {...partnerData},
  });
  const product = await core.adminSaveProduct({
    principal: adminActor,
    data: {
      partnerId: partner.partnerId,
      name: "Плов",
      price: 25,
      unit: "portion",
      sku: "PLV-1",
    },
  });
  const doc = (
    await db.collection("products").doc(product.productId as string).get()
  ).data();
  assert.equal(doc?.sku, "PLV-1");
  assert.equal(doc?.isPublished, true);
});

test("adminImportCatalog writes partner and products idempotently", async () => {
  await seedUser(adminActor, "admin");
  const payload = {
    idempotencyKey: "import-catalog-0001",
    partner: {id: "imp-partner", ...partnerData, category: "groceries"},
    products: [
      {id: "imp-1", name: "Хлеб", price: 5, unit: "item", sku: "BR-1"},
      {id: "imp-2", name: "Молоко", price: 8, unit: "item"},
    ],
  };
  await core.adminImportCatalog({principal: adminActor, data: payload});
  await core.adminImportCatalog({principal: adminActor, data: payload});
  const products = await db
    .collection("products")
    .where("partnerId", "==", "imp-partner")
    .get();
  assert.equal(products.size, 2);
  const partner = (
    await db.collection("partners").doc("imp-partner").get()
  ).data();
  assert.equal(partner?.category, "groceries");
});

test("adminSetCourierOffline forces the courier offline", async () => {
  await Promise.all([seedCourier(courier), seedUser(adminActor, "admin")]);
  await db.collection("courier_public").doc(courier.uid).set({
    uid: courier.uid,
    isOnline: true,
  });
  await core.adminSetCourierOffline({
    principal: adminActor,
    data: {courierId: courier.uid},
  });
  const courierDoc = (
    await db.collection("couriers").doc(courier.uid).get()
  ).data();
  assert.equal(courierDoc?.isOnline, false);
});

test("non-admin cannot save a partner", async () => {
  await seedUser(customer, "customer");
  await assert.rejects(
    core.adminSavePartner({principal: customer, data: {...partnerData}}),
    (error: unknown) =>
      error instanceof CoreError && error.code === "permission-denied",
  );
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

test("legacy mobile order completes with private attempt counters while old clients retain its code", async () => {
  await seedCourier(courier, {activeOrderId: "old-delivery", isBusy: true, location: new GeoPoint(40.2900, 69.6300)});
  await seedWaitingOrder("old-delivery", customer, {status: "pickedUp", courierId: courier.uid, confirmationCode: "4321"});
  await assert.rejects(core.completeDeliveryWithCode({principal: courier, data: {orderId: "old-delivery", code: "1111", idempotencyKey: "legacy-wrong-code"}}));
  assert.equal((await db.collection("order_secrets").doc("old-delivery").get()).data()?.failedAttempts, 1);
  assert.equal((await db.collection("orders").doc("old-delivery").get()).data()?.confirmationCode, "4321");
  await core.completeDeliveryWithCode({principal: courier, data: {orderId: "old-delivery", code: "4321", idempotencyKey: "legacy-right-code"}});
  assert.equal((await db.collection("orders").doc("old-delivery").get()).data()?.status, "completed");
  assert.equal((await db.collection("order_secrets").doc("old-delivery").get()).exists, false);
  assert.equal((await db.collection("couriers").doc(courier.uid).get()).data()?.ordersToday, 1);
});
test("completion cannot clear a courier's different active delivery", async () => {
  await seedCourier(courier, {activeOrderId: "new-order", isBusy: true, location: new GeoPoint(40.2900, 69.6300)});
  await seedWaitingOrder("old-order", customer, {status: "pickedUp", courierId: courier.uid, confirmationCode: "4321"});
  await assert.rejects(core.completeDeliveryWithCode({principal: courier, data: {orderId: "old-order", code: "4321", idempotencyKey: "stale-order-code"}}), (e: unknown) => e instanceof CoreError && e.code === "failed-precondition");
  const current = (await db.collection("couriers").doc(courier.uid).get()).data();
  assert.equal(current?.activeOrderId, "new-order"); assert.equal(current?.ordersToday, 0);
});
test("resolving an already-paid dispute cannot pay twice or clear a newer order", async () => {
  await seedUser(adminActor, "admin");
  await seedCourier(courier, {activeOrderId: "new-order", isBusy: true, earningsToday: 35, ordersToday: 1});
  await seedWaitingOrder("paid-order", customer, {status: "disputed", courierId: courier.uid, completedAt: Timestamp.fromDate(now), price: 35});
  await core.adminResolveDispute({principal: adminActor, data: {orderId: "paid-order", resolution: "complete", reason: "Проверено администратором", idempotencyKey: "settled-dispute-resolve"}});
  const current = (await db.collection("couriers").doc(courier.uid).get()).data();
  assert.equal(current?.activeOrderId, "new-order"); assert.equal(current?.earningsToday, 35); assert.equal(current?.ordersToday, 1);
});
test("admin cancellation or return of an old order preserves a newer courier assignment", async () => {
  await seedUser(adminActor, "admin");
  await seedCourier(courier, {activeOrderId: "new-order", isBusy: true});
  for (const resolution of ["adminCancel", "cancel", "returnToWaiting"]) {
    await seedWaitingOrder("old-order", customer, {status: "disputed", courierId: courier.uid});
    const data = {orderId: "old-order", reason: "Проверено администратором", idempotencyKey: `old-order-${resolution}-safe`};
    if (resolution === "adminCancel") await core.adminCancelOrder({principal: adminActor, data});
    else await core.adminResolveDispute({principal: adminActor, data: {...data, resolution}});
    const current = (await db.collection("couriers").doc(courier.uid).get()).data();
    assert.equal(current?.activeOrderId, "new-order"); assert.equal(current?.isBusy, true);
  }
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
