# TajGo v1.8 — Единая дизайн-система

Статус: реализована (Part 2, этап 2). Аддитивно — существующие экраны продолжают работать, миграция на компоненты идёт по мере доработки каждого экрана.

## Принципы

- Светлый фон, тёмный основной текст (ink), фирменный зелёный для главных действий, lime — только акцент.
- Радиусы 16–20 для основных поверхностей, сетка отступов 8 px, переходы 200–300 мс, минимальные мягкие тени.
- Одна основная кнопка действия на экран. Touch target ≥ 48.
- Цены — в сомони (никакого сырого TJS/₽/$ в интерфейсе).
- Смысл статуса кодируется текстом (и иконкой), не только цветом.

## Токены — `lib/core/design/`

Единая точка импорта: `import 'package:tajgo/core/design/tajgo_design.dart';`

| Токен | Файл | Значения |
|---|---|---|
| `TajGoColors` | `core/constants/tajgo_colors.dart` | green `#16A34A`, darkGreen `#15803D`, lime `#84CC16`, mint `#DCFCE7`, background `#F4F9F3`, ink `#12301E`, muted, error, warning, success |
| `TajGoTypography` | `tajgo_typography.dart` | display 28/w900, title 20/w800, subtitle 17/w700, body 15/w500, bodyStrong 15/w700, caption 13, label 12, button 16/w800; `toTextTheme()` |
| `TajGoSpacing` | `tajgo_spacing.dart` | xxs 2, xs 4, sm 8, md 12, lg 16, xl 20, xxl 24, xxxl 32; `screenH/screenV` 16, `touchTarget` 48 |
| `TajGoRadius` | `tajgo_radius.dart` | xs 8, sm 12, md 16, lg 20, xl 28, pill 999; `*All` helpers, `sheetTop` |
| `TajGoDurations` | `tajgo_durations.dart` | fast 120, base 200, medium 250, slow 300 |
| `TajGoShadows` | `tajgo_shadows.dart` | none, sm, md, lg, bar (ink-tinted, мягкие) |
| `TajGoIconSizes` | `tajgo_icon_sizes.dart` | sm 16, md 20, lg 24, xl 32, hero 48 |
| `TajGoMoney` | `tajgo_money.dart` | `format(num)` → «15 сомони» / «12,5 сомони»; `amount(num)` |

Тема `TajGoTheme.light` (`app/tajgo_theme.dart`) применяет `TextTheme` из токенов, фирменные кнопки (lime), карточки (radius 20), app bar без тени. Только light-режим; dark не ломает приложение (тема одна).

## Компоненты — `lib/shared/design/`

Единая точка импорта: `import 'package:tajgo/shared/design/tajgo_components.dart';` (реэкспортирует и токены).

| Компонент | Назначение |
|---|---|
| `TajGoScaffold` | фирменный фон, safe area, опциональная закреплённая нижняя панель (`bottomBar`) |
| `TajGoAppBar` | компактный app bar, реализует `PreferredSizeWidget` |
| `TajGoPrimaryButton` | основная кнопка (lime, ink), иконка, состояние загрузки, `expand` |
| `TajGoSecondaryButton` | вторичная кнопка (приглушённый зелёный) |
| `TajGoCard` | белая карточка, тень, radius 20, `onTap`, `accent` (mint) |
| `TajGoSectionHeader` | заголовок секции + действие справа |
| `TajGoSearchField` | поиск товаров/магазинов (не адресов), `readOnly`-режим-кнопка |
| `TajGoPrice` | цена в сомони + опциональная старая (зачёркнутая) |
| `TajGoStatusChip` | чип статуса, tone: neutral/info/success/warning/danger |
| `TajGoEmptyState` | пустое состояние (иконка/заголовок/действие) |
| `TajGoErrorState` | дружелюбная ошибка + «Повторить» (без технических деталей) |
| `TajGoLoadingSkeleton` / `TajGoCardSkeleton` | скелетоны загрузки |
| `TajGoOfflineBanner` | полоса «нет сети» |
| `showTajGoBottomSheet` | единый bottom sheet (скруглённый верх, ручка) |
| `showTajGoConfirmation` | единое подтверждение действия (в т.ч. destructive) |

## Среда и флаги — `lib/core/config/`

- `AppEnvironment` (`app_environment.dart`): `debug` / `pilot` / `production`. Определяется `--dart-define=TAJGO_ENV=...`; по умолчанию debug в debug-сборке, иначе production.
- `FeatureFlags` (`feature_flags.dart`): `marketplace`, `customPrice`, `merchantApplications`, `notifications`, `crashReporting`, `diagnostics`, `adminImport`, `previewData`, `appCheck`, `publicPilotRouting`, `demoTools` (только debug), `anonymousDemoLogin` (только debug). Каждый флаг переопределяется через `--dart-define` (например `TAJGO_FF_NOTIFICATIONS`, `TAJGO_ROUTING_ENABLED`).
- Доступ из UI: `TajGoScope.of(context).featureFlags`.

Правило релиза: незавершённая функция либо закончена, либо выключена флагом. Demo Tools и anonymous-вход недоступны вне debug.

## Наблюдаемость и App Check (за флагами, graceful)

- `CrashReportingService` (`crashReporting`): подключает `FlutterError.onError` и `PlatformDispatcher.onError` к Crashlytics. Не логирует код получения/телефон/адрес/токены. При отсутствии настройки — тихий no-op.
- `AppCheckService` (`appCheck`): активирует attestation provider (debug в debug-сборке, Play Integrity / App Attest иначе). **Enforcement не включается в коде** — только в Console после rollout.
- Инициализация — в `main.dart` внутри `runZonedGuarded`; отсутствие Console-настройки не роняет запуск.

## Правило миграции

Новые и переработанные экраны используют компоненты дизайн-системы и токены вместо ad-hoc `Scaffold`/`AppBar`/`Card` и магических чисел. Существующие READY-экраны переводятся при плановой доработке, а не массовым рефактором.
