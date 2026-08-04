import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal/legal_documents.dart';
import '../../core/models/app_user.dart';
import '../../shared/design/tajgo_components.dart';
import '../../shared/widgets/tajgo_scope.dart';

/// Экран юридического документа (Политика/Условия) с записью согласия.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.document,
    this.showAcceptance = true,
  });

  final LegalDocument document;
  final bool showAcceptance;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  AppUser? _user;
  bool _loading = true;
  bool _saving = false;

  Future<void> _openPublicCopy() async {
    final uri = Uri.parse(widget.document.publicUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final user = await scope.userRepository.getUser(uid);
    if (mounted) {
      setState(() {
        _user = user;
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    setState(() => _saving = true);
    final scope = TajGoScope.of(context);
    try {
      await scope.userRepository.acceptLegalDocuments(
        privacyVersion: LegalDocuments.privacyVersion,
        termsVersion: LegalDocuments.termsVersion,
        locale: LegalDocuments.locale,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Согласие сохранено.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить. Повторите.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _accepted =>
      _user?.hasAcceptedLegal(
        LegalDocuments.privacyVersion,
        LegalDocuments.termsVersion,
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final signedIn = TajGoScope.of(context).authService.currentUser != null;
    return TajGoScaffold(
      appBar: TajGoAppBar(title: doc.title),
      body: ListView(
        padding: const EdgeInsets.all(TajGoSpacing.lg),
        children: [
          Text(
            'Версия ${doc.version} · обновлено ${doc.updated}',
            style: TajGoTypography.caption,
          ),
          const SizedBox(height: TajGoSpacing.lg),
          ...doc.sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: TajGoSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.heading, style: TajGoTypography.subtitle),
                  const SizedBox(height: TajGoSpacing.xs),
                  Text(section.body, style: TajGoTypography.body),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _openPublicCopy,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Открыть публичную версию'),
          ),
          const SizedBox(height: TajGoSpacing.lg),
          if (widget.showAcceptance && signedIn) ...[
            const Divider(),
            const SizedBox(height: TajGoSpacing.sm),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_accepted)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: TajGoColors.green,
                    size: TajGoIconSizes.md,
                  ),
                  const SizedBox(width: TajGoSpacing.sm),
                  Expanded(
                    child: Text(
                      'Вы приняли политику и условия'
                      '${_user?.legalAcceptedAt != null ? ' · ${_date(_user!.legalAcceptedAt!)}' : ''}',
                      style: TajGoTypography.caption,
                    ),
                  ),
                ],
              )
            else
              TajGoPrimaryButton(
                label: 'Принимаю политику и условия',
                loading: _saving,
                onPressed: _saving ? null : _accept,
              ),
          ],
        ],
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';
}
