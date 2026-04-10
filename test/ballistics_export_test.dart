import 'package:blue_viper_pro/core/ballistics/ballistics_engine.dart';
import 'package:blue_viper_pro/core/ballistics/ballistics_export.dart';
import 'package:blue_viper_pro/core/ballistics/click_units.dart';
import 'package:flutter_test/flutter_test.dart';

BallisticsSolveOutput _solveAt(double distanceM) {
  return BallisticsEngine.solve(
    BallisticsSolveInput.legacyG1(
      distanceMeters: distanceM,
      muzzleVelocityMps: 800,
      ballisticCoefficientG1: 0.45,
      temperatureC: 15,
      pressureHpa: 1013,
      targetElevationDeltaMeters: 0,
      slopeAngleDegrees: 0,
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    ),
  );
}

void main() {
  test('profileCompareToCsv başlık ve temel metrik satırları', () {
    final ref = _solveAt(400);
    final cur = _solveAt(450);
    final csv = profileCompareToCsv(refOut: ref, curOut: cur);
    final lines = csv.trim().split('\n');
    expect(lines.first, 'metric,referans,guncel,delta');
    final metrics = lines.skip(1).map((l) => l.split(',').first).toList();
    expect(metrics, containsAll(<String>[
      'elev_mil',
      'elev_moa',
      'wind_mil',
      'wind_moa',
      'lat_sum_mil',
      'lat_sum_moa',
      'lead_mil',
      'lead_moa',
      'lead_clicks',
      'drop_cm',
      'wind_cm',
      'lead_cm',
      'lat_cm',
    ]));
    expect(lines.length, greaterThan(12));
  });

  test('multiRangeSolveToCsv menzil tablosu CSV ailesiyle uyumlu sütunlar', () {
    final o = _solveAt(300);
    final csv = multiRangeSolveToCsv([(300, o)]);
    final header = csv.trim().split('\n').first.split(',');
    expect(header.first, 'range_m');
    expect(header, containsAll(<String>[
      'drop_moa',
      'wind_moa',
      'lead_moa',
      'lat_total_moa',
      'lead_clicks',
      'drop_cm',
      'wind_cm',
      'lead_cm',
      'lat_total_cm',
    ]));
    final data = csv.trim().split('\n')[1].split(',');
    expect(data.length, header.length);
    expect(data.first, '300');
  });

  test('rangeTableToCsv lead_clicks sütunu (RangeTableRow)', () {
    final o = _solveAt(275);
    final row = RangeTableRow.fromSolveOutput(275, o);
    final csv = rangeTableToCsv([row]);
    final header = csv.trim().split('\n').first.split(',');
    expect(header, contains('lead_clicks'));
    expect(header, contains('lead_cm'));
    expect(header.indexOf('wind_cm'), lessThan(header.indexOf('lead_cm')));
    expect(header.indexOf('lead_cm'), lessThan(header.indexOf('lat_total_cm')));
    expect(header.indexOf('lead_clicks'), lessThan(header.indexOf('lat_total_clicks')));
    final data = csv.trim().split('\n')[1].split(',');
    expect(data.length, header.length);
  });

  test('savedTargetSolvesToCsv isim + delta_h + genişletilmiş satır', () {
    final o = _solveAt(250);
    final csv = savedTargetSolvesToCsv([
      ('Hedef-A', 250, 2.5, o),
    ]);
    final lines = csv.trim().split('\n');
    expect(lines.first.split(',').first, 'name');
    expect(lines.first, contains('drop_cm'));
    expect(lines.first, contains('lead_cm'));
    expect(lines.first, contains('lat_total_moa'));
    expect(lines[1].startsWith('Hedef-A,250'), isTrue);
    expect(lines[1], contains(',2.5,'));
    expect(lines[1].split(',').length, lines.first.split(',').length);
  });
}
