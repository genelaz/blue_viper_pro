import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:blue_viper_pro/core/maps/mbtiles_mvt_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/protobuf.dart';
import 'package:vector_tile/vector_tile.dart';

void main() {
  test('ham boş MVT protobuf çözülür', () {
    final tile = MbtilesMvtCodec.decodeVectorTileFromTileBlob(Uint8List(0));
    expect(tile.layers, isEmpty);
  });

  test('gzip sarmalı aynı içeriği verir', () {
    final inner = Uint8List(0);
    final wrapped = Uint8List.fromList(GZipEncoder().encodeBytes(inner));
    expect(MbtilesMvtCodec.looksLikeGzip(wrapped), true);
    final tile = MbtilesMvtCodec.decodeVectorTileFromTileBlob(wrapped);
    expect(tile.layers, isEmpty);
  });

  test('TMS satır dönüşümü (z=1)', () {
    expect(MbtilesMvtCodec.mbtilesTileRowFromXyzY(1, 0), 1);
    expect(MbtilesMvtCodec.mbtilesTileRowFromXyzY(1, 1), 0);
  });

  test('geçersiz protobuf reddedilir', () {
    expect(
      () => MbtilesMvtCodec.decodeVectorTileFromTileBlob(Uint8List.fromList([0xFF, 0xEE])),
      throwsA(isA<InvalidProtocolBufferException>()),
    );
  });

  test('örnek .mvt dosyası varsa katmanlar okunur', () async {
    final env = Platform.environment['MVT_FIXTURE'];
    if (env == null || env.isEmpty) return;
    final f = File(env);
    if (!f.existsSync()) return;
    final bytes = await f.readAsBytes();
    final tile = MbtilesMvtCodec.decodeVectorTileFromTileBlob(bytes);
    final raw = bytes[0] == 0x1f && bytes[1] == 0x8b
        ? const GZipDecoder().decodeBytes(bytes)
        : bytes;
    final direct = VectorTile.fromBytes(bytes: raw);
    expect(tile.layers.length, direct.layers.length);
  });
}
