import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';

import 'mbtiles_basemap_probe.dart';
import 'vector_mbtiles_policy.dart';

/// Raster MBTiles (png/jpg/webp) uygunluğu; vektör pbf/mvt reddi.
class MbtilesRasterCheck {
  static Future<({bool ok, String? message, MbTilesMetadata? meta})> validateFile(
    String mbtilesPath,
  ) async {
    final a = await MbtilesBasemapProbe.analyze(mbtilesPath);
    if (!a.ok) {
      return (ok: false, message: a.message ?? 'MBTiles okunamadı', meta: null);
    }
    if (a.kind == MbtilesBasemapKind.vector) {
      return (
        ok: false,
        message: VectorMbtilesPolicy.shortUserMessage,
        meta: null,
      );
    }
    return (ok: true, message: null, meta: a.meta);
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
