# TajGo v0.7.0 Demo Release Candidate

## Готово

- Полный customer → courier → confirmation code → completed flow.
- Живая GPS-позиция курьера и безопасная трансляция через `courier_public`.
- Courier Navigation MVP: A/B, направление, дистанция, ETA, гео-гейт 2 км.
- Admin/Dispatch MVP: сводка, заказы, детали, курьеры и карта города.
- Семь транзакционных admin actions с append-only `admin_logs`.
- Debug-only Demo Tools для быстрой подготовки сценария.
- Единый RouteService с интерфейсом под будущий OSRM/GraphHopper.
- Pricing v2: минимум 10 TJS, база 7 TJS, 3 TJS/км.

## Ограничения RC

- Маршрут — Haversine и прямая линия, без дорожного графа и пробок.
- GPS транслируется только при открытом приложении.
- Phone Auth требует настройки SHA и Firebase Console.
- Admin actions начнут работать на реальном проекте только после согласованного deploy обновлённых Rules.
- Гео-гейт выполняется на клиенте; trusted server validation пока нет.
- Адрес выбирается точкой на карте, полноценный поиск отложен.

## До production

- Подпись release APK/AAB и безопасное хранение keystore.
- Реальные Phone Auth и SMS-квоты.
- Deploy и интеграционные тесты Firestore Rules двумя обычными пользователями и admin.
- Дорожная маршрутизация, push-уведомления, фоновые GPS и мониторинг ошибок.
