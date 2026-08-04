# TajGo Phase 2 — Independent Post-Audit

Date: 2026-08-05
Repository: `C:\Projects\tajgo`
Baseline: `main`, `ff3622b91c1501a3ef90a3d61f84c0635a66342e`
Phase 2 range: `e927018d52d5e773c72f11c8c0036c88bab73d8b..ff3622b91c1501a3ef90a3d61f84c0635a66342e`

## 1. Executive summary

**Audit verdict: NO-GO for production; CONDITIONAL GO for a bounded pre-Blaze remediation phase.**

Phase 2 materially improved the code: the customer shell is delivery-only; map tiles and attribution are centralized; a road-provider failure no longer silently unlocks a route, quote, or CTA; city bounds and pricing profiles exist for Khujand and Dushanbe; customer price input is read-only; order creation overwrites manipulated client price; and courier location subscriptions are explicitly stopped on lifecycle pause.

The implementation is not yet production-quality. The decisive blockers are:

1. A normal release build has road routing disabled by default, while the CTA requires a valid road route. Therefore the main delivery flow cannot reach an enabled submit action without an owner-selected provider/build configuration.
2. The customer preview, `getDeliveryQuote`, and `createCustomDeliveryOrder` are three different quote paths. Order creation does not use taxi observations or a trusted road route, yet stores a geometric `direct × 1.25` fallback as `server-v2-authoritative`. The displayed price and stored price can differ, and the claimed taxi-reference authority is not integrated end to end.
3. No physical-device/profile evidence exists for camera ownership, poor/stale GPS, background/resume, rapid route changes, keyboard/bottom-sheet behavior, route fit, or API 36. Pure helper tests do not verify the screen control flow.

Finding count in this audit: **P0: 3, P1: 11, P2: 9, P3: 0**. Known non-code production gates also remain: Blaze/deploy, production signing, published legal surface, production tile/routing provider, and owner-approved taxi data acquisition.

No product code, test code, Firebase configuration, dependency, rules, or build configuration was changed. This document is the only audit-created source-tree file.

## 2. Audit scope

Baseline at start:

| Field | Value |
|---|---|
| Branch | `main` |
| HEAD | `ff3622b91c1501a3ef90a3d61f84c0635a66342e` |
| Upstream | `origin/main`, local branch ahead 21 |
| Pre-existing worktree change | `M android/app/google-services.json` |
| Stash | `stash@{0}: On main: wip v1.5.1 pilot hardening before v1.7 audit` |

Phase 2 changed 34 files: five planning/readiness documents; Flutter service-area, map-provider, location, routing, map session, pricing and taxi-observation sources; the customer shell and main map screen; map viewports in customer/courier/admin/marketplace flows; Functions quote/pricing source; and Phase 2 Flutter/Functions/integration tests. The full name-status list was derived with `git diff --name-status e927018..ff3622b`.

Required documents read in full:

- `PHASE2_DELIVERY_CORE_V2_REPORT.md`
- `PHASE2_DEVICE_TEST_PLAN.md`
- `ROUTING_PROVIDER_PLAN.md`
- `TAXI_REFERENCE_PRICING_PLAN.md`
- `MAP_PROVIDER_READINESS.md`
- `RELEASE_AUDIT_2026.md`
- `PHASE1_FIX_BEFORE_BLAZE_REPORT.md`

## 3. Verified claims from the Phase 2 report

- Customer navigation is delivery-only: `lib/features/customer/customer_shell.dart:8-9,56-82`.
- Stable service-area IDs, centers, rectangular bounds, zoom, pricing profile and routing profile exist for Khujand and Dushanbe: `lib/core/config/service_area_config.dart:23-76`.
- Stored/manual city selection exists and manual switching clears selected points, route and price: `lib/core/services/city_selection_service.dart:8-18`; `lib/features/map/screens/new_order_map_screen.dart:638-683`.
- Last-known location is shown before a fresh request, and a fresh result does not move the camera after `_userMovedCamera`: `new_order_map_screen.dart:99-147`.
- Explicit current-position reads reject stale and poor fixes and terminate on timeout: `lib/features/map/services/tajgo_location_service.dart:88-117`.
- Older route responses cannot write screen state after a newer request or city reset: `new_order_map_screen.dart:429-462,505-518,671-681`.
- Direct fallback is not returned by `RouteService.buildRoute` as a usable road route: `lib/features/map/services/route_service.dart:121-191`.
- Route error clears route and preview price; CTA requires a non-null route: `new_order_map_screen.dart:454-461,1471-1479`.
- Tile URL/User-Agent are centralized and all current `TileLayer` call sites contain visible OSM attribution; the source-enforcement test passed: `lib/core/config/map_provider_config.dart:1-22`; `test/phase2_delivery_core_test.dart:175-190`.
- Courier screens cancel foreground location subscriptions outside resumed state: `lib/features/courier/courier_home_screen.dart:55-66`; `lib/features/courier/courier_order_screen.dart:88-95`.
- Customer price field is read-only: `new_order_map_screen.dart:1451-1463`.
- Backend creation ignores a manipulated client price and recomputes stored price: `functions/src/core.ts:518-546,571-599`; integration test `functions/test/integration/core.integration.test.ts:203-223` passed.
- Rules do not expose a client write path for `taxi_price_observations`; the default-deny rule applies: `firestore.rules:423-424`.
- No Maxim API, live price, or scraper is present.

## 4. Claims not fully verified

- “Fresh GPS does not take the camera after a gesture” is supported by screen code but not tested through the real widget/map event path. The tested `CameraOwnership` helper is unused by the screen.
- “Stale route response cannot overwrite a newer route” is supported by `_routeRequestId`, but the tested `LatestRequestGate` helper is unused and no delayed-provider screen test exercises rapid A/B changes.
- “Location stream stops outside foreground” is visible in lifecycle callbacks, but pause/resume races and the shared stream controller have no lifecycle test or device proof.
- “Backend authoritative quote” is only partly true: order creation overrides client price, but does not reuse `getDeliveryQuote`, taxi observations, or an authorized road distance.
- “Taxi reference abstractions are ready” is true at prototype level, not at operational/data-quality level.
- “Khujand and Dushanbe support” is partial. City bounds and selection exist, but manual Dushanbe search can still be biased to the physical Khujand GPS position, saved/recent places are not city-filtered, and other app surfaces retain Khujand defaults.
- Map performance, route fit under the bottom panel, high text scale, Android predictive back and API 36 remain unverified without device/profile evidence.

## 5. P0 blockers

| ID | Finding and evidence | Risk | Recommended fix |
|---|---|---|---|
| P0-01 | **Release customer flow has no road route by default.** `RoutingConfig.fromEnvironment` enables routing only with `TAJGO_ROUTING_ENABLED`, defaulting to `kDebugMode` (`routing_config.dart:58-62`). `RouteService` throws when it is disabled (`route_service.dart:184-191`), and CTA requires `route != null` (`new_order_map_screen.dart:1471-1479`). | A normal release opens the map but cannot progress from A/B to a submit-enabled order. | Select an authorized provider/server adapter, make release configuration explicit, validate it in an artifact manifest and outage test, then field-test both cities. Do not silently re-enable public OSRM as production authority. |
| P0-02 | **Pricing authority is not end-to-end.** Flutter preview uses road route + local fallback only (`new_order_map_screen.dart:440-452`). `getDeliveryQuote` may read observations but uses `direct × 1.25` (`functions/src/core.ts:69-133`). Order creation independently calculates fallback without observations (`core.ts:535-546`) and stores it as `server-v2-authoritative` (`core.ts:571-599`). | Customer-visible and stored amounts can differ; taxi-reference data does not affect the order; geometric distance can underprice a real road journey and undermine courier payout/margin. | Implement one server quote contract with trusted road distance, quote ID/version/expiry and observation selection; require order creation to consume/revalidate it. Client preview must be clearly provisional. |
| P0-03 | **Critical physical/profile claims have no evidence.** `PHASE2_DEVICE_TEST_PLAN.md` explicitly records no passes, while the critical helper tests do not drive `NewOrderMapScreen`. | Camera jumps, lifecycle leaks, route-fit obstruction, keyboard overlap or API 36 regressions can block the only customer flow despite green unit tests. | Run the P0 device matrix in section 18 before further feature work and attach build/device/network/provider evidence. |

Blaze/deploy is an additional known operational P0 gate: callable order/quote flows cannot work in the real project until owner-approved deployment. It is not counted as a newly discovered Phase 2 code finding.

## 6. P1 issues

| ID | Finding and evidence | Risk | Recommended fix |
|---|---|---|---|
| P1-01 | **Requested bicycle mode is ignored.** `RoadRouteProvider.buildRoute` assigns `effectiveMode = config.mode` instead of the method parameter (`road_route_provider.dart:48-57`), and `ROUTING_PROFILE` defaults to `driving` (`routing_config.dart:75-78`). The per-city `routingProfile` is never used by the order screen. | Bicycle/scooter routes, ETA and price can be based on car roads and restrictions. | Pass the requested/city mode through to the provider; remove the surprising driving override; test generated OSRM/other-provider requests for both cities and modes. |
| P1-02 | **Manual city selection can be reverted by a late fresh GPS result.** `_refreshFreshLocation` always assigns detected `_city` (`new_order_map_screen.dart:127-140`), while manual switch/reset is independent (`638-683`). | User switches to Dushanbe; an in-flight Khujand GPS result silently changes city after the reset and can produce inconsistent map/city/search state. | Add a city-selection generation/ownership token. Manual selection must win until explicit GPS recenter/auto-detect is requested. |
| P1-03 | **Dushanbe address search uses physical GPS rather than selected city and saved/recent results have no city affinity.** Search sheet receives `near: _current` (`new_order_map_screen.dart:228-236`). `PlaceSearchService` infers city from `near` and always adds favorites/recent first (`place_search_service.dart:38-71`). | A user physically in Khujand who manually selects Dushanbe gets Khujand geocoding and stale Khujand favorites/recent results. | Pass selected city/center explicitly; store/filter `cityId` on recent/saved addresses; reject or clearly label cross-city entries before map confirmation. |
| P1-04 | **Taxi local-time semantics drift between Dart and Functions.** Dart compares `DateTime.weekday` (1–7) and device `at.hour` (`taxi_observation.dart:173-191`); TypeScript compares `Date.getDay()` (0–6) and server-local/UTC `getHours()` (`functions/src/pricing.ts:94-100`). | Day/hour weighting is inconsistent and wrong for Tajikistan UTC+5; preview and backend select different references. | Define weekday convention and IANA/timezone offset in schema; derive local time server-side from `observedAt` + city timezone; add cross-language parity vectors. |
| P1-05 | **Reference query/quality controls are insufficient.** Firestore reads an unordered `.limit(100)` (`taxi_observation.dart:65-71`; `core.ts:89-93`); age uses absolute difference with no stale/future cutoff (`taxi_observation.dart:173-174`; `pricing.ts:95-96`); duplicates and provider concentration are not controlled. | Arbitrary or stale records dominate; duplicate/provider-biased imports create false confidence; future timestamps receive high weight. | Query ordered recent records, reject future/stale data, deduplicate, cap per-provider contribution, validate source/quality and add required indexes after owner approval. |
| P1-06 | **Pricing profile/reference inputs lack server validation.** `calculateDeliveryQuote` accepts negative, `NaN`/Infinity, unbounded surge/profile values (`functions/src/pricing.ts:112-136`). An Infinity observation is not rejected by `quotedPrice <= 0` (`76-90`). | A malformed authorized import/config can return a non-serializable or extreme quote and break order creation. | Validate all finite ranges, maximum distance/duration/price, `0 < multiplier <= policy max`, bounded surge and currency before selection/calculation. |
| P1-07 | **`getDeliveryQuote` trusts `cityId` independently of coordinates.** It selects `pricingProfile(cityId)` without checking pickup/dropoff service city (`functions/src/core.ts:79-88`). | When city profiles diverge, a modified client can request the cheaper profile for another city. | Detect both cities from coordinates, require same supported city, derive profile server-side and ignore/reject mismatched `cityId`. |
| P1-08 | **Critical regression tests provide false confidence.** `CameraOwnership` and `LatestRequestGate` are tested (`test/phase2_delivery_core_test.dart:63-101`) but not used by `NewOrderMapScreen`, which uses booleans/request IDs. The only Phase 2 details widget test uses a prebuilt road route (`192-202`). | The tests stay green if actual map gesture, delayed route or city-switch wiring regresses. | Add injectable controller/services and widget/integration tests with delayed GPS/router/quote futures, rapid A/B changes, city switch, denied-forever and lifecycle transitions. |
| P1-09 | **Route fit ignores the real bottom panel.** Initial fit and overview use fixed all-side 60/50 px padding (`new_order_map_screen.dart:417-424,476-485`), while the panel occupies a large fixed-height bottom region (`488-492,906-931`). | Much of the route can be hidden behind the details panel, especially on small screens/landscape. | Measure panel/safe-area/keyboard insets and use asymmetric dynamic fit padding; device-test route visibility. |
| P1-10 | **Shared native GPS stream has a cancel/relisten race.** Broadcast `onCancel` starts async cancellation, `_positionController` is retained, and `onListen` returns if `_nativePositionSubscription` is still non-null (`tajgo_location_service.dart:177-213`). | A rapid pause/resume can attach a listener while cancellation is in flight, then leave it with no native subscription. | Serialize stream lifecycle or use a ref-counted/restartable subscription state machine; test rapid pause/resume and two listeners. |
| P1-11 | **Map performance remains structurally risky and unmeasured.** `NewOrderMapScreen` is 1,767 lines with UI, GPS, city, search, routing, pricing and order commands in one State. Its whole `FlutterMap` subtree rebuilds for tile-ready, GPS, gesture, reverse-geocode, route, comment/type and courier stream updates (`new_order_map_screen.dart:41-74,686-953`); markers/polylines are allocated in build. | Jank and unnecessary allocation/network-adjacent work on low-end Android are not disproved by unit tests. | Split controller/state from viewport/panels, isolate rebuilds, cache marker/polyline models, and record profile traces/rebuild counts before calling performance ready. |

## 7. P2 improvements

| ID | Finding and evidence | Risk | Recommended fix |
|---|---|---|---|
| P2-01 | `LocationFixQuality.evaluate` treats future timestamps as fresh because negative age is not rejected (`map_session_state.dart:31-57`). | Clock skew/bad data can label a non-trustworthy fix authoritative. | Reject age below a small skew tolerance and test future timestamps. |
| P2-02 | Passive last-known location sets `_gpsWeak` only by accuracy and does not surface stale age (`new_order_map_screen.dart:99-124`). | User may mistake an old marker for a current position. | Evaluate/pass `LocationFixQuality` and show stale/poor state until fresh GPS arrives. |
| P2-03 | Low-confidence pricing is described only as generic “preliminary”; actual confidence/source is not carried to the details panel (`new_order_map_screen.dart:1434-1447`). | A weak geometric/fallback estimate looks the same as a better-supported preview. | Carry a customer-safe confidence state and explain that the amount will be confirmed, without provider/margin internals. |
| P2-04 | `_RoundButton` is 40×40 (`new_order_map_screen.dart:1540-1565`). | Small touch target reduces accessibility and one-handed reliability. | Use at least a 48×48 semantic hit area while preserving visual size if needed. |
| P2-05 | City chip/address rows rely largely on inferred semantics; map markers and courier dots lack explicit semantic labels (`new_order_map_screen.dart:768-805,1258-1289,1488-1537`). | TalkBack users receive incomplete map context/actions. | Add `Semantics` labels, selected/value states and explicit edit/change-city actions. |
| P2-06 | Fixed panel heights and one-line hints are only covered at text scale 1.3, not 1.5/2.0 or landscape (`new_order_map_screen.dart:488-492,1020-1089`; current widget suite cases 113–115). | Larger text can truncate instructions or squeeze actions/map visibility. | Add 1.5/2.0 and landscape tests; allow content-driven/adaptive panel height. |
| P2-07 | Android back from A/B/details does not step through the map flow; only shell tabs use `PopScope` (`customer_shell.dart:49-55`; no `PopScope` in `new_order_map_screen.dart`). | Back may exit the app/screen instead of undoing B/details, contrary to user expectation. | Define a stage-aware `PopScope` and predictive-back behavior, then test API 36. |
| P2-08 | City service areas are unverified rectangles (`service_area_config.dart:52-74`). | Edge districts and GPS jitter can be accepted/rejected inaccurately. | Validate against owner-approved service polygons/corpus and add boundary tolerance tests. |
| P2-09 | Khujand defaults remain outside creation: tracking/admin/courier models and address formatter (`order_tracking_screen.dart:38,391`; `dispatch_map_screen.dart:28,203`; `map_address_formatter.dart:14-38`). | Dushanbe orders can be framed with wrong fallback center/city labels in secondary flows. | Derive fallbacks from order/user `cityId` and remove scattered city literals in a bounded multi-city cleanup. |

## 8. Map architecture

State ownership is local to `_NewOrderMapScreenState`; it mixes presentation, camera control, reverse geocoding, city persistence, routing, preview pricing and order creation. `MapSessionState` primitives exist, but the screen does not use `CameraOwnership`, `DeliveryMapFlowState`, `LocationAvailability` or `LatestRequestGate`. This duplicates the same concepts as `_stage`, `_routeLoading`, `_routeError`, `_userMovedCamera` and request integers.

Positive lifecycle points:

- Text controllers/timer/camera animation are stopped in `dispose` (`new_order_map_screen.dart:209-215`).
- Async state writes generally check `mounted` and route/reverse generations.
- Courier Firestore stream is cached in `didChangeDependencies`, not recreated inside build (`85-91`).

Architecture gaps:

- No app lifecycle observer exists on the customer map, so in-flight passive/fresh GPS/geocode/route calls continue across pause. They avoid stale writes only by `mounted`/IDs, not by cancellation.
- `_userMovedCamera` never resets except by reconstructing the screen; explicit GPS works because it bypasses the flag, but the ownership policy is implicit.
- A late GPS result can change `_city` after manual selection even when it cannot move the camera.
- Map controller state is not explicitly restored across process death; the `IndexedStack` preserves it only during in-process tab switching.

## 9. Map UX

Actual code flow is clear: open delivery tab → select A → select B → road route calculation → ETA/preliminary price → submit CTA. No Taxi/Market/Food promises appear in the customer shell. A/B are visually distinct, route loading does not block map interaction, route errors expose retry, and outside-city point confirmation gives an actionable city-switch message.

Weak points are route fit, Dushanbe search affinity, manual-city/GPS race, lack of explicit low-confidence state and absent high-scale/landscape/device validation. The details panel is scrollable and uses SafeArea, but fixed outer height means the effective map viewport and route padding are not coordinated.

UX scores (code/widget evidence only; physical feel not scored as verified):

| Dimension | Score / 10 | Rationale |
|---|---:|---|
| Clarity | 8.0 | Strong A/B labels, delivery-only CTA and explicit stages. |
| Speed to first action | 8.0 | Map opens immediately; GPS is optional and manual selection works. |
| Map readability | 6.5 | Clear markers/road-only polyline, but fixed route fit and panel obstruction risk. |
| Address selection | 6.0 | Search/recent/manual paths exist; Dushanbe/city affinity is incomplete. |
| Error recovery | 7.0 | GPS actions and route retry exist; lifecycle/offline recovery is not device-proven. |
| Delivery focus | 9.0 | Customer shell and CTA are consistently delivery-only. |

Overall UX assessment: **7.4/10, PARTIAL pending device and multi-city corrections.**

## 10. Multi-city

Stable IDs and server/client rectangular bounds match numerically. The server correctly rejects an order whose A/B do not resolve to the same supported city (`functions/src/core.ts:525-534`). Client point confirmation is constrained to the actively selected city (`new_order_map_screen.dart:329-343`).

| Scenario | Result | Evidence / limitation |
|---|---|---|
| Khujand | PARTIAL | Core selection/bounds/profile work; release routing/provider and device proof absent. |
| Dushanbe | PARTIAL | Registry/profile work; search can use Khujand GPS; no curated Dushanbe corpus; broad app hardcodes remain. |
| Outside area | PASS (code) / PARTIAL (UX) | Client blocks confirmation and server rejects; boundary rectangles and device messaging not field-validated. |
| Cross-city | PASS (authority) / PARTIAL (discovery) | Server rejects cross-city A/B; saved/recent entries are not city-filtered before selection. |

The bounding boxes do not overlap, so iteration order is not currently ambiguous. Points exactly on an edge are included. There is no tolerance/polygon model for near-boundary GPS jitter.

## 11. Routing

The UI calls `RouteService`, not a concrete endpoint. Timeout and at most one retry for HTTP 429/5xx exist (`road_route_provider.dart:65-81`). OSRM geometry is decoded as longitude/latitude, distance meters become km, duration seconds become minutes, and GraphHopper milliseconds are handled correctly (`153-260`). Screen request generation prevents old results from setting route/price.

No straight-line fallback can currently unlock the customer CTA through `buildRoute`: disabled/provider/sanity failure throws, route is cleared, price is cleared, and CTA is disabled. Direct routes still exist for diagnostics/admin/demo and are not themselves a customer-authority defect.

Major gaps are P0-01, P1-01 and P1-09. Error mapping collapses provider/timeout/offline/429 into one customer string. Cancellation is logical only: old HTTP work continues. Public `router.project-osrm.org` and public OSM tiles have no TajGo SLA/quota/contractual guarantee; OSM tile config is explicitly marked `pilotOnly`. Production provider selection and terms remain owner gates.

## 12. Pricing

Flutter and TypeScript implement the requested arithmetic for valid finite inputs:

`ceil(max(taxiReference × multiplier OR fallback, minimumDeliveryPrice, minimumCourierPayout + platformMinimumMargin) × surgeFactor)`

Both current city profiles use multiplier `0.50`, minimum 10 TJS, courier floor 7 + margin 3, fallback `7 + 3/km`, zero per minute and surge 1.0. Both round upward to whole TJS.

Semantic parity is **PARTIAL**:

- Flutter rejects negative/non-finite distance/duration; Functions does not.
- Flutter confidence is an enum supplied by reference; Functions maps numeric confidence `<0.7` to medium and never returns low when any reference exists.
- Dart zone weighting exists (`taxi_observation.dart:179-191`); TypeScript selector has no pickup/dropoff bucket parameters or zone weight.
- Day-of-week/time conventions differ.
- Customer preview never calls `getDeliveryQuote`; order creation never reads observations.
- Client preview uses provider road distance/ETA; server creation uses geometric distance and 5 m/s.

Zero distance is not allowed by the UI only below 1 meter, but server order creation accepts coincident coordinates and prices them at the floor. Huge but in-city routes are bounded only by city rectangles. Missing route blocks the client CTA; modified clients can call create directly, where coordinates remain the true authority and price is recomputed.

## 13. Taxi reference engine

**REFERENCE ENGINE = NOT READY for production authority; PARTIAL as a prototype.**

Good properties: city and TJS filtering, broad distance/time similarity, a three-sample floor, median unit-price outlier filter, recency/hour/day/quality weighting, no necessary PII, and safe empty-dataset fallback.

Not-ready properties:

- no lawful populated dataset or live Maxim claim;
- no explicit schema/rules/import validator/version contract;
- unordered 100-record cap;
- no maximum age or future timestamp rejection;
- UTC/local weekday mismatch and Dart/JS weekday mismatch;
- no deduplication or per-provider balancing;
- no finite/maximum field validation;
- confidence can be inflated by duplicates and is not calibrated;
- Dart has zone weighting but backend does not;
- no end-to-end order integration;
- no required composite index today for equality-only city query, but ordered-recency/provider queries recommended above will require planned indexes after Blaze.

## 14. Security and authority

Positive findings:

- Callable wrapper requires Firebase authentication (`functions/src/index.ts:28-47`).
- Order creation derives customer UID from auth principal and recomputes price/city/distance.
- Client `finalPrice`, route hints, multiplier and preview price cannot set stored authoritative price.
- Direct mobile writes to orders and taxi observations are denied by Rules.
- New Phase 2 logs reviewed do not reintroduce coordinates/address/UID payloads; routing diagnostics use aggregate route metrics/provider name.

Authority gaps:

- `getDeliveryQuote` derives profile from client `cityId` rather than coordinates (P1-07).
- Order creation recomputes a fallback price but does not bind to a quote ID, expiry, observation snapshot or trusted road route (P0-02).
- No explicit admin/import callable exists for observations, which is safe now but means the repository is not operational. Any future import must validate and audit fields before Admin SDK writes.
- App Check is intentionally unenforced and Blaze deployment is absent; these are declared gates, not audit regressions.

No direct privilege-escalation path or client-controlled final stored price was found in the reviewed Phase 2 source.

## 15. Performance

Code-positive changes: courier stream is cached, reverse geocoding occurs at map move end rather than every movement event, route requests are de-duplicated/cache-backed, and stale results are ignored.

Unresolved: the entire map stack rebuilds frequently; markers/polylines are reconstructed; route HTTP requests are not canceled; fresh GPS and last-known reverse geocodes can overlap; courier stream updates rebuild the full viewport; and no DevTools/profile trace, rebuild counter, memory cycle or network request count exists. No diagnostic benchmark was added because production behavior did not need mutation to establish the structural evidence, and a synthetic counter would not replace physical/profile measurement.

The 212 MB debug APK is informational, not a P0; debug artifacts include unstripped/runtime content and are not Play download-size evidence.

## 16. Accessibility and Android UX

- Main A/B buttons are 48 px high and have text labels.
- Back, route overview and locate controls have tooltips/known semantic button behavior, but `_RoundButton` is only 40 px.
- SafeArea is used for top controls and panels; search sheet behavior already accounts for keyboard insets in existing code.
- White/light-green surfaces and dark text look reasonable by source constants, but no automated contrast measurement or dark-theme design exists. The map screen forces a light background/panels.
- Text scale coverage stops at 1.3 for the collapsed panel; 1.5/2.0 and landscape are unverified.
- Shell `PopScope` handles returning from Orders/Profile to Delivery, but map-stage back navigation is not modeled.
- Target/compile API 36 configuration passes static tests; predictive back and edge-to-edge/system-nav overlap need physical API 36 verification.

## 17. Test quality

Critical test assessment:

| Scenario | Current coverage | Confidence |
|---|---|---|
| City centers/outside and last-city fallback | Pure registry tests | Medium; no boundaries/jitter/persistence widget flow. |
| Camera after user gesture | Unused helper only | Low/false confidence. |
| Route race | Unused helper only; screen integer not driven | Low/false confidence. |
| Direct fallback cannot unlock route | RouteService unit test | Good for service; no full CTA screen test. |
| Price formula/floors | Dart + TS happy-path unit tests | Medium; no invalid/extreme/parity vectors. |
| Taxi outlier/city split | Small in-memory happy dataset | Low-medium; no stale/future/duplicates/provider/timezone. |
| Client price manipulation | Emulator core integration | Good for overwritten amount; does not test quote/order parity. |
| Rapid destination changes | Missing | None. |
| Quote race / city switch during request | Missing | None. |
| GPS denied forever / service off / timeout | Service mapping only, no screen flow | Low. |
| App background/resume | Missing | None. |
| Zero/huge distance | Missing | None. |
| `getDeliveryQuote` auth, city mismatch and observation use | Missing | None. |
| Text scale 1.5/2.0, landscape, keyboard | Missing | None. |

The source-scanning tests for “delivery only” and centralized attribution are useful policy guards but do not prove runtime layout or behavior.

## 18. Device test reality

No physical test can be marked PASS from this audit. Only local static/unit/widget/emulator/debug-build results were produced.

### P0 before next feature work

1. Real Khujand GPS: cold start, last-known then fresh fix, poor/stale/timeout and location service off.
2. Drag map while fresh GPS is pending; confirm no camera takeover; explicit recenter works once.
3. Manual/simulated Dushanbe switch while a Khujand fresh fix/search/route is pending.
4. Route provider success, offline, timeout, 429/5xx and recovery; no price/CTA on failure.
5. Rapid A/B destination changes and city switch during route calculation; only latest route/quote survives.
6. Background/resume during location and route; verify native stream stop/restart and no camera jump.
7. Route fit with details panel and keyboard on small portrait and landscape.
8. API 36 profile-mode smoke: edge-to-edge, system navigation, back behavior, permissions and skipped frames.

### P1 before closed testing

1. Dushanbe address search, recent/saved places and both-city route corpus.
2. Permission denied and denied forever with settings return.
3. Ten map open/close and pause/resume cycles; listener/network/memory counts.
4. Text scale 1.3/1.5/2.0; TalkBack labels/order; 48 px target verification.
5. API 24 representative device plus API 33/35; slow network/cold tile cache.

### P2 before production

1. Broader device/OEM matrix, dark-system settings, rotation/process recreation.
2. Field validation of boundary points, bicycle route quality and ETA accuracy.
3. Production provider attribution, quota/outage telemetry and cost-alert smoke.

## 19. What can be fixed before Blaze

- Unify screen/controller state and add injectable delayed GPS/router/quote tests.
- Fix requested routing mode/profile behavior.
- Fix manual city ownership and selected-city search/recent/saved affinity.
- Add pricing finite/range validation and cross-language parity fixtures.
- Define taxi observation schema, timezone, recency, dedupe, provider balancing and confidence rules.
- Validate `getDeliveryQuote` city from coordinates.
- Add quote ID/version/expiry contract in source and emulator tests, even if deployment waits.
- Implement dynamic route-fit padding and accessibility/text-scale fixes.
- Run offline/emulator/widget tests and local profile tests that do not require live Functions.

## 20. What requires Blaze, provider, device or owner

| Dependency | Required work |
|---|---|
| Blaze/deploy | Activate Functions/Rules/indexes in an approved window; real quote/order smoke; logs/cost/alerts. |
| Routing/tile provider | Contract/SLA/quota/privacy/coverage decision; server-side road recomputation; both-city route corpus. |
| Owner/data | Lawful taxi observation acquisition, import approval, provider balance and data-quality ownership. |
| Physical devices | GPS, lifecycle, keyboard/layout, performance, API 36/predictive-back and multi-device validation. |
| Signing/legal | Production upload key and published/verified legal/support surfaces remain outside this audit. |

## 21. Recommended next implementation phase

**Phase 3A — Delivery Core Authority & Race Hardening (pre-Blaze).**

Order:

1. Establish one quote contract and make order creation revalidate/consume it; keep server road adapter pluggable.
2. Correct routing mode/profile semantics and build an injectable fake-provider test harness.
3. Replace implicit map booleans with one tested controller/generation model; fix manual city ownership and stream lifecycle race.
4. Align Dart/Functions pricing and taxi selection using shared parity fixtures, strict validation and city timezone rules.
5. Add city-affine saved/recent/search behavior, dynamic fit padding and accessibility/text-scale coverage.
6. Run the P0 physical test matrix. Stop again for audit/owner provider decision before deploy.

Do not start broad visual polish until these authority/race/device gates are closed.

## 22. GO / CONDITIONAL GO / NO-GO

- **Local code gates:** PASS.
- **Further bounded pre-Blaze remediation:** CONDITIONAL GO.
- **Closed testing:** NO-GO until P0/P1 authority/provider/device items and Blaze/signing prerequisites are resolved.
- **Production:** NO-GO.

## A. Phase 2 claims verification

| Phase 2 claim | Result | Audit conclusion |
|---|---|---|
| Delivery-only customer shell opens map | VERIFIED | Source and widget policy test confirm. |
| Khujand + Dushanbe centralized registry | VERIFIED | IDs/config/bounds exist and client/server values match. |
| Full multi-city user experience | PARTIAL | Dushanbe search/saved/recent affinity and broad hardcodes remain. |
| Fresh GPS cannot steal camera after gesture | PARTIAL | Code guard exists; real widget/device race untested; helper test is disconnected. |
| Stale/poor/timeout are finite states | PARTIAL | Explicit GPS path handles them; passive last-known stale age is not surfaced. |
| Map usable without GPS | VERIFIED | City fallback/manual map path continues without permission. |
| Location stream stops outside foreground | PARTIAL | Lifecycle cancellation exists; cancel/relisten race and device proof remain. |
| Stale route response cannot overwrite new | PARTIAL | Request ID guard exists; no delayed screen test. |
| No fake direct route unlocks quote/CTA | VERIFIED | `buildRoute` throws; route/price clear; CTA requires road route. |
| Timeout and bounded retry | VERIFIED | Per-attempt timeout and one retry for 429/5xx. |
| Correct bicycle routing profile | FAILED | Passed mode is ignored and profile override defaults to driving. |
| Central tiles and visible attribution | VERIFIED (pilot) | All current viewports/source guard pass; provider is not production-ready. |
| Customer cannot edit final price | VERIFIED | Field read-only; backend ignores manipulated client amount. |
| Flutter/backend pricing semantic parity | FAILED | Different route/reference/time/validation/confidence paths. |
| Backend authoritative quote readiness | FAILED | Price overwrite exists, but order path bypasses quote observations/road route. |
| Taxi reference engine ready | FAILED for production / PARTIAL prototype | Missing data, schema/time/recency/dedupe/provider controls and order integration. |
| Phase 2 automated gates | VERIFIED | 188 tests plus analyze/build/debug APK passed in this audit. |
| Physical device readiness | FAILED / NOT RUN | No device evidence, correctly not claimed as passed by the plan. |

## B. Next phase backlog

| Order | Priority | Backlog item | Exit evidence |
|---:|---|---|---|
| 1 | P0 | One authoritative quote/order contract with trusted road adapter, quote ID/version/expiry | Emulator tests prove preview/requote/order parity and manipulation rejection. |
| 2 | P0 | Owner selects production routing/tile path; explicit release configuration | Provider/legal/quota decision + both-city success/outage build evidence. |
| 3 | P0 | Run physical core matrix | Recorded Khujand/Dushanbe/GPS/race/lifecycle/API36 results. |
| 4 | P1 | Fix route mode/profile and dynamic fit padding | Request-builder tests + device-visible full route. |
| 5 | P1 | Unify map state/generations and fix city/GPS/stream races | Delayed fake-service widget/lifecycle tests. |
| 6 | P1 | Add selected-city affinity to search/recent/saved addresses | Khujand/Dushanbe widget and persistence tests. |
| 7 | P1 | Strict pricing/reference validation and timezone/parity fixtures | Same golden vectors pass in Dart and TypeScript. |
| 8 | P1 | Ordered, stale-safe, deduplicated, provider-balanced observation selector | Unit/import/index tests with malicious/extreme datasets. |
| 9 | P1 | Split rebuild boundaries and profile map | Rebuild/listener/network counters and profile trace on representative Android. |
| 10 | P2 | Accessibility, text scale, back flow and broader city hardcode cleanup | TalkBack/text-scale/landscape/API36 UX matrix. |

## Verification run

| Gate | Result |
|---|---|
| `flutter analyze` | PASS, 0 issues |
| `flutter test` | PASS, 116 tests |
| `functions: npm.cmd run build` | PASS |
| `functions: npm.cmd test` | PASS, 25 tests |
| Firestore Rules emulator | PASS, 17 tests (Android Studio JBR/OpenJDK 21) |
| Functions + Firestore integration emulator | PASS, 30 tests |
| Total automated tests | **188 PASS** |
| `flutter build apk --debug` | PASS |
| Debug APK size | 212,342,786 bytes |
| Debug APK SHA-256 | `14974B1FE2FB6D8EF4D35691E44BF39BFA7E091B5342549595C62C67CF95E7C5` |
| `git diff --check` | PASS |

Emulator note: the first Rules attempt stopped before tests because the shell defaulted to Java 17. Re-running with installed Android Studio JBR/OpenJDK 21 passed. Functions emulator warned that host Node 24 differs from requested Node 20; it still passed all 30 integration tests. This does not replace a Node 20 production-parity run.

Audit discipline: no deploy, Rules/Hosting deploy, push, dependency update, production keystore action, App Check enforcement, stash mutation or edit/stage of `android/app/google-services.json` occurred.

## Phase 3A follow-up note — 2026-08-05

Historical findings above are unchanged. Phase 3A remediation and its current closure
assessment are recorded in `PHASE3A_AUTHORITY_RACE_REPORT.md`; the outstanding physical
matrix is `PHASE3A_DEVICE_GATE.md`. Production remains NO-GO until the provider, Blaze
and device gates recorded there are completed.
