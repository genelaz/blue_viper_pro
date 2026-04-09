import 'package:blue_viper_pro/core/maps/map_coordinate_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WGS ızgarası çizgi üretir, boş alan döndürmez', () {
    final segs = MapCoordinateGrid.wgs84LineSegments(
      south: 39.8,
      north: 40.2,
      west: 32.8,
      east: 33.2,
      zoom: 12,
    );
    expect(segs, isNotEmpty);
    expect(segs.every((e) => e.length == 2), isTrue);
  });

  test('UTM kuzey ızgarası (Türkiye) çizgi üretir', () {
    final segs = MapCoordinateGrid.utmNorthLineSegments(
      south: 39.8,
      north: 40.2,
      west: 32.8,
      east: 33.2,
      zoom: 12,
      utmZone: 36,
    );
    expect(segs, isNotEmpty);
    expect(segs.every((e) => e.length >= 2), isTrue);
  });

  test('Güney yarıkürede UTM kuzey ızgarası boş', () {
    final segs = MapCoordinateGrid.utmNorthLineSegments(
      south: -35.0,
      north: -34.0,
      west: 149.0,
      east: 150.0,
      zoom: 10,
      utmZone: 55,
    );
    expect(segs, isEmpty);
  });

  test('Geçersiz zon boş döner', () {
    final segs = MapCoordinateGrid.utmNorthLineSegments(
      south: 39.0,
      north: 40.0,
      west: 32.0,
      east: 33.0,
      zoom: 10,
      utmZone: 0,
    );
    expect(segs, isEmpty);
  });
}
