# TajGo — Spec v1.1 для реализации: «Реальный поток заказа» + дизайн «Платформа TG+»

Это самодостаточное техническое задание. Выполняй его по порядку, раздел за разделом.
Общая архитектура проекта описана в `docs/ARCHITECTURE.md` — прочитай её перед началом.

Изменения v1.1 против v1.0: выбран дизайн «Платформа TG+» (раздел 5), тип заказа
`taxi` заменён на `docs`, экран выбора роли удаляется — вход всегда в клиентскую
главную, режим курьера открывается модулем с главной.

---

## 1. Контекст

TajGo — Flutter-приложение доставки для города Худжанд (Таджикистан).
Позиционирование: **платформа городских сервисов**, где сейчас работает только
доставка, а такси и кошелёк появятся позже (на главной они уже анонсированы
бейджем «скоро»). Две роли: **клиент** (создаёт заказ) и **курьер** (выходит на
линию, принимает заказы).
Бэкенд — Firebase: анонимный Firebase Auth + Cloud Firestore (realtime через
`snapshots()`). Язык интерфейса — русский. Валюта — TJS (сомони).

### Что уже работает

- `main.dart` → `app/tajgo_app.dart` → `features/splash` → `features/role` →
  `features/customer` / `features/courier`.
- DI через `lib/shared/widgets/tajgo_scope.dart` (`InheritedWidget`, отдаёт
  `authService`, `userRepository`, `courierRepository`). Экраны получают сервисы
  только через `TajGoScope.of(context)` — это правило проекта.
- Splash: анонимный вход + создание демо-пользователя в `users/{uid}`, с таймаутами.
- Курьер: тумблер «на линии» (`couriers/{uid}.online`), лента заказов со статусом
  `waiting` (StreamBuilder), кнопки «Принять» / «Отказаться», кнопка «Создать
  тестовый заказ».
- Клиент: статический экран-витрина без функциональности.

### Ключевые проблемы

Поток заказа — демо: клиент не может создать настоящий заказ, у заказа нет
жизненного цикла после `accepted`, «Отказаться» убивает заказ для всех курьеров,
в коде захардкожено имя пользователя. Дизайн экранов не соответствует
утверждённому направлению «Платформа TG+».

---

## 2. Цель этой итерации

Рабочий сквозной сценарий на одном устройстве, в новом дизайне:

> Клиент на главной-платформе жмёт «Заказать доставку» → заполняет форму (откуда,
> куда, тип, цена) → видит карточку «Ищем курьера» → переключается в режим курьера,
> выходит на линию, принимает заказ → отмечает «Забрал» → «Доставил» → в клиентском
> режиме заказ показан как «Доставлено», заработок курьера за день вырос на цену заказа.

---

## 3. Жёсткие ограничения

1. **Не добавлять новые pub-пакеты.** Только то, что уже в `pubspec.yaml`
   (firebase_core, firebase_auth, cloud_firestore, flutter_map, latlong2,
   geolocator, permission_handler). Шрифты не подключать — системный.
2. **Не трогать** `lib/firebase_options.dart`, `firebase.json`,
   `android/app/google-services.json`.
3. **Не вводить** Bloc/Riverpod/Provider/go_router. Состояние — `setState` +
   `StreamBuilder`; зависимости — через `TajGoScope`; навигация — `Navigator` +
   `MaterialPageRoute`.
4. UI-обращения к Firestore/Auth — только через репозитории в `lib/core/services/`.
   Экраны не импортируют `cloud_firestore` напрямую (модели — можно, им нужны
   `DocumentSnapshot`/`Timestamp`).
5. Все записи времени — `FieldValue.serverTimestamp()`.
6. Комментарии и строки UI — на русском. Стиль кода — как в существующих файлах.
7. Карта (`lib/features/map/`) в этой итерации **не подключается** — не трогать
   и не удалять: следующая итерация («Живая карта») построена на ней.

---

## 4. Задачи

### Задача 0. Удалить legacy-код

Следующие файлы/папки — мёртвый код от старых версий, ниоткуда не импортируются
активной веткой (`main → app → features`). Удалить целиком:

- `lib/screens/` (вся папка)
- `lib/services/` (вся папка)
- `lib/widgets/` (вся папка)
- `lib/models/` (вся папка)
- `lib/core/theme/` (дубликат: актуальная тема — `lib/app/tajgo_theme.dart`,
  цвета — `lib/core/constants/tajgo_colors.dart`)

Дополнительно в этой итерации удаляется `lib/features/role/` — выбор роли
заменяется модулем «Режим курьера» на главной (Задача 6).

После удаления `flutter analyze` не должен показывать ошибок.

### Задача 1. Типизированные модели в `lib/core/models/`

Сейчас экраны работают с сырыми `Map<String, dynamic>`. Создать модели:

**`lib/core/models/tajgo_order.dart`** — класс `TajGoOrder`:

```dart
enum OrderStatus { waiting, accepted, pickedUp, delivered, cancelled }
// хранение в Firestore строками: 'waiting', 'accepted', 'pickedUp', 'delivered', 'cancelled'
// неизвестная строка при чтении → waiting (защита от старых документов)
```

Поля: `id`, `customerId`, `customerName`, `courierId` (nullable), `status`
(enum), `type` (String, см. список типов ниже), `city`, `fromText`, `toText`,
`price` (num), `currency` (String, `'TJS'`), `distanceKm` (num?), `etaMinutes`
(int?), `declinedBy` (List\<String\>, по умолчанию пустой), `createdAt`,
`acceptedAt`, `updatedAt` (DateTime?, из Timestamp).

Типы заказа (все — виды доставки, такси в платформе появится позже и типом
заказа НЕ является): `'package'` Посылка, `'food'` Еда, `'shops'` Магазины,
`'pharmacy'` Аптеки, `'flowers'` Цветы, `'docs'` Документы.

Методы: `factory TajGoOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>>)`
с дефолтами на отсутствующие поля; `Map<String, dynamic> toCreateMap()` — только
поля для создания нового заказа.

**`lib/core/models/tajgo_courier.dart`** — класс `TajGoCourier`:
`uid`, `name`, `city`, `online` (bool), `rating` (double), `transport` (String),
`earningsToday` (num). `fromDoc` с дефолтами.

**`lib/core/models/app_user.dart`** — уже существует; добавить
`factory AppUser.fromDoc(...)` и поле `language` (String, дефолт `'ru'`).

### Задача 2. `OrderRepository` — клиентская сторона заказов

Новый файл `lib/core/services/order_repository.dart`, конструктор как у соседей:
`OrderRepository(this._db)`. Методы:

```dart
/// Создаёт заказ со статусом waiting, возвращает id документа.
Future<String> createOrder({
  required String customerId,
  required String customerName,
  required String fromText,
  required String toText,
  required String type,      // 'package' | 'food' | 'shops' | 'pharmacy' | 'flowers' | 'docs'
  required num price,
});

/// Последний незавершённый заказ клиента (status in [waiting, accepted, pickedUp]),
/// отсортировано по createdAt desc, limit 1. Стрим типизированных моделей.
Stream<TajGoOrder?> activeOrderStream(String customerId);

/// Отмена клиентом. Разрешена только из waiting (проверять в транзакции:
/// если статус уже не waiting — бросить StateError с русским сообщением).
Future<void> cancelOrder(String orderId);
```

Примечание про индекс: чтобы не требовать составной индекс Firestore, в
`activeOrderStream` запрашивать только по `customerId` +
`orderBy('createdAt', descending: true)` + `limit(5)` и фильтровать по статусу
на клиенте.

Зарегистрировать `OrderRepository` в `TajGoScope` (поле + инициализация в
конструкторе, по образцу существующих).

### Задача 3. Доработать `CourierRepository`

Файл `lib/core/services/courier_repository.dart`:

1. **`setOnline`**: убрать захардкоженные `name: 'Рахимджон'` и прочие demo-поля.
   Новая сигнатура: `setOnline({required String uid, required bool online, required String name, required String city})`.
   Записывать `uid, name, city, online, updatedAt`; поля `rating: 5.0`,
   `score: 100`, `transport: 'electric_bike'`, `earningsToday: 0` — только при
   создании документа (использовать транзакцию или два set: merge-set статуса +
   отдельный set дефолтов, если документа не было).
2. **`declineOrder` — исправить семантику.** Сейчас отказ одного курьера ставит
   `status: 'declined'` и убивает заказ для всех. Новое поведение: отказ — это
   персональное скрытие:
   ```dart
   Future<void> declineOrder({required String orderId, required String courierId}) async {
     // orders/{id}: declinedBy: FieldValue.arrayUnion([courierId]), updatedAt
     // статус НЕ менять
   }
   ```
   В ленте курьера фильтровать на клиенте: скрывать заказы, где
   `declinedBy` содержит uid текущего курьера.
3. **`acceptOrder`**: обернуть в транзакцию — принять можно только заказ в
   статусе `waiting` (иначе `StateError('Заказ уже забрал другой курьер.')`).
   Записывать `status: 'accepted'`, `courierId`, `acceptedAt`, `updatedAt`.
4. **Новые методы смены статуса** (тоже транзакции с проверкой допустимого
   перехода и того, что `courierId == uid` вызывающего):
   ```dart
   Future<void> markPickedUp({required String orderId, required String courierId}); // accepted → pickedUp
   Future<void> markDelivered({required String orderId, required String courierId}); // pickedUp → delivered
   // markDelivered дополнительно увеличивает couriers/{uid}.earningsToday
   // на цену заказа: FieldValue.increment(price) — в той же транзакции.
   ```
5. **`waitingOrdersStream`** → возвращать `Stream<List<TajGoOrder>>`
   (маппинг через `TajGoOrder.fromDoc`), limit оставить 10.
6. **Новый стрим активного заказа курьера**:
   ```dart
   /// Заказы этого курьера в статусах accepted/pickedUp.
   Stream<List<TajGoOrder>> activeCourierOrdersStream(String courierId);
   // where('courierId', isEqualTo: courierId), фильтр статусов на клиенте, limit 5
   ```
7. `createDemoOrder()` — удалить (заменяется реальной формой клиента).
8. `courierStream` → возвращать `Stream<TajGoCourier?>` (маппинг из snapshot,
   null если документа нет).

### Задача 4. `UserRepository` — профиль вместо демо

Файл `lib/core/services/user_repository.dart`:

- `ensureDemoUser` переименовать в `ensureUser({required String uid})` —
  логика та же (создать документ, если нет), `role: 'demo'` заменить на
  `role: 'customer'`.
- Добавить `Future<AppUser?> getUser(String uid)` — прочитать и смаппить в модель.
- Обновить вызов в `features/splash/splash_screen.dart`; после успешного
  bootstrap Splash ведёт на `CustomerHomeScreen` (RoleScreen удалён).

### Задача 5. Тема и дизайн-токены «Платформа TG+»

Обновить `lib/core/constants/tajgo_colors.dart` и `lib/app/tajgo_theme.dart`
под токены из раздела 5 (Дизайн). В `TajGoColors` должны быть все именованные
цвета из таблицы токенов; существующие имена (`green`, `darkGreen`, `muted`)
сохранить, чтобы не ломать импорты, но привести значения к токенам.

В `TajGoTheme.light`: `scaffoldBackgroundColor` = фон `#F4F9F3`; карточки
(CardTheme) — белые, скругление 18, лёгкая тень; `FilledButton` по умолчанию —
лаймовый CTA (`#84CC16`, текст `#12301E`, скругление 12, высота ≥ 48,
`fontWeight: w800`); AppBar прозрачный/зелёный по месту. Заголовки — w900.

### Задача 6. Клиентская сторона — главная-платформа, форма, статус

**`lib/features/customer/customer_home_screen.dart`** — переделать под
«Платформу TG+» (макет в разделе 5):

- **Шапка** — градиент `#15803D → #16A34A`, скруглена только снизу (24),
  занимает верх экрана без отступов по бокам. Внутри: строка «📍 Худжанд»,
  заголовок «TajGo — платформа вашего города 💚» (белый, w900).
- **Модуль «Доставка»** (главный): белая карточка со скруглением 18 и рамкой
  2px `#84CC16`, бейдж «Активно» (`#DCFCE7` / текст `#15803D`) в правом верхнем
  углу, заголовок «🚚 Доставка», подзаголовок «Посылки · Еда · Аптеки · Документы»,
  внутри — лаймовая кнопка «Заказать доставку» → push `OrderFormScreen`.
- **Карточка активного заказа** — между шапкой и модулем «Доставка», только
  когда есть активный заказ: `StreamBuilder` на
  `orderRepository.activeOrderStream(uid)`. Фон `#DCFCE7`, статус-чип
  (`#15803D`, белый текст):
  - `waiting` → «🔎 Ищем курьера» + маршрут + цена + кнопка «Отменить»
    (вызывает `cancelOrder`; StateError → SnackBar);
  - `accepted` → «🚴 Курьер принял заказ» + маршрут;
  - `pickedUp` → «📦 Курьер забрал посылку»;
  - `delivered` → «✅ Доставлено».
- **Ряд «скоро»**: две одинаковые карточки в ряд, приглушённые (opacity ~0.7),
  бейдж «скоро» (`#EDF0F4` / `#64748B`): «🚕 Такси — Поездки по городу» и
  «💳 Кошелёк — Оплата и бонусы». **Не кликабельны**; по тапу — SnackBar
  «Скоро на платформе TajGo 💚».
- **Модуль «Режим курьера»**: обычная белая карточка внизу, «🚴 Стать курьером»,
  подзаголовок «Зарабатывайте с TajGo — свободный график». Тап → push
  `CourierHomeScreen` (в AppBar курьера есть «назад»).

**`lib/features/customer/order_form_screen.dart`** (новый) — экран «Новый заказ»:

- Поля: «Откуда» (TextField), «Куда» (TextField), тип заказа (горизонтальные
  ChoiceChip: Посылка/Еда/Магазины/Аптеки/Цветы/Документы — значения `package`,
  `food`, `shops`, `pharmacy`, `flowers`, `docs`), «Цена, TJS» (TextField,
  `keyboardType: number`). Выбранный чип — `#15803D` с белым текстом.
- Валидация: откуда/куда непустые, цена — положительное число. Ошибки — красным
  текстом под полем или SnackBar.
- Кнопка «Заказать» (лаймовый CTA): блокируется на время записи (`_busy`-паттерн
  как в `courier_home_screen.dart`), вызывает `orderRepository.createOrder(...)`
  (customerId — из `authService.currentUser`, customerName — из
  `userRepository.getUser(...)`, city — `'Худжанд'`), затем
  `Navigator.pop(context)` обратно на главную.

### Задача 7. Курьерская сторона — полный цикл

**`lib/features/courier/courier_home_screen.dart`** — доработать:

- **Шапка** — тот же градиент, что у клиента, скруглена снизу: «📍 Худжанд»,
  крупно «Вы на линии 🟢» / «Готовы выйти на линию?», строка
  «Сегодня заработано — N TJS» (из `TajGoCourier.earningsToday`), кнопка
  тумблера линии (на зелёном фоне — белая/контурная).
- Убрать кнопку «Создать тестовый заказ».
- `_setOnline`: получать `name`/`city` из `userRepository.getUser(uid)`
  (fallback: `'Курьер'` / `'Худжанд'`).
- Перейти на типизированные стримы из Задачи 3 (`List<TajGoOrder>`,
  `TajGoCourier?`).
- **Блок «Мой активный заказ»** (`activeCourierOrdersStream`): карточка с фоном
  `#DCFCE7`, кнопка по статусу:
  - `accepted` → «Забрал посылку» (`markPickedUp`);
  - `pickedUp` → «Доставил» (`markDelivered`).
- **Лента «Ожидающие заказы»**: только когда курьер online (offline → подсказка
  «Выйдите на линию, чтобы видеть заказы»). Скрывать заказы, где `declinedBy`
  содержит мой uid. «Принять» (лаймовый CTA) / «Отказаться» (вторичная,
  `#EDF6EC` / текст `#15803D`) — с `_busy`-защитой от даблтапа; StateError при
  принятии — SnackBar «Заказ уже забрал другой курьер».

### Задача 8. Финальная проверка

1. `flutter analyze` — ноль ошибок и ворнингов в `lib/`.
2. `flutter test` — существующие тесты проходят (если `test/widget_test.dart`
   ссылается на удалённый код или падает из-за Firebase — привести к
   компилирующемуся минимальному smoke-тесту: юнит-тесты на маппинг статусов
   `TajGoOrder` и `toCreateMap` без Firestore-эмулятора).
3. Убедиться, что нигде в `lib/features/` не осталось прямых импортов
   `cloud_firestore` (кроме моделей в `core/models`).

---

## 5. Дизайн «Платформа TG+» (утверждён)

Идея: главная клиента — витрина платформы. Модуль «Доставка» активен, «Такси»
и «Кошелёк» анонсированы бейджем «скоро». Следующая итерация — «Живая карта»
(карта Худжанда как главный экран с курьерами онлайн) — в этой итерации НЕ
реализуется, но модуль карты в `lib/features/map/` сохраняется под неё.

### Токены цвета (`TajGoColors`)

| Токен | Значение | Использование |
|---|---|---|
| `bg` | `#F4F9F3` | фон всех экранов |
| `green` | `#16A34A` | основной зелёный, конец градиента шапки |
| `darkGreen` | `#15803D` | начало градиента, выбранные чипы, вторичный текст-акцент |
| `lime` | `#84CC16` | главные кнопки (CTA), рамка активного модуля |
| `mint` | `#DCFCE7` | фон карточки активного заказа, бейдж «Активно» |
| `ink` | `#12301E` | основной текст, текст на лаймовых кнопках |
| `muted` | `#54705E` | вторичный текст |
| `soonBg` / `soonText` | `#EDF0F4` / `#64748B` | бейдж «скоро» |
| `secondaryBtn` | `#EDF6EC` | фон вторичных кнопок (текст `darkGreen`) |
| `navy` | `#0F172A` | зарезервирован под тёмную тему (не используется сейчас) |

### Форма и типографика

- Скругления: шапка снизу 24; карточки/модули 18; кнопки и поля 12; бейджи —
  полностью круглые (999).
- Кнопки: высота ≥ 48, текст w800. Главная кнопка — лайм с тёмным текстом
  (`lime` + `ink`); вторичная — `secondaryBtn` + `darkGreen`; на зелёном фоне —
  белая или контурная белая.
- Заголовки экранов w900; заголовки карточек w800; шрифт системный
  (Manrope подключим отдельной задачей позже).
- Тени: мягкие, только у белых карточек на светлом фоне
  (`BoxShadow` ~ `rgba(18,48,30,0.1)`, blur 18, offset (0,6)).

### Макет главной клиента (сверху вниз)

```text
┌─ Градиент #15803D→#16A34A, скруглён снизу 24 ──┐
│ 📍 Худжанд                                     │
│ TajGo — платформа вашего города 💚  (w900)     │
└────────────────────────────────────────────────┘
[Карточка активного заказа — mint, только если есть]
┌─ Модуль «Доставка» — белый, рамка 2px lime ────┐
│ 🚚 Доставка                        [Активно]   │
│ Посылки · Еда · Аптеки · Документы             │
│ [ Заказать доставку ]  ← лаймовый CTA          │
└────────────────────────────────────────────────┘
┌─ 🚕 Такси ──[скоро]─┐ ┌─ 💳 Кошелёк ─[скоро]─┐   ← приглушённые, не кликабельны
└─────────────────────┘ └──────────────────────┘
┌─ 🚴 Стать курьером — белый модуль ─────────────┐  → CourierHomeScreen
└────────────────────────────────────────────────┘
```

Таббар в этой итерации не делаем (появится вместе с «Живой картой» и историей
заказов) — главная скроллится как ListView.

---

## 6. Модель данных (итог после итерации)

### orders/{orderId}

| Поле | Тип | Обязательное |
|---|---|---|
| customerId | string | да |
| customerName | string | да |
| courierId | string | после accept |
| status | string: waiting/accepted/pickedUp/delivered/cancelled | да |
| type | string: package/food/shops/pharmacy/flowers/docs | да |
| city | string | да |
| fromText, toText | string | да |
| price | number | да |
| currency | string ('TJS') | да |
| distanceKm, etaMinutes | number | нет |
| declinedBy | array\<string\> uid-ы отказавшихся курьеров | дефолт [] |
| createdAt, acceptedAt, updatedAt | timestamp (server) | createdAt/updatedAt да |

### Переходы статусов (единственно допустимые)

```text
waiting → accepted   (курьер, транзакция, ставит courierId)
waiting → cancelled  (клиент)
accepted → pickedUp  (только назначенный курьер)
pickedUp → delivered (только назначенный курьер; + earningsToday += price)
```

Отказ курьера статус НЕ меняет — только `declinedBy: arrayUnion(uid)`.

### couriers/{uid}

`uid, name, city, online (bool), rating (number), score (number),
transport (string), earningsToday (number), updatedAt (timestamp)`.

### users/{uid}

`uid, name, role, city, language ('ru'), createdAt, updatedAt`.

---

## 7. Критерии приёмки (ручной сценарий на одном устройстве)

1. Запуск → Splash → сразу главная клиента в дизайне «Платформа TG+»: зелёная
   шапка, модуль «Доставка» с лаймовой рамкой и бейджем «Активно», ряд
   «Такси»/«Кошелёк» с бейджами «скоро» (тап по ним — только SnackBar), модуль
   «Стать курьером». Экрана выбора роли больше нет.
2. «Заказать доставку» → форма: чипы типов без такси, но с «Документы».
   Заполнить, «Заказать» → на главной появилась mint-карточка «🔎 Ищем курьера»
   с кнопкой «Отменить».
3. «Стать курьером» → «Выйти на линию» → заказ появился в ленте.
4. «Отказаться» → заказ исчез из ленты курьера, но у клиента остался в статусе
   «Ищем курьера» (в Firestore: status = waiting, declinedBy содержит uid).
5. Создать второй заказ клиентом → курьером «Принять» → появился блок «Мой
   активный заказ», у клиента карточка сменилась на «Курьер принял заказ».
6. «Забрал посылку» → у клиента «Курьер забрал посылку». «Доставил» → у клиента
   «✅ Доставлено», в шапке курьера «Сегодня заработано» выросло на цену заказа.
7. Отмена: создать заказ → «Отменить» до принятия → карточка исчезла; в
   Firestore status = cancelled.
8. `flutter analyze` чистый; папок `lib/screens`, `lib/services`, `lib/widgets`,
   `lib/models`, `lib/core/theme`, `lib/features/role` не существует;
   `lib/features/map/` не тронута.

---

## 8. Вне рамок этой итерации (НЕ делать)

- «Живая карта»: карта как главный экран, геолокация, координаты в заказе,
  курьеры онлайн на карте — это СЛЕДУЮЩАЯ итерация (модуль `lib/features/map/`
  сохранить нетронутым).
- Таббар, история заказов, экран профиля.
- Модули «Такси» и «Кошелёк» как функциональность (только бейджи «скоро»).
- Телефонная авторизация, Firestore security rules.
- Оплата, рейтинги, push-уведомления.
- Мультиязычность (весь UI — русский).
- Подключение шрифта Manrope (отдельная задача позже).
- Riverpod/Bloc/go_router и любые новые зависимости.
