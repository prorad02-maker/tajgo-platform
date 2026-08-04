import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal/legal_documents.dart';
import '../../core/models/app_user.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/authoritative_command_service.dart';
import '../../shared/design/tajgo_components.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../startup/intent_selection_screen.dart';

enum _DeletionPhase { checking, blocked, intro, codeEntry, confirm, done }

/// In-app удаление аккаунта: последствия, запрет при активном заказе,
/// повторная SMS-авторизация, финальное подтверждение и logout.
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final TextEditingController _code = TextEditingController();

  _DeletionPhase _phase = _DeletionPhase.checking;
  AppUser? _user;

  Future<void> _openPublicDeletionPage() => launchUrl(
    Uri.parse(LegalDocuments.accountDeletionUrl),
    mode: LaunchMode.externalApplication,
  );
  bool _busy = false;
  bool _acknowledged = false;
  String? _verificationId;
  String? _error;

  static const List<String> _deletedData = [
    'Имя и номер телефона',
    'Сохранённые адреса',
    'Присутствие курьера и геолокация',
    'Токены уведомлений',
  ];
  static const List<String> _retainedData = [
    'Обезличенная история заказов',
    'Спорные заказы и обязательные операционные записи',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkEligibility());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _checkEligibility() async {
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _phase = _DeletionPhase.blocked);
      return;
    }
    try {
      final user = await scope.userRepository.getUser(uid);
      final hasCustomerOrder = await scope.orderRepository.hasActiveOrder(uid);
      final courier = await scope.courierRepository.getCourier(uid);
      final courierBusy =
          courier?.activeOrderId != null || courier?.isBusy == true;
      if (!mounted) return;
      setState(() {
        _user = user;
        _phase = (hasCustomerOrder || courierBusy)
            ? _DeletionPhase.blocked
            : _DeletionPhase.intro;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось проверить статус заказов. Повторите позже.';
          _phase = _DeletionPhase.blocked;
        });
      }
    }
  }

  Future<void> _continueFromIntro() async {
    final phone = _user?.phoneNumber;
    // Пользователи без подтверждённого номера (debug/тест) пропускают SMS re-auth.
    if (phone == null || phone.trim().isEmpty) {
      setState(() => _phase = _DeletionPhase.confirm);
      return;
    }
    await _sendReauthCode(phone);
  }

  Future<void> _sendReauthCode(String phone) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await TajGoScope.of(
        context,
      ).authService.requestPhoneCode(phoneNumber: phone);
      if (!mounted) return;
      if (session.isAutoVerified) {
        // Мгновенная верификация уже обновила сессию — код не нужен.
        setState(() => _phase = _DeletionPhase.confirm);
      } else {
        setState(() {
          _verificationId = session.verificationId;
          _phase = _DeletionPhase.codeEntry;
        });
      }
    } on PhoneAuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось отправить код. Повторите позже.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCode() async {
    final id = _verificationId;
    final code = _code.text.trim();
    if (id == null || code.length < 4) {
      setState(() => _error = 'Введите код из SMS.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TajGoScope.of(context).authService.reauthenticateWithSmsCode(
        verificationId: id,
        smsCode: code,
      );
      if (mounted) setState(() => _phase = _DeletionPhase.confirm);
    } on PhoneAuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось подтвердить код. Повторите.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await scope.pushNotificationService.disableForUser(uid);
      await scope.userRepository.deleteAccountRequest(uid: uid);
      await scope.authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const IntentSelectionScreen()),
        (_) => false,
      );
    } on TajGoCommandException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.reason == 'active-order'
              ? 'Сначала завершите активный заказ.'
              : error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Не удалось удалить аккаунт. Проверьте связь и повторите.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TajGoScaffold(
      appBar: const TajGoAppBar(title: 'Удалить аккаунт'),
      body: switch (_phase) {
        _DeletionPhase.checking => const Center(
          child: CircularProgressIndicator(),
        ),
        _DeletionPhase.blocked => _blockedView(),
        _DeletionPhase.intro => _introView(),
        _DeletionPhase.codeEntry => _codeView(),
        _DeletionPhase.confirm => _confirmView(),
        _DeletionPhase.done => const SizedBox.shrink(),
      },
    );
  }

  Widget _blockedView() {
    return TajGoErrorState(
      title: 'Удаление сейчас недоступно',
      message:
          _error ??
          'Дождитесь завершения активного заказа, затем повторите. '
              'Так мы защищаем незавершённые операции.',
      onRetry: () {
        setState(() => _phase = _DeletionPhase.checking);
        _checkEligibility();
      },
    );
  }

  Widget _introView() {
    return ListView(
      padding: const EdgeInsets.all(TajGoSpacing.lg),
      children: [
        Text('Что произойдёт', style: TajGoTypography.title),
        const SizedBox(height: TajGoSpacing.sm),
        Text(
          'Удаление аккаунта необратимо. Мы обезличим ваши персональные данные '
          'и завершим вход в TajGo на этом устройстве.',
          style: TajGoTypography.body,
        ),
        const SizedBox(height: TajGoSpacing.lg),
        _DataCard(
          title: 'Будет удалено или обезличено',
          icon: Icons.delete_outline_rounded,
          items: _deletedData,
        ),
        const SizedBox(height: TajGoSpacing.md),
        _DataCard(
          title: 'Сохраняется в обезличенном виде',
          icon: Icons.inventory_2_outlined,
          items: _retainedData,
          muted: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: TajGoSpacing.md),
          Text(
            _error!,
            style: TajGoTypography.caption.copyWith(color: TajGoColors.error),
          ),
        ],
        const SizedBox(height: TajGoSpacing.xl),
        TextButton.icon(
          onPressed: _openPublicDeletionPage,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Публичная страница удаления'),
        ),
        const SizedBox(height: TajGoSpacing.sm),
        TajGoPrimaryButton(
          label: 'Продолжить',
          loading: _busy,
          backgroundColor: TajGoColors.error,
          foregroundColor: Colors.white,
          onPressed: _busy ? null : _continueFromIntro,
        ),
      ],
    );
  }

  Widget _codeView() {
    return ListView(
      padding: const EdgeInsets.all(TajGoSpacing.lg),
      children: [
        Text('Подтвердите личность', style: TajGoTypography.title),
        const SizedBox(height: TajGoSpacing.sm),
        Text(
          'Мы отправили SMS с кодом на ${_user?.phoneNumber ?? 'ваш номер'}. '
          'Введите код, чтобы подтвердить удаление.',
          style: TajGoTypography.body,
        ),
        const SizedBox(height: TajGoSpacing.lg),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: TajGoTypography.title,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            counterText: '',
            hintText: '••••••',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: TajGoSpacing.sm),
          Text(
            _error!,
            style: TajGoTypography.caption.copyWith(color: TajGoColors.error),
          ),
        ],
        const SizedBox(height: TajGoSpacing.xl),
        TajGoPrimaryButton(
          label: 'Подтвердить',
          loading: _busy,
          onPressed: _busy ? null : _confirmCode,
        ),
      ],
    );
  }

  Widget _confirmView() {
    return ListView(
      padding: const EdgeInsets.all(TajGoSpacing.lg),
      children: [
        Text('Последнее подтверждение', style: TajGoTypography.title),
        const SizedBox(height: TajGoSpacing.sm),
        Text(
          'После нажатия «Удалить аккаунт» ваши данные будут обезличены, '
          'а вход завершён. Отменить это действие нельзя.',
          style: TajGoTypography.body,
        ),
        const SizedBox(height: TajGoSpacing.lg),
        CheckboxListTile(
          value: _acknowledged,
          onChanged: _busy
              ? null
              : (value) => setState(() => _acknowledged = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: TajGoColors.error,
          title: Text(
            'Я понимаю, что удаление необратимо',
            style: TajGoTypography.body,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: TajGoSpacing.sm),
          Text(
            _error!,
            style: TajGoTypography.caption.copyWith(color: TajGoColors.error),
          ),
        ],
        const SizedBox(height: TajGoSpacing.xl),
        TajGoPrimaryButton(
          label: 'Удалить аккаунт',
          icon: Icons.delete_forever_rounded,
          loading: _busy,
          backgroundColor: TajGoColors.error,
          foregroundColor: Colors.white,
          onPressed: (_acknowledged && !_busy) ? _delete : null,
        ),
      ],
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.title,
    required this.icon,
    required this.items,
    this.muted = false,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return TajGoCard(
      padding: const EdgeInsets.all(TajGoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: TajGoIconSizes.md,
                color: muted ? TajGoColors.muted : TajGoColors.error,
              ),
              const SizedBox(width: TajGoSpacing.sm),
              Expanded(child: Text(title, style: TajGoTypography.bodyStrong)),
            ],
          ),
          const SizedBox(height: TajGoSpacing.sm),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: TajGoSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TajGoTypography.body),
                  Expanded(child: Text(item, style: TajGoTypography.body)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
