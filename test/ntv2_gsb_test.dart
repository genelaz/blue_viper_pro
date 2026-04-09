import 'dart:convert';
import 'dart:typed_data';

import 'package:blue_viper_pro/core/geo/ntv2_gsb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('Ntv2GsbShift.tryParse minimal tail grid', () {
    final header = '''
NUM_OREC  11
VERSION   NTv2.0
NTv2
LAT_COUNT 2
LONG_COUNT 2
S_LAT     0
N_LAT     3600
W_LONG    0
E_LONG    3600
LAT_INC   1800
LONG_INC  1800
${'#' * 280}
''';
    final h = latin1.encode(header);
    final grid = Uint8List(32);
    final all = Uint8List(h.length + grid.length);
    all.setAll(0, h);
    all.setAll(h.length, grid);
    final g = Ntv2GsbShift.tryParse(all);
    expect(g, isNotNull);
    expect(g!.latCount, 2);
    expect(g.lonCount, 2);
    final s = g.shiftWgs84(const LatLng(0.25, 0.25));
    expect(s.latitude, closeTo(0.25, 1e-6));
  });
}
