import 'package:mbtiles/mbtiles.dart';

/// Vektör MBTiles (`format=pbf` / mvt) raster [MbtilesRasterCheck] ile reddedilir.
///
/// Tippecanoe / GDAL ile **raster** (png/jpg/webp) MBTiles üretin; vektör paket
/// flutter_map ile bu projede tam katman olarak açılmaz.
class VectorMbtilesPolicy {
  static const String shortUserMessage =
      'Vektör MBTiles (Mapbox pbf) desteklenmiyor; png/jpg/webp raster paketi seçin.';

  static bool looksLikeVectorFormat(String formatRaw) {
    final f = formatRaw.toLowerCase().trim();
    if (f.isEmpty) return false;
    if (f == 'pbf' || f == 'mvt') return true;
    if (f.contains('protobuf')) return true;
    if (f.contains('mapbox-vector-tile')) return true;
    return false;
  }

  /// Tippecanoe / Mapbox `metadata.json` içeriği (`vector_layers`).
  static bool metadataJsonSuggestsVector(String? jsonRaw) {
    if (jsonRaw == null || jsonRaw.isEmpty) return false;
    return jsonRaw.contains('"vector_layers"');
  }

  static bool isVectorMetadata(MbTilesMetadata meta) =>
      looksLikeVectorFormat(meta.format) || metadataJsonSuggestsVector(meta.json);
}
