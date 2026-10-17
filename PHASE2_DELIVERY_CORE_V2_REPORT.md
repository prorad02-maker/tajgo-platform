# TajGo Phase 2 — Delivery Core V2

Date: 2026-08-04. Baseline: `e927018d52d5e773c72f11c8c0036c88bab73d8b`.
Scope is local source/tests only; no deploy, push or App Check enforcement.

## 1. Summary

TajGo customer navigation is delivery-only and opens on the working delivery map.
Khujand and Dushanbe share centralized service-area configuration. Road routing failure
is explicit and cannot masquerade as a road route or unlock price/order submission.
Local quote preview and backend authoritative quote source use city profiles and taxi
reference abstractions.

## 2. Architecture

- Central `ServiceAreaRegistry`, selection persistence, bounds and city profiles.
- Map session primitives for location quality, camera ownership and latest-request gate.
- Central tile provider config/attribution across all map viewports.
- Routing provider/config/service boundary with explicit unavailable mapping.
- Flutter and TypeScript delivery quote engines plus taxi observation selection.

## 3. Map UX before/after

Before: Khujand constants, silent direct fallback, editable customer price, possible
Firestore stream recreation in build. After: city selector/bounds, cached courier
stream, road-only route display, retry state, preliminary fixed quote and delivery CTA.
Last-known position can render quickly while an explicit location action requests a
fresh fix. Physical feel/performance remains a device gate.

## 4. Khujand/Dushanbe

Each city has stable ID, RU name, country, center, bbox, zoom, pricing profile and
routing profile. GPS detection, stored/manual fallback and outside-area handling are
covered by pure tests. Dushanbe local place corpus remains a data-content follow-up;
remote geocoding is city-aware and Khujand-only curated places are not offered there.

## 5. Routing

OSRM/GraphHopper remain pilot adapters. One canonical feature flag and centralized
endpoint config are used. Timeout and bounded retry exist. Direct-line diagnostics are
not shown/charged as roads. Production provider choice is still required.

## 6. Pricing

Formula: `max(taxiReference × configured multiplier, minimumDeliveryPrice,
minimumCourierPayout + platformMinimumMargin) × surgeFactor`. Default multiplier is
0.50 and surge hook is 1.0. Existing `7 + 3/km, min 10` survives only as the
low-confidence city fallback; values are independently configurable per city.

## 7. Taxi observations

The privacy-minimized model and repository read `taxi_price_observations`. Selection
uses city separation, route similarity, recency/hour/day weighting, quality and outlier
rejection with a three-sample floor. No current Maxim integration or unauthorized
scraping exists.

## 8. Backend authority

`getDeliveryQuote` callable source ignores client price/route hints, recomputes trusted
inputs and reads server observations. Until an authorized road provider is selected,
its server geometric fallback is explicitly identified and low-confidence. Custom
order creation no longer stores a manipulated client preview as authoritative price.
Activation and real end-to-end validation require Blaze plus owner-approved deploy.

## 9. Security review

No new PII is required by observations. Provider names/confidence/floors are not shown
to customers. No keys were added. App Check remains unenforced. Existing order command
authority is preserved; price manipulation receives a server-derived value.

## 10. Performance review

Courier Firestore stream creation moved out of map build. Request generations prevent
stale route overwrite. Reverse geocode remains camera-idle driven. Courier GPS streams
cancel outside foreground. Physical profile traces are still required.

## 11. Test results

- `flutter analyze`: PASS, 0 issues.
- Flutter tests: PASS, 116 tests (including 11 focused Phase 2 tests).
- Functions TypeScript build: PASS.
- Functions unit: PASS, 25 tests.
- Firestore Rules emulator: PASS, 17 tests.
- Functions/Firestore integration emulator: PASS, 30 tests.
- Debug APK: PASS, `build/app/outputs/flutter-apk/app-debug.apk`, 212,342,786
  bytes, SHA-256 `14974B1FE2FB6D8EF4D35691E44BF39BFA7E091B5342549595C62C67CF95E7C5`.

Total automated tests: 188. Physical device tests were not run.

## 12. Device tests required

All cases in `PHASE2_DEVICE_TEST_PLAN.md`; none are represented as passed.

## 13. Requires Blaze/owner action

Functions deployment, real quote/order smoke, taxi observation population, production
tile/routing provider selection, legal acquisition approval, signing and physical API
36/two-phone validation.

## 14. Remaining priorities

- P0: Blaze/deploy unavailable; production signing absent.
- P1: production tile/routing provider and physical route/GPS/profile validation.
- P1: server-side authorized road recomputation before authoritative quote rollout.
- P2: curated Dushanbe places/polygons, richer saved-address city filtering and broader
  whole-app UX polish.

## 15. Decision

**CONDITIONAL GO for local Phase 2 code; NO-GO for production.** Cloud/provider/device
gates above remain mandatory.
