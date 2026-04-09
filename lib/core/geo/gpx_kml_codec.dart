import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

/// `IconStyle` / `hotSpot`: çapa noktası görüntü üzerinde; birimler KML 2.2 ile uyumlu (küçük harf).
class KmlIconHotspot {
  const KmlIconHotspot({
    required this.x,
    required this.y,
    required this.xunits,
    required this.yunits,
  });

  /// Alt kenar ortası (yaygın varsayılan).
  static const KmlIconHotspot kmlDefault = KmlIconHotspot(
    x: 0.5,
    y: 0,
    xunits: 'fraction',
    yunits: 'fraction',
  );

  final double x;
  final double y;
  /// `fraction` | `pixels` | `insetpixels`
  final String xunits;
  final String yunits;

  /// Görüntü boyutuna göre çapanın sol alt köşeden piksel uzaklığı.
  (double pxFromLeft, double pyFromBottom) anchorFromBottomLeft(double imgW, double imgH) {
    if (imgW <= 0 || imgH <= 0) return (0, 0);
    final xu = xunits.replaceAll('_', '');
    final yu = yunits.replaceAll('_', '');
    double pxLeft;
    switch (xu) {
      case 'pixels':
        pxLeft = x;
        break;
      case 'insetpixels':
        pxLeft = imgW - x;
        break;
      case 'fraction':
      default:
        pxLeft = x * imgW;
        break;
    }
    double pyBottom;
    switch (yu) {
      case 'pixels':
        pyBottom = y;
        break;
      case 'insetpixels':
        pyBottom = imgH - y;
        break;
      case 'fraction':
      default:
        pyBottom = y * imgH;
        break;
    }
    return (pxLeft, pyBottom);
  }
}

bool _kmlHotspotEqual(KmlIconHotspot? a, KmlIconHotspot? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  return a.x == b.x && a.y == b.y && a.xunits == b.xunits && a.yunits == b.yunits;
}

/// CDATA / basit HTML `description` veya balon metnini araç ipucu için düz metne indirger.
String kmlPlainTextFromBalloonHtml(String? raw) {
  if (raw == null) return '';
  var s = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// KML `Point` placemark — harita içe aktarımı.
class KmlPointImport {
  const KmlPointImport({
    required this.name,
    required this.point,
    this.iconColorArgb,
    this.iconScale,
    this.iconImageBytes,
    this.iconHotspot,
    this.balloonText,
    this.iconHref,
    this.hasKmlIconHighlight = false,
    this.iconHighlightColorArgb,
    this.iconHighlightScale,
    this.iconHighlightHotspot,
  });

  final String name;
  final LatLng point;
  final int? iconColorArgb;
  final double? iconScale;
  /// KMZ gömülü dosyadan çözülen ikon; yoksa yalnız renk/ölçek ile daire işaret.
  final Uint8List? iconImageBytes;
  final KmlIconHotspot? iconHotspot;
  /// `BalloonStyle` / `text` (`$[name]` ve `$[description]` yerine metin konur).
  final String? balloonText;
  /// `Icon/href` (KMZ / yerel dosya / HTTPS sonradan çözülür).
  final String? iconHref;
  /// `StyleMap` highlight yolu birleşik görünümden ikon açısından farklıysa dokununca highlight uygulanır.
  final bool hasKmlIconHighlight;
  final int? iconHighlightColorArgb;
  final double? iconHighlightScale;
  final KmlIconHotspot? iconHighlightHotspot;

  KmlPointImport withResolvedIcon(Uint8List bytes) => KmlPointImport(
        name: name,
        point: point,
        iconColorArgb: iconColorArgb,
        iconScale: iconScale,
        iconImageBytes: bytes,
        iconHotspot: iconHotspot,
        balloonText: balloonText,
        iconHref: null,
        hasKmlIconHighlight: hasKmlIconHighlight,
        iconHighlightColorArgb: iconHighlightColorArgb,
        iconHighlightScale: iconHighlightScale,
        iconHighlightHotspot: iconHighlightHotspot,
      );
}

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
  int? iconColorArgb;
  double? iconScale;
  String? iconHref;
  KmlIconHotspot? iconHotspot;
  String? balloonText;

  bool get hasLine => lineArgb != null;
  bool get hasFill => fillArgb != null;
  bool get hasAny =>
      hasLine ||
      hasFill ||
      lineWidth != null ||
      polyOutline != null ||
      iconColorArgb != null ||
      iconScale != null ||
      (iconHref != null && iconHref!.trim().isNotEmpty) ||
      iconHotspot != null ||
      (balloonText != null && balloonText!.trim().isNotEmpty);

  void applyStyleElement(XmlElement styleRoot) {
    final lc = _lineStyleArgbFromStyleElement(styleRoot);
    if (lc != null) lineArgb = lc;
    final lw = _lineWidthFromStyleElement(styleRoot);
    if (lw != null) lineWidth = lw;
    final fc = _polyStyleArgbFromStyleElement(styleRoot);
    if (fc != null) fillArgb = fc;
    final po = _polyOutlineFromStyleElement(styleRoot);
    if (po != null) polyOutline = po;
    for (final bs in styleRoot.findElements('BalloonStyle')) {
      for (final t in bs.findElements('text')) {
        final raw = t.innerText.trim();
        if (raw.isNotEmpty) balloonText = raw;
      }
    }
    for (final ic in styleRoot.findElements('IconStyle')) {
      for (final c in ic.findElements('color')) {
        final v = kmlLineColorAabbggrrToArgb32(c.innerText);
        if (v != null) iconColorArgb = v;
      }
      for (final s in ic.findElements('scale')) {
        final v = double.tryParse(s.innerText.trim());
        if (v != null && v > 0) iconScale = v;
      }
      for (final iconEl in ic.findElements('Icon')) {
        for (final h in iconEl.findElements('href')) {
          final t = h.innerText.trim();
          if (t.isNotEmpty) iconHref = t;
        }
      }
      if (iconHref == null || iconHref!.trim().isEmpty) {
        for (final h in ic.findElements('href')) {
          final t = h.innerText.trim();
          if (t.isNotEmpty) iconHref = t;
        }
      }
      for (final hs in ic.findElements('hotSpot')) {
        iconHotspot = _parseKmlHotSpotElement(hs);
      }
    }
  }

  void mergeFrom(_KmlVisStyle o) {
    if (o.lineArgb != null) lineArgb = o.lineArgb;
    if (o.lineWidth != null) lineWidth = o.lineWidth;
    if (o.fillArgb != null) fillArgb = o.fillArgb;
    if (o.polyOutline != null) polyOutline = o.polyOutline;
    if (o.iconColorArgb != null) iconColorArgb = o.iconColorArgb;
    if (o.iconScale != null) iconScale = o.iconScale;
    if (o.iconHref != null && o.iconHref!.trim().isNotEmpty) iconHref = o.iconHref;
    if (o.iconHotspot != null) iconHotspot = o.iconHotspot;
    if (o.balloonText != null && o.balloonText!.trim().isNotEmpty) balloonText = o.balloonText;
  }

  void fillGapsFrom(_KmlVisStyle o) {
    lineArgb ??= o.lineArgb;
    lineWidth ??= o.lineWidth;
    fillArgb ??= o.fillArgb;
    polyOutline ??= o.polyOutline;
    iconColorArgb ??= o.iconColorArgb;
    iconScale ??= o.iconScale;
    if (iconHref == null || iconHref!.trim().isEmpty) iconHref = o.iconHref;
    iconHotspot ??= o.iconHotspot;
    if (balloonText == null || balloonText!.trim().isEmpty) balloonText = o.balloonText;
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

  _KmlVisStyle _resolveStyleUrlHighlightOnly(String? raw) {
    final frag = _kmlStyleUrlFragment(raw ?? '');
    final acc = _KmlVisStyle();
    if (frag == null) return acc;
    _walkMerge(frag, styleMapHighlight, acc);
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

  /// Yalnızca `StyleMap` / `Pair` `highlight` zinciri + placemark içi `Style` (GE tıklama görünümü).
  _KmlVisStyle placemarkVisualHighlightOnly(XmlElement pm) {
    final acc = _KmlVisStyle();
    final urls = pm.findElements('styleUrl');
    if (urls.isNotEmpty) {
      acc.mergeFrom(_resolveStyleUrlHighlightOnly(urls.first.innerText));
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
  List<(String name, LatLng p, String? description)> waypoints = const [],
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
  for (final (nm, p, desc) in waypoints) {
    buf.writeln('  <wpt lat="${p.latitude}" lon="${p.longitude}"><name>${esc(nm)}</name>');
    final d = desc?.trim();
    if (d != null && d.isNotEmpty) {
      buf.writeln('    <desc>${esc(d)}</desc>');
    }
    buf.writeln('  </wpt>');
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
  List<(String name, LatLng p, String? description)> waypoints = const [],
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
  for (final (nm, p, desc) in waypoints) {
    buf.writeln('    <Placemark>');
    buf.writeln('      <name>${_kmlEsc(nm)}</name>');
    final d = desc?.trim();
    if (d != null && d.isNotEmpty) {
      buf.writeln('      <description>${_kmlEsc(d)}</description>');
    }
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

/// KMZ içi göreli yol — arama anahtarı (küçük harf, `/` ayracı).
String kmlNormalizeZipInternalPath(String raw) {
  var s = raw.trim().replaceAll('\\', '/');
  while (s.startsWith('/')) {
    s = s.substring(1);
  }
  while (s.startsWith('./')) {
    s = s.substring(2);
  }
  return s.toLowerCase();
}

/// KMZ arşivindeki tüm dosyalar → normalize yol → ham bayt.
Map<String, Uint8List> decodeKmzEmbeddedFiles(List<int> bytes) {
  final arch = ZipDecoder().decodeBytes(bytes);
  final out = <String, Uint8List>{};
  for (final f in arch.files) {
    if (!f.isFile) continue;
    final norm = kmlNormalizeZipInternalPath(f.name);
    if (norm.isEmpty) continue;
    out[norm] = Uint8List.fromList(f.content);
  }
  return out;
}

/// PNG `IHDR` boyutu; aksi `null` (JPEG vb. için üst katman varsayılan boy kullanır).
(int width, int height)? kmlPngDimensionsIfAny(Uint8List b) {
  if (b.length < 24) return null;
  if (b[0] != 0x89 || b[1] != 0x50 || b[2] != 0x4E || b[3] != 0x47) return null;
  final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
  final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
  if (w <= 0 || h <= 0 || w > 8192 || h > 8192) return null;
  return (w, h);
}

Uint8List? _lookupKmzIconBytes(String? href, Map<String, Uint8List>? files) {
  if (href == null || files == null || files.isEmpty) return null;
  final t = href.trim();
  if (t.isEmpty) return null;
  if (t.contains('://')) return null;
  final key = kmlNormalizeZipInternalPath(t);
  final direct = files[key];
  if (direct != null) return direct;
  final slash = key.lastIndexOf('/');
  final base = slash < 0 ? key : key.substring(slash + 1);
  for (final e in files.entries) {
    if (e.key == base || e.key.endsWith('/$base')) return e.value;
  }
  return null;
}

KmlIconHotspot? _parseKmlHotSpotElement(XmlElement hs) {
  final x = double.tryParse(hs.getAttribute('x') ?? '') ?? 0.5;
  final y = double.tryParse(hs.getAttribute('y') ?? '') ?? 0;
  var xu = (hs.getAttribute('xunits') ?? 'fraction').trim().toLowerCase().replaceAll('_', '');
  var yu = (hs.getAttribute('yunits') ?? 'fraction').trim().toLowerCase().replaceAll('_', '');
  if (xu == 'inset') xu = 'insetpixels';
  if (yu == 'inset') yu = 'insetpixels';
  return KmlIconHotspot(x: x, y: y, xunits: xu, yunits: yu);
}

bool _kmlIconStyleSameForMarker(_KmlVisStyle merged, _KmlVisStyle highlight) {
  return merged.iconColorArgb == highlight.iconColorArgb &&
      merged.iconScale == highlight.iconScale &&
      _kmlHotspotEqual(merged.iconHotspot, highlight.iconHotspot);
}

KmlPointImport _kmlPointFromVis(
  String name,
  LatLng p,
  _KmlVisStyle visMerged,
  _KmlVisStyle visHighlight,
  Map<String, Uint8List>? kmzEmbeddedFiles,
  XmlElement pm,
) {
  final hrefRaw = visMerged.iconHref?.trim();
  final href = (hrefRaw == null || hrefRaw.isEmpty) ? null : hrefRaw;
  final bytes = _lookupKmzIconBytes(href, kmzEmbeddedFiles);
  String? descFromPm;
  for (final d in pm.findElements('description')) {
    final t = d.innerText.trim();
    if (t.isNotEmpty) {
      descFromPm = kmlPlainTextFromBalloonHtml(t);
      break;
    }
  }
  String? bt = visMerged.balloonText?.trim();
  if (bt != null && bt.isNotEmpty) {
    bt = kmlPlainTextFromBalloonHtml(bt);
    bt = bt.replaceAll(r'$[name]', name);
    if (descFromPm != null) bt = bt.replaceAll(r'$[description]', descFromPm);
  } else {
    bt = descFromPm;
  }
  final hiDiffers = !_kmlIconStyleSameForMarker(visMerged, visHighlight);
  return KmlPointImport(
    name: name,
    point: p,
    iconColorArgb: visMerged.iconColorArgb,
    iconScale: visMerged.iconScale,
    iconImageBytes: bytes,
    iconHotspot: visMerged.iconHotspot,
    balloonText: bt,
    iconHref: bytes != null ? null : href,
    hasKmlIconHighlight: hiDiffers,
    iconHighlightColorArgb: hiDiffers ? visHighlight.iconColorArgb : null,
    iconHighlightScale: hiDiffers ? visHighlight.iconScale : null,
    iconHighlightHotspot: hiDiffers ? visHighlight.iconHotspot : null,
  );
}

/// KML: Point, LineString/LinearRing, Polygon (dış + iç sınırlar) ve MultiPolygon.
///
/// [hasNetworkLink]: belgede `<NetworkLink>` var (harici KML bağlantısı; okunmaz).
///
/// [styledLines]: Placemark adı, geometri, 0xAARRGGBB ve isteğe bağlı KML `LineStyle`/`width`.
({
  List<KmlPointImport> points,
  List<List<LatLng>> lines,
  List<(String name, List<LatLng> line, int? strokeArgb, double? strokeWidthPx)> styledLines,
  List<KmlPolygonPatch> polygonPatches,
  bool hasNetworkLink,
}) parseKmlPlacemarks(String kml, {Map<String, Uint8List>? kmzEmbeddedFiles}) {
  final doc = XmlDocument.parse(kml);
  final styleIndex = _KmlStyleIndex(doc);
  final points = <KmlPointImport>[];
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
      if (p != null) {
        final vis = styleIndex.placemarkVisual(pm);
        final visHi = styleIndex.placemarkVisualHighlightOnly(pm);
        points.add(_kmlPointFromVis(name, p, vis, visHi, kmzEmbeddedFiles, pm));
      }
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
          if (p != null) {
            final vis = styleIndex.placemarkVisual(pm);
            final visHi = styleIndex.placemarkVisualHighlightOnly(pm);
            points.add(_kmlPointFromVis(name, p, vis, visHi, kmzEmbeddedFiles, pm));
          }
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
  List<KmlPointImport> points,
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
  Map<String, Uint8List>? kmzEmbeddedFiles,
}) async {
  final base = parseKmlPlacemarks(kml, kmzEmbeddedFiles: kmzEmbeddedFiles);
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
  var pts = List<KmlPointImport>.from(base.points);
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
      kmzEmbeddedFiles: null,
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
  List<KmlPointImport> points,
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
  Map<String, Uint8List>? kmzEmbeddedFiles,
}) async {
  var pts = <KmlPointImport>[];
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
      kmzEmbeddedFiles: kmzEmbeddedFiles,
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

/// `https` veya `http` `Icon/href` için küçük raster; büyük yanıtlar reddedilir.
Future<Uint8List?> fetchKmlIconBytesUri(
  Uri uri, {
  int maxBytes = 512 * 1024,
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  final client = http.Client();
  try {
    final req = http.Request('GET', uri);
    req.headers['User-Agent'] = 'BlueViperPro/1.0 KML-icon';
    final streamed = await client.send(req).timeout(timeout);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) return null;
    final chunks = <int>[];
    var total = 0;
    await for (final chunk in streamed.stream.timeout(timeout)) {
      total += chunk.length;
      if (total > maxBytes) return null;
      chunks.addAll(chunk);
    }
    if (chunks.isEmpty) return null;
    return Uint8List.fromList(chunks);
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Geriye uyumluluk: yalnızca `https` (http için [fetchKmlIconBytesUri]).
Future<Uint8List?> fetchKmlIconBytesHttps(
  Uri uri, {
  int maxBytes = 512 * 1024,
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (uri.scheme != 'https') return null;
  return fetchKmlIconBytesUri(uri, maxBytes: maxBytes, timeout: timeout);
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
