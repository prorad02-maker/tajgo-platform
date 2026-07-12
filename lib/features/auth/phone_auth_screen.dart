import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/services/auth_service.dart';
import '../../shared/widgets/tajgo_scope.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, this.allowAnonymousFallback = true});

  final bool allowAnonymousFallback;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController(text: '+992 ');
  final _codeController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();

  bool _loading = false;
  String? _verificationId;
  String? _error;

  bool get _waitingForCode => _verificationId != null;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^\+992 \d{2} \d{3} \d{2} \d{2}$').hasMatch(phone)) {
      setState(() => _error = 'Введите 9 цифр после +992.');
      return;
    }
    await _run(() async {
      final scope = TajGoScope.of(context);
      final session = await scope.authService.requestPhoneCode(
        phoneNumber: phone.replaceAll(' ', ''),
        onAutoVerified: _completeProfileAndClose,
      );
      if (!mounted || session.isAutoVerified) {
        if (session.isAutoVerified) {
          await _completeProfileAndClose();
        }
        return;
      }
      setState(() => _verificationId = session.verificationId);
      _codeFocus.requestFocus();
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
      await _completeProfileAndClose();
    });
  }

  Future<void> _completeProfileAndClose() async {
    if (!mounted) {
      return;
    }
    final scope = TajGoScope.of(context);
    final user = scope.authService.currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }
    await scope.userRepository.ensureUser(
      uid: user.uid,
      phoneNumber: user.phoneNumber,
      displayName: user.displayName,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on PhoneAuthFailure catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось войти. Попробуйте ещё раз.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _changePhone() {
    setState(() {
      _verificationId = null;
      _codeController.clear();
      _error = null;
    });
    _phoneFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход в TajGo'),
        automaticallyImplyLeading: !widget.allowAnonymousFallback,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: TajGoColors.mint,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.phone_android_rounded,
                color: TajGoColors.darkGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _waitingForCode ? 'Код из SMS' : 'Войдите по телефону',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _waitingForCode
                  ? 'Мы отправили код на ${_phoneController.text}.'
                  : 'Телефон защитит ваши заказы и профиль.',
              style: const TextStyle(color: TajGoColors.muted, fontSize: 16),
            ),
            const SizedBox(height: 26),
            if (!_waitingForCode)
              TextField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                enabled: !_loading,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: const [TajikPhoneInputFormatter()],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _requestCode(),
                decoration: const InputDecoration(
                  labelText: 'Номер телефона',
                  hintText: '+992 XX XXX XX XX',
                  prefixIcon: Icon(Icons.phone_rounded),
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _confirmCode(),
                decoration: const InputDecoration(
                  labelText: 'SMS-код',
                  hintText: '000000',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loading ? null : _changePhone,
                  child: const Text('Изменить номер'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: TajGoColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 20),
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
            if (widget.allowAnonymousFallback) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                child: const Text('Продолжить без телефона (демо)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TajikPhoneInputFormatter extends TextInputFormatter {
  const TajikPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('992')) {
      digits = digits.substring(3);
    }
    if (digits.length > 9) {
      digits = digits.substring(0, 9);
    }

    final buffer = StringBuffer('+992');
    for (var index = 0; index < digits.length; index++) {
      if (index == 0 || index == 2 || index == 5 || index == 7) {
        buffer.write(' ');
      }
      buffer.write(digits[index]);
    }
    final value = buffer.toString();
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}
