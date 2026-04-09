import 'dart:io';

import 'package:proj4dart/proj4dart.dart';

String _prjSiblingPath(String shpPath) {
  final lower = shpPath.toLowerCase();
  if (lower.endsWith('.shp')) {
    return '${shpPath.substring(0, shpPath.length - 4)}.prj';
  }
  return '$shpPath.prj';
}

/// `.prj` var mı?
bool shapefilePrjExistsAtShpPath(String shpPath) => File(_prjSiblingPath(shpPath)).existsSync();

/// [Projection] veya ham koordinat (WGS84 enlem/boylam) için `null`.
Projection? tryProjectionFromShapefilePrj(String shpPath) {
  final prjPath = _prjSiblingPath(shpPath);
  final f = File(prjPath);
  if (!f.existsSync()) return null;
  String text;
  try {
    text = f.readAsStringSync().trim();
  } catch (_) {
    return null;
  }
  return projectionFromPrjText(text);
}

/// Metin: OGC WKT veya sadece EPSG ipuçları içeren .prj.
Projection? projectionFromPrjText(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  try {
    return Projection.parse(t);
  } catch (_) {
    final code = lastEpsgCodeFromWkt(t);
    if (code == null) return null;
    return projectionFromKnownEpsg(code);
  }
}

/// Son `AUTHORITY["EPSG", ...]` eşleşmesi (genelde asıl CRS).
int? lastEpsgCodeFromWkt(String wkt) {
  final re = RegExp(r'AUTHORITY\s*\[\s*"EPSG"\s*,\s*"?(\d+)"?\s*\]', caseSensitive: false);
  int? last;
  for (final m in re.allMatches(wkt)) {
    last = int.tryParse(m.group(1)!);
  }
  return last;
}

/// Yaygın kodlar için proj4 kuralı (WKT çözülemezse).
Projection? projectionFromKnownEpsg(int code) {
  try {
    if (code == 4326) return Projection.get('EPSG:4326');
    if (code == 3857 || code == 900913) return Projection.get('EPSG:3857');

    if (code >= 32601 && code <= 32660) {
      final zone = code - 32600;
      return Projection.parse('+proj=utm +zone=$zone +datum=WGS84 +units=m +no_defs');
    }
    if (code >= 32701 && code <= 32760) {
      final zone = code - 32700;
      return Projection.parse('+proj=utm +zone=$zone +south +datum=WGS84 +units=m +no_defs');
    }
  } catch (_) {}
  return null;
}
