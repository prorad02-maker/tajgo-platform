import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:tajgo/core/models/app_user.dart';
import 'package:tajgo/core/models/tajgo_order.dart';
import 'package:tajgo/features/account/account_profile_screen.dart';
import 'package:tajgo/features/admin/admin_home_screen.dart';
import 'package:tajgo/features/auth/phone_auth_screen.dart';
import 'package:tajgo/features/courier/courier_home_screen.dart';
import 'package:tajgo/features/customer/tabs/customer_orders_tab.dart';
import 'package:tajgo/features/startup/role_onboarding_screen.dart';
import 'package:tajgo/features/marketplace/marketplace_partners_screen.dart';
import 'package:tajgo/features/customer/tabs/marketplace_search_tab.dart';
import 'package:tajgo/features/admin/widgets/admin_access_gate.dart';
import 'package:tajgo/features/map/screens/new_order_map_screen.dart';
import 'package:tajgo/features/customer/tabs/customer_home_tab.dart';
import 'package:tajgo/core/services/external_navigator_service.dart';
import 'package:tajgo/core/models/tajgo_courier.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tajgo/shared/design/tajgo_components.dart';
import 'support/ui_fixture.dart';
import 'support/ui_capture.dart';

void main() {
  setUpAll(loadUiFonts);
  testWidgets(
    'profile failure and missing profile offer recovery instead of endless loading',
    (tester) async {
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      fixture.users.fail = true;
      await pumpUi(tester, fixture, const CustomerProfileScreen());
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(find.text('Повторить'), findsOneWidget);
      fixture.users.fail = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Мадина'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      fixture.users.profile = null;
      await pumpUi(tester, fixture, const CustomerProfileScreen());
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Повторить'), findsOneWidget);
    },
  );
  testWidgets('customer orders recover from a stream failure with one retry', (
    tester,
  ) async {
    final fixture = UiFixture();
    addTearDown(fixture.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    fixture.orders.fail = true;
    await pumpUi(
      tester,
      fixture,
      CustomerOrdersTab(scrollController: controller),
    );
    expect(find.text('Повторить'), findsOneWidget);
    fixture.orders.fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Заказов пока нет'), findsOneWidget);
    expect(fixture.orders.subscriptions, 2);
  });
  testWidgets(
    'courier setup failure offers retry and does not escape as an async exception',
    (tester) async {
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      fixture.courier.failEnsure = true;
      await pumpUi(tester, fixture, const CourierHomeScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Повторить'), findsOneWidget);
      fixture.courier.failEnsure = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Рядом'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'feedback and offline text remain usable above a keyboard with large text',
    (tester) async {
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      var retried = false;
      await pumpUi(
        tester,
        fixture,
        Scaffold(
          body: Column(
            children: [
              const TajGoOfflineBanner(),
              Expanded(child: TajGoErrorState(onRetry: () => retried = true)),
            ],
          ),
        ),
        width: 320,
        height: 568,
        scale: 2,
        keyboard: 280,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      expect(retried, isTrue);
    },
  );
  testWidgets(
    'primary action stays readable and keeps its accessible label while loading',
    (tester) async {
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      final semantics = tester.ensureSemantics();
      const label = 'Подтвердить отправление';
      await pumpUi(
        tester,
        fixture,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TajGoPrimaryButton(
                  label: label,
                  icon: Icons.check,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        width: 320,
        scale: 2,
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse);
      await pumpUi(
        tester,
        fixture,
        const Scaffold(body: TajGoPrimaryButton(label: label, loading: true)),
      );
      expect(find.bySemanticsLabel(RegExp(label)), findsOneWidget);
      semantics.dispose();
    },
  );
  for (final search in [false, true]) {
    testWidgets(
      'catalog failure offers retry without fake results (search=$search)',
      (tester) async {
        final fixture = UiFixture();
        addTearDown(fixture.dispose);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        fixture.marketplace.fail = true;
        await pumpUi(
          tester,
          fixture,
          search
              ? MarketplaceSearchTab(scrollController: controller)
              : const MarketplacePartnersScreen(category: 'food'),
        );
        expect(find.text('Повторить'), findsOneWidget);
        expect(tester.takeException(), isNull);
        fixture.marketplace.fail = false;
        await tester.tap(find.text('Повторить'));
        await tester.pumpAndSettle();
        expect(find.text('Повторить'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'admin gate recovers from a network error and reacts to revoked access',
    (tester) async {
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      fixture.users.fail = true;
      const screen = AdminAccessGate(
        child: Scaffold(body: Text('Управление заказами')),
      );
      await pumpUi(tester, fixture, screen);
      expect(find.text('Не удалось проверить доступ'), findsOneWidget);
      final profile = StreamController<AppUser?>();
      addTearDown(profile.close);
      fixture.users.fail = false;
      fixture.users.streamOverride = profile.stream;
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      profile.add(AppUser.fromMap({'role': 'admin'}, uid: 'ui-fixture'));
      await tester.pumpAndSettle();
      expect(find.text('Управление заказами'), findsOneWidget);
      profile.add(AppUser.fromMap({'role': 'customer'}, uid: 'ui-fixture'));
      await tester.pumpAndSettle();
      expect(find.text('Управление заказами'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'home sections show failed data and recover instead of disappearing',
    (tester) async {
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      fixture.orders.activeFail = true;
      await pumpUi(
        tester,
        fixture,
        Scaffold(
          body: CustomerHomeTab(
            scrollController: controller,
            onOpenSearch: () {},
            onOpenCart: () {},
          ),
        ),
      );
      expect(
        find.text('Не удалось загрузить текущую доставку'),
        findsOneWidget,
      );
      fixture.orders.activeFail = false;
      await tester.ensureVisible(find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Не удалось загрузить текущую доставку'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'home action blocks duplicate preflight and handles failure safely',
    (tester) async {
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final request = Completer<AppUser?>();
      fixture.users.getOverride = request.future;
      await pumpUi(
        tester,
        fixture,
        Scaffold(
          body: CustomerHomeTab(
            scrollController: controller,
            onOpenSearch: () {},
            onOpenCart: () {},
          ),
        ),
      );
      await tester.tap(find.text('Отправить посылку'));
      await tester.tap(find.text('Отправить посылку'));
      expect(fixture.users.getCalls, 1);
      request.completeError(StateError('PRIVATE BACKEND DETAILS'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'courier navigator preference refreshes after returning from profile',
    (tester) async {
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      await pumpUi(tester, fixture, const CourierHomeScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Профиль'));
      await tester.pumpAndSettle();
      fixture.navigator.preference = const NavigatorPreference(
        navigator: ExternalNavigator.google,
      );
      Navigator.of(tester.element(find.text('Профиль'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Google'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cached assigned order remains visible during temporary courier setup failure',
    (tester) async {
      final fixture = UiFixture();
      addTearDown(fixture.dispose);
      fixture.courier.ensureError = FirebaseException(
        plugin: 'cloud_functions',
        code: 'unavailable',
      );
      fixture.courier.cachedCourier = const TajGoCourier(
        uid: 'ui-fixture',
        displayName: 'Рахим',
        city: 'Худжанд',
        isOnline: true,
        isBusy: true,
        activeOrderId: 'assigned',
        rating: 4.9,
        transport: 'bicycle',
        earningsToday: 140,
      );
      fixture.courier.activeOrder = TajGoOrder(
        id: 'assigned',
        customerId: 'customer',
        customerName: 'Мадина',
        courierId: 'ui-fixture',
        status: OrderStatus.accepted,
        type: 'package',
        city: 'Худжанд',
        fromText: 'Исмоили Сомони, 54',
        toText: 'Гагарина, 12',
        price: 25,
        currency: 'TJS',
      );
      await pumpUi(tester, fixture, const CourierHomeScreen());
      await tester.pumpAndSettle();
      expect(find.text('Профиль не обновлён'), findsOneWidget);
      await tester.ensureVisible(find.text('Мой заказ'));
      await tester.tap(find.text('Мой заказ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Исмоили Сомони'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final scale in [1.0, 2.0]) {
    for (final name in [
      'phone',
      'role',
      'profile',
      'orders',
      'courier',
      'admin',
    ]) {
      testWidgets(
        '$name screen renders on a 360px phone at text scale $scale',
        (tester) async {
          final fixture = UiFixture();
          addTearDown(fixture.dispose);
          final controller = ScrollController();
          addTearDown(controller.dispose);
          if (name == 'admin') {
            fixture.users.profile = AppUser.fromMap({
              'role': 'admin',
              'displayName': 'Администратор',
              'phoneVerified': true,
            }, uid: 'ui-fixture');
          }
          fixture.orders.orders = [
            TajGoOrder(
              id: 'fixture-order',
              customerId: 'ui-fixture',
              customerName: 'Мадина',
              status: OrderStatus.waiting,
              type: 'package',
              city: 'Худжанд',
              fromText: 'Проспект Исмоили Сомони, дом 54',
              toText: 'Улица Гагарина, дом 12',
              price: 25,
              currency: 'TJS',
            ),
          ];
          final screen = switch (name) {
            'phone' => const PhoneAuthScreen(allowAnonymousFallback: false),
            'role' => const RoleOnboardingScreen(),
            'profile' => const CustomerProfileScreen(),
            'orders' => CustomerOrdersTab(scrollController: controller),
            'courier' => const CourierHomeScreen(),
            _ => const AdminHomeScreen(),
          };
          await pumpUi(tester, fixture, screen, scale: scale);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await captureUi(tester, '$name-${scale.toInt()}x');
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final details in [false, true]) {
    testWidgets(
      'map controls stay usable on a small phone with large text (details=$details)',
      (tester) async {
        final fixture = UiFixture();
        addTearDown(fixture.dispose);
        await pumpUi(
          tester,
          fixture,
          Scaffold(
            body: details
                ? buildNewOrderDetailsMapLayoutForTest(
                    size: const Size(320, 640),
                    textScaler: const TextScaler.linear(2),
                  )
                : buildNewOrderEmergencyMapLayoutForTest(
                    size: const Size(320, 640),
                    textScaler: const TextScaler.linear(2),
                  ),
          ),
          width: 320,
          height: 640,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        await captureUi(tester, details ? 'map-details-2x' : 'map-pickup-2x');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
