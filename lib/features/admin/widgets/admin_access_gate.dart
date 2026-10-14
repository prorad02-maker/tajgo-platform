import 'package:flutter/material.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../../../shared/widgets/tajgo_scope.dart';
import '../../../shared/widgets/tajgo_state_view.dart';
import '../../../core/models/app_user.dart';

class AdminAccessGate extends StatefulWidget {
  const AdminAccessGate({super.key, required this.child});

  final Widget child;

  @override
  State<AdminAccessGate> createState() => _AdminAccessGateState();
}

class _AdminAccessGateState extends State<AdminAccessGate> {
  Stream<AppUser?>? _profile;
  String? _uid;
  Stream<AppUser?> _load() =>
      TajGoScope.of(context).userRepository.userStream(_uid!);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = TajGoScope.of(context).authService.currentUser?.uid;
    if (uid != _uid || _profile == null) {
      _uid = uid;
      _profile = uid == null ? Stream.value(null) : _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final user = scope.authService.currentUser;
    if (user == null) return const _NoAccess();
    return StreamBuilder<AppUser?>(
      stream: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Управление TajGo')),
            body: TajGoStateView(
              icon: Icons.cloud_off_rounded,
              title: 'Не удалось проверить доступ',
              message: 'Проверьте интернет и попробуйте ещё раз.',
              onRetry: () => setState(() => _profile = _load()),
              actionLabel: 'Повторить',
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data?.isAdmin == true) return widget.child;
        return const _NoAccess();
      },
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Управление TajGo')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 54, color: TajGoColors.muted),
            SizedBox(height: 16),
            Text(
              'Нет доступа. Раздел доступен только администраторам TajGo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
}
