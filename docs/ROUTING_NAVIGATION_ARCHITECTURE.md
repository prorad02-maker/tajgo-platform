# Routing & Navigation Architecture

## Providers

`RouteProvider` принимает from/to и `RouteMode`: walking, bicycle, scooter, car.

- `RoadRouteProvider` поддерживает OSRM и GraphHopper-совместимые ответы.
- `DirectRouteProvider` всегда доступен и возвращает прямую линию.
- `RouteService` выбирает provider, объединяет одинаковые in-flight запросы и
  сохраняет результат в `RouteCache`.

Endpoint по умолчанию выключен. В коде нет платного URL или ключа. Пример:

```powershell
flutter run --dart-define=TAJGO_ROUTE_ENDPOINT=https://your-router.example `
  --dart-define=TAJGO_ROUTE_PROVIDER=osrm
```

Для GraphHopper дополнительно передаётся `TAJGO_ROUTE_API_KEY`. Секрет нельзя
коммитить.

## Fallback и cache

Road route живёт в memory-cache 8 минут. Direct fallback — 45 секунд, чтобы при
слабой сети не спамить endpoint. Ключ использует округлённые from/to и mode.
Fallback обозначается в UI текстом «Маршрут предварительный».

## Курьер

Активная цель зависит от статуса: accepted → A, pickedUp → B. Follow-mode включён
по умолчанию, жест отключает его, GPS-кнопка включает снова. Перестроение возможно
не чаще 20–25 секунд и только после движения от 120 м, off-route или смены цели.
Off-route v1 измеряет близость к точкам road-polyline; для direct fallback не
применяется.

До production нужны выбранный endpoint, мониторинг, серверное ограничение,
map-matching, инструкции манёвров, traffic и фоновая навигация.
