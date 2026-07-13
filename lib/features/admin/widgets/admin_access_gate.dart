import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../../../shared/widgets/tajgo_scope.dart';

class AdminAccessGate extends StatelessWidget {
  const AdminAccessGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = TajGoScope.of(context);
    final user = scope.authService.currentUser;
    if (user == null) return const _NoAccess();
    return FutureBuilder(
      future: scope.userRepository.getUser(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data?.role == 'admin' || kDebugMode) return child;
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
