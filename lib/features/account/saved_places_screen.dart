import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/constants/tajgo_colors.dart';
import '../../core/services/user_error_message.dart';
import '../../shared/widgets/tajgo_state_view.dart';
import '../map/models/place_suggestion.dart';
import '../map/screens/new_order_map_screen.dart';
import '../map/services/place_search_service.dart';
import '../map/services/saved_places_service.dart';
import '../map/widgets/place_search_sheet.dart';
import '../map/widgets/tajgo_map_attribution.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key, this.service, this.canOrder = true});
  final SavedPlacesService? service;
  final bool canOrder;
  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  late final SavedPlacesService _saved;
  late Future<List<PlaceSuggestion>> _places;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.service ?? SavedPlacesService();
    _places = _saved.load();
  }

  Future<void> _change(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _places = _saved.load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final place = await showPlaceSearchSheet(
      context: context,
      service: PlaceSearchService(savedPlaces: _saved),
      title: 'Добавить адрес в избранное',
    );
    if (!mounted) return;
    await _change(() async {
      if (place != null && !await _saved.isFavorite(place)) {
        await _saved.toggleFavorite(place);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Избранные адреса'),
      actions: [
        IconButton(
          tooltip: 'Добавить адрес',
          onPressed: _busy ? null : _add,
          icon: const Icon(Icons.add_location_alt_outlined),
        ),
      ],
    ),
    body: FutureBuilder<List<PlaceSuggestion>>(
      future: _places,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TajGoStateView(
            icon: Icons.location_off_outlined,
            title: 'Не удалось открыть адреса',
            message: userErrorMessage(snapshot.error),
            onRetry: () => setState(() => _places = _saved.load()),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return TajGoStateView(
            icon: Icons.favorite_border_rounded,
            title: 'Сохраните важные адреса',
            message:
                'Добавьте дом, работу или другое место. Адреса сохраняются на этом устройстве и доступны в поиске на карте.',
            onRetry: _busy ? null : _add,
            actionLabel: 'Добавить адрес',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final place = snapshot.data![index];
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: TajGoColors.darkGreen,
                ),
                title: Text(
                  place.shortTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(place.address),
                trailing: IconButton(
                  tooltip: 'Удалить адрес',
                  onPressed: _busy
                      ? null
                      : () => _change(() => _saved.remove(place)),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        _SavedPlaceMap(place: place, canOrder: widget.canOrder),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _SavedPlaceMap extends StatelessWidget {
  const _SavedPlaceMap({required this.place, required this.canOrder});
  final PlaceSuggestion place;
  final bool canOrder;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(place.shortTitle)),
    body: FlutterMap(
      options: MapOptions(
        initialCenter: place.point,
        initialZoom: 16,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'tj.tajgo.app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: place.point,
              width: 48,
              height: 48,
              child: const Icon(
                Icons.location_on_rounded,
                size: 46,
                color: TajGoColors.darkGreen,
              ),
            ),
          ],
        ),
        const TajGoMapAttribution(),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(place.address, textAlign: TextAlign.center),
          if (canOrder) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => NewOrderMapScreen(initialPlace: place),
                ),
              ),
              child: const Text('Заказать доставку отсюда'),
            ),
          ],
        ],
      ),
    ),
  );
}
