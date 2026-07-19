import 'package:flutter/material.dart';

import '../../core/models/app_user.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../auth/profile_completion_screen.dart';
import '../courier/courier_home_screen.dart';
import '../courier/courier_onboarding_screen.dart';
import '../courier/courier_application_status_screen.dart';
import '../customer/customer_home_screen.dart';
import 'intent_selection_screen.dart';
import 'role_onboarding_screen.dart';
import 'startup_decision.dart';

class AppStartupRouter extends StatefulWidget {
  const AppStartupRouter({super.key});

  @override
  State<AppStartupRouter> createState() => _AppStartupRouterState();
}

class _AppStartupRouterState extends State<AppStartupRouter> {
  Future<_StartupState>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _resolve();
  }

  Future<_StartupState> _resolve() async {
    final scope = TajGoScope.of(context);
    final firebaseUser = scope.authService.currentUser;
    if (firebaseUser == null) {
      return const _StartupState(StartupDestination.intent, null);
    }
    try {
      await scope.accountMigrationService.migrate(firebaseUser.uid);
    } catch (_) {
      // Migration is additive. A temporary rules/network failure must never
      // destroy or hide the existing account.
    }
    var profile = await scope.userRepository.getUser(firebaseUser.uid);
    if (profile == null) {
      await scope.userRepository.ensureUser(
        uid: firebaseUser.uid,
        phoneNumber: firebaseUser.phoneNumber,
        displayName: firebaseUser.displayName,
        phoneVerified:
            !firebaseUser.isAnonymous && firebaseUser.phoneNumber != null,
      );
      profile = await scope.userRepository.getUser(firebaseUser.uid);
    }
    return _StartupState(
      resolveStartupDestination(authenticated: true, profile: profile),
      profile,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_StartupState>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Не удалось загрузить аккаунт',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Проверьте интернет и попробуйте ещё раз.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => setState(() => _future = _resolve()),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final state = snapshot.data!;
      return switch (state.destination) {
        StartupDestination.intent => const IntentSelectionScreen(),
        StartupDestination.roleOnboarding => const RoleOnboardingScreen(),
        StartupDestination.profileCompletion => ProfileCompletionScreen(
          initialIntent: state.profile?.courierStatus == CourierStatus.draft
              ? AppUserRole.courier
              : AppUserRole.customer,
        ),
        StartupDestination.customerHome => const CustomerHomeScreen(),
        StartupDestination.courierOnboarding => const CourierOnboardingScreen(),
        StartupDestination.courierApplicationStatus =>
          CourierApplicationStatusScreen(
            status: state.profile?.courierStatus ?? CourierStatus.draft,
          ),
        StartupDestination.courierHome => const CourierHomeScreen(),
      };
    },
  );
}

class _StartupState {
  const _StartupState(this.destination, this.profile);
  final StartupDestination destination;
  final AppUser? profile;
}
