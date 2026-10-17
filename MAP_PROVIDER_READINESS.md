# Map Provider Readiness

## Pilot state

Every Flutter map uses centralized `MapProviderConfig.current` and displays
`OpenStreetMap contributors` attribution. The package User-Agent is centralized.
Public `tile.openstreetmap.org` remains marked `pilotOnly`; it is not treated as a
production SLA. The app does not prefetch/scrape tiles or hide attribution.

## Production requirements

- Select a tile provider/self-hosted stack whose usage terms allow TajGo traffic.
- Confirm coverage and label quality for Khujand and Dushanbe.
- Establish quota, caching, contactable identification, monitoring, cost alerts and
  outage fallback behavior.
- Review attribution placement on all device sizes and provider-specific wording.
- Keep credentials restricted; do not ship unrestricted server secrets in Dart.
- Run profile-mode pan/zoom, cold-cache, slow-network and offline device tests.

Production map readiness remains conditional on provider selection and physical QA.
