import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../geo/wgs84_utm_epsg.dart';

/// WGS enlem/boylam veya kuzey yarıküre UTM metrajıyla uyumlu koordinat ızgarası.
///
/// UTM çizgileri harita merkezinde seçilen zon için üretilir; MGRS ile aynı
/// metre tabanını (1 km, 100 m, …) yansıtır.
abstract final class MapCoordinateGrid {
  static const int _maxLinesPerAxis = 48;
  static const int _utmCurveSegments = 28;

  static double _wgsStepDeg(double zoom) {
    if (zoom <= 4) return 10;
    if (zoom <= 6) return 5;
    if (zoom <= 8) return 1;
    if (zoom <= 10) return 0.5;
    if (zoom <= 12) return 0.1;
    if (zoom <= 14) return 0.05;
    if (zoom <= 16) return 0.02;
    return 0.01;
  }

  static double _utmStepMeters(double zoom) {
    if (zoom <= 7) return 100000;
    if (zoom <= 9) return 10000;
    if (zoom <= 11) return 1000;
    if (zoom <= 13) return 500;
    if (zoom <= 15) return 100;
    if (zoom <= 17) return 50;
    return 25;
  }

  /// [south]≤[north], [west]≤[east]; derece (WGS84).
  static List<List<LatLng>> wgs84LineSegments({
    required double south,
    required double north,
    required double west,
    required double east,
    required double zoom,
  }) {
    if (north <= south || east < west) return const [];

    var step = _wgsStepDeg(zoom);
    final latSpan = north - south;
    final lonSpan = east - west;

    while (latSpan / step > _maxLinesPerAxis + 1) {
      step *= 2;
    }
    while (lonSpan / step > _maxLinesPerAxis + 1) {
      step *= 2;
    }

    final lon0 = (west / step).floorToDouble() * step;
    final lat0 = (south / step).floorToDouble() * step;

    final out = <List<LatLng>>[];

    for (var lon = lon0; lon <= east + 1e-9; lon += step) {
      if (lon < west - 1e-9 || lon > east + 1e-9) continue;
      out.add([LatLng(south, lon), LatLng(north, lon)]);
    }

    for (var lat = lat0; lat <= north + 1e-9; lat += step) {
      if (lat < south - 1e-9 || lat > north + 1e-9) continue;
      out.add([LatLng(lat, west), LatLng(lat, east)]);
    }

    return out;
  }

  /// WGS 84 / UTM **kuzey** ([utmZone] 1–60). Güney yarıkürede çizim yapılmaz.
  static List<List<LatLng>> utmNorthLineSegments({
    required double south,
    required double north,
    required double west,
    required double east,
    required double zoom,
    required int utmZone,
  }) {
    if (utmZone < 1 || utmZone > 60 || north <= south || east < west) {
      return const [];
    }
    if (north <= 0) return const [];

    var step = _utmStepMeters(zoom);
    final env = _utmEnvelope(south: south, north: north, west: west, east: east, zone: utmZone);
    final eMin = env.$1;
    final eMax = env.$2;
    final nMin = env.$3;
    final nMax = env.$4;

    final eSpan = eMax - eMin;
    final nSpan = nMax - nMin;
    if (eSpan <= 0 || nSpan <= 0) return const [];

    while (eSpan / step > _maxLinesPerAxis + 1) {
      step *= 2;
    }
    while (nSpan / step > _maxLinesPerAxis + 1) {
      step *= 2;
    }

    final e0 = (eMin / step).floorToDouble() * step;
    final n0 = (nMin / step).floorToDouble() * step;

    final out = <List<LatLng>>[];

    for (var e = e0; e <= eMax + 1e-6; e += step) {
      if (e < eMin - 1e-6) continue;
      final seg = _utmMeridianNorth(e, nMin, nMax, utmZone);
      if (seg.length >= 2) out.add(seg);
    }

    for (var n = n0; n <= nMax + 1e-6; n += step) {
      if (n < nMin - 1e-6) continue;
      final seg = _utmParallelNorth(n, eMin, eMax, utmZone);
      if (seg.length >= 2) out.add(seg);
    }

    return out;
  }

  /// Döndürür: (eMin, eMax, nMin, nMax).
  static (double, double, double, double) _utmEnvelope({
    required double south,
    required double north,
    required double west,
    required double east,
    required int zone,
  }) {
    double? eMin;
    double? eMax;
    double? nMin;
    double? nMax;

    void acc(LatLng p) {
      try {
        final xy = Wgs84UtmNorth.toUtm(p, zone);
        final e = xy.$1;
        final n = xy.$2;
        if (e.isNaN || n.isNaN) return;
        eMin = eMin == null ? e : math.min(eMin!, e);
        eMax = eMax == null ? e : math.max(eMax!, e);
        nMin = nMin == null ? n : math.min(nMin!, n);
        nMax = nMax == null ? n : math.max(nMax!, n);
      } catch (_) {}
    }

    final midLat = (south + north) / 2;
    final midLon = (west + east) / 2;
    for (final p in <LatLng>[
      LatLng(south, west),
      LatLng(south, east),
      LatLng(north, west),
      LatLng(north, east),
      LatLng(midLat, west),
      LatLng(midLat, east),
      LatLng(south, midLon),
      LatLng(north, midLon),
    ]) {
      acc(p);
    }

    if (eMin == null || eMax == null || nMin == null || nMax == null) {
      return (0, 0, 0, 0);
    }

    const pad = 1.08;
    final cx = (eMin! + eMax!) / 2;
    final cy = (nMin! + nMax!) / 2;
    var halfW = (eMax! - eMin!) * pad / 2;
    var halfH = (nMax! - nMin!) * pad / 2;
    if (halfW < 500) halfW = 500;
    if (halfH < 500) halfH = 500;

    return (cx - halfW, cx + halfW, cy - halfH, cy + halfH);
  }

  static List<LatLng> _utmMeridianNorth(
    double easting,
    double nLo,
    double nHi,
    int zone,
  ) {
    final pts = <LatLng>[];
    for (var i = 0; i <= _utmCurveSegments; i++) {
      final t = i / _utmCurveSegments;
      final n = nLo + (nHi - nLo) * t;
      try {
        pts.add(Wgs84UtmNorth.fromUtm(easting: easting, northing: n, zone: zone));
      } catch (_) {}
    }
    return pts;
  }

  static List<LatLng> _utmParallelNorth(
    double northing,
    double eLo,
    double eHi,
    int zone,
  ) {
    final pts = <LatLng>[];
    for (var i = 0; i <= _utmCurveSegments; i++) {
      final t = i / _utmCurveSegments;
      final e = eLo + (eHi - eLo) * t;
      try {
        pts.add(Wgs84UtmNorth.fromUtm(easting: e, northing: northing, zone: zone));
      } catch (_) {}
    }
    return pts;
  }
}
