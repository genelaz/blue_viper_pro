import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'mbtiles_mvt_codec.dart';

/// Salt okunur MBTiles üzerinde XYZ (OSM) karosu — `tile_row` TMS dönüşümü dahil.
class MbtilesRawTileReader {
  MbtilesRawTileReader(this.path);

  final String path;
  Database? _db;

  Database get _ensure => _db ??= sqlite3.open(path, mode: OpenMode.readOnly);

  Uint8List? readTileXyz(int z, int x, int yXyz) {
    final row = MbtilesMvtCodec.mbtilesTileRowFromXyzY(z, yXyz);
    final rows = _ensure.select(
      'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ? LIMIT 1',
      [z, x, row],
    );
    if (rows.isEmpty) return null;
    final blob = rows.first['tile_data'];
    if (blob is! Uint8List || blob.isEmpty) return null;
    return blob;
  }

  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
