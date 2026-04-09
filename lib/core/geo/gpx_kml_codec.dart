import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

/// KML `Polygon`: dış sınır ve isteğe bağlı `innerBoundaryIs` delikleri.
class KmlPolygonPatch {
  const KmlPolygonPatch({
    required this.outer,
    this.holes = const [],
    this.fillArgb32,
    this.strokeArgb32,
    this.strokeWidthPx,
    this.drawStrokeOutline = true,
  });

  final List<LatLng> outer;
  final List<List<LatLng>> holes;
  /// `PolyStyle` / `color` (0xAARRGGBB); yoksa haritada varsayılan teal.
  final int? fillArgb32;
  /// `LineStyle` sınır rengi; [drawStrokeOutline] false ise kullanılmaz.
  final int? strokeArgb32;
  /// `LineStyle` / `width` (KML birimleri; yaklaşık piksel).
  final double? strokeWidthPx;
  /// `PolyStyle` / `outline` ≠ 0.
  final bool drawStrokeOutline;
}

/// KML `LineStyle` / `color` (aabbggrr) → Flutter `Color` uyumu: 0xAARRGGBB.
int? kmlLineColorAabbggrrToArgb32(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  if (s.length == 6) s = 'ff$s';
  if (s.length != 8) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  final a = (v >> 24) & 0xFF;
  final b = (v >> 16) & 0xFF;
  final g = (v >> 8) & 0xFF;
  final r = v & 0xFF;
  return (a << 24) | (r << 16) | (g << 8) | b;
}

/// 0xAARRGGBB → KML `color` (aabbggrr), 8 küçük harf hex.
String kmlArgb32ToAabbggrrHex(int argb) {
  final a = (argb >> 24) & 0xFF;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  final v = (a << 24) | (b << 16) | (g << 8) | r;
  return v.toRadixString(16).padLeft(8, '0');
}

/// [buildKmlMapExport] içi `#bv_polygon` ile aynı dolgu / çizgi (içe aktarımla uyumlu).
const int _kExportBvPolygonFillArgb = 0x55009688; // KML 55889600
const int _kExportBvPolygonStrokeArgb = 0xFF009688; // KML ff889600
const double _kExportBvPolygonStrokeWidth = 2;

bool _polygonPatchUsesBuiltinStyle(KmlPolygonPatch p) {
  return p.fillArgb32 == null &&
      p.strokeArgb32 == null &&
      p.strokeWidthPx == null &&
      p.drawStrokeOutline;
}

void _writeKmlPolygonPatchStyle(StringBuffer buf, String styleId, KmlPolygonPatch p) {
  final fillArgb = p.fillArgb32 ?? _kExportBvPolygonFillArgb;
  final fillHex = kmlArgb32ToAabbggrrHex(fillArgb);
  buf.writeln('    <Style id="$styleId">');
  if (p.drawStrokeOutline) {
    final strokeArgb = p.strokeArgb32 ?? _kExportBvPolygonStrokeArgb;
    final w = p.strokeWidthPx ?? _kExportBvPolygonStrokeWidth;
    final widthStr = w == w.floorToDouble() ? '${w.toInt()}' : '$w';
    buf.writeln(
      '      <LineStyle><color>${kmlArgb32ToAabbggrrHex(strokeArgb)}</color><width>$widthStr</width></LineStyle>',
    );
  }
  buf.writeln('      <PolyStyle><color>$fillHex</color><outline>${p.drawStrokeOutline ? 1 : 0}</outline></PolyStyle>');
  buf.writeln('    </Style>');
}

/// Haritada KML içe aktarılı çizgilerde `strokeArgb` null iken kullanılan mor (varsayılan ~4 px çizgi).
const int _kExportKmlImportPolylineDefaultArgb = 0xFF673AB7;
const double _kExportKmlImportPolylineDefaultWidth = 4;

/// `#bv_route` ile aynı çizgi rengi (`ffb0279c`) ve genişlik 3.
const int _kExportBvRouteStrokeArgb = 0xFF9C27B0;
const double _kExportBvRouteStrokeWidth = 3;

void _writeKmlLineOnlyStyle(StringBuffer buf, String styleId, int strokeArgb, double width) {
  buf.writeln('    <Style id="$styleId">');
  final widthStr = width == width.floorToDouble() ? '${width.toInt()}' : '$width';
  buf.writeln(
    '      <LineStyle><color>${kmlArgb32ToAabbggrrHex(strokeArgb)}</color><width>$widthStr</width></LineStyle>',
  );
  buf.writeln('    </Style>');
}

String? _kmlStyleUrlFragment(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (t.startsWith('#')) return t.substring(1);
  if (t.contains(':')) return null;
  return t;
}

int? _lineStyleArgbFromStyleElement(XmlElement styleRoot) {
  for (final ls in styleRoot.findElements('LineStyle')) {
    for (final c in ls.findElements('color')) {
      return kmlLineColorAabbggrrToArgb32(c.innerText);
    }
  }
  return null;
}

double? _lineWidthFromStyleElement(XmlElement styleRoot) {
  for (final ls in styleRoot.findElements('LineStyle')) {
    for (final w in ls.findElements('width')) {
      final v = double.tryParse(w.innerText.trim());
      if (v != null && v > 0) return v;
    }
  }
  return null;
}

int? _polyStyleArgbFromStyleElement(XmlElement styleRoot) {
  for (final ps in styleRoot.findElements('PolyStyle')) {
    for (final c in ps.findElements('color')) {
      return kmlLineColorAabbggrrToArgb32(c.innerText);
    }
  }
  return null;
}

/// `PolyStyle` / `outline`: 0 = sınır çizme.
bool? _polyOutlineFromStyleElement(XmlElement styleRoot) {
  for (final ps in styleRoot.findElements('PolyStyle')) {
    for (final o in ps.findElements('outline')) {
      final t = o.innerText.trim();
      if (t == '0') return false;
      if (t == '1') return true;
    }
  }
  return null;
}

class _KmlVisStyle {
  _KmlVisStyle();

  int? lineArgb;
  double? lineWidth;
  int? fillArgb;
  bool? polyOutline;

  bool get hasLine => lineArgb != null;
  bool get hasFill => fillArgb != null;
  bool get hasAny => hasLine || hasFill || lineWidth != null || polyOutline != null;

  void applyStyleElement(XmlElement styleRoot) {
    final lc = _lineStyleArgbFromStyleElement(styleRoot);
    if (lc != null) lineArgb = lc;
    final lw = _lineWidthFromStyleElement(styleRoot);
    if (lw != null) lineWidth = lw;
    final fc = _polyStyleArgbFromStyleElement(styleRoot);
    if (fc != null) fillArgb = fc;
    final po = _polyOutlineFromStyleElement(styleRoot);
    if (po != null) polyOutline = po;
  }

  void mergeFrom(_KmlVisStyle o) {
    if (o.lineArgb != null) lineArgb = o.lineArgb;
    if (o.lineWidth != null) lineWidth = o.lineWidth;
    if (o.fillArgb != null) fillArgb = o.fillArgb;
    if (o.polyOutline != null) polyOutline = o.polyOutline;
  }

  void fillGapsFrom(_KmlVisStyle o) {
    lineArgb ??= o.lineArgb;
    lineWidth ??= o.lineWidth;
    fillArgb ??= o.fillArgb;
    polyOutline ??= o.polyOutline;
  }
}

/// `Style` / `StyleMap` (`normal` ve isteğe bağlı `highlight` yedek).
class _KmlStyleIndex {
  _KmlStyleIndex(XmlDocument doc) {
    for (final st in doc.findAllElements('Style')) {
      final id = st.getAttribute('id');
      if (id == null || id.isEmpty) continue;
      final acc = _KmlVisStyle();
      acc.applyStyleElement(st);
      if (acc.hasAny) byId[id] = acc;
    }
    for (final sm in doc.findAllElements('StyleMap')) {
      final id = sm.getAttribute('id');
      if (id == null || id.isEmpty) continue;
      for (final pair in sm.findElements('Pair')) {
        final keys = pair.findElements('key');
        final urls = pair.findElements('styleUrl');
        if (keys.isEmpty || urls.isEmpty) continue;
        final key = keys.first.innerText.trim();
        final frag = _kmlStyleUrlFragment(urls.first.innerText);
        if (frag == null) continue;
        if (key == 'normal') styleMapNormal[id] = frag;
        if (key == 'highlight') styleMapHighlight[id] = frag;
      }
    }
  }

  final byId = <String, _KmlVisStyle>{};
  final styleMapNormal = <String, String>{};
  final styleMapHighlight = <String, String>{};

  void _walkMerge(String startFrag, Map<String, String> sm, _KmlVisStyle into) {
    var id = startFrag;
    for (var i = 0; i < 8; i++) {
      final e = byId[id];
      if (e != null) into.mergeFrom(e);
      final next = sm[id];
      if (next == null) break;
      id = next;
    }
  }

  _KmlVisStyle _resolveStyleUrl(String? raw) {
    final frag = _kmlStyleUrlFragment(raw ?? '');
    final acc = _KmlVisStyle();
    if (frag == null) return acc;
    _walkMerge(frag, styleMapNormal, acc);
    final hi = _KmlVisStyle();
    _walkMerge(frag, styleMapHighlight, hi);
    acc.fillGapsFrom(hi);
    return acc;
  }

  _KmlVisStyle placemarkVisual(XmlElement pm) {
    final acc = _KmlVisStyle();
    final urls = pm.findElements('styleUrl');
    if (urls.isNotEmpty) {
      acc.mergeFrom(_resolveStyleUrl(urls.first.innerText));
    }
    for (final st in pm.findElements('Style')) {
      acc.applyStyleElement(st);
    }
    return acc;
  }
}

/// GPX 1.1 üret (waypoint, rota, iz, isteğe bağlı kapalı alan izleri).
///
/// Çıktı sırası: `metadata`, tüm [waypoints] (`wpt`), [routeLines] (her biri ayrı `rte`),
/// [lineTracks] (her çizgi ayrı `<trk><trkseg>`; GPX izleri / KML çizgileri), [trackPoints] GPS izi (`trk`),
/// [areaLoops] (her halka ayrı `trk`, gerekirse kapatmak için ilk nokta sonda tekrarlanır).
///
/// [lineTracks]: açık çizgiler; GPX `<trk>` veya KML `LineString` segmentleri.
/// [routeLines]: planlı rotalar (`<rte>`); GPX içe aktarımdaki `<rte>` burada korunur.
///
/// [areaLoops]: çokgen sınırları; kapalı değilse ilk nokta sonda tekrarlanır.
String buildGpxDocument({
  required String name,
  List<(String name, LatLng p)> waypoints = const [],
  List<(String routeName, List<LatLng> line)>? routeLines,
  List<(String trackName, List<LatLng> line)>? lineTracks,
  List<LatLng>? trackPoints,
  String? trackName,
  List<(String trackName, List<LatLng> ring)>? areaLoops,
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
  if (routeLines != null) {
    for (final (rteNm, rteLine) in routeLines) {
      if (rteLine.length < 2) continue;
      buf.writeln('  <rte><name>${esc(rteNm)}</name>');
      for (final p in rteLine) {
        buf.writeln('    <rtept lat="${p.latitude}" lon="${p.longitude}"/>');
      }
      buf.writeln('  </rte>');
    }
  }
  if (lineTracks != null) {
    for (final (trkNm, line) in lineTracks) {
      if (line.length < 2) continue;
      buf.writeln('  <trk><name>${esc(trkNm)}</name><trkseg>');
      for (final p in line) {
        buf.writeln('      <trkpt lat="${p.latitude}" lon="${p.longitude}"/>');
      }
      buf.writeln('    </trkseg></trk>');
    }
  }
  if (trackPoints != null && trackPoints.length >= 2) {
    buf.writeln('  <trk><name>${esc(trackName ?? '$name — iz')}</name><trkseg>');
    for (final p in trackPoints) {
      buf.writeln('      <trkpt lat="${p.latitude}" lon="${p.longitude}"/>');
    }
    buf.writeln('    </trkseg></trk>');
  }
  if (areaLoops != null) {
    for (final (trkNm, ring) in areaLoops) {
      if (ring.length < 3) continue;
      final pts = List<LatLng>.from(ring);
      final fst = pts.first;
      final lst = pts.last;
      if (fst.latitude != lst.latitude || fst.longitude != lst.longitude) {
        pts.add(fst);
      }
      buf.writeln('  <trk><name>${esc(trkNm)}</name><trkseg>');
      for (final p in pts) {
        buf.writeln('      <trkpt lat="${p.latitude}" lon="${p.longitude}"/>');
      }
      buf.writeln('    </trkseg></trk>');
    }
  }
  buf.writeln('</gpx>');
  return buf.toString();
}

String _kmlEsc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _kmlCoordLine(List<LatLng> pts, {required bool closeRing}) {
  final list = List<LatLng>.from(pts);
  if (closeRing && list.isNotEmpty) {
    final a = list.first;
    final b = list.last;
    if (a.latitude != b.latitude || a.longitude != b.longitude) {
      list.add(a);
    }
  }
  return list.map((p) => '${p.longitude},${p.latitude},0').join(' ');
}

/// KML `color`: aabbggrr (alfa, mavi, yeşil, kırmızı), Google Earth uyumu.
void _writeKmlMapStyles(StringBuffer buf) {
  buf.writeln('    <Style id="bv_wpt">');
  buf.writeln('      <IconStyle><color>ff0098ff</color><scale>1</scale></IconStyle>');
  buf.writeln('    </Style>');
  buf.writeln('    <Style id="bv_route">');
  buf.writeln('      <LineStyle><color>ffb0279c</color><width>3</width></LineStyle>');
  buf.writeln('    </Style>');
  buf.writeln('    <Style id="bv_track">');
  buf.writeln('      <LineStyle><color>ff327d2e</color><width>3</width></LineStyle>');
  buf.writeln('    </Style>');
  buf.writeln('    <Style id="bv_polygon">');
  buf.writeln('      <LineStyle><color>ff889600</color><width>2</width></LineStyle>');
  buf.writeln('      <PolyStyle><color>55889600</color></PolyStyle>');
  buf.writeln('    </Style>');
}

/// KML 2.2: `Document` altında stiller, nokta, çizgi ve kapalı alanlar (delik destekli).
///
/// [styledPolylines]: ayrı `LineString` placemark’ları (renk / genişlik). Dolu iken
/// çağıran genelde [routeLine] vermez — aynı geometrinin iki kez yazılmasını önler.
String buildKmlMapExport({
  required String documentName,
  List<(String name, LatLng p)> waypoints = const [],
  List<(String name, List<LatLng> line, int? strokeArgb, double? strokeWidthPx)>? styledPolylines,
  List<LatLng>? routeLine,
  List<LatLng>? recordedTrackLine,
  String? recordedTrackName,
  List<(String name, KmlPolygonPatch patch)>? polygons,
}) {
  final buf = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2">')
    ..writeln('  <Document>')
    ..writeln('    <name>${_kmlEsc(documentName)}</name>');
  _writeKmlMapStyles(buf);
  for (final (nm, p) in waypoints) {
    buf.writeln('    <Placemark>');
    buf.writeln('      <name>${_kmlEsc(nm)}</name>');
    buf.writeln('      <styleUrl>#bv_wpt</styleUrl>');
    buf.writeln('      <Point><coordinates>${p.longitude},${p.latitude},0</coordinates></Point>');
    buf.writeln('    </Placemark>');
  }
  var lineStyleSeq = 0;
  if (styledPolylines != null) {
    for (final (lineName, pts, strokeArgb, widthPx) in styledPolylines) {
      if (pts.length < 2) continue;
      final stroke = strokeArgb ?? _kExportKmlImportPolylineDefaultArgb;
      final w = widthPx ?? _kExportKmlImportPolylineDefaultWidth;
      final useBvRoute = stroke == _kExportBvRouteStrokeArgb && w == _kExportBvRouteStrokeWidth;
      final styleRef = useBvRoute ? 'bv_route' : 'bv_ls_$lineStyleSeq';
      if (!useBvRoute) {
        _writeKmlLineOnlyStyle(buf, styleRef, stroke, w);
        lineStyleSeq++;
      }
      buf.writeln('    <Placemark>');
      buf.writeln('      <name>${_kmlEsc(lineName)}</name>');
      buf.writeln('      <styleUrl>#$styleRef</styleUrl>');
      buf.writeln(
        '      <LineString><tessellate>1</tessellate><coordinates>${_kmlCoordLine(pts, closeRing: false)}</coordinates></LineString>',
      );
      buf.writeln('    </Placemark>');
    }
  }
  if (routeLine != null && routeLine.length >= 2) {
    buf.writeln('    <Placemark>');
    buf.writeln('      <name>${_kmlEsc('$documentName — rota')}</name>');
    buf.writeln('      <styleUrl>#bv_route</styleUrl>');
    buf.writeln(
      '      <LineString><tessellate>1</tessellate><coordinates>${_kmlCoordLine(routeLine, closeRing: false)}</coordinates></LineString>',
    );
    buf.writeln('    </Placemark>');
  }
  if (recordedTrackLine != null && recordedTrackLine.length >= 2) {
    buf.writeln('    <Placemark>');
    buf.writeln('      <name>${_kmlEsc(recordedTrackName ?? '$documentName — iz')}</name>');
    buf.writeln('      <styleUrl>#bv_track</styleUrl>');
    buf.writeln(
      '      <LineString><tessellate>1</tessellate><coordinates>${_kmlCoordLine(recordedTrackLine, closeRing: false)}</coordinates></LineString>',
    );
    buf.writeln('    </Placemark>');
  }
  if (polygons != null) {
    var patchStyleSeq = 0;
    for (final (nm, patch) in polygons) {
      if (patch.outer.length < 3) continue;
      final builtinPolyStyle = _polygonPatchUsesBuiltinStyle(patch);
      final styleRef = builtinPolyStyle ? 'bv_polygon' : 'bv_patch_$patchStyleSeq';
      if (!builtinPolyStyle) {
        _writeKmlPolygonPatchStyle(buf, styleRef, patch);
        patchStyleSeq++;
      }
      buf.writeln('    <Placemark>');
      buf.writeln('      <name>${_kmlEsc(nm)}</name>');
      buf.writeln('      <styleUrl>#$styleRef</styleUrl>');
      buf.writeln('      <Polygon>');
      buf.writeln(
        '        <outerBoundaryIs><LinearRing><coordinates>${_kmlCoordLine(patch.outer, closeRing: true)}</coordinates></LinearRing></outerBoundaryIs>',
      );
      for (final h in patch.holes) {
        if (h.length < 3) continue;
        buf.writeln(
          '        <innerBoundaryIs><LinearRing><coordinates>${_kmlCoordLine(h, closeRing: true)}</coordinates></LinearRing></innerBoundaryIs>',
        );
      }
      buf.writeln('      </Polygon>');
      buf.writeln('    </Placemark>');
    }
  }
  buf.writeln('  </Document>');
  buf.writeln('</kml>');
  return buf.toString();
}

/// GPX ayrıştır: waypointler, iz ve rota polilineleri.
///
/// [tracks] / [routes]: belge sırasında düz segment listeleri (`trkseg` başına bir parça).
/// [namedTrackLines] / [namedRouteLines]: üst öğedeki `<name>` ile eşleşen isimler;
/// aynı `<trk>` altında birden fazla `trkseg` ise `Ad`, `Ad (2)`, …
({
  List<(String name, LatLng p)> wpts,
  List<List<LatLng>> tracks,
  List<List<LatLng>> routes,
  List<(String name, List<LatLng> line)> namedTrackLines,
  List<(String name, List<LatLng> line)> namedRouteLines,
}) parseGpx(
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
    wpts.add((n.isEmpty ? 'WPT' : n, LatLng(la, lo)));
  }
  final tracks = <List<LatLng>>[];
  final namedTrackLines = <(String, List<LatLng>)>[];
  for (final trk in doc.findAllElements('trk')) {
    final ne = trk.findElements('name');
    var base = ne.isEmpty ? 'İz' : ne.first.innerText.trim();
    if (base.isEmpty) base = 'İz';
    var segIdx = 0;
    for (final seg in trk.findAllElements('trkseg')) {
      final pts = <LatLng>[];
      for (final pt in seg.findAllElements('trkpt')) {
        final la = double.tryParse(pt.getAttribute('lat') ?? '');
        final lo = double.tryParse(pt.getAttribute('lon') ?? '');
        if (la != null && lo != null) pts.add(LatLng(la, lo));
      }
      if (pts.length < 2) continue;
      segIdx++;
      final segName = segIdx <= 1 ? base : '$base ($segIdx)';
      tracks.add(pts);
      namedTrackLines.add((segName, pts));
    }
  }
  final routes = <List<LatLng>>[];
  final namedRouteLines = <(String, List<LatLng>)>[];
  for (final rte in doc.findAllElements('rte')) {
    final ne = rte.findElements('name');
    var base = ne.isEmpty ? 'Rota' : ne.first.innerText.trim();
    if (base.isEmpty) base = 'Rota';
    final pts = <LatLng>[];
    for (final pt in rte.findAllElements('rtept')) {
      final la = double.tryParse(pt.getAttribute('lat') ?? '');
      final lo = double.tryParse(pt.getAttribute('lon') ?? '');
      if (la != null && lo != null) pts.add(LatLng(la, lo));
    }
    if (pts.length < 2) continue;
    routes.add(pts);
    namedRouteLines.add((base, pts));
  }
  return (
    wpts: wpts,
    tracks: tracks,
    routes: routes,
    namedTrackLines: namedTrackLines,
    namedRouteLines: namedRouteLines,
  );
}

/// KMZ: zip içindeki tüm `.kml` dosyaları (sırayla).
List<String> decodeKmzToKmlStrings(List<int> bytes) {
  final arch = ZipDecoder().decodeBytes(bytes);
  final out = <String>[];
  for (final f in arch.files) {
    if (f.isFile && f.name.toLowerCase().endsWith('.kml')) {
      out.add(String.fromCharCodes(f.content as List<int>));
    }
  }
  return out;
}

/// KMZ: ilk `.kml` (geriye uyumluluk).
String? decodeKmzToKmlString(List<int> bytes) {
  final all = decodeKmzToKmlStrings(bytes);
  if (all.isEmpty) return null;
  return all.first;
}

/// KMZ: zip içinde `doc.kml` (yaygın / OGC önerisi ile uyumlu tek dosya).
List<int> encodeKmzFromKml(String kml) {
  final arch = Archive()..add(ArchiveFile.string('doc.kml', kml));
  return ZipEncoder().encode(arch);
}

/// KML: Point, LineString/LinearRing, Polygon (dış + iç sınırlar) ve MultiPolygon.
///
/// [hasNetworkLink]: belgede `<NetworkLink>` var (harici KML bağlantısı; okunmaz).
///
/// [styledLines]: Placemark adı, geometri, 0xAARRGGBB ve isteğe bağlı KML `LineStyle`/`width`.
({
  List<(String name, LatLng p)> points,
  List<List<LatLng>> lines,
  List<(String name, List<LatLng> line, int? strokeArgb, double? strokeWidthPx)> styledLines,
  List<KmlPolygonPatch> polygonPatches,
  bool hasNetworkLink,
}) parseKmlPlacemarks(String kml) {
  final doc = XmlDocument.parse(kml);
  final styleIndex = _KmlStyleIndex(doc);
  final points = <(String, LatLng)>[];
  final lines = <List<LatLng>>[];
  final styledLines = <(String, List<LatLng>, int?, double?)>[];
  final polygonPatches = <KmlPolygonPatch>[];

  void addLineStroke(List<LatLng> pts, XmlElement pmForStyle, String lineName) {
    if (pts.length < 2) return;
    lines.add(pts);
    final vis = styleIndex.placemarkVisual(pmForStyle);
    styledLines.add((lineName, pts, vis.lineArgb, vis.lineWidth));
  }

  List<LatLng>? ringPoints(XmlElement ringEl) {
    final ce = ringEl.findElements('coordinates');
    final coord = ce.isEmpty ? '' : ce.first.innerText;
    final pts = _parseCoordLine(coord);
    return pts.length >= 3 ? pts : null;
  }

  void addPolygonPatch(XmlElement poly, XmlElement pm) {
    List<LatLng>? outer;
    for (final ob in poly.findElements('outerBoundaryIs')) {
      for (final ring in ob.findElements('LinearRing')) {
        outer = ringPoints(ring);
        if (outer != null) break;
      }
      if (outer != null) break;
    }
    if (outer == null) return;
    final holes = <List<LatLng>>[];
    for (final ib in poly.findElements('innerBoundaryIs')) {
      for (final ring in ib.findElements('LinearRing')) {
        final h = ringPoints(ring);
        if (h != null) holes.add(h);
      }
    }
    final vis = styleIndex.placemarkVisual(pm);
    final outline = vis.polyOutline ?? true;
    polygonPatches.add(KmlPolygonPatch(
      outer: outer,
      holes: holes,
      fillArgb32: vis.fillArgb,
      strokeArgb32: outline ? vis.lineArgb : null,
      strokeWidthPx: vis.lineWidth,
      drawStrokeOutline: outline,
    ));
  }

  void visitMultiPolygon(XmlElement multi, XmlElement pm) {
    for (final poly in multi.findElements('Polygon')) {
      addPolygonPatch(poly, pm);
    }
  }

  void visitPlacemark(XmlElement pm) {
    final nmEl = pm.findElements('name');
    var name = nmEl.isEmpty ? 'PM' : nmEl.first.innerText.trim();
    if (name.isEmpty) name = 'PM';
    var placemarkLineSeq = 0;
    String lineNameForNextSegment() {
      placemarkLineSeq++;
      return placemarkLineSeq <= 1 ? name : '$name ($placemarkLineSeq)';
    }
    final pointEl = pm.findElements('Point');
    final point = pointEl.isEmpty ? null : pointEl.first;
    if (point != null) {
      final ce = point.findElements('coordinates');
      final coord = ce.isEmpty ? '' : ce.first.innerText;
      final p = _parseCoordTriplet(coord);
      if (p != null) points.add((name, p));
    }
    for (final child in pm.childElements) {
      if (child.name.local != 'LineString' && child.name.local != 'LinearRing') continue;
      final ce = child.findElements('coordinates');
      final coord = ce.isEmpty ? '' : ce.first.innerText;
      final pts = _parseCoordLine(coord);
      addLineStroke(pts, pm, lineNameForNextSegment());
    }
    for (final poly in pm.findElements('Polygon')) {
      addPolygonPatch(poly, pm);
    }
    for (final multi in pm.findElements('MultiPolygon')) {
      visitMultiPolygon(multi, pm);
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
          addLineStroke(pts, pm, lineNameForNextSegment());
        } else if (c.name.local == 'Polygon') {
          addPolygonPatch(c, pm);
        } else if (c.name.local == 'MultiPolygon') {
          visitMultiPolygon(c, pm);
        }
      }
    }
  }

  for (final pm in doc.findAllElements('Placemark')) {
    visitPlacemark(pm);
  }
  final hasNetworkLink = doc.findAllElements('NetworkLink').isNotEmpty;
  return (
    points: points,
    lines: lines,
    styledLines: styledLines,
    polygonPatches: polygonPatches,
    hasNetworkLink: hasNetworkLink,
  );
}

/// En fazla [maxLinks] adet **tekil** mutlak HTTPS `NetworkLink` / `Link` / `href` adresi.
List<String> kmlHttpsNetworkLinkHrefs(String kml, {int maxLinks = 5}) {
  final doc = XmlDocument.parse(kml);
  final out = <String>[];
  final seen = <String>{};
  for (final nl in doc.findAllElements('NetworkLink')) {
    if (out.length >= maxLinks) break;
    String? hrefText;
    for (final link in nl.findElements('Link')) {
      for (final h in link.findElements('href')) {
        final t = h.innerText.trim();
        if (t.isNotEmpty) {
          hrefText = t;
          break;
        }
      }
      if (hrefText != null) break;
    }
    if (hrefText == null || hrefText.isEmpty) continue;
    final uri = Uri.tryParse(hrefText);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) continue;
    if (!seen.add(hrefText)) continue;
    out.add(hrefText);
  }
  return out;
}

/// Yalnızca HTTPS; en fazla [maxBytes] bayt; [timeout] ile sınırlı.
/// Yanıt KMZ (PK zip) ise içteki tüm `.kml` parçaları birleştirilir.
Future<String?> fetchKmlOrKmzAsUtf8String(
  Uri uri, {
  int maxBytes = 2 * 1024 * 1024,
  Duration timeout = const Duration(seconds: 15),
}) async {
  if (uri.scheme != 'https') return null;
  final client = http.Client();
  try {
    final req = http.Request('GET', uri);
    req.headers['User-Agent'] = 'BlueViperPro/1.0 KML-importer';
    final streamed = await client.send(req).timeout(timeout);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) return null;
    if (streamed.request?.url.scheme != 'https') return null;
    final chunks = <int>[];
    var total = 0;
    await for (final chunk in streamed.stream.timeout(timeout)) {
      total += chunk.length;
      if (total > maxBytes) return null;
      chunks.addAll(chunk);
    }
    if (chunks.isEmpty) return null;
    final bytes = Uint8List.fromList(chunks);
    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
      final kmls = decodeKmzToKmlStrings(bytes);
      if (kmls.isEmpty) return null;
      return kmls.join('\n');
    }
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Yerel geometri + isteğe bağlı `NetworkLink` hedeflerinden (HTTPS) ek geometri.
Future<({
  List<(String name, LatLng p)> points,
  List<List<LatLng>> lines,
  List<(String name, List<LatLng> line, int? strokeArgb, double? strokeWidthPx)> styledLines,
  List<KmlPolygonPatch> polygonPatches,
  bool hadNetworkLink,
  bool resolvedAnyNetworkLink,
})> parseKmlPlacemarksWithNetworkLinks(
  String kml, {
  int maxLinksPerDocument = 5,
  int maxBytesPerUrl = 2 * 1024 * 1024,
  Duration fetchTimeout = const Duration(seconds: 15),
  int networkNestingLeft = 2,
}) async {
  final base = parseKmlPlacemarks(kml);
  if (networkNestingLeft <= 0) {
    return (
      points: base.points,
      lines: base.lines,
      styledLines: base.styledLines,
      polygonPatches: base.polygonPatches,
      hadNetworkLink: base.hasNetworkLink,
      resolvedAnyNetworkLink: false,
    );
  }
  final hrefs = kmlHttpsNetworkLinkHrefs(kml, maxLinks: maxLinksPerDocument);
  if (hrefs.isEmpty) {
    return (
      points: base.points,
      lines: base.lines,
      styledLines: base.styledLines,
      polygonPatches: base.polygonPatches,
      hadNetworkLink: base.hasNetworkLink,
      resolvedAnyNetworkLink: false,
    );
  }
  var pts = List<(String, LatLng)>.from(base.points);
  var lns = List<List<LatLng>>.from(base.lines);
  var sln = List<(String, List<LatLng>, int?, double?)>.from(base.styledLines);
  var polys = List<KmlPolygonPatch>.from(base.polygonPatches);
  var resolved = false;
  for (final href in hrefs) {
    final uri = Uri.tryParse(href);
    if (uri == null || uri.scheme != 'https') continue;
    final text = await fetchKmlOrKmzAsUtf8String(uri, maxBytes: maxBytesPerUrl, timeout: fetchTimeout);
    if (text == null || text.trim().isEmpty) continue;
    final sub = await parseKmlPlacemarksWithNetworkLinks(
      text,
      maxLinksPerDocument: maxLinksPerDocument,
      maxBytesPerUrl: maxBytesPerUrl,
      fetchTimeout: fetchTimeout,
      networkNestingLeft: networkNestingLeft - 1,
    );
    pts.addAll(sub.points);
    lns.addAll(sub.lines);
    sln.addAll(sub.styledLines);
    polys.addAll(sub.polygonPatches);
    resolved = true;
  }
  return (
    points: pts,
    lines: lns,
    styledLines: sln,
    polygonPatches: polys,
    hadNetworkLink: base.hasNetworkLink,
    resolvedAnyNetworkLink: resolved,
  );
}

/// Zip veya birden çok KML parçası için üst üste birleştirilmiş sonuç.
Future<({
  List<(String name, LatLng p)> points,
  List<List<LatLng>> lines,
  List<(String name, List<LatLng> line, int? strokeArgb, double? strokeWidthPx)> styledLines,
  List<KmlPolygonPatch> polygonPatches,
  bool anyHadNetworkLink,
  bool anyResolvedNetworkLink,
})> parseKmlDocumentsWithNetworkLinks(
  Iterable<String> kmlXmlStrings, {
  int maxLinksPerDocument = 5,
  int maxBytesPerUrl = 2 * 1024 * 1024,
  Duration fetchTimeout = const Duration(seconds: 15),
  int networkNestingLeft = 2,
}) async {
  var pts = <(String, LatLng)>[];
  var lns = <List<LatLng>>[];
  var sln = <(String, List<LatLng>, int?, double?)>[];
  var polys = <KmlPolygonPatch>[];
  var anyHad = false;
  var anyResolved = false;
  for (final s in kmlXmlStrings) {
    final k = await parseKmlPlacemarksWithNetworkLinks(
      s,
      maxLinksPerDocument: maxLinksPerDocument,
      maxBytesPerUrl: maxBytesPerUrl,
      fetchTimeout: fetchTimeout,
      networkNestingLeft: networkNestingLeft,
    );
    if (k.hadNetworkLink) anyHad = true;
    if (k.resolvedAnyNetworkLink) anyResolved = true;
    pts.addAll(k.points);
    lns.addAll(k.lines);
    sln.addAll(k.styledLines);
    polys.addAll(k.polygonPatches);
  }
  return (
    points: pts,
    lines: lns,
    styledLines: sln,
    polygonPatches: polys,
    anyHadNetworkLink: anyHad,
    anyResolvedNetworkLink: anyResolved,
  );
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
