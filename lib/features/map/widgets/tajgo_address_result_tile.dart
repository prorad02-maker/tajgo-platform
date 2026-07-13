import 'package:flutter/material.dart';

import '../../../core/constants/tajgo_colors.dart';
import '../models/place_suggestion.dart';

class TajGoAddressResultTile extends StatelessWidget {
  const TajGoAddressResultTile({
    super.key,
    required this.place,
    required this.onShowOnMap,
    this.onToggleFavorite,
    this.favorite = false,
  });

  final PlaceSuggestion place;
  final VoidCallback onShowOnMap;
  final VoidCallback? onToggleFavorite;
  final bool favorite;

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
        child: Icon(categoryIcon(place.category), color: TajGoColors.darkGreen),
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
              categoryLabel(place.category),
              ?place.district,
              ?distanceText,
            ].join(' · '),
            style: const TextStyle(fontSize: 11, color: TajGoColors.muted),
          ),
          Text(
            confidenceLabel(place.confidence),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: place.confidence >= 0.8
                  ? TajGoColors.darkGreen
                  : place.confidence >= 0.55
                  ? TajGoColors.warning
                  : TajGoColors.error,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onToggleFavorite != null)
            IconButton(
              tooltip: favorite ? 'Убрать из избранного' : 'В избранное',
              onPressed: onToggleFavorite,
              icon: Icon(
                favorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: favorite ? TajGoColors.warning : TajGoColors.muted,
              ),
            ),
          TextButton(onPressed: onShowOnMap, child: const Text('На карте')),
        ],
      ),
      onTap: onShowOnMap,
    );
  }
}

String confidenceLabel(double value) {
  if (value >= 0.8) return 'Высокое совпадение';
  if (value >= 0.55) return 'Среднее совпадение';
  return 'Нужно уточнить';
}

String categoryLabel(String category) => switch (category) {
  'market' => 'Рынок',
  'cafe' => 'Кафе',
  'shop' => 'Магазин',
  'pharmacy' => 'Аптека',
  'school' => 'Школа',
  'hospital' => 'Больница',
  'street' => 'Улица',
  'district' => 'Район',
  'mall' => 'Торговый центр',
  'government' => 'Учреждение',
  'transport' => 'Транспорт',
  'landmark' => 'Ориентир',
  'mapPoint' => 'Точка на карте',
  _ => 'Адрес',
};

IconData categoryIcon(String category) => switch (category) {
  'market' || 'shop' || 'mall' => Icons.storefront_outlined,
  'cafe' => Icons.restaurant_outlined,
  'pharmacy' || 'hospital' => Icons.local_hospital_outlined,
  'school' => Icons.school_outlined,
  'street' => Icons.signpost_outlined,
  'district' => Icons.location_city_outlined,
  'transport' => Icons.directions_bus_outlined,
  _ => Icons.location_on_outlined,
};
