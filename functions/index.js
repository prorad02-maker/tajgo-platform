'use strict';
const {onCall} = require('firebase-functions/v2/https');
const {onInit} = require('firebase-functions/v2/core');
let commands;
// Firebase discovers exported functions before starting their runtime. Keep
// Firestore initialization out of discovery so it cannot exceed that timeout.
onInit(() => {
  const {initializeApp} = require('firebase-admin/app');
  const {getFirestore} = require('firebase-admin/firestore');
  const {createOrderCommands} = require('./order_commands');
  initializeApp();
  commands = createOrderCommands(getFirestore());
});
exports.orderCommand = onCall({region: 'europe-west1', maxInstances: 10}, request => commands(request));
