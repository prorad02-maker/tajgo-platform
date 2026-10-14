'use strict';
const {test, before, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const {readFileSync} = require('node:fs');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, getDocs, collection} = require('firebase/firestore');
const {createDeviceRegistration, createNotificationDelivery, orderNotices} = require('../notifications');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Notification tests require Firestore Emulator; refusing live access.');
const projectId = 'demo-tajgo-notifications';
const app = initializeApp({projectId}, 'notification-tests');
const db = getFirestore(app);
const hash = value => createHash('sha256').update(value).digest('hex');
const token = n => `test-android-registration-token-${n}`;
const tokenRef = n => db.doc(`_notification_tokens/${hash(token(n))}`);
let rules, register, delivery, clock, sends, sender;
const snapshot = data => ({exists: !!data, data: () => data});
const event = (before, after, id = 'event-1') => ({id, time: new Date(clock).toISOString(), params: {orderId: 'order', offerId: 'courier'}, data: {before: snapshot(before), after: snapshot(after)}});
function device(uid, n, enabled = true, registrationId = 'registration-1', overrides = {}) {
  return register({auth: uid ? {uid, token: {phone_number: '+992900000001'}} : null,
    data: {accountId: uid, token: token(n), platform: 'android', enabled, registrationId, ...overrides}});
}
before(async () => {
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  rules = await initializeTestEnvironment({projectId, firestore: {host, port: Number(port), rules: readFileSync('../firestore.rules', 'utf8')}});
});
beforeEach(async () => {
  await rules.clearFirestore(); clock = Date.now(); sends = [];
  await Promise.all(['customer', 'other', 'courier'].map(uid => db.doc(`users/${uid}`).set({role: 'customer'})));
  register = createDeviceRegistration(db);
  sender = async message => ({responses: message.tokens.map(() => ({success: true}))});
  delivery = createNotificationDelivery(db, {sendEachForMulticast: async message => {sends.push(message); return sender(message);}}, {now: () => clock});
});
after(async () => {await rules.cleanup(); await db.terminate(); await deleteApp(app);});

test('registration requires authentication, current account and a phone-backed profile', async () => {
  await assert.rejects(device(null, 1), error => error.code === 'unauthenticated');
  await assert.rejects(device('customer', 1, true, 'r', {accountId: 'other'}), error => error.code === 'permission-denied');
  await assert.rejects(register({auth: {uid: 'customer', token: {}}, data: {accountId: 'customer', token: token(1), platform: 'android', enabled: true, registrationId: 'r'}}), error => error.code === 'permission-denied');
  await assert.rejects(device('missing', 1), error => error.code === 'permission-denied');
  assert.equal((await db.collection('_notification_tokens').get()).size, 0);
});
test('invalid device payloads do not create token documents', async () => {
  for (const overrides of [{token: 'short'}, {token: 'token with spaces xxxxxxxxxx'}, {enabled: 'yes'}, {platform: 'web'}, {registrationId: '../other'}]) {
    await assert.rejects(device('customer', 1, true, 'r', overrides), error => error.code === 'invalid-argument');
  }
});
test('one token belongs to the latest signed-in account; stale logout cannot remove it', async () => {
  await device('customer', 1, true, 'old');
  await device('other', 1, true, 'new');
  await device('customer', 1, false, 'old');
  assert.equal((await tokenRef(1).get()).data().uid, 'other');
});
test('late logout cannot remove a new registration of the same account', async () => {
  await device('customer', 1, true, 'old');
  await device('customer', 1, true, 'new');
  await device('customer', 1, false, 'old');
  assert.equal((await tokenRef(1).get()).data().registrationId, 'new');
  await device('customer', 1, false, 'new');
  assert.equal((await tokenRef(1).get()).exists, false);
});
test('registration caps devices at eight even during concurrent registration', async () => {
  for (let n = 1; n <= 8; n++) await device('customer', n);
  await Promise.all([device('customer', 9), device('customer', 10)]);
  assert.equal((await db.collection('_notification_tokens').where('uid', '==', 'customer').get()).size, 8);
  assert.ok((await tokenRef(9).get()).exists && (await tokenRef(10).get()).exists);
});
test('tokens, event journal and registration locks are private even to their owner', async () => {
  await device('customer', 1);
  const client = rules.authenticatedContext('customer').firestore();
  for (const name of ['_notification_tokens', '_notification_events', '_notification_accounts']) {
    await assertFails(getDocs(collection(client, name)));
    await assertFails(getDoc(doc(client, name, 'any')));
    await assertFails(setDoc(doc(client, name, 'any'), {uid: 'customer'}));
  }
});
test('pure notices ignore initial/unknown/metadata changes and handle reassignment', () => {
  const order = {customerId: 'customer', courierId: 'courier', status: 'accepted'};
  assert.deepEqual(orderNotices(null, order), []);
  assert.deepEqual(orderNotices(order, {...order, adminNote: 'note'}), []);
  assert.deepEqual(orderNotices(order, {...order, status: 'unknown'}), []);
  assert.deepEqual(orderNotices(order, {customerId: 'customer', status: 'waitingOffers'}), [{uid: 'customer', kind: 'reassigned'}, {uid: 'courier', kind: 'removed'}]);
  assert.deepEqual(orderNotices(order, {...order, arrivedAtPickupAt: Timestamp.now()}), [{uid: 'customer', kind: 'arrived'}]);
});
async function assignedEvent() {
  await device('customer', 1); await device('courier', 2);
  const before = {customerId: 'customer', status: 'waitingOffers'};
  const after = {customerId: 'customer', courierId: 'courier', status: 'accepted', fromText: 'PRIVATE ADDRESS', phoneNumber: 'PRIVATE PHONE', confirmationCode: 'PRIVATE CODE'};
  await db.doc('orders/order').set(after);
  return event(before, after);
}
test('assignment targets only participants, without address, phone or confirmation code', async () => {
  await delivery.orderChanged(await assignedEvent());
  assert.equal(sends.length, 2);
  assert.deepEqual(new Set(sends.map(message => message.data.recipientId)), new Set(['customer', 'courier']));
  for (const message of sends) {
    assert.equal(message.android.notification.channelId, 'tajgo_orders');
    assert.equal(message.data.orderId, 'order');
    assert.ok(!JSON.stringify(message).includes('PRIVATE'));
  }
});
test('replaying a completed event never sends its notification again', async () => {
  const change = await assignedEvent();
  await delivery.orderChanged(change); await delivery.orderChanged(change);
  assert.equal(sends.length, 2);
  const jobs = await db.collection('_notification_events').get();
  assert.ok(jobs.docs.every(doc => doc.data().state === 'sent' && doc.data().expiresAt instanceof Timestamp));
});
test('stale and out-of-order events are discarded', async () => {
  const change = await assignedEvent();
  clock += 16 * 60000; await delivery.orderChanged(change);
  assert.equal(sends.length, 0);
  clock -= 16 * 60000;
  await db.doc('orders/order').update({status: 'completed'});
  await delivery.orderChanged(change);
  assert.equal(sends.length, 0);
});
test('invalid FCM tokens are removed and do not block other devices', async () => {
  const change = await assignedEvent();
  sender = async message => ({responses: message.tokens.map(value => value === token(1) ? {success: false, error: {code: 'messaging/registration-token-not-registered'}} : {success: true})});
  await delivery.orderChanged(change);
  assert.equal((await tokenRef(1).get()).exists, false);
  assert.equal((await tokenRef(2).get()).exists, true);
});
test('an invalid-token response cannot delete a newer token owner', async () => {
  const change = await assignedEvent();
  sender = async message => {
    if (message.data.recipientId === 'customer') {
      await device('other', 1, true, 'new-owner');
      return {responses: [{success: false, error: {code: 'messaging/registration-token-not-registered'}}]};
    }
    return {responses: [{success: true}]};
  };
  await delivery.orderChanged(change);
  assert.equal((await tokenRef(1).get()).data().uid, 'other');
});
test('retry sends only failed devices, preserving successful deliveries', async () => {
  await device('customer', 1); await device('customer', 2);
  const before = {customerId: 'customer', status: 'pickedUp'};
  const after = {customerId: 'customer', status: 'delivered'};
  await db.doc('orders/order').set(after);
  sender = async message => ({responses: message.tokens.map(value => value === token(2) ? {success: false, error: {code: 'messaging/server-unavailable'}} : {success: true})});
  const change = event(before, after);
  await assert.rejects(delivery.orderChanged(change), /retry/);
  sender = async message => ({responses: message.tokens.map(() => ({success: true}))});
  await delivery.orderChanged(change);
  assert.deepEqual(sends[1].tokens, [token(2)]);
});
test('all-transient failures and transport exceptions leave the event retryable', async () => {
  const change = await assignedEvent();
  sender = async () => {throw new Error('network');};
  await assert.rejects(delivery.orderChanged(change), /retry/);
  sender = async message => ({responses: message.tokens.map(() => ({success: false, error: {code: 'messaging/server-unavailable'}}))});
  await assert.rejects(delivery.orderChanged(change), /retry/);
  sender = async message => ({responses: message.tokens.map(() => ({success: true}))});
  await delivery.orderChanged(change);
  assert.ok((await db.collection('_notification_events').get()).docs.every(doc => doc.data().state === 'sent'));
});
test('an active lease requests retry; an expired lease can recover after a crash', async () => {
  const change = await assignedEvent();
  const jobId = hash('event-1:customer:assigned');
  await db.doc(`_notification_events/${jobId}`).set({state: 'sending', leaseUntil: Timestamp.fromMillis(clock + 120000), delivered: []});
  await assert.rejects(delivery.orderChanged(change), /retry/);
  assert.equal(sends.length, 1); // Courier delivery is independent of the lease.
  clock += 120001;
  await delivery.orderChanged(change);
  assert.equal(sends.length, 2);
});
test('new pending offer notifies the customer; expiration or an accepted order does not', async () => {
  await device('customer', 1);
  await db.doc('orders/order').set({customerId: 'customer', status: 'waitingOffers'});
  const offer = {status: 'pending', proposedPrice: 22, expiresAt: Timestamp.fromMillis(clock + 300000)};
  await db.doc('orders/order/offers/courier').set(offer);
  await delivery.offerChanged(event(null, offer));
  assert.equal(sends.length, 1);
  assert.equal(sends[0].data.kind, 'offer');
  await delivery.offerChanged(event(offer, offer, 'same-price'));
  await db.doc('orders/order').update({status: 'accepted'});
  await delivery.offerChanged(event(null, offer, 'already-accepted'));
  assert.equal(sends.length, 1);
});
