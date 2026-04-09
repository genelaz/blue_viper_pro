import 'dart:typed_data';

import 'package:mbtiles/mbtiles.dart';
import 'package:sqlite3/sqlite3.dart';

import 'vector_mbtiles_policy.dart';

/// Yerel MBTiles paketinin raster (png/jpg/webp) mı vektör (MVT) mü olduğunu ayırır.
enum MbtilesBasemapKind { raster, vector }

class MbtilesBasemapProbe {
  MbtilesBasemapProbe._();

  /// İlk karo gzip mi (MVT’de yaygın); raster karolarda tipik değildir.
  static bool firstTileIsGzip(String mbtilesPath) {
    final raw = sqlite3.open(mbtilesPath, mode: OpenMode.readOnly);
    try {
      final rows = raw.select('SELECT tile_data FROM tiles LIMIT 1');
      if (rows.isEmpty) return false;
      final blob = rows.first['tile_data'];
      if (blob is! Uint8List || blob.length < 2) return false;
      return blob[0] == 0x1f && blob[1] == 0x8b;
    } catch (_) {
      return false;
    } finally {
      raw.dispose();
    }
  }

  static bool _claimedRasterFormat(String formatRaw) {
    final f = formatRaw.toLowerCase().trim();
    return f == 'png' || f == 'jpg' || f == 'jpeg' || f == 'webp';
  }

  /// Geçerli arşiv ve metadata için türü döndürür.
  static Future<({bool ok, String? message, MbtilesBasemapKind? kind, MbTilesMetadata? meta})> analyze(
    String mbtilesPath,
  ) async {
    final db = MbTiles(mbtilesPath: mbtilesPath);
    final MbTilesMetadata meta;
    try {
      meta = db.getMetadata();
    } catch (e) {
      db.dispose();
      return (ok: false, message: 'MBTiles okunamadı: $e', kind: null, meta: null);
    }
    db.dispose();

    final vecByMeta = VectorMbtilesPolicy.isVectorMetadata(meta);
    final rasterClaim = _claimedRasterFormat(meta.format);
    final gzipBlob = firstTileIsGzip(mbtilesPath);
    final isVector = vecByMeta || (rasterClaim && gzipBlob);

    return (
      ok: true,
      message: null,
      kind: isVector ? MbtilesBasemapKind.vector : MbtilesBasemapKind.raster,
      meta: meta,
    );
  }
}
