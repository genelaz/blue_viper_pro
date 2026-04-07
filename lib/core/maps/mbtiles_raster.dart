import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';

/// Raster MBTiles (png/jpg/webp) uygunluğu; vektör pbf/mvt reddi.
class MbtilesRasterCheck {
  static Future<({bool ok, String? message, MbTilesMetadata? meta})> validateFile(
    String mbtilesPath,
  ) async {
    final db = MbTiles(mbtilesPath: mbtilesPath);
    try {
      final meta = db.getMetadata();
      final f = meta.format.toLowerCase().trim();
      if (f == 'pbf' || f == 'mvt' || f.contains('protobuf')) {
        return (
          ok: false,
          message:
              'Bu MBTiles vektör (pbf/mvt). Şimdilik yalnızca png/jpg/webp raster paketleri desteklenir.',
          meta: null,
        );
      }
      return (ok: true, message: null, meta: meta);
    } catch (e) {
      return (ok: false, message: 'MBTiles okunamadı: $e', meta: null);
    } finally {
      db.dispose();
    }
  }

  /// metadata ile haritayı ortalamak için merkez / zoom.
  static (LatLng center, double zoom) viewForMetadata(MbTilesMetadata meta, LatLng fallback) {
    final c = meta.defaultCenter;
    final z = meta.defaultZoom;
    if (c != null && z != null && z.isFinite) {
      return (c, z.clamp(0.0, 22.0));
    }
    final b = meta.bounds;
    if (b != null) {
      final lat = (b.bottom + b.top) / 2;
      final lon = (b.left + b.right) / 2;
      return (LatLng(lat, lon), (meta.maxZoom ?? 14).clamp(0.0, 22.0).toDouble());
    }
    return (fallback, 6);
  }
}
