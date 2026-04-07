import 'package:latlong2/latlong.dart';
import 'package:proj4dart/proj4dart.dart';

/// WGS 84 / UTM **kuzey** yarıküre (EPSG **32601** … **32660**).
///
/// Orta Doğu için tipik zonlar **35N–41N** (EPSG **32635**–**32641**).
class Wgs84UtmNorth {
  Wgs84UtmNorth._();

  static final Projection _wgs84 = Projection.get('EPSG:4326')!;

  static final Map<int, Projection> _utm = {};

  static Projection _utmProj(int zone) {
    if (zone < 1 || zone > 60) {
      throw ArgumentError('UTM zon 1–60 olmalı: $zone');
    }
    return _utm.putIfAbsent(
      zone,
      () => Projection.parse('+proj=utm +zone=$zone +datum=WGS84 +units=m +no_defs'),
    );
  }

  /// Kuzey TM için EPSG kodu: 32600 + zon.
  static int epsgCode(int zone) => 32600 + zone;

  /// Boylama göre UTM zon (1–60).
  static int autoZoneFromLongitude(double lon) {
    var z = ((lon + 180) / 6).floor() + 1;
    if (z < 1) z = 1;
    if (z > 60) z = 60;
    return z;
  }

  /// WGS84 → UTM metre (kuzey).
  static (double easting, double northing) toUtm(LatLng wgs, int zone) {
    final src = Point(x: wgs.longitude, y: wgs.latitude);
    final r = _wgs84.transform(_utmProj(zone), src);
    return (r.x, r.y);
  }

  /// UTM metre (kuzey) → WGS84.
  static LatLng fromUtm({
    required double easting,
    required double northing,
    required int zone,
  }) {
    final src = Point(x: easting, y: northing);
    final r = _utmProj(zone).transform(_wgs84, src);
    return LatLng(r.y, r.x);
  }

  /// Orta Doğu için sık kullanılan zonlar (35N–41N).
  static const middleEastZones = [35, 36, 37, 38, 39, 40, 41];
}
