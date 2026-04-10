import 'package:blue_viper_pro/core/realtime/map_collab_identity.dart';
import 'package:blue_viper_pro/features/maps/presentation/maps_page.dart';
import 'package:blue_viper_pro/main.dart';
import 'helpers/maps_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Harita sekmesi akışları çalışır', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      // licensing gate
      'activation_ok_v1': true,
      'activation_remote_v1': false,
      // bootstrap intro
      'app_permissions_intro_done_v1': true,
      'map_collab_user_id': 'test-nav-user',
    });
    await MapCollabIdentity.load();

    await tester.pumpWidget(
      const BlueViperProApp(showDeveloperCreditOverlay: false),
    );
    await tester.pumpAndSettle();

    // Bottom NavigationBar -> Harita sekmesi (ikinci hedef).
    final navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);
    final haritaIcon = find.descendant(
      of: navBar,
      matching: find.byIcon(Icons.map_outlined),
    );
    expect(haritaIcon, findsOneWidget);
    await tester.ensureVisible(haritaIcon);
    await tester.tap(haritaIcon);
    await tester.pumpAndSettle();

    expect(find.byType(MapsPage), findsOneWidget);
    final state = mapsPageState(tester);

    // HUD / tools should be present
    expect(find.byKey(const ValueKey('maps_topright_layers_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('maps_zoom_in_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('maps_zoom_out_button')), findsOneWidget);

    // 1) Katmanlar sheet aç/kapat
    await tester.tap(find.byKey(const ValueKey('maps_topright_layers_button')));
    await tester.pumpAndSettle();
    expect(find.text('Altlık'), findsOneWidget);
    expect(find.text('Çevrimiçi'), findsWidgets);
    // Katman seçimi (dropdown) - çökmeden ve state güncelleyerek
    expect(state.debugMapBase, isNotNull);
    final baseDropdown = find.byKey(const ValueKey('maps_layers_online_base_dropdown'));
    expect(baseDropdown, findsOneWidget);
    await tester.tap(baseDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OSM').last);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // scrim
    await tester.pumpAndSettle();
    expect(find.text('Altlık'), findsNothing);

    // 2) Zoom + / - tıkla (çökmeden)
    await tester.tap(find.byKey(const ValueKey('maps_zoom_in_button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('maps_zoom_out_button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 3) Menü sheet aç/kapat
    final menuButton = find.widgetWithIcon(IconButton, Icons.menu);
    expect(menuButton, findsOneWidget);
    await openMapDetailsSheet(tester);
    await tester.tapAt(const Offset(5, 5)); // scrim
    await tester.pumpAndSettle();
    expect(find.text('Harita · ayrıntılar'), findsNothing);

    // 3.1) Koordinat/arama sheet aç/kapat
    await tester.tap(find.byKey(const ValueKey('maps_topright_coordinate_search_button')));
    await tester.pumpAndSettle();
    expect(find.text('Koordinat ile işaret'), findsOneWidget);
    // Sheet kapanır
    await tester.tapAt(const Offset(5, 5)); // scrim
    await tester.pumpAndSettle();
    expect(find.text('Koordinat ile işaret'), findsNothing);

    // 3.2) Alt şeritte dışa aktarma menüsü (GPX / KML), etkin (tıklamıyoruz)
    final exportMenuFinder = find.byKey(const ValueKey('maps_bottom_export_menu_button'));
    expect(exportMenuFinder, findsOneWidget);
    final exportMenu = tester.widget<PopupMenuButton<String>>(exportMenuFinder);
    expect(exportMenu.enabled, isTrue);

    // 4) TapMode değiştir → haritaya tıkla → İşaret 1 oluşur
    await tester.tap(find.byKey(const ValueKey('maps_bottom_tapmode_waypoint1_button')));
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.9, 32.8));
    await tester.pumpAndSettle();
    expect(state.debugWaypoint1, isNotNull);

    // 5) TapMode rota → haritaya tıkla → rota marker "1" oluşur
    await tester.tap(find.byKey(const ValueKey('maps_bottom_tapmode_route_button')));
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.9005, 32.8005));
    await tester.pumpAndSettle();
    expect(state.debugRouteVertexCount, 1);

    // 6) TapMode İşaret 2 → haritaya tıkla → waypoint2 oluşur
    state.debugSelectTapModeWaypoint2();
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.901, 32.801));
    await tester.pumpAndSettle();
    expect(state.debugWaypoint2, isNotNull);

    // 7) TapMode Konum (mapAnchor) → haritaya tıkla → myPosition güncellenir ve followGps kapanır
    state.debugSelectTapModeMapAnchor();
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.902, 32.802));
    await tester.pumpAndSettle();
    expect(state.debugMyPosition, isNotNull);
    expect(state.debugFollowGps, isFalse);

    // 8) TapMode Alan → haritaya tıkla → poligon köşe sayısı artar
    state.debugSelectTapModePolygonVertex();
    await tester.pumpAndSettle();
    state.debugHandleMapTap(const LatLng(39.903, 32.803));
    state.debugHandleMapTap(const LatLng(39.904, 32.804));
    state.debugHandleMapTap(const LatLng(39.905, 32.805));
    await tester.pumpAndSettle();
    expect(state.debugPolygonVertexCount, greaterThanOrEqualTo(3));

    // 9) İz kaydı (alt çubuk yüksekliği değişince üst buton z-order’da kayabiliyor; state API)
    expect(state.debugRecordingTrack, isFalse);
    state.debugToggleTrackRecording();
    await tester.pumpAndSettle();
    expect(state.debugRecordingTrack, isTrue);

    state.debugToggleTrackRecording();
    await tester.pumpAndSettle();
    expect(state.debugRecordingTrack, isFalse);
  });
}

