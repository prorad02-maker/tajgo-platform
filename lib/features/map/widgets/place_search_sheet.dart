import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../models/place_suggestion.dart';
import '../services/place_search_service.dart';

Future<PlaceSuggestion?> showPlaceSearchSheet({
  required BuildContext context,
  required PlaceSearchService service,
  required String title,
  LatLng? near,
}) => showModalBottomSheet<PlaceSuggestion>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  builder: (_) => _PlaceSearchSheet(service: service, title: title, near: near),
);

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({
    required this.service,
    required this.title,
    required this.near,
  });

  final PlaceSearchService service;
  final String title;
  final LatLng? near;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _results = const [];
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    final requestId = ++_requestId;
    setState(() => _loading = true);
    final results = await widget.service.search(value, near: widget.near);
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final hasQuery = _query.text.trim().isNotEmpty;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + keyboard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DDD8),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: (value) {
                setState(() {});
                _onChanged(value);
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Введите адрес или короткое название',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                          _search('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (!_loading && _results.length > 1 && hasQuery) ...[
              const Text(
                'Нашли несколько похожих мест',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              const Text(
                'Выберите нужный вариант и уточните его на карте.',
                style: TextStyle(color: TajGoColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            if (!_loading && !hasQuery && _results.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Недавние · Рядом с вами · Популярные',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            Expanded(
              child: !_loading && _results.isEmpty
                  ? const _EmptySearch()
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final place = _results[index];
                        return _PlaceTile(
                          place: place,
                          onTap: () => Navigator.pop(context, place),
                        );
                      },
                    ),
            ),
            const Text(
              'Не нашли адрес? Закройте поиск и выберите точку вручную на карте.',
              style: TextStyle(color: TajGoColors.muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.onTap});
  final PlaceSuggestion place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = place.distanceMetersFromUser;
    final distanceText = distance == null
        ? null
        : distance < 1000
        ? '${distance.round()} м от вас'
        : '${(distance / 1000).toStringAsFixed(1)} км от вас';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF4E7),
        child: Icon(
          _categoryIcon(place.category),
          color: TajGoColors.darkGreen,
        ),
      ),
      title: Text(
        place.shortTitle,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(place.address, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            [
              _categoryLabel(place.category),
              ?distanceText,
              'Совпадение: ${_confidenceLabel(place.confidence)}',
            ].join(' · '),
            style: const TextStyle(fontSize: 11, color: TajGoColors.muted),
          ),
        ],
      ),
      trailing: const Tooltip(
        message: 'Показать на карте',
        child: Icon(Icons.map_outlined, color: TajGoColors.green),
      ),
      onTap: onTap,
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_searching, size: 44, color: TajGoColors.muted),
          SizedBox(height: 12),
          Text(
            'Адрес не найден',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Проверьте написание или выберите точку вручную на карте.',
            textAlign: TextAlign.center,
            style: TextStyle(color: TajGoColors.muted),
          ),
        ],
      ),
    ),
  );
}

String _confidenceLabel(double value) {
  if (value >= 0.8) return 'высокое';
  if (value >= 0.55) return 'среднее';
  return 'приблизительное';
}

String _categoryLabel(String category) => switch (category) {
  'cafe' => 'Кафе',
  'shop' => 'Магазин',
  'street' => 'Улица',
  'district' => 'Район',
  'landmark' => 'Ориентир',
  'demo' => 'Демо-точка',
  'mapPoint' => 'Точка на карте',
  _ => 'Адрес',
};

IconData _categoryIcon(String category) => switch (category) {
  'cafe' => Icons.restaurant_outlined,
  'shop' => Icons.storefront_outlined,
  'street' => Icons.signpost_outlined,
  'district' => Icons.location_city_outlined,
  'landmark' => Icons.place_outlined,
  'demo' => Icons.science_outlined,
  _ => Icons.location_on_outlined,
};
