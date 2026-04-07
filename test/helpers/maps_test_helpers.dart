import 'package:blue_viper_pro/core/realtime/realtime_ptt_service_factory.dart';
import 'package:blue_viper_pro/features/maps/presentation/maps_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpStandaloneMapsPage(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: MapsPage(
          pttBackend: RealtimePttBackend.inMemory,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 15));
}

dynamic mapsPageState(WidgetTester tester) {
  return tester.state(find.byType(MapsPage)) as dynamic;
}

Future<void> openMapDetailsSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('maps_bottom_open_details_button')));
  await tester.pumpAndSettle(const Duration(seconds: 15));
  expect(find.text('Harita · ayrıntılar'), findsOneWidget);

  final utm = find.byKey(const ValueKey('maps_details_utm_zone_dropdown'));
  for (var i = 0; i < 40; i++) {
    if (utm.evaluate().isNotEmpty) break;
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(utm, findsOneWidget, reason: 'UTM alanı detay sheet içinde oluşmalı');
  // Do not ensureVisible(utm): it scrolls the sheet and can unmount lazily-built
  // widgets above (e.g. SegmentedButton) in widget tests.
}

Finder detailsTapModeSegmentedFinder() =>
    find.byKey(const ValueKey('maps_details_tap_mode_segmented'));

Finder detailsUtmZoneDropdownFinder() =>
    find.byKey(const ValueKey('maps_details_utm_zone_dropdown'));

Finder detailsGotoLocationButtonFinder() =>
    find.byKey(const ValueKey('maps_details_goto_location_button'));

ButtonStyleButton buttonByText(WidgetTester tester, String text) {
  final sheet = find.byType(DraggableScrollableSheet);
  final textInSheet = find.descendant(of: sheet, matching: find.text(text));
  expect(textInSheet, findsOneWidget);
  final btn = find.ancestor(
    of: textInSheet,
    matching: find.byWidgetPredicate(
      (w) => w is ButtonStyleButton,
    ),
  );
  expect(btn, findsOneWidget);
  return tester.widget<ButtonStyleButton>(btn);
}

bool isEnabled(ButtonStyleButton button) => button.onPressed != null;

bool coordsApproxEqual(double a, double b, {double eps = 1e-4}) =>
    (a - b).abs() <= eps;
