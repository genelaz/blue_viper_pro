import 'dart:io';
import 'dart:typed_data';

import 'package:blue_viper_pro/core/maps/mbtiles_raster.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void _writeMbtiles(String path, void Function(Database db) fill) {
  if (File(path).existsSync()) File(path).deleteSync();
  final db = sqlite3.open(path);
  try {
    db.execute('CREATE TABLE metadata (name TEXT PRIMARY KEY, value TEXT);');
    db.execute(
      'CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);',
    );
    fill(db);
  } finally {
    db.dispose();
  }
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mbtiles_raster_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('accepts raster metadata and png signature tile', () async {
    final path = '${tmp.path}/ok.mbtiles';
    _writeMbtiles(path, (db) {
      db.execute("INSERT INTO metadata VALUES ('name', 't')");
      db.execute("INSERT INTO metadata VALUES ('format', 'png')");
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      db.prepare('INSERT INTO tiles VALUES (?, ?, ?, ?)').execute([0, 0, 0, bytes]);
    });
    final r = await MbtilesRasterCheck.validateFile(path);
    expect(r.ok, true);
    expect(r.meta?.format, 'png');
  });

  test('rejects format=pbf', () async {
    final path = '${tmp.path}/pbf.mbtiles';
    _writeMbtiles(path, (db) {
      db.execute("INSERT INTO metadata VALUES ('name', 't')");
      db.execute("INSERT INTO metadata VALUES ('format', 'pbf')");
    });
    final r = await MbtilesRasterCheck.validateFile(path);
    expect(r.ok, false);
    expect(r.message, isNotNull);
  });

  test('rejects metadata json with vector_layers while format png', () async {
    final path = '${tmp.path}/layers.mbtiles';
    _writeMbtiles(path, (db) {
      db.execute("INSERT INTO metadata VALUES ('name', 't')");
      db.execute("INSERT INTO metadata VALUES ('format', 'png')");
      db.execute("INSERT INTO metadata VALUES ('json', '{\"vector_layers\":[]}')");
    });
    final r = await MbtilesRasterCheck.validateFile(path);
    expect(r.ok, false);
  });

  test('rejects gzip first tile when format claims png', () async {
    final path = '${tmp.path}/gzip.mbtiles';
    _writeMbtiles(path, (db) {
      db.execute("INSERT INTO metadata VALUES ('name', 't')");
      db.execute("INSERT INTO metadata VALUES ('format', 'png')");
      final gzipMagic = Uint8List.fromList([0x1f, 0x8b, 0x08, 0]);
      db.prepare('INSERT INTO tiles VALUES (?, ?, ?, ?)').execute([0, 0, 0, gzipMagic]);
    });
    final r = await MbtilesRasterCheck.validateFile(path);
    expect(r.ok, false);
  });

  test('empty tiles table does not trigger gzip heuristic', () async {
    final path = '${tmp.path}/emptytiles.mbtiles';
    _writeMbtiles(path, (db) {
      db.execute("INSERT INTO metadata VALUES ('name', 't')");
      db.execute("INSERT INTO metadata VALUES ('format', 'png')");
    });
    final r = await MbtilesRasterCheck.validateFile(path);
    expect(r.ok, true);
  });
}
