import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {
  SafeNotification,
  offerReceivedNotification,
  orderStatusNotification,
} from "./domain";

/**
 * FCM Firestore triggers. Privacy-safe payloads only (no delivery code, phone or
 * address). Requires owner deploy + Messaging enabled in the project — see
 * docs/V1_8_FCM_ARCHITECTURE.md. Inactive until deployed.
 */

async function sendToUser(
  uid: string,
  notification: SafeNotification,
): Promise<void> {
  const db = getFirestore();
  const snapshot = await db
    .collection("users")
    .doc(uid)
    .collection("notification_tokens")
    .where("active", "==", true)
    .get();
  const tokens = snapshot.docs
    .map((doc) => doc.get("token"))
    .filter((token): token is string => typeof token === "string");
  if (tokens.length === 0) return;
  try {
    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title: notification.title, body: notification.body},
      data: notification.data,
    });
  } catch (error) {
    logger.error("FCM send failed", {
      errorType: error instanceof Error ? error.name : typeof error,
    });
  }
}

export const onOrderStatusChanged = onDocumentUpdated(
  {document: "orders/{orderId}", region: "europe-west1"},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (before == null || after == null) return;
    if (before.status === after.status) return;
    const customerId = after.customerId;
    if (typeof customerId !== "string") return;
    const notification = orderStatusNotification(
      String(after.status),
      event.params.orderId,
    );
    if (notification == null) return;
    await sendToUser(customerId, notification);
  },
);

export const onOfferCreated = onDocumentCreated(
  {document: "orders/{orderId}/offers/{courierId}", region: "europe-west1"},
  async (event) => {
    const db = getFirestore();
    const orderDoc = await db
      .collection("orders")
      .doc(event.params.orderId)
      .get();
    const customerId = orderDoc.get("customerId");
    if (typeof customerId !== "string") return;
    await sendToUser(
      customerId,
      offerReceivedNotification(event.params.orderId),
    );
  },
);
