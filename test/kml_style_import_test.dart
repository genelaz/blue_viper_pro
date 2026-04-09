import 'package:blue_viper_pro/core/geo/gpx_kml_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('parseKmlPlacemarks resolves Style id via styleUrl', () {
    const kml = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Style id="myLine">
      <LineStyle><color>ff0000ff</color><width>2</width></LineStyle>
    </Style>
    <Placemark>
      <name>L</name>
      <styleUrl>#myLine</styleUrl>
      <LineString><coordinates>30,40,0 31,41,0</coordinates></LineString>
    </Placemark>
  </Document>
</kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.lines.length, 1);
    expect(r.styledLines.length, 1);
    expect(r.styledLines.single.$1, 'L');
    expect(r.styledLines.single.$2.length, 2);
    expect(r.styledLines.single.$3, 0xFFFF0000); // opaque red (KML abgr ff0000ff)
    expect(r.styledLines.single.$4, 2);
  });

  test('parseKmlPlacemarks expands BalloonStyle text placeholders', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <Style id="b">
    <BalloonStyle><text>\$[name]: \$[description]</text></BalloonStyle>
    <IconStyle><color>ffffffff</color><scale>1</scale></IconStyle>
  </Style>
  <Placemark>
    <name>Alpha</name>
    <description><![CDATA[<b>Beta</b> desc]]></description>
    <styleUrl>#b</styleUrl>
    <Point><coordinates>1,2,0</coordinates></Point>
  </Placemark>
</Document></kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.points.single.balloonText, 'Alpha: Beta desc');
  });

  test('kmlPlainTextFromBalloonHtml strips tags and common entities', () {
    expect(kmlPlainTextFromBalloonHtml('<p>A &amp; B</p>'), 'A & B');
    expect(kmlPlainTextFromBalloonHtml('  x  '), 'x');
  });

  test('parseKmlPlacemarks sets highlight icon fields when StyleMap differs', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <Style id="n"><IconStyle><color>ff0000ff</color><scale>1</scale></IconStyle></Style>
  <Style id="h"><IconStyle><color>ff00ff00</color><scale>1.5</scale></IconStyle></Style>
  <StyleMap id="m">
    <Pair><key>normal</key><styleUrl>#n</styleUrl></Pair>
    <Pair><key>highlight</key><styleUrl>#h</styleUrl></Pair>
  </StyleMap>
  <Placemark><name>X</name><styleUrl>#m</styleUrl><Point><coordinates>0,0,0</coordinates></Point></Placemark>
</Document></kml>''';
    final r = parseKmlPlacemarks(kml);
    final p = r.points.single;
    expect(p.hasKmlIconHighlight, isTrue);
    expect(p.iconColorArgb, 0xFFFF0000);
    expect(p.iconHighlightColorArgb, 0xFF00FF00);
    expect(p.iconHighlightScale, 1.5);
  });

  test('parseKmlPlacemarks reads IconStyle color and scale on Point', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <Style id="ic">
    <IconStyle>
      <color>ff00ff00</color>
      <scale>2</scale>
    </IconStyle>
  </Style>
  <Placemark>
    <name>W</name>
    <styleUrl>#ic</styleUrl>
    <Point><coordinates>10,20,0</coordinates></Point>
  </Placemark>
</Document></kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.points.length, 1);
    expect(r.points.single.name, 'W');
    expect(r.points.single.point, const LatLng(20, 10));
    expect(r.points.single.iconColorArgb, 0xFF00FF00);
    expect(r.points.single.iconScale, 2);
  });

  test('parseKmlPlacemarks disambiguates multiple LineStrings in one Placemark', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <Placemark>
    <name>Dual</name>
    <MultiGeometry>
      <LineString><coordinates>10,20,0 11,21,0</coordinates></LineString>
      <LineString><coordinates>12,22,0 13,23,0</coordinates></LineString>
    </MultiGeometry>
  </Placemark>
</Document></kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.styledLines.length, 2);
    expect(r.styledLines[0].$1, 'Dual');
    expect(r.styledLines[1].$1, 'Dual (2)');
  });

  test('parseKmlPlacemarks resolves StyleMap normal pair', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <Style id="sn"><LineStyle><color>ff00ffff</color></LineStyle></Style>
  <StyleMap id="msn">
    <Pair><key>highlight</key><styleUrl>#sn</styleUrl></Pair>
    <Pair><key>normal</key><styleUrl>#sn</styleUrl></Pair>
  </StyleMap>
  <Placemark>
    <styleUrl>#msn</styleUrl>
    <LineString><coordinates>10,20,0 11,21,0</coordinates></LineString>
  </Placemark>
</Document></kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.styledLines.length, 1);
    expect(r.styledLines.single.$1, 'PM');
    expect(r.styledLines.single.$3, 0xFFFFFF00); // yellow
  });

  test('parseKmlPlacemarks applies shared Style to Polygon fill and stroke', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <Style id="p1">
    <LineStyle><color>ff0000ff</color><width>3</width></LineStyle>
    <PolyStyle><color>7f00ff00</color><outline>1</outline></PolyStyle>
  </Style>
  <Placemark>
    <styleUrl>#p1</styleUrl>
    <Polygon>
      <outerBoundaryIs><LinearRing><coordinates>
      32.0,39.9,0 32.1,39.9,0 32.1,40.0,0 32.0,40.0,0 32.0,39.9,0
      </coordinates></LinearRing></outerBoundaryIs>
    </Polygon>
  </Placemark>
</Document></kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.polygonPatches.length, 1);
    final p = r.polygonPatches.single;
    expect(p.fillArgb32, 0x7F00FF00);
    expect(p.strokeArgb32, 0xFFFF0000);
    expect(p.strokeWidthPx, 3);
    expect(p.drawStrokeOutline, true);
  });

  test('PolyStyle outline 0 clears polygon stroke ARGB', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <Style id="p1">
    <LineStyle><color>ffffffff</color><width>2</width></LineStyle>
    <PolyStyle><color>80008000</color><outline>0</outline></PolyStyle>
  </Style>
  <Placemark>
    <styleUrl>#p1</styleUrl>
    <Polygon>
      <outerBoundaryIs><LinearRing><coordinates>
      32.0,39.9,0 32.1,39.9,0 32.1,40.0,0 32.0,39.9,0
      </coordinates></LinearRing></outerBoundaryIs>
    </Polygon>
  </Placemark>
</Document></kml>''';
    final r = parseKmlPlacemarks(kml);
    final p = r.polygonPatches.single;
    expect(p.drawStrokeOutline, false);
    expect(p.strokeArgb32, isNull);
  });

  test('Polygon outer ring is not duplicated as line', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <Placemark>
    <Polygon>
      <outerBoundaryIs>
        <LinearRing>
          <coordinates>32.0,39.9,0 32.1,39.9,0 32.1,40.0,0 32.0,40.0,0 32.0,39.9,0</coordinates>
        </LinearRing>
      </outerBoundaryIs>
    </Polygon>
  </Placemark>
</Document></kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.lines, isEmpty);
    expect(r.styledLines, isEmpty);
    expect(r.polygonPatches.length, 1);
  });

  test('buildKmlMapExport styles roundtrip stroke color', () {
    final built = buildKmlMapExport(
      documentName: 'T',
      routeLine: [LatLng(1, 2), LatLng(2, 3)],
    );
    final r = parseKmlPlacemarks(built);
    expect(r.lines.length, 1);
    expect(r.styledLines.length, 1);
    expect(r.styledLines.single.$1, 'T — rota');
    expect(r.styledLines.single.$3, isNotNull);
  });
}
