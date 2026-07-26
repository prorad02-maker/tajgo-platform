import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import path from "node:path";
import {after, before, beforeEach, test} from "node:test";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  Timestamp,
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";

let environment: RulesTestEnvironment;

const customerId = "customer-1";
const otherCustomerId = "customer-2";
const courierId = "courier-1";
const otherCourierId = "courier-2";
const adminId = "admin-1";

async function seed(): Promise<void> {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const users = collection(db, "users");
    await Promise.all([
      setDoc(doc(users, customerId), {
        uid: customerId,
        role: "customer",
        roles: ["customer"],
        courierStatus: "none",
        displayName: "Customer",
        updatedAt: Timestamp.now(),
      }),
      setDoc(doc(users, otherCustomerId), {
        uid: otherCustomerId,
        role: "customer",
        roles: ["customer"],
        courierStatus: "none",
        displayName: "Other customer",
        updatedAt: Timestamp.now(),
      }),
      setDoc(doc(users, courierId), {
        uid: courierId,
        role: "courier",
        roles: ["customer", "courier"],
        courierStatus: "approved",
        displayName: "Courier",
        updatedAt: Timestamp.now(),
      }),
      setDoc(doc(users, otherCourierId), {
        uid: otherCourierId,
        role: "courier",
        roles: ["customer", "courier"],
        courierStatus: "approved",
        displayName: "Other courier",
        updatedAt: Timestamp.now(),
      }),
      setDoc(doc(users, adminId), {
        uid: adminId,
        role: "admin",
        roles: ["customer"],
        courierStatus: "none",
        displayName: "Admin",
        updatedAt: Timestamp.now(),
      }),
    ]);

    await Promise.all([
      setDoc(doc(db, "couriers", courierId), {
        uid: courierId,
        isOnline: true,
        online: true,
        activeOrderId: null,
        isBusy: false,
        displayName: "Courier",
        updatedAt: Timestamp.now(),
      }),
      setDoc(doc(db, "couriers", otherCourierId), {
        uid: otherCourierId,
        isOnline: true,
        online: true,
        activeOrderId: null,
        isBusy: false,
        displayName: "Other courier",
        updatedAt: Timestamp.now(),
      }),
      setDoc(doc(db, "courier_public", courierId), {
        uid: courierId,
        displayName: "Courier",
        isOnline: true,
        online: true,
        rating: 5,
        updatedAt: Timestamp.now(),
      }),
    ]);

    await Promise.all([
      setDoc(doc(db, "orders", "waiting-order"), {
        customerId,
        status: "waitingOffers",
        isTestOrder: false,
        createdAt: Timestamp.now(),
      }),
      setDoc(doc(db, "orders", "assigned-order"), {
        customerId,
        courierId,
        selectedCourierId: courierId,
        status: "accepted",
        createdAt: Timestamp.now(),
      }),
      setDoc(doc(db, "orders", "foreign-order"), {
        customerId: otherCustomerId,
        courierId: otherCourierId,
        selectedCourierId: otherCourierId,
        status: "accepted",
        createdAt: Timestamp.now(),
      }),
      setDoc(doc(db, "orders", "legacy-code-order"), {
        customerId,
        courierId,
        selectedCourierId: courierId,
        status: "pickedUp",
        confirmationCode: "1234",
        createdAt: Timestamp.now(),
      }),
      setDoc(doc(db, "orders", "waiting-order", "offers", courierId), {
        courierId,
        status: "pending",
        proposedPrice: 30,
        createdAt: Timestamp.now(),
      }),
      setDoc(doc(db, "order_customer_codes", "assigned-order"), {
        customerId,
        code: "4321",
        createdAt: Timestamp.now(),
      }),
      setDoc(doc(db, "order_secrets", "assigned-order"), {
        hash: "private",
        attempts: 0,
      }),
    ]);

    await Promise.all([
      setDoc(doc(db, "partners", "published"), {
        name: "Published",
        isActive: true,
        isPublished: true,
        isTest: false,
        isPreview: false,
      }),
      setDoc(doc(db, "partners", "inactive"), {
        name: "Inactive",
        isActive: false,
        isPublished: true,
        isTest: false,
        isPreview: false,
      }),
      setDoc(doc(db, "partners", "preview"), {
        name: "Preview",
        isActive: true,
        isPublished: false,
        isTest: false,
        isPreview: true,
      }),
      setDoc(doc(db, "products", "visible-product"), {
        partnerId: "published",
        name: "Visible",
        hidden: false,
        isAvailable: true,
        isPublished: true,
        isTest: false,
      }),
      setDoc(doc(db, "products", "hidden-product"), {
        partnerId: "published",
        name: "Hidden",
        hidden: true,
        isAvailable: true,
        isPublished: false,
        isTest: false,
      }),
      setDoc(doc(db, "admin_logs", "log-1"), {
        action: "seed",
        adminId,
        createdAt: Timestamp.now(),
      }),
      setDoc(doc(db, "account_deletion_requests", customerId), {
        uid: customerId,
        status: "completed",
        createdAt: Timestamp.now(),
      }),
      setDoc(doc(db, "merchant_applications", customerId), {
        ownerId: customerId,
        status: "submitted",
        storeName: "Гулхона",
        createdAt: Timestamp.now(),
      }),
      setDoc(doc(db, "unknown_private", "secret"), {value: true}),
    ]);
  });
}

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "demo-tajgo",
    firestore: {
      rules: readFileSync(
        path.join(process.cwd(), "..", "firestore.rules"),
        "utf8",
      ),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await seed();
});

after(async () => {
  await environment.cleanup();
});

test("anonymous users cannot read protected data", async () => {
  const db = environment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, "partners", "published")));
  await assertFails(getDoc(doc(db, "orders", "waiting-order")));
});

test("customer reads own profile and order but not foreign data", async () => {
  const db = environment.authenticatedContext(customerId).firestore();
  await assertSucceeds(getDoc(doc(db, "users", customerId)));
  await assertSucceeds(getDoc(doc(db, "orders", "assigned-order")));
  await assertFails(getDoc(doc(db, "users", otherCustomerId)));
  await assertFails(getDoc(doc(db, "orders", "foreign-order")));
});

test("customer can update safe profile fields but cannot self-assign role", async () => {
  const db = environment.authenticatedContext(customerId).firestore();
  await assertSucceeds(
    updateDoc(doc(db, "users", customerId), {
      displayName: "Updated customer",
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(db, "users", customerId), {
      role: "admin",
      roles: ["customer", "courier"],
      updatedAt: serverTimestamp(),
    }),
  );
});

test("approved courier reads waiting and assigned orders only", async () => {
  const db = environment.authenticatedContext(courierId).firestore();
  await assertSucceeds(getDoc(doc(db, "orders", "waiting-order")));
  await assertSucceeds(getDoc(doc(db, "orders", "assigned-order")));
  await assertFails(getDoc(doc(db, "orders", "foreign-order")));
  await assertFails(getDoc(doc(db, "orders", "legacy-code-order")));
});

test("customer and courier queries are constrained by document ownership", async () => {
  const customerDb = environment.authenticatedContext(customerId).firestore();
  const courierDb = environment.authenticatedContext(courierId).firestore();
  await assertSucceeds(
    getDocs(
      query(
        collection(customerDb, "orders"),
        where("customerId", "==", customerId),
      ),
    ),
  );
  await assertFails(getDocs(collection(customerDb, "orders")));
  await assertSucceeds(
    getDocs(
      query(
        collection(courierDb, "orders"),
        where("status", "in", ["waiting", "waitingOffers"]),
      ),
    ),
  );
});

test("mobile clients cannot create or perform critical order writes", async () => {
  const customerDb = environment.authenticatedContext(customerId).firestore();
  const courierDb = environment.authenticatedContext(courierId).firestore();
  await assertFails(
    setDoc(doc(customerDb, "orders", "direct-create"), {
      customerId,
      status: "waitingOffers",
    }),
  );
  await assertFails(
    updateDoc(doc(courierDb, "orders", "assigned-order"), {
      status: "pickedUp",
    }),
  );
  await assertFails(
    updateDoc(doc(customerDb, "orders", "waiting-order"), {
      courierId,
      status: "accepted",
    }),
  );
});

test("offers are visible only to order customer and matching courier", async () => {
  const customerDb = environment.authenticatedContext(customerId).firestore();
  const courierDb = environment.authenticatedContext(courierId).firestore();
  const strangerDb = environment
    .authenticatedContext(otherCustomerId)
    .firestore();
  const offerPath = doc(
    customerDb,
    "orders",
    "waiting-order",
    "offers",
    courierId,
  );
  await assertSucceeds(getDoc(offerPath));
  await assertSucceeds(
    getDoc(
      doc(
        courierDb,
        "orders",
        "waiting-order",
        "offers",
        courierId,
      ),
    ),
  );
  await assertFails(
    getDoc(
      doc(
        strangerDb,
        "orders",
        "waiting-order",
        "offers",
        courierId,
      ),
    ),
  );
  await assertFails(updateDoc(offerPath, {proposedPrice: 35}));
});

test("delivery code is customer-only and secret hash is backend-only", async () => {
  const customerDb = environment.authenticatedContext(customerId).firestore();
  const courierDb = environment.authenticatedContext(courierId).firestore();
  await assertSucceeds(
    getDoc(doc(customerDb, "order_customer_codes", "assigned-order")),
  );
  await assertFails(
    getDoc(doc(courierDb, "order_customer_codes", "assigned-order")),
  );
  await assertFails(getDoc(doc(customerDb, "order_secrets", "assigned-order")));
});

test("catalog exposes only published partners and visible products", async () => {
  const db = environment.authenticatedContext(customerId).firestore();
  await assertSucceeds(getDoc(doc(db, "partners", "published")));
  await assertFails(getDoc(doc(db, "partners", "inactive")));
  await assertFails(getDoc(doc(db, "partners", "preview")));
  await assertSucceeds(getDoc(doc(db, "products", "visible-product")));
  await assertFails(getDoc(doc(db, "products", "hidden-product")));
  await assertSucceeds(
    getDocs(
      query(
        collection(db, "partners"),
        where("isActive", "==", true),
        where("isTest", "==", false),
        where("isPreview", "==", false),
        where("isPublished", "==", true),
      ),
    ),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(db, "products"),
        where("partnerId", "==", "published"),
        where("hidden", "==", false),
        where("isTest", "==", false),
        where("isAvailable", "==", true),
        where("isPublished", "==", true),
      ),
    ),
  );
});

test("admin has guarded reads and logs; non-admin cannot access them", async () => {
  const adminDb = environment
    .authenticatedContext(adminId, {admin: true})
    .firestore();
  const customerDb = environment.authenticatedContext(customerId).firestore();
  await assertSucceeds(getDoc(doc(adminDb, "admin_logs", "log-1")));
  await assertSucceeds(
    setDoc(doc(adminDb, "admin_logs", "log-2"), {
      action: "manual-check",
      adminId,
      createdAt: serverTimestamp(),
    }),
  );
  await assertFails(getDoc(doc(customerDb, "admin_logs", "log-1")));
  await assertFails(
    setDoc(doc(customerDb, "admin_logs", "forged"), {
      action: "forged",
      adminId: customerId,
      createdAt: serverTimestamp(),
    }),
  );
});

test("account deletion request is owner/admin read-only, never client-writable", async () => {
  const ownerDb = environment.authenticatedContext(customerId).firestore();
  const otherDb = environment
    .authenticatedContext(otherCustomerId)
    .firestore();
  const adminDb = environment
    .authenticatedContext(adminId, {admin: true})
    .firestore();
  await assertSucceeds(
    getDoc(doc(ownerDb, "account_deletion_requests", customerId)),
  );
  await assertSucceeds(
    getDoc(doc(adminDb, "account_deletion_requests", customerId)),
  );
  await assertFails(
    getDoc(doc(otherDb, "account_deletion_requests", customerId)),
  );
  await assertFails(
    setDoc(doc(ownerDb, "account_deletion_requests", customerId), {
      uid: customerId,
      status: "completed",
    }),
  );
});

test("merchant application is owner/admin read-only, never client-writable", async () => {
  const ownerDb = environment.authenticatedContext(customerId).firestore();
  const otherDb = environment
    .authenticatedContext(otherCustomerId)
    .firestore();
  const adminDb = environment
    .authenticatedContext(adminId, {admin: true})
    .firestore();
  await assertSucceeds(
    getDoc(doc(ownerDb, "merchant_applications", customerId)),
  );
  await assertSucceeds(
    getDoc(doc(adminDb, "merchant_applications", customerId)),
  );
  await assertFails(
    getDoc(doc(otherDb, "merchant_applications", customerId)),
  );
  await assertFails(
    setDoc(doc(ownerDb, "merchant_applications", customerId), {
      ownerId: customerId,
      status: "approved",
    }),
  );
});

test("unknown collections remain denied by default", async () => {
  const adminDb = environment
    .authenticatedContext(adminId, {admin: true})
    .firestore();
  await assertFails(getDoc(doc(adminDb, "unknown_private", "secret")));
  await assertFails(
    setDoc(doc(adminDb, "unknown_private", "new-secret"), {value: true}),
  );
});

test("semantic test fixture contains all intended principals", () => {
  assert.equal(
    new Set([
      customerId,
      otherCustomerId,
      courierId,
      otherCourierId,
      adminId,
    ]).size,
    5,
  );
});
