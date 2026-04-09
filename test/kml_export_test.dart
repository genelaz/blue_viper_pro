import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:blue_viper_pro/core/geo/gpx_kml_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('buildKmlMapExport roundtrips polygons via parseKmlPlacemarks', () {
    final kml = buildKmlMapExport(
      documentName: 'T',
      waypoints: [('X', LatLng(1, 2), null)],
      routeLine: [LatLng(0, 0), LatLng(1, 1)],
      polygons: [
        (
          'P1',
          KmlPolygonPatch(
            outer: [
              LatLng(39.9, 32.0),
              LatLng(39.9, 32.1),
              LatLng(40.0, 32.1),
              LatLng(40.0, 32.0),
            ],
            holes: [
              [
                LatLng(39.95, 32.02),
                LatLng(39.95, 32.08),
                LatLng(39.98, 32.08),
                LatLng(39.98, 32.02),
              ],
            ],
          ),
        ),
      ],
    );
    expect(kml, contains('<kml xmlns="http://www.opengis.net/kml/2.2">'));
    expect(kml, contains('<Style id="bv_route">'));
    expect(kml, contains('<styleUrl>#bv_polygon</styleUrl>'));
    expect(kml, contains('<innerBoundaryIs>'));
    final r = parseKmlPlacemarks(kml);
    expect(r.hasNetworkLink, isFalse);
    expect(r.points.length, 1);
    expect(r.points.single.iconColorArgb, 0xFFFF9800); // `bv_wpt` IconStyle ff0098ff (aabbggrr)
    expect(r.lines.length, 1);
    expect(r.polygonPatches.length, 1);
    expect(r.polygonPatches.single.holes.length, 1);
    expect(r.polygonPatches.single.outer.length, greaterThanOrEqualTo(4));
    expect(r.styledLines.length, r.lines.length);
    expect(r.styledLines.where((e) => e.$3 != null).length, greaterThanOrEqualTo(1));
  });

  test('kmlArgb32ToAabbggrrHex roundtrips with kmlLineColorAabbggrrToArgb32', () {
    for (final c in [0xFF00AA88, 0x7F00FF00, 0x55009688, 0xFFFF0000]) {
      final hex = kmlArgb32ToAabbggrrHex(c);
      expect(hex.length, 8);
      expect(kmlLineColorAabbggrrToArgb32(hex), c);
    }
  });

  test('buildKmlMapExport emits per-patch Style and parse roundtrips colors', () {
    final kml = buildKmlMapExport(
      documentName: 'S',
      polygons: [
        (
          'A',
          KmlPolygonPatch(
            outer: [LatLng(40, 32), LatLng(40, 33), LatLng(41, 33)],
            fillArgb32: 0x7F00FF00,
            strokeArgb32: 0xFFFF0000,
            strokeWidthPx: 4,
            drawStrokeOutline: true,
          ),
        ),
        (
          'B',
          KmlPolygonPatch(
            outer: [LatLng(39, 31), LatLng(39, 32), LatLng(40, 32)],
          ),
        ),
      ],
    );
    expect(kml, contains('<Style id="bv_patch_0">'));
    expect(kml, contains('<styleUrl>#bv_patch_0</styleUrl>'));
    expect(kml, contains('<styleUrl>#bv_polygon</styleUrl>'));
    final r = parseKmlPlacemarks(kml);
    expect(r.polygonPatches.length, 2);
    final a = r.polygonPatches[0];
    expect(a.fillArgb32, 0x7F00FF00);
    expect(a.strokeArgb32, 0xFFFF0000);
    expect(a.strokeWidthPx, 4);
    expect(a.drawStrokeOutline, true);
    final b = r.polygonPatches[1];
    expect(b.fillArgb32, kmlLineColorAabbggrrToArgb32('55889600'));
  });

  test('buildKmlMapExport PolyStyle outline 0 roundtrips', () {
    final kml = buildKmlMapExport(
      documentName: 'O',
      polygons: [
        (
          'NoOutline',
          KmlPolygonPatch(
            outer: [LatLng(40, 32), LatLng(40, 33), LatLng(41, 33)],
            fillArgb32: 0x80008000,
            drawStrokeOutline: false,
          ),
        ),
      ],
    );
    expect(kml, contains('<outline>0</outline>'));
    expect(kml, contains('<Style id="bv_patch_0">'));
    final p = parseKmlPlacemarks(kml).polygonPatches.single;
    expect(p.drawStrokeOutline, false);
    expect(p.strokeArgb32, isNull);
    expect(p.fillArgb32, 0x80008000);
  });

  test('buildKmlMapExport styledPolylines roundtrip via parseKmlPlacemarks', () {
    final kml = buildKmlMapExport(
      documentName: 'Lines',
      styledPolylines: [
        (
          'L1',
          [LatLng(0, 0), LatLng(1, 1)],
          0xFFFF0000,
          5,
        ),
        (
          'L2',
          [LatLng(2, 2), LatLng(3, 3), LatLng(3, 4)],
          null,
          null,
        ),
      ],
    );
    expect(kml, contains('<Style id="bv_ls_0">'));
    expect(kml, contains('<name>L1</name>'));
    expect(kml, contains('<name>L2</name>'));
    final r = parseKmlPlacemarks(kml);
    expect(r.lines.length, 2);
    expect(r.styledLines.length, 2);
    expect(r.styledLines[0].$1, 'L1');
    expect(r.styledLines[0].$3, 0xFFFF0000);
    expect(r.styledLines[0].$4, 5);
    expect(r.styledLines[1].$1, 'L2');
    expect(r.styledLines[1].$3, 0xFF673AB7);
    expect(r.styledLines[1].$4, 4);
  });

  test('encodeKmzFromKml puts doc.kml and roundtrips parse', () {
    final kml = buildKmlMapExport(
      documentName: 'Z',
      waypoints: [('W', LatLng(3, 4), null)],
      routeLine: [LatLng(5, 5), LatLng(6, 6)],
    );
    final kmz = encodeKmzFromKml(kml);
    final extracted = decodeKmzToKmlStrings(kmz);
    expect(extracted.length, 1);
    expect(extracted.single, contains('<name>Z</name>'));
    final r = parseKmlPlacemarks(extracted.single);
    expect(r.hasNetworkLink, isFalse);
    expect(r.points.length, 1);
    expect(r.points.single.iconColorArgb, 0xFFFF9800);
    expect(r.lines.length, 1);
  });

  test('parseKmlPlacemarks loads Icon href from KMZ embedded files map', () {
    const kml = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <Style id="s1">
    <IconStyle><Icon><href>files/dot.png</href></Icon></IconStyle>
  </Style>
  <Placemark><name>P</name><styleUrl>#s1</styleUrl>
  <Point><coordinates>5,10,0</coordinates></Point></Placemark>
</Document></kml>''';
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final arch = Archive()
      ..add(ArchiveFile.string('doc.kml', kml))
      ..add(ArchiveFile('files/dot.png', png.length, png));
    final kmzBytes = ZipEncoder().encode(arch);
    final files = decodeKmzEmbeddedFiles(kmzBytes);
    final r = parseKmlPlacemarks(kml, kmzEmbeddedFiles: files);
    expect(r.points.single.iconImageBytes, isNotNull);
    expect(r.points.single.iconImageBytes!.length, greaterThan(30));
    expect(r.points.single.iconHref, isNull);
    expect(r.points.single.point, const LatLng(10, 5));
  });
}
