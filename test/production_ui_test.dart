import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajgo/app/tajgo_theme.dart';
import 'package:tajgo/core/models/app_user.dart';
import 'package:tajgo/core/services/user_error_message.dart';
import 'package:tajgo/features/startup/startup_decision.dart';
import 'package:tajgo/features/map/models/place_suggestion.dart';
import 'package:tajgo/features/map/services/place_search_service.dart';
import 'package:tajgo/features/map/services/recent_places_service.dart';
import 'package:tajgo/features/map/services/saved_places_service.dart';
import 'package:tajgo/features/map/widgets/place_search_sheet.dart';
import 'package:tajgo/features/map/widgets/address_details_dialog.dart';

class _SavedPlaces extends SavedPlacesService {
  _SavedPlaces() : super(preferences: _Preferences());
  @override
  Future<List<PlaceSuggestion>> load() async => [];
}

class _Preferences implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Search extends PlaceSearchService {
  _Search()
    : super(
        savedPlaces: _SavedPlaces(),
        recentPlaces: RecentPlacesService(preferences: _Preferences()),
      );
  final pending = <String, Completer<List<PlaceSuggestion>>>{};
  @override
  Future<List<PlaceSuggestion>> search(
    String input, {
    LatLng? near,
    String? recentType,
  }) {
    if (input.isEmpty) return Future.value([]);
    return (pending[input] ??= Completer<List<PlaceSuggestion>>()).future;
  }
}

const oldPlace = PlaceSuggestion(
  id: 'old',
  title: 'Старый результат',
  subtitle: 'Худжанд',
  shortTitle: 'Старый результат',
  address: 'Старый адрес',
  lat: 40.28,
  lng: 69.62,
  source: 'remote',
  confidence: 0.7,
  category: 'address',
);

void main() {
  testWidgets(
    'missing geocoded address requires a label and returns trimmed detail',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: TajGoTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showAddressDetailsDialog(
                    context: context,
                    initialAddress: 'Точка на карте',
                    needsAddress: true,
                  );
                },
                child: const Text('Указать адрес'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Указать адрес'));
      await tester.pumpAndSettle();
      expect(find.text('Точка на карте'), findsNothing);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Укажите улицу, дом или ориентир.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        '  Сомони, 54, у входа  ',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(selected, 'Сомони, 54, у входа');
      expect(tester.takeException(), isNull);
    },
  );
  test('infrastructure errors do not leak provider detail', () {
    expect(
      userErrorMessage(
        FirebaseException(
          plugin: 'firestore',
          code: 'permission-denied',
          message: '/internal/private/path',
        ),
      ),
      contains('Нет доступа'),
    );
    expect(
      userErrorMessage(StateError('Route API key secret')),
      isNot(contains('secret')),
    );
    expect(
      userErrorMessage(StateError('Этот заказ уже нельзя отменить.')),
      'Этот заказ уже нельзя отменить.',
    );
  });

  test('admin role opens administration, not customer onboarding', () {
    final admin = AppUser.fromMap({'role': 'admin'}, uid: 'admin');
    expect(
      resolveStartupDestination(authenticated: true, profile: admin),
      StartupDestination.adminHome,
    );
    expect(
      resolveStartupDestination(authenticated: false, profile: admin),
      StartupDestination.intent,
    );
  });

  testWidgets('typing invalidates an old search before debounce finishes', (
    tester,
  ) async {
    final service = _Search();
    await tester.pumpWidget(
      MaterialApp(
        theme: TajGoTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPlaceSearchSheet(
                context: context,
                service: service,
                title: 'Найти адрес',
              ),
              child: const Text('Поиск'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Поиск'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Сом');
    await tester.pump(const Duration(milliseconds: 330));
    await tester.enterText(find.byType(TextField), 'Сомони');
    service.pending['Сом']!.complete([oldPlace]);
    await tester.pump();
    expect(find.text('Старый результат'), findsNothing);
    await tester.pump(const Duration(milliseconds: 330));
    service.pending['Сомони']!.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Не нашли адрес'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
