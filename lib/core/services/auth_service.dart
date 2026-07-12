import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User> signInAnonymouslyIfNeeded() async {
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
    Future<void> Function()? onAutoVerified,
  }) async {
    final completer = Completer<PhoneCodeSession>();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          try {
            final user = await _authenticateWithPhoneCredential(credential);
            if (!completer.isCompleted) {
              completer.complete(PhoneCodeSession.autoVerified(user));
            }
            await onAutoVerified?.call();
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
        if (error.code != 'credential-already-in-use' &&
            error.code != 'provider-already-linked') {
          rethrow;
        }
        // The phone already belongs to an account. Use that account instead
        // of creating a duplicate identity.
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
      'invalid-verification-code' => 'Неверный SMS-код.',
      'session-expired' => 'Срок действия кода истёк. Запросите новый.',
      'too-many-requests' ||
      'quota-exceeded' => 'Слишком много попыток. Попробуйте позже.',
      'network-request-failed' => 'Нет связи. Проверьте интернет.',
      'operation-not-allowed' =>
        'Phone Auth ещё не включён в Firebase Console.',
      _ => error.message ?? 'Ошибка авторизации. Попробуйте ещё раз.',
    };
    return PhoneAuthFailure(code: error.code, message: message);
  }

  final String code;
  final String message;

  @override
  String toString() => message;
}
