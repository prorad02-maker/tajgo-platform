# TajGo 1.8.0+31 — Part 1 Release Notes

## Added

- TypeScript authoritative Cloud Functions core.
- Server radius `< 1000 m`, GPS freshness/accuracy and busy checks.
- Transactional offers and one-active-order enforcement.
- Idempotency ledger for critical commands.
- Secure delivery code split with scrypt hash and attempt limit.
- Authoritative catalog price/total validation.
- Deny-by-default Firestore Rules and semantic emulator tests.
- Protected admin startup route plus offers, disputes, settings and audit log entries.
- Owner scripts for environment, emulators, tests, build, install and confirmed deploy.

## Changed

- Flutter repositories use callable Functions for critical order/offer/status/catalog/admin operations.
- Firestore role overrides local mode cache at startup.
- Preview/test checkout is blocked both in Flutter and backend.
- Customer reads delivery code from a customer-only document.
- Version is `1.8.0+31`.

## Compatibility

Legacy order statuses remain readable. Legacy open delivery codes require the documented admin migration before new Rules are deployed. Existing catalog documents need publication flags (`isTest`, `isPreview`, `isPublished`; products also `isAvailable`, `hidden`) to appear in the hardened public queries.

## Deployment

No Firebase deploy, git push or production tag is part of this change. The APK cannot execute new critical flows against production until Functions, indexes and Rules are deployed in the documented order.

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`

SHA-256: `05ABDC20BC5B2056140351FFB7E83D0A37647E059FE35C3E0C624E1A4F31508D`
