'use strict';
const {test, before, beforeEach, after} = require('node:test');
const {readFileSync} = require('node:fs');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, serverTimestamp} = require('firebase/firestore');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator is required');
let rules;
before(async () => {
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  rules = await initializeTestEnvironment({projectId: 'demo-tajgo-transition', firestore: {
    host, port: Number(port), rules: readFileSync('../firestore.compat.rules', 'utf8'),
  }});
});
beforeEach(async () => {
  await rules.clearFirestore();
  await rules.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await Promise.all([
      setDoc(doc(db, 'users/customer'), {uid: 'customer', role: 'customer', roles: ['customer'], courierStatus: 'none'}),
      setDoc(doc(db, 'users/courier'), {uid: 'courier', role: 'courier', roles: ['customer', 'courier'], courierStatus: 'approved', courierOnboardingCompleted: true}),
      setDoc(doc(db, 'users/admin'), {uid: 'admin', role: 'admin'}),
      setDoc(doc(db, 'couriers/courier'), {uid: 'courier', isBusy: false, activeOrderId: null}),
      setDoc(doc(db, 'orders/current'), {customerId: 'customer', courierId: 'courier', status: 'accepted', schemaVersion: 8, price: 20}),
      setDoc(doc(db, 'orders/previous'), {customerId: 'customer', courierId: 'courier', status: 'accepted', commandVersion: 'server-v1', price: 20}),
      setDoc(doc(db, 'orders/legacy'), {customerId: 'customer', courierId: 'courier', status: 'accepted', price: 20}),
      setDoc(doc(db, 'order_customer_codes/current'), {customerId: 'customer', code: '0001'}),
      setDoc(doc(db, 'order_receipts/previous'), {customerId: 'customer', confirmationCode: '0002'}),
    ]);
  });
});
after(async () => rules?.cleanup());
function db(uid) {return rules.authenticatedContext(uid, {phone_number: '+992900000001'}).firestore();}
test('both managed schemas reject mobile price, status and admin-note changes', async () => {
  for (const uid of ['customer', 'courier', 'admin']) {
    for (const id of ['current', 'previous']) {
      await assertFails(updateDoc(doc(db(uid), 'orders', id), {price: 1, updatedAt: serverTimestamp()}));
      await assertFails(updateDoc(doc(db(uid), 'orders', id), {status: 'completed', updatedAt: serverTimestamp()}));
    }
    await assertFails(updateDoc(doc(db(uid), 'orders/current'), {adminNote: 'bypass', updatedAt: serverTimestamp()}));
  }
});
test('managed orders cannot be reclassified to restore client permissions', async () => {
  await assertFails(updateDoc(doc(db('customer'), 'orders/current'), {schemaVersion: 0}));
  await assertFails(updateDoc(doc(db('admin'), 'orders/previous'), {commandVersion: 'legacy'}));
  await assertFails(setDoc(doc(db('customer'), 'orders/forged'), {customerId: 'customer', status: 'waitingOffers', schemaVersion: 8, price: 20, currency: 'TJS'}));
});
test('old and current customer receipts stay private and readable by their owner', async () => {
  for (const path of ['order_customer_codes/current', 'order_receipts/previous']) {
    await assertSucceeds(getDoc(doc(db('customer'), path)));
    await assertFails(getDoc(doc(db('courier'), path)));
    await assertFails(setDoc(doc(db('customer'), path), {code: '9999'}));
  }
});
test('existing customers and assigned couriers retain access to all order formats', async () => {
  for (const uid of ['customer', 'courier']) for (const id of ['current', 'previous', 'legacy']) {
    await assertSucceeds(getDoc(doc(db(uid), 'orders', id)));
  }
  await assertFails(getDoc(doc(db('other'), 'orders/current')));
});
test('quotes, journals, secrets and device associations are server-only', async () => {
  for (const uid of ['customer', 'admin']) for (const collection of ['delivery_quotes', 'order_secrets', '_order_secrets', 'command_results', '_order_commands', '_notification_tokens', '_notification_events', '_notification_accounts', '_road_route_cache', '_routing_limits']) {
    await assertFails(getDoc(doc(db(uid), collection, 'private')));
    await assertFails(setDoc(doc(db(uid), collection, 'private'), {ownerId: uid}));
  }
});
test('saved addresses allow only their owner', async () => {
  await assertSucceeds(setDoc(doc(db('customer'), 'users/customer/addresses/home'), {address: 'Сомони 54', latitude: 40.28, longitude: 69.62}));
  await assertFails(getDoc(doc(db('courier'), 'users/customer/addresses/home')));
});
test('courier offers for both managed schemas must go through server commands', async () => {
  for (const id of ['current', 'previous']) await assertFails(setDoc(doc(db('courier'), 'orders', id, 'offers', 'courier'), {courierId: 'courier', status: 'pending', proposedPrice: 20}));
});
