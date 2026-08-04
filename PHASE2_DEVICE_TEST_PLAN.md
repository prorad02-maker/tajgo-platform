# Phase 2 Android Device Test Plan

These tests have not been claimed as passed. Run on physical Android devices, including
an API 36 profile-mode smoke, and record device/build/network/provider evidence.

## City and location

- Khujand real GPS: cold start, last-known location then fresh fix, service bounds.
- Dushanbe simulated GPS and manual city switch; restart persistence.
- Permission denied, denied forever, location service off, timeout and temporary loss.
- Poor/stale GPS: warning/action, no false authoritative pickup.
- Drag map then receive GPS: camera stays user-owned; location button recenters once.
- Outside both service areas: clear message, manual city choice, no crash.

## Selection, route and quote

- Pickup/dropoff via center pin, search, recent and saved addresses.
- Rapid destination changes: only newest reverse-geocode/route appears.
- Routing timeout, 429/5xx, offline and recovery; no fake road polyline/price.
- Route fit with bottom sheet, keyboard open/closed and small/large screens.
- Route distance/ETA and preliminary price; no provider, multiplier or margin exposed.
- Order submit disabled until a road route/quote exists.

## Lifecycle/performance

- Background/resume during locating, selection, route-ready and active courier order.
- Confirm GPS stream stops/reduces outside foreground and resumes without camera jump.
- Ten open/close cycles; inspect listeners, memory, network duplication and skipped
  frames in profile mode.
- API 24 representative device plus API 33/35 and API 36 smoke.
