import 'package:flutter/material.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/models/app_user.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../courier/courier_application_status_screen.dart';
import '../customer/customer_home_screen.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({
    super.key,
    this.initialIntent = AppUserRole.customer,
  });

  final String initialIntent;

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _name = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Введите имя — минимум 2 символа.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = TajGoScope.of(context);
      final user = scope.authService.currentUser!;
      await scope.userRepository.completeProfile(
        uid: user.uid,
        displayName: _name.text,
        initialIntent: widget.initialIntent,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => widget.initialIntent == AppUserRole.courier
              ? const CourierApplicationStatusScreen()
              : const CustomerHomeScreen(),
        ),
        (_) => false,
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось сохранить профиль.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = TajGoScope.of(context).authService.currentUser?.phoneNumber;
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль TajGo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const CircleAvatar(
              radius: 38,
              backgroundColor: TajGoColors.mint,
              child: Icon(
                Icons.person_rounded,
                size: 42,
                color: TajGoColors.darkGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Как вас называть?',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Фото можно добавить позже в профиле.',
              style: TextStyle(color: TajGoColors.muted),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Имя',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: phone ?? 'Тестовый вход · номер не подтверждён',
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Телефон',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.add_a_photo_outlined),
              title: Text('Фото профиля · необязательно'),
              subtitle: Text('Его можно добавить позже в профиле'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: TajGoColors.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const Text('Продолжить'),
            ),
          ],
        ),
      ),
    );
  }
}
