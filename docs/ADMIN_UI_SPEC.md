# TajGo — v0.5.0 Admin / Dispatch MVP: продуктовая и UI-спецификация

Внедрять ПОСЛЕ v0.4.2 Security & Phone Auth (админ-вход опирается на роль и
телефоны из 0.4.2). Дизайн — токены TG+ (`SPEC_CODEX_V1.md` §5). Courier MVP,
Customer MVP, Splash/Brand — не трогать (разрешены только точечные дельты,
перечисленные в §F и §I).

---

## A. Концепция

Админка — третий режим того же приложения (как «Стать курьером»), а не
отдельный продукт. Владелец видит живое состояние системы (заказы, курьеры,
карта города) и может руками разрулить любую ситуацию тестового периода:
застрявший заказ, спор, заблокированного курьера. Каждое админ-действие
подтверждается диалогом и оставляет след в `admin_logs`. Никакого
enterprise-дашборда: 4 экрана, один репозиторий, переиспользуемые виджеты.

## B. Роли и вход

- Админ = `users/{uid}.role == "admin"`. Роль выставляется вручную в консоли
  Firebase владельцем (UI для назначения ролей НЕ делаем — вне рамок).
- **Entry point**: на главной клиента, после модуля «Стать курьером», модуль
  «🛠 Управление TajGo» (тёмно-зелёная рамка, бейдж «admin»). Показывается
  ТОЛЬКО если профиль текущего пользователя имеет роль admin
  (`userRepository.getUser` уже есть — FutureBuilder при построении главной).
- Никаких скрытых кнопок и «пасхалок»: обычный клиент/курьер модуль просто
  не видит. Клиентская проверка — это UX, БЕЗОПАСНОСТЬ обеспечивают rules
  (§H): даже зная о существовании экранов, не-админ не получит данные.
- Тап → `AdminHomeScreen`. Назад — обычный Navigator.

## C. Список экранов (lib/features/admin/)

| Файл | Экран |
|---|---|
| `admin_home_screen.dart` | дашборд: цифры дня + навигация |
| `admin_orders_screen.dart` | список заказов с фильтрами |
| `admin_order_details_screen.dart` | детали заказа + карта + действия |
| `admin_couriers_screen.dart` | список курьеров + действия |
| `dispatch_map_screen.dart` | живая карта города |

### C1. AdminHomeScreen

Шапка-градиент TG+: «🛠 Управление TajGo», «📍 Худжанд», дата.
Ниже — сетка 2×3 из `TajGoStatCard` (данные: один стрим заказов за сегодня +
стрим курьеров online, §F):

- 📦 Заказов сегодня (все созданные с 00:00);
- 🔄 Активные сейчас (waiting/accepted/pickedUp/delivered);
- ✅ Завершённые сегодня (completed);
- ⚠️ Спорные (disputed, за всё время — им нет срока давности);
- 🛵 Курьеров на линии (online == true);
- 💰 Оборот сегодня (сумма price завершённых сегодня, TJS).

Тап по карточке → AdminOrdersScreen с соответствующим предвыбранным фильтром
(спорные → фильтр «Спорные» и т.д.). Ниже — три большие навигационные
карточки: «📋 Заказы», «🛵 Курьеры», «🗺 Карта города».

### C2. AdminOrdersScreen

- Сверху горизонтальные фильтр-чипы (`ChoiceChip`, выбранный — darkGreen):
  Все · Ожидают · Активные · Спорные · Завершённые · Отменённые.
  Соответствие: Ожидают = waiting; Активные = accepted+pickedUp+delivered;
  Завершённые = completed; Отменённые = cancelled.
- Список: `TajGoOrderCard` (существующий) + сверху строка-мета:
  бейдж статуса, время создания («14:32 · сегодня»), `customerName`
  и телефон клиента (если есть в users, после 0.4.2), имя/телефон курьера
  (если назначен). Тап → детали.
- Данные: стрим последних 100 заказов `orderBy createdAt desc limit 100`,
  фильтрация по статусу client-side (индексы не нужны).
- Пусто по фильтру → «Заказов нет» + иконка.

### C3. AdminOrderDetailsScreen

- **Карта** (верхняя треть): пины A/B, линия, маркер курьера (если назначен
  и есть координаты) — переиспользовать подход OrderTrackingScreen.
- **Карточка заказа**: тип, маршрут, цена, 💬 комментарий, `adminNote`
  (если есть), клиент (имя + телефон + uid мелко), курьер (имя + телефон +
  uid мелко).
- **История статусов** — вертикальный таймлайн из полей заказа (новых
  механизмов не нужно): Создан (createdAt) → Принят (acceptedAt) → На месте
  (arrivedAtPickupAt) → Забрал (pickedUpAt) → Передан (deliveredAt) →
  Завершён (completedAt) / Спор (disputedAt) / Отменён (cancelledAt).
  Показывать только заполненные; для отменённых — cancelledReason.
- **Действия админа** (§G) — ряд кнопок внизу, каждая через confirm-диалог;
  недоступные для текущего статуса — скрыты (не disabled).
- Поле «Заметка админа» — TextField + «Сохранить» → `adminNote`.

### C4. AdminCouriersScreen

- Два раздела: «На линии» и «Не на линии» (стрим всех курьеров, limit 100,
  сортировка client-side: online первыми, затем по updatedAt desc).
- Карточка курьера: имя, телефон (если есть), 🟢/⚪ статус, ⭐ rating,
  🏆 score, 💰 earningsToday, 📦 ordersToday, активный заказ (маршрут кратко,
  тап → детали заказа), «координаты обновлены N мин назад»
  (из locationUpdatedAt; > 10 мин — цвет warning).
- Кнопки: «📍 На карте» (→ DispatchMapScreen с центровкой на курьере),
  «Снять с линии» (admin action), «Очистить активный заказ» (admin/debug
  action, показывается ТОЛЬКО когда activeOrderId != null) — обе через
  confirm-диалог с текстом последствий.

### C5. DispatchMapScreen

- FlutterMap на весь экран (OSM, центр Худжанд), сверху чип-«пилюля» со
  сводкой: «🛵 N на линии · 📦 M активных».
- Маркеры: курьеры — зелёная точка (стрим onlineCouriersStream);
  waiting-заказы — пин A darkGreen; активные заказы — пин A полупрозрачный +
  пин B lime (стрим заказов в статусах waiting/accepted/pickedUp/delivered,
  limit 50, client-side фильтр).
- Тап по маркеру → нижняя карточка (peek ~120px): курьер — имя, статус,
  заработок, кнопка «Профиль» (→ AdminCouriersScreen highlight); заказ —
  маршрут, статус, цена, кнопка «Детали» (→ AdminOrderDetailsScreen).
- Опциональный параметр `focusCourierId` — центровка при входе с C4.

## D. Состояния экранов

| Экран | Состояния |
|---|---|
| AdminHome | загрузка (скелетоны-заглушки цифр «—»), данные, ошибка стрима → SnackBar |
| AdminOrders | список / пусто по фильтру / загрузка |
| OrderDetails | загрузка, данные; после admin-действия — SnackBar «Готово» и живое обновление стрима; StateError → SnackBar с текстом |
| AdminCouriers | список / «Курьеров пока нет» |
| DispatchMap | карта без выбора / карточка курьера / карточка заказа |
| Вход | у не-админа модуль на главной отсутствует; прямой push админ-экрана без роли (dev-ошибка) → экран «Нет доступа» |

## E. Компоненты (новые, lib/shared/widgets/ или lib/features/admin/widgets/)

| Виджет | Описание |
|---|---|
| `TajGoStatusTimeline` | вертикальный таймлайн истории статусов: точка-время-подпись |
| `TajGoAdminActionButton` | кнопка опасного действия: вторичная, текст error/darkGreen, встроенный confirm-диалог (title, message, onConfirm) |
| `TajGoCourierAdminCard` | карточка курьера для C4 |
| `TajGoMapPeekCard` | нижняя peek-карточка для DispatchMap |

Переиспользовать: TajGoStatCard, TajGoOrderCard, TajGoBadge, TajGoStatusPill,
TajGoActionButton, пины/точки из OrderTrackingScreen (вынести `_AddressPin`
и `_CourierDot` в shared, они уже дублируются в двух экранах — разрешённый
рефакторинг).

## F. Firestore — поля и коллекции

### Новая коллекция `admin_logs/{logId}`

| Поле | Тип | Описание |
|---|---|---|
| action | string | 'cancelOrder' \| 'returnToWaiting' \| 'completeManually' \| 'markDisputed' \| 'forceOffline' \| 'clearActiveOrder' \| 'setAdminNote' |
| orderId / courierId | string? | цель действия |
| adminId | string | uid админа |
| details | string? | причина/заметка |
| createdAt | timestamp | серверное время |

Логи только пишутся из приложения (append-only); экрана просмотра логов в
MVP нет — читаются консолью Firebase.

### Новые поля orders

| Поле | Тип | Кто пишет |
|---|---|---|
| cancelledAt, cancelledReason | timestamp, string | отмена (клиентская отмена тоже начинает писать cancelledAt; reason — только админ) |
| resolvedBy, resolvedAt | string, timestamp | админ, разрешивший спор |
| manuallyCompletedBy | string | админ при ручном завершении |
| adminNote | string | заметка админа |
| pickedUpAt, deliveredAt | timestamp | **дельта в courier_repository**: в существующей транзакции `_transition` добавить запись timestamp при переходах в pickedUp/delivered (одна строка на переход, поведение не меняется — нужно для таймлайна C3) |

### Запросы (индексы не требуются)

- Заказы за сегодня: `where createdAt >= <полночь> orderBy createdAt desc
  limit 200` (один диапазон по одному полю);
- Последние 100 заказов: `orderBy createdAt desc limit 100`;
- Курьеры: вся коллекция limit 100; online — существующий onlineCouriersStream.

## G. Admin actions (новый `lib/core/services/admin_repository.dart`)

Все действия: транзакция (проверка допустимости) + документ в `admin_logs`
(в той же транзакции). Регистрация в TajGoScope.

| Метод | Допустимо из | Что делает |
|---|---|---|
| `cancelOrder(orderId, adminId, reason)` | waiting/accepted/pickedUp/delivered/disputed | status=cancelled, cancelledAt, cancelledReason; если courierId назначен — couriers.activeOrderId=null |
| `returnToWaiting(orderId, adminId)` | accepted/pickedUp/delivered/disputed | status=waiting; courierId=null, acceptedAt/arrivedAtPickupAt/pickedUpAt/deliveredAt удалить (FieldValue.delete()); declinedBy очистить; у бывшего курьера activeOrderId=null |
| `completeManually(orderId, adminId)` | delivered/disputed/pickedUp | status=completed, completedAt, manuallyCompletedBy, resolvedBy/resolvedAt (для disputed); курьеру earningsToday += price, ordersToday += 1, activeOrderId=null — как в confirmReceived |
| `markDisputed(orderId, adminId, reason)` | accepted/pickedUp/delivered/completed | status=disputed, disputedAt, adminNote=reason |
| `forceOffline(courierId, adminId)` | — | couriers.online=false (трансляция у курьера сама остановится — экран это уже слушает) |
| `clearActiveOrder(courierId, adminId)` | activeOrderId != null | couriers.activeOrderId=null (заказ НЕ трогает — только разблокировка) |
| `setAdminNote(orderId, adminId, note)` | любой | adminNote |

Тексты confirm-диалогов — с последствиями, например «Вернуть в waiting»:
«Заказ снова увидят все курьеры. Текущий курьер будет снят с заказа. Продолжить?»

## H. Security rules (для слияния с rules из v0.4.2)

```text
function isAdmin() {
  return request.auth != null &&
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}
- orders: правила 0.4.2 + `|| isAdmin()` на read/update;
- couriers: чужие документы писать может только admin (online, activeOrderId);
- admin_logs: create — только isAdmin(); read — только isAdmin(); update/delete — never;
- users: чтение чужих профилей (телефоны!) — только isAdmin() или участники
  общего заказа (уточнить в 0.4.2).
```

Важно: клиентское скрытие модуля — не защита. До деплоя правил админка
считается dev-функцией. Каждый admin-метод пишет lог — правила должны
требовать наличие лог-записи? (Нельзя атомарно проверить в rules —
принимаем: лог пишется той же транзакцией из приложения, аудит честный,
пока admin-аккаунт не скомпрометирован. Cloud Functions — вне рамок.)

## I. Что должен сделать Codex (порядок)

1. Поля timestamps: `pickedUpAt`/`deliveredAt` в `_transition`
   courier_repository (+ модель TajGoOrder читает их и `cancelledAt`,
   `cancelledReason`, `resolvedBy/At`, `manuallyCompletedBy`, `adminNote`);
   `cancelledAt` в существующем cancelOrder.
   ⚠️ **ВНИМАНИЕ (добавлено после инцидента GPS v0.6.0):** задеплоенные
   в Firebase правила проверяют `affectedKeys().hasOnly([...])` и НЕ знают
   новых полей — запись `pickedUpAt`/`deliveredAt`/`cancelledAt` в переходы
   СЛОМАЕТ основной поток заказа до деплоя обновлённых правил (как это было
   с heading/speed). Делать одним из двух способов: (а) отложить эти поля до
   деплоя правил; (б) писать их с fallback как в updateLocation — при
   permission-denied повторить запись без новых полей. Таймлайн в C3 обязан
   работать и без этих полей (показывать только заполненные).
2. `admin_repository.dart` (§G) + регистрация в TajGoScope.
3. Общие виджеты §E (+ вынести `_AddressPin`/`_CourierDot` в shared).
4. Экраны C1–C5.
5. Модуль «🛠 Управление TajGo» на главной (виден только role == admin).
6. Дополнить rules по §H (согласовать с тем, что сделано в 0.4.2).
7. Проверка: analyze/test чистые; ручной сценарий — под admin-аккаунтом
   пройти все 7 действий §G на тестовых заказах, убедиться в записях
   admin_logs; под обычным аккаунтом модуль админки не виден.

## J. Что НЕ трогать / НЕ делать

- Courier MVP и Customer MVP экраны (кроме модуля на главной из §I-5).
- Splash/Brand, main.dart, firebase_options, тему.
- Формулу цены, статусную машину (админ-переходы — только через новый
  admin_repository).
- Аналитика, бухгалтерия, операторы, push, web-dashboard, автоназначение
  заказов, многоуровневые роли, экран просмотра admin_logs, назначение
  ролей из приложения — всё вне рамок v0.5.0.
- Никаких новых pub-пакетов.
