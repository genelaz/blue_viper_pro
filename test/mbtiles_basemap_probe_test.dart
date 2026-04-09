import 'dart:io';
import 'dart:typed_data';

import 'package:blue_viper_pro/core/maps/mbtiles_basemap_probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void _writeSqliteMbtiles(String path, void Function(Database db) fill) {
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
    tmp = Directory.systemTemp.createTempSync('mbtiles_probe_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('format=pbf → vector', () async {
    final path = '${tmp.path}/v.mbtiles';
    _writeSqliteMbtiles(path, (db) {
      db.execute("INSERT INTO metadata VALUES ('name', 't')");
      db.execute("INSERT INTO metadata VALUES ('format', 'pbf')");
    });
    final r = await MbtilesBasemapProbe.analyze(path);
    expect(r.ok, true);
    expect(r.kind, MbtilesBasemapKind.vector);
  });

  test('format=png ve gzip karo → vector', () async {
    final path = '${tmp.path}/g.mbtiles';
    _writeSqliteMbtiles(path, (db) {
      db.execute("INSERT INTO metadata VALUES ('name', 't')");
      db.execute("INSERT INTO metadata VALUES ('format', 'png')");
      final gz = Uint8List.fromList([0x1f, 0x8b, 0x08, 0]);
      db.prepare('INSERT INTO tiles VALUES (0,0,0,?)').execute([gz]);
    });
    final r = await MbtilesBasemapProbe.analyze(path);
    expect(r.kind, MbtilesBasemapKind.vector);
  });

  test('format=png ve png imza → raster', () async {
    final path = '${tmp.path}/r.mbtiles';
    _writeSqliteMbtiles(path, (db) {
      db.execute("INSERT INTO metadata VALUES ('name', 't')");
      db.execute("INSERT INTO metadata VALUES ('format', 'png')");
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      db.prepare('INSERT INTO tiles VALUES (0,0,0,?)').execute([png]);
    });
    final r = await MbtilesBasemapProbe.analyze(path);
    expect(r.kind, MbtilesBasemapKind.raster);
  });
}
