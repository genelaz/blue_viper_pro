import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

/// GPX 1.1 üret (waypoint, rota, iz).
String buildGpxDocument({
  required String name,
  List<(String name, LatLng p)> waypoints = const [],
  List<LatLng>? routePoints,
  List<LatLng>? trackPoints,
  String? trackName,
}) {
  String esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  final buf = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="Blue Viper Pro" xmlns="http://www.topografix.com/GPX/1/1">')
    ..writeln('  <metadata><name>${esc(name)}</name></metadata>');
  for (final (nm, p) in waypoints) {
    buf.writeln(
      '  <wpt lat="${p.latitude}" lon="${p.longitude}"><name>${esc(nm)}</name></wpt>',
    );
  }
  if (routePoints != null && routePoints.length >= 2) {
    buf.writeln('  <rte><name>${esc('$name — rota')}</name>');
    for (final p in routePoints) {
      buf.writeln('    <rtept lat="${p.latitude}" lon="${p.longitude}"/>');
    }
    buf.writeln('  </rte>');
  }
  if (trackPoints != null && trackPoints.length >= 2) {
    buf.writeln('  <trk><name>${esc(trackName ?? '$name — iz')}</name><trkseg>');
    for (final p in trackPoints) {
      buf.writeln('      <trkpt lat="${p.latitude}" lon="${p.longitude}"/>');
    }
    buf.writeln('    </trkseg></trk>');
  }
  buf.writeln('</gpx>');
  return buf.toString();
}

/// GPX ayrıştır: waypointler ve iz segmentleri.
({List<(String name, LatLng p)> wpts, List<List<LatLng>> tracks, List<List<LatLng>> routes}) parseGpx(
  String xmlStr,
) {
  final doc = XmlDocument.parse(xmlStr);
  final wpts = <(String, LatLng)>[];
  for (final el in doc.findAllElements('wpt')) {
    final la = double.tryParse(el.getAttribute('lat') ?? '');
    final lo = double.tryParse(el.getAttribute('lon') ?? '');
    if (la == null || lo == null) continue;
    final ne = el.findElements('name');
    final n = ne.isEmpty ? 'WPT' : ne.first.innerText.trim();
    wpts.add((n, LatLng(la, lo)));
  }
  final tracks = <List<LatLng>>[];
  for (final trk in doc.findAllElements('trk')) {
    for (final seg in trk.findAllElements('trkseg')) {
      final pts = <LatLng>[];
      for (final pt in seg.findAllElements('trkpt')) {
        final la = double.tryParse(pt.getAttribute('lat') ?? '');
        final lo = double.tryParse(pt.getAttribute('lon') ?? '');
        if (la != null && lo != null) pts.add(LatLng(la, lo));
      }
      if (pts.length >= 2) tracks.add(pts);
    }
  }
  final routes = <List<LatLng>>[];
  for (final rte in doc.findAllElements('rte')) {
    final pts = <LatLng>[];
    for (final pt in rte.findAllElements('rtept')) {
      final la = double.tryParse(pt.getAttribute('lat') ?? '');
      final lo = double.tryParse(pt.getAttribute('lon') ?? '');
      if (la != null && lo != null) pts.add(LatLng(la, lo));
    }
    if (pts.length >= 2) routes.add(pts);
  }
  return (wpts: wpts, tracks: tracks, routes: routes);
}

/// KMZ: zip içinden ilk .kml dosyasını UTF-8 metin olarak döndürür.
String? decodeKmzToKmlString(List<int> bytes) {
  final arch = ZipDecoder().decodeBytes(bytes);
  for (final f in arch.files) {
    if (f.isFile && f.name.toLowerCase().endsWith('.kml')) {
      return String.fromCharCodes(f.content as List<int>);
    }
  }
  return null;
}

/// KML: Point ve LineString/LinearRing koordinatları (basit).
({List<(String name, LatLng p)> points, List<List<LatLng>> lines}) parseKmlPlacemarks(String kml) {
  final doc = XmlDocument.parse(kml);
  final points = <(String, LatLng)>[];
  final lines = <List<LatLng>>[];

  void visitPlacemark(XmlElement pm) {
    final nmEl = pm.findElements('name');
    final name = nmEl.isEmpty ? 'PM' : nmEl.first.innerText.trim();
    final pointEl = pm.findElements('Point');
    final point = pointEl.isEmpty ? null : pointEl.first;
    if (point != null) {
      final ce = point.findElements('coordinates');
      final coord = ce.isEmpty ? '' : ce.first.innerText;
      final p = _parseCoordTriplet(coord);
      if (p != null) points.add((name, p));
    }
    for (final tag in ['LineString', 'LinearRing']) {
      final lsEl = pm.findElements(tag);
      if (lsEl.isEmpty) continue;
      final ls = lsEl.first;
      {
        final ce = ls.findElements('coordinates');
        final coord = ce.isEmpty ? '' : ce.first.innerText;
        final pts = _parseCoordLine(coord);
        if (pts.length >= 2) lines.add(pts);
      }
    }
    final mgEl = pm.findElements('MultiGeometry');
    final multiGeom = mgEl.isEmpty ? null : mgEl.first;
    if (multiGeom != null) {
      for (final c in multiGeom.childElements) {
        if (c.name.local == 'Point') {
          final ce = c.findElements('coordinates');
          final coord = ce.isEmpty ? '' : ce.first.innerText;
          final p = _parseCoordTriplet(coord);
          if (p != null) points.add((name, p));
        } else if (c.name.local == 'LineString' || c.name.local == 'LinearRing') {
          final ce = c.findElements('coordinates');
          final coord = ce.isEmpty ? '' : ce.first.innerText;
          final pts = _parseCoordLine(coord);
          if (pts.length >= 2) lines.add(pts);
        }
      }
    }
  }

  for (final pm in doc.findAllElements('Placemark')) {
    visitPlacemark(pm);
  }
  return (points: points, lines: lines);
}

LatLng? _parseCoordTriplet(String raw) {
  final parts = raw.trim().split(RegExp(r'[\s,]+')).where((e) => e.isNotEmpty).toList();
  if (parts.length < 2) return null;
  final lon = double.tryParse(parts[0].replaceAll(',', '.'));
  final lat = double.tryParse(parts[1].replaceAll(',', '.'));
  if (lat == null || lon == null) return null;
  return LatLng(lat, lon);
}

List<LatLng> _parseCoordLine(String raw) {
  final pts = <LatLng>[];
  for (final tup in raw.trim().split(RegExp(r'\s+'))) {
    if (tup.isEmpty) continue;
    final p = _parseCoordTriplet(tup);
    if (p != null) pts.add(p);
  }
  return pts;
}
