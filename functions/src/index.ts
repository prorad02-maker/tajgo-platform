import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {
  CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2/options";
import {TajGoAuthoritativeCore} from "./core";
import {CoreError, Principal, asRecord, parseCoordinate, assertOnlyKeys} from "./domain";
import {createSharedRoadRoutes} from "./shared_road_routes";
import {detectServiceCity} from "./pricing";

initializeApp();
setGlobalOptions({
  region: "europe-west1",
  maxInstances: 5,
  memory: "256MiB",
  timeoutSeconds: 30,
});

const roadRoutes = process.env.FUNCTIONS_EMULATOR === "true" ? async () => null : createSharedRoadRoutes(getFirestore());
const core = new TajGoAuthoritativeCore(getFirestore(), undefined, undefined, undefined, roadRoutes);

type Handler = (context: {
  principal: Principal;
  data: Record<string, unknown>;
}) => Promise<Record<string, unknown>>;

function command(name: string, handler: Handler) {
  return onCall(
    {
      enforceAppCheck: false,
      consumeAppCheckToken: false,
      cors: true,
      concurrency: 8,
    },
    async (request: CallableRequest<unknown>) => {
      if (request.auth == null) {
        throw new HttpsError("unauthenticated", "Сначала войдите в TajGo.");
      }
      const principal: Principal = {
        uid: request.auth.uid,
        token: request.auth.token as unknown as Record<string, unknown>,
      };
      try {
        return await handler({
          principal,
          data: asRecord(request.data),
        });
      } catch (error) {
        if (error instanceof CoreError) {
          throw new HttpsError(error.code, error.message, error.details);
        }
        logger.error("Unexpected authoritative command failure", {
          command: name,
          errorType: error instanceof Error ? error.name : typeof error,
        });
        throw new HttpsError(
          "aborted",
          "Операция временно недоступна. Повторите запрос.",
        );
      }
    },
  );
}

export const ensureUserProfile = command(
  "ensureUserProfile",
  (context) => core.ensureUserProfile(context),
);

export const completeUserProfile = command(
  "completeUserProfile",
  (context) => core.completeUserProfile(context),
);

export const switchAccountMode = command(
  "switchAccountMode",
  (context) => core.switchAccountMode(context),
);

export const completeCourierOnboarding = command(
  "completeCourierOnboarding",
  (context) => core.completeCourierOnboarding(context),
);

export const ensureCourierProfile = command(
  "ensureCourierProfile",
  (context) => core.ensureCourierProfile(context),
);

export const createCustomDeliveryOrder = command(
  "createCustomDeliveryOrder",
  (context) => core.createCustomDeliveryOrder(context),
);

export const submitCourierOffer = command(
  "submitCourierOffer",
  (context) => core.submitCourierOffer(context),
);

export const updateCourierOffer = command(
  "updateCourierOffer",
  (context) => core.updateCourierOffer(context),
);

export const withdrawCourierOffer = command(
  "withdrawCourierOffer",
  (context) => core.withdrawCourierOffer(context),
);

export const rejectCourierOffer = command(
  "rejectCourierOffer",
  (context) => core.rejectCourierOffer(context),
);

export const selectCourierOffer = command(
  "selectCourierOffer",
  (context) => core.selectCourierOffer(context),
);

export const cancelWaitingOrder = command(
  "cancelWaitingOrder",
  (context) => core.cancelWaitingOrder(context),
);

export const updateDeliveryStatus = command(
  "updateDeliveryStatus",
  (context) => core.updateDeliveryStatus(context),
);

export const completeDeliveryWithCode = command(
  "completeDeliveryWithCode",
  (context) => core.completeDeliveryWithCode(context),
);

export const createCatalogOrder = command(
  "createCatalogOrder",
  (context) => core.createCatalogOrder(context),
);

export const cancelCatalogOrder = command(
  "cancelCatalogOrder",
  (context) => core.cancelCatalogOrder(context),
);

export const resetTestOrderForCourier = command(
  "resetTestOrderForCourier",
  (context) => core.resetTestOrderForCourier(context),
);

export const getDeliveryQuote = command(
  "getDeliveryQuote",
  (context) => core.getDeliveryQuote(context),
);
export const getRoadRoute = command("getRoadRoute", async ({data}) => {
// Route geometry and participant contacts are returned only to authenticated clients.
  assertOnlyKeys(data, new Set(["pickup", "dropoff", "transportMode"]));
  const pickup = parseCoordinate(data.pickup, "pickup");
  const dropoff = parseCoordinate(data.dropoff, "dropoff");
  const cityId = detectServiceCity(pickup);
  if (!cityId || detectServiceCity(dropoff) !== cityId) throw new CoreError("failed-precondition", "Выберите точки в одной зоне доставки.");
  const mode = data.transportMode;
  if (mode !== "bicycle" && mode !== "scooter" && mode !== "driving") throw new CoreError("invalid-argument", "Проверьте тип транспорта.");
  const route = await roadRoutes({pickup, dropoff, cityId, transportMode: mode});
  if (!route) throw new CoreError("aborted", "Дорожный маршрут временно недоступен. Повторите попытку.");
  return {...route};
});

export const getOrderContact = command("getOrderContact", context => core.getOrderContact(context));

export const adminApproveCourier = command(
  "adminApproveCourier",
  (context) => core.adminApproveCourier(context),
);

export const adminRejectCourier = command(
  "adminRejectCourier",
  (context) => core.adminRejectCourier(context),
);

export const adminSuspendCourier = command(
  "adminSuspendCourier",
  (context) => core.adminSuspendCourier(context),
);

export const adminRestoreCourier = command(
  "adminRestoreCourier",
  (context) => core.adminRestoreCourier(context),
);

export const deleteAccountRequest = command(
  "deleteAccountRequest",
  (context) => core.deleteAccountRequest(context),
);

export const acceptLegalDocuments = command(
  "acceptLegalDocuments",
  (context) => core.acceptLegalDocuments(context),
);

export const saveMerchantApplicationDraft = command(
  "saveMerchantApplicationDraft",
  (context) => core.saveMerchantApplicationDraft(context),
);

export const submitMerchantApplication = command(
  "submitMerchantApplication",
  (context) => core.submitMerchantApplication(context),
);

export const updateMerchantApplication = command(
  "updateMerchantApplication",
  (context) => core.updateMerchantApplication(context),
);

export const withdrawMerchantApplication = command(
  "withdrawMerchantApplication",
  (context) => core.withdrawMerchantApplication(context),
);

export const adminReviewMerchantApplication = command(
  "adminReviewMerchantApplication",
  (context) => core.adminReviewMerchantApplication(context),
);

export const adminConvertMerchantApplication = command(
  "adminConvertMerchantApplication",
  (context) => core.adminConvertMerchantApplication(context),
);

export const adminSavePartner = command(
  "adminSavePartner",
  (context) => core.adminSavePartner(context),
);

export const adminSaveProduct = command(
  "adminSaveProduct",
  (context) => core.adminSaveProduct(context),
);

export const adminImportCatalog = command(
  "adminImportCatalog",
  (context) => core.adminImportCatalog(context),
);

export const adminSetCourierOffline = command(
  "adminSetCourierOffline",
  (context) => core.adminSetCourierOffline(context),
);

export const adminCancelOrder = command(
  "adminCancelOrder",
  (context) => core.adminCancelOrder(context),
);

export const adminReleaseCourier = command(
  "adminReleaseCourier",
  (context) => core.adminReleaseCourier(context),
);

export const adminResolveDispute = command(
  "adminResolveDispute",
  (context) => core.adminResolveDispute(context),
);

export const adminSetOrderNote = command(
  "adminSetOrderNote",
  (context) => core.adminSetOrderNote(context),
);

export const adminMigrateLegacyDeliveryCode = command(
  "adminMigrateLegacyDeliveryCode",
  (context) => core.adminMigrateLegacyDeliveryCode(context),
);

// Notification triggers live in the separate notifications codebase. Keeping
// one sender prevents duplicate delivery and avoids the old per-user token path.
