import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/saved_address.dart';
import '../../../shared/design/tajgo_components.dart';
import '../../../shared/widgets/tajgo_scope.dart';
import '../../map/screens/map_point_picker_screen.dart';

/// Создание/редактирование сохранённого адреса. Точка на карте необязательна —
/// адрес можно ввести вручную без GPS.
class SavedAddressFormScreen extends StatefulWidget {
  const SavedAddressFormScreen({super.key, this.existing});

  final SavedAddress? existing;

  @override
  State<SavedAddressFormScreen> createState() => _SavedAddressFormScreenState();
}

class _SavedAddressFormScreenState extends State<SavedAddressFormScreen> {
  late final TextEditingController _customTitle;
  late final TextEditingController _shortAddress;
  late final TextEditingController _fullAddress;
  late final TextEditingController _entrance;
  late final TextEditingController _floor;
  late final TextEditingController _apartment;
  late final TextEditingController _landmark;
  late final TextEditingController _comment;

  String _label = AddressLabel.home;
  GeoPoint? _geo;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = AddressLabel.values.contains(e?.label)
        ? e!.label
        : AddressLabel.home;
    _customTitle = TextEditingController(text: e?.customTitle ?? '');
    _shortAddress = TextEditingController(text: e?.shortAddress ?? '');
    _fullAddress = TextEditingController(text: e?.fullAddress ?? '');
    _entrance = TextEditingController(text: e?.entrance ?? '');
    _floor = TextEditingController(text: e?.floor ?? '');
    _apartment = TextEditingController(text: e?.apartment ?? '');
    _landmark = TextEditingController(text: e?.landmark ?? '');
    _comment = TextEditingController(text: e?.comment ?? '');
    _geo = e?.geo;
  }

  @override
  void dispose() {
    for (final c in [
      _customTitle,
      _shortAddress,
      _fullAddress,
      _entrance,
      _floor,
      _apartment,
      _landmark,
      _comment,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPoint() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute<LatLng>(
        builder: (_) => MapPointPickerScreen(
          title: 'Точка адреса',
          initial: _geo == null
              ? null
              : LatLng(_geo!.latitude, _geo!.longitude),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _geo = GeoPoint(result.latitude, result.longitude));
    }
  }

  Future<void> _save() async {
    if (_shortAddress.text.trim().length < 2) {
      setState(() => _error = 'Укажите адрес.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser!.uid;
    try {
      await scope.savedAddressRepository.save(
        uid,
        SavedAddress(
          id: widget.existing?.id ?? '',
          label: _label,
          customTitle: _customTitle.text.trim(),
          shortAddress: _shortAddress.text.trim(),
          fullAddress: _fullAddress.text.trim(),
          geo: _geo,
          entrance: _entrance.text.trim(),
          floor: _floor.text.trim(),
          apartment: _apartment.text.trim(),
          landmark: _landmark.text.trim(),
          comment: _comment.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось сохранить адрес. Повторите.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TajGoScaffold(
      appBar: TajGoAppBar(
        title: widget.existing == null ? 'Новый адрес' : 'Изменить адрес',
      ),
      body: ListView(
        padding: const EdgeInsets.all(TajGoSpacing.lg),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: AddressLabel.home, label: Text('Дом')),
              ButtonSegment(value: AddressLabel.work, label: Text('Работа')),
              ButtonSegment(value: AddressLabel.other, label: Text('Другой')),
            ],
            selected: {_label},
            onSelectionChanged: (v) => setState(() => _label = v.first),
          ),
          const SizedBox(height: TajGoSpacing.md),
          if (_label == AddressLabel.other)
            _field('Название (например, «Родители»)', _customTitle),
          _field('Адрес', _shortAddress),
          _field('Уточнение адреса (необязательно)', _fullAddress),
          _pointTile(),
          Row(
            children: [
              Expanded(child: _field('Подъезд', _entrance)),
              const SizedBox(width: TajGoSpacing.sm),
              Expanded(child: _field('Этаж', _floor)),
              const SizedBox(width: TajGoSpacing.sm),
              Expanded(child: _field('Кв.', _apartment)),
            ],
          ),
          _field('Ориентир (необязательно)', _landmark),
          _field('Комментарий курьеру (необязательно)', _comment, maxLines: 2),
          if (_error != null) ...[
            const SizedBox(height: TajGoSpacing.sm),
            Text(
              _error!,
              style: TajGoTypography.caption.copyWith(color: TajGoColors.error),
            ),
          ],
          const SizedBox(height: TajGoSpacing.lg),
          TajGoPrimaryButton(
            label: 'Сохранить',
            loading: _busy,
            onPressed: _busy ? null : _save,
          ),
          const SizedBox(height: TajGoSpacing.xl),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TajGoSpacing.md),
      child: TextField(
        controller: controller,
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

  Widget _pointTile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: TajGoSpacing.md),
      child: TajGoCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(
            Icons.map_outlined,
            color: _geo == null ? TajGoColors.muted : TajGoColors.green,
          ),
          title: Text(
            _geo == null ? 'Точка на карте (необязательно)' : 'Точка выбрана',
            style: TajGoTypography.body,
          ),
          subtitle: _geo == null
              ? Text('Ускорит доставку курьера', style: TajGoTypography.caption)
              : Text(
                  '${_geo!.latitude.toStringAsFixed(5)}, '
                  '${_geo!.longitude.toStringAsFixed(5)}',
                  style: TajGoTypography.caption,
                ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _busy ? null : _pickPoint,
        ),
      ),
    );
  }
}
