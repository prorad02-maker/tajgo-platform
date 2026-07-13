# TajGo 1.0.0+21 — Pilot Navigation & Map Production Prep

- Routing настраивается через `ROUTING_*` dart-define без секретов в Git.
- Добавлены OSRM code validation, публичный request builder и безопасный fallback.
- Route quality получил пользовательские статусы road/approximate/fallback/error.
- Demo Tools показывает provider health, latency, cache hits и карту slow ops.
- Добавлены избранные, закреплённые и партнёрские места.
- Расширена схема базы Худжанда и исправлен UTF-8 демо-справочника.
- Добавлен delivery intelligence для фаз «забрать»/«доставить» и кода.
- Добавлены архитектура production prep и полевой phone QA.

Firebase, Phone Auth, платежи и `tj.tajgo.app` не менялись.
