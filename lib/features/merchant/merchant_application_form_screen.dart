import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/marketplace_partner.dart';
import '../../core/models/merchant_application.dart';
import '../../core/services/authoritative_command_service.dart';
import '../../shared/design/tajgo_components.dart';
import '../../shared/widgets/tajgo_scope.dart';
import '../map/screens/map_point_picker_screen.dart';

/// Форма заявки магазина: создание/редактирование, черновик и отправка.
class MerchantApplicationFormScreen extends StatefulWidget {
  const MerchantApplicationFormScreen({super.key, this.existing});

  final MerchantApplication? existing;

  @override
  State<MerchantApplicationFormScreen> createState() =>
      _MerchantApplicationFormScreenState();
}

class _MerchantApplicationFormScreenState
    extends State<MerchantApplicationFormScreen> {
  late final TextEditingController _storeName;
  late final TextEditingController _ownerName;
  late final TextEditingController _phone;
  late final TextEditingController _extraContact;
  late final TextEditingController _address;
  late final TextEditingController _workingHours;
  late final TextEditingController _description;
  late final TextEditingController _minimumOrder;
  late final TextEditingController _comment;

  String _category = 'food';
  String _deliveryMode = MerchantDeliveryMode.tajgo;
  GeoPoint? _location;
  bool _consent = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _storeName = TextEditingController(text: e?.storeName ?? '');
    _ownerName = TextEditingController(text: e?.ownerName ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _extraContact = TextEditingController(text: e?.extraContact ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _workingHours = TextEditingController(text: e?.workingHours ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _minimumOrder = TextEditingController(
      text: (e?.minimumOrder ?? 0) > 0 ? '${e!.minimumOrder}' : '',
    );
    _comment = TextEditingController(text: e?.comment ?? '');
    _category = marketplaceCategories.contains(e?.category)
        ? e!.category
        : 'food';
    _deliveryMode = e?.deliveryMode ?? MerchantDeliveryMode.tajgo;
    _location = e?.location;
    _consent = e?.consent ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _storeName,
      _ownerName,
      _phone,
      _extraContact,
      _address,
      _workingHours,
      _description,
      _minimumOrder,
      _comment,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _fields({required bool full}) {
    final minOrder = num.tryParse(_minimumOrder.text.trim()) ?? 0;
    return {
      if (_storeName.text.trim().isNotEmpty) 'storeName': _storeName.text.trim(),
      'category': _category,
      if (_ownerName.text.trim().isNotEmpty) 'ownerName': _ownerName.text.trim(),
      if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
      if (_extraContact.text.trim().isNotEmpty)
        'extraContact': _extraContact.text.trim(),
      if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
      if (_location != null)
        'location': {
          'latitude': _location!.latitude,
          'longitude': _location!.longitude,
        },
      if (_workingHours.text.trim().isNotEmpty)
        'workingHours': _workingHours.text.trim(),
      if (_description.text.trim().isNotEmpty)
        'description': _description.text.trim(),
      'minimumOrder': minOrder,
      'deliveryMode': _deliveryMode,
      if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
      if (full || _consent) 'consent': _consent,
    };
  }

  String? _validateForSubmit() {
    if (_storeName.text.trim().length < 2) return 'Укажите название магазина.';
    if (_ownerName.text.trim().length < 2) return 'Укажите имя владельца.';
    if (_phone.text.trim().length < 5) return 'Укажите телефон.';
    if (_address.text.trim().length < 2) return 'Укажите адрес.';
    if (_location == null) return 'Выберите точку на карте.';
    if (!_consent) return 'Подтвердите согласие на обработку данных.';
    return null;
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute<LatLng>(
        builder: (_) => MapPointPickerScreen(
          title: 'Точка магазина',
          initial: _location == null
              ? null
              : LatLng(_location!.latitude, _location!.longitude),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _location = GeoPoint(result.latitude, result.longitude));
    }
  }

  Future<void> _saveDraft() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TajGoScope.of(
        context,
      ).merchantApplicationRepository.saveDraft(_fields(full: false));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось сохранить черновик.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final validation = _validateForSubmit();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final scope = TajGoScope.of(context);
    final repo = scope.merchantApplicationRepository;
    final uid = scope.authService.currentUser!.uid;
    try {
      if (widget.existing?.needsInfo == true) {
        await repo.update(_fields(full: true));
      } else {
        await repo.submit(uid, _fields(full: true));
      }
      if (mounted) Navigator.pop(context);
    } on TajGoCommandException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось отправить заявку. Повторите.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpdate = widget.existing?.needsInfo == true;
    return TajGoScaffold(
      appBar: TajGoAppBar(
        title: isUpdate ? 'Обновить заявку' : 'Подключить магазин',
      ),
      body: ListView(
        padding: const EdgeInsets.all(TajGoSpacing.lg),
        children: [
          _field('Название магазина', _storeName),
          _categoryField(),
          _field('Имя владельца', _ownerName),
          _field('Телефон', _phone, keyboard: TextInputType.phone),
          _field('Дополнительный контакт (необязательно)', _extraContact),
          _field('Адрес', _address),
          _locationTile(),
          _field('График работы (необязательно)', _workingHours),
          _field('Описание (необязательно)', _description, maxLines: 3),
          _field(
            'Минимальный заказ, сомони',
            _minimumOrder,
            keyboard: TextInputType.number,
          ),
          _deliveryField(),
          _field('Комментарий (необязательно)', _comment, maxLines: 2),
          const SizedBox(height: TajGoSpacing.sm),
          CheckboxListTile(
            value: _consent,
            onChanged: _busy
                ? null
                : (v) => setState(() => _consent = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: TajGoColors.green,
            title: Text(
              'Согласен на обработку данных заявки',
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
          const SizedBox(height: TajGoSpacing.lg),
          TajGoPrimaryButton(
            label: isUpdate ? 'Отправить обновление' : 'Отправить заявку',
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
          if (!isUpdate) ...[
            const SizedBox(height: TajGoSpacing.sm),
            TajGoSecondaryButton(
              label: 'Сохранить черновик',
              onPressed: _busy ? null : _saveDraft,
            ),
          ],
          const SizedBox(height: TajGoSpacing.xl),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TajGoSpacing.md),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: TajGoTypography.body,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: TajGoColors.card,
          border: OutlineInputBorder(borderRadius: TajGoRadius.smAll),
        ),
      ),
    );
  }

  Widget _categoryField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: TajGoSpacing.md),
      child: DropdownButtonFormField<String>(
        initialValue: _category,
        decoration: InputDecoration(
          labelText: 'Категория',
          filled: true,
          fillColor: TajGoColors.card,
          border: OutlineInputBorder(borderRadius: TajGoRadius.smAll),
        ),
        items: marketplaceCategories
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(marketplaceCategoryLabel(c)),
              ),
            )
            .toList(growable: false),
        onChanged: (v) => setState(() => _category = v ?? 'food'),
      ),
    );
  }

  Widget _locationTile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: TajGoSpacing.md),
      child: TajGoCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(
            Icons.location_on_rounded,
            color: _location == null ? TajGoColors.muted : TajGoColors.green,
          ),
          title: Text(
            _location == null ? 'Точка на карте' : 'Точка выбрана',
            style: TajGoTypography.body,
          ),
          subtitle: _location == null
              ? Text('Укажите расположение магазина',
                  style: TajGoTypography.caption)
              : Text(
                  '${_location!.latitude.toStringAsFixed(5)}, '
                  '${_location!.longitude.toStringAsFixed(5)}',
                  style: TajGoTypography.caption,
                ),
          trailing: const Icon(Icons.map_outlined),
          onTap: _busy ? null : _pickLocation,
        ),
      ),
    );
  }

  Widget _deliveryField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: TajGoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Доставка', style: TajGoTypography.label),
          const SizedBox(height: TajGoSpacing.xs),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: MerchantDeliveryMode.tajgo,
                label: Text('TajGo'),
              ),
              ButtonSegment(
                value: MerchantDeliveryMode.self,
                label: Text('Своя'),
              ),
            ],
            selected: {_deliveryMode},
            onSelectionChanged: (v) =>
                setState(() => _deliveryMode = v.first),
          ),
        ],
      ),
    );
  }
}
