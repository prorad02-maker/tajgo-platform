import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';

import 'safe_diagnostics.dart';

class AuthoritativeCommandService {
  AuthoritativeCommandService(this._gateway);

  final AuthoritativeCommandGateway _gateway;

  Future<Map<String, dynamic>> call(
    String command,
    Map<String, dynamic> data,
  ) async {
    try {
      return await _gateway.call(command, data);
    } on TajGoCommandException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      SafeDiagnostics.log(
        'COMMAND_FUNCTION_ERROR',
        fields: {
          'function': command,
          'region': _gateway.region,
          'code': error.code,
        },
      );
      throw TajGoCommandException.fromFirebase(error);
    } catch (error) {
      SafeDiagnostics.log(
        'COMMAND_TRANSPORT_ERROR',
        fields: {'function': command, 'code': SafeDiagnostics.errorCode(error)},
      );
      throw const TajGoCommandException(
        code: 'unavailable',
        message: 'Нет связи с TajGo. Проверьте интернет и повторите.',
        retryable: true,
      );
    }
  }
}

abstract interface class AuthoritativeCommandGateway {
  Future<Map<String, dynamic>> call(String command, Map<String, dynamic> data);

  /// Регион callable-функций (для диагностики несоответствия region).
  String get region;
}

class FirebaseAuthoritativeCommandGateway
    implements AuthoritativeCommandGateway {
  FirebaseAuthoritativeCommandGateway(
    this._functions, {
    this.region = 'europe-west1',
  });

  final FirebaseFunctions _functions;

  @override
  final String region;

  @override
  Future<Map<String, dynamic>> call(
    String command,
    Map<String, dynamic> data,
  ) async {
    final result = await _functions.httpsCallable(command).call(data);
    final value = result.data;
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }
}

class TajGoCommandException implements Exception {
  const TajGoCommandException({
    required this.code,
    required this.message,
    this.reason,
    this.details = const {},
    this.retryable = false,
  });

  factory TajGoCommandException.fromFirebase(FirebaseFunctionsException error) {
    return TajGoCommandException.safe(
      code: error.code,
      serverMessage: error.message,
      rawDetails: error.details,
    );
  }

  factory TajGoCommandException.safe({
    required String code,
    String? serverMessage,
    Object? rawDetails,
  }) {
    final details = rawDetails is Map
        ? Map<String, dynamic>.from(rawDetails)
        : const <String, dynamic>{};
    final reason = details['reason'] as String?;
    final message = switch (reason) {
      'price-changed' => 'Цены изменились. Проверьте обновлённую корзину.',
      'preview-blocked' => 'Тестовый каталог нельзя оформить.',
      'offer-expired' => 'Срок предложения истёк.',
      'invalid-code' => 'Неверный код. Уточните код у клиента.',
      'code-locked' =>
        'Слишком много неверных попыток. Обратитесь в поддержку.',
      _ => _safeMessage(code, serverMessage),
    };
    return TajGoCommandException(
      code: code,
      message: message,
      reason: reason,
      details: details,
      retryable: const {
        'aborted',
        'cancelled',
        'deadline-exceeded',
        'internal',
        'unavailable',
      }.contains(code),
    );
  }

  final String code;
  final String message;
  final String? reason;
  final Map<String, dynamic> details;
  final bool retryable;

  bool get isPriceChanged => reason == 'price-changed';

  Map<String, num> get currentPrices {
    final raw = details['currentPrices'];
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: entry.value as num,
    };
  }

  @override
  String toString() => message;
}

String _safeMessage(String code, String? serverMessage) => switch (code) {
  'unauthenticated' => 'Сначала войдите в TajGo.',
  'permission-denied' => 'У вас нет прав для этого действия.',
  'invalid-argument' =>
    serverMessage?.trim().isNotEmpty == true
        ? serverMessage!.trim()
        : 'Проверьте введённые данные.',
  'failed-precondition' =>
    serverMessage?.trim().isNotEmpty == true
        ? serverMessage!.trim()
        : 'Состояние заказа изменилось. Обновите экран.',
  'already-exists' => 'Операция уже выполнена.',
  'not-found' => 'Данные больше недоступны. Обновите экран.',
  'resource-exhausted' => 'Слишком много попыток. Попробуйте позже.',
  'aborted' => 'Данные изменились. Обновите экран и повторите.',
  'deadline-exceeded' ||
  'unavailable' => 'Нет связи с TajGo. Проверьте интернет и повторите.',
  _ => 'Не удалось выполнить действие. Попробуйте ещё раз.',
};

class TajGoIdempotencyKey {
  TajGoIdempotencyKey._();

  static final math.Random _random = math.Random.secure();

  static String create(String operation) {
    final safeOperation = operation.replaceAll(
      RegExp(r'[^A-Za-z0-9._:-]'),
      '-',
    );
    final randomPart = List.generate(
      3,
      (_) => _random.nextInt(0x7fffffff).toRadixString(36),
    ).join();
    return '$safeOperation-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  static String stable(String operation, Iterable<Object?> parts) {
    final raw = '$operation:${parts.join(':')}';
    var hash = 0x811c9dc5;
    for (final unit in raw.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return '${operation.replaceAll(RegExp(r'[^A-Za-z0-9._:-]'), '-')}-${hash.toRadixString(16)}-request';
  }
}
