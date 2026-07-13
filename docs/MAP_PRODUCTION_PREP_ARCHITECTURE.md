# Map Production Prep v1.0

## Слои

- `RoutingConfig` читает безопасные compile-time параметры.
- `RoadRouteProvider` отвечает только за HTTP/OSRM/GraphHopper parsing.
- `RouteService` управляет cache, in-flight deduplication и fallback.
- `RoutingHealthMonitor` хранит debug-состояние provider без показа ошибок
  клиенту.
- `MapPerformanceMonitor` считает search/route/reverse latency и slow operations.
- `PlaceSearchService` объединяет favorite → recent → pinned/local → remote.
- `SavedPlacesService` хранит до 50 избранных мест в SharedPreferencesAsync.

## Route quality

- `road`: провайдер вернул дорожную geometry.
- `approximate`: маршрут приблизительный.
- `directFallback`: provider выключен, нормальный offline/demo режим.
- `providerError`: provider включён, но сработал fallback.
- `unavailable`: маршрут нельзя показать.

Техническая причина хранится только для debug. Пользователь видит короткий
статус, а сценарий заказа продолжается.

## Места и доставка

Place поддерживает `partnerId`, `isPartner`, `pinned`, `tags`, verification и
popularity. Избранное локальное; recent остаётся раздельным для pickup/dropoff.
`DeliveryMapIntelligenceService` формирует следующую цель A/B, заметку и момент
показа кода, чтобы карта вела не транспорт, а доставку.

## Ограничения пилота

Нет гарантий пробок, голосовых инструкций, offline vector tiles, map matching и
фоновой навигации. Production требует проверенной базы Худжанда, SLA routing,
rate limits, наблюдаемость backend и длительные дорожные тесты.
