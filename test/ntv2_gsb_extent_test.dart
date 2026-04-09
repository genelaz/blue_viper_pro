import 'package:blue_viper_pro/core/geo/ntv2_gsb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('coversWgs84 matches shiftWgs84 boundary (inclusive corners)', () {
    final g = Ntv2GsbShift.debugEmptyGridForExtent(
      latCount: 3,
      lonCount: 4,
      southDeg: 36.0,
      westDeg: 26.0,
      latStepDeg: 1.0,
      lonStepDeg: 0.5,
    );
    expect(g.northDeg, 38.0);
    expect(g.eastDeg, 27.5);
    expect(g.coversWgs84(const LatLng(36.0, 26.0)), isTrue);
    expect(g.coversWgs84(const LatLng(38.0, 27.5)), isTrue);
    expect(g.coversWgs84(const LatLng(35.9, 26.0)), isFalse);
    expect(g.coversWgs84(const LatLng(36.0, 25.9)), isFalse);
  });

  test('extentSummaryDegrees formats range', () {
    final g = Ntv2GsbShift.debugEmptyGridForExtent(
      latCount: 2,
      lonCount: 2,
      southDeg: 40.12,
      westDeg: 29.5,
      latStepDeg: 0.25,
      lonStepDeg: 0.25,
    );
    expect(g.extentSummaryDegrees(decimals: 2), '40.12–40.37°N, 29.50–29.75°E');
  });
}
