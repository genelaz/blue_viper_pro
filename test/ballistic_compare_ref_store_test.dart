import 'package:blue_viper_pro/core/ballistics/ballistic_compare_ref_store.dart';
import 'package:blue_viper_pro/core/ballistics/ballistics_engine.dart';
import 'package:blue_viper_pro/core/ballistics/bc_kind.dart';
import 'package:blue_viper_pro/core/ballistics/bc_mach_segment.dart';
import 'package:blue_viper_pro/core/ballistics/click_units.dart';
import 'package:blue_viper_pro/core/ballistics/powder_temperature.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save / load round-trip preserves solve inputs', () async {
    final input = BallisticsSolveInput(
      distanceMeters: 440,
      muzzleVelocityMps: 815,
      bcKind: BcKind.g7,
      ballisticCoefficient: 0.311,
      temperatureC: 18,
      pressureHpa: 1008,
      relativeHumidityPercent: 40,
      densityAltitudeMeters: 500,
      targetElevationDeltaMeters: 15,
      slopeAngleDegrees: 3,
      sightHeightMeters: 0.042,
      zeroRangeMeters: 100,
      crossWindMps: 5,
      enableCoriolis: true,
      latitudeDegrees: 39.2,
      azimuthFromNorthDegrees: 45,
      enableSpinDrift: true,
      riflingTwistSign: 1,
      bulletMassGrains: 140,
      bulletCaliberInches: 0.264,
      twistInchesPerTurn: 8,
      enableAerodynamicJump: false,
      clickUnit: ClickUnit.moa,
      clickValue: 0.25,
      powderTempVelocityPairs: const [
        TempVelocityPair(tempC: 0, velocityMps: 800),
        TempVelocityPair(tempC: 25, velocityMps: 820),
      ],
      powderTemperatureC: 12,
      bcMachSegments: const [
        BcMachSegment(machMin: 2.0, bc: 0.34),
        BcMachSegment(machMin: 0.9, bc: 0.30),
        BcMachSegment(machMin: 0.0, bc: 0.28),
      ],
      customDragMachNodes: const [0.5, 1.2],
      customDragI: const [0.4, 0.55],
      targetCrossTrackMps: 1.5,
    );
    await BallisticCompareRefStore.save(input);
    final back = await BallisticCompareRefStore.load();
    expect(back, isNotNull);
    expect(back!.muzzleVelocityMps, input.muzzleVelocityMps);
    expect(back.bcKind, input.bcKind);
    expect(back.ballisticCoefficient, input.ballisticCoefficient);
    expect(back.sightHeightMeters, input.sightHeightMeters);
    expect(back.powderTempVelocityPairs.length, 2);
    expect(back.bcMachSegments?.length, 3);
    expect(back.customDragMachNodes, input.customDragMachNodes);
    expect(back.clickUnit, ClickUnit.moa);
    await BallisticCompareRefStore.clear();
    expect(await BallisticCompareRefStore.load(), isNull);
  });
}
