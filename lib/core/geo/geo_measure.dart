import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Küre üzerinde basit poligon alanı (WGS84 yaklaşık; AlpinQuest tarzı ölçüm).
double sphericalPolygonAreaM2(List<LatLng> ring) {
  if (ring.length < 3) return 0;
  const r = 6378137.0;
  var area = 0.0;
  final n = ring.length;
  for (var i = 0; i < n; i++) {
    final p1 = ring[i];
    final p2 = ring[(i + 1) % n];
    final lat1 = p1.latitude * math.pi / 180;
    final lat2 = p2.latitude * math.pi / 180;
    final lon1 = p1.longitude * math.pi / 180;
    final lon2 = p2.longitude * math.pi / 180;
    area += (lon2 - lon1) * (2 + math.sin(lat1) + math.sin(lat2));
  }
  return (area.abs() * r * r / 2);
}

/// Çizgi boyunca örnek noktalar (DEM profili için).
List<LatLng> samplePolyline(List<LatLng> vertices, {double stepMeters = 120}) {
  if (vertices.length < 2) return List<LatLng>.from(vertices);
  final out = <LatLng>[vertices.first];
  for (var i = 0; i < vertices.length - 1; i++) {
    final a = vertices[i];
    final b = vertices[i + 1];
    final dist = Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    if (dist < 1) continue;
    final nSeg = math.max(1, (dist / stepMeters).ceil());
    for (var s = 1; s <= nSeg; s++) {
      final t = s / nSeg;
      final lat = a.latitude + (b.latitude - a.latitude) * t;
      final lon = a.longitude + (b.longitude - a.longitude) * t;
      out.add(LatLng(lat, lon));
    }
  }
  return out;
}
