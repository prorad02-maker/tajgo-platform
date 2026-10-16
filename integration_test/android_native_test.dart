import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:tajgo/app/tajgo_theme.dart';
import 'package:tajgo/core/models/app_user.dart';
import 'package:tajgo/core/config/service_area_config.dart';
import 'package:tajgo/core/services/auth_service.dart';
import 'package:tajgo/features/auth/phone_auth_screen.dart';
import 'package:tajgo/features/map/screens/new_order_map_screen.dart';
import 'package:tajgo/features/map/services/tajgo_location_service.dart';
import 'package:tajgo/features/map/widgets/tajgo_map_loading_status.dart';

import '../test/support/ui_fixture.dart';

const _project = 'demo-tajgo-android';
const _phone = '+992900000001'; // Synthetic account in the local emulator only.
const _uiPhone = '+992900000002';

class _NativeAuth extends AuthService {
  _NativeAuth(super.auth);
  String? verificationId;
  int confirmations = 0;
  String? lastFailure;
  @override
  Future<User> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    confirmations++;
    lastFailure = null;
    try {
      return await super.confirmSmsCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );
    } on PhoneAuthFailure catch (error) {
      lastFailure = error.code;
      rethrow;
    }
  }

  @override
  Future<PhoneCodeSession> requestPhoneCode({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    final session = await super.requestPhoneCode(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
    );
    verificationId = session.verificationId;
    return session;
  }
}

class _OutsideLocation extends TajGoLocationService {
  int passiveCalls = 0, freshCalls = 0;
  Position get position => Position(
    latitude: 39,
    longitude: 70,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  @override
  Future<Position?> currentPositionIfAuthorized() async {
    passiveCalls++;
    return position;
  }

  @override
  Future<Position> determineCurrentPosition() async {
    freshCalls++;
    return position;
  }
}

class _Users extends FixtureUsers {
  String? ensuredUid;
  @override
  Future<void> ensureUser({
    required String uid,
    String? phoneNumber,
    String? displayName,
    bool phoneVerified = false,
    String initialMode = AppUserRole.customer,
  }) async {
    ensuredUid = uid;
  }

  @override
  Future<void> completeRoleOnboarding(String uid, String role) async {}
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 35));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(ready(), isTrue, reason: 'Native UI condition did not become ready');
}

Future<void> _gate(
  WidgetTester tester,
  String state,
  Future<bool> Function() ready,
) async {
  final acknowledgement = File(
    // run-as starts in this test package's data directory on the owner emulator.
    '/data/user/0/tj.tajgo.app/cache/tajgo-native-$state.ready',
  );
  if (await acknowledgement.exists()) await acknowledgement.delete();
  // The host runner performs the corresponding ADB change on this emulator.
  debugPrint('TAJGO_NATIVE_GATE:$state');
  final deadline = DateTime.now().add(const Duration(seconds: 35));
  while (DateTime.now().isBefore(deadline)) {
    if (await acknowledgement.exists() && await ready()) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  fail('Host did not apply Android state: $state');
}

Future<String> _smsCode(String phone, String? verificationId) async {
  final response = await http
      .get(
        Uri.parse(
          'http://10.0.2.2:9099/emulator/v1/projects/$_project/verificationCodes',
        ),
      )
      .timeout(const Duration(seconds: 10));
  expect(response.statusCode, 200);
  final codes =
      (jsonDecode(response.body) as Map<String, dynamic>)['verificationCodes']
          as List;
  final code = codes.cast<Map<String, dynamic>>().lastWhere(
    (item) =>
        item['phoneNumber'] == phone && item['sessionInfo'] == verificationId,
  );
  return code['code'] as String;
}

Future<void> _enterCode(
  WidgetTester tester,
  _NativeAuth auth,
  String code,
) async {
  final field = find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == 'SMS-код',
  );
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  final previous = auth.confirmations;
  await tester.enterText(field, code);
  if (field.evaluate().isNotEmpty) {
    expect(tester.widget<TextField>(field).controller?.text, code);
  }
  await tester.pump();
  if (auth.confirmations == previous) {
    await tester.ensureVisible(find.text('Подтвердить'));
    await tester.tap(find.text('Подтвердить'));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseAuth firebaseAuth;
  late _NativeAuth auth;

  setUpAll(() async {
    expect(Platform.isAndroid, isTrue);
    expect(
      const bool.fromEnvironment('TAJGO_NATIVE_SMOKE'),
      isTrue,
      reason: 'Use scripts/run_android_smoke.ps1 with a dedicated emulator',
    );
    final app = await Firebase.initializeApp(
      name: 'tajgo-native-smoke',
      options: const FirebaseOptions(
        apiKey: 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        appId: '1:123456789:android:0123456789abcdef012345',
        messagingSenderId: '123456789',
        projectId: _project,
      ),
    );
    firebaseAuth = FirebaseAuth.instanceFor(app: app);
    await firebaseAuth.useAuthEmulator('10.0.2.2', 9099);
    await firebaseAuth.signOut();
    auth = _NativeAuth(firebaseAuth);
  });

  testWidgets('Android SMS rejects wrong code and accepts emulator code', (
    tester,
  ) async {
    final session = await auth.requestPhoneCode(phoneNumber: _phone);
    expect(session.verificationId, isNotNull);
    final correct = await _smsCode(_phone, session.verificationId);
    final wrong = correct == '000000' ? '111111' : '000000';
    await expectLater(
      auth.confirmSmsCode(
        verificationId: session.verificationId!,
        smsCode: wrong,
      ),
      throwsA(
        isA<PhoneAuthFailure>().having(
          (error) => error.code,
          'code',
          'invalid-verification-code',
        ),
      ),
    );
    expect(auth.currentUser, isNull);
    final user = await auth.confirmSmsCode(
      verificationId: session.verificationId!,
      smsCode: correct,
    );
    expect(user.phoneNumber, _phone);
    expect(user.isAnonymous, isFalse);
    await auth.signOut();
  });

  testWidgets('Android phone screen handles keyboard and wrong-code retry', (
    tester,
  ) async {
    final fixture = UiFixture();
    final users = _Users();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      fixture.wrap(
        MaterialApp(
          theme: TajGoTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const PhoneAuthScreen(allowAnonymousFallback: false),
                  ),
                ),
                child: const Text('Открыть вход'),
              ),
            ),
          ),
        ),
        authService: auth,
        userRepository: users,
      ),
    );
    await tester.tap(find.text('Открыть вход'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), _uiPhone);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _until(
      tester,
      () => find
          .byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'SMS-код',
          )
          .evaluate()
          .isNotEmpty,
    );
    final correct = await _smsCode(_uiPhone, auth.verificationId);
    final wrong = correct == '000000' ? '111111' : '000000';
    await _enterCode(tester, auth, wrong);
    await _until(
      tester,
      () => find
          .text('Неверный код. Проверьте SMS и попробуйте ещё раз.')
          .evaluate()
          .isNotEmpty,
    );
    expect(auth.currentUser, isNull);
    await _gate(tester, 'capture-sms', () async => true);
    await _enterCode(tester, auth, correct);
    await tester.pump(const Duration(seconds: 2));
    debugPrint(
      'TAJGO_NATIVE_AUTH: confirmations=${auth.confirmations} signedIn=${auth.currentUser != null} ensured=${users.ensuredUid != null} failure=${auth.lastFailure}',
    );
    await _until(
      tester,
      () =>
          find.text('Открыть вход').evaluate().isNotEmpty &&
          find.byType(PhoneAuthScreen).evaluate().isEmpty,
    );
    expect(auth.currentUser?.phoneNumber, _uiPhone);
    expect(users.ensuredUid, auth.currentUser!.uid);
    expect(tester.takeException(), isNull);
    await auth.signOut();
  });

  testWidgets(
    'Android GPS handles permanent denial, disabled service and recovery',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Проверка геолокации'))),
      );
      final location = TajGoLocationService();
      await _gate(
        tester,
        'denied',
        () async =>
            await Geolocator.checkPermission() == LocationPermission.denied,
      );
      expect(await location.currentPositionIfAuthorized(), isNull);
      await expectLater(
        location.determineCurrentPosition(),
        throwsA(
          isA<TajGoLocationException>().having(
            (error) => error.issue,
            'issue',
            TajGoLocationIssue.deniedForever,
          ),
        ),
      );
      await _gate(
        tester,
        'disabled',
        () async => !await Geolocator.isLocationServiceEnabled(),
      );
      await expectLater(
        location.determineCurrentPosition(),
        throwsA(
          isA<TajGoLocationException>().having(
            (error) => error.issue,
            'issue',
            TajGoLocationIssue.serviceDisabled,
          ),
        ),
      );
      await _gate(
        tester,
        'granted',
        () async =>
            await Geolocator.isLocationServiceEnabled() &&
            await Geolocator.checkPermission() == LocationPermission.whileInUse,
      );
      Position? position;
      final deadline = DateTime.now().add(const Duration(seconds: 35));
      do {
        position = await location.determineCurrentPosition();
        if ((position.latitude - 40.2833).abs() < 0.001 &&
            (position.longitude - 69.6222).abs() < 0.001) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 500));
      } while (DateTime.now().isBefore(deadline));
      expect(position.latitude, closeTo(40.2833, 0.001));
      expect(position.longitude, closeTo(69.6222, 0.001));
      expect(position.accuracy, lessThanOrEqualTo(50));
    },
  );

  testWidgets('Android loads real map tiles and exposes map controls', (
    tester,
  ) async {
    final probe = await http
        .get(
          Uri.parse('https://tile.openstreetmap.org/14/11360/6187.png'),
          headers: {'User-Agent': 'TajGo/1.8.3 Android QA (tj.tajgo.app)'},
        )
        .timeout(const Duration(seconds: 20));
    expect(probe.statusCode, 200, reason: 'Android tile endpoint status');
    expect(probe.bodyBytes.take(4), [137, 80, 78, 71]);
    final fixture = UiFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      fixture.wrap(
        MaterialApp(theme: TajGoTheme.light, home: const NewOrderMapScreen()),
        locationService: TajGoLocationService(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _until(
      tester,
      () => find.byType(TajGoMapLoadingStatus).evaluate().isEmpty,
    );
    await _until(
      tester,
      () =>
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('new-order-map-confirm')),
              )
              .onPressed !=
          null,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('new-order-map-gps')), findsOneWidget);
    expect(find.textContaining('Демо:'), findsNothing);
    final mapWidget = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final camera = mapWidget.mapController!.camera;
    final mapRect = tester.getRect(find.byType(FlutterMap));
    final point = mapRect.topLeft + camera.latLngToScreenOffset(camera.center);
    final pinTip = tester
        .getRect(find.byKey(const ValueKey('new-order-map-selection-pin')))
        .bottomCenter;
    expect((point - pinTip).distance, lessThan(0.01));
    await _gate(tester, 'capture-map', () async => true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening map outside service area retains the selected city', (
    tester,
  ) async {
    final fixture = UiFixture();
    final location = _OutsideLocation();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      fixture.wrap(
        MaterialApp(theme: TajGoTheme.light, home: const NewOrderMapScreen()),
        locationService: location,
      ),
    );
    await _until(
      tester,
      () => location.passiveCalls > 0 && location.freshCalls > 0,
    );
    await tester.pump(const Duration(seconds: 1));
    final center = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera
        .center;
    expect(
      center.latitude,
      closeTo(ServiceAreaRegistry.khujand.center.latitude, 0.001),
    );
    expect(
      center.longitude,
      closeTo(ServiceAreaRegistry.khujand.center.longitude, 0.001),
    );
    expect(tester.takeException(), isNull);
  });
}
