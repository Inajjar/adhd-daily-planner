# ADHD Daily Planner

ADHD-first daily planner for iOS, built with Flutter.

## Product direction

ADHD Daily Planner is designed around three tabs only:

- `Today`
- `Routines`
- `Settings`

The MVP includes:

- high-conversion onboarding
- Today screen with progress, quick add, Start My Day, Overwhelm Mode
- Focus Mode fullscreen timer
- Routines loading into Today
- Brain Dump sheet that turns messy input into a short plan
- separated `firebase` and `revenuecat` folders for future production wiring

## Structure

- `lib/features/` app screens and flows
- `lib/state/` app state and local logic
- `lib/firebase/` Firebase client integration for auth, firestore, and remote config
- `firebase/functions/` Firebase Functions backend for premium AI
- `firebase/remote_config/` Firebase Remote Config template
- `lib/revenuecat/` RevenueCat config and service placeholders

## Firebase setup

Firebase code is organized in:

- `lib/firebase/core/`
- `lib/firebase/auth/`
- `lib/firebase/firestore/`
- `lib/firebase/remote_config/`

1. Add your real `GoogleService-Info.plist` into `ios/Runner/`.
2. Toggle Firebase in [lib/firebase/core/firebase_config.dart](/Users/adaminajjar/Desktop/app%20mobile/cueday/lib/firebase/core/firebase_config.dart:1).
3. Bootstrap runs from [lib/firebase/core/firebase_bootstrap.dart](/Users/adaminajjar/Desktop/app%20mobile/cueday/lib/firebase/core/firebase_bootstrap.dart:1).
4. Firestore sync for `users`, `tasks`, `routines`, and `focus_sessions` is handled in [lib/firebase/firestore/firebase_firestore_service.dart](/Users/adaminajjar/Desktop/app%20mobile/cueday/lib/firebase/firestore/firebase_firestore_service.dart:1).

## RevenueCat setup

1. Put your public Apple SDK key in [lib/revenuecat/revenuecat_config.dart](/Users/adaminajjar/Desktop/app%20mobile/cueday/lib/revenuecat/revenuecat_config.dart:1).
2. Set `enabled: true`.
3. Replace `premium` with your real entitlement id if needed.

## Run

```bash
cd adhd-daily-planner
flutter pub get
flutter run
```
