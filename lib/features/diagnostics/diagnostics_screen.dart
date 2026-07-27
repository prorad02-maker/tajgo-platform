import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../shared/design/tajgo_components.dart';
import '../../shared/widgets/tajgo_scope.dart';

/// Экран диагностики (pilot/debug). Скрыт в production (за флагом `diagnostics`).
/// Не показывает код получения, полный телефон, полный адрес, API-ключи или
/// полный FCM-токен.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Map<String, String> _report = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _collect());
  }

  Future<void> _collect() async {
    final scope = TajGoScope.of(context);
    final flags = scope.featureFlags;
    final user = scope.authService.currentUser;
    final report = <String, String>{
      'Среда': flags.environment.label,
      'Режим сборки': kReleaseMode ? 'release' : 'debug',
      'Firebase project': _safe(() => Firebase.app().options.projectId),
      'Регион Functions': 'europe-west1',
      'Авторизация': user == null ? 'нет' : 'есть',
      'UID (маскирован)': _maskUid(user?.uid),
      'Телефон подтверждён': user?.phoneNumber == null ? 'нет' : 'да',
      'Уведомления (флаг)': flags.notifications ? 'вкл' : 'выкл',
      'Crashlytics (флаг)': flags.crashReporting ? 'вкл' : 'выкл',
      'App Check (флаг)': flags.appCheck ? 'вкл' : 'выкл',
      'Preview-данные': flags.previewData ? 'вкл' : 'выкл',
      'Road routing': flags.publicPilotRouting ? 'вкл' : 'выкл (fallback)',
    };
    try {
      final permission = await Geolocator.checkPermission();
      report['GPS разрешение'] = permission.name;
      report['GPS сервис'] =
          (await Geolocator.isLocationServiceEnabled()) ? 'вкл' : 'выкл';
    } catch (_) {
      report['GPS разрешение'] = 'недоступно';
    }
    if (mounted) {
      setState(() {
        _report = report;
        _loading = false;
      });
    }
  }

  static String _safe(String Function() f) {
    try {
      return f();
    } catch (_) {
      return '—';
    }
  }

  static String _maskUid(String? uid) {
    if (uid == null || uid.isEmpty) return '—';
    if (uid.length <= 6) return '***';
    return '${uid.substring(0, 6)}***';
  }

  void _copy() {
    final text = _report.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: 'TajGo диагностика\n$text'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Отчёт скопирован.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TajGoScaffold(
      appBar: const TajGoAppBar(title: 'Диагностика'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(TajGoSpacing.lg),
              children: [
                TajGoCard(
                  padding: const EdgeInsets.all(TajGoSpacing.lg),
                  child: Column(
                    children: _report.entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: TajGoSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(e.key,
                                      style: TajGoTypography.caption),
                                ),
                                Text(e.value, style: TajGoTypography.bodyStrong),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: TajGoSpacing.lg),
                TajGoPrimaryButton(
                  label: 'Скопировать диагностический отчёт',
                  icon: Icons.copy_rounded,
                  onPressed: _copy,
                ),
              ],
            ),
    );
  }
}
