import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class DiagnosticPort {
  Future<void> collection(bool enabled);
  Future<void> deleteUnsent();
  Future<void> record(String type, StackTrace stack, {required bool fatal});
}

class FirebaseDiagnostics implements DiagnosticPort {
  @override
  Future<void> collection(bool enabled) =>
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
  @override
  Future<void> deleteUnsent() =>
      FirebaseCrashlytics.instance.deleteUnsentReports();
  @override
  Future<void> record(String type, StackTrace stack, {required bool fatal}) =>
      FirebaseCrashlytics.instance.recordError(
        type,
        stack,
        fatal: fatal,
        printDetails: false,
      );
}

class DiagnosticService extends ChangeNotifier {
  DiagnosticService({
    DiagnosticPort? port,
    SharedPreferencesAsync? preferences,
    bool? supported,
    bool? release,
    this.allowed = true,
  }) : _port = port ?? FirebaseDiagnostics(),
       _preferences = preferences ?? SharedPreferencesAsync(),
       supported =
           supported ??
           (!kIsWeb &&
               {
                 TargetPlatform.android,
                 TargetPlatform.iOS,
                 TargetPlatform.macOS,
               }.contains(defaultTargetPlatform)),
       _release = release ?? kReleaseMode;
  static const preferenceKey = 'tajgo.diagnostics.enabled';
  final DiagnosticPort _port;
  final SharedPreferencesAsync _preferences;
  final bool supported, _release;
  final bool allowed;
  bool enabled = false, busy = false;
  String? error;
  bool _disposed = false;
  Future<void>? _initializing;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> retry() => _initializing = _initialize();
  Future<void> _initialize() async {
    if (!supported) return;
    error = null;
    try {
      await _port.collection(false);
      enabled = allowed && await _preferences.getBool(preferenceKey) == true;
      await _port.collection(enabled && _release);
      if (!enabled) await _port.deleteUnsent();
    } catch (_) {
      enabled = false;
      error = 'Не удалось загрузить настройку отчётов.';
    }
    _changed();
  }

  Future<void> setEnabled(bool value) async {
    if (!supported || !allowed || busy || _disposed) return;
    busy = true;
    error = null;
    if (!value) enabled = false;
    _changed();
    try {
      // Reports produced before consent must not be uploaded retroactively.
      if (value) {
        await _port.deleteUnsent();
        await _preferences.setBool(preferenceKey, true);
        await _port.collection(_release);
      } else {
        await Future.wait([
          _port.collection(false),
          _preferences.setBool(preferenceKey, false),
          _port.deleteUnsent(),
        ]);
      }
      enabled = value;
    } catch (_) {
      error = 'Не удалось изменить настройку отчётов. Попробуйте ещё раз.';
    } finally {
      busy = false;
      _changed();
    }
  }

  static StackTrace safeStack(StackTrace stack) => StackTrace.fromString(
    stack
        .toString()
        .split('\n')
        .where(
          (line) => RegExp(
            r'^#\d+\s+.*\((package:|dart:)[^\n]+:\d+(:\d+)?\)$',
          ).hasMatch(line),
        )
        .take(64)
        .join('\n'),
  );
  Future<void> record(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    if (!supported || !enabled || !_release || _disposed) return;
    try {
      await _port.record(
        error.runtimeType.toString(),
        safeStack(stack),
        fatal: fatal,
      );
    } catch (_) {
      /* A reporting failure must not become another app failure. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
