import 'package:blue_viper_pro/core/geo/gpx_kml_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('buildGpxDocument adds areaLoops as trk and closes ring', () {
    final ring = [
      LatLng(40.0, 30.0),
      LatLng(40.0, 30.1),
      LatLng(40.1, 30.1),
    ];
    final xml = buildGpxDocument(
      name: 'T',
      areaLoops: [('Test alan', ring)],
    );
    expect(xml, contains('<trk><name>Test alan</name>'));
    expect(xml.split('<trkpt').length - 1, 4);
    final p = parseGpx(xml);
    expect(p.tracks.length, 1);
    expect(p.tracks.single.length, 4);
    expect(p.tracks.single.last.latitude, closeTo(40.0, 1e-9));
    expect(p.tracks.single.last.longitude, closeTo(30.0, 1e-9));
  });

  test('buildGpxDocument lineTracks become separate trk segments', () {
    final xml = buildGpxDocument(
      name: 'M',
      lineTracks: [
        ('A', [LatLng(1, 2), LatLng(3, 4)]),
        ('B', [LatLng(5, 6), LatLng(7, 8), LatLng(9, 10)]),
      ],
    );
    expect(xml, contains('<trk><name>A</name>'));
    expect(xml, contains('<trk><name>B</name>'));
    expect(xml.split('<trk>').length - 1, 2);
    final p = parseGpx(xml);
    expect(p.tracks.length, 2);
    expect(p.tracks[0].length, 2);
    expect(p.tracks[1].length, 3);
  });

  test('parseGpx fills namedTrackLines and namedRouteLines', () {
    final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
  <trk><name>A</name><trkseg>
    <trkpt lat="1" lon="2"/><trkpt lat="3" lon="4"/>
  </trkseg><trkseg>
    <trkpt lat="5" lon="6"/><trkpt lat="7" lon="8"/>
  </trkseg></trk>
  <rte><name>R1</name>
    <rtept lat="10" lon="20"/><rtept lat="11" lon="21"/>
  </rte>
</gpx>''';
    final p = parseGpx(xml);
    expect(p.namedTrackLines.length, 2);
    expect(p.namedTrackLines[0].$1, 'A');
    expect(p.namedTrackLines[1].$1, 'A (2)');
    expect(p.namedRouteLines.single.$1, 'R1');
    expect(p.tracks.length, 2);
    expect(p.routes.length, 1);
  });

  test('buildGpxDocument routeLines and lineTracks can both appear', () {
    final xml = buildGpxDocument(
      name: 'M',
      routeLines: [('M — rota', [LatLng(0, 0), LatLng(1, 1)])],
      lineTracks: [('Seg', [LatLng(2, 2), LatLng(3, 3)])],
    );
    expect(xml, contains('<rte>'));
    expect(xml, contains('<trk><name>Seg</name>'));
    final p = parseGpx(xml);
    expect(p.routes.length, 1);
    expect(p.tracks.length, 1);
  });

  test('buildGpxDocument routeLines stay rte on parse (trk separate)', () {
    final xml = buildGpxDocument(
      name: 'Doc',
      routeLines: [('Plan', [LatLng(10, 20), LatLng(11, 21)])],
      lineTracks: [('Kayıt', [LatLng(1, 2), LatLng(3, 4)])],
    );
    final p = parseGpx(xml);
    expect(p.namedRouteLines.single.$1, 'Plan');
    expect(p.namedTrackLines.single.$1, 'Kayıt');
    expect(p.routes.length, 1);
    expect(p.tracks.length, 1);
  });

  test('buildGpxDocument multiple rte', () {
    final xml = buildGpxDocument(
      name: 'X',
      routeLines: [
        ('R1', [LatLng(0, 0), LatLng(1, 1)]),
        ('R2', [LatLng(2, 2), LatLng(3, 3)]),
      ],
      lineTracks: [('T1', [LatLng(4, 4), LatLng(5, 5)])],
    );
    expect(xml.split('<rte>').length - 1, 2);
    expect(xml.split('<trk>').length - 1, 1);
  });
}
