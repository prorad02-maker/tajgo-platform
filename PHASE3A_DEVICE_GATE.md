# TajGo Phase 3A — P0 Device Gate

Date prepared: 2026-08-05. Status: **NOT RUN**. No row may be marked PASS without a
recorded device, Android version, build hash, provider/config, network condition and
log excerpt. Use the Phase 3A debug APK; production authority additionally requires
the owner-approved server routing adapter and Blaze deployment.

| Scenario | SETUP | ACTION | EXPECTED | LOG MARKERS | PASS CRITERIA |
|---|---|---|---|---|---|
| Real GPS Khujand | Physical phone in Khujand; location on; cold app | Open Delivery and wait for last-known then fresh fix | Khujand remains active; fresh marker appears; camera moves only before gesture | `TAJGO_POINT_CONFIRMED`; Android location permission/service state | Correct city/fix; no crash, duplicate prompt or late camera jump |
| Manual/simulated Dushanbe | Phone/simulator reports Khujand; select Dushanbe | Search and select A/B in Dushanbe | Search is centered/bounded to Dushanbe; Khujand results do not leak in | routing request provider/mode; selected city screenshot | Both points in Dushanbe; no hidden city reversal |
| GPS denied | Fresh install; deny once | Tap locate, then continue with map | Actionable permission message; manual map remains usable | permission state `denied` | No loop; manual A/B still works |
| GPS denied forever | Deny permanently in OS settings | Tap locate and return from settings | Settings action appears; state recovers after grant | permission state `deniedForever` | No crash/blank screen; correct recovery |
| Services off | Permission granted; system location off | Tap locate, then enable service | Service action appears; explicit retry obtains fix | service state `serviceDisabled` | No false current location; retry succeeds |
| Poor/stale location | Inject >50 m accuracy and >2 min fix | Open Delivery and request location | Weak/stale state is not authoritative for automatic confirmation | accuracy/age diagnostic without coordinates | Warning/retry; no false pickup confirmation |
| Drag then recenter | Start fresh GPS request on slow fix | Drag map before completion; then tap locate | Late GPS does not take camera; explicit locate recenters once | map gesture + location completion timestamps | Camera ownership follows user then explicit action |
| Rapid destination A→B→C | Working pilot provider with delay injection | Select three destinations rapidly | Only C address, route and quote remain | route/quote request generations | No A/B polyline, price or CTA survives |
| Route failure/offline | Disable network or return timeout/429/5xx | Build route, retry after recovery | Route error and retry; no polyline, quote or enabled CTA while failed | routing health status/provider; no raw URL key | No geometric route masquerades as road authority |
| City switch with GPS in-flight | Delay Khujand fresh fix | Switch manually to Dushanbe before fix completes | Manual Dushanbe ownership wins | city ownership generation and GPS completion time | City/camera/search stay Dushanbe |
| City switch with route/quote in-flight | Delay route and quote | Switch city before either completes | Old work is discarded; A/B/route/quote reset | route/quote generations | No cross-city state or enabled CTA |
| Background/resume | Start GPS/route/quote | Pause 5–10 s, resume, repeat rapidly | In-flight writes are invalidated; no duplicate native stream/request | lifecycle state; request/listener counters | One active stream/listener; explicit retry works |
| Keyboard/bottom sheet | Small portrait and landscape; text scale 1.5/2.0 | Open search keyboard and details panel; show route | A/B and CTA reachable; route visible above measured panel | screenshots + overflow logs | No overflow, hidden route endpoints or trapped keyboard |
| API 36 profile smoke | Physical/emulated API 36 profile build | Run permission, A/B, back, pause/resume and offline flows | Edge-to-edge/back/permissions stable; no severe jank | `Choreographer`, ANR/crash, frame chart | No P0 functional issue; attach frame evidence |

Record results below this table with timestamp and evidence links. Until then the
device gate is **OUTSTANDING**.
