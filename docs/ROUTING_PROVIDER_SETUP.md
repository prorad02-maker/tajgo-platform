# Настройка дорожного route provider

По умолчанию внешний провайдер выключен. Секреты и endpoint не хранятся в Git.

## Параметры `--dart-define`

| Параметр | Пример | Назначение |
|---|---|---|
| `TAJGO_ROUTE_ENABLED` | `true` | Включить дорожные маршруты |
| `TAJGO_ROUTE_PROVIDER` | `osrm` | `osrm` или `graphhopper` |
| `TAJGO_ROUTE_ENDPOINT` | `https://routing.example.tj` | Базовый URL сервиса |
| `TAJGO_ROUTE_API_KEY` | локальный секрет | Необязательный ключ |
| `TAJGO_ROUTE_TIMEOUT_MS` | `7000` | Timeout запроса |
| `TAJGO_ROUTE_MODE` | `bicycle` | `walking`, `bicycle`, `scooter`, `car` |

Пример локального запуска:

```powershell
flutter run `
  --dart-define=TAJGO_ROUTE_ENABLED=true `
  --dart-define=TAJGO_ROUTE_PROVIDER=osrm `
  --dart-define=TAJGO_ROUTE_ENDPOINT=https://routing.example.tj
```

OSRM-запрос использует `overview=full`, `geometries=geojson`, `steps=true` и `language=ru`. Endpoint должен поддерживать профили, соответствующие режимам TajGo. Для GraphHopper можно передать ключ только через локальный `--dart-define` или секрет CI.

## Проверка

1. Запустить приложение с включённым провайдером.
2. Открыть активный заказ курьера.
3. Убедиться, что статус — «Маршрут построен», а не «Маршрут предварительный».
4. Проверить манёвры и ETA на реальной дороге.
5. Отключить сеть: приложение должно тихо перейти на fallback и продолжить сценарий.

Никогда не коммитить API-ключ, приватный endpoint с токеном или файл секретов.
