import 'package:flutter/material.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../../../core/models/courier_application.dart';
import '../../../shared/widgets/tajgo_scope.dart';
import '../courier_application_status_screen.dart';

class CourierApplicationFlowScreen extends StatefulWidget {
  const CourierApplicationFlowScreen({
    super.key,
    required this.initialApplication,
  });

  final CourierApplication initialApplication;

  @override
  State<CourierApplicationFlowScreen> createState() =>
      _CourierApplicationFlowScreenState();
}

class _CourierApplicationFlowScreenState
    extends State<CourierApplicationFlowScreen> {
  late final TextEditingController _name;
  late final TextEditingController _birthDate;
  late final TextEditingController _documentNumber;
  late int _step;
  late String _transport;
  late String _documentType;
  late String _district;
  late String _availability;
  late bool _termsAccepted;
  late bool _dataConsent;
  bool _busy = false;
  bool _closing = false;
  String? _error;

  static const _districts = [
    'Весь город',
    'Центр',
    'Панчшанбе',
    '34-й микрорайон',
    'Сырдарья',
  ];
  static const _availabilityOptions = [
    'Свободный график',
    'Утро',
    'День',
    'Вечер',
  ];

  @override
  void initState() {
    super.initState();
    final app = widget.initialApplication;
    _name = TextEditingController(text: app.displayName);
    _birthDate = TextEditingController(text: app.birthDate);
    _documentNumber = TextEditingController(text: app.documentNumber);
    _step = app.currentStep;
    _transport = app.transport;
    _documentType = app.documentType;
    _district = app.workDistrict;
    _availability = app.availability;
    _termsAccepted = app.termsAccepted;
    _dataConsent = app.dataConsent;
  }

  @override
  void dispose() {
    _name.dispose();
    _birthDate.dispose();
    _documentNumber.dispose();
    super.dispose();
  }

  CourierApplication _draft([int? step]) => CourierApplication(
    uid: widget.initialApplication.uid,
    displayName: _name.text.trim(),
    phoneNumber: widget.initialApplication.phoneNumber,
    status: 'draft',
    currentStep: step ?? _step,
    birthDate: _birthDate.text.trim().isEmpty ? null : _birthDate.text.trim(),
    profilePhotoUrl: widget.initialApplication.profilePhotoUrl,
    transport: _transport,
    documentType: _documentType,
    documentNumber: _documentNumber.text.trim(),
    documentPhotoUrl: widget.initialApplication.documentPhotoUrl,
    transportPhotoUrl: widget.initialApplication.transportPhotoUrl,
    city: 'Худжанд',
    workDistrict: _district,
    availability: _availability,
    termsAccepted: _termsAccepted,
    dataConsent: _dataConsent,
    storageEnabled: courierStorageEnabled,
    verificationMethod:
        courierStorageEnabled &&
            widget.initialApplication.documentPhotoUrl != null &&
            (_transport == CourierTransport.walking ||
                widget.initialApplication.transportPhotoUrl != null)
        ? 'storage'
        : 'personalMeeting',
    history: widget.initialApplication.history,
  );

  String? _validationError() => switch (_step) {
    0 when _name.text.trim().length < 2 => 'Введите имя — минимум 2 символа.',
    1 when !CourierTransport.values.contains(_transport) =>
      'Выберите доступный транспорт.',
    2 when _documentNumber.text.trim().length < 3 => 'Введите номер документа.',
    2 when !_termsAccepted || !_dataConsent => 'Подтвердите оба согласия.',
    _ => null,
  };

  Future<bool> _save({int? step}) async {
    if (_busy) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TajGoScope.of(
        context,
      ).courierApplicationRepository.saveDraft(_draft(step));
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    final error = _validationError();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final next = (_step + 1).clamp(0, 4);
    if (await _save(step: next) && mounted) setState(() => _step = next);
  }

  Future<void> _submit() async {
    if (!await _save(step: 4) || !mounted) return;
    setState(() => _busy = true);
    try {
      await TajGoScope.of(
        context,
      ).courierApplicationRepository.submit(widget.initialApplication.uid);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
              const CourierApplicationStatusScreen(status: 'pending'),
        ),
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAndClose() async {
    if (_closing) return;
    _closing = true;
    final saved = await _save();
    if (saved && mounted) {
      Navigator.pop(context);
    } else {
      _closing = false;
    }
  }

  String _message(Object error) => error is StateError
      ? error.message
      : 'Не удалось сохранить анкету. Проверьте интернет и права доступа.';

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _saveAndClose();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _busy ? null : _saveAndClose,
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text('Анкета курьера · ${_step + 1}/5'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / 5),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _content(),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: TajGoColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: _busy ? null : () => setState(() => _step--),
                      child: const Text('Назад'),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : _step == 4
                          ? _submit
                          : _next,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _step == 4
                                  ? 'Отправить заявку'
                                  : 'Сохранить и продолжить',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _content() => switch (_step) {
    0 => _basicStep(),
    1 => _transportStep(),
    2 => _documentsStep(),
    3 => _areaStep(),
    _ => _reviewStep(),
  };

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: TajGoColors.muted)),
      const SizedBox(height: 20),
    ],
  );

  Widget _basicStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Основные данные', 'Проверьте имя и телефон.'),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Имя',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        initialValue:
            widget.initialApplication.phoneNumber ??
            'Номер не подтверждён · доступен только debug',
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Телефон',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _birthDate,
        keyboardType: TextInputType.datetime,
        decoration: const InputDecoration(
          labelText: 'Дата рождения · необязательно',
          hintText: 'ДД.ММ.ГГГГ',
          border: OutlineInputBorder(),
        ),
      ),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.add_a_photo_outlined),
        title: Text('Фото профиля · необязательно'),
        subtitle: Text('Поле URL зарезервировано; загрузка зависит от Storage'),
      ),
    ],
  );

  Widget _transportStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Как вы будете доставлять?', 'Выберите основной транспорт.'),
      ...[
        CourierTransport.walking,
        CourierTransport.bicycle,
        CourierTransport.electricBike,
        CourierTransport.scooter,
      ].map(
        (value) => Card(
          color: _transport == value ? TajGoColors.mint : null,
          child: ListTile(
            leading: Icon(
              _transport == value
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: _transport == value ? TajGoColors.darkGreen : null,
            ),
            title: Text(CourierTransport.label(value)),
            onTap: () => setState(() => _transport = value),
          ),
        ),
      ),
      const ListTile(
        enabled: false,
        leading: Icon(Icons.directions_car_rounded),
        title: Text('Автомобиль'),
        trailing: Chip(label: Text('Позже')),
      ),
    ],
  );

  Widget _documentsStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Проверка документов',
        'Данные видят только вы и администратор.',
      ),
      DropdownButtonFormField<String>(
        initialValue: _documentType,
        decoration: const InputDecoration(
          labelText: 'Тип документа',
          border: OutlineInputBorder(),
        ),
        items: CourierDocumentType.values
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(CourierDocumentType.label(value)),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _documentType = value!),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _documentNumber,
        decoration: const InputDecoration(
          labelText: 'Номер документа',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 14),
      Card(
        color: TajGoColors.soonBg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            courierStorageEnabled
                ? 'Storage-флаг включён, но production uploader ещё не подключён. '
                      'Не отправляйте реальные документы до настройки Storage Rules.'
                : 'Фото пока не нужны — покажете документ и транспорт при личной встрече. '
                      'Мы честно не изображаем загрузку как готовую.',
          ),
        ),
      ),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.badge_outlined),
        title: Text('Фото документа'),
        subtitle: Text('Проверим оригинал и сделаем фото при личной встрече'),
      ),
      if (_transport != CourierTransport.walking)
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.pedal_bike_rounded),
          title: Text('Фото транспорта'),
          subtitle: Text(
            'Проверим транспорт и сделаем фото при личной встрече',
          ),
        ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _dataConsent,
        onChanged: (value) => setState(() => _dataConsent = value ?? false),
        title: const Text('Данные используются только для проверки'),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _termsAccepted,
        onChanged: (value) => setState(() => _termsAccepted = value ?? false),
        title: const Text('Согласен с правилами работы курьера TajGo'),
      ),
    ],
  );

  Widget _areaStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Зона работы', 'На пилоте работаем только в Худжанде.'),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.location_city_rounded),
        title: Text('Худжанд'),
        subtitle: Text('Город запуска'),
      ),
      const Text('Район · необязательно'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: _districts
            .map(
              (value) => ChoiceChip(
                label: Text(value),
                selected: _district == value,
                onSelected: (_) => setState(() => _district = value),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 18),
      const Text('Когда удобно работать · необязательно'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: _availabilityOptions
            .map(
              (value) => ChoiceChip(
                label: Text(value),
                selected: _availability == value,
                onSelected: (_) => setState(() => _availability = value),
              ),
            )
            .toList(),
      ),
    ],
  );

  Widget _reviewStep() {
    final draft = _draft(4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Проверьте данные',
          'После отправки анкету увидит администратор.',
        ),
        _ReviewTile(
          title: 'Основные данные',
          value: '${draft.displayName}\n${draft.phoneNumber ?? 'Без телефона'}',
          onEdit: () => setState(() => _step = 0),
        ),
        _ReviewTile(
          title: 'Транспорт',
          value: CourierTransport.label(draft.transport),
          onEdit: () => setState(() => _step = 1),
        ),
        _ReviewTile(
          title: 'Документ',
          value:
              '${CourierDocumentType.label(draft.documentType)} · ${draft.documentNumber}',
          onEdit: () => setState(() => _step = 2),
        ),
        _ReviewTile(
          title: 'Зона',
          value: '${draft.city} · ${draft.workDistrict}\n${draft.availability}',
          onEdit: () => setState(() => _step = 3),
        ),
        const SizedBox(height: 8),
        const Text(
          'После отправки статус станет «На проверке». Заказывать доставку можно как обычно.',
          style: TextStyle(color: TajGoColors.muted),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.title,
    required this.value,
    required this.onEdit,
  });
  final String title;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(value),
      trailing: TextButton(onPressed: onEdit, child: const Text('Изменить')),
    ),
  );
}
