import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/models/app_user.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../auth/profile_completion_screen.dart';
import '../admin/admin_home_screen.dart';
import '../courier/courier_home_screen.dart';
import '../courier/courier_onboarding_screen.dart';
import '../courier/courier_application_status_screen.dart';
import '../customer/customer_home_screen.dart';
import 'intent_selection_screen.dart';
import 'role_onboarding_screen.dart';
import 'startup_decision.dart';

/// Результат стартовой маршрутизации: куда идти + загруженный профиль.
class StartupState {
  const StartupState(this.destination, this.profile);
  final StartupDestination destination;
  final AppUser? profile;
}

class AppStartupRouter extends StatefulWidget {
  const AppStartupRouter({
    super.key,
    this.resolver,
    this.authUidStream,
    this.initialUid,
  });

  /// Инъекция резолвера/потока auth для тестов. По умолчанию — реальные стадии.
  final Future<StartupState> Function(BuildContext context)? resolver;
  final Stream<String?>? authUidStream;
  final String? initialUid;

  @override
  State<AppStartupRouter> createState() => _AppStartupRouterState();
}

class _AppStartupRouterState extends State<AppStartupRouter> {
  bool _loading = true;
  bool _inFlight = false;
  bool _pendingReload = false;
  bool _started = false;
  String? _lastUid;
  Object? _profileError;
  StartupState? _state;
  StreamSubscription<String?>? _authSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Подписка на изменения авторизации: startup пере-резолвится при null->User
    // (и любой смене uid), а не только при первом запуске.
    if (widget.authUidStream != null) {
      _lastUid = widget.initialUid;
      _authSub = widget.authUidStream!.listen(_onAuthChanged);
    } else {
      final scope = TajGoScope.of(context);
      _lastUid = scope.authService.currentUser?.uid;
      _authSub = scope.authService.authStateChanges
          .map((user) => user?.uid)
          .listen(_onAuthChanged);
    }

    // Первичный резолв — после кадра, чтобы setState не вызывался во время build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _onAuthChanged(String? uid) {
    debugPrint('[AUTH_STATE_CHANGE] uid=$uid');
    if (uid == _lastUid) return; // без изменений — не перезапускаем
    _lastUid = uid;
    // Смена авторизации во время активного resolve откладывается (коалесцируется),
    // чтобы после текущего resolve перечитать актуальное состояние. Ручной retry
    // (кнопка) при активном resolve, наоборот, просто дропается.
    if (_inFlight) {
      _pendingReload = true;
    } else {
      _load();
    }
  }

  /// Единая точка запуска/повтора startup. Никогда не передаёт async-колбэк в
  /// setState; параллельные запросы исключены (ручной повтор при активном
  /// resolve дропается; отложенный auth-повтор запускается в finally).
  Future<void> _load() async {
    if (_inFlight) return;
    _inFlight = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _profileError = null;
      });
    }
    try {
      final resolver = widget.resolver ?? _resolve;
      final result = await resolver(context);
      if (!mounted) return;
      setState(() {
        _state = result;
        _loading = false;
      });
    } catch (error, stackTrace) {
      final code = error is FirebaseException
          ? error.code
          : error.runtimeType.toString();
      debugPrint('[PROFILE_LOAD_ERROR] code=$code message=$error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _profileError = error;
        _loading = false;
      });
    } finally {
      _inFlight = false;
      if (_pendingReload && mounted) {
        _pendingReload = false;
        _load();
      }
    }
  }

  /// Стадии startup: (1) Firebase Auth, (2) загрузка users/{uid},
  /// (3) определение роли, (4) переход в shell.
  Future<StartupState> _resolve(BuildContext context) async {
    final scope = TajGoScope.of(context);

    // (1) Firebase Authentication.
    final firebaseUser = scope.authService.currentUser;
    debugPrint('[AUTH_STATE] uid=${firebaseUser?.uid ?? 'null'}');
    if (firebaseUser == null) {
      debugPrint('[STARTUP_ROUTE] role=intent');
      return const StartupState(StartupDestination.intent, null);
    }

    // (2) Загрузка профиля users/{uid}.
    debugPrint('[PROFILE_LOAD_START] uid=${firebaseUser.uid}');
    await scope.userRepository.ensureUser(
      uid: firebaseUser.uid,
      phoneNumber: firebaseUser.phoneNumber,
      displayName: firebaseUser.displayName,
      phoneVerified:
          !firebaseUser.isAnonymous && firebaseUser.phoneNumber != null,
    );
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
    debugPrint('[PROFILE_LOAD_SUCCESS] uid=${firebaseUser.uid}');
    if (profile != null) {
      await scope.rolePreferenceService.save(profile.lastMode);
    }

    // (3) Определение роли и (4) переход в shell.
    final destination = resolveStartupDestination(
      authenticated: true,
      profile: profile,
    );
    debugPrint('[STARTUP_ROUTE] role=${profile?.role ?? 'unknown'}');
    return StartupState(destination, profile);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profileError != null) {
      return _ProfileErrorScreen(
        onRetry: _inFlight ? null : () => _load(),
      );
    }
    final state = _state!;
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
      StartupDestination.adminHome => const AdminHomeScreen(),
    };
  }
}

/// Ошибка загрузки профиля (после успешного входа). Не «Не удалось войти».
class _ProfileErrorScreen extends StatelessWidget {
  const _ProfileErrorScreen({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
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
                  'Вход выполнен, но не удалось загрузить профиль',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Проверьте интернет и попробуйте ещё раз.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
