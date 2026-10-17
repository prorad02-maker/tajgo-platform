import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tajgo/features/map/utils/new_order_map_layout.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(320, 640),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('selected coordinate meets pin tip on $size at scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = MapController();
        addTearDown(controller.dispose);
        final panel = NewOrderMapLayout.panelHeight(
          size,
          details: false,
          textScaler: TextScaler.linear(scale),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NewOrderMapStack(
                children: [
                  NewOrderMapViewport(
                    panelHeight: panel,
                    selecting: true,
                    child: FlutterMap(
                      mapController: controller,
                      options: const MapOptions(
                        initialCenter: LatLng(40.2833, 69.6222),
                        initialZoom: 16,
                      ),
                      children: const [],
                    ),
                  ),
                  NewOrderSelectionPinAnchor(
                    panelHeight: panel,
                    child: const ColoredBox(color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        // Move the map as a user would: the same center feeds reverse geocoding
        // and order confirmation, while the visible tip must stay on it.
        controller.move(const LatLng(40.285, 69.626), 17);
        await tester.pump();
        final mapRect = tester.getRect(find.byType(FlutterMap));
        final projected = controller.camera.latLngToScreenOffset(
          controller.camera.center,
        );
        final coordinate = mapRect.topLeft + projected;
        final tip = tester
            .getRect(find.byKey(const ValueKey('new-order-map-selection-pin')))
            .bottomCenter;
        expect((coordinate - tip).distance, lessThan(0.01));
        expect(mapRect.bottom, closeTo(size.height - panel, 0.01));
        expect(mapRect.height, greaterThanOrEqualTo(180));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
