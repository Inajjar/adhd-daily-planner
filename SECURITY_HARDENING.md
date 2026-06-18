# Security hardening

## What changed

- Premium AI Firebase callables now require:
  - authenticated Firebase user
  - valid Firebase App Check token
  - active RevenueCat entitlement verified on the server
- The client can no longer write `premium` or related verification fields into Firestore.
- Remote Config bypass for subscription enforcement was removed.

## Required setup

### 1. Add RevenueCat secret to Firebase Functions

Set the RevenueCat secret key used for server-side entitlement checks:

```bash
firebase functions:secrets:set REVENUECAT_SECRET_KEY
```

Use the RevenueCat secret API key, not the public SDK key.

### 2. Deploy Functions

```bash
cd firebase/functions
npm run lint
firebase deploy --only functions
```

### 3. Enable App Check enforcement

In Firebase console, enable App Check enforcement for:

- Cloud Functions
- Firestore
- Authentication

For iOS, register the app with App Attest or DeviceCheck in App Check.

## Important note about `GoogleService-Info.plist`

`GoogleService-Info.plist` is not a secret. It identifies your Firebase app, so it should be treated as public metadata.

The real protection must be:

- server-side subscription verification
- Firebase Auth checks
- App Check enforcement
- strict Firestore rules

Without those controls, someone could reuse your Firebase project configuration from another client.
