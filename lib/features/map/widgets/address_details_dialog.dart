import 'package:flutter/material.dart';

/// The map pin remains authoritative; editing the label never changes its
/// coordinates. Useful where the geocoder has no building or house number.
Future<String?> showAddressDetailsDialog({
  required BuildContext context,
  required String initialAddress,
  bool needsAddress = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _AddressDetailsDialog(
    initialAddress: needsAddress ? '' : initialAddress,
    needsAddress: needsAddress,
  ),
);

class _AddressDetailsDialog extends StatefulWidget {
  const _AddressDetailsDialog({
    required this.initialAddress,
    required this.needsAddress,
  });
  final String initialAddress;
  final bool needsAddress;
  @override
  State<_AddressDetailsDialog> createState() => _AddressDetailsDialogState();
}

class _AddressDetailsDialogState extends State<_AddressDetailsDialog> {
  final _form = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialAddress);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.needsAddress ? 'Укажите адрес' : 'Уточните адрес'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Добавьте улицу, дом или ориентир. Точка на карте останется на выбранном месте.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              maxLength: 300,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Адрес и ориентир',
                hintText: 'Например, ул. Сомони, 54, у главного входа',
              ),
              validator: (value) => (value ?? '').trim().length < 3
                  ? 'Укажите улицу, дом или ориентир.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _save, child: const Text('Сохранить')),
    ],
  );
}
