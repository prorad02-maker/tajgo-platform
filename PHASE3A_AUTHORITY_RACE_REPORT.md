# TajGo Phase 3A — Delivery Core Authority & Race Hardening

Date: 2026-08-05
Repository: `C:\Projects\tajgo`
Baseline: `main`, `ff3622b91c1501a3ef90a3d61f84c0635a66342e`, ahead 21
Pre-existing protected change: `M android/app/google-services.json`

## 1. Baseline and dependency map

Phase 2 audit was untracked at baseline. No product change began before the audit and
its Phase 2 documents were read. Canonical dependency chain:

`city + A/B + mode + generation → provider capability → trusted road route → input fingerprint → server quote/expiry → transactional order revalidation → authoritative order snapshot`.

Changing city, A/B or routing profile invalidates route and quote generations. A quote
cannot create an order unless its owner, city, coordinates, mode, fingerprint, version
and expiry still match.

## 2. P0/P1 addressed

| Finding | Phase 3A status |
|---|---|
| P0-01 release has no selected road provider | **OPEN external/provider gate.** No public provider was promoted to production authority. |
| P0-02 quote/order drift | **CLOSED IN SOURCE.** One v3 calculator and persisted quote contract; order consumes/revalidates it. |
| P0-03 physical/profile evidence absent | **OPEN device gate.** Matrix prepared; no PASS invented. |
| P1-01 bicycle ignored | **CLOSED.** City mode reaches provider; unsupported capability degrades explicitly. |
| P1-02 late GPS reverts manual city | **CLOSED IN SOURCE/REGRESSION TEST.** Manual city ownership invalidates in-flight GPS. |
| P1-03 Dushanbe search/city affinity | **CLOSED for new-order search/recent/favorites.** Active-city center/bounds and cityId persistence/filtering added. Broader whole-app hardcodes remain P2. |
| P1-04 timezone drift | **CLOSED.** UTC+05:00 and ISO weekday 1–7 on Dart/Functions. |
| P1-05 weak observation query/quality | **CLOSED IN SOURCE.** Ordered query/index, cutoff, future rejection, dedupe, provider cap and outlier handling. |
| P1-06 missing validation | **CLOSED.** Finite/range validation for route, profile, surge, reference and observations. |
| P1-07 client city trusted | **CLOSED.** Server derives both point cities and rejects mismatch. |
| P1-08 disconnected critical tests | **PARTIAL.** The screen now uses the tested request coordinator and server quote repository; pure/focused regression coverage exists. Full delayed map-widget/device injection remains. |
| P1-09 fixed route padding | **CLOSED IN CODE / DEVICE OUTSTANDING.** Fit uses bottom-panel-aware asymmetric padding. |
| P1-10 GPS cancel/relisten race | **CLOSED IN SOURCE.** Native subscription start/stop is serialized by a lifecycle chain and generation. Device repetition remains. |
| P1-11 structural performance risk | **PARTIAL.** Duplicate work/lifecycle generations and stream race are addressed; the 1,700+ line screen and physical profile evidence remain. |

## 3. Canonical quote architecture

`DeliveryQuoteInput`, `DeliveryQuoteResult`, `PricingProfile`, `QuoteConfidence`,
`roundTjs`, strict validators and `deliveryInputFingerprint` live in the backend pricing
domain. Formula order is:

`ceil(max(reference × multiplier OR fallback, delivery floor, courier payout + margin) × surge)`.

The callable derives city from coordinates, asks an injected server route resolver,
selects validated city observations, calculates once and stores a ten-minute
`delivery_quotes/{quoteId}` snapshot. Without a trusted server route it returns
`status=degraded`, `authoritative=false` and no quoteId.

## 4. Order authority

`createCustomDeliveryOrder` requires `quoteId`. Inside the same transaction it checks
owner, expiry, authoritative flag, v3 version, city/mode/input fingerprint and prior
consumption. Stored distance, ETA, price, confidence, source and provider come only
from that quote. Client price/distance/ETA remain compatibility fields and cannot set
the order. Missing, expired, consumed or mismatched quotes fail closed.

## 5. Routing mode

Both service areas currently request `bicycle`. The previous `config.mode` override is
removed from request execution. OSRM maps bicycle→`bike`, car→`driving`; GraphHopper
maps bicycle/scooter→`bike`, car→`car`. Provider-supported modes are explicit. Public
OSRM is considered driving-only and therefore degrades for bicycle rather than silently
substituting driving. Production bicycle authority is still blocked on provider choice.

## 6. Race hardening

`DeliveryRequestCoordinator` owns GPS, reverse-geocode, route and quote generations,
input generation and manual-city ownership. The production screen uses it in addition
to local request IDs. City/A/B edits clear route, quote and CTA; lifecycle pause
invalidates writes; late GPS cannot defeat a manual switch; old route/quote results
cannot become visible. User gesture camera ownership remains respected.

## 7. City-aware search

The selected city center, not physical GPS, biases remote search. All local, recent,
favorite and remote results are bounded to the active service area. New saved/recent
place JSON carries `cityId`; legacy entries are safely filtered by coordinates.
Dushanbe no longer loads the Khujand curated corpus. Cross-city results cannot be
selected through this flow without first switching the active city.

## 8. Taxi reference hardening

Selectors enforce finite positive limits, 45-day staleness, five-minute future skew,
city/currency separation, obvious deduplication, provider contribution caps, route
similarity, median unit-price outlier limits and a three-sample minimum. Time semantics
are Tajikistan UTC+05:00 with ISO weekday. Status remains **PARTIAL / NOT READY** until
lawful real observations and operational ownership exist.

## 9. Pricing parity gate

`test/fixtures/pricing_contract_v3.json` is the single machine-readable fixture source.
Flutter and Functions tests load that exact file. It covers normal reference, both
floors, surge, both cities, fallback/low confidence, zero/near-zero, large distance and
decimal rounding. Any arithmetic/profile/rounding drift breaks one or both suites.

## 10. Lifecycle/performance

Customer-map pause invalidates GPS/geocode/route/quote completions and presents a retry
state. Native courier GPS start/stop is serialized to prevent pause/resume relisten
races. Search already debounces and now rejects stale results by request generation.
Route fit uses measured panel height. Full rebuild isolation and profile traces remain
honest outstanding work, not claimed complete.

## 11. Tests

Focused Phase 3A results before the final gate:

- Shared Flutter pricing/race/search suite: PASS.
- Routing provider selection suite: PASS.
- Functions unit: PASS, 28 tests.
- Functions integration emulator: PASS, 32 tests.

Final gate:

- `flutter analyze`: PASS, 0 issues.
- Flutter: PASS, 121 tests.
- Functions build: PASS; unit: PASS, 28 tests.
- Firestore Rules emulator: PASS, 17 tests.
- Functions integration emulator: PASS, 32 tests.
- Total automated tests: **198 PASS**.
- Debug APK: PASS, 212,342,786 bytes, SHA-256
  `E0C4EEFD890F16FA477825552DA141F71D9AEC60A5410FE43156D282737C959A`.
- `git diff --check`: PASS.

The emulator host used Node 24 although Functions request Node 20; this remains an
environment-parity warning, not a failed test. No dependency was updated.

## 12. Device gate outstanding

`PHASE3A_DEVICE_GATE.md` contains the required SETUP/ACTION/EXPECTED/LOG MARKERS/PASS
criteria. Every row is NOT RUN. No physical evidence was fabricated.

## 13. Blaze/provider blockers

- Blaze and an owner-approved deployment window for Functions/indexes/Rules.
- Authorized server-side bicycle routing provider with Tajikistan coverage, quotas,
  privacy/retention terms, outage behavior and route corpus.
- Lawful taxi observations and data-quality owner.
- Physical Khujand/Dushanbe/GPS/lifecycle/layout/API 36 evidence.
- Existing signing/legal release gates remain outside this phase.

## 14. Remaining findings

- P0: production route/provider configuration (P0-01); physical matrix (P0-03); Blaze
  activation is a known operational P0.
- P1: full delayed map-widget injection evidence (remaining P1-08); physical padding
  evidence (P1-09); structural rebuild/profile work (remaining P1-11).
- P2: accessibility/back/text-scale, service polygons, passive stale label and broader
  Dushanbe hardcode cleanup remain as historical backlog.

## 15. Decision

**CONDITIONAL GO for continued bounded pre-Blaze/device work. NO-GO for closed testing
and production.** Canonical source authority is materially hardened, but production
cannot be called ready without the external provider, Blaze and physical gates.
