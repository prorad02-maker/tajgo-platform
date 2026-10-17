# TajGo v1.8 Part 1 — Test Plan

## Автоматические проверки

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug

cd functions
npm ci
npm run lint
npm run build
npm test
npm run test:rules
npm run test:functions
```

Functions integration запускается через Firestore + Functions emulators проекта `demo-tajgo`. Production Firebase и публичный интернет для тестовых данных не используются.

## Functions scenarios

- unauthenticated callable;
- invalid role, wrong owner, invalid status;
- radius 0/500/998/999/999.99 allow, 1000/1000.01/1001 deny;
- stale/missing/invalid/poor-accuracy GPS;
- busy courier;
- duplicate request;
- два заказа конкурируют за courier;
- два couriers конкурируют за order;
- wrong/right delivery code и single courier release;
- authoritative catalog total;
- changed price;
- preview blocked.

## Rules scenarios

Anonymous, customer, approved courier и admin; own/foreign user/order/offer; direct create/status/assignment; customer code/secret; published/preview/inactive/hidden catalog; admin logs; unknown collection.

## Phone pilot

1. Phone Auth: SMS, auto verification, wrong/expired code, resend timer, weak network, logout/relogin.
2. Customer creates custom order with price.
3. Courier within 999 м offers client or higher integer price.
4. Customer selects offer; concurrent second selection fails.
5. Courier follows A -> pickup -> B -> delivery.
6. Wrong code does not complete; correct code completes and releases courier.
7. Catalog server detects changed price, refreshes cart, requests confirmation.
8. Admin route is absent for customer/courier and available to owner-admin.
9. Offers, disputes, settings and audit logs open.
10. Restart both phones during pending and active flows.

## Evidence

Record APK SHA-256, test totals, emulator logs without secrets, two UID values masked in report, and screenshots of completed order/courier release. Never capture delivery code in shared logs.
