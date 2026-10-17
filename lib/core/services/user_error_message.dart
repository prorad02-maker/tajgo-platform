import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'authoritative_command_service.dart';

/// Maps infrastructure failures to actionable messages without exposing paths,
/// provider responses or credentials to the user.
String userErrorMessage(Object? error) {
  if (error is TajGoCommandException) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'Нет доступа к этому действию. Проверьте аккаунт.',
      'unauthenticated' || 'user-token-expired' => 'Войдите в аккаунт ещё раз.',
      'unavailable' ||
      'network-request-failed' => 'Проверьте интернет и повторите попытку.',
      'deadline-exceeded' =>
        'Ответ задерживается. Проверьте состояние заказа перед повторной попыткой.',
      'not-found' => 'Данные больше недоступны. Обновите экран.',
      'resource-exhausted' ||
      'too-many-requests' => 'Слишком много попыток. Попробуйте немного позже.',
      _ => 'Не удалось выполнить действие. Попробуйте ещё раз.',
    };
  }
  if (error is TimeoutException) {
    return 'Ответ задерживается. Проверьте состояние заказа перед повторной попыткой.';
  }
  // Business validation errors are authored by TajGo and are already in Russian.
  if (error is StateError && RegExp(r'[А-Яа-яЁё]').hasMatch(error.message)) {
    return error.message;
  }
  return 'Не удалось выполнить действие. Проверьте интернет и попробуйте ещё раз.';
}
