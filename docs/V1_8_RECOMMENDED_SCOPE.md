# TajGo — рекомендуемый scope v1.8

Дата: 26 июля 2026  
Основание: аудит фактической версии `1.5.0+30`.  
Это план, не реализованные изменения.

Цель v1.8: превратить собираемый product preview в безопасный, наблюдаемый и воспроизводимый closed-pilot build. В scope не следует включать новый визуальный редизайн или полноценный turn-by-turn до закрытия P0/P1.

## P0 — security boundary и корректность денег/заказа

### P0.1 Authoritative command backend

- Причина: все критические операции сейчас выполняются мобильным client SDK.
- Зависимость: Firebase Functions project setup, Node/TypeScript, agreed region.
- Риск: миграция может временно нарушить старый flow; нужен backward-compatible rollout.
- Сложность: `XL`.
- Scope:
  - callable `createOrder`;
  - `submitOffer`;
  - `selectOffer`;
  - `acceptOrder`;
  - `advanceOrder`;
  - `verifyDeliveryCode`;
  - `createCatalogOrder`;
  - admin resolution commands.
- Критерий готовности: клиент не может напрямую выполнить критический transition; каждая команда валидирует auth, role, ownership, current state и выполняет transaction.
- Тест: Functions unit + emulator integration + duplicate/retry/race suite.

### P0.2 Server-side radius and GPS eligibility

- Причина: правило `<1000 м` обходится modified client.
- Зависимость: P0.1, schema trusted location, server timestamp policy.
- Риск: stale/low-accuracy GPS может необоснованно блокировать честного courier.
- Сложность: `L`.
- Scope:
  - Haversine на backend;
  - strict `< 1000`;
  - max age/accuracy;
  - coordinate bounds;
  - App Check signal;
  - audit reason on rejection.
- Критерий готовности: forged distance field не влияет на решение.
- Тест: 0, 500, 998, 999, 999.99, 1000, 1001, 1500; stale/future timestamp; accuracy boundary; swapped lat/lng.

### P0.3 Secure delivery confirmation

- Причина: код читаем courier и не проверяется Rules.
- Зависимость: P0.1.
- Риск: lockout пользователя при плохой сети.
- Сложность: `M–L`.
- Scope:
  - server-generated challenge;
  - hash/secret вне courier-readable order;
  - callable verify;
  - attempts, expiration, rate limit;
  - client confirmation alternative;
  - admin recovery log.
- Критерий готовности: courier document/order response не содержит secret; completion без правильного code отклоняется backend.
- Тест: correct/wrong/expired/replayed code, attempts limit, foreign courier/customer.

### P0.4 Firestore Rules semantic test suite

- Причина: compile не доказывает authorization.
- Зависимость: P0.1–P0.3 define final access.
- Риск: слишком строгие Rules сломают realtime reads.
- Сложность: `L`.
- Scope: tests anonymous/customer/courier/admin/foreign для каждой collection и каждого state transition.
- Критерий готовности: deny-by-default; direct critical writes denied; permitted reads documented.
- Тест: emulator suite запускается в CI и имеет положительные/отрицательные cases.

### P0.5 Authoritative marketplace checkout

- Причина: item/price snapshot можно подделать.
- Зависимость: P0.1, catalog schema version.
- Риск: несовпадение цены при изменении товара во время checkout.
- Сложность: `L`.
- Scope:
  - server reads partner/products;
  - validates active/available/hidden/quantity;
  - calculates subtotal/fee/total;
  - writes immutable item snapshot;
  - idempotency key.
- Критерий готовности: клиент передаёт IDs/quantity, но не authoritative totals.
- Тест: changed/hidden/wrong partner/forged price/minimum/race/idempotent retry.

### P0.6 Atomic dispute and active-order reconciliation

- Причина: dispute может оставить courier busy; admin clear создаёт inconsistency.
- Зависимость: P0.1, final status machine.
- Риск: автоматическое освобождение courier до решения по товару.
- Сложность: `M–L`.
- Scope: explicit disputed policy, atomic courier/order updates, admin resolve outcomes, reconciliation function.
- Критерий готовности: для каждого non-active terminal state courier не застревает; order assignment остаётся согласованным.
- Тест: dispute at delivered/completed, retry, admin resolution, crash between operations.

## P1 — готовность двух телефонов

### P1.1 Final state machine specification

- Причина: enum, Firestore aliases, UI и admin transitions расходятся.
- Зависимость: product decision.
- Риск: migration старых documents.
- Сложность: `M`.
- Scope: canonical persisted statuses, transition table, actor, required timestamps, terminal semantics, legacy mapping.
- Критерий готовности: один документ и одна server implementation; unknown status quarantined.
- Тест: every allowed/forbidden transition, legacy fixtures.

### P1.2 Protected admin entry and operations

- Причина: admin code недостижим.
- Зависимость: backend role claims/profile and P0 Rules.
- Риск: случайное раскрытие admin navigation.
- Сложность: `M–L`.
- Scope: admin startup route/profile entry, guard, re-auth for dangerous actions, order/app/catalog/log views.
- Критерий готовности: admin видит admin home; non-admin не может открыть route или repository action.
- Тест: customer/courier/admin navigation and direct deep-link attempts.

### P1.3 Idempotency and uncertain-result recovery

- Причина: timeout/retry может дублировать order/checkout.
- Зависимость: P0.1.
- Риск: operation keys retained too short/long.
- Сложность: `M`.
- Scope: stable UUID persisted before command, server result replay, UI recovery/query by request id.
- Критерий готовности: 10 identical concurrent/repeated requests create one logical operation.
- Тест: timeout after commit, airplane-mode toggle, app restart, double tap.

### P1.4 Phone Auth field validation

- Причина: текущая реализация не проверена на Android.
- Зависимость: Firebase Console owner action and release/debug SHA.
- Риск: SMS quota/reCAPTCHA/OEM differences.
- Сложность: `M`.
- Scope: test numbers, real test number, resend, auto verification, conflict/link, sign-out/sign-in, safe errors.
- Критерий готовности: repeatable checklist passes on two Android devices.
- Тест: new/existing user, expired code, wrong code, no network, quota error.

### P1.5 GPS and two-phone E2E

- Причина: map/location is code-tested only.
- Зависимость: safe Rules deploy, test accounts.
- Риск: lifecycle/OEM battery behavior.
- Сложность: `M–L`.
- Scope: permission states, service disabled, stream online/offline, `courier_public`, restart/background, location staleness.
- Критерий готовности: customer sees courier movement; courier target switches A→B; no duplicate streams.
- Тест: physical movement or controlled mock location on two devices.

### P1.6 Index audit and controlled Firebase deployment

- Причина: local/deployed index drift.
- Зависимость: final queries.
- Риск: unnecessary indexes add cost, missing index breaks screen.
- Сложность: `S–M`.
- Scope: query inventory, emulator/real query smoke, rules/index diff, owner-approved deploy.
- Критерий готовности: every production query succeeds; deployed config hash recorded.
- Тест: all list/filter/order screens with representative dataset.

## P2 — закрытый пилот: надёжность и операции

### P2.1 FCM notifications

- Причина: background users miss events.
- Зависимость: Functions, privacy payload design.
- Риск: stale tokens and sensitive payload.
- Сложность: `L`.
- Scope: token rotation, per-user delivery, offer selected/order status/admin alert, foreground/background/tap.
- Критерий готовности: no phone/code/address in notification body unless explicitly approved; delivery metrics available.
- Тест: app foreground/background/terminated, token refresh, signed-out user.

### P2.2 App Check staged rollout

- Причина: modified clients/scripts remain a threat.
- Зависимость: release signing, Functions/Firestore supported clients.
- Риск: enforcement can lock out testers.
- Сложность: `M`.
- Scope: debug provider for dev, Play Integrity for release, monitoring, allowlist plan, later enforcement.
- Критерий готовности: legitimate build metrics clean; invalid requests visible/blocked in staged phase.
- Тест: valid release token, debug setup, missing/invalid token.

### P2.3 Release signing and reproducible artifacts

- Причина: current release APK is debug-signed.
- Зависимость: owner-generated keystore and secure storage.
- Риск: key loss permanently breaks updates.
- Сложность: `M`.
- Scope: ignored secrets, CI signing, AAB/APK, checksums, version/tag/release notes, upgrade test.
- Критерий готовности: release cert is not Android Debug; artifact reproducible and install-upgrade works.
- Тест: clean machine build, signature verify, install then upgrade.

### P2.4 Operational observability

- Причина: no visibility into failures/stuck orders.
- Зависимость: privacy agreement.
- Риск: collection of phone/location PII.
- Сложность: `L`.
- Scope: Crashlytics with redaction, Functions structured logs, metrics for auth/order/status/notification, stuck-order alert.
- Критерий готовности: owner can identify and correlate failure without seeing secret/code/full phone.
- Тест: injected client crash/function error/stuck order triggers expected signal.

### P2.5 Data inventory and migration

- Причина: legacy aliases and unknown statuses.
- Зависимость: canonical P1 state schema.
- Риск: incorrect rewrite of live orders.
- Сложность: `M–L`.
- Scope: export/backup, read-only report, dry-run, quarantine, versioned migration, rollback.
- Критерий готовности: all documents classified; migration repeatable; unknowns not shown as waiting.
- Тест: fixture corpus from every historical schema.

### P2.6 Support/admin runbook

- Причина: pilot needs rapid recovery.
- Зависимость: protected admin and observability.
- Риск: over-privileged manual actions.
- Сложность: `M`.
- Scope: dispute, stuck courier, duplicate order, bad catalog, user access, rollback, incident log.
- Критерий готовности: trained owner resolves scripted incidents with audit trail.
- Тест: tabletop incident rehearsal.

## P3 — production hardening

### P3.1 Production routing decision

- Причина: public OSRM pilot endpoint has no SLA and profile mismatch.
- Зависимость: cost/privacy/provider choice.
- Риск: route outage or bad bicycle ETA.
- Сложность: `L–XL`.
- Scope: own/provider endpoint, correct profiles, quotas, caching, fallback, privacy and monitoring.
- Критерий готовности: release config explicit; fallback does not block order; provider load/SLA accepted.
- Тест: Khujand route set, timeout/400/429/5xx, off-route rebuild.

### P3.2 Security/privacy review

- Причина: phone and live location are personal data.
- Зависимость: final backend/data retention.
- Риск: regulatory and trust exposure.
- Сложность: `L`.
- Scope: least-privilege fields, retention/deletion, consent, privacy notice, admin access audit, incident response.
- Критерий готовности: approved data map and retention policy implemented.
- Тест: access/delete/export and unauthorized read suite.

### P3.3 CI quality gates

- Причина: current checks are manual and tags drift.
- Зависимость: tests from P0/P1.
- Риск: slow pipeline.
- Сложность: `M`.
- Scope: format/analyze/unit/functions/rules/build/signature/dependency scan, protected release workflow.
- Критерий готовности: failing security test blocks merge/release.
- Тест: intentionally broken rule/function/build fails CI.

### P3.4 Secret hygiene

- Причина: ignore patterns incomplete.
- Зависимость: signing/backend setup.
- Риск: accidental credential commit.
- Сложность: `S–M`.
- Scope: ignore rules, secret scanner, local examples, rotation procedure.
- Критерий готовности: known secret fixtures are rejected; no real secret tracked.
- Тест: scanner/pre-commit negative fixture.

## P4 — после стабильного пилота

### P4.1 Catalog media pipeline

- Причина: current images are URL-only.
- Зависимость: Storage/CDN/moderation decision.
- Риск: untrusted or unavailable external URLs.
- Сложность: `L`.
- Критерий готовности: upload, resize, moderation, lifecycle and fallback tested.

### P4.2 Full turn-by-turn and courier UX

- Причина: current MVP shows route/ETA and opens external navigator.
- Зависимость: P3 routing provider.
- Риск: high scope and driver-safety concerns.
- Сложность: `XL`.
- Критерий готовности: only after road routing reliability and field UX research.

### P4.3 Product analytics and growth

- Причина: useful after operational stability.
- Зависимость: privacy review and Analytics decision.
- Риск: premature metrics and PII.
- Сложность: `M–L`.
- Критерий готовности: event dictionary, consent and dashboards reviewed.

### P4.4 Dead-code cleanup and modularization

- Причина: 19 files are unreachable by static graph; some may be intentionally staged.
- Зависимость: admin route decision.
- Риск: deleting future/admin code accidentally.
- Сложность: `M`.
- Критерий готовности: reachability verified by tests; each removed artifact has no product owner.

## Рекомендуемый порядок релиза

1. Зафиксировать canonical schemas/state machine.
2. Реализовать authoritative Functions commands.
3. Переписать Rules на запрет direct critical writes и покрыть emulator tests.
4. Добавить server radius, code verification и catalog checkout.
5. Подключить защищённую админку и reconciliation.
6. Провести migration dry run.
7. Controlled deploy Rules/Functions/indexes только с подтверждением владельца.
8. Два телефона: Auth/GPS/order/race/offline.
9. Добавить FCM, App Check monitoring, observability.
10. Release signing, AAB, upgrade/rollback test.
11. Ограниченный closed pilot с kill switch.
12. После пилота решать production routing, media и advanced navigation.

## Definition of Done v1.8

v1.8 можно считать pilot-ready только если одновременно:

- все P0 завершены и имеют automated negative tests;
- P1 field test пройден на двух физических Android;
- deployed Rules/Functions/indexes зафиксированы и совпадают с repository;
- release artifact подписан production key;
- нет известных BLOCKER/CRITICAL;
- owner имеет admin/support recovery path;
- data migration и rollback воспроизводимы;
- observability показывает ошибки без утечки phone/code/location;
- GO/NO-GO документ обновлён фактическими evidence, а не только кодовым review.
