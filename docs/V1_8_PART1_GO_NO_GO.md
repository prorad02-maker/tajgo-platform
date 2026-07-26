# TajGo v1.8 Part 1 — GO / NO-GO

| Gate | Status | Evidence / remaining action |
|---|---|---|
| Phone Auth code path | PASS | SMS callbacks, resend, conflict and session restore paths exist |
| Server role source of truth | PASS | profile normalized by Function; router reads Firestore |
| Backend radius | PASS | strict `< 1000 m` unit boundaries |
| One active order | PASS | transactional race tests |
| Transactional offers | PASS | duplicate and competing selection tests |
| Delivery code protected | PASS | separate secret/customer docs, scrypt, attempt limit |
| Catalog total authoritative | PASS | server reread, price-change and total tests |
| Preview checkout blocked | PASS | Flutter + backend tests |
| Admin route protected | PASS | server role route/gate/Rules |
| Semantic Rules tests | PASS | local emulator suite |
| Functions tests | PASS | unit + Firestore/Functions emulator integration |
| Flutter tests | PASS | existing and v1.8 tests |
| Flutter analyze | PASS | no issues |
| Debug APK | PASS | `build/app/outputs/flutter-apk/app-debug.apk`, SHA-256 `05ABDC20BC5B2056140351FFB7E83D0A37647E059FE35C3E0C624E1A4F31508D` |
| Two physical phones | PHONE_REQUIRED | no Android device was connected during final build |
| Production backend | DEPLOY_REQUIRED | owner deploy of indexes, Functions and Rules |
| Legacy code/catalog migration | DEPLOY_REQUIRED | perform before/with pilot rollout |

## Part 2 decision

Code-level Part 1 is GO for controlled owner deployment and a two-phone pilot. Production/user rollout remains NO-GO until:

1. owner completes the documented deploy;
2. legacy codes and catalog publication flags are verified;
3. two physical phones pass the full flow;
4. App Check rollout and dependency advisories are reviewed.

Build warning to track: current `cloud_functions` Android plugin still applies Kotlin Gradle Plugin instead of Flutter Built-in Kotlin. It does not block this APK, but must be revisited before a future Flutter toolchain upgrade.
