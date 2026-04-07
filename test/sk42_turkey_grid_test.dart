import 'package:blue_viper_pro/core/geo/sk42_turkey_grid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('SK-42 grid gidiş-dönüş (Ankara yakını)', () {
    const wgs = LatLng(39.925533, 32.866287);
    const cm = 33;
    final (e, n) = Sk42TurkeyGrid.wgs84ToGrid(wgs, cm);
    final back = Sk42TurkeyGrid.gridToWgs84(easting: e, northing: n, centralMeridian: cm);
    expect((back.latitude - wgs.latitude).abs(), lessThan(1e-4));
    expect((back.longitude - wgs.longitude).abs(), lessThan(1e-4));
  });

  test('pickMeridian en yakın dilim', () {
    expect(Sk42TurkeyGrid.pickMeridian(32.8), 33);
    expect(Sk42TurkeyGrid.pickMeridian(29.0), 30);
  });
}
