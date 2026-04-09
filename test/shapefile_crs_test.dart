import 'package:blue_viper_pro/core/geo/shapefile_crs_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj4dart/proj4dart.dart';

void main() {
  test('lastEpsgCodeFromWkt son AUTHORITY', () {
    expect(
      lastEpsgCodeFromWkt(
        'PROJCS["foo",GEOGCS["bar"],PROJECTION["Transverse_Mercator"],'
        'AUTHORITY["EPSG","4326"],AUTHORITY["EPSG","32636"]]',
      ),
      32636,
    );
  });

  test('projectionFromKnownEpsg UTM 36N', () {
    final p = projectionFromKnownEpsg(32636);
    expect(p, isNotNull);
    final wgs = Projection.get('EPSG:4326')!;
    final ankara = p!.transform(wgs, Point(x: 427906.0, y: 4432039.0));
    expect(ankara.y, greaterThan(38));
    expect(ankara.y, lessThan(41));
    expect(ankara.x, greaterThan(31));
    expect(ankara.x, lessThan(35));
  });
}
