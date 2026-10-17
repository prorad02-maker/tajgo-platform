# TajGo v1.8 Part 1 — Firestore Indexes

`firestore.indexes.json` содержит только составные индексы для фактических запросов:

1. `orders: customerId ASC, createdAt DESC` — активные и недавние заказы клиента.
2. `orders: status ASC, createdAt DESC` — status/admin feed.
3. `orders: customerId ASC, status ASC` — server check активного заказа перед сменой режима.

Остальные текущие запросы используют single-field indexes или index merging:

- waiting/courier orders;
- nested offers;
- partners/products с equality filters;
- online couriers;
- courier applications;
- admin logs.

`orderType + status` не добавлен: текущий UI фильтрует загруженную admin feed и не выполняет такой Firestore query. Индекс следует добавить только вместе с реальным query.

Проверка и deploy выполняются владельцем:

```powershell
firebase deploy --only firestore:indexes --project tajgo-4fcd0
```

Индексы могут строиться несколько минут. Пока build не завершён, соответствующий server query может вернуть failed-precondition.
