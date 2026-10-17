import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/saved_address.dart';
import '../../../shared/design/tajgo_components.dart';
import '../../../shared/widgets/tajgo_scope.dart';
import 'saved_address_form_screen.dart';

/// Список сохранённых адресов с offline-кэшем и CRUD.
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<SavedAddress> _addresses = const [];
  bool _loaded = false;
  StreamSubscription<List<SavedAddress>>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub != null) return;
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser?.uid;
    if (uid == null) {
      setState(() => _loaded = true);
      return;
    }
    // Мгновенно показываем кэш (offline), затем подписываемся на Firestore.
    scope.savedAddressRepository.cachedAddresses(uid).then((cached) {
      if (mounted && !_loaded) {
        setState(() {
          _addresses = cached;
          _loaded = true;
        });
      }
    });
    _sub = scope.savedAddressRepository
        .addressesStream(uid)
        .listen(
          (list) {
            if (mounted) {
              setState(() {
                _addresses = list;
                _loaded = true;
              });
            }
          },
          onError: (_) {
            if (mounted) setState(() => _loaded = true);
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _openForm([SavedAddress? existing]) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => SavedAddressFormScreen(existing: existing),
    ),
  );

  Future<void> _delete(SavedAddress address) async {
    final ok = await showTajGoConfirmation(
      context: context,
      title: 'Удалить адрес?',
      message: address.title,
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final scope = TajGoScope.of(context);
    final uid = scope.authService.currentUser?.uid;
    if (uid != null) {
      try {
        await scope.savedAddressRepository.delete(uid, address.id);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return TajGoScaffold(
      appBar: const TajGoAppBar(title: 'Избранные адреса'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: TajGoColors.green,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
          ? const TajGoEmptyState(
              icon: Icons.location_off_outlined,
              title: 'Нет сохранённых адресов',
              message:
                  'Добавьте Дом, Работу или другой адрес для быстрой '
                  'доставки.',
            )
          : ListView(
              padding: const EdgeInsets.only(top: TajGoSpacing.sm, bottom: 96),
              children: _addresses
                  .map(
                    (a) => TajGoCard(
                      onTap: () => _openForm(a),
                      padding: const EdgeInsets.all(TajGoSpacing.md),
                      child: Row(
                        children: [
                          Text(
                            AddressLabel.icon(a.label),
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(width: TajGoSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.title, style: TajGoTypography.subtitle),
                                const SizedBox(height: TajGoSpacing.xxs),
                                Text(
                                  a.displayAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TajGoTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: TajGoColors.muted,
                            onPressed: () => _delete(a),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}
