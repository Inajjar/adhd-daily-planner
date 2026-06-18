"use strict";

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {refreshPremiumStatus} = require("../security/premiumAccess");

const REVENUECAT_SECRET_KEY = defineSecret("REVENUECAT_SECRET_KEY");

exports.refreshPremiumStatus = onCall(
    {
      region: "us-central1",
      cors: true,
      enforceAppCheck: true,
      secrets: [REVENUECAT_SECRET_KEY],
    },
    async (request) => {
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Authentication required.");
      }

      const revenueCatSecretKey = REVENUECAT_SECRET_KEY.value();
      if (!revenueCatSecretKey) {
        throw new HttpsError(
            "failed-precondition",
            "REVENUECAT_SECRET_KEY missing.",
        );
      }

      const status = await refreshPremiumStatus(uid, revenueCatSecretKey);
      return {
        isPremium: status.isPremium,
        expiresAt: status.expiresAt instanceof Date ?
          status.expiresAt.toISOString() :
          null,
      };
    },
);
