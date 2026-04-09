import 'package:blue_viper_pro/core/geo/geo_measure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('sphericalPolygonWithHolesAreaM2 subtracts hole', () {
    final outer = [
      LatLng(39.9, 32.0),
      LatLng(39.9, 32.2),
      LatLng(40.1, 32.2),
      LatLng(40.1, 32.0),
      LatLng(39.9, 32.0),
    ];
    final hole = [
      LatLng(39.95, 32.05),
      LatLng(39.95, 32.15),
      LatLng(40.05, 32.15),
      LatLng(40.05, 32.05),
      LatLng(39.95, 32.05),
    ];
    final full = sphericalPolygonAreaM2(outer);
    final withHole = sphericalPolygonWithHolesAreaM2(outer, [hole]);
    expect(withHole, lessThan(full));
    expect(withHole, greaterThan(0));
  });
}
