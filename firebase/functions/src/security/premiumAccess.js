"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const REVENUECAT_API_BASE_URL = "https://api.revenuecat.com/v1";
const ENTITLEMENT_ID = "ADHD_Daily_Pro";
const PREMIUM_STATUS_CACHE_TTL_MS = 30 * 1000;
const PREMIUM_FUNCTION_MIN_INTERVAL_MS = 5 * 1000;

function parseRevenueCatDate(value) {
  if (!value || typeof value !== "string") {
    return null;
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return parsed;
}

async function readStoredPremiumStatus(uid) {
  const snapshot = await getFirestore().collection("users").doc(uid).get();
  if (!snapshot.exists) {
    return null;
  }

  const data = snapshot.data() || {};
  return {
    isPremium: data.premium === true,
    expiresAt: data.premiumExpiresAt?.toDate?.() ?? null,
    checkedAt: data.premiumCheckedAt?.toDate?.() ?? null,
  };
}

async function persistPremiumStatus(uid, {isPremium, expiresAt}) {
  const payload = {
    premium: isPremium,
    premiumCheckedAt: FieldValue.serverTimestamp(),
    premiumSource: "revenuecat",
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (expiresAt instanceof Date) {
    payload.premiumExpiresAt = expiresAt;
  } else {
    payload.premiumExpiresAt = FieldValue.delete();
  }

  await getFirestore().collection("users").doc(uid).set(payload, {merge: true});
}

async function fetchRevenueCatSubscriber(uid, revenueCatSecretKey) {
  const response = await fetch(
      `${REVENUECAT_API_BASE_URL}/subscribers/${encodeURIComponent(uid)}`,
      {
        method: "GET",
        headers: {
          Authorization: `Bearer ${revenueCatSecretKey}`,
          "Content-Type": "application/json",
        },
      },
  );

  if (!response.ok) {
    const body = await response.text();
    throw new HttpsError(
        "internal",
        `RevenueCat lookup failed with status ${response.status}: ${body}`,
    );
  }

  return response.json();
}

function resolvePremiumStatus(revenueCatPayload) {
  const subscriber = revenueCatPayload?.subscriber;
  const entitlement = subscriber?.entitlements?.[ENTITLEMENT_ID];
  const expiresAt = parseRevenueCatDate(
      entitlement?.expires_date ?? subscriber?.original_purchase_date,
  );

  const isPremium = entitlement?.product_identifier != null &&
    (entitlement?.expires_date == null ||
      (expiresAt instanceof Date && expiresAt.getTime() > Date.now()));

  return {
    isPremium,
    expiresAt,
  };
}

async function assertPremiumAccess(uid, revenueCatSecretKey) {
  const premiumStatus = await getPremiumStatusForProtectedCall(
      uid,
      revenueCatSecretKey,
  );
  if (!premiumStatus.isPremium) {
    throw new HttpsError(
        "permission-denied",
        "An active premium subscription is required.",
    );
  }

  return premiumStatus;
}

async function refreshPremiumStatus(uid, revenueCatSecretKey) {
  const payload = await fetchRevenueCatSubscriber(uid, revenueCatSecretKey);
  const premiumStatus = resolvePremiumStatus(payload);
  await persistPremiumStatus(uid, premiumStatus);
  return premiumStatus;
}

async function getPremiumStatusForProtectedCall(uid, revenueCatSecretKey) {
  const storedStatus = await readStoredPremiumStatus(uid);
  const checkedAt = storedStatus?.checkedAt;
  if (
    storedStatus != null &&
    checkedAt instanceof Date &&
    Date.now() - checkedAt.getTime() <= PREMIUM_STATUS_CACHE_TTL_MS
  ) {
    return {
      isPremium: storedStatus.isPremium,
      expiresAt: storedStatus.expiresAt,
    };
  }

  return refreshPremiumStatus(uid, revenueCatSecretKey);
}

async function assertPremiumFunctionRateLimit(uid) {
  const userRef = getFirestore().collection("users").doc(uid);

  await getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(userRef);
    const data = snapshot.data() || {};
    const lastCalledAt = data.lastPremiumFunctionCallAt?.toDate?.();

    if (
      lastCalledAt instanceof Date &&
      Date.now() - lastCalledAt.getTime() < PREMIUM_FUNCTION_MIN_INTERVAL_MS
    ) {
      throw new HttpsError(
          "resource-exhausted",
          "Please wait a few seconds before using another premium action.",
      );
    }

    transaction.set(
        userRef,
        {
          lastPremiumFunctionCallAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  });
}

module.exports = {
  assertPremiumAccess,
  assertPremiumFunctionRateLimit,
  refreshPremiumStatus,
};
