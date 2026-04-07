import 'package:blue_viper_pro/core/ballistics/ballistics_engine.dart';
import 'package:blue_viper_pro/core/ballistics/bc_mach_segment.dart';
import 'package:blue_viper_pro/core/ballistics/click_units.dart';
import 'package:blue_viper_pro/core/ballistics/custom_drag_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Parçalı BC ve özel i(M) ayrıştırma', () {
    final segs = parseBcMachSegments('3.0 0.28\n1.0 0.25\n0.0 0.22');
    expect(segs, isNotNull);
    expect(segs!.length, 3);
    final tab = parseCustomDragTable('0.5 0.3\n2.0 0.5');
    expect(tab, isNotNull);
    expect(tab!.machs.length, 2);
  });

  test('G1 nokta-kütle: 800 m/s, BC 0,45 @ 500 m — makul düşüş aralığı', () {
    final out = BallisticsEngine.solve(
      BallisticsSolveInput.legacyG1(
        distanceMeters: 500,
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
    final dropM = out.dropMil * 500 / 1000;
    expect(out.timeOfFlightMs, greaterThan(550));
    expect(out.timeOfFlightMs, lessThan(950));
    expect(dropM, greaterThan(1.2));
    expect(dropM, lessThan(8.0));
  });

  test('Hareketli hedef öncüsü sıfır değil', () {
    final out = BallisticsEngine.solve(
      BallisticsSolveInput(
        distanceMeters: 400,
        muzzleVelocityMps: 800,
        ballisticCoefficient: 0.45,
        clickUnit: ClickUnit.mil,
        clickValue: 0.1,
        targetCrossTrackMps: 2.0,
      ),
    );
    expect(out.leadMil.abs(), greaterThan(0.01));
    expect(out.combinedLateralMil, greaterThan(out.windMil));
  });
}
