# Архитектура TajGo v1.0

Единый архитектурный документ приложения. Заменяет разрозненные FOUNDATION_V*-заметки
(они остаются как история версий). Архитектура карты описана отдельно в
[MAP_ARCHITECTURE.md](MAP_ARCHITECTURE.md).

## 1. Что за приложение

TajGo — сервис доставки для Худжанда. Два типа пользователей в одном приложении:

- **Клиент** — создаёт заказ (откуда, куда, тип, цена), следит за статусом.
- **Курьер** — выходит на линию, видит ожидающие заказы в реальном времени,
  принимает или отклоняет их.

Бэкенд — Firebase: анонимная авторизация (Auth), данные и realtime-обновления (Firestore).
Карта — flutter_map (OpenStreetMap), без Google-зависимостей.

## 2. Принципы

1. **Feature-first.** Код группируется по фичам (`features/courier`, `features/map`),
   а не по типам файлов. Экран, его виджеты и локальная логика живут рядом.
2. **UI не ходит в Firebase напрямую.** Все обращения к Auth/Firestore — только через
   сервисы и репозитории в `core/services`. Экран получает их через `TajGoScope`.
3. **Firestore — источник истины.** Экраны подписываются на стримы (`snapshots()`),
   а не кэшируют состояние локально. Realtime «из коробки».
4. **Карта — переиспользуемый модуль**, не экран. В базе хранятся только бизнес-данные
   поверх карты (координаты, зоны, маршруты) — см. MAP_ARCHITECTURE.md.
5. **Простота важнее паттернов.** Пока хватает `StatefulWidget` + `StreamBuilder` +
   `InheritedWidget` — не тащим Bloc/Riverpod. Точка пересмотра описана в §8.

## 3. Слои и структура каталогов

```text
lib/
  main.dart                  # только bootstrap: Firebase.initializeApp + runApp
  firebase_options.dart      # сгенерирован flutterfire configure (не редактировать)

  app/                       # сборка приложения
    tajgo_app.dart           # MaterialApp, тема, стартовый экран
    tajgo_theme.dart         # единственная тема приложения

  core/                      # общая логика без UI
    constants/
      tajgo_colors.dart      # единственный источник цветов
    models/                  # доменные модели: AppUser, Courier, Order
    services/                # доступ к Firebase
      auth_service.dart      # Firebase Auth (анонимный вход)
      user_repository.dart   # коллекция users
      courier_repository.dart# коллекции couriers + orders (курьерская сторона)
      order_repository.dart  # коллекция orders (клиентская сторона) — план

  features/                  # экраны, сгруппированные по фичам
    splash/                  # bootstrap-экран: вход + профиль → RoleScreen
    role/                    # выбор роли клиент/курьер
    customer/                # сторона клиента (создание заказа, статус)
    courier/                 # сторона курьера (линия, лента заказов)
    map/                     # модуль карты (см. MAP_ARCHITECTURE.md)

  shared/                    # переиспользуемый UI без бизнес-логики
    widgets/
      tajgo_scope.dart       # DI-контейнер (InheritedWidget)
      tajgo_logo.dart        # и прочие общие виджеты
```

Правила зависимостей между слоями:

```text
app ──► features ──► core, shared
              │
shared ───────┘ (shared не знает о features; core не знает об UI вообще,
                 исключение — tajgo_scope.dart, он живёт в shared и собирает core-сервисы)
```

- `core` не импортирует Flutter-виджеты (кроме `foundation`).
- `features/*` не импортируют друг друга напрямую; общее выносится в `core`/`shared`.
- Единственная точка, знающая про Firebase-инстансы, — `TajGoScope`.

## 4. Внедрение зависимостей: TajGoScope

`TajGoScope` (lib/shared/widgets/tajgo_scope.dart) — `InheritedWidget` над `MaterialApp`,
создаёт сервисы один раз и раздаёт их экранам:

```dart
final scope = TajGoScope.of(context);
scope.authService / scope.userRepository / scope.courierRepository
```

Зачем так: экраны тестируемы (сервису можно подсунуть фейковый Firestore),
нет глобальных синглтонов, нет пакета-DI. Новый сервис = поле в `TajGoScope`.

## 5. Навигация и жизненный цикл

Дизайн приложения — «Платформа TG+» (утверждён): главная клиента — витрина
платформы с модулями сервисов («Доставка» активна, «Такси»/«Кошелёк» — «скоро»).
Отдельного экрана выбора роли нет: режим курьера открывается модулем
«Стать курьером» с главной. Следующая итерация дизайна — «Живая карта»
(карта города как главный экран, см. MAP_ARCHITECTURE.md).

```text
SplashScreen ──(анонимный вход + ensureUser, таймаут 10с)──► CustomerHomeScreen
                                                              (главная-платформа:
                                                               заказ, статус, модули)
                                                                    │ «Стать курьером»
                                                                    ▼
                                                             CourierHomeScreen
                                                             (тумблер «на линии»,
                                                              лента waiting-заказов)
```

- Навигация — обычный `Navigator` с `MaterialPageRoute`. Роутер-пакет (go_router)
  понадобится только при появлении диплинков/веба — не раньше.
- Splash обязан завершаться всегда: каждый await — с `.timeout()`, ошибка показывается
  текстом на экране (урок Foundation v5 про зависания).

## 6. Модель данных Firestore

### users/{uid}
| Поле | Тип | Описание |
|---|---|---|
| uid | string | = Auth uid |
| name | string | имя |
| role | string | `customer` \| `courier` |
| city | string | город (пока `Худжанд`) |
| createdAt | timestamp | создание |

### couriers/{uid}
| Поле | Тип | Описание |
|---|---|---|
| uid | string | = Auth uid |
| name, city | string | профиль |
| online | bool | на линии |
| rating | number | рейтинг |
| score | number | внутренние баллы |
| transport | string | `electric_bike` и т.п. |
| earningsToday | number | заработок за день |
| location | geopoint | позиция (план, для карты) |
| updatedAt | timestamp | серверное время |

### orders/{orderId}
| Поле | Тип | Описание |
|---|---|---|
| status | string | см. машину состояний ниже |
| type | string | `package` и т.п. |
| city | string | город |
| fromText / toText | string | адреса текстом |
| fromLocation / toLocation | geopoint | координаты (план) |
| price, currency | number, string | цена, `TJS` |
| distanceKm, etaMinutes | number | оценка |
| customerName / customerId | string | клиент |
| courierId | string? | назначенный курьер |
| createdAt / acceptedAt / updatedAt | timestamp | серверное время |

### Машина состояний заказа

```text
waiting ──accept──► accepted ──► pickedUp ──► delivered
   │                    │
   └──decline/timeout──►└──cancel──► cancelled
```

Правила: статус меняется только вперёд по стрелкам; каждая смена пишет `updatedAt`;
`accepted` обязан содержать `courierId`. Сейчас реализованы `waiting → accepted/declined`,
остальное — план.

## 7. Потоки данных

Один шаблон на все realtime-экраны:

```text
Firestore snapshots() ──► Stream в репозитории ──► StreamBuilder в экране ──► UI
Действие пользователя ──► метод репозитория (update/set) ──► Firestore ──► стрим сам обновит UI
```

После записи ничего не «перерисовываем вручную» — обновление приходит через подписку.

## 8. Состояние: когда усложнять

Сейчас: `setState` для локального UI-состояния, `StreamBuilder` для данных,
`TajGoScope` для сервисов. Этого достаточно.

Переходить на Riverpod (предпочтительно) стоит, только когда появится любое из:
- состояние, разделяемое между 3+ экранами (корзина, активный заказ клиента);
- комбинирование нескольких стримов с бизнес-логикой (матчинг заказ↔курьер на клиенте);
- необходимость unit-тестировать логику отдельно от виджетов.

До этого момента — не добавлять.

## 9. Безопасность (обязательно до продакшена)

- Анонимный Auth — временно. План: телефонная авторизация (SMS), анонимный аккаунт
  апгрейдится через `linkWithCredential`.
- Firestore rules сейчас открыты для теста. Минимальные правила перед публикацией:
  - `users/{uid}`, `couriers/{uid}` — запись только владельцем (`request.auth.uid == uid`);
  - `orders` — создание любым авторизованным; `accept` — только сменой
    `waiting → accepted` с установкой `courierId == request.auth.uid`;
  - никаких клиентских записей в чужие документы.
- Захардкоженные данные (`name: 'Рахимджон'` в CourierRepository.setOnline) заменить
  на данные профиля из `users`.

## 10. Миграция: что удалить

В репозитории осталась мёртвая структура от Foundation ≤ v4 — она не импортируется
активным кодом (`main → app → features`) и только мешает:

- `lib/screens/` — все экраны (заменены `lib/features/*`);
- `lib/services/` — auth_service, tajgo_firestore_service (заменены `lib/core/services/`);
- `lib/widgets/` — все виджеты (актуальные — в `lib/shared/widgets/`);
- `lib/models/tajgo_order.dart` — заменить на модель в `lib/core/models/`;
- `lib/core/theme/` — дубликат, актуальная тема в `lib/app/tajgo_theme.dart`,
  цвета в `lib/core/constants/tajgo_colors.dart`.

После удаления: `flutter analyze` должен быть чистым.

## 11. Дорожная карта

**Итерация 1 — «Реальный поток заказа» + дизайн «Платформа TG+»** —
✅ выполнена и проверена 12.07.2026 (спека: SPEC_CODEX_V1.md + SPEC_CODEX_V1_FIXES.md).

**Итерация 2 — «Живая карта»** — ✅ выполнена и проверена 12.07.2026
(спека: SPEC_CODEX_V2.md): заказ через карту с пин-выбором и геокодированием,
расчёт км/мин/цены (pricing.dart), geopoint-координаты заказа, трансляция
позиции курьера, светлый сплэш с пейзажем (CustomPainter).

**Итерация 3 — «Курьер: карта, навигация, честная передача»**
(детальная спека: SPEC_CODEX_V3.md):

1. Экран активного заказа курьера с картой: живая позиция, пины A/B,
   кнопка «Навигатор» (url_launcher → внешние карты).
2. Гео-гейт 2 км: «Забрал»/«Передал» только рядом с точкой.
3. Подтверждение получения: 4-значный код клиента (как Uber Eats/DoorDash)
   или кнопки «Получил»/«Не получил» у клиента; статусы completed/disputed.
4. Правило «один активный заказ»: couriers.activeOrderId, курьер заблокирован
   до подтверждения клиента; заработок начисляется только на completed.

**Дальше:**

9. Firestore rules (§9) и телефонная авторизация.
10. Шрифт Manrope (у Poppins из бренд-бука нет кириллицы), тёмная тема на #0F172A.
11. Маршруты через OSRM/GraphHopper (см. MAP_ARCHITECTURE.md).
12. Модули платформы: «Такси», «Кошелёк».
