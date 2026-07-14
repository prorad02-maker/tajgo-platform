import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const bool allowAnonymousDemo = kDebugMode;

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Future<void> signOut() => _auth.signOut();

  Future<User> signInAnonymouslyIfNeeded() async {
    if (!allowAnonymousDemo) {
      throw StateError('Тестовый вход недоступен в release-сборке.');
    }
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase не вернул пользователя.');
    }
    return user;
  }

  Future<PhoneCodeSession> requestPhoneCode({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    final completer = Completer<PhoneCodeSession>();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: forceResendingToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          try {
            final user = await _authenticateWithPhoneCredential(credential);
            if (!completer.isCompleted) {
              completer.complete(PhoneCodeSession.autoVerified(user));
            }
          } on AccountConflictFailure catch (error, stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          } on FirebaseAuthException catch (error, stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(
                PhoneAuthFailure.fromFirebase(error),
                stackTrace,
              );
            }
          }
        },
        verificationFailed: (error) {
          if (!completer.isCompleted) {
            completer.completeError(PhoneAuthFailure.fromFirebase(error));
          }
        },
        codeSent: (verificationId, resendToken) {
          if (!completer.isCompleted) {
            completer.complete(
              PhoneCodeSession.codeSent(
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!completer.isCompleted) {
            completer.complete(
              PhoneCodeSession.codeSent(verificationId: verificationId),
            );
          }
        },
      );
    } on FirebaseAuthException catch (error) {
      throw PhoneAuthFailure.fromFirebase(error);
    }
    return completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => throw const PhoneAuthFailure(
        code: 'timeout',
        message: 'Не удалось отправить код. Попробуйте ещё раз.',
      ),
    );
  }

  Future<User> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _authenticateWithPhoneCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw PhoneAuthFailure.fromFirebase(error);
    }
  }

  Future<User> _authenticateWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    final existing = _auth.currentUser;
    if (existing?.isAnonymous == true) {
      try {
        final linked = await existing!.linkWithCredential(credential);
        final user = linked.user;
        if (user != null) {
          return user;
        }
      } on FirebaseAuthException catch (error) {
        if (error.code == 'credential-already-in-use') {
          throw AccountConflictFailure(credential);
        }
        if (error.code != 'provider-already-linked') {
          rethrow;
        }
      }
    }
    final signedIn = await _auth.signInWithCredential(credential);
    final user = signedIn.user;
    if (user == null) {
      throw const PhoneAuthFailure(
        code: 'missing-user',
        message: 'Не удалось завершить вход.',
      );
    }
    return user;
  }

  Future<User> signInToExistingAccount(PhoneAuthCredential credential) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw const PhoneAuthFailure(
          code: 'missing-user',
          message: 'Не удалось войти в существующий аккаунт.',
        );
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw PhoneAuthFailure.fromFirebase(error);
    }
  }
}

class AccountConflictFailure implements Exception {
  const AccountConflictFailure(this.credential);

  final PhoneAuthCredential credential;
}

class PhoneCodeSession {
  const PhoneCodeSession._({this.verificationId, this.resendToken, this.user});

  factory PhoneCodeSession.codeSent({
    required String verificationId,
    int? resendToken,
  }) => PhoneCodeSession._(
    verificationId: verificationId,
    resendToken: resendToken,
  );

  factory PhoneCodeSession.autoVerified(User user) =>
      PhoneCodeSession._(user: user);

  final String? verificationId;
  final int? resendToken;
  final User? user;

  bool get isAutoVerified => user != null;
}

class PhoneAuthFailure implements Exception {
  const PhoneAuthFailure({required this.code, required this.message});

  factory PhoneAuthFailure.fromFirebase(FirebaseAuthException error) {
    final message = switch (error.code) {
      'invalid-phone-number' =>
        'Проверьте номер. Нужен формат +992 XX XXX XX XX.',
      'invalid-verification-code' =>
        'Неверный код. Проверьте SMS и попробуйте ещё раз.',
      'session-expired' => 'Срок действия кода истёк. Запросите новый.',
      'too-many-requests' || 'quota-exceeded' =>
        'Слишком много попыток. Подождите немного и попробуйте снова.',
      'network-request-failed' => 'Нет связи. Проверьте интернет и повторите.',
      'operation-not-allowed' =>
        'Вход по SMS временно недоступен. Попробуйте позже.',
      _ => error.message ?? 'Ошибка авторизации. Попробуйте ещё раз.',
    };
    return PhoneAuthFailure(code: error.code, message: message);
  }

  final String code;
  final String message;

  @override
  String toString() => message;
}

enum AuthLinkDecision { linkAnonymous, signIn, conflict }

AuthLinkDecision authLinkDecision({
  required bool isAnonymous,
  String? firebaseErrorCode,
}) {
  if (isAnonymous && firebaseErrorCode == 'credential-already-in-use') {
    return AuthLinkDecision.conflict;
  }
  return isAnonymous ? AuthLinkDecision.linkAnonymous : AuthLinkDecision.signIn;
}
