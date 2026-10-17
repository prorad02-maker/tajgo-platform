import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/app/tajgo_theme.dart';
import 'ui_fixture.dart';

const captureKey = ValueKey('ui-capture');
Future<void> loadUiFonts() async {
  final fonts = Platform.environment['TAJGO_UI_FONT_DIR'];
  if (fonts == null) return;
  final loader = FontLoader('Roboto');
  for (final name in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    loader.addFont(
      File(
        '$fonts/$name',
      ).readAsBytes().then((data) => ByteData.sublistView(data)),
    );
  }
  await loader.load();
  // Flutter's test engine uses Ahem for unresolved platform fonts. Use the
  // same Roboto face there for readable previews, without changing the app.
  await (FontLoader('Ahem')..addFont(
        File(
          '$fonts/roboto-regular.ttf',
        ).readAsBytes().then((data) => ByteData.sublistView(data)),
      ))
      .load();
  await (FontLoader('MaterialIcons')..addFont(
        File(
          '$fonts/materialicons-regular.otf',
        ).readAsBytes().then((data) => ByteData.sublistView(data)),
      ))
      .load();
}

Future<void> pumpUi(
  WidgetTester tester,
  UiFixture fixture,
  Widget screen, {
  double width = 360,
  double height = 800,
  double scale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: fixture.wrap(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: TajGoTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> captureUi(WidgetTester tester, String name) async {
  final dir = Platform.environment['TAJGO_UI_CAPTURE_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
