import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:vector_tile/vector_tile.dart';

/// MBTiles içindeki tek bir vektör karo: tipik olarak gzip'li MVT protobuf;
/// bazı üreticiler ham protobuf saklar.
///
/// Haritada çizim [flutter_map] veya MapLibre ayrıdır; bu sınıf yalnızca bayta → [VectorTile].
class MbtilesMvtCodec {
  MbtilesMvtCodec._();

  static bool looksLikeGzip(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

  /// MBTiles `tile_data` hücresinden MVT protobuf baytlarını üretir (gerekirse gzip açar).
  static Uint8List mvtPayloadFromTileBlob(Uint8List tileBlob) {
    if (looksLikeGzip(tileBlob)) {
      return const GZipDecoder().decodeBytes(tileBlob);
    }
    return tileBlob;
  }

  /// Ham veya gzip'li tek karo → çözümlenmiş vektör karo.
  static VectorTile decodeVectorTileFromTileBlob(Uint8List tileBlob) {
    final payload = mvtPayloadFromTileBlob(tileBlob);
    return VectorTile.fromBytes(bytes: payload);
  }

  /// Flutter / OSM XYZ y bileşeninden MBTiles TMS `tile_row` değeri.
  static int mbtilesTileRowFromXyzY(int z, int yXyz) => (1 << z) - 1 - yXyz;
}
