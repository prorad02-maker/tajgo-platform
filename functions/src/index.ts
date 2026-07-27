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
import {CoreError, Principal, asRecord} from "./domain";

initializeApp();
setGlobalOptions({
  region: "europe-west1",
  maxInstances: 20,
  memory: "256MiB",
  timeoutSeconds: 30,
});

const core = new TajGoAuthoritativeCore(getFirestore());

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
          actorId: request.auth.uid,
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

// FCM Firestore triggers (privacy-safe payloads). Inactive until owner deploy.
export {onOrderStatusChanged, onOfferCreated} from "./notifications";
