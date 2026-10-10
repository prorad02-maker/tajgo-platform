'use strict';
const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, GeoPoint, Timestamp} = require('firebase-admin/firestore');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, getDocs, collection, query, where, orderBy, setDoc, updateDoc, serverTimestamp, writeBatch, increment, GeoPoint: ClientGeoPoint} = require('firebase/firestore');
const {createOrderCommands, meters} = require('../order_commands');

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Tests require the Firestore Emulator; refusing to access a live database.');
const projectId = 'demo-tajgo-readiness';
const app = initializeApp({projectId});
const db = getFirestore(app);
let rules, clock, command;
const pickup = {latitude: 40.2833, longitude: 69.6222, address: 'Сомони, 54'};
const dropoff = {latitude: 40.2933, longitude: 69.6322, address: 'Гагарина, 12'};
let seq = 0;
function call(uid, action, data = {}, requestId = `request-${++seq}`) {
  return command({auth: uid ? {uid, token: {phone_number: '+992000000000'}} : null, data: {action, requestId, ...data}});
}
const rejects = (promise, code) => assert.rejects(promise, error => error.code === code);
async function create(requestId) { return (await call('customer', 'create', {pickup, dropoff, price: 20}, requestId)).orderId; }
async function assigned() {
  const orderId = await create();
  await call('courier', 'offer', {orderId, proposedPrice: 22});
  await call('customer', 'select', {orderId, offerId: 'courier'});
  return orderId;
}
async function pickedUp() {
  const orderId = await assigned();
  await call('courier', 'arrive', {orderId});
  await call('courier', 'pickup', {orderId});
  return orderId;
}
before(async () => {
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  rules = await initializeTestEnvironment({projectId, firestore: {host, port: Number(port), rules: readFileSync('../firestore.rules', 'utf8')}});
});
beforeEach(async () => {
  await rules.clearFirestore();
  clock = Date.now();
  command = createOrderCommands(db, {now: () => clock});
  await Promise.all([
    db.doc('users/customer').set({displayName: 'Клиент', role: 'customer'}),
    db.doc('users/foreign').set({displayName: 'Другой клиент', role: 'customer'}),
    db.doc('users/admin').set({displayName: 'Админ', role: 'admin'}),
    ...['courier', 'courier2'].flatMap(uid => [
      db.doc(`users/${uid}`).set({displayName: 'Курьер', role: 'courier', roles: ['customer', 'courier'], courierStatus: 'approved', courierOnboardingCompleted: true}),
      db.doc(`couriers/${uid}`).set({uid, displayName: 'Курьер', name: 'Курьер', isOnline: true, online: true, isBusy: false, activeOrderId: null, location: new GeoPoint(pickup.latitude, pickup.longitude), locationAccuracy: 10, locationUpdatedAt: Timestamp.fromMillis(clock), earningsToday: 0, ordersToday: 0}),
    ]),
  ]);
});
after(async () => {await rules.cleanup(); await db.terminate(); await deleteApp(app);});

test('unauthenticated commands are denied', async () => rejects(call(null, 'create', {pickup, dropoff, price: 20}), 'unauthenticated'));
test('customer identity and confirmation code come from server', async () => {
  const orderId = (await call('customer', 'create', {pickup, dropoff, price: 20, customerId: 'foreign', confirmationCode: '9999'})).orderId;
  const order = (await db.doc(`orders/${orderId}`).get()).data();
  assert.equal(order.customerId, 'customer');
  assert.equal(order.confirmationCode, undefined);
  assert.equal(order.commandVersion, 'server-v1');
  assert.match((await db.doc(`order_receipts/${orderId}`).get()).data().confirmationCode, /^\d{4}$/);
});
test('parallel retries create exactly one order and mismatched reuse is rejected', async () => {
  const results = await Promise.all([create('same-create'), create('same-create')]);
  assert.equal(results[0], results[1]);
  assert.equal((await db.collection('orders').get()).size, 1);
  await rejects(call('customer', 'create', {pickup, dropoff, price: 99}, 'same-create'), 'already-exists');
});
test('distinct parallel creates are serialized and cancellation releases the customer', async () => {
  const attempts = await Promise.allSettled([create('first-create'), create('second-create')]);
  assert.equal(attempts.filter(attempt => attempt.status === 'fulfilled').length, 1);
  assert.equal((await db.collection('orders').get()).size, 1);
  const orderId = attempts.find(attempt => attempt.status === 'fulfilled').value;
  await rejects(create('third-create'), 'failed-precondition');
  await call('customer', 'cancel', {orderId});
  assert.notEqual(await create('next-create'), orderId);
});

test('server creation detects an active legacy order during migration', async () => {
  await db.doc('orders/legacy-active').set({customerId: 'customer', status: 'accepted'});
  await rejects(create(), 'failed-precondition');
});
test('foreign customer cannot cancel or select the order', async () => {
  const orderId = await create();
  await rejects(call('foreign', 'cancel', {orderId}), 'permission-denied');
  await rejects(call('foreign', 'select', {orderId, offerId: 'courier'}), 'permission-denied');
});
test('an approved courier cannot deliver their own customer order', async () => {
  await db.doc('users/customer').update({roles: ['customer', 'courier'], courierStatus: 'approved', courierOnboardingCompleted: true});
  await db.doc('couriers/customer').set((await db.doc('couriers/courier').get()).data());
  const orderId = await create();
  await rejects(call('customer', 'offer', {orderId, proposedPrice: 20}), 'failed-precondition');
  await rejects(call('customer', 'select', {orderId, offerId: 'customer'}), 'failed-precondition');
});
test('offer price and GPS checks run on server', async () => {
  const orderId = await create();
  await rejects(call('courier', 'offer', {orderId, proposedPrice: 19}), 'invalid-argument');
  await db.doc('couriers/courier').update({locationAccuracy: -1});
  await rejects(call('courier', 'offer', {orderId, proposedPrice: 20}), 'failed-precondition');
  await db.doc('couriers/courier').update({locationAccuracy: 10});
  clock += 15001;
  await rejects(call('courier', 'offer', {orderId, proposedPrice: 20}), 'failed-precondition');
});
test('radius is strict: outside one kilometre cannot submit', async () => {
  const orderId = await create();
  await db.doc('couriers/courier').update({location: new GeoPoint(40.3033, 69.6222)});
  await rejects(call('courier', 'offer', {orderId, proposedPrice: 20}), 'failed-precondition');
  assert.ok(meters(new GeoPoint(40.3033, 69.6222), new GeoPoint(pickup.latitude, pickup.longitude)) > 1000);
});
test('two customer selections cannot assign two couriers', async () => {
  const orderId = await create();
  await call('courier', 'offer', {orderId, proposedPrice: 20});
  await call('courier2', 'offer', {orderId, proposedPrice: 21});
  const selected = await Promise.allSettled([
    call('customer', 'select', {orderId, offerId: 'courier'}),
    call('customer', 'select', {orderId, offerId: 'courier2'}),
  ]);
  assert.equal(selected.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal((await db.collection('couriers').where('isBusy', '==', true).get()).size, 1);
  assert.equal((await db.doc(`orders/${orderId}`).collection('offers').where('status', '==', 'pending').get()).size, 0);
});

test('admin actions reject forged roles and log the authenticated administrator', async () => {
  const orderId = await create();
  await rejects(call('customer', 'adminCancel', {orderId, reason: 'Подмена', adminId: 'admin'}), 'permission-denied');
  await call('admin', 'adminCancel', {orderId, reason: 'Просьба клиента', adminId: 'foreign'});
  assert.equal((await db.doc(`orders/${orderId}`).get()).data().status, 'cancelled');
  const logs = await db.collection('admin_logs').get();
  assert.equal(logs.docs[0].data().adminId, 'admin');
  assert.equal((await db.doc(`_order_secrets/${orderId}`).get()).exists, false);
});

test('return to waiting resets price, offers, code attempts and assignment', async () => {
  const orderId = await pickedUp();
  const oldSecret = (await db.doc(`_order_secrets/${orderId}`).get()).data();
  const oldCode = (await db.doc(`order_receipts/${orderId}`).get()).data().confirmationCode;
  await call('admin', 'adminReturn', {orderId});
  const order = (await db.doc(`orders/${orderId}`).get()).data();
  assert.equal(order.status, 'waitingOffers');
  assert.equal(order.price, 20);
  assert.equal(order.courierId, undefined);
  assert.equal(order.pickedUpAt, undefined);
  assert.equal((await db.doc('couriers/courier').get()).data().activeOrderId, null);
  assert.equal((await db.doc(`orders/${orderId}`).collection('offers').get()).size, 0);
  const secret = (await db.doc(`_order_secrets/${orderId}`).get()).data();
  assert.notEqual(secret.salt, oldSecret.salt);
  assert.notEqual((await db.doc(`order_receipts/${orderId}`).get()).data().confirmationCode, oldCode);
  assert.equal(secret.attempts, 0);
  await call('courier2', 'offer', {orderId, proposedPrice: 21});
  await call('customer', 'select', {orderId, offerId: 'courier2'});
});

test('resolving a completed dispute neither pays twice nor releases a newer order', async () => {
  const orderId = await pickedUp();
  await call('admin', 'adminComplete', {orderId}, 'admin-finish');
  await call('admin', 'adminComplete', {orderId}, 'admin-finish');
  const newOrder = await assigned();
  await call('admin', 'adminDispute', {orderId, reason: 'Проверка доставки'});
  await rejects(call('admin', 'adminReturn', {orderId}), 'failed-precondition');
  await rejects(call('admin', 'adminCancel', {orderId, reason: 'Проверка'}), 'failed-precondition');
  await call('admin', 'adminComplete', {orderId});
  const courier = (await db.doc('couriers/courier').get()).data();
  assert.equal(courier.ordersToday, 1);
  assert.equal(courier.earningsToday, 22);
  assert.equal(courier.activeOrderId, newOrder);
  assert.equal(courier.isBusy, true);
});

test('clearing an active order is refused and cancellation preserves unrelated assignment', async () => {
  const orderId = await assigned();
  await rejects(call('admin', 'adminClear', {orderId}), 'failed-precondition');
  await db.doc('couriers/courier').update({activeOrderId: 'another-order', isBusy: true});
  await call('admin', 'adminCancel', {orderId, reason: 'Проверка'});
  assert.equal((await db.doc('couriers/courier').get()).data().activeOrderId, 'another-order');
});

test('fixed delivery fees support cents without rounding an agreed price', async () => {
  await db.doc('partners/shop').set({name: 'Магазин', address: pickup.address, location: new GeoPoint(pickup.latitude, pickup.longitude), category: 'groceries', isActive: true, isOpen: true, deliveryFee: 15.5, minimumOrder: 0});
  await db.doc('products/apple').set({partnerId: 'shop', name: 'Яблоки', unit: 'kg', price: 0.29, isAvailable: true, hidden: false});
  const orderId = (await call('customer', 'checkout', {partnerId: 'shop', dropoff, items: [{productId: 'apple', quantity: 1, expectedPrice: 0.29}]})).orderId;
  await call('courier', 'offer', {orderId, proposedPrice: 15.5});
  await call('customer', 'select', {orderId, offerId: 'courier'});
  assert.equal((await db.doc(`orders/${orderId}`).get()).data().price, 15.5);
});
test('completion checks code, commits failed attempts, and credits once', async () => {
  const orderId = await pickedUp();
  const code = (await db.doc(`order_receipts/${orderId}`).get()).data().confirmationCode;
  const wrong = code === '0000' ? '0001' : '0000';
  for (let attempt = 0; attempt < 2; attempt++) await rejects(call('courier', 'complete', {orderId, code: wrong}, 'wrong-code'), 'invalid-argument');
  assert.equal((await db.doc(`_order_secrets/${orderId}`).get()).data().attempts, 1);
  await call('courier', 'complete', {orderId, code}, 'finish');
  await call('courier', 'complete', {orderId, code}, 'finish');
  const courier = (await db.doc('couriers/courier').get()).data();
  assert.equal(courier.ordersToday, 1);
  assert.equal(courier.earningsToday, 22);
  assert.equal(courier.activeOrderId, null);
  assert.equal((await db.doc(`_order_secrets/${orderId}`).get()).exists, false);
});
test('five distinct wrong attempts lock the code', async () => {
  const orderId = await pickedUp();
  const code = (await db.doc(`order_receipts/${orderId}`).get()).data().confirmationCode;
  const wrong = code === '0000' ? '0001' : '0000';
  for (let attempt = 0; attempt < 5; attempt++) await rejects(call('courier', 'complete', {orderId, code: wrong}), 'invalid-argument');
  await rejects(call('courier', 'complete', {orderId, code}), 'resource-exhausted');
  assert.equal((await db.doc('couriers/courier').get()).data().ordersToday, 0);
});
test('pickup and delivery record timestamps and customer confirmation settles', async () => {
  const orderId = await pickedUp();
  await call('courier', 'deliver', {orderId});
  await call('customer', 'confirm', {orderId});
  const order = (await db.doc(`orders/${orderId}`).get()).data();
  assert.ok(order.pickedUpAt && order.deliveredAt && order.completedAt);
  await rejects(call('customer', 'confirm', {orderId}), 'failed-precondition');
  assert.equal((await db.doc('couriers/courier').get()).data().ordersToday, 1);
});
test('catalog totals ignore forged client totals and use current product prices', async () => {
  await db.doc('partners/shop').set({name: 'Магазин', address: pickup.address, location: new GeoPoint(pickup.latitude, pickup.longitude), category: 'groceries', isActive: true, isOpen: true, deliveryFee: 15, minimumOrder: 20});
  await db.doc('products/apple').set({partnerId: 'shop', name: 'Яблоки', unit: 'kg', price: 20, isAvailable: true, hidden: false});
  const data = {partnerId: 'shop', dropoff, items: [{productId: 'apple', quantity: 1.5, expectedPrice: 20}], total: 1, deliveryFee: 1};
  const orderId = (await call('customer', 'checkout', data)).orderId;
  const order = (await db.doc(`orders/${orderId}`).get()).data();
  assert.equal(order.subtotal, 30);
  assert.equal(order.total, 45);
  assert.equal(order.price, 15);
  await rejects(call('customer', 'checkout', {...data, items: [{productId: 'apple', quantity: 1.5, expectedPrice: 1}]}), 'failed-precondition');
  await rejects(call('customer', 'checkout', {...data, items: [{productId: 'apple', quantity: 1.2, expectedPrice: 20}]}), 'invalid-argument');
});
test('rules hide code from courier and block direct server-order tampering', async () => {
  const orderId = await pickedUp();
  const customer = rules.authenticatedContext('customer').firestore();
  const courier = rules.authenticatedContext('courier').firestore();
  const foreign = rules.authenticatedContext('foreign').firestore();
  await assertSucceeds(getDoc(doc(customer, `order_receipts/${orderId}`)));
  await assertSucceeds(getDoc(doc(courier, `orders/${orderId}`)));
  for (const client of [courier, foreign, rules.unauthenticatedContext().firestore()]) await assertFails(getDoc(doc(client, `order_receipts/${orderId}`)));
  await assertFails(getDoc(doc(customer, `_order_secrets/${orderId}`)));
  await assertFails(getDoc(doc(customer, '_customer_orders/customer')));
  await assertFails(updateDoc(doc(courier, 'couriers/courier'), {activeOrderId: null, isBusy: false, earningsToday: increment(22), ordersToday: increment(1), updatedAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(courier, `orders/${orderId}`), {status: 'completed', completedAt: serverTimestamp(), updatedAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(customer, `orders/${orderId}`), {price: 1, updatedAt: serverTimestamp()}));
  await assertFails(setDoc(doc(courier, `orders/${orderId}/offers/courier`), {status: 'pending', proposedPrice: 1}));
});

test('catalog rounds half cents from integer price cents', async () => {
  await db.doc('partners/shop').set({name: 'Магазин', address: pickup.address, location: new GeoPoint(pickup.latitude, pickup.longitude), category: 'groceries', isActive: true, isOpen: true, deliveryFee: 0, minimumOrder: 0});
  await db.doc('products/apple').set({partnerId: 'shop', name: 'Яблоки', unit: 'kg', price: 0.29, isAvailable: true, hidden: false});
  const {orderId} = await call('customer', 'checkout', {partnerId: 'shop', dropoff, items: [{productId: 'apple', quantity: 0.5, expectedPrice: 0.29}]});
  const order = (await db.doc(`orders/${orderId}`).get()).data();
  assert.equal(order.subtotal, 0.15);
  assert.equal(order.deliveryFee, 10);
  assert.equal(order.total, 10.15);
});

test('legacy customer selection uses public telemetry while private courier data stays hidden', async () => {
  const customer = rules.authenticatedContext('customer', {phone_number: '+992000000000'}).firestore();
  const orderId = 'legacy-offers';
  await assertSucceeds(setDoc(doc(customer, `orders/${orderId}`), {customerId: 'customer', customerName: 'Клиент', status: 'waitingOffers', type: 'package', city: 'Худжанд', fromText: pickup.address, toText: dropoff.address, fromLocation: new ClientGeoPoint(pickup.latitude, pickup.longitude), toLocation: new ClientGeoPoint(dropoff.latitude, dropoff.longitude), price: 20, clientPrice: 20, pricingVersion: 'v2', currency: 'TJS', declinedBy: [], createdAt: serverTimestamp(), updatedAt: serverTimestamp()}));
  await db.doc('courier_public/courier').set({isOnline: true, location: new GeoPoint(pickup.latitude, pickup.longitude), locationAccuracy: 10, locationUpdatedAt: Timestamp.fromMillis(clock)});
  await db.doc(`orders/${orderId}/offers/courier`).set({courierId: 'courier', proposedPrice: 22, status: 'pending', createdAt: Timestamp.fromMillis(clock), expiresAt: Timestamp.fromMillis(clock + 60000)});
  await assertSucceeds(getDoc(doc(customer, 'courier_public/courier')));
  await assertFails(getDoc(doc(customer, 'couriers/courier')));
  const selection = writeBatch(customer);
  selection.update(doc(customer, `orders/${orderId}/offers/courier`), {status: 'accepted', updatedAt: serverTimestamp()});
  selection.update(doc(customer, `orders/${orderId}`), {status: 'accepted', courierId: 'courier', selectedCourierId: 'courier', selectedOfferId: 'courier', finalPrice: 22, price: 22, acceptedAt: serverTimestamp(), updatedAt: serverTimestamp()});
  selection.update(doc(customer, 'couriers/courier'), {activeOrderId: orderId, isBusy: true, updatedAt: serverTimestamp()});
  await assertSucceeds(selection.commit());
  assert.equal((await db.doc(`orders/${orderId}`).get()).data().status, 'accepted');
});

test('classic waiting orders still pass acceptance, delivery and customer confirmation', async () => {
  const customer = rules.authenticatedContext('customer', {phone_number: '+992000000000'}).firestore();
  const courier = rules.authenticatedContext('courier').firestore();
  const orderId = 'classic-order';
  await assertSucceeds(setDoc(doc(customer, `orders/${orderId}`), {customerId: 'customer', customerName: 'Клиент', status: 'waiting', type: 'package', city: 'Худжанд', fromText: pickup.address, toText: dropoff.address, price: 20, currency: 'TJS', declinedBy: [], confirmationCode: '1234', createdAt: serverTimestamp(), updatedAt: serverTimestamp()}));
  const acceptance = writeBatch(courier);
  acceptance.update(doc(courier, `orders/${orderId}`), {status: 'accepted', courierId: 'courier', acceptedAt: serverTimestamp(), updatedAt: serverTimestamp()});
  // Older builds did not publish an isBusy field during acceptance.
  acceptance.update(doc(courier, 'couriers/courier'), {activeOrderId: orderId, updatedAt: serverTimestamp()});
  await assertSucceeds(acceptance.commit());
  await assertFails(updateDoc(doc(courier, `orders/${orderId}`), {status: 'pickedUp', price: 1, updatedAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(customer, `orders/${orderId}`), {status: 'cancelled', updatedAt: serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(courier, `orders/${orderId}`), {arrivedAtPickupAt: serverTimestamp(), updatedAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(courier, `orders/${orderId}`), {status: 'pickedUp', fromText: 'Подменённый адрес', updatedAt: serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(courier, `orders/${orderId}`), {status: 'pickedUp', updatedAt: serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(courier, `orders/${orderId}`), {status: 'delivered', updatedAt: serverTimestamp()}));
  const finish = writeBatch(customer);
  finish.update(doc(customer, `orders/${orderId}`), {status: 'completed', completedAt: serverTimestamp(), updatedAt: serverTimestamp()});
  finish.update(doc(customer, 'couriers/courier'), {activeOrderId: null, earningsToday: increment(20), ordersToday: increment(1), updatedAt: serverTimestamp()});
  await assertSucceeds(finish.commit());
  assert.equal((await db.doc('couriers/courier').get()).data().earningsToday, 20);
});
test('migration gate blocks new legacy orders without breaking legacy cancellation', async () => {
  const client = rules.authenticatedContext('customer', {phone_number: '+992000000000'}).firestore();
  const data = {customerId: 'customer', customerName: 'Клиент', status: 'waitingOffers', type: 'package', city: 'Худжанд', fromText: 'A', toText: 'B', price: 20, clientPrice: 20, suggestedPrice: 20, priceNegotiable: true, orderType: 'customDelivery', currency: 'TJS', declinedBy: [], createdAt: serverTimestamp(), updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(doc(client, 'orders/legacy'), data));
  await db.doc('_config/order_commands').set({enabled: true});
  await assertFails(setDoc(doc(client, 'orders/legacy-new'), data));
  await assertSucceeds(updateDoc(doc(client, 'orders/legacy'), {status: 'cancelled', updatedAt: serverTimestamp()}));
});

test('legacy catalog supports cent totals but still rejects a forged delivery fee', async () => {
  await db.doc('partners/shop').set({name: 'Магазин', address: pickup.address, location: new GeoPoint(pickup.latitude, pickup.longitude), category: 'groceries', isActive: true, isOpen: true, deliveryFee: 10.12, minimumOrder: 0});
  const client = rules.authenticatedContext('customer', {phone_number: '+992000000000'}).firestore();
  const data = {customerId: 'customer', customerName: 'Клиент', status: 'waitingOffers', type: 'groceries', city: 'Худжанд', fromText: pickup.address, toText: dropoff.address, fromLocation: new ClientGeoPoint(pickup.latitude, pickup.longitude), toLocation: new ClientGeoPoint(dropoff.latitude, dropoff.longitude), price: 10.12, currency: 'TJS', declinedBy: [], orderType: 'catalogOrder', priceNegotiable: false, partnerId: 'shop', partnerName: 'Магазин', items: [{productId: 'apple', quantity: 1}], subtotal: 0.09, deliveryFee: 10.12, total: 10.21, createdAt: serverTimestamp(), updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(doc(client, 'orders/legacy-cents'), data));
  await assertFails(setDoc(doc(client, 'orders/legacy-forged-fee'), {...data, price: 10, deliveryFee: 10, total: 10.09}));
});

test('legacy migration cannot let suspended or rejected couriers approve themselves', async () => {
  const courier = rules.authenticatedContext('courier').firestore();
  for (const status of ['suspended', 'rejected', 'pending', 'draft']) {
    await db.doc('users/courier').set({uid: 'courier', role: 'courier', roles: ['customer', 'courier'], courierStatus: status, courierOnboardingCompleted: false, phoneVerified: false, createdAt: Timestamp.fromMillis(clock), updatedAt: Timestamp.fromMillis(clock)});
    await assertFails(updateDoc(doc(courier, 'users/courier'), {courierStatus: 'approved', courierOnboardingCompleted: true, updatedAt: serverTimestamp()}));
  }
  // A real legacy account without a courierStatus can still migrate.
  await db.doc('users/courier').set({uid: 'courier', role: 'courier', phoneVerified: false, createdAt: Timestamp.fromMillis(clock), updatedAt: Timestamp.fromMillis(clock)});
  await assertSucceeds(updateDoc(doc(courier, 'users/courier'), {roles: ['customer', 'courier'], courierStatus: 'approved', courierOnboardingCompleted: true, updatedAt: serverTimestamp()}));
});

test('active order and history queries respect customer and courier ownership', async () => {
  await pickedUp();
  const customer = rules.authenticatedContext('customer').firestore();
  const courier = rules.authenticatedContext('courier').firestore();
  const foreign = rules.authenticatedContext('foreign').firestore();
  await assertSucceeds(getDocs(query(collection(customer, 'orders'), where('customerId', '==', 'customer'), where('status', 'in', ['waiting', 'waitingOffers', 'accepted', 'pickedUp', 'delivered', 'disputed']))));
  await assertSucceeds(getDocs(query(collection(courier, 'orders'), where('courierId', '==', 'courier'), where('status', 'in', ['accepted', 'pickedUp', 'delivered', 'disputed']))));
  await assertSucceeds(getDocs(query(collection(courier, 'orders'), where('courierId', '==', 'courier'), orderBy('createdAt', 'desc'))));
  await assertFails(getDocs(query(collection(foreign, 'orders'), where('customerId', '==', 'customer'), orderBy('createdAt', 'desc'))));
});

test('callable endpoint verifies Firebase auth and replays a lost response safely', {skip: !process.env.TAJGO_FUNCTIONS_EMULATOR_URL}, async () => {
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST, 'Auth Emulator required');
  const auth = getAuth(app);
  try {await auth.deleteUser('customer');} catch (error) {if (error.code !== 'auth/user-not-found') throw error;}
  await auth.createUser({uid: 'customer', email: 'customer@example.test', phoneNumber: '+992900000001', password: 'test-password-only'});
  const login = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-test-key`, {
    method: 'POST', headers: {'content-type': 'application/json'}, body: JSON.stringify({email: 'customer@example.test', password: 'test-password-only', returnSecureToken: true}),
  });
  assert.equal(login.status, 200);
  const {idToken} = await login.json();
  async function invoke(token) {
    const response = await fetch(process.env.TAJGO_FUNCTIONS_EMULATOR_URL, {method: 'POST', headers: {'content-type': 'application/json', ...(token ? {authorization: `Bearer ${token}`} : {})}, body: JSON.stringify({data: {action: 'create', requestId: 'real-callable-create', pickup, dropoff, price: 20}})});
    return {status: response.status, body: await response.json()};
  }
  assert.equal((await invoke()).status, 401);
  assert.equal((await invoke('not-a-real-token')).status, 401);
  const first = await invoke(idToken);
  assert.equal(first.status, 200, JSON.stringify(first.body));
  const retry = await invoke(idToken);
  assert.deepEqual(first.body, retry.body);
  assert.equal((await db.collection('orders').get()).size, 1);
  assert.equal((await db.doc(`orders/${first.body.result.orderId}`).get()).data().customerId, 'customer');
});
