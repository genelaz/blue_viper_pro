import 'dart:convert';

import 'package:latlong2/latlong.dart';

import 'geopdf_streams.dart';

/// Adobe geospatial PDF ölçümünden (`/GPTS`) WGS84 köşe listesi — raster harita gövdesi okunmaz.
class GeoPdfExtentResult {
  const GeoPdfExtentResult({
    required this.found,
    this.cornersWgs84 = const [],
    this.detail,
  });

  final bool found;
  final List<LatLng> cornersWgs84;
  final String? detail;
}

final RegExp _pdfFloat = RegExp(
  r'[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?',
);

/// PDF baytlarında `GPTS` dizilerini arar; düz metin ve Flate açılmış içerik.
GeoPdfExtentResult tryParseGeoPdfGpts(List<int> bytes) {
  if (bytes.isEmpty) {
    return const GeoPdfExtentResult(found: false, detail: 'Dosya boş');
  }
  final direct = _parseGptsFromText(latin1.decode(bytes, allowInvalid: true));
  if (direct.found) return direct;

  final flate = tryConcatenateDecodedFlateText(bytes);
  if (flate.isNotEmpty) {
    final fromFlate = _parseGptsFromText(flate);
    if (fromFlate.found) {
      return GeoPdfExtentResult(
        found: true,
        cornersWgs84: fromFlate.cornersWgs84,
        detail: '${fromFlate.detail} · Flate',
      );
    }
  }
  return const GeoPdfExtentResult(
    found: false,
    detail:
        'GeoPDF ölçümü (GPTS) bulunamadı; dosya raster-only veya farklı biçimde olabilir.',
  );
}

GeoPdfExtentResult _parseGptsFromText(String scan) {
  for (var i = 0; i < scan.length - 4; i++) {
    if (!_matchGpts(scan, i)) continue;
    final end = scan.length < i + 8192 ? scan.length : i + 8192;
    final slice = scan.substring(i, end);
    final nums = _numbersInFirstPdfArray(slice);
    if (nums == null || nums.length < 4 || nums.length.isOdd) continue;

    final corners = _tryLonLatPairs(nums) ?? _tryLonLatPairs(_swappedPairs(nums));
    if (corners != null && corners.length >= 2) {
      return GeoPdfExtentResult(
        found: true,
        cornersWgs84: corners,
        detail: '${corners.length} köşe (GPTS)',
      );
    }
  }
  return const GeoPdfExtentResult(found: false);
}

bool _matchGpts(String s, int i) {
  if (i + 4 > s.length) return false;
  final g = s.codeUnitAt(i);
  if (g != 0x47 && g != 0x67) return false;
  final p = s.codeUnitAt(i + 1) | 0x20;
  final t = s.codeUnitAt(i + 2) | 0x20;
  final s2 = s.codeUnitAt(i + 3) | 0x20;
  return p == 0x70 && t == 0x74 && s2 == 0x73;
}

/// [inner] — `GPTS` sonrası ilk `[ ... ]` içeriği (köşeli ayraçlar dengeli).
List<double>? _numbersInFirstPdfArray(String fromGpts) {
  final open = fromGpts.indexOf('[');
  if (open < 0) return null;
  var depth = 0;
  for (var i = open; i < fromGpts.length; i++) {
    final c = fromGpts[i];
    if (c == '[') {
      depth++;
    } else if (c == ']') {
      depth--;
      if (depth == 0) {
        var inner = fromGpts.substring(open + 1, i);
        inner = inner.replaceAll(RegExp(r'%[^\r\n]*'), ' ');
        return _pdfFloat.allMatches(inner).map((m) => double.parse(m.group(0)!)).toList();
      }
    }
  }
  return null;
}

List<double> _swappedPairs(List<double> nums) {
  final out = <double>[];
  for (var i = 0; i + 1 < nums.length; i += 2) {
    out.add(nums[i + 1]);
    out.add(nums[i]);
  }
  return out;
}

List<LatLng>? _tryLonLatPairs(List<double> nums) {
  final out = <LatLng>[];
  for (var i = 0; i + 1 < nums.length; i += 2) {
    final lon = nums[i];
    final lat = nums[i + 1];
    if (!_isPlausibleWgs84(lon, lat)) return null;
    out.add(LatLng(lat, lon));
  }
  return out;
}

bool _isPlausibleWgs84(double lon, double lat) =>
    lon >= -180 && lon <= 180 && lat >= -90 && lat <= 90 && (lon.abs() > 1e-6 || lat.abs() > 1e-6);
