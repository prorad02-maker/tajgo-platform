import {
  FieldValue,
  DocumentReference,
  Firestore,
  GeoPoint,
  Timestamp,
  Transaction,
} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {
  ACTION_RADIUS_METERS,
  CoreError,
  MAX_CODE_ATTEMPTS,
  OFFER_LIFETIME_SECONDS,
  Principal,
  activeDeliveryStatuses,
  asRecord,
  assertCourierEligibility,
  canCourierTransition,
  commandDocumentId,
  coordinateFromStored,
  dateFromStored,
  deliveryEtaMinutes,
  deterministicOrderId,
  generateDeliveryCode,
  hashDeliveryCode,
  haversineDistanceMeters,
  normalizeStoredStatus,
  optionalString,
  parseCoordinate,
  requiredIdempotencyKey,
  requiredNumber,
  requiredString,
  suggestedDeliveryPrice,
  terminalOrderStatuses,
  toGeoPoint,
  validateOfferPrice,
  verifyDeliveryCode,
  waitingOrderStatuses,
} from "./domain";

type Data = Record<string, unknown>;
type Result = Record<string, unknown>;

interface CommandContext {
  principal: Principal;
  data: Data;
}

export class TajGoAuthoritativeCore {
  constructor(
    private readonly db: Firestore,
    private readonly now: () => Date = () => new Date(),
    private readonly codeGenerator: () => string = generateDeliveryCode,
    private readonly authDeleter: (uid: string) => Promise<void> = async (
      uid,
    ) => {
      await getAuth().deleteUser(uid);
    },
  ) {}

  async ensureUserProfile(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const initialIntent = optionalString(data, "initialIntent", 20);
    if (
      initialIntent != null &&
      initialIntent !== "customer" &&
      initialIntent !== "courier"
    ) {
      throw new CoreError("invalid-argument", "Неизвестный режим аккаунта.");
    }
    const authPhone =
      typeof principal.token.phone_number === "string"
        ? principal.token.phone_number
        : null;
    const authName =
      typeof principal.token.name === "string"
        ? principal.token.name.trim()
        : "";
    const userRef = this.db.collection("users").doc(principal.uid);
    const courierRef = this.db.collection("couriers").doc(principal.uid);
    await this.db.runTransaction(async (transaction) => {
      const [userDoc, courierDoc] = await Promise.all([
        transaction.get(userRef),
        transaction.get(courierRef),
      ]);
      const existing = userDoc.data() ?? {};
      const legacyRole =
        typeof existing.role === "string" ? existing.role : "customer";
      const hasCourierCapability =
        courierDoc.exists ||
        legacyRole === "courier" ||
        existing.isCourier === true ||
        existing.courierMode === true;
      const existingRoles = Array.isArray(existing.roles)
        ? existing.roles.filter(
            (value): value is string =>
              value === "customer" || value === "courier",
          )
        : [];
      const roles = new Set<string>(["customer", ...existingRoles]);
      if (hasCourierCapability) roles.add("courier");
      const role =
        legacyRole === "admin"
          ? "admin"
          : legacyRole === "courier" && hasCourierCapability
            ? "courier"
            : "customer";
      const displayName =
        optionalString(data, "displayName", 80) ||
        (typeof existing.displayName === "string"
          ? existing.displayName
          : typeof existing.name === "string"
            ? existing.name
            : authName || "Пользователь");
      transaction.set(
        userRef,
        {
          uid: principal.uid,
          phoneNumber: authPhone ?? existing.phoneNumber ?? null,
          displayName,
          name: displayName,
          role,
          roles: [...roles],
          lastMode:
            existing.lastMode === "courier" && hasCourierCapability
              ? "courier"
              : "customer",
          selectedRole:
            existing.selectedRole === "courier" ? "courier" : "customer",
          targetRole:
            existing.targetRole === "courier"
              ? "courier"
              : initialIntent === "courier"
                ? "courier"
                : "customer",
          courierStatus:
            typeof existing.courierStatus === "string"
              ? existing.courierStatus
              : hasCourierCapability
                ? "approved"
                : initialIntent === "courier"
                  ? "draft"
                  : "none",
          phoneVerified: authPhone != null,
          profileComplete: existing.profileComplete === true,
          onboardingCompleted: existing.onboardingCompleted === true,
          courierOnboardingCompleted:
            existing.courierOnboardingCompleted === true ||
            courierDoc.exists,
          city:
            typeof existing.city === "string" ? existing.city : "Худжанд",
          language:
            typeof existing.language === "string" ? existing.language : "ru",
          createdAt: userDoc.exists
            ? existing.createdAt ?? FieldValue.serverTimestamp()
            : FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });
    return {uid: principal.uid};
  }

  async completeUserProfile(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const displayName = requiredString(data, "displayName", {min: 2, max: 80});
    const photoUrl = optionalString(data, "photoUrl", 500);
    const initialIntent = requiredString(data, "initialIntent", {max: 20});
    if (initialIntent !== "customer" && initialIntent !== "courier") {
      throw new CoreError("invalid-argument", "Неизвестный режим аккаунта.");
    }
    const key = requiredIdempotencyKey(data);
    return this.runIdempotent(
      "completeUserProfile",
      principal,
      key,
      async (transaction) => {
        const userRef = this.db.collection("users").doc(principal.uid);
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw new CoreError("not-found", "Профиль пользователя не найден.");
        }
        const user = userDoc.data() ?? {};
        const courierApproved =
          user.courierStatus === "approved" &&
          Array.isArray(user.roles) &&
          user.roles.includes("courier");
        const preserveAdmin = user.role === "admin";
        transaction.update(userRef, {
          displayName,
          name: displayName,
          ...(photoUrl != null ? {photoUrl} : {}),
          profileComplete: true,
          onboardingCompleted: true,
          selectedRole: initialIntent,
          targetRole: initialIntent,
          lastMode:
            initialIntent === "courier" && courierApproved
              ? "courier"
              : "customer",
          role: preserveAdmin
            ? "admin"
            : initialIntent === "courier" && courierApproved
              ? "courier"
              : "customer",
          ...(initialIntent === "courier" &&
          user.courierStatus !== "approved"
            ? {courierStatus: user.courierStatus ?? "draft"}
            : {}),
          roleSelectedAt: user.roleSelectedAt ?? FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {profileComplete: true};
      },
    );
  }

  async switchAccountMode(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const targetMode = requiredString(data, "targetMode", {max: 20});
    if (targetMode !== "customer" && targetMode !== "courier") {
      throw new CoreError("invalid-argument", "Неизвестный режим аккаунта.");
    }
    const key = requiredIdempotencyKey(data);
    return this.runIdempotent(
      "switchAccountMode",
      principal,
      key,
      async (transaction) => {
        const userRef = this.db.collection("users").doc(principal.uid);
        const courierRef = this.db.collection("couriers").doc(principal.uid);
        const publicRef = this.db
          .collection("courier_public")
          .doc(principal.uid);
        const activeCustomerOrders = this.db
          .collection("orders")
          .where("customerId", "==", principal.uid)
          .where("status", "in", [
            "waitingOffers",
            "accepted",
            "arrivedPickup",
            "pickedUp",
            "arrivedDropoff",
            "delivered",
            "disputed",
          ])
          .limit(1);
        const [userDoc, courierDoc, customerOrders] = await Promise.all([
          transaction.get(userRef),
          transaction.get(courierRef),
          transaction.get(activeCustomerOrders),
        ]);
        if (!userDoc.exists) {
          throw new CoreError("not-found", "Профиль пользователя не найден.");
        }
        const user = userDoc.data() ?? {};
        if (user.role === "admin") {
          throw new CoreError(
            "failed-precondition",
            "Администратор использует защищённый интерфейс управления.",
          );
        }
        const courier = courierDoc.data() ?? {};
        if (
          courier.activeOrderId != null ||
          courier.isBusy === true ||
          !customerOrders.empty
        ) {
          throw new CoreError(
            "failed-precondition",
            "Сначала завершите активный заказ.",
          );
        }
        if (targetMode === "courier") {
          const roles = Array.isArray(user.roles) ? user.roles : [];
          if (
            user.courierStatus !== "approved" ||
            user.courierOnboardingCompleted !== true ||
            !roles.includes("courier")
          ) {
            throw new CoreError(
              "failed-precondition",
              "Курьерский режим ещё не одобрен.",
            );
          }
        }
        transaction.update(userRef, {
          role: targetMode,
          lastMode: targetMode,
          selectedRole: targetMode,
          onboardingCompleted: true,
          updatedAt: FieldValue.serverTimestamp(),
        });
        if (targetMode === "customer" && courierDoc.exists) {
          transaction.update(courierRef, {
            isOnline: false,
            online: false,
            updatedAt: FieldValue.serverTimestamp(),
          });
          transaction.set(
            publicRef,
            {
              isOnline: false,
              online: false,
              updatedAt: FieldValue.serverTimestamp(),
            },
            {merge: true},
          );
        }
        return {mode: targetMode};
      },
    );
  }

  async completeCourierOnboarding(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    return this.runIdempotent(
      "completeCourierOnboarding",
      principal,
      key,
      async (transaction) => {
        const userRef = this.db.collection("users").doc(principal.uid);
        const userDoc = await transaction.get(userRef);
        const user = userDoc.data();
        const roles = Array.isArray(user?.roles) ? user.roles : [];
        if (
          user?.courierStatus !== "approved" ||
          !roles.includes("courier")
        ) {
          throw new CoreError(
            "failed-precondition",
            "Курьерский режим ещё не одобрен.",
          );
        }
        transaction.update(userRef, {
          courierOnboardingCompleted: true,
          role: "courier",
          lastMode: "courier",
          selectedRole: "courier",
          onboardingCompleted: true,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {mode: "courier"};
      },
    );
  }

  async ensureCourierProfile(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    return this.runIdempotent(
      "ensureCourierProfile",
      principal,
      key,
      async (transaction) => {
        const userRef = this.db.collection("users").doc(principal.uid);
        const courierRef = this.db.collection("couriers").doc(principal.uid);
        const publicRef = this.db
          .collection("courier_public")
          .doc(principal.uid);
        const [userDoc, courierDoc] = await Promise.all([
          transaction.get(userRef),
          transaction.get(courierRef),
        ]);
        const user = userDoc.data();
        const roles = Array.isArray(user?.roles) ? user.roles : [];
        if (
          user?.courierStatus !== "approved" ||
          user?.courierOnboardingCompleted !== true ||
          !roles.includes("courier")
        ) {
          throw new CoreError(
            "permission-denied",
            "Курьерский профиль ещё не одобрен.",
          );
        }
        const existing = courierDoc.data() ?? {};
        const displayName =
          typeof user?.displayName === "string"
            ? user.displayName
            : "Курьер";
        const isOnline =
          existing.isOnline === true || existing.online === true;
        transaction.set(
          courierRef,
          {
            uid: principal.uid,
            phoneNumber: user?.phoneNumber ?? null,
            displayName,
            name: displayName,
            city: user?.city ?? "Худжанд",
            isOnline,
            online: isOnline,
            rating: existing.rating ?? 5,
            score: existing.score ?? 100,
            transport: existing.transport ?? "bicycle",
            earningsToday: existing.earningsToday ?? 0,
            ordersToday: existing.ordersToday ?? 0,
            activeOrderId: existing.activeOrderId ?? null,
            isBusy:
              existing.isBusy === true || existing.activeOrderId != null,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        transaction.set(
          publicRef,
          {
            uid: principal.uid,
            displayName,
            name: displayName,
            isOnline,
            online: isOnline,
            rating: existing.rating ?? 5,
            transport: existing.transport ?? "bicycle",
            ...(existing.location instanceof GeoPoint
              ? {
                  location: existing.location,
                  locationUpdatedAt: existing.locationUpdatedAt,
                  locationAccuracy: existing.locationAccuracy,
                }
              : {}),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        return {courierId: principal.uid};
      },
    );
  }

  async createCustomDeliveryOrder(
    context: CommandContext,
  ): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const fromText = requiredString(data, "fromText", {min: 2, max: 240});
    const toText = requiredString(data, "toText", {min: 2, max: 240});
    const type = requiredString(data, "type", {max: 40});
    const comment = optionalString(data, "comment", 500);
    const clientPrice = requiredNumber(data, "clientPrice", {
      min: 10,
      max: 10_000,
      integer: true,
    });
    const from = parseCoordinate(data.fromLocation, "точки A");
    const to = parseCoordinate(data.toLocation, "точки B");
    const distanceKm = haversineDistanceMeters(from, to) / 1000;
    const suggestedPrice = suggestedDeliveryPrice(distanceKm);
    const etaMinutes = deliveryEtaMinutes(distanceKm);
    const code = this.codeGenerator();
    const secret = hashDeliveryCode(code);
    return this.runIdempotent(
      "createCustomDeliveryOrder",
      principal,
      key,
      async (transaction) => {
        const user = await this.requireCustomer(transaction, principal);
        this.requireVerifiedPhone(principal, user);
        const orderId = deterministicOrderId(
          principal.uid,
          "custom",
          key,
        );
        const orderRef = this.db.collection("orders").doc(orderId);
        const secretRef = this.db.collection("order_secrets").doc(orderId);
        const codeRef = this.db
          .collection("order_customer_codes")
          .doc(orderId);
        const existingOrder = await transaction.get(orderRef);
        if (existingOrder.exists) {
          return {orderId};
        }
        transaction.create(orderRef, {
          customerId: principal.uid,
          customerName: user.displayName ?? user.name ?? "Клиент",
          status: "waitingOffers",
          orderType: "customDelivery",
          type,
          city: user.city ?? "Худжанд",
          fromText,
          toText,
          fromLocation: toGeoPoint(from),
          toLocation: toGeoPoint(to),
          distanceKm: Number(distanceKm.toFixed(2)),
          etaMinutes,
          price: clientPrice,
          suggestedPrice,
          clientPrice,
          priceNegotiable: true,
          offersCount: 0,
          pricingVersion: "server-v1.8",
          currency: "TJS",
          codeAvailable: true,
          ...(comment != null && comment.length > 0 ? {comment} : {}),
          declinedBy: [],
          requestId: key,
          schemaVersion: 8,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        this.writeDeliverySecret(
          transaction,
          secretRef,
          codeRef,
          principal.uid,
          orderId,
          code,
          secret,
        );
        return {orderId};
      },
    );
  }

  async submitCourierOffer(context: CommandContext): Promise<Result> {
    return this.writeCourierOffer("submitCourierOffer", context);
  }

  async updateCourierOffer(context: CommandContext): Promise<Result> {
    return this.writeCourierOffer("updateCourierOffer", context);
  }

  private async writeCourierOffer(
    command: string,
    context: CommandContext,
  ): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const orderId = requiredString(data, "orderId", {max: 128});
    const proposedPrice = requiredNumber(data, "proposedPrice", {
      min: 10,
      max: 10_000,
      integer: true,
    });
    return this.runIdempotent(
      command,
      principal,
      key,
      async (transaction) => {
        const user = await this.requireCourier(transaction, principal);
        const orderRef = this.db.collection("orders").doc(orderId);
        const courierRef = this.db
          .collection("couriers")
          .doc(principal.uid);
        const offerRef = orderRef.collection("offers").doc(principal.uid);
        const [orderDoc, courierDoc, offerDoc] = await Promise.all([
          transaction.get(orderRef),
          transaction.get(courierRef),
          transaction.get(offerRef),
        ]);
        const order = orderDoc.data();
        const courier = courierDoc.data();
        if (order == null) {
          throw new CoreError("not-found", "Заказ не найден.");
        }
        if (courier == null) {
          throw new CoreError("not-found", "Профиль курьера не найден.");
        }
        if (
          !waitingOrderStatuses.has(String(order.status)) ||
          order.courierId != null ||
          order.selectedCourierId != null
        ) {
          throw new CoreError(
            "failed-precondition",
            "Заказ уже недоступен для предложений.",
          );
        }
        const clientPrice = Number(order.clientPrice ?? order.price ?? 0);
        validateOfferPrice({
          proposedPrice,
          clientPrice,
          priceNegotiable: order.priceNegotiable !== false,
        });
        const distanceMeters = assertCourierEligibility({
          isOnline:
            courier.isOnline === true || courier.online === true,
          activeOrderId: courier.activeOrderId,
          isBusy: courier.isBusy === true,
          courierLocation: coordinateFromStored(courier.location),
          pickupLocation: coordinateFromStored(order.fromLocation),
          locationUpdatedAt: dateFromStored(courier.locationUpdatedAt),
          locationAccuracy:
            typeof courier.locationAccuracy === "number"
              ? courier.locationAccuracy
              : null,
          now: this.now(),
        });
        const previous = offerDoc.data();
        if (
          command === "updateCourierOffer" &&
          previous?.status !== "pending"
        ) {
          throw new CoreError(
            "failed-precondition",
            "Изменить можно только активное предложение.",
          );
        }
        const expiresAt = Timestamp.fromMillis(
          this.now().getTime() + OFFER_LIFETIME_SECONDS * 1000,
        );
        transaction.set(
          offerRef,
          {
            orderId,
            courierId: principal.uid,
            courierName:
              user.displayName ??
              courier.displayName ??
              courier.name ??
              "Курьер",
            courierRating: courier.rating ?? 5,
            courierTransport: courier.transport ?? "bicycle",
            courierDistanceMeters: Math.round(distanceMeters),
            proposedPrice,
            originalClientPrice: clientPrice,
            status: "pending",
            createdAt:
              previous?.createdAt ?? FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            expiresAt,
            isTest: false,
            requestId: key,
          },
          {merge: true},
        );
        if (previous?.status !== "pending") {
          transaction.update(orderRef, {
            offersCount: FieldValue.increment(1),
            offerExpiresAt: expiresAt,
            updatedAt: FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(orderRef, {
            offerExpiresAt: expiresAt,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        return {
          orderId,
          offerId: principal.uid,
          distanceMeters: Math.round(distanceMeters),
          expiresAt: expiresAt.toMillis(),
        };
      },
    );
  }

  async withdrawCourierOffer(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const orderId = requiredString(data, "orderId", {max: 128});
    return this.runIdempotent(
      "withdrawCourierOffer",
      principal,
      key,
      async (transaction) => {
        await this.requireCourier(transaction, principal);
        const orderRef = this.db.collection("orders").doc(orderId);
        const offerRef = orderRef.collection("offers").doc(principal.uid);
        const [orderDoc, offerDoc] = await Promise.all([
          transaction.get(orderRef),
          transaction.get(offerRef),
        ]);
        if (!orderDoc.exists || !offerDoc.exists) {
          throw new CoreError("not-found", "Предложение не найдено.");
        }
        const offer = offerDoc.data() ?? {};
        if (offer.courierId !== principal.uid) {
          throw new CoreError(
            "permission-denied",
            "Нельзя изменить чужое предложение.",
          );
        }
        if (offer.status === "withdrawn") {
          return {orderId, offerId: principal.uid};
        }
        if (offer.status !== "pending") {
          throw new CoreError(
            "failed-precondition",
            "Это предложение уже закрыто.",
          );
        }
        transaction.update(offerRef, {
          status: "withdrawn",
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.update(orderRef, {
          offersCount: FieldValue.increment(-1),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {orderId, offerId: principal.uid};
      },
    );
  }

  async rejectCourierOffer(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const orderId = requiredString(data, "orderId", {max: 128});
    const offerId = requiredString(data, "offerId", {max: 128});
    return this.runIdempotent(
      "rejectCourierOffer",
      principal,
      key,
      async (transaction) => {
        await this.requireCustomer(transaction, principal);
        const orderRef = this.db.collection("orders").doc(orderId);
        const offerRef = orderRef.collection("offers").doc(offerId);
        const [orderDoc, offerDoc] = await Promise.all([
          transaction.get(orderRef),
          transaction.get(offerRef),
        ]);
        const order = orderDoc.data();
        const offer = offerDoc.data();
        if (order == null || offer == null) {
          throw new CoreError("not-found", "Предложение не найдено.");
        }
        if (order.customerId !== principal.uid) {
          throw new CoreError(
            "permission-denied",
            "Это не ваш заказ.",
          );
        }
        if (offer.status !== "pending") {
          throw new CoreError(
            "failed-precondition",
            "Предложение уже закрыто.",
          );
        }
        transaction.update(offerRef, {
          status: "rejected",
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.update(orderRef, {
          offersCount: FieldValue.increment(-1),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {orderId, offerId};
      },
    );
  }

  async selectCourierOffer(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const orderId = requiredString(data, "orderId", {max: 128});
    const offerId = requiredString(data, "offerId", {max: 128});
    return this.runIdempotent(
      "selectCourierOffer",
      principal,
      key,
      async (transaction) => {
        await this.requireCustomer(transaction, principal);
        const orderRef = this.db.collection("orders").doc(orderId);
        const offerRef = orderRef.collection("offers").doc(offerId);
        const [orderDoc, offerDoc] = await Promise.all([
          transaction.get(orderRef),
          transaction.get(offerRef),
        ]);
        const order = orderDoc.data();
        const offer = offerDoc.data();
        if (order == null || offer == null) {
          throw new CoreError("not-found", "Предложение не найдено.");
        }
        if (order.customerId !== principal.uid) {
          throw new CoreError(
            "permission-denied",
            "Это не ваш заказ.",
          );
        }
        if (
          !waitingOrderStatuses.has(String(order.status)) ||
          order.selectedCourierId != null
        ) {
          throw new CoreError(
            "failed-precondition",
            "Курьер для заказа уже выбран.",
          );
        }
        if (offer.status !== "pending") {
          throw new CoreError(
            "failed-precondition",
            "Предложение уже закрыто.",
          );
        }
        const expiresAt = dateFromStored(offer.expiresAt);
        if (expiresAt == null || expiresAt.getTime() <= this.now().getTime()) {
          throw new CoreError(
            "failed-precondition",
            "Срок предложения истёк.",
            {reason: "offer-expired"},
          );
        }
        const courierId =
          typeof offer.courierId === "string" ? offer.courierId : offerId;
        const courierRef = this.db.collection("couriers").doc(courierId);
        const courierUserRef = this.db.collection("users").doc(courierId);
        const [courierDoc, courierUserDoc, pendingOffers] =
          await Promise.all([
            transaction.get(courierRef),
            transaction.get(courierUserRef),
            transaction.get(
              orderRef.collection("offers").where("status", "==", "pending"),
            ),
          ]);
        const courier = courierDoc.data();
        const courierUser = courierUserDoc.data();
        const roles = Array.isArray(courierUser?.roles)
          ? courierUser.roles
          : [];
        if (
          courier == null ||
          courierUser?.courierStatus !== "approved" ||
          !roles.includes("courier")
        ) {
          throw new CoreError(
            "failed-precondition",
            "Курьер сейчас недоступен.",
          );
        }
        const distanceMeters = assertCourierEligibility({
          isOnline:
            courier.isOnline === true || courier.online === true,
          activeOrderId: courier.activeOrderId,
          isBusy: courier.isBusy === true,
          courierLocation: coordinateFromStored(courier.location),
          pickupLocation: coordinateFromStored(order.fromLocation),
          locationUpdatedAt: dateFromStored(courier.locationUpdatedAt),
          locationAccuracy:
            typeof courier.locationAccuracy === "number"
              ? courier.locationAccuracy
              : null,
          now: this.now(),
        });
        const finalPrice = Number(offer.proposedPrice);
        validateOfferPrice({
          proposedPrice: finalPrice,
          clientPrice: Number(order.clientPrice ?? order.price ?? 0),
          priceNegotiable: order.priceNegotiable !== false,
        });
        for (const pending of pendingOffers.docs) {
          transaction.update(pending.ref, {
            status: pending.id === offerId ? "accepted" : "rejected",
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        transaction.update(orderRef, {
          status: "accepted",
          courierId,
          selectedCourierId: courierId,
          selectedOfferId: offerId,
          finalPrice,
          price: finalPrice,
          finalPriceLocked: true,
          offersCount: 0,
          acceptedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.update(courierRef, {
          activeOrderId: orderId,
          currentOrderId: orderId,
          isBusy: true,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {
          orderId,
          courierId,
          offerId,
          finalPrice,
          distanceMeters: Math.round(distanceMeters),
        };
      },
    );
  }

  async cancelWaitingOrder(context: CommandContext): Promise<Result> {
    return this.cancelCustomerOrder("cancelWaitingOrder", context, false);
  }

  async cancelCatalogOrder(context: CommandContext): Promise<Result> {
    return this.cancelCustomerOrder("cancelCatalogOrder", context, true);
  }

  private async cancelCustomerOrder(
    command: string,
    context: CommandContext,
    catalogOnly: boolean,
  ): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const orderId = requiredString(data, "orderId", {max: 128});
    return this.runIdempotent(
      command,
      principal,
      key,
      async (transaction) => {
        await this.requireCustomer(transaction, principal);
        const orderRef = this.db.collection("orders").doc(orderId);
        const [orderDoc, pendingOffers] = await Promise.all([
          transaction.get(orderRef),
          transaction.get(
            orderRef.collection("offers").where("status", "==", "pending"),
          ),
        ]);
        const order = orderDoc.data();
        if (order == null) {
          throw new CoreError("not-found", "Заказ не найден.");
        }
        if (order.customerId !== principal.uid) {
          throw new CoreError("permission-denied", "Это не ваш заказ.");
        }
        if (
          catalogOnly &&
          order.orderType !== "catalogOrder"
        ) {
          throw new CoreError("invalid-argument", "Это не заказ каталога.");
        }
        if (
          !waitingOrderStatuses.has(String(order.status)) ||
          order.courierId != null ||
          order.selectedCourierId != null
        ) {
          throw new CoreError(
            "failed-precondition",
            "Отменить можно только ожидающий заказ.",
          );
        }
        for (const offer of pendingOffers.docs) {
          transaction.update(offer.ref, {
            status: "rejected",
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        transaction.update(orderRef, {
          status: "cancelled",
          offersCount: 0,
          cancelledAt: FieldValue.serverTimestamp(),
          cancelledReason: "customer",
          updatedAt: FieldValue.serverTimestamp(),
        });
        this.deleteDeliverySecret(transaction, orderId);
        return {orderId, status: "cancelled"};
      },
    );
  }

  async updateDeliveryStatus(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const orderId = requiredString(data, "orderId", {max: 128});
    const action = requiredString(data, "action", {max: 40});
    return this.runIdempotent(
      "updateDeliveryStatus",
      principal,
      `${key}:${action}`,
      async (transaction) => {
        const userRef = this.db.collection("users").doc(principal.uid);
        const orderRef = this.db.collection("orders").doc(orderId);
        const [userDoc, orderDoc] = await Promise.all([
          transaction.get(userRef),
          transaction.get(orderRef),
        ]);
        const user = userDoc.data();
        const order = orderDoc.data();
        if (user == null) {
          throw new CoreError("permission-denied", "Профиль не найден.");
        }
        if (order == null) {
          throw new CoreError("not-found", "Заказ не найден.");
        }
        const current = normalizeStoredStatus(order.status);
        if (action === "customerDispute") {
          if (
            order.customerId !== principal.uid ||
            current !== "delivered"
          ) {
            throw new CoreError(
              "failed-precondition",
              "Спор сейчас открыть нельзя.",
            );
          }
          transaction.update(orderRef, {
            status: "disputed",
            disputedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          return {orderId, status: "disputed"};
        }
        if (action === "customerConfirm") {
          if (
            order.customerId !== principal.uid ||
            current !== "delivered"
          ) {
            throw new CoreError(
              "failed-precondition",
              "Заказ ещё не ожидает подтверждения.",
            );
          }
          const courierId = this.orderCourierId(order);
          const courierRef = this.db.collection("couriers").doc(courierId);
          const courierDoc = await transaction.get(courierRef);
          if (!courierDoc.exists) {
            throw new CoreError("not-found", "Курьер не найден.");
          }
          this.completeOrder(
            transaction,
            orderRef,
            courierRef,
            order,
            "customer",
          );
          return {orderId, status: "completed"};
        }
        if (
          user.role !== "courier" ||
          user.courierStatus !== "approved" ||
          order.courierId !== principal.uid
        ) {
          throw new CoreError(
            "permission-denied",
            "Действие доступно только назначенному курьеру.",
          );
        }
        const targetStatus = {
          arrivedPickup: "arrivedPickup",
          pickedUp: "pickedUp",
          arrivedDropoff: "arrivedDropoff",
          delivered: "delivered",
        }[action];
        if (targetStatus == null || !canCourierTransition(current, targetStatus)) {
          throw new CoreError(
            "failed-precondition",
            "Недопустимый переход статуса заказа.",
          );
        }
        const courierRef = this.db
          .collection("couriers")
          .doc(principal.uid);
        const courierDoc = await transaction.get(courierRef);
        const courier = courierDoc.data();
        if (courier == null) {
          throw new CoreError("not-found", "Курьер не найден.");
        }
        const targetLocation =
          targetStatus === "arrivedPickup" || targetStatus === "pickedUp"
            ? order.fromLocation
            : order.toLocation;
        assertCourierEligibility({
          isOnline: true,
          activeOrderId: null,
          isBusy: false,
          courierLocation: coordinateFromStored(courier.location),
          pickupLocation: coordinateFromStored(targetLocation),
          locationUpdatedAt: dateFromStored(courier.locationUpdatedAt),
          locationAccuracy:
            typeof courier.locationAccuracy === "number"
              ? courier.locationAccuracy
              : null,
          now: this.now(),
          radiusMeters: ACTION_RADIUS_METERS,
        });
        const timestampField = {
          arrivedPickup: "arrivedAtPickupAt",
          pickedUp: "pickedUpAt",
          arrivedDropoff: "arrivedAtDropoffAt",
          delivered: "deliveredAt",
        }[targetStatus];
        if (timestampField == null) {
          throw new CoreError(
            "invalid-argument",
            "Неизвестный переход статуса заказа.",
          );
        }
        transaction.update(orderRef, {
          status: targetStatus,
          [timestampField]: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {orderId, status: targetStatus};
      },
    );
  }

  async completeDeliveryWithCode(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const orderId = requiredString(data, "orderId", {max: 128});
    const code = requiredString(data, "code", {
      min: 4,
      max: 4,
      pattern: /^\d{4}$/,
    });
    const outcome = await this.runIdempotent(
      "completeDeliveryWithCode",
      principal,
      key,
      async (transaction) => {
        await this.requireCourier(transaction, principal);
        const orderRef = this.db.collection("orders").doc(orderId);
        const courierRef = this.db
          .collection("couriers")
          .doc(principal.uid);
        const secretRef = this.db.collection("order_secrets").doc(orderId);
        const [orderDoc, courierDoc, secretDoc] = await Promise.all([
          transaction.get(orderRef),
          transaction.get(courierRef),
          transaction.get(secretRef),
        ]);
        const order = orderDoc.data();
        const courier = courierDoc.data();
        const secret = secretDoc.data();
        if (order == null || courier == null || secret == null) {
          throw new CoreError(
            "not-found",
            "Заказ или код подтверждения не найден.",
          );
        }
        const current = normalizeStoredStatus(order.status);
        if (
          order.courierId !== principal.uid ||
          !new Set(["pickedUp", "arrivedDropoff", "delivered"]).has(current)
        ) {
          throw new CoreError(
            "failed-precondition",
            "Завершить этот заказ сейчас нельзя.",
          );
        }
        assertCourierEligibility({
          isOnline: true,
          activeOrderId: null,
          isBusy: false,
          courierLocation: coordinateFromStored(courier.location),
          pickupLocation: coordinateFromStored(order.toLocation),
          locationUpdatedAt: dateFromStored(courier.locationUpdatedAt),
          locationAccuracy:
            typeof courier.locationAccuracy === "number"
              ? courier.locationAccuracy
              : null,
          now: this.now(),
          radiusMeters: ACTION_RADIUS_METERS,
        });
        const attempts =
          typeof secret.failedAttempts === "number"
            ? secret.failedAttempts
            : 0;
        if (attempts >= MAX_CODE_ATTEMPTS || secret.locked === true) {
          return {ok: false, reason: "locked"};
        }
        const valid = verifyDeliveryCode(code, {
          salt: String(secret.salt ?? ""),
          hash: String(secret.hash ?? ""),
        });
        if (!valid) {
          const nextAttempts = attempts + 1;
          transaction.update(secretRef, {
            failedAttempts: nextAttempts,
            locked: nextAttempts >= MAX_CODE_ATTEMPTS,
            lastFailedAt: FieldValue.serverTimestamp(),
          });
          transaction.create(this.db.collection("admin_logs").doc(), {
            action: "deliveryCodeRejected",
            actorId: principal.uid,
            orderId,
            attempts: nextAttempts,
            createdAt: FieldValue.serverTimestamp(),
          });
          return {
            ok: false,
            reason:
              nextAttempts >= MAX_CODE_ATTEMPTS ? "locked" : "invalid-code",
          };
        }
        this.completeOrder(
          transaction,
          orderRef,
          courierRef,
          order,
          "code",
        );
        transaction.create(this.db.collection("admin_logs").doc(), {
          action: "deliveryCompletedWithCode",
          actorId: principal.uid,
          orderId,
          createdAt: FieldValue.serverTimestamp(),
        });
        return {ok: true, orderId, status: "completed"};
      },
    );
    if (outcome.ok !== true) {
      if (outcome.reason === "locked") {
        throw new CoreError(
          "resource-exhausted",
          "Слишком много неверных попыток. Обратитесь в поддержку.",
          {reason: "code-locked"},
        );
      }
      throw new CoreError(
        "failed-precondition",
        "Неверный код. Уточните код у клиента.",
        {reason: "invalid-code"},
      );
    }
    return outcome;
  }

  async createCatalogOrder(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const partnerId = requiredString(data, "partnerId", {max: 128});
    const deliveryAddress = requiredString(data, "deliveryAddress", {
      min: 2,
      max: 240,
    });
    const delivery = parseCoordinate(data.deliveryLocation, "доставки");
    const comment = optionalString(data, "comment", 500);
    if (!Array.isArray(data.items) || data.items.length === 0) {
      throw new CoreError("invalid-argument", "Корзина пуста.");
    }
    if (data.items.length > 50) {
      throw new CoreError(
        "invalid-argument",
        "В одном заказе может быть не больше 50 товаров.",
      );
    }
    const requestedItems = data.items.map((raw) => {
      const item = asRecord(raw);
      return {
        productId: requiredString(item, "productId", {max: 128}),
        quantity: requiredNumber(item, "quantity", {
          min: 0.5,
          max: 100,
        }),
        knownUnitPrice: requiredNumber(item, "knownUnitPrice", {
          min: 0,
          max: 1_000_000,
        }),
      };
    });
    if (
      new Set(requestedItems.map((item) => item.productId)).size !==
      requestedItems.length
    ) {
      throw new CoreError(
        "invalid-argument",
        "Товар не должен повторяться в корзине.",
      );
    }
    const code = this.codeGenerator();
    const secret = hashDeliveryCode(code);
    return this.runIdempotent(
      "createCatalogOrder",
      principal,
      key,
      async (transaction) => {
        const user = await this.requireCustomer(transaction, principal);
        this.requireVerifiedPhone(principal, user);
        const partnerRef = this.db.collection("partners").doc(partnerId);
        const productRefs = requestedItems.map((item) =>
          this.db.collection("products").doc(item.productId),
        );
        const [partnerDoc, ...productDocs] = await Promise.all([
          transaction.get(partnerRef),
          ...productRefs.map((ref) => transaction.get(ref)),
        ]);
        const partner = partnerDoc.data();
        if (partner == null) {
          throw new CoreError("not-found", "Партнёр не найден.");
        }
        if (
          partner.isActive !== true ||
          partner.isOpen !== true ||
          partner.isPublished === false
        ) {
          throw new CoreError(
            "failed-precondition",
            "Партнёр сейчас недоступен.",
          );
        }
        if (partner.isTest === true || partner.isPreview === true) {
          throw new CoreError(
            "failed-precondition",
            "Тестовый каталог нельзя оформить.",
            {reason: "preview-blocked"},
          );
        }
        const snapshots: Data[] = [];
        const currentPrices: Record<string, number> = {};
        let subtotal = 0;
        for (let index = 0; index < requestedItems.length; index += 1) {
          const requested = requestedItems[index]!;
          const productDoc = productDocs[index]!;
          const product = productDoc.data();
          if (product == null) {
            throw new CoreError("not-found", "Один из товаров не найден.");
          }
          if (
            product.partnerId !== partnerId ||
            product.hidden === true ||
            product.isAvailable !== true ||
            product.isPublished === false ||
            product.isTest === true
          ) {
            throw new CoreError(
              "failed-precondition",
              "Некоторые товары сейчас недоступны.",
              {reason: "product-unavailable"},
            );
          }
          const price = Number(product.price);
          if (!Number.isFinite(price) || price < 0) {
            throw new CoreError(
              "failed-precondition",
              "Цена товара временно недоступна.",
            );
          }
          currentPrices[requested.productId] = price;
          const step = product.unit === "kg" ? 0.5 : 1;
          if (
            Math.abs(requested.quantity / step -
              Math.round(requested.quantity / step)) >
            0.000001
          ) {
            throw new CoreError(
              "invalid-argument",
              "Количество товара указано неверно.",
            );
          }
          if (
            typeof product.stockQuantity === "number" &&
            requested.quantity > product.stockQuantity
          ) {
            throw new CoreError(
              "failed-precondition",
              "Недостаточно товара в наличии.",
              {reason: "insufficient-stock"},
            );
          }
          const lineTotal = this.money(price * requested.quantity);
          subtotal = this.money(subtotal + lineTotal);
          snapshots.push({
            productId: requested.productId,
            name: product.name ?? "Товар",
            unit: product.unit ?? "item",
            unitPrice: price,
            quantity: requested.quantity,
            lineTotal,
          });
        }
        const changed = requestedItems.some(
          (item) =>
            currentPrices[item.productId] !== item.knownUnitPrice,
        );
        if (changed) {
          throw new CoreError(
            "failed-precondition",
            "Цены изменились. Проверьте обновлённую корзину.",
            {reason: "price-changed", currentPrices},
          );
        }
        const minimumOrder = Number(partner.minimumOrder ?? 0);
        if (subtotal < minimumOrder) {
          throw new CoreError(
            "failed-precondition",
            "Сумма заказа меньше минимальной.",
            {
              reason: "minimum-order",
              minimumOrder,
              subtotal,
            },
          );
        }
        const pickup = coordinateFromStored(partner.location);
        if (pickup == null) {
          throw new CoreError(
            "failed-precondition",
            "У партнёра не указана точка выдачи.",
          );
        }
        const distanceKm = haversineDistanceMeters(pickup, delivery) / 1000;
        const deliveryFee = Math.max(
          10,
          this.money(Number(partner.deliveryFee ?? 10)),
        );
        const total = this.money(subtotal + deliveryFee);
        const orderId = deterministicOrderId(
          principal.uid,
          "catalog",
          key,
        );
        const orderRef = this.db.collection("orders").doc(orderId);
        const existingOrder = await transaction.get(orderRef);
        if (existingOrder.exists) return {orderId, subtotal, deliveryFee, total};
        transaction.create(orderRef, {
          customerId: principal.uid,
          customerName: user.displayName ?? user.name ?? "Клиент",
          status: "waitingOffers",
          orderType: "catalogOrder",
          type: partner.category ?? "food",
          city: user.city ?? "Худжанд",
          fromText: partner.address ?? "Худжанд",
          toText: deliveryAddress,
          fromLocation: toGeoPoint(pickup),
          toLocation: toGeoPoint(delivery),
          partnerId,
          partnerName: partner.name ?? "Партнёр TajGo",
          partnerSnapshot: {
            id: partnerId,
            name: partner.name ?? "Партнёр TajGo",
            address: partner.address ?? "",
            category: partner.category ?? "food",
          },
          items: snapshots,
          subtotal,
          deliveryFee,
          total,
          price: deliveryFee,
          suggestedPrice: deliveryFee,
          clientPrice: deliveryFee,
          priceNegotiable: false,
          offersCount: 0,
          pricingVersion: "marketplace-server-v1.8",
          currency: "TJS",
          distanceKm: Number(distanceKm.toFixed(2)),
          etaMinutes: deliveryEtaMinutes(distanceKm),
          codeAvailable: true,
          ...(comment != null && comment.length > 0 ? {comment} : {}),
          declinedBy: [],
          isTestOrder: false,
          requestId: key,
          schemaVersion: 8,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        this.writeDeliverySecret(
          transaction,
          this.db.collection("order_secrets").doc(orderId),
          this.db.collection("order_customer_codes").doc(orderId),
          principal.uid,
          orderId,
          code,
          secret,
        );
        return {orderId, subtotal, deliveryFee, total};
      },
    );
  }

  async resetTestOrderForCourier(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    return this.runIdempotent(
      "resetTestOrderForCourier",
      principal,
      key,
      async (transaction) => {
        await this.requireCourier(transaction, principal);
        const courierRef = this.db
          .collection("couriers")
          .doc(principal.uid);
        const courierDoc = await transaction.get(courierRef);
        const courier = courierDoc.data();
        const orderId =
          typeof courier?.activeOrderId === "string"
            ? courier.activeOrderId
            : null;
        if (orderId == null) {
          throw new CoreError(
            "failed-precondition",
            "У курьера нет активного тестового заказа.",
          );
        }
        const orderRef = this.db.collection("orders").doc(orderId);
        const orderDoc = await transaction.get(orderRef);
        const order = orderDoc.data();
        if (
          order == null ||
          order.isTestOrder !== true ||
          order.courierId !== principal.uid
        ) {
          throw new CoreError(
            "permission-denied",
            "Сброс разрешён только для тестового заказа курьера.",
          );
        }
        transaction.update(courierRef, {
          activeOrderId: null,
          currentOrderId: null,
          isBusy: false,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.update(orderRef, {
          status: "waitingOffers",
          courierId: FieldValue.delete(),
          selectedCourierId: FieldValue.delete(),
          selectedOfferId: FieldValue.delete(),
          finalPrice: FieldValue.delete(),
          finalPriceLocked: FieldValue.delete(),
          acceptedAt: FieldValue.delete(),
          arrivedAtPickupAt: FieldValue.delete(),
          pickedUpAt: FieldValue.delete(),
          arrivedAtDropoffAt: FieldValue.delete(),
          deliveredAt: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {orderId, status: "waitingOffers"};
      },
    );
  }

  async adminCancelOrder(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const orderId = requiredString(data, "orderId", {max: 128});
    const reason = requiredString(data, "reason", {min: 3, max: 300});
    return this.runIdempotent(
      "adminCancelOrder",
      principal,
      key,
      async (transaction) => {
        await this.requireAdmin(transaction, principal);
        const orderRef = this.db.collection("orders").doc(orderId);
        const [orderDoc, pendingOffers] = await Promise.all([
          transaction.get(orderRef),
          transaction.get(
            orderRef.collection("offers").where("status", "==", "pending"),
          ),
        ]);
        const order = orderDoc.data();
        if (order == null) {
          throw new CoreError("not-found", "Заказ не найден.");
        }
        if (terminalOrderStatuses.has(String(order.status))) {
          throw new CoreError(
            "failed-precondition",
            "Завершённый заказ отменить нельзя.",
          );
        }
        const courierId =
          typeof order.courierId === "string" ? order.courierId : null;
        const courierRef =
          courierId == null
            ? null
            : this.db.collection("couriers").doc(courierId);
        if (courierRef != null) await transaction.get(courierRef);
        for (const offer of pendingOffers.docs) {
          transaction.update(offer.ref, {
            status: "rejected",
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        transaction.update(orderRef, {
          status: "cancelled",
          offersCount: 0,
          cancelledAt: FieldValue.serverTimestamp(),
          cancelledReason: reason,
          resolvedBy: principal.uid,
          resolvedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        this.deleteDeliverySecret(transaction, orderId);
        if (courierRef != null) {
          transaction.update(courierRef, {
            activeOrderId: null,
            currentOrderId: null,
            isBusy: false,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        this.writeAdminLog(transaction, principal.uid, {
          action: "adminCancelOrder",
          orderId,
          courierId,
          reason,
        });
        return {orderId, status: "cancelled"};
      },
    );
  }

  async adminReleaseCourier(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const courierId = requiredString(data, "courierId", {max: 128});
    const resolution =
      optionalString(data, "resolution", 40) ?? "returnToWaiting";
    const reason =
      optionalString(data, "reason", 300) ?? "admin release";
    if (!new Set(["returnToWaiting", "cancel", "releaseTerminal"]).has(resolution)) {
      throw new CoreError("invalid-argument", "Неизвестный вариант решения.");
    }
    return this.runIdempotent(
      "adminReleaseCourier",
      principal,
      key,
      async (transaction) => {
        await this.requireAdmin(transaction, principal);
        const courierRef = this.db.collection("couriers").doc(courierId);
        const courierDoc = await transaction.get(courierRef);
        const courier = courierDoc.data();
        if (courier == null) {
          throw new CoreError("not-found", "Курьер не найден.");
        }
        const orderId =
          typeof courier.activeOrderId === "string"
            ? courier.activeOrderId
            : null;
        const orderRef =
          orderId == null ? null : this.db.collection("orders").doc(orderId);
        const orderDoc =
          orderRef == null ? null : await transaction.get(orderRef);
        const order = orderDoc?.data();
        if (
          resolution === "releaseTerminal" &&
          order != null &&
          activeDeliveryStatuses.has(String(order.status))
        ) {
          throw new CoreError(
            "failed-precondition",
            "Активный заказ нужно вернуть в ленту или отменить.",
          );
        }
        transaction.update(courierRef, {
          activeOrderId: null,
          currentOrderId: null,
          isBusy: false,
          updatedAt: FieldValue.serverTimestamp(),
        });
        if (orderRef != null && order != null) {
          if (resolution === "returnToWaiting") {
            transaction.update(orderRef, {
              status: "waitingOffers",
              courierId: FieldValue.delete(),
              selectedCourierId: FieldValue.delete(),
              selectedOfferId: FieldValue.delete(),
              finalPrice: FieldValue.delete(),
              finalPriceLocked: FieldValue.delete(),
              acceptedAt: FieldValue.delete(),
              arrivedAtPickupAt: FieldValue.delete(),
              pickedUpAt: FieldValue.delete(),
              arrivedAtDropoffAt: FieldValue.delete(),
              deliveredAt: FieldValue.delete(),
              disputedAt: FieldValue.delete(),
              offersCount: 0,
              updatedAt: FieldValue.serverTimestamp(),
            });
          } else if (resolution === "cancel") {
            transaction.update(orderRef, {
              status: "cancelled",
              cancelledAt: FieldValue.serverTimestamp(),
              cancelledReason: reason,
              resolvedBy: principal.uid,
              resolvedAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            });
            this.deleteDeliverySecret(transaction, orderRef.id);
          }
        }
        this.writeAdminLog(transaction, principal.uid, {
          action: "adminReleaseCourier",
          orderId,
          courierId,
          reason,
          resolution,
        });
        return {courierId, orderId, resolution};
      },
    );
  }

  async adminResolveDispute(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const orderId = requiredString(data, "orderId", {max: 128});
    const resolution = requiredString(data, "resolution", {max: 40});
    const reason = requiredString(data, "reason", {min: 3, max: 300});
    if (
      !new Set([
        "complete",
        "cancel",
        "returnToWaiting",
        "markDisputed",
      ]).has(resolution)
    ) {
      throw new CoreError("invalid-argument", "Неизвестный вариант решения.");
    }
    return this.runIdempotent(
      "adminResolveDispute",
      principal,
      key,
      async (transaction) => {
        await this.requireAdmin(transaction, principal);
        const orderRef = this.db.collection("orders").doc(orderId);
        const orderDoc = await transaction.get(orderRef);
        const order = orderDoc.data();
        if (order == null) {
          throw new CoreError("not-found", "Заказ не найден.");
        }
        if (terminalOrderStatuses.has(String(order.status))) {
          throw new CoreError(
            "failed-precondition",
            "Terminal-заказ повторно изменить нельзя.",
          );
        }
        const courierId =
          typeof order.courierId === "string" ? order.courierId : null;
        const courierRef =
          courierId == null
            ? null
            : this.db.collection("couriers").doc(courierId);
        if (courierRef != null) await transaction.get(courierRef);
        if (resolution === "markDisputed") {
          transaction.update(orderRef, {
            status: "disputed",
            disputedAt: FieldValue.serverTimestamp(),
            adminNote: reason,
            updatedAt: FieldValue.serverTimestamp(),
          });
        } else if (resolution === "complete") {
          if (courierRef == null) {
            throw new CoreError("failed-precondition", "Курьер не назначен.");
          }
          this.completeOrder(
            transaction,
            orderRef,
            courierRef,
            order,
            "admin",
            principal.uid,
          );
        } else if (resolution === "cancel") {
          transaction.update(orderRef, {
            status: "cancelled",
            cancelledAt: FieldValue.serverTimestamp(),
            cancelledReason: reason,
            resolvedBy: principal.uid,
            resolvedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          this.deleteDeliverySecret(transaction, orderId);
          if (courierRef != null) {
            transaction.update(courierRef, {
              activeOrderId: null,
              currentOrderId: null,
              isBusy: false,
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
        } else {
          transaction.update(orderRef, {
            status: "waitingOffers",
            courierId: FieldValue.delete(),
            selectedCourierId: FieldValue.delete(),
            selectedOfferId: FieldValue.delete(),
            finalPrice: FieldValue.delete(),
            finalPriceLocked: FieldValue.delete(),
            acceptedAt: FieldValue.delete(),
            arrivedAtPickupAt: FieldValue.delete(),
            pickedUpAt: FieldValue.delete(),
            arrivedAtDropoffAt: FieldValue.delete(),
            deliveredAt: FieldValue.delete(),
            disputedAt: FieldValue.delete(),
            resolvedBy: principal.uid,
            resolvedAt: FieldValue.serverTimestamp(),
            offersCount: 0,
            updatedAt: FieldValue.serverTimestamp(),
          });
          if (courierRef != null) {
            transaction.update(courierRef, {
              activeOrderId: null,
              currentOrderId: null,
              isBusy: false,
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
        }
        this.writeAdminLog(transaction, principal.uid, {
          action: "adminResolveDispute",
          orderId,
          courierId,
          reason,
          resolution,
        });
        return {
          orderId,
          resolution,
          status:
            resolution === "complete"
              ? "completed"
              : resolution === "cancel"
                ? "cancelled"
                : resolution === "returnToWaiting"
                  ? "waitingOffers"
                  : "disputed",
        };
      },
    );
  }

  async adminSetOrderNote(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const orderId = requiredString(data, "orderId", {max: 128});
    const note = requiredString(data, "note", {min: 1, max: 500});
    return this.runIdempotent(
      "adminSetOrderNote",
      principal,
      key,
      async (transaction) => {
        await this.requireAdmin(transaction, principal);
        const orderRef = this.db.collection("orders").doc(orderId);
        const orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) {
          throw new CoreError("not-found", "Заказ не найден.");
        }
        transaction.update(orderRef, {
          adminNote: note,
          updatedAt: FieldValue.serverTimestamp(),
        });
        this.writeAdminLog(transaction, principal.uid, {
          action: "adminSetOrderNote",
          orderId,
          details: note,
        });
        return {orderId};
      },
    );
  }

  async adminMigrateLegacyDeliveryCode(
    context: CommandContext,
  ): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const orderId = requiredString(data, "orderId", {max: 128});
    return this.runIdempotent(
      "adminMigrateLegacyDeliveryCode",
      principal,
      key,
      async (transaction) => {
        await this.requireAdmin(transaction, principal);
        const orderRef = this.db.collection("orders").doc(orderId);
        const secretRef = this.db.collection("order_secrets").doc(orderId);
        const codeRef = this.db
          .collection("order_customer_codes")
          .doc(orderId);
        const [orderDoc, secretDoc] = await Promise.all([
          transaction.get(orderRef),
          transaction.get(secretRef),
        ]);
        const order = orderDoc.data();
        if (order == null) {
          throw new CoreError("not-found", "Заказ не найден.");
        }
        if (
          typeof order.confirmationCode !== "string" &&
          secretDoc.exists
        ) {
          return {orderId, migrated: false, alreadySecure: true};
        }
        const code = String(order.confirmationCode ?? "");
        if (!/^\d{4}$/.test(code)) {
          throw new CoreError(
            "failed-precondition",
            "В заказе нет корректного legacy-кода для миграции.",
          );
        }
        const customerId =
          typeof order.customerId === "string" ? order.customerId : null;
        if (customerId == null) {
          throw new CoreError(
            "failed-precondition",
            "У заказа не указан клиент.",
          );
        }
        const secret = hashDeliveryCode(code);
        transaction.set(secretRef, {
          orderId,
          customerId,
          salt: secret.salt,
          hash: secret.hash,
          failedAttempts: 0,
          locked: false,
          migratedAt: FieldValue.serverTimestamp(),
        });
        transaction.set(codeRef, {
          orderId,
          customerId,
          code,
          migratedAt: FieldValue.serverTimestamp(),
        });
        transaction.update(orderRef, {
          confirmationCode: FieldValue.delete(),
          codeAvailable: true,
          schemaVersion: 8,
          updatedAt: FieldValue.serverTimestamp(),
        });
        this.writeAdminLog(transaction, principal.uid, {
          action: "adminMigrateLegacyDeliveryCode",
          orderId,
        });
        return {orderId, migrated: true};
      },
    );
  }

  /**
   * Self-service account deletion. Anonymizes the user's identity and courier
   * presence, records an audit-ready deletion request, and best-effort deletes
   * the Firebase Auth user. Blocked while any order is still active. Mandatory
   * operational history (orders, disputes) is retained but detached from PII.
   */
  async deleteAccountRequest(context: CommandContext): Promise<Result> {
    const {principal, data} = context;
    const key = requiredIdempotencyKey(data);
    const reason = optionalString(data, "reason", 300);
    const activeStatuses = [
      ...waitingOrderStatuses,
      ...activeDeliveryStatuses,
    ];
    const result = await this.runIdempotent(
      "deleteAccountRequest",
      principal,
      key,
      async (transaction) => {
        const userRef = this.db.collection("users").doc(principal.uid);
        const courierRef = this.db.collection("couriers").doc(principal.uid);
        const courierPublicRef = this.db
          .collection("courier_public")
          .doc(principal.uid);
        const deletionRef = this.db
          .collection("account_deletion_requests")
          .doc(principal.uid);

        // Reads first (transaction contract): profile, courier, active orders.
        const [userDoc, courierDoc, activeOrders] = await Promise.all([
          transaction.get(userRef),
          transaction.get(courierRef),
          transaction.get(
            this.db
              .collection("orders")
              .where("customerId", "==", principal.uid)
              .where("status", "in", activeStatuses)
              .limit(1),
          ),
        ]);

        const user = userDoc.data();
        if (user == null || user.deleted === true) {
          throw new CoreError(
            "failed-precondition",
            "Аккаунт уже удалён или не найден.",
          );
        }
        if (!activeOrders.empty) {
          throw new CoreError(
            "failed-precondition",
            "Сначала завершите активный заказ.",
            {reason: "active-order"},
          );
        }
        const courier = courierDoc.data();
        if (
          courier != null &&
          (courier.activeOrderId != null || courier.isBusy === true)
        ) {
          throw new CoreError(
            "failed-precondition",
            "Сначала завершите активную доставку.",
            {reason: "active-order"},
          );
        }

        const anonymizedCategories = ["profile", "courier-presence"];
        transaction.set(
          userRef,
          {
            displayName: "Удалённый пользователь",
            name: "Удалённый пользователь",
            phoneNumber: null,
            phoneVerified: false,
            role: "deleted",
            roles: [],
            lastMode: "customer",
            selectedRole: "customer",
            targetRole: "customer",
            courierStatus: "none",
            deleted: true,
            deletedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        if (courierDoc.exists) {
          transaction.set(
            courierRef,
            {
              displayName: "Удалённый курьер",
              name: "Удалённый курьер",
              phoneNumber: null,
              isOnline: false,
              online: false,
              deleted: true,
              deletedAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            },
            {merge: true},
          );
          transaction.delete(courierPublicRef);
        }

        transaction.set(deletionRef, {
          uid: principal.uid,
          status: "completed",
          method: "in-app",
          ...(reason != null ? {reason} : {}),
          anonymizedCategories,
          retainedCategories: [
            "order-history-anonymized",
            "disputes",
            "operational-records",
          ],
          requestedAt: FieldValue.serverTimestamp(),
          completedAt: FieldValue.serverTimestamp(),
        });

        this.writeAdminLog(transaction, principal.uid, {
          action: "account.delete.self",
          entityType: "user",
          entityId: principal.uid,
          anonymizedCategories,
        });

        return {status: "deleted", anonymizedCategories};
      },
    );

    // Best-effort: remove the Firebase Auth identity so sign-in is no longer
    // possible. Failure here does not undo the committed anonymization.
    await this.deleteAuthUser(principal.uid);
    return result;
  }

  private async deleteAuthUser(uid: string): Promise<void> {
    try {
      await this.authDeleter(uid);
    } catch (_) {
      // Auth identity may already be gone, or Auth is unavailable in this
      // environment; anonymized Firestore state is the authoritative outcome.
    }
  }

  private async runIdempotent(
    command: string,
    principal: Principal,
    key: string,
    action: (transaction: Transaction) => Promise<Result>,
  ): Promise<Result> {
    const id = commandDocumentId(principal.uid, command, key);
    const ref = this.db.collection("command_results").doc(id);
    return this.db.runTransaction(async (transaction) => {
      const existing = await transaction.get(ref);
      if (existing.exists) {
        const data = existing.data() ?? {};
        if (
          data.ownerId !== principal.uid ||
          data.command !== command
        ) {
          throw new CoreError(
            "already-exists",
            "Ключ запроса уже использован.",
          );
        }
        return asRecord(data.result ?? {});
      }
      const result = await action(transaction);
      transaction.create(ref, {
        ownerId: principal.uid,
        command,
        keyHash: id,
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  }

  private async requireCustomer(
    transaction: Transaction,
    principal: Principal,
  ): Promise<Data> {
    const userRef = this.db.collection("users").doc(principal.uid);
    const userDoc = await transaction.get(userRef);
    const user = userDoc.data();
    if (user == null || user.role !== "customer") {
      throw new CoreError(
        "permission-denied",
        "Действие доступно только клиенту.",
      );
    }
    return user;
  }

  private async requireCourier(
    transaction: Transaction,
    principal: Principal,
  ): Promise<Data> {
    const userRef = this.db.collection("users").doc(principal.uid);
    const userDoc = await transaction.get(userRef);
    const user = userDoc.data();
    const roles = Array.isArray(user?.roles) ? user.roles : [];
    if (
      user == null ||
      user.role !== "courier" ||
      user.courierStatus !== "approved" ||
      !roles.includes("courier")
    ) {
      throw new CoreError(
        "permission-denied",
        "Действие доступно только одобренному курьеру.",
      );
    }
    return user;
  }

  private async requireAdmin(
    transaction: Transaction,
    principal: Principal,
  ): Promise<Data> {
    const userRef = this.db.collection("users").doc(principal.uid);
    const userDoc = await transaction.get(userRef);
    const user = userDoc.data();
    if (principal.token.admin !== true && user?.role !== "admin") {
      throw new CoreError(
        "permission-denied",
        "Действие доступно только администратору.",
      );
    }
    return user ?? {};
  }

  private requireVerifiedPhone(principal: Principal, user: Data): void {
    if (
      typeof principal.token.phone_number !== "string" &&
      user.phoneVerified !== true
    ) {
      throw new CoreError(
        "failed-precondition",
        "Подтвердите номер телефона.",
      );
    }
  }

  private writeDeliverySecret(
    transaction: Transaction,
    secretRef: DocumentReference,
    codeRef: DocumentReference,
    customerId: string,
    orderId: string,
    code: string,
    secret: {salt: string; hash: string},
  ): void {
    transaction.create(secretRef, {
      orderId,
      customerId,
      salt: secret.salt,
      hash: secret.hash,
      failedAttempts: 0,
      locked: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.create(codeRef, {
      orderId,
      customerId,
      code,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  private completeOrder(
    transaction: Transaction,
    orderRef: DocumentReference,
    courierRef: DocumentReference,
    order: Data,
    method: "code" | "customer" | "admin",
    adminId?: string,
  ): void {
    const earning = Number(order.finalPrice ?? order.price ?? 0);
    transaction.update(orderRef, {
      status: "completed",
      completedAt: FieldValue.serverTimestamp(),
      completionMethod: method,
      ...(adminId != null
        ? {
            manuallyCompletedBy: adminId,
            resolvedBy: adminId,
            resolvedAt: FieldValue.serverTimestamp(),
          }
        : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(courierRef, {
      activeOrderId: null,
      currentOrderId: null,
      isBusy: false,
      earningsToday: FieldValue.increment(earning),
      ordersToday: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    });
    this.deleteDeliverySecret(transaction, orderRef.id);
  }

  private deleteDeliverySecret(
    transaction: Transaction,
    orderId: string,
  ): void {
    transaction.delete(this.db.collection("order_secrets").doc(orderId));
    transaction.delete(
      this.db.collection("order_customer_codes").doc(orderId),
    );
  }

  private orderCourierId(order: Data): string {
    if (typeof order.courierId !== "string" || order.courierId.length === 0) {
      throw new CoreError("failed-precondition", "Курьер не назначен.");
    }
    return order.courierId;
  }

  private writeAdminLog(
    transaction: Transaction,
    adminId: string,
    data: Data,
  ): void {
    transaction.create(this.db.collection("admin_logs").doc(), {
      ...data,
      adminId,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  private money(value: number): number {
    return Math.round((value + Number.EPSILON) * 100) / 100;
  }
}
