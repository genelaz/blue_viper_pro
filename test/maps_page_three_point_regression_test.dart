import 'helpers/maps_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('Bottom controls allow waypoint2 selection', (tester) async {
    await pumpStandaloneMapsPage(tester);

    final state = mapsPageState(tester);

    await tester.tap(find.byKey(const ValueKey('maps_bottom_tapmode_waypoint1_button')));
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.900, 32.800));
    await tester.pumpAndSettle();
    expect(state.debugWaypoint1, isNotNull);

    await tester.tap(find.byKey(const ValueKey('maps_bottom_tapmode_waypoint2_button')));
    await tester.pumpAndSettle();

    state.debugHandleMapTap(const LatLng(39.901, 32.801));
    await tester.pumpAndSettle();

    expect(state.debugWaypoint2, isNotNull);
  });

  testWidgets('Polygon reaches 3-point condition', (tester) async {
    await pumpStandaloneMapsPage(tester);

    final state = mapsPageState(tester);
    state.debugSelectTapModePolygonVertex();
    await tester.pumpAndSettle();

    state.debugHandleMapTap(const LatLng(39.903, 32.803));
    state.debugHandleMapTap(const LatLng(39.904, 32.804));
    state.debugHandleMapTap(const LatLng(39.905, 32.805));
    await tester.pumpAndSettle();

    expect(state.debugPolygonVertexCount, greaterThanOrEqualTo(3));
  });

  testWidgets('Route 3-point undo and clear remain stable in details sheet', (tester) async {
    await pumpStandaloneMapsPage(tester);

    final state = mapsPageState(tester);

    await tester.tap(find.byKey(const ValueKey('maps_bottom_tapmode_route_button')));
    await tester.pumpAndSettle();

    state.debugHandleMapTap(const LatLng(39.9001, 32.8001));
    state.debugHandleMapTap(const LatLng(39.9002, 32.8002));
    state.debugHandleMapTap(const LatLng(39.9003, 32.8003));
    await tester.pumpAndSettle();

    expect(state.debugRouteVertexCount, 3);

    await openMapDetailsSheet(tester);
    expect(find.text('Rota (3)'), findsOneWidget);

    final undoRouteButton = find.byKey(const ValueKey('maps_details_route_undo_button'));
    final undoBefore = tester.widget<TextButton>(undoRouteButton);
    expect(undoBefore.onPressed, isNotNull);

    state.debugUndoLastRouteVertex();
    await tester.pumpAndSettle();
    expect(state.debugRouteVertexCount, 2);
    expect(find.text('Rota (2)'), findsOneWidget);

    final clearRouteButton = find.byKey(const ValueKey('maps_details_route_clear_button'));
    expect(tester.widget<TextButton>(clearRouteButton).onPressed, isNotNull);

    state.debugClearRouteVertices();
    await tester.pumpAndSettle();
    expect(state.debugRouteVertexCount, 0);
    expect(find.text('Rota (0)'), findsOneWidget);

    final undoAfter = tester.widget<TextButton>(undoRouteButton);
    expect(undoAfter.onPressed, isNull);
  });

  testWidgets('Details sheet enabled-disabled matrix updates live', (tester) async {
    await pumpStandaloneMapsPage(tester);

    final state = mapsPageState(tester);

    await openMapDetailsSheet(tester);
    expect(detailsTapModeSegmentedFinder(), findsOneWidget);
    expect(detailsUtmZoneDropdownFinder(), findsOneWidget);

    expect(isEnabled(buttonByText(tester, 'Konuma git')), isFalse);
    expect(isEnabled(buttonByText(tester, "İşaret 1'e git")), isFalse);
    expect(isEnabled(buttonByText(tester, "İşaret 2'ye git")), isFalse);
    expect(isEnabled(buttonByText(tester, 'İşaret 2 sil')), isFalse);
    expect(isEnabled(buttonByText(tester, 'Rota geri')), isFalse);
    expect(isEnabled(buttonByText(tester, 'Alan geri')), isFalse);
    expect(isEnabled(buttonByText(tester, 'DEM (noktalar)')), isFalse);

    state.debugSelectTapModeMapAnchor();
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.93, 32.83));
    await tester.pumpAndSettle();
    expect(isEnabled(buttonByText(tester, 'Konuma git')), isTrue);

    state.debugSelectTapModeWaypoint1();
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.91, 32.81));
    await tester.pumpAndSettle();

    state.debugSelectTapModeWaypoint2();
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.92, 32.82));
    await tester.pumpAndSettle();

    state.debugSelectTapModeRouteVertex();
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.9001, 32.8001));
    state.debugHandleMapTap(const LatLng(39.9002, 32.8002));
    await tester.pumpAndSettle();

    state.debugSelectTapModePolygonVertex();
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.9301, 32.8301));
    state.debugHandleMapTap(const LatLng(39.9302, 32.8302));
    await tester.pumpAndSettle();

    expect(isEnabled(buttonByText(tester, "İşaret 1'e git")), isTrue);
    expect(isEnabled(buttonByText(tester, "İşaret 2'ye git")), isTrue);
    expect(isEnabled(buttonByText(tester, 'İşaret 2 sil')), isTrue);
    expect(isEnabled(buttonByText(tester, 'Rota geri')), isTrue);
    expect(isEnabled(buttonByText(tester, 'Alan geri')), isTrue);
    expect(isEnabled(buttonByText(tester, 'DEM (noktalar)')), isTrue);

    expect(find.text('Rota (2)'), findsOneWidget);
    expect(find.text('Alan (2)'), findsOneWidget);
  });

  testWidgets('Konuma git recenters map to GPS point', (tester) async {
    await pumpStandaloneMapsPage(tester);

    final state = mapsPageState(tester);

    await openMapDetailsSheet(tester);

    state.debugSelectTapModeMapAnchor();
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.931234, 32.831234));
    await tester.pumpAndSettle();

    final goToLocationButtonFinder = detailsGotoLocationButtonFinder();
    final goToLocationButton = tester.widget<OutlinedButton>(goToLocationButtonFinder);
    expect(isEnabled(goToLocationButton), isTrue);

    await tester.tap(goToLocationButtonFinder);
    await tester.pumpAndSettle();

    final center = state.debugMapHudCenter as LatLng;
    expect(coordsApproxEqual(center.latitude, 39.931234), isTrue);
    expect(coordsApproxEqual(center.longitude, 32.831234), isTrue);
  });
}
