# TajGo Routing Provider Plan

## Current pilot

`RouteService` exposes one UI-independent route contract through `RouteProvider` and
`TajGoRoute`: geometry, road distance, duration, provider name, quality and navigation
steps. `RoutingConfig` has one canonical rollout flag, `TAJGO_ROUTING_ENABLED`, plus
provider/base URL/profile/timeout configuration. OSRM and GraphHopper parsers remain
pilot adapters. The endpoint is not embedded in widgets.

Provider calls have a timeout and one bounded retry for HTTP 429/5xx. UI request
generations prevent an older response from replacing a newer route. Failures now map
to an explicit unavailable/retry state. A direct line is available only as an internal
diagnostic baseline: it is not drawn as a road route and cannot unlock customer quote
or order submission.

## Production risks

- Public OSRM has no TajGo SLA, quota commitment, regional coverage guarantee or
  contractual support.
- Road profiles for bicycle/scooter in Khujand and Dushanbe require field validation.
- Client-side provider keys are extractable; paid provider credentials need a
  restricted server/proxy integration.
- Outages, 429 handling, attribution, privacy and retention terms need owner review.

## Future provider options

Evaluate an authorized commercial routing API, a managed/self-hosted OSRM/Valhalla
deployment, or another provider with Tajikistan coverage. Compare route quality,
bicycle support, latency, SLA, price, data processing terms and attribution. This
document does not select or connect a paid provider.

## Migration

1. Owner selects provider and commercial/privacy terms.
2. Add a server-side adapter implementing the existing route result contract.
3. Keep secrets outside the APK; add quotas, health probes and redacted telemetry.
4. Validate a Khujand/Dushanbe route corpus and outage behavior.
5. Enable in a controlled build, run physical device/profile tests, then remove the
pilot adapter only after parity is demonstrated.

## Phase 3A capability contract

The requested transport mode is now passed through unchanged. Khujand and Dushanbe
select `bicycle` from `ServiceAreaRegistry`; GraphHopper maps it to `bike`, while an
OSRM adapter maps it to the configured bicycle profile. A provider must explicitly
declare supported modes. The public `router.project-osrm.org` configuration is treated
as driving-only: a bicycle request returns an unsupported/degraded result and is never
silently changed to `driving`.

This remains a pilot limitation, not production readiness. Production authority still
requires an owner-approved server-side route adapter, a documented bicycle-capable
profile, both-city corpus results, quotas/SLA/privacy review and device outage tests.
