import 'package:latlong2/latlong.dart';
import 'package:proj4dart/proj4dart.dart';

/// Türkiye alanında yaygın **SK-42 / Pulkovo 1942** 3° dilim Gauss–Kruger (TM),
/// yalancı doğu **500 000 m**, Krasovski 1940, WGS84’e [EPSG tarzı towgs84](https://epsg.io/28406).
///
/// Resmi ölçümde NTv2 ızgarası gerekebilir; bu sınıf yaklaşık 7-parametre dönüşümüdür.
class Sk42TurkeyGrid {
  Sk42TurkeyGrid._();

  /// Orta meridyenleri (°) — Türkiye 3° dilimleri.
  static const meridians = [27, 30, 33, 36, 39, 42, 45];

  /// Boylama en yakın orta meridyeni seçer.
  static int pickMeridian(double lonWgs84) {
    var best = 33;
    var bestD = double.infinity;
    for (final m in meridians) {
      final d = (lonWgs84 - m).abs();
      if (d < bestD) {
        bestD = d;
        best = m;
      }
    }
    return best;
  }

  static final Projection _wgs84 = Projection.get('EPSG:4326')!;

  static final Map<int, Projection> _tm = {};

  static Projection _projected(int centralMeridian) {
    if (!meridians.contains(centralMeridian)) {
      throw ArgumentError('Geçersiz orta meridyen: $centralMeridian');
    }
    return _tm.putIfAbsent(centralMeridian, () {
      final def = '+proj=tmerc +lat_0=0 +lon_0=$centralMeridian +k=1 '
          '+x_0=500000 +y_0=0 +ellps=krass '
          '+towgs84=25,-141,-78.5,0,-0.35,-0.736,0 +units=m +no_defs';
      return Projection.parse(def);
    });
  }

  /// WGS84 → SK-42 TM (E, N metre).
  static (double east, double north) wgs84ToGrid(LatLng wgs, int centralMeridian) {
    final src = Point(x: wgs.longitude, y: wgs.latitude);
    final r = _wgs84.transform(_projected(centralMeridian), src);
    return (r.x, r.y);
  }

  /// SK-42 TM → WGS84.
  static LatLng gridToWgs84({
    required double easting,
    required double northing,
    required int centralMeridian,
  }) {
    final src = Point(x: easting, y: northing);
    final r = _projected(centralMeridian).transform(_wgs84, src);
    return LatLng(r.y, r.x);
  }
}
