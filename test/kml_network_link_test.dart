import 'package:blue_viper_pro/core/geo/gpx_kml_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('kmlHttpsNetworkLinkHrefs collects https hrefs only', () {
    const kml = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <NetworkLink><name>A</name><Link><href>http://evil/insecure.kml</href></Link></NetworkLink>
    <NetworkLink><Link><href>https://example.com/x.kml</href></Link></NetworkLink>
    <NetworkLink><Link><href>relative.kml</href></Link></NetworkLink>
  </Document>
</kml>''';
    final h = kmlHttpsNetworkLinkHrefs(kml);
    expect(h, ['https://example.com/x.kml']);
  });

  test('kmlHttpsNetworkLinkHrefs dedupes identical https hrefs', () {
    const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <NetworkLink><Link><href>https://example.com/same.kml</href></Link></NetworkLink>
  <NetworkLink><Link><href>https://example.com/same.kml</href></Link></NetworkLink>
  <NetworkLink><Link><href>https://example.com/other.kml</href></Link></NetworkLink>
</Document></kml>''';
    final h = kmlHttpsNetworkLinkHrefs(kml, maxLinks: 5);
    expect(h, ['https://example.com/same.kml', 'https://example.com/other.kml']);
  });

  test('parseKmlPlacemarksWithNetworkLinks equals sync when no network hrefs', () async {
    final kml = buildKmlMapExport(
      documentName: 'L',
      waypoints: [('P', LatLng(1, 2))],
      routeLine: [LatLng(0, 0), LatLng(1, 1)],
    );
    final sync = parseKmlPlacemarks(kml);
    final async = await parseKmlPlacemarksWithNetworkLinks(kml);
    expect(async.hadNetworkLink, sync.hasNetworkLink);
    expect(async.resolvedAnyNetworkLink, isFalse);
    expect(async.points.length, sync.points.length);
    expect(async.lines.length, sync.lines.length);
    expect(async.styledLines.length, sync.styledLines.length);
    expect(async.polygonPatches.length, sync.polygonPatches.length);
  });

  test('parseKmlDocumentsWithNetworkLinks merges two static docs', () async {
    const a = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <Placemark><Point><coordinates>10,20,0</coordinates></Point></Placemark>
</Document></kml>''';
    const b = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document>
  <Placemark><Point><coordinates>11,21,0</coordinates></Point></Placemark>
</Document></kml>''';
    final m = await parseKmlDocumentsWithNetworkLinks([a, b]);
    expect(m.points.length, 2);
    expect(m.styledLines.length, m.lines.length);
    expect(m.anyHadNetworkLink, isFalse);
    expect(m.anyResolvedNetworkLink, isFalse);
  });
}
