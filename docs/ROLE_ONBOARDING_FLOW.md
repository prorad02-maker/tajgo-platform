# Выбор роли

Первый завершённый профиль видит две карточки: «Я клиент» и «Я курьер». Admin через этот экран не назначается.

Сохраняются exact keys SharedPreferences:

- `selectedRole`;
- `onboardingCompleted`.

В `users/{uid}` сохраняются `selectedRole`, совместимое поле `role`, `onboardingCompleted`, `roleSelectedAt`, `updatedAt`.

Курьер без одобрения направляется в статус заявки. Смена режима остаётся только в профиле, требует подтверждения и блокируется при активном заказе. Старый профиль без `onboardingCompleted` снова получает выбор роли.
