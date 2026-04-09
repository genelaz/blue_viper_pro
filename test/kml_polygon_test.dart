import 'package:blue_viper_pro/core/geo/gpx_kml_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseKmlPlacemarks reads Polygon outerBoundaryIs', () {
    const kml = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Placemark>
    <name>Alan</name>
    <Polygon>
      <outerBoundaryIs>
        <LinearRing>
          <coordinates>
            32.0,39.9,0 32.1,39.9,0 32.1,40.0,0 32.0,40.0,0 32.0,39.9,0
          </coordinates>
        </LinearRing>
      </outerBoundaryIs>
    </Polygon>
  </Placemark>
</kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.polygonPatches.length, 1);
    expect(r.polygonPatches.single.outer.length, greaterThanOrEqualTo(4));
    expect(r.polygonPatches.single.holes, isEmpty);
    expect(r.polygonPatches.single.outer.first.latitude, closeTo(39.9, 1e-6));
    expect(r.polygonPatches.single.outer.first.longitude, closeTo(32.0, 1e-6));
  });

  test('parseKmlPlacemarks reads innerBoundaryIs holes', () {
    const kml = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Placemark>
    <Polygon>
      <outerBoundaryIs>
        <LinearRing>
          <coordinates>
            32.0,39.9,0 32.2,39.9,0 32.2,40.1,0 32.0,40.1,0 32.0,39.9,0
          </coordinates>
        </LinearRing>
      </outerBoundaryIs>
      <innerBoundaryIs>
        <LinearRing>
          <coordinates>
            32.05,39.95,0 32.15,39.95,0 32.15,40.05,0 32.05,40.05,0 32.05,39.95,0
          </coordinates>
        </LinearRing>
      </innerBoundaryIs>
    </Polygon>
  </Placemark>
</kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.polygonPatches.length, 1);
    expect(r.polygonPatches.single.holes.length, 1);
    expect(r.polygonPatches.single.holes.single.length, greaterThanOrEqualTo(4));
    expect(r.polygonPatches.single.holes.single.first.latitude, closeTo(39.95, 1e-6));
  });

  test('parseKmlPlacemarks reads MultiPolygon outer rings', () {
    const kml = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Placemark>
    <name>Çoklu alan</name>
    <MultiPolygon>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>30.0,40.0,0 30.1,40.0,0 30.1,40.1,0 30.0,40.1,0 30.0,40.0,0</coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>31.0,41.0,0 31.2,41.0,0 31.2,41.2,0 31.0,41.2,0 31.0,41.0,0</coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </MultiPolygon>
  </Placemark>
</kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.polygonPatches.length, 2);
    expect(r.polygonPatches[0].outer.first.latitude, closeTo(40.0, 1e-6));
    expect(r.polygonPatches[0].outer.first.longitude, closeTo(30.0, 1e-6));
    expect(r.polygonPatches[1].outer.first.latitude, closeTo(41.0, 1e-6));
    expect(r.polygonPatches[1].outer.first.longitude, closeTo(31.0, 1e-6));
  });

  test('parseKmlPlacemarks MultiPolygon inside MultiGeometry', () {
    const kml = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Placemark>
    <name>Mixed</name>
    <MultiGeometry>
      <MultiPolygon>
        <Polygon>
          <outerBoundaryIs>
            <LinearRing>
              <coordinates>28.0,38.0,0 28.1,38.0,0 28.1,38.1,0 28.0,38.1,0 28.0,38.0,0</coordinates>
            </LinearRing>
          </outerBoundaryIs>
        </Polygon>
      </MultiPolygon>
    </MultiGeometry>
  </Placemark>
</kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.polygonPatches.length, 1);
    expect(r.polygonPatches.single.outer.first.latitude, closeTo(38.0, 1e-6));
    expect(r.polygonPatches.single.outer.first.longitude, closeTo(28.0, 1e-6));
  });

  test('parseKmlPlacemarks flags NetworkLink when present', () {
    const kml = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <NetworkLink>
    <Link><href>http://example.com/x.kml</href></Link>
  </NetworkLink>
  <Placemark><name>P</name><Point><coordinates>30,40,0</coordinates></Point></Placemark>
</kml>''';
    final r = parseKmlPlacemarks(kml);
    expect(r.hasNetworkLink, isTrue);
    expect(r.points.length, 1);
  });
}
