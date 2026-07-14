import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';

class AccountConflictScreen extends StatefulWidget {
  const AccountConflictScreen({
    super.key,
    required this.credential,
    required this.onContinue,
  });

  final PhoneAuthCredential credential;
  final Future<void> Function(PhoneAuthCredential credential) onContinue;

  @override
  State<AccountConflictScreen> createState() => _AccountConflictScreenState();
}

class _AccountConflictScreenState extends State<AccountConflictScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _continue() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onContinue(widget.credential);
      if (mounted) Navigator.pop(context, true);
    } on PhoneAuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось войти в существующий аккаунт. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Аккаунт уже существует')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.shield_rounded, size: 72),
          const SizedBox(height: 20),
          const Text(
            'Этот номер уже привязан к аккаунту TajGo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          const Text(
            'Войти в него? Текущие тестовые данные этого устройства '
            'останутся в старом профиле — TajGo ничего не удалит автоматически.',
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _continue,
            child: _loading
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Войти в существующий аккаунт'),
          ),
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    ),
  );
}
