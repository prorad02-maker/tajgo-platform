# TajGo v1 — Codex Handoff (большая реализация)

Техническое задание по продуктовому пакету v1. Источники истины:
TAJGO_PRODUCT_V1_MASTER_SPEC, AUTH_ACCOUNT_MODES_UX_SPEC,
COURIER_ONBOARDING_VERIFICATION_SPEC, PRODUCT_V1_ACCEPTANCE_QA.
При противоречии со СТАРЫМИ документами (SPEC_CODEX_V1..V3, CUSTOMER/COURIER
_UI_SPEC, ARCHITECTURE.md) — побеждает пакет v1.

## §0. Разрешённые противоречия (контекст для аудита)

1. **RoleScreen против «Платформы TG+»:** RoleScreen («Выберите режим»)
   упраздняется. Вход — App Startup Router (этап 3) + экран намерения для
   новых. ARCHITECTURE.md обновить.
2. **role-строка против режимов:** users.role остаётся ТОЛЬКО как legacy +
   признак admin; режимы — roles[] + lastMode (AUTH §G).
3. **«Стать курьером» мгновенно против проверки:** ensureCourierProfile при
   входе на экран курьера — заменяется заявкой с одобрением; легаси-курьеры
   (существующий couriers-док) — auto-approve при миграции.
4. **Anonymous против «телефонного входа»:** anonymous — только debug/demo
   за feature-flag; в release реальные действия требуют телефона (AUTH §H).
5. **draft/arrivedAtDropoff:** новые Firestore-статусы НЕ вводятся; draft —
   локальный, arrivedAtDropoffAt — необязательный флаг (MASTER §E).

## Обязательные ограничения (весь проект)

- НЕ менять Firebase project и firebase_options.dart; НЕ делать deploy.
- НЕ менять package tj.tajgo.app.
- НЕ ломать карту/routing/навигацию — это quality gate (MASTER §D);
  map-файлы трогать только там, где явно сказано.
- main.dart — только если без этого невозможен router (минимальный дифф).
- НЕ удалять/переписывать существующие заказы и couriers-доки.
- Один телефон = один UID; дубликаты не создавать (AUTH §J).
- НЕ коммитить секреты (key.properties, keystore).
- Ручная проверка после каждого внутреннего этапа НЕ нужна:
  analyze/test/build — автоматически после этапов 2, 7, 11, 15, 17;
  git checkpoint перед стартом и после каждого этапа с компилирующимся
  состоянием. Один итоговый отчёт в конце.

## Этапы

### 1. Audit / migration compatibility
Проверить: app_user.dart, user_repository, splash_screen, role_screen,
phone_auth_screen, courier_repository.ensureCourierProfile, firestore.rules,
admin-экраны. Зафиксировать (в отчёт): где читается role, где создаётся
courier-профиль, где anonymous fallback. Ничего не менять.
**AC:** список точек касания в отчёте.

### 2. Account models
Файлы: core/models/app_user.dart (+roles, lastMode, courierStatus,
phoneVerified, profileComplete; legacy role сохранить), новый
core/models/courier_application.dart. user_repository: чтение/запись новых
полей + ленивая миграция старого дока (AUTH §G). Юнит-тесты маппинга.
**AC:** старый док без roles читается корректно; analyze/test чистые.

### 3. App startup router
Новый features/startup/app_router.dart (или расширение splash): Splash →
(нет auth/профиля → Intent) | (профиль → lastMode home) | (pending →
CustomerHome + карточка заявки). RoleScreen удалить, все импорты почистить.
**AC:** 6 маршрутов из AUTH §E работают; RoleScreen не существует.

### 4. Intent screen
features/startup/intent_screen.dart по AUTH §A (две карточки, тексты
дословно). Показ один раз (профиль создан → больше никогда).
**AC:** QA-1/3 первые шаги.

### 5. Phone Auth integration
phone_auth_screen: встроить в оба потока намерения; тексты ошибок — AUTH §I;
account conflict — отдельный экран AUTH §J (не SnackBar). Anonymous
fallback — за флагом allowAnonymousDemo (debug-only) + бейдж «Тест».
**AC:** QA-7 (SMS failure, conflict, disabled) — тексты человеческие.

### 6. Profile completion
Экран «Как вас называть?» после первой SMS (profileComplete=false → показ).
**AC:** имя попадает в users, повторно не спрашивается.

### 7. Account modes
TajGoScope/сервис текущего режима; lastMode пишется при переключении.
Курьерский вход по roles.contains('courier') && courierStatus==approved.
**AC:** переключение без SMS; QA-4 переключения. Analyze/test/build.

### 8. Courier application
features/courier/application/*: экран «Стать курьером» (§A), анкета 5 шагов
(§B) с draft-сохранением (§C) в courier_applications/{uid}; Storage-флаг:
фото-шаги деградируют в «личную встречу» без блокировки.
**AC:** QA-2 шаги анкеты и черновик.

### 9. Application status
Экраны pending/rejected/suspended (§D/F/G) + карточка статуса в клиентском
профиле/главной.
**AC:** QA-3; rejected показывает причину и возвращает в анкету.

### 10. Admin approvals
Раздел «Заявки курьеров» в админке (список, карточка, approve/reject с
причиной, suspend/reinstate в «Курьерах»); транзакции + admin_logs (§H);
approve выполняет §E (roles+, couriers/courier_public через существующий
ensureCourierProfile).
**AC:** QA-5; каждый approve/reject виден в admin_logs.

### 11. Mode switch
Пункты переключения в профилях (AUTH §F); выход с линии перед переключением
из курьера, если online. Analyze/test/build.
**AC:** тумблер линии ≠ переключатель режимов; lastMode переживает рестарт.

### 12. Settings / profile
Экраны профиля клиента (MASTER §F: избранные адреса — модель+UI, история,
«Зарабатывать», настройки §I, выход AUTH §K) и курьера (MASTER §G).
Удаление аккаунта — экран-контакт, БЕЗ кнопки удаления данных.
**AC:** QA-1/4 профильные шаги; выход возвращает на Intent.

### 13. Firestore Rules readiness (локально, БЕЗ deploy)
Дополнить firestore.rules: courier_applications (владелец: create/read/
update-draft; admin: read/решения), users: новые поля в affectedKeys
существующих правил, roles меняет только admin/системная транзакция
approve. Совместимость с задеплоенными правилами: код должен переживать
permission-denied на новых коллекциях с человеческой ошибкой (как v0.6.0).
**AC:** rules компилируются (firebase emulators не требуется — синтаксис);
приложение без деплоя не падает, показывает «не хватает прав» по-русски.

### 14. Migration legacy data (ленивая, при входе)
- users без roles → roles из role (QA-8а);
- couriers/{uid} существует → courierStatus=approved, roles+=courier,
  повторная анкета НЕ требуется (QA-8в);
- anonymous в release → баннер входа, заказы читаются (QA-8б);
- активный заказ любого статуса доживает по старой машине (QA-8г).
Поля legacy (role, name, online) продолжают писаться как сейчас.
**AC:** QA-8 целиком; ни один существующий док не «испорчен».

### 15. Tests
Юнит: маппинг AppUser (legacy/new), CourierApplication, courierStatus-
матрица переходов, router-решения (чистая функция «куда идти» по профилю).
Analyze/test/build.
**AC:** новые тесты зелёные, старые не тронуты.

### 16. Documentation
Обновить: ARCHITECTURE.md (навигация v1, режимы), OWNER_NEXT_STEPS.md
(что появилось), release notes v1. Пометить устаревшие разделы старых
спеков ссылкой на пакет v1 (не удалять файлы).
**AC:** ARCHITECTURE.md не противоречит реализации.

### 17. Debug/release builds
flutter build apk --debug и --release; обход release: без Demo Tools, без
anonymous, без kDebugMode-админки (QA-9). Итоговый отчёт: этапы, файлы,
миграция, известные ограничения, что требует владельца.
**AC:** QA-9 полностью; отчёт один, финальный.

## Итоговый отчёт Codex должен содержать
1. Чекпоинт-коммиты по этапам.
2. Карту изменённых/новых файлов.
3. Результаты analyze/test/build (debug и release).
4. Список того, что ждёт владельца (Firebase Console) — из FIREBASE_
   PRODUCTION_SETUP + rules deploy по готовности.
5. Отклонения от спеков пакета v1, если были, с причинами.
