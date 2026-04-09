import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';
import 'package:vector_tile/vector_tile.dart';

import 'mbtiles_mvt_codec.dart';
import 'mbtiles_raw_tile_reader.dart';

/// Tek MVT poligonu: dış halka + isteğe bağlı delikler (WGS84).
class MbtilesVectorPolygonPatch {
  MbtilesVectorPolygonPatch({required this.outer, List<List<LatLng>>? holes})
      : holes = holes ?? const [];

  final List<LatLng> outer;
  final List<List<LatLng>> holes;
}

/// MVT özelliklerinden türetilen basit harita etiketi (MapLibre yazı stili değil).
class MbtilesVectorMapLabel {
  MbtilesVectorMapLabel({required this.point, required this.text});

  final LatLng point;
  final String text;
}

/// Çizgi parçaları + dolu poligonlar + noktalar (önizleme; MapLibre stili değil).
class MbtilesVectorOverlayData {
  MbtilesVectorOverlayData({
    required this.lineSegments,
    required this.polygonPatches,
    required this.points,
    required this.labels,
  });

  final List<List<LatLng>> lineSegments;
  final List<MbtilesVectorPolygonPatch> polygonPatches;
  /// MVT Point / MultiPoint merkezleri (WGS84).
  final List<LatLng> points;
  /// `name` / `ref` vb. alanlardan; en fazla [MbtilesVectorOverlayBuilder.overlayForBounds] `maxLabels`.
  final List<MbtilesVectorMapLabel> labels;
}

/// Görünür alan için MVT karolarından WGS84 geometrileri (önizleme; tam stil değil).
class MbtilesVectorOverlayBuilder {
  MbtilesVectorOverlayBuilder._();

  /// Önizlemede çok sayıda nokta katmanını sınırlamak için.
  static const int maxOverlayPoints = 3072;

  static const int _kMaxLabelChars = 44;

  static const List<String> _kLabelPropertyKeys = [
    'name',
    'name:en',
    'name:latin',
    'name:de',
    'int_name',
    'loc_name',
    'ref',
    'shield_text',
  ];

  static String? _displayStringFromValue(VectorTileValue v) {
    final s = v.dartStringValue;
    if (s != null) {
      final t = s.trim();
      if (t.isNotEmpty) return t;
    }
    final n = v.dartIntValue;
    if (n != null) return n.toString();
    final d = v.dartDoubleValue;
    if (d != null && !d.isNaN) {
      return d == d.roundToDouble() ? d.round().toString() : d.toStringAsFixed(2);
    }
    return null;
  }

  /// Yaklaşık 50–60 m hücre + metin ile aynı yerde tekrarlayan etiketleri azaltır.
  static String _labelDedupeKey(LatLng p, String text) {
    final gx = (p.latitude * 2000).round();
    final gy = (p.longitude * 2000).round();
    return '$gx:$gy:$text';
  }

  /// OpenMapTiles benzeri katman adlarına göre kotada tutulacak öncelik (yüksek = kalır).
  static int _labelPriorityForLayer(String layerName) {
    final n = layerName.toLowerCase();
    if (n == 'place' || n.startsWith('place_')) return 100;
    if (n.contains('poi')) return 88;
    if (n.contains('transportation') && n.contains('name')) return 82;
    if (n.contains('water') && n.contains('name')) return 74;
    if (n.contains('mountain') || n.contains('peak')) return 68;
    if (n.contains('aeroway') && n.contains('name')) return 62;
    if (n.contains('park')) return 58;
    if (n.contains('admin') && n.contains('name')) return 48;
    if (n.contains('housenumber')) return 36;
    if (n.contains('building')) return 30;
    if (n.contains('boundary')) return 12;
    return 42;
  }

  @visibleForTesting
  static int labelPriorityForLayerTest(String layerName) => _labelPriorityForLayer(layerName);

  @visibleForTesting
  static String labelDedupeKeyTest(LatLng p, String text) => _labelDedupeKey(p, text);

  /// Uzak zoom’da etiket yoğunluğunu azaltır ([userMax] tavanına göre).
  static int effectiveLabelBudget({
    required int zoom,
    required int userMax,
    required bool scaleByZoom,
  }) {
    if (userMax <= 0) return 0;
    if (!scaleByZoom) return userMax;
    final t = (zoom.clamp(8, 20) - 8) / 12.0;
    return (userMax * (0.12 + 0.88 * t)).round().clamp(1, userMax);
  }

  @visibleForTesting
  static int effectiveLabelBudgetTest({
    required int zoom,
    required int userMax,
    required bool scaleByZoom,
  }) =>
      effectiveLabelBudget(zoom: zoom, userMax: userMax, scaleByZoom: scaleByZoom);

  static String? _labelTextFromProperties(Map<String, VectorTileValue>? props) {
    if (props == null || props.isEmpty) return null;
    for (final k in _kLabelPropertyKeys) {
      final v = props[k];
      if (v == null) continue;
      final raw = _displayStringFromValue(v);
      if (raw == null || raw.isEmpty) continue;
      if (raw.length > _kMaxLabelChars) {
        return '${raw.substring(0, _kMaxLabelChars - 1)}…';
      }
      return raw;
    }
    return null;
  }

  static LatLng? _centroidRing(List<LatLng> ring) {
    if (ring.isEmpty) return null;
    var lat = 0.0;
    var lng = 0.0;
    for (final p in ring) {
      lat += p.latitude;
      lng += p.longitude;
    }
    final n = ring.length;
    return LatLng(lat / n, lng / n);
  }

  static LatLng? _anchorForGeometry(Geometry geom) {
    switch (geom.type) {
      case GeometryType.Point:
        final c = (geom as GeometryPoint).coordinates;
        if (c.length < 2) return null;
        return LatLng(c[1], c[0]);
      case GeometryType.MultiPoint:
        final pts = (geom as GeometryMultiPoint).coordinates;
        if (pts.isEmpty || pts.first.length < 2) return null;
        final p = pts.first;
        return LatLng(p[1], p[0]);
      case GeometryType.LineString:
        final coords = (geom as GeometryLineString).coordinates;
        if (coords.isEmpty) return null;
        final mid = coords[coords.length ~/ 2];
        if (mid.length < 2) return null;
        return LatLng(mid[1], mid[0]);
      case GeometryType.MultiLineString:
        final lines = (geom as GeometryMultiLineString).coordinates;
        if (lines.isEmpty || lines.first.isEmpty) return null;
        final line = lines.first;
        final mid = line[line.length ~/ 2];
        if (mid.length < 2) return null;
        return LatLng(mid[1], mid[0]);
      case GeometryType.Polygon:
        final rings = (geom as GeometryPolygon).coordinates;
        if (rings.isEmpty) return null;
        return _centroidRing(_ringToLatLngs(rings.first));
      case GeometryType.MultiPolygon:
        final mp = (geom as GeometryMultiPolygon).coordinates;
        if (mp == null || mp.isEmpty || mp.first.isEmpty) return null;
        return _centroidRing(_ringToLatLngs(mp.first.first));
      case null:
        return null;
    }
  }

  static void _offerRankedMapLabel(
    List<({int priority, MbtilesVectorMapLabel label})> bucket,
    Set<String> dedupe,
    int maxLabels,
    Map<String, VectorTileValue>? props,
    Geometry geom,
    String layerName,
  ) {
    if (maxLabels <= 0) return;
    final text = _labelTextFromProperties(props);
    if (text == null) return;
    final anchor = _anchorForGeometry(geom);
    if (anchor == null) return;
    final key = _labelDedupeKey(anchor, text);
    if (dedupe.contains(key)) return;
    final priority = _labelPriorityForLayer(layerName);
    final cand = MbtilesVectorMapLabel(point: anchor, text: text);
    if (bucket.length < maxLabels) {
      bucket.add((priority: priority, label: cand));
      dedupe.add(key);
      return;
    }
    var minI = 0;
    var minP = bucket[0].priority;
    for (var i = 1; i < bucket.length; i++) {
      if (bucket[i].priority < minP) {
        minP = bucket[i].priority;
        minI = i;
      }
    }
    if (priority > minP) {
      final old = bucket[minI].label;
      dedupe.remove(_labelDedupeKey(old.point, old.text));
      bucket[minI] = (priority: priority, label: cand);
      dedupe.add(key);
    }
  }

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

  static Iterable<(int x, int y)> _tilesCoveringBounds({
    required double south,
    required double north,
    required double west,
    required double east,
    required int z,
  }) sync* {
    var x0 = _lonToTileX(west, z);
    var x1 = _lonToTileX(east, z);
    var y0 = _latToTileY(north, z);
    var y1 = _latToTileY(south, z);
    if (x0 > x1) {
      final t = x0;
      x0 = x1;
      x1 = t;
    }
    if (y0 > y1) {
      final t = y0;
      y0 = y1;
      y1 = t;
    }
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        yield (x, y);
      }
    }
  }

  static List<LatLng> _ringToLatLngs(List<List<double>> ring) {
    return [
      for (final p in ring)
        if (p.length >= 2) LatLng(p[1], p[0]),
    ];
  }

  static void _addLineString(List<List<LatLng>> polylines, List<List<double>> coords) {
    if (coords.length < 2) return;
    polylines.add(_ringToLatLngs(coords));
  }

  static void _collectFromGeometry(
    Geometry geom,
    List<List<LatLng>> lineSegments,
    List<MbtilesVectorPolygonPatch> polygons,
    List<LatLng> points,
  ) {
    switch (geom.type) {
      case GeometryType.Point:
        if (points.length >= maxOverlayPoints) break;
        final c = (geom as GeometryPoint).coordinates;
        if (c.length >= 2) points.add(LatLng(c[1], c[0]));
        break;
      case GeometryType.MultiPoint:
        for (final p in (geom as GeometryMultiPoint).coordinates) {
          if (points.length >= maxOverlayPoints) break;
          if (p.length >= 2) points.add(LatLng(p[1], p[0]));
        }
        break;
      case GeometryType.LineString:
        _addLineString(lineSegments, (geom as GeometryLineString).coordinates);
        break;
      case GeometryType.MultiLineString:
        for (final line in (geom as GeometryMultiLineString).coordinates) {
          _addLineString(lineSegments, line);
        }
        break;
      case GeometryType.Polygon:
        final poly = geom as GeometryPolygon;
        final rings = poly.coordinates;
        if (rings.isEmpty) break;
        final outer = _ringToLatLngs(rings.first);
        if (outer.length >= 3) {
          final holes = <List<LatLng>>[
            for (var i = 1; i < rings.length; i++)
              if (_ringToLatLngs(rings[i]).length >= 3) _ringToLatLngs(rings[i]),
          ];
          polygons.add(MbtilesVectorPolygonPatch(outer: outer, holes: holes));
        }
        break;
      case GeometryType.MultiPolygon:
        final mp = geom as GeometryMultiPolygon;
        for (final polyRings in mp.coordinates ?? const <List<List<List<double>>>>[]) {
          if (polyRings.isEmpty) continue;
          final outer = _ringToLatLngs(polyRings.first);
          if (outer.length < 3) continue;
          final holes = <List<LatLng>>[
            for (var i = 1; i < polyRings.length; i++)
              if (_ringToLatLngs(polyRings[i]).length >= 3) _ringToLatLngs(polyRings[i]),
          ];
          polygons.add(MbtilesVectorPolygonPatch(outer: outer, holes: holes));
        }
        break;
      case null:
        break;
    }
  }

  static MbtilesVectorOverlayData overlayForBounds({
    required MbtilesRawTileReader reader,
    required double south,
    required double north,
    required double west,
    required double east,
    required int zoom,
    int maxTiles = 28,
    int maxLabels = 32,
  }) {
    final lineSegments = <List<LatLng>>[];
    final polygonPatches = <MbtilesVectorPolygonPatch>[];
    final points = <LatLng>[];
    final labelBucket = <({int priority, MbtilesVectorMapLabel label})>[];
    final labelDedupe = <String>{};
    var used = 0;
    for (final t in _tilesCoveringBounds(
      south: south,
      north: north,
      west: west,
      east: east,
      z: zoom,
    )) {
      if (used >= maxTiles) break;
      final blob = reader.readTileXyz(zoom, t.$1, t.$2);
      if (blob == null) continue;
      final VectorTile vt;
      try {
        vt = MbtilesMvtCodec.decodeVectorTileFromTileBlob(blob);
      } catch (_) {
        continue;
      }
      final tx = t.$1;
      final ty = t.$2;
      for (final layer in vt.layers) {
        final tileSize = layer.extent * (1 << zoom);
        final x0 = layer.extent * tx;
        final y0 = layer.extent * ty;
        for (final feature in layer.features) {
          final fj = feature.toGeoJsonWithExtentCalculated(x0: x0, y0: y0, size: tileSize);
          if (fj == null) continue;
          final g = fj.geometry;
          if (g == null) continue;
          _collectFromGeometry(g, lineSegments, polygonPatches, points);
          _offerRankedMapLabel(labelBucket, labelDedupe, maxLabels, fj.properties, g, layer.name);
        }
      }
      used++;
    }
    labelBucket.sort((a, b) => b.priority.compareTo(a.priority));
    final labels = [for (final e in labelBucket) e.label];
    return MbtilesVectorOverlayData(
      lineSegments: lineSegments,
      polygonPatches: polygonPatches,
      points: points,
      labels: labels,
    );
  }
}
