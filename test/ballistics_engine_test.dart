import 'package:blue_viper_pro/core/ballistics/ballistics_engine.dart';
import 'package:blue_viper_pro/core/ballistics/bc_kind.dart';
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
    final dropM = out.verticalHoldDeltaMeters;
    expect(out.timeOfFlightMs, greaterThan(550));
    expect(out.timeOfFlightMs, lessThan(950));
    expect(dropM, greaterThan(1.2));
    expect(dropM, lessThan(8.0));
  });

  test('withShotConditionsFrom korur Vo/BC, atış koşulunu shot’tan alır', () {
    final ref = BallisticsSolveInput(
      distanceMeters: 100,
      muzzleVelocityMps: 800,
      ballisticCoefficient: 0.45,
      bcKind: BcKind.g1,
      temperatureC: -12,
      pressureHpa: 990,
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    );
    final shot = BallisticsSolveInput(
      distanceMeters: 520,
      muzzleVelocityMps: 950,
      ballisticCoefficient: 0.22,
      bcKind: BcKind.g7,
      temperatureC: 22,
      pressureHpa: 1015,
      targetElevationDeltaMeters: 12,
      crossWindMps: 4,
      clickUnit: ClickUnit.mil,
      clickValue: 0.2,
    );
    final m = ref.withShotConditionsFrom(shot);
    expect(m.muzzleVelocityMps, 800);
    expect(m.ballisticCoefficient, 0.45);
    expect(m.bcKind, BcKind.g1);
    expect(m.distanceMeters, 520);
    expect(m.temperatureC, 22);
    expect(m.pressureHpa, 1015);
    expect(m.targetElevationDeltaMeters, 12);
    expect(m.crossWindMps, 4);
    expect(m.clickUnit, ClickUnit.mil);
    expect(m.clickValue, 0.2);
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
