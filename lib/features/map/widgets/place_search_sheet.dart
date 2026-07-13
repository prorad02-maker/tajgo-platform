import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../models/place_suggestion.dart';
import '../services/place_search_service.dart';
import 'tajgo_address_result_tile.dart';

Future<PlaceSuggestion?> showPlaceSearchSheet({
  required BuildContext context,
  required PlaceSearchService service,
  required String title,
  LatLng? near,
  String? recentType,
}) => showModalBottomSheet<PlaceSuggestion>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  builder: (_) => _PlaceSearchSheet(
    service: service,
    title: title,
    near: near,
    recentType: recentType,
  ),
);

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({
    required this.service,
    required this.title,
    required this.near,
    required this.recentType,
  });

  final PlaceSearchService service;
  final String title;
  final LatLng? near;
  final String? recentType;

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
    _debounce = Timer(const Duration(milliseconds: 320), () => _search(value));
  }

  Future<void> _search(String value) async {
    final requestId = ++_requestId;
    setState(() => _loading = true);
    final results = await widget.service.search(
      value,
      near: widget.near,
      recentType: widget.recentType,
    );
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
                hintText: 'Введите адрес, место или ориентир',
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
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (!_loading && _results.length > 1 && hasQuery) ...[
              const Text(
                'Нашли несколько похожих мест',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              const Text(
                'Выберите нужный вариант и уточните точку на карте.',
                style: TextStyle(color: TajGoColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: !_loading && _results.isEmpty
                  ? const _EmptySearch()
                  : hasQuery
                  ? _resultList(_results)
                  : _suggestionSections(),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Выбрать на карте'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultList(List<PlaceSuggestion> places) => ListView.separated(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    itemCount: places.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, index) => TajGoAddressResultTile(
      place: places[index],
      onShowOnMap: () => Navigator.pop(context, places[index]),
    ),
  );

  Widget _suggestionSections() {
    final recent = _results.where((place) => place.source == 'recent').toList();
    final local = _results.where((place) => place.source == 'local').toList();
    final nearby = widget.near == null
        ? <PlaceSuggestion>[]
        : local.take(3).toList();
    final popular = local.where((place) => !nearby.contains(place)).toList();
    final children = <Widget>[];
    void addSection(String title, List<PlaceSuggestion> places) {
      if (places.isEmpty) return;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      );
      children.addAll(
        places.map(
          (place) => TajGoAddressResultTile(
            place: place,
            onShowOnMap: () => Navigator.pop(context, place),
          ),
        ),
      );
    }

    addSection('Недавние', recent.take(5).toList());
    addSection('Рядом с вами', nearby);
    addSection('Популярные', popular);
    return ListView(children: children);
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
            'Не нашли адрес',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Выберите точку на карте. Так даже точнее.',
            textAlign: TextAlign.center,
            style: TextStyle(color: TajGoColors.muted),
          ),
        ],
      ),
    ),
  );
}
