'use strict';
const {onCall} = require('firebase-functions/v2/https');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {onInit} = require('firebase-functions/v2/core');
let devices, delivery;
onInit(() => {
  const {initializeApp} = require('firebase-admin/app');
  const {getFirestore} = require('firebase-admin/firestore');
  const {getMessaging} = require('firebase-admin/messaging');
  const {createDeviceRegistration, createNotificationDelivery} = require('./notifications');
  initializeApp();
  const db = getFirestore();
  devices = createDeviceRegistration(db);
  delivery = createNotificationDelivery(db, getMessaging());
});
exports.notificationDevice = onCall({region: 'europe-west1', maxInstances: 5}, request => devices(request));
// The emulator has no FCM transport; delivery is tested with an injected sender.
const dispatch = (method, event) => process.env.FUNCTIONS_EMULATOR === 'true' ? Promise.resolve() : delivery[method](event);
exports.notifyOrderChanged = onDocumentWritten({document: 'orders/{orderId}', region: 'europe-west1', maxInstances: 5, retry: true}, event => dispatch('orderChanged', event));
exports.notifyOfferChanged = onDocumentWritten({document: 'orders/{orderId}/offers/{offerId}', region: 'europe-west1', maxInstances: 5, retry: true}, event => dispatch('offerChanged', event));
