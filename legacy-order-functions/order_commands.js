'use strict';
const {createHash, randomInt, randomBytes, timingSafeEqual} = require('node:crypto');
const {FieldValue, GeoPoint, Timestamp} = require('firebase-admin/firestore');
const {HttpsError} = require('firebase-functions/v2/https');

const fail = (code, message) => {throw new HttpsError(code, message);};
const stamp = () => FieldValue.serverTimestamp();
const waiting = order => ['waiting', 'waitingOffers'].includes(order.status) && !order.courierId && !order.selectedCourierId;
const text = (value, name, max = 300) => {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) fail('invalid-argument', `Проверьте поле «${name}».`);
  return value.trim();
};
const id = value => {
  const result = text(value, 'идентификатор', 128);
  if (!/^[a-zA-Z0-9_-]+$/.test(result)) fail('invalid-argument', 'Некорректный идентификатор.');
  return result;
};
const money = value => {
  if (!Number.isSafeInteger(value) || value < 10 || value > 100000) fail('invalid-argument', 'Укажите целую цену от 10 до 100000 TJS.');
  return value;
};
const amount = value => {
  if (!Number.isFinite(value) || value < 10 || value > 100000 || Math.abs(Math.round(value * 100) - value * 100) > 0.000001) fail('invalid-argument', 'Некорректная стоимость доставки.');
  return value;
};
function address(value) {
  if (!value || !Number.isFinite(value.latitude) || !Number.isFinite(value.longitude) ||
      Math.abs(value.latitude) > 90 || Math.abs(value.longitude) > 180) fail('invalid-argument', 'Выберите корректную точку на карте.');
  return {label: text(value.address, 'адрес'), point: new GeoPoint(value.latitude, value.longitude)};
}
function meters(a, b) {
  const rad = n => n * Math.PI / 180;
  const sin = Math.sin;
  const h = sin(rad(b.latitude - a.latitude) / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * sin(rad(b.longitude - a.longitude) / 2) ** 2;
  return 6371000 * 2 * Math.asin(Math.sqrt(Math.min(1, h)));
}
function courierReady(profile, courier) {
  if (!profile || profile.courierStatus !== 'approved' || profile.courierOnboardingCompleted !== true || !profile.roles?.includes('courier') || !courier) {
    fail('permission-denied', 'Курьерский аккаунт не подтверждён.');
  }
}
function locationNear(courier, target, radius, now, available = false) {
  if (available && (courier.activeOrderId || courier.isBusy === true)) fail('failed-precondition', 'Сначала завершите текущий заказ.');
  const age = now - (courier.locationUpdatedAt?.toMillis?.() ?? 0);
  if (!(courier.location instanceof GeoPoint) || age < 0 || age > 15000) fail('failed-precondition', 'Обновите ваше местоположение.');
  if (!Number.isFinite(courier.locationAccuracy) || courier.locationAccuracy < 0 || courier.locationAccuracy > 50) fail('failed-precondition', 'Нужна более точная геолокация.');
  const distance = meters(courier.location, target);
  if (distance >= radius) fail('failed-precondition', 'Вы слишком далеко от точки заказа.');
  return distance;
}
function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, stable(value[k])]));
  return value;
}
const hash = value => createHash('sha256').update(value).digest('hex');

function createOrderCommands(db, {now = () => Date.now()} = {}) {
  return async request => {
    const uid = request.auth?.uid;
    if (!uid) fail('unauthenticated', 'Войдите в аккаунт.');
    const data = request.data;
    if (!data || typeof data !== 'object' || Array.isArray(data)) fail('invalid-argument', 'Некорректный запрос.');
    const action = text(data.action, 'действие', 40);
    const requestId = id(data.requestId);
    const actions = ['create', 'checkout', 'offer', 'withdraw', 'reject', 'select', 'accept', 'arrive', 'pickup', 'deliver', 'complete', 'confirm', 'cancel', 'dispute', 'adminCancel', 'adminReturn', 'adminComplete', 'adminDispute', 'adminClear'];
    if (!actions.includes(action)) fail('invalid-argument', 'Неизвестное действие.');
    const fingerprint = hash(JSON.stringify(stable(data)));
    const commandRef = db.collection('_order_commands').doc(hash(`${uid}:${requestId}`));
    const isCreate = action === 'create' || action === 'checkout';
    // Deterministic identity makes retries safe even after process/connection loss.
    const orderId = isCreate ? hash(`${uid}:${requestId}`).slice(0, 32) : id(data.orderId);
    const orderRef = db.collection('orders').doc(orderId);
    const outcome = await db.runTransaction(async tx => {
      const previous = (await tx.get(commandRef)).data();
      if (previous) {
        if (previous.fingerprint !== fingerprint) fail('already-exists', 'Этот запрос уже использован. Обновите данные.');
        return previous.result;
      }
      const [userDoc, orderDoc] = await Promise.all([tx.get(db.collection('users').doc(uid)), tx.get(orderRef)]);
      const user = userDoc.data();
      const order = orderDoc.data();
      const result = {orderId};
      const customerLockRef = db.collection('_customer_orders').doc(isCreate ? uid : order?.customerId ?? uid);
      const customerLock = (await tx.get(customerLockRef)).data();
      const releaseCustomer = () => {
        if (customerLock?.orderId === orderId) tx.set(customerLockRef, {orderId: null, updatedAt: stamp()});
      };
      if (isCreate) {
        if (!request.auth.token?.phone_number) fail('permission-denied', 'Подтвердите номер телефона.');
        if (!user) fail('failed-precondition', 'Заполните профиль.');
        if (order) fail('already-exists', 'Заказ уже существует.');
        const destination = address(data.dropoff);
        let origin, price, extra = {};
        if (action === 'checkout') {
          const partnerId = id(data.partnerId);
          const partner = (await tx.get(db.collection('partners').doc(partnerId))).data();
          if (!partner?.isActive || !partner.isOpen || !(partner.location instanceof GeoPoint)) fail('failed-precondition', 'Партнёр сейчас недоступен.');
          if (!Array.isArray(data.items) || data.items.length < 1 || data.items.length > 50) fail('invalid-argument', 'Проверьте корзину.');
          const keys = data.items.map(item => id(item.productId));
          if (new Set(keys).size !== keys.length) fail('invalid-argument', 'Объедините одинаковые товары в корзине.');
          const products = await Promise.all(keys.map(key => tx.get(db.collection('products').doc(key))));
          let subtotal = 0;
          const items = products.map((doc, index) => {
            const product = doc.data();
            const quantity = data.items[index].quantity;
            if (!product || product.partnerId !== partnerId || product.hidden || product.isAvailable === false) fail('failed-precondition', 'Некоторые товары закончились. Обновите корзину.');
            if (!Number.isFinite(quantity) || quantity <= 0 || quantity > 100 || (product.unit === 'kg' ? !Number.isInteger(quantity * 2) : !Number.isInteger(quantity))) fail('invalid-argument', 'Проверьте количество товара.');
            if (!Number.isFinite(product.price) || product.price < 0 || product.price > 100000 || Math.abs(Math.round(product.price * 100) - product.price * 100) > 0.000001) fail('failed-precondition', 'Цена товара некорректна.');
            if (data.items[index].expectedPrice !== product.price) fail('failed-precondition', 'Цена товара изменилась. Обновите корзину.');
            const lineTotal = Math.round(Math.round(product.price * 100) * quantity) / 100;
            subtotal = Math.round((subtotal + lineTotal) * 100) / 100;
            return {productId: doc.id, name: product.name, unit: product.unit, unitPrice: product.price, quantity, lineTotal};
          });
          if (!Number.isFinite(partner.minimumOrder) || subtotal < partner.minimumOrder) fail('failed-precondition', 'Сумма корзины ниже минимального заказа.');
          if (!Number.isFinite(partner.deliveryFee) || partner.deliveryFee < 0 || partner.deliveryFee > 10000) fail('failed-precondition', 'Стоимость доставки недоступна.');
          price = amount(Math.max(10, partner.deliveryFee));
          origin = {label: text(partner.address, 'адрес партнёра'), point: partner.location};
          extra = {orderType: 'catalogOrder', type: partner.category, partnerId, partnerName: partner.name, items, subtotal, deliveryFee: price, total: Math.round((subtotal + price) * 100) / 100, priceNegotiable: false};
        } else {
          origin = address(data.pickup);
          price = money(data.price);
          extra = {orderType: 'customDelivery', type: 'package', priceNegotiable: true};
        }
        const distance = meters(origin.point, destination.point);
        if (distance < 1) fail('invalid-argument', 'Выберите разные точки забора и доставки.');
        // A per-customer document serializes concurrent creates. Querying also
        // catches active orders from the client-only version during migration.
        const activeOrders = await tx.get(db.collection('orders').where('customerId', '==', uid).where('status', 'in', ['waiting', 'waitingOffers', 'accepted', 'pickedUp', 'delivered', 'disputed']));
        if (activeOrders.docs.some(doc => !doc.data().completedAt)) fail('failed-precondition', 'Сначала завершите текущий заказ.');
        const code = String(randomInt(0, 10000)).padStart(4, '0');
        const salt = randomBytes(32).toString('hex');
        tx.create(orderRef, {
          customerId: uid, customerName: text(user.displayName ?? user.name, 'имя', 100),
          status: 'waitingOffers', city: 'Худжанд', currency: 'TJS',
          fromText: origin.label, fromLocation: origin.point, toText: destination.label, toLocation: destination.point,
          price, clientPrice: price, suggestedPrice: action === 'checkout' ? price : Math.max(10, Math.round(7 + 3 * distance / 1000)),
          distanceKm: distance / 1000, etaMinutes: Math.ceil(distance / 1000 / 18 * 60) + 5,
          routeQuality: 'estimate', pricingVersion: 'server-v1', commandVersion: 'server-v1',
          offersCount: 0, declinedBy: [], comment: data.comment == null || data.comment === '' ? '' : text(data.comment, 'комментарий', 1000),
          createdAt: stamp(), updatedAt: stamp(), ...extra,
        });
        tx.create(db.collection('_order_secrets').doc(orderId), {salt, codeHash: hash(`${salt}:${code}`), attempts: 0, expiresAt: Timestamp.fromMillis(now() + 24 * 60 * 60 * 1000)});
        tx.create(db.collection('order_receipts').doc(orderId), {customerId: uid, confirmationCode: code, createdAt: stamp()});
        tx.set(customerLockRef, {orderId, updatedAt: stamp()});
      } else {
        if (!order) fail('not-found', 'Заказ больше недоступен.');
        if (order.commandVersion !== 'server-v1') fail('failed-precondition', 'Для старого заказа используйте прежний процесс.');
        const owner = order.customerId === uid;
        const assigned = order.courierId === uid;
        const courierAction = ['offer', 'withdraw', 'accept', 'arrive', 'pickup', 'deliver', 'complete'].includes(action);
        const selecting = action === 'select';
        const adminAction = action.startsWith('admin');
        if (adminAction ? user?.role !== 'admin' : !courierAction && !owner) fail('permission-denied', 'Нет доступа к этому заказу.');
        if ((courierAction && owner) || (selecting && data.offerId === order.customerId)) fail('failed-precondition', 'Нельзя выполнять собственный заказ.');
        let courier, courierRef;
        if (courierAction || selecting || action === 'confirm' || (adminAction && order.courierId)) {
          const courierId = selecting ? id(data.offerId) : action === 'confirm' || adminAction ? id(order.courierId) : uid;
          courierRef = db.collection('couriers').doc(courierId);
          courier = (await tx.get(courierRef)).data();
          const courierProfile = courierId === uid ? user : (await tx.get(db.collection('users').doc(courierId))).data();
          if (action !== 'confirm' && !adminAction) courierReady(courierProfile, courier);
          if (!courier) fail('failed-precondition', 'Профиль курьера недоступен.');
        }
        const updated = {updatedAt: stamp()};
        if (adminAction) {
          const settled = !!order.completedAt;
          const active = ['waiting', 'waitingOffers', 'accepted', 'pickedUp', 'delivered', 'disputed'].includes(order.status);
          const release = () => {
            if (courier?.activeOrderId === orderId) tx.update(courierRef, {activeOrderId: null, isBusy: false, ...updated});
          };
          let details = '';
          // Read every document before making writes to keep the transaction atomic.
          const offers = action === 'adminReturn' ? await tx.get(orderRef.collection('offers')) : null;
          const oldReceipt = action === 'adminReturn' ? (await tx.get(db.collection('order_receipts').doc(orderId))).data() : null;
          if (action === 'adminCancel') {
            if (!active || settled) fail('failed-precondition', 'Этот заказ уже нельзя отменить.');
            details = text(data.reason, 'причина', 1000);
            tx.update(orderRef, {status: 'cancelled', cancelledAt: stamp(), cancelledReason: details, ...updated});
            release();
            tx.delete(db.collection('_order_secrets').doc(orderId));
            releaseCustomer();
          } else if (action === 'adminReturn') {
            if (!['accepted', 'pickedUp', 'delivered', 'disputed'].includes(order.status) || settled) fail('failed-precondition', 'Вернуть этот заказ на поиск курьера нельзя.');
            tx.update(orderRef, {
              status: 'waitingOffers', price: order.clientPrice, offersCount: 0, declinedBy: [],
              ...Object.fromEntries(['courierId', 'selectedCourierId', 'selectedOfferId', 'finalPrice', 'acceptedAt', 'arrivedAtPickupAt', 'pickedUpAt', 'deliveredAt', 'disputedAt', 'offerExpiresAt'].map(key => [key, FieldValue.delete()])), ...updated,
            });
            for (const offer of offers.docs) tx.delete(offer.ref);
            release();
            // Rotate the code: a previous courier must not retain a usable code.
            let code;
            do {code = String(randomInt(0, 10000)).padStart(4, '0');} while (code === oldReceipt?.confirmationCode);
            const salt = randomBytes(32).toString('hex');
            tx.set(db.collection('_order_secrets').doc(orderId), {salt, codeHash: hash(`${salt}:${code}`), attempts: 0, expiresAt: Timestamp.fromMillis(now() + 24 * 60 * 60 * 1000)});
            tx.set(db.collection('order_receipts').doc(orderId), {customerId: order.customerId, confirmationCode: code, createdAt: stamp()});
          } else if (action === 'adminComplete') {
            if (!['pickedUp', 'delivered', 'disputed'].includes(order.status) || !courier) fail('failed-precondition', 'Завершить этот заказ вручную нельзя.');
            if (settled) {
              // Resolving a dispute opened after completion cannot pay twice or
              // clear a courier's newer active order.
              tx.update(orderRef, {status: 'completed', resolvedBy: uid, resolvedAt: stamp(), ...updated});
            } else {
              if (courier.activeOrderId !== orderId) fail('failed-precondition', 'Назначение курьера изменилось. Проверьте заказ.');
              complete(tx, orderRef, courierRef, order, courier, updated);
              tx.update(orderRef, {manuallyCompletedBy: uid, ...(order.status === 'disputed' ? {resolvedBy: uid, resolvedAt: stamp()} : {})});
            }
            tx.delete(db.collection('_order_secrets').doc(orderId));
            releaseCustomer();
          } else if (action === 'adminDispute') {
            if (!['accepted', 'pickedUp', 'delivered', 'completed'].includes(order.status)) fail('failed-precondition', 'Пометить этот заказ спорным нельзя.');
            details = text(data.reason, 'причина', 1000);
            tx.update(orderRef, {status: 'disputed', disputedAt: stamp(), adminNote: details, ...updated});
          } else if (action === 'adminClear') {
            if (!['completed', 'cancelled'].includes(order.status)) fail('failed-precondition', 'Сначала отмените заказ или верните его на поиск курьера.');
            release();
          }
          tx.create(db.collection('admin_logs').doc(), {action, adminId: uid, orderId, ...(courierRef ? {courierId: courierRef.id} : {}), details, createdAt: stamp()});
        } else if (action === 'offer' || action === 'accept' || selecting) {
          if (!waiting(order)) fail('failed-precondition', 'Курьер уже выбран.');
          const distance = locationNear(courier, order.fromLocation, 1000, now(), true);
          if (courier.isOnline !== true && courier.online !== true) fail('failed-precondition', 'Включите режим «На линии».');
          const offerRef = orderRef.collection('offers').doc(selecting ? id(data.offerId) : uid);
          const offer = (await tx.get(offerRef)).data();
          if (action === 'offer') {
            const price = order.priceNegotiable ? money(data.proposedPrice) : amount(data.proposedPrice);
            if (order.priceNegotiable ? price < order.clientPrice : price !== order.clientPrice) fail('invalid-argument', 'Предложение не соответствует цене заказа.');
            const expiresAt = Timestamp.fromMillis(now() + 5 * 60 * 1000);
            tx.set(offerRef, {courierId: uid, courierName: courier.displayName ?? courier.name ?? 'Курьер', courierRating: courier.rating ?? 5, courierTransport: courier.transport ?? 'bicycle', courierDistanceMeters: Math.round(distance), proposedPrice: price, originalClientPrice: order.clientPrice, status: 'pending', expiresAt, createdAt: offer?.createdAt ?? stamp(), ...updated});
            tx.update(orderRef, {...updated, offerExpiresAt: expiresAt, offersCount: (order.offersCount ?? 0) + (offer?.status === 'pending' ? 0 : 1)});
          } else {
            // Even the accept button creates/selects a normal offer. Pricing is
            // decided by the customer for negotiable orders, never by a courier.
            if (action === 'accept' && order.priceNegotiable !== false) fail('failed-precondition', 'Отправьте предложение и дождитесь выбора клиента.');
            if (selecting && (offer?.status !== 'pending' || offer.courierId !== courierRef.id || !offer.expiresAt || offer.expiresAt.toMillis() <= now())) fail('failed-precondition', 'Предложение устарело.');
            const price = selecting ? (order.priceNegotiable ? money(offer.proposedPrice) : amount(offer.proposedPrice)) : amount(order.clientPrice);
            if (!order.priceNegotiable && price !== order.clientPrice) fail('failed-precondition', 'Цена доставки фиксирована.');
            if (order.priceNegotiable && price < order.clientPrice) fail('failed-precondition', 'Некорректная цена предложения.');
            const otherOffers = await tx.get(orderRef.collection('offers').where('status', '==', 'pending'));
            for (const other of otherOffers.docs) if (other.id !== offerRef.id) tx.update(other.ref, {status: 'rejected', ...updated});
            tx.set(offerRef, {...(offer ?? {}), courierId: courierRef.id, proposedPrice: price, status: 'accepted', createdAt: offer?.createdAt ?? stamp(), ...updated});
            tx.update(orderRef, {status: 'accepted', courierId: courierRef.id, selectedCourierId: courierRef.id, selectedOfferId: offerRef.id, finalPrice: price, price, acceptedAt: stamp(), ...updated});
            tx.update(courierRef, {activeOrderId: orderId, isBusy: true, ...updated});
          }
        } else if (action === 'withdraw' || action === 'reject') {
          if (!waiting(order)) fail('failed-precondition', 'Заказ уже принят.');
          const offerRef = orderRef.collection('offers').doc(action === 'withdraw' ? uid : id(data.offerId));
          const offer = (await tx.get(offerRef)).data();
          if (offer?.status === 'pending') tx.update(offerRef, {status: action === 'withdraw' ? 'withdrawn' : 'rejected', ...updated});
        } else if (['arrive', 'pickup', 'deliver', 'complete'].includes(action)) {
          if (!assigned || courier.activeOrderId !== orderId || !courier.isBusy) fail('permission-denied', 'Заказ не назначен вам.');
          const expected = ['arrive', 'pickup'].includes(action) ? 'accepted' : 'pickedUp';
          if (order.status !== expected) fail('failed-precondition', 'Недопустимый переход статуса заказа.');
          locationNear(courier, expected === 'accepted' ? order.fromLocation : order.toLocation, 2000.01, now());
          if (action === 'pickup' && !order.arrivedAtPickupAt) fail('failed-precondition', 'Сначала отметьте прибытие.');
          if (action === 'complete') {
            const secretRef = db.collection('_order_secrets').doc(orderId);
            const secret = (await tx.get(secretRef)).data();
            if (!secret || secret.expiresAt.toMillis() <= now()) fail('failed-precondition', 'Код истёк. Обратитесь в поддержку.');
            if (secret.attempts >= 5) fail('resource-exhausted', 'Слишком много неверных попыток. Обратитесь в поддержку.');
            const submitted = typeof data.code === 'string' && /^\d{4}$/.test(data.code) ? data.code : '';
            const correct = timingSafeEqual(Buffer.from(hash(`${secret.salt}:${submitted}`)), Buffer.from(secret.codeHash));
            if (!correct) {
              tx.update(secretRef, {attempts: secret.attempts + 1});
              // Return, then throw outside the transaction so the attempt count
              // is committed rather than rolled back by the error.
              const failure = {orderId, failure: 'invalid-code'};
              tx.create(commandRef, {uid, action, orderId, fingerprint, result: failure, createdAt: stamp()});
              return failure;
            }
            tx.delete(secretRef);
            complete(tx, orderRef, courierRef, order, courier, updated);
            releaseCustomer();
          } else {
            const next = {arrive: {arrivedAtPickupAt: stamp()}, pickup: {status: 'pickedUp', pickedUpAt: stamp()}, deliver: {status: 'delivered', deliveredAt: stamp()}}[action];
            tx.update(orderRef, {...next, ...updated});
          }
        } else if (action === 'confirm') {
          if (order.status !== 'delivered' || courier.activeOrderId !== orderId) fail('failed-precondition', 'Заказ ещё не ожидает подтверждения.');
          complete(tx, orderRef, courierRef, order, courier, updated);
          tx.delete(db.collection('_order_secrets').doc(orderId));
          releaseCustomer();
        } else if (action === 'cancel') {
          if (!waiting(order)) fail('failed-precondition', 'Отменить можно только ожидающий заказ.');
          tx.update(orderRef, {status: 'cancelled', cancelledAt: stamp(), ...updated});
          tx.delete(db.collection('_order_secrets').doc(orderId));
          releaseCustomer();
        } else if (action === 'dispute') {
          if (order.status !== 'delivered') fail('failed-precondition', 'Заказ ещё не ожидает подтверждения.');
          tx.update(orderRef, {status: 'disputed', disputedAt: stamp(), ...updated});
        }
      }
      tx.create(commandRef, {uid, action, orderId, fingerprint, result, createdAt: stamp()});
      return result;
    });
    if (outcome.failure) fail('invalid-argument', 'Код не совпадает. Уточните код у клиента.');
    return outcome;
  };
}
function complete(tx, orderRef, courierRef, order, courier, updated) {
  if (order.completedAt) fail('failed-precondition', 'Заказ уже был завершён.');
  tx.update(orderRef, {status: 'completed', completedAt: stamp(), ...updated});
  tx.update(courierRef, {activeOrderId: null, isBusy: false, earningsToday: (courier.earningsToday ?? 0) + order.price, ordersToday: (courier.ordersToday ?? 0) + 1, ...updated});
}
module.exports = {createOrderCommands, meters, address, locationNear};
