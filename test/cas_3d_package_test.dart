import 'package:blue_viper_pro/core/geo/cas_3d_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseCas3dPackageJson parses threat tubes', () {
    const raw = '''
{
  "name": "CAS Demo",
  "version": "1.0",
  "threatTubes": [
    {
      "id": "tube-1",
      "observer": {"lat": 39.93, "lon": 32.86},
      "target": {"lat": 39.95, "lon": 32.90},
      "startHalfWidthM": 30,
      "endHalfWidthM": 120,
      "minAltM": 10,
      "maxAltM": 350
    }
  ]
}
''';
    final p = parseCas3dPackageJson(raw);
    expect(p.name, 'CAS Demo');
    expect(p.threatTubes.length, 1);
    expect(p.threatTubes.first.startHalfWidthM, 30);
    expect(p.threatTubes.first.endHalfWidthM, 120);
    final fp = casThreatTubeFootprint(p.threatTubes.first);
    expect(fp.length, 4);
  });

  test('parseCas3dPackageJson validates required fields', () {
    const raw = '{"name":"x","threatTubes":[{"id":"a"}]}';
    expect(
      () => parseCas3dPackageJson(raw),
      throwsA(isA<FormatException>()),
    );
  });
}
