import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/app_user.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/safe_diagnostics.dart';
import '../../shared/widgets/tajgo_scope.dart';
import 'account_conflict_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({
    super.key,
    this.allowAnonymousFallback = true,
    this.initialIntent = AppUserRole.customer,
  });

  final bool allowAnonymousFallback;
  final String initialIntent;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController(text: '+992 ');
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  bool _loading = false;
  String? _verificationId;
  int? _resendToken;
  String? _error;
  int _resendSeconds = 0;
  Timer? _timer;
  bool _finishingAuth = false;

  bool get _waitingForCode => _verificationId != null;
  bool get _demoAllowed => allowAnonymousDemo && widget.allowAnonymousFallback;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _requestCode({bool resend = false}) async {
    final phone = normalizeLoginPhone(_phoneController.text);
    if (phone == null) {
      setState(
        () => _error =
            'Введите полный номер с кодом страны, например +992 или +7.',
      );
      return;
    }
    await _run(() async {
      final session = await TajGoScope.of(context).authService.requestPhoneCode(
        phoneNumber: phone,
        forceResendingToken: resend ? _resendToken : null,
      );
      if (!mounted) return;
      if (session.isAutoVerified) {
        await _finishAuth();
        return;
      }
      setState(() {
        _verificationId = session.verificationId;
        _resendToken = session.resendToken;
      });
      _startTimer();
      _codeFocus.requestFocus();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _confirmCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Введите 6-значный код из SMS.');
      return;
    }
    await _run(() async {
      await TajGoScope.of(context).authService.confirmSmsCode(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _finishAuth();
    });
  }

  Future<void> _finishAuth() async {
    if (!mounted || _finishingAuth) return;
    _finishingAuth = true;
    final scope = TajGoScope.of(context);
    final user = scope.authService.currentUser;
    if (user == null) {
      _finishingAuth = false;
      return;
    }
    // Успешный credential сразу ведёт к маршрутизации. Профиль записываем
    // best-effort: ошибка (например, недоступные Functions) НЕ должна блокировать
    // возврат к AppStartupRouter, который сам загрузит профиль и покажет нужный
    // экран или «Вход выполнен, но не удалось загрузить профиль».
    try {
      await scope.userRepository.ensureUser(
        uid: user.uid,
        phoneNumber: user.phoneNumber,
        displayName: user.displayName,
        phoneVerified: !user.isAnonymous && user.phoneNumber != null,
        initialMode: widget.initialIntent,
      );
      final profile = await scope.userRepository.getUser(user.uid);
      if (profile != null && profile.onboardingCompleted != true) {
        await scope.userRepository.completeRoleOnboarding(
          user.uid,
          widget.initialIntent,
        );
      }
    } catch (error, stackTrace) {
      SafeDiagnostics.log(
        'AUTH_FINISH_PROFILE_ERROR',
        fields: {'code': SafeDiagnostics.errorCode(error)},
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    // Возврат к корневому AppStartupRouter (он слушает authStateChanges и
    // пере-резолвит маршрут после входа). Не создаём второй роутер.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _demoLogin() async {
    await _run(() async {
      await TajGoScope.of(context).authService.signInAnonymouslyIfNeeded();
      await _finishAuth();
    });
  }

  Future<void> _openConflict(AccountConflictFailure failure) async {
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AccountConflictScreen(
          credential: failure.credential,
          onContinue: (credential) async {
            await TajGoScope.of(
              context,
            ).authService.signInToExistingAccount(credential);
          },
        ),
      ),
    );
    if (signedIn == true) await _finishAuth();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on AccountConflictFailure catch (error) {
      if (mounted) await _openConflict(error);
    } on PhoneAuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось войти. Попробуйте ещё раз.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changePhone() {
    _timer?.cancel();
    setState(() {
      _verificationId = null;
      _codeController.clear();
      _resendSeconds = 0;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Вход в TajGo')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.phone_android_rounded,
              color: TajGoColors.darkGreen,
              size: 64,
            ),
            const SizedBox(height: 22),
            Text(
              _waitingForCode ? 'Код из SMS' : 'Ваш номер телефона',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _waitingForCode
                  ? 'Отправили на ${_phoneController.text}.'
                  : 'По номеру мы привяжем ваши заказы и код получения. Никакого спама.',
              style: const TextStyle(color: TajGoColors.muted, fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (!_waitingForCode)
              TextField(
                controller: _phoneController,
                enabled: !_loading,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
                ],
                onSubmitted: (_) => _requestCode(),
                decoration: const InputDecoration(
                  labelText: 'Номер телефона',
                  hintText: '+992 XX XXX XX XX или +7 XXX XXX XX XX',
                  border: OutlineInputBorder(),
                ),
              )
            else ...[
              TextField(
                controller: _codeController,
                focusNode: _codeFocus,
                enabled: !_loading,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (value) {
                  if (value.length == 6 && !_loading) _confirmCode();
                },
                decoration: const InputDecoration(
                  labelText: 'SMS-код',
                  hintText: '000000',
                  border: OutlineInputBorder(),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: _loading ? null : _changePhone,
                    child: const Text('Изменить номер'),
                  ),
                  TextButton(
                    onPressed: _loading || _resendSeconds > 0
                        ? null
                        : () => _requestCode(resend: true),
                    child: Text(
                      _resendSeconds > 0
                          ? 'Повторить через $_resendSeconds с'
                          : 'Отправить ещё раз',
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: TajGoColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loading
                  ? null
                  : _waitingForCode
                  ? _confirmCode
                  : _requestCode,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_waitingForCode ? 'Подтвердить' : 'Получить код'),
            ),
            if (_demoAllowed) ...[
              const SizedBox(height: 18),
              const Center(
                child: Chip(
                  avatar: Icon(Icons.science_rounded, size: 18),
                  label: Text('Тестовый вход'),
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _demoLogin,
                child: const Text('Продолжить без подтверждённого номера'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String? normalizeTajikPhone(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('992')) digits = digits.substring(3);
  if (digits.length != 9) return null;
  return '+992$digits';
}

/// Explicit country codes are preserved; local nine-digit input remains Tajik.
String? normalizeLoginPhone(String input) {
  final text = input.trim();
  if (!RegExp(r'^[0-9+ ()\-\u00a0\u202f]+$').hasMatch(text)) return null;
  final compact = text.replaceAll(RegExp(r'[ ()\-\u00a0\u202f]'), '');
  if (!compact.startsWith('+')) {
    if (compact.contains('+')) return null;
    return normalizeTajikPhone(compact);
  }
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(compact)) return null;
  if (compact.startsWith('+992') && compact.length != 13) return null;
  if (compact.startsWith('+7') && compact.length != 12) return null;
  return compact;
}
