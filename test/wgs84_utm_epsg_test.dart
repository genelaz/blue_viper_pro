import 'package:blue_viper_pro/core/geo/wgs84_utm_epsg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('WGS84 ↔ UTM 38N (Irak/Orta Doğu) gidiş-dönüş', () {
    const wgs = LatLng(33.3152, 44.3661); // Bağdat yakını
    expect(Wgs84UtmNorth.autoZoneFromLongitude(wgs.longitude), 38);
    const z = 38;
    expect(Wgs84UtmNorth.epsgCode(z), 32638);
    final (e, n) = Wgs84UtmNorth.toUtm(wgs, z);
    final back = Wgs84UtmNorth.fromUtm(easting: e, northing: n, zone: z);
    expect((back.latitude - wgs.latitude).abs(), lessThan(5e-5));
    expect((back.longitude - wgs.longitude).abs(), lessThan(5e-5));
  });

  test('Orta Doğu zon listesi 35–41', () {
    expect(Wgs84UtmNorth.middleEastZones.first, 35);
    expect(Wgs84UtmNorth.middleEastZones.last, 41);
    expect(Wgs84UtmNorth.epsgCode(41), 32641);
  });
}
