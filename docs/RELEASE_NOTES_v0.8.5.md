# TajGo Map Core Upgrade v0.8.5–v0.8.7

- Address Search 2.0: отдельные recent/nearby/popular, debounce, ручной fallback.
- Gazetteer получил district, verified, popularity и notes.
- Recent places увеличены до 20 и разделены на pickup/dropoff.
- Добавлены RouteProvider, RoadRouteProvider, DirectRouteProvider и RouteCache.
- Road endpoint выключен и настраивается только через dart-define.
- Клиентские карты показывают route quality, ETA и «Показать весь маршрут».
- Курьер получил cached route до активной цели, follow-mode, throttled rebuild и
  мягкое off-route предупреждение.
- Dispatch получил городской обзор, фильтры и маршрут только выбранного заказа.
- Firebase, Phone Auth, платежи и `tj.tajgo.app` не менялись.
