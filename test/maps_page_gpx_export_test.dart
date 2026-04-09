import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/maps_test_helpers.dart';

void main() {
  testWidgets('GPX: KML segmentleri ayrı trk; içe aktarım baz çizgisiyle rte yok', (tester) async {
    await pumpStandaloneMapsPage(tester);
    final state = mapsPageState(tester);
    const a = LatLng(10, 20);
    const b = LatLng(11, 21);
    const c = LatLng(30, 40);
    const d = LatLng(31, 41);
    state.debugApplyKmlImportSnapshotForTest(
      styledLines: [
        ('Çizgi 1', [a, b], 0xFF0000FF, 3.0),
        ('Çizgi 2', [c, d], 0xFF00FF00, 3.0),
      ],
      routeVertices: [a, b, c, d],
    );
    await tester.pumpAndSettle();
    final gpx = state.debugBuildGpxDocumentForTest();
    expect(gpx.split('<trk>').length - 1, 2);
    expect(gpx, contains('<trk><name>Çizgi 1</name>'));
    expect(gpx, contains('<trk><name>Çizgi 2</name>'));
    expect(gpx, isNot(contains('<rte>')));
  });

  testWidgets('GPX: rota KML bazından farklıysa rte de yazılır', (tester) async {
    await pumpStandaloneMapsPage(tester);
    final state = mapsPageState(tester);
    const a = LatLng(1, 2);
    const b = LatLng(3, 4);
    const extra = LatLng(9, 9);
    state.debugApplyKmlImportSnapshotForTest(
      styledLines: [('Tek', [a, b], null, null)],
      routeVertices: [a, b, extra],
    );
    await tester.pumpAndSettle();
    final gpx = state.debugBuildGpxDocumentForTest();
    expect(gpx, contains('<rte>'));
    expect(gpx, contains('<trk><name>Tek</name>'));
    expect(gpx.split('<rtept').length - 1, 3);
  });

  testWidgets('GPX: içe aktarım izi trk, plan rte olarak ayrı yazılır', (tester) async {
    await pumpStandaloneMapsPage(tester);
    final state = mapsPageState(tester);
    const t1 = LatLng(1, 2);
    const t2 = LatLng(3, 4);
    const r1 = LatLng(10, 20);
    const r2 = LatLng(11, 21);
    state.debugApplyGpxImportSnapshotForTest(
      trackLines: [('Kayıt', [t1, t2])],
      routeLines: [('Plan', [r1, r2])],
      routeVertices: [t1, t2, r1, r2],
    );
    await tester.pumpAndSettle();
    final gpx = state.debugBuildGpxDocumentForTest();
    expect(gpx, contains('<trk><name>Kayıt</name>'));
    expect(gpx, contains('<rte><name>Plan</name>'));
    expect(gpx, isNot(contains('<trk><name>Plan</name>')));
    expect(state.debugImportPolylineStrokeArgbAt(0), 0xFF1565C0);
    expect(state.debugImportPolylineStrokeArgbAt(1), 0xFFE65100);
  });
}
