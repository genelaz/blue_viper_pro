import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_tile/vector_tile.dart';

import 'mbtiles_mvt_codec.dart';
import 'mbtiles_raw_tile_reader.dart';

/// Dokunma / sorgu ile seçilen MVT öğesi özeti.
class MbtilesVectorPickResult {
  MbtilesVectorPickResult({
    required this.layerName,
    required this.featureId,
    required this.matchKind,
    required this.distanceMeters,
    required this.properties,
  });

  final String layerName;
  final String featureId;
  /// `alan` | `nokta` | `cizgi`
  final String matchKind;
  final double distanceMeters;
  final Map<String, String> properties;

  String get matchKindLabel {
    switch (matchKind) {
      case 'alan':
        return 'Alan (poligon)';
      case 'nokta':
        return 'Nokta';
      case 'cizgi':
        return 'Çizgi';
      default:
        return matchKind;
    }
  }
}

class MbtilesVectorPick {
  MbtilesVectorPick._();

  static int _lonToTileX(double lon, int z) {
    final n = 1 << z;
    var x = ((lon + 180.0) / 360.0 * n).floor();
    if (x < 0) x = 0;
    if (x > n - 1) x = n - 1;
    return x;
  }

  static int _latToTileY(double lat, int z) {
    final n = 1 << z;
    final latRad = lat * math.pi / 180;
    final y = ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n).floor();
    return y.clamp(0, n - 1);
  }

  static String? _valueToString(VectorTileValue v) {
    final s = v.dartStringValue;
    if (s != null) {
      final t = s.trim();
      if (t.isNotEmpty) return t;
    }
    final n = v.dartIntValue;
    if (n != null) return n.toString();
    final d = v.dartDoubleValue;
    if (d != null && !d.isNaN) {
      return d == d.roundToDouble() ? d.round().toString() : d.toStringAsFixed(4);
    }
    if (v.dartBoolValue == true) return 'yes';
    if (v.dartBoolValue == false) return 'no';
    return null;
  }

  static Map<String, String> _propsToStrings(Map<String, VectorTileValue>? p) {
    if (p == null || p.isEmpty) return const {};
    final keys = p.keys.toList()..sort();
    final out = <String, String>{};
    for (final k in keys) {
      final raw = _valueToString(p[k]!);
      if (raw == null || raw.isEmpty) continue;
      var s = raw;
      if (s.length > 200) s = '${s.substring(0, 199)}…';
      out[k] = s;
    }
    if (out.length > 48) {
      return Map.fromEntries(out.entries.take(48));
    }
    return out;
  }

  static bool _pointInRing(LatLng p, List<LatLng> ring) {
    if (ring.length < 3) return false;
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final yi = ring[i].latitude;
      final yj = ring[j].latitude;
      final xi = ring[i].longitude;
      final xj = ring[j].longitude;
      final intersect =
          ((yi > p.latitude) != (yj > p.latitude)) && (p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  static bool _pointInPolygonWithHoles(LatLng p, List<LatLng> outer, List<List<LatLng>> holes) {
    if (!_pointInRing(p, outer)) return false;
    for (final h in holes) {
      if (h.length >= 3 && _pointInRing(p, h)) return false;
    }
    return true;
  }

  static List<LatLng> _ringToLatLngs(List<List<double>> ring) {
    return [
      for (final q in ring)
        if (q.length >= 2) LatLng(q[1], q[0]),
    ];
  }

  static double _pointToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    if ((a.latitude - b.latitude).abs() < 1e-12 && (a.longitude - b.longitude).abs() < 1e-12) {
      return Geolocator.distanceBetween(p.latitude, p.longitude, a.latitude, a.longitude);
    }
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final px = p.longitude - a.longitude;
    final py = p.latitude - a.latitude;
    final len2 = dx * dx + dy * dy;
    var t = (px * dx + py * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final clat = a.latitude + t * dy;
    final clon = a.longitude + t * dx;
    return Geolocator.distanceBetween(p.latitude, p.longitude, clat, clon);
  }

  static double _minDistanceToLineStringMeters(LatLng p, List<List<double>> coords) {
    if (coords.length < 2) return 1e12;
    final pts = _ringToLatLngs(coords);
    if (pts.length < 2) return 1e12;
    var best = 1e12;
    for (var i = 0; i < pts.length - 1; i++) {
      final d = _pointToSegmentMeters(p, pts[i], pts[i + 1]);
      if (d < best) best = d;
    }
    return best;
  }

  static double _linePickThresholdM(int z) => 28.0 + z * 2.8;

  static double _pointPickThresholdM(int z) => 22.0 + z * 2.2;

  static String _featureIdStr(VectorTileFeature feature) {
    final s = feature.id.toString();
    return s == '0' ? '' : s;
  }

  /// [zoom] ile çözünür karoda ve komşu karolarda (3×3) en iyi eşleşmeler; en fazla [maxHits].
  static List<MbtilesVectorPickResult> pickAt({
    required MbtilesRawTileReader reader,
    required LatLng point,
    required int zoom,
    int maxHits = 10,
  }) {
    if (maxHits <= 0) return const [];
    final cx = _lonToTileX(point.longitude, zoom);
    final cy = _latToTileY(point.latitude, zoom);
    final lineTol = _linePickThresholdM(zoom);
    final pointTol = _pointPickThresholdM(zoom);
    final candidates = <MbtilesVectorPickResult>[];
    final seen = <String>{};

    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final tx = cx + dx;
        final ty = cy + dy;
        final blob = reader.readTileXyz(zoom, tx, ty);
        if (blob == null) continue;
        final VectorTile vt;
        try {
          vt = MbtilesMvtCodec.decodeVectorTileFromTileBlob(blob);
        } catch (_) {
          continue;
        }
        for (final layer in vt.layers) {
          final ts = layer.extent * (1 << zoom);
          final x0 = layer.extent * tx;
          final y0 = layer.extent * ty;
          for (final feature in layer.features) {
            final fj = feature.toGeoJsonWithExtentCalculated(x0: x0, y0: y0, size: ts);
            if (fj == null) continue;
            final g = fj.geometry;
            if (g == null) continue;
            final idStr = _featureIdStr(feature);
            final keyBase = '${layer.name}\x00$idStr';
            switch (g.type) {
              case GeometryType.Polygon:
                final poly = g as GeometryPolygon;
                final rings = poly.coordinates;
                if (rings.isEmpty) break;
                final outer = _ringToLatLngs(rings.first);
                if (outer.length < 3) break;
                final holes = <List<LatLng>>[
                  for (var i = 1; i < rings.length; i++)
                    if (_ringToLatLngs(rings[i]).length >= 3) _ringToLatLngs(rings[i]),
                ];
                if (_pointInPolygonWithHoles(point, outer, holes)) {
                  final k = '$keyBase\x00alan';
                  if (seen.add(k)) {
                    candidates.add(
                      MbtilesVectorPickResult(
                        layerName: layer.name,
                        featureId: idStr,
                        matchKind: 'alan',
                        distanceMeters: 0,
                        properties: _propsToStrings(fj.properties),
                      ),
                    );
                  }
                }
                break;
              case GeometryType.MultiPolygon:
                final mp = g as GeometryMultiPolygon;
                for (final polyRings in mp.coordinates ?? const <List<List<List<double>>>>[]) {
                  if (polyRings.isEmpty) continue;
                  final outer = _ringToLatLngs(polyRings.first);
                  if (outer.length < 3) continue;
                  final holes = <List<LatLng>>[
                    for (var i = 1; i < polyRings.length; i++)
                      if (_ringToLatLngs(polyRings[i]).length >= 3) _ringToLatLngs(polyRings[i]),
                  ];
                  if (_pointInPolygonWithHoles(point, outer, holes)) {
                    final k = '$keyBase\x00alan';
                    if (seen.add(k)) {
                      candidates.add(
                        MbtilesVectorPickResult(
                          layerName: layer.name,
                          featureId: idStr,
                          matchKind: 'alan',
                          distanceMeters: 0,
                          properties: _propsToStrings(fj.properties),
                        ),
                      );
                    }
                    break;
                  }
                }
                break;
              case GeometryType.Point:
                final c = (g as GeometryPoint).coordinates;
                if (c.length < 2) break;
                final q = LatLng(c[1], c[0]);
                final d = Geolocator.distanceBetween(point.latitude, point.longitude, q.latitude, q.longitude);
                if (d <= pointTol) {
                  if (seen.add('$keyBase\x00nokta')) {
                    candidates.add(
                      MbtilesVectorPickResult(
                        layerName: layer.name,
                        featureId: idStr,
                        matchKind: 'nokta',
                        distanceMeters: d,
                        properties: _propsToStrings(fj.properties),
                      ),
                    );
                  }
                }
                break;
              case GeometryType.MultiPoint:
                final pts = (g as GeometryMultiPoint).coordinates;
                var best = 1e12;
                for (final pair in pts) {
                  if (pair.length < 2) continue;
                  final q = LatLng(pair[1], pair[0]);
                  final d = Geolocator.distanceBetween(point.latitude, point.longitude, q.latitude, q.longitude);
                  if (d < best) best = d;
                }
                if (best <= pointTol && best < 1e11) {
                  if (seen.add('$keyBase\x00nokta')) {
                    candidates.add(
                      MbtilesVectorPickResult(
                        layerName: layer.name,
                        featureId: idStr,
                        matchKind: 'nokta',
                        distanceMeters: best,
                        properties: _propsToStrings(fj.properties),
                      ),
                    );
                  }
                }
                break;
              case GeometryType.LineString:
                final d = _minDistanceToLineStringMeters(point, (g as GeometryLineString).coordinates);
                if (d <= lineTol) {
                  if (seen.add('$keyBase\x00cizgi')) {
                    candidates.add(
                      MbtilesVectorPickResult(
                        layerName: layer.name,
                        featureId: idStr,
                        matchKind: 'cizgi',
                        distanceMeters: d,
                        properties: _propsToStrings(fj.properties),
                      ),
                    );
                  }
                }
                break;
              case GeometryType.MultiLineString:
                var best = 1e12;
                for (final line in (g as GeometryMultiLineString).coordinates) {
                  final d = _minDistanceToLineStringMeters(point, line);
                  if (d < best) best = d;
                }
                if (best <= lineTol && best < 1e11) {
                  if (seen.add('$keyBase\x00cizgi')) {
                    candidates.add(
                      MbtilesVectorPickResult(
                        layerName: layer.name,
                        featureId: idStr,
                        matchKind: 'cizgi',
                        distanceMeters: best,
                        properties: _propsToStrings(fj.properties),
                      ),
                    );
                  }
                }
                break;
              case null:
                break;
            }
          }
        }
      }
    }

    int sortRank(MbtilesVectorPickResult r) {
      if (r.matchKind == 'alan' && r.distanceMeters == 0) return 0;
      if (r.matchKind == 'nokta') return 1;
      if (r.matchKind == 'cizgi') return 2;
      return 3;
    }

    candidates.sort((a, b) {
      final ra = sortRank(a);
      final rb = sortRank(b);
      if (ra != rb) return ra.compareTo(rb);
      return a.distanceMeters.compareTo(b.distanceMeters);
    });
    if (candidates.length <= maxHits) return candidates;
    return candidates.sublist(0, maxHits);
  }
}
