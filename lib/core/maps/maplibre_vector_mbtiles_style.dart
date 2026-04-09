import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Uzakta barındırılan OpenFreeMap «Liberty» stil belgesi (sprite + glif + tam katman ifadeleri).
const String kOpenFreeMapLibertyStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

/// Yerel `.mbtiles` için MapLibre Native’in beklediği `mbtiles://` tabanı.
///
/// Windows: `C:\a\b.mbtiles` → `mbtiles:///C:/a/b.mbtiles`
String mbtilesSchemeUrlFromAbsolutePath(String absolutePath) {
  final normalized = absolutePath.replaceAll('\\', '/');
  if (Platform.isWindows) {
    final m = RegExp(r'^([a-zA-Z]):').firstMatch(normalized);
    if (m != null) {
      final rest = normalized.substring(m.end);
      return 'mbtiles:///${m[1]}:$rest';
    }
  }
  if (normalized.startsWith('/')) {
    return 'mbtiles://$normalized';
  }
  return 'mbtiles:///$normalized';
}

/// [kOpenFreeMapLibertyStyleUrl] indirilir; `sources.openmaptiles` yerel vektör MBTiles olacak şekilde değiştirilir.
///
/// Ağ: stil + sprite + glif hâlâ OpenFreeMap üzerinden (çoğu çevrimdışı senaryoda üst raster katmanınız olabilir).
/// Karo verisi: yalnızca yerel paketten.
Future<String> buildOpenFreeMapLibertyStyleJsonWithMbtiles({
  required String mbtilesAbsolutePath,
  http.Client? httpClient,
}) async {
  final c = httpClient ?? http.Client();
  try {
    final res = await c.get(Uri.parse(kOpenFreeMapLibertyStyleUrl));
    if (res.statusCode != 200) {
      throw HttpException('Liberty stil HTTP ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Liberty stil kök nesne değil');
    }
    final sources = decoded['sources'];
    if (sources is! Map<String, dynamic>) {
      throw const FormatException('Liberty stil sources yok');
    }
    sources['openmaptiles'] = <String, dynamic>{
      'type': 'vector',
      'url': mbtilesSchemeUrlFromAbsolutePath(mbtilesAbsolutePath),
    };
    return jsonEncode(decoded);
  } finally {
    if (httpClient == null) {
      c.close();
    }
  }
}
