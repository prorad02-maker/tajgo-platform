import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/services/diagnostic_service.dart';
import '../firebase_options.dart';
import '../shared/widgets/tajgo_state_view.dart';
import 'tajgo_app.dart';
import 'tajgo_theme.dart';
import '../core/config/feature_flags.dart';

class TajGoBootstrap extends StatefulWidget {
  const TajGoBootstrap({
    super.key,
    this.initialize,
    this.diagnostics,
    this.ready,
  });
  final Future<void> Function()? initialize;
  final DiagnosticService? diagnostics;
  final Widget? ready;
  @override
  State<TajGoBootstrap> createState() => _TajGoBootstrapState();
}

class _TajGoBootstrapState extends State<TajGoBootstrap> {
  late final DiagnosticService _diagnostics;
  late final FeatureFlags _flags;
  late Future<void> _future;
  FlutterExceptionHandler? _previousFlutter;
  bool Function(Object, StackTrace)? _previousAsync;
  late final FlutterExceptionHandler _flutterHandler;
  late final bool Function(Object, StackTrace) _asyncHandler;
  @override
  void initState() {
    super.initState();
    _flags = FeatureFlags.resolve();
    _diagnostics =
        widget.diagnostics ??
        DiagnosticService(
          allowed:
              !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android &&
              _flags.crashReporting,
        );
    _previousFlutter = FlutterError.onError;
    _previousAsync = PlatformDispatcher.instance.onError;
    _flutterHandler = (details) {
      (_previousFlutter ?? FlutterError.presentError)(details);
      unawaited(
        _diagnostics.record(
          details.exception,
          details.stack ?? StackTrace.current,
          fatal: true,
        ),
      );
    };
    _asyncHandler = (error, stack) {
      unawaited(_diagnostics.record(error, stack, fatal: true));
      return _previousAsync?.call(error, stack) ?? false;
    };
    FlutterError.onError = _flutterHandler;
    PlatformDispatcher.instance.onError = _asyncHandler;
    _future = _initialize();
  }

  Future<void> _initialize() async {
    if (widget.initialize != null) {
      await widget.initialize!();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          _flags.appCheck) {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: const AndroidPlayIntegrityProvider(),
        );
      }
    }
    await _diagnostics.initialize();
  }

  @override
  void dispose() {
    if (identical(FlutterError.onError, _flutterHandler)) {
      FlutterError.onError = _previousFlutter;
    }
    if (identical(PlatformDispatcher.instance.onError, _asyncHandler)) {
      PlatformDispatcher.instance.onError = _previousAsync;
    }
    if (widget.diagnostics == null) _diagnostics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return widget.ready ??
            TajGoApp(diagnostics: _diagnostics, featureFlags: _flags);
      }
      return MaterialApp(
        title: 'TajGo',
        debugShowCheckedModeBanner: false,
        theme: TajGoTheme.light,
        home: Scaffold(
          body: snapshot.hasError
              ? TajGoStateView(
                  icon: Icons.cloud_off_rounded,
                  title: 'Не удалось запустить TajGo',
                  message: 'Проверьте подключение и попробуйте ещё раз.',
                  onRetry: () => setState(() {
                    _future = _initialize();
                  }),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      );
    },
  );
}
