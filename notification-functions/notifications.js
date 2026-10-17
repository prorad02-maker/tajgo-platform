'use strict';
const {createHash} = require('node:crypto');
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
const {HttpsError} = require('firebase-functions/v2/https');

const hash = value => createHash('sha256').update(value).digest('hex');
const validId = value => typeof value === 'string' && /^[a-zA-Z0-9_-]{1,128}$/.test(value);
const waitStates = new Set(['waiting', 'waitingOffers', 'draft']);
const messages = {
  assigned: ['Курьер выбран', 'Откройте заказ, чтобы посмотреть детали.'],
  selected: ['Вас выбрали для доставки', 'Откройте TajGo и проверьте назначенный заказ.'],
  arrived: ['Курьер прибыл', 'Курьер находится у точки забора.'],
  pickedUp: ['Заказ в пути', 'Курьер забрал заказ и направляется к получателю.'],
  delivered: ['Заказ доставлен', 'Проверьте получение и подтвердите заказ в TajGo.'],
  completed: ['Заказ завершён', 'Детали сохранены в истории заказов.'],
  cancelled: ['Заказ отменён', 'Откройте TajGo, чтобы проверить состояние заказа.'],
  disputed: ['Заказ на проверке', 'Администратор рассмотрит спор по доставке.'],
  reassigned: ['Снова ищем курьера', 'Заказ возвращён на поиск курьера.'],
  removed: ['Назначение изменилось', 'Этот заказ больше не назначен вам.'],
  offer: ['Новое предложение курьера', 'Откройте заказ и проверьте предложение.'],
};

function orderNotices(before, after) {
  if (!before || !after || !validId(after.customerId)) return [];
  const result = [];
  const add = (uid, kind) => {
    if (validId(uid) && !result.some(item => item.uid === uid && item.kind === kind)) result.push({uid, kind});
  };
  const customer = after.customerId;
  const courier = after.courierId || after.selectedCourierId;
  const previousCourier = before.courierId || before.selectedCourierId;
  if (before.status !== after.status) {
    const kind = {
      accepted: 'assigned', courierSelected: 'assigned', arrivedPickup: 'arrived',
      pickedUp: 'pickedUp', arrivedDropoff: 'pickedUp', delivered: 'delivered',
      completed: 'completed', cancelled: 'cancelled', disputed: 'disputed',
    }[after.status];
    if (kind) add(customer, kind);
    if (['completed', 'cancelled', 'disputed'].includes(after.status)) add(courier || previousCourier, kind);
    if (waitStates.has(after.status) && previousCourier) {
      add(customer, 'reassigned');
      add(previousCourier, 'removed');
    }
  } else if (!before.arrivedAtPickupAt && after.arrivedAtPickupAt) {
    add(customer, 'arrived');
  }
  if (courier && courier !== previousCourier && ['accepted', 'courierSelected', 'arrivedPickup'].includes(after.status)) add(courier, 'selected');
  return result;
}

function createDeviceRegistration(db) {
  const pendingAccounts = new Map();
  return async request => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Войдите в аккаунт.');
    const data = request.data;
    if (!data || data.accountId !== uid) throw new HttpsError('permission-denied', 'Аккаунт изменился. Повторите действие.');
    if (typeof data.enabled !== 'boolean' || data.platform !== 'android' ||
        typeof data.token !== 'string' || !/^[\x21-\x7e]{20,4096}$/.test(data.token) || !validId(data.registrationId)) {
      throw new HttpsError('invalid-argument', 'Не удалось настроить уведомления.');
    }
    const tokenRef = db.collection('_notification_tokens').doc(hash(data.token));
    const lock = db.collection('_notification_accounts').doc(uid);
    const previousOperation = pendingAccounts.get(uid) ?? Promise.resolve();
    const operation = previousOperation.catch(() => {}).then(() => db.runTransaction(async tx => {
      await tx.get(lock);
      const previous = (await tx.get(tokenRef)).data();
      if (!data.enabled) {
        // A late sign-out must never remove a newer registration on this phone.
        if (previous?.uid === uid && previous.registrationId === data.registrationId) tx.delete(tokenRef);
        return {registered: false, accountId: uid};
      }
      if (!request.auth.token?.phone_number || !(await tx.get(db.doc(`users/${uid}`))).exists) {
        throw new HttpsError('permission-denied', 'Сначала подтвердите номер и заполните профиль.');
      }
      const devices = await tx.get(db.collection('_notification_tokens').where('uid', '==', uid));
      const others = devices.docs.filter(doc => doc.id !== tokenRef.id).sort((a, b) =>
        (a.data().updatedAt?.toMillis?.() || 0) - (b.data().updatedAt?.toMillis?.() || 0));
      // Serialize registration per account and retain at most eight devices.
      for (const old of others.slice(0, Math.max(0, others.length - 7))) tx.delete(old.ref);
      tx.set(lock, {updatedAt: FieldValue.serverTimestamp()});
      tx.set(tokenRef, {uid, token: data.token, platform: data.platform, registrationId: data.registrationId, updatedAt: FieldValue.serverTimestamp()});
      return {registered: true, accountId: uid, registrationId: data.registrationId};
    }, {maxAttempts: 8}));
    pendingAccounts.set(uid, operation);
    try { return await operation; }
    finally { if (pendingAccounts.get(uid) === operation) pendingAccounts.delete(uid); }
  };
}

function createNotificationDelivery(db, messaging, {now = () => Date.now()} = {}) {
  async function deliver(eventId, orderId, notice) {
    if (!validId(orderId) || !validId(notice.uid) || !messages[notice.kind]) return;
    const jobId = hash(`${eventId}:${notice.uid}:${notice.kind}`);
    const jobRef = db.collection('_notification_events').doc(jobId);
    const claim = await db.runTransaction(async tx => {
      const job = (await tx.get(jobRef)).data();
      if (job?.state === 'sent') return null;
      if ((job?.leaseUntil?.toMillis?.() || 0) > now()) return {busy: true};
      const tokens = await tx.get(db.collection('_notification_tokens').where('uid', '==', notice.uid));
      const pending = tokens.docs.filter(doc => now() - (doc.data().updatedAt?.toMillis?.() || 0) < 30 * 86400000 && !job?.delivered?.includes(doc.id)).slice(0, 8);
      if (!pending.length) {
        if (job) tx.set(jobRef, {state: 'sent', leaseUntil: null}, {merge: true});
        return null;
      }
      tx.set(jobRef, {state: 'sending', leaseUntil: Timestamp.fromMillis(now() + 120000), delivered: job?.delivered || [], expiresAt: Timestamp.fromMillis(now() + 14 * 86400000)}, {merge: true});
      return pending;
    });
    if (!claim) return;
    // Keep the event retryable if another attempt crashes while holding a lease.
    if (claim.busy) throw new Error('Order notification delivery is already running; retry later.');
    const [title, body] = messages[notice.kind];
    let response;
    try {
      response = await messaging.sendEachForMulticast({
        tokens: claim.map(doc => doc.data().token), notification: {title, body},
        data: {type: 'order', orderId, recipientId: notice.uid, kind: notice.kind, eventId: jobId},
        android: {priority: 'high', ttl: 15 * 60 * 1000, collapseKey: 'tajgo-order', notification: {channelId: 'tajgo_orders', tag: `tajgo-${hash(orderId).slice(0, 32)}`, icon: 'ic_stat_tajgo', color: '#126B44'}},
      });
    } catch (_) {
      await jobRef.set({state: 'retry', leaseUntil: null}, {merge: true});
      throw new Error('Order notification delivery needs a retry.');
    }
    const delivered = [], invalid = [];
    let retry = false;
    response.responses.forEach((item, index) => {
      if (item.success) delivered.push(claim[index].id);
      else if (['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(item.error?.code)) {
        delivered.push(claim[index].id); invalid.push(claim[index]);
      } else retry = true;
    });
    await db.runTransaction(async tx => {
      const current = await Promise.all(invalid.map(doc => tx.get(doc.ref)));
      current.forEach((doc, index) => {
        if (doc.data()?.uid === notice.uid && doc.data()?.registrationId === invalid[index].data().registrationId) tx.delete(doc.ref);
      });
      tx.set(jobRef, {state: retry ? 'retry' : 'sent', leaseUntil: null,
        ...(delivered.length ? {delivered: FieldValue.arrayUnion(...delivered)} : {})}, {merge: true});
    });
    if (retry) throw new Error('Order notification delivery needs a retry.');
  }
  const recent = event => typeof event.id === 'string' && Number.isFinite(Date.parse(event.time)) && now() - Date.parse(event.time) < 15 * 60000;
  return {
    async orderChanged(event) {
      if (!recent(event) || !event.data?.before.exists || !event.data?.after.exists) return;
      const before = event.data.before.data(), after = event.data.after.data();
      const current = (await db.doc(`orders/${event.params.orderId}`).get()).data();
      // Ignore out-of-order deliveries after a newer state/assignment exists.
      if (!current || current.status !== after.status || current.courierId !== after.courierId || current.customerId !== after.customerId) return;
      const outcomes = await Promise.allSettled(orderNotices(before, after).map(notice => deliver(event.id, event.params.orderId, notice)));
      if (outcomes.some(item => item.status === 'rejected')) throw new Error('Order notification delivery needs a retry.');
    },
    async offerChanged(event) {
      if (!recent(event) || !event.data?.after.exists) return;
      const after = event.data.after.data(), before = event.data.before.data();
      if (after.status !== 'pending' || (after.expiresAt?.toMillis?.() || 0) <= now() ||
          (before?.status === 'pending' && before.proposedPrice === after.proposedPrice)) return;
      const order = (await db.doc(`orders/${event.params.orderId}`).get()).data();
      const current = (await db.doc(`orders/${event.params.orderId}/offers/${event.params.offerId}`).get()).data();
      if (!order || !waitStates.has(order.status) || order.courierId || current?.status !== 'pending' || current.proposedPrice !== after.proposedPrice) return;
      await deliver(event.id, event.params.orderId, {uid: order.customerId, kind: 'offer'});
    },
  };
}
module.exports = {createDeviceRegistration, createNotificationDelivery, orderNotices};
