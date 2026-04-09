import 'package:blue_viper_pro/core/ballistics/ballistics_engine.dart';
import 'package:blue_viper_pro/core/ballistics/bc_kind.dart';
import 'package:blue_viper_pro/core/ballistics/bc_mach_segment.dart';
import 'package:blue_viper_pro/core/ballistics/click_units.dart';
import 'package:blue_viper_pro/core/ballistics/powder_temperature.dart';
import 'package:flutter_test/flutter_test.dart';

BallisticsSolveInput _matrixBase({
  required double distanceMeters,
  required double muzzleVelocityMps,
  BcKind bcKind = BcKind.g1,
  required double ballisticCoefficient,
  double temperatureC = 15,
  double pressureHpa = 1013,
  double relativeHumidityPercent = 0,
  double? densityAltitudeMeters,
  double targetElevationDeltaMeters = 0,
  double slopeAngleDegrees = 0,
  double crossWindMps = 0,
  List<TempVelocityPair> powderTempVelocityPairs = const [],
  double? powderTemperatureC,
  List<BcMachSegment>? bcMachSegments,
}) {
  return BallisticsSolveInput(
    distanceMeters: distanceMeters,
    muzzleVelocityMps: muzzleVelocityMps,
    bcKind: bcKind,
    ballisticCoefficient: ballisticCoefficient,
    temperatureC: temperatureC,
    pressureHpa: pressureHpa,
    relativeHumidityPercent: relativeHumidityPercent,
    densityAltitudeMeters: densityAltitudeMeters,
    targetElevationDeltaMeters: targetElevationDeltaMeters,
    slopeAngleDegrees: slopeAngleDegrees,
    crossWindMps: crossWindMps,
    clickUnit: ClickUnit.mil,
    clickValue: 0.1,
    powderTempVelocityPairs: powderTempVelocityPairs,
    powderTemperatureC: powderTemperatureC,
    bcMachSegments: bcMachSegments,
  );
}

void main() {
  group('Atmosfer monotonluk (kalibrasyon)', () {
    test('daha sıcak hava — aynı basınçta düşüş ve uçuş süresi azalır', () {
      final cold = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 600,
          muzzleVelocityMps: 810,
          ballisticCoefficient: 0.44,
          temperatureC: -18,
          pressureHpa: 1013,
        ),
      );
      final hot = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 600,
          muzzleVelocityMps: 810,
          ballisticCoefficient: 0.44,
          temperatureC: 38,
          pressureHpa: 1013,
        ),
      );
      expect(hot.dropMil, lessThan(cold.dropMil));
      expect(hot.timeOfFlightMs, lessThan(cold.timeOfFlightMs));
    });

    test('daha yüksek basınç — daha çok düşüş ve daha uzun uçuş', () {
      final lowP = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 550,
          muzzleVelocityMps: 795,
          ballisticCoefficient: 0.47,
          temperatureC: 12,
          pressureHpa: 985,
        ),
      );
      final highP = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 550,
          muzzleVelocityMps: 795,
          ballisticCoefficient: 0.47,
          temperatureC: 12,
          pressureHpa: 1035,
        ),
      );
      expect(highP.dropMil, greaterThan(lowP.dropMil));
      expect(highP.timeOfFlightMs, greaterThan(lowP.timeOfFlightMs));
    });

    test('yoğunluk irtifası arttıkça sürtünme azalır — düşüş azalır', () {
      final sl = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 500,
          muzzleVelocityMps: 780,
          ballisticCoefficient: 0.41,
          densityAltitudeMeters: 0,
        ),
      );
      final highDa = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 500,
          muzzleVelocityMps: 780,
          ballisticCoefficient: 0.41,
          densityAltitudeMeters: 2800,
        ),
      );
      expect(highDa.dropMil, lessThan(sl.dropMil));
      expect(highDa.timeOfFlightMs, lessThan(sl.timeOfFlightMs));
    });

    test('yüksek nem — sıcak havada kuru havaya göre biraz daha az düşüş', () {
      final dry = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 500,
          muzzleVelocityMps: 805,
          ballisticCoefficient: 0.43,
          temperatureC: 32,
          pressureHpa: 1010,
          relativeHumidityPercent: 5,
        ),
      );
      final humid = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 500,
          muzzleVelocityMps: 805,
          ballisticCoefficient: 0.43,
          temperatureC: 32,
          pressureHpa: 1010,
          relativeHumidityPercent: 92,
        ),
      );
      expect(humid.dropMil, lessThan(dry.dropMil));
    });

    test('barut sıcaklığı tablosu — soğuk barut daha düşük MV ile daha çok düşüş', () {
      const pairs = [
        TempVelocityPair(tempC: -15, velocityMps: 765),
        TempVelocityPair(tempC: 25, velocityMps: 805),
      ];
      final warmPowder = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 500,
          muzzleVelocityMps: 800,
          ballisticCoefficient: 0.45,
          powderTempVelocityPairs: pairs,
          powderTemperatureC: 24,
        ),
      );
      final coldPowder = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 500,
          muzzleVelocityMps: 800,
          ballisticCoefficient: 0.45,
          powderTempVelocityPairs: pairs,
          powderTemperatureC: -14,
        ),
      );
      expect(coldPowder.adjustedMuzzleVelocityMps, lessThan(warmPowder.adjustedMuzzleVelocityMps));
      expect(coldPowder.dropMil, greaterThan(warmPowder.dropMil));
    });
  });

  group('Senaryo matrisi — makul çıktı sınırları', () {
    final scenarios = <({
      String name,
      BallisticsSolveInput input,
      double tofMin,
      double tofMax,
      double dropMilMin,
      double dropMilMax,
    })>[
      (
        name: 'G1 .308 benzeri, deniz seviyesi',
        input: _matrixBase(
          distanceMeters: 650,
          muzzleVelocityMps: 808,
          ballisticCoefficient: 0.45,
          temperatureC: 15,
          pressureHpa: 1013,
        ),
        tofMin: 700,
        tofMax: 1500,
        dropMilMin: 4,
        dropMilMax: 28,
      ),
      (
        name: 'G1 soğuk yüksek basınç',
        input: _matrixBase(
          distanceMeters: 650,
          muzzleVelocityMps: 808,
          ballisticCoefficient: 0.45,
          temperatureC: -22,
          pressureHpa: 1040,
        ),
        tofMin: 750,
        tofMax: 1600,
        dropMilMin: 4,
        dropMilMax: 32,
      ),
      (
        name: 'G7 6.5 benzeri, sıcak ince hava',
        input: _matrixBase(
          distanceMeters: 800,
          muzzleVelocityMps: 875,
          bcKind: BcKind.g7,
          ballisticCoefficient: 0.27,
          temperatureC: 28,
          pressureHpa: 995,
          densityAltitudeMeters: 1200,
        ),
        tofMin: 820,
        tofMax: 1700,
        dropMilMin: 5,
        dropMilMax: 35,
      ),
      (
        name: 'G1 yan rüzgâr — yatay düzeltme artar, düşüş benzer bantta',
        input: _matrixBase(
          distanceMeters: 600,
          muzzleVelocityMps: 820,
          ballisticCoefficient: 0.42,
          crossWindMps: 9,
        ),
        tofMin: 650,
        tofMax: 1450,
        dropMilMin: 3,
        dropMilMax: 26,
      ),
      (
        name: 'Hedef üst kot + eğim (delta + slope)',
        input: _matrixBase(
          distanceMeters: 450,
          muzzleVelocityMps: 790,
          ballisticCoefficient: 0.4,
          targetElevationDeltaMeters: 55,
          slopeAngleDegrees: 6,
        ),
        tofMin: 480,
        tofMax: 1150,
        dropMilMin: 1,
        dropMilMax: 20,
      ),
      (
        name: 'Parçalı BC (yüksek Mach’tan düşüğe)',
        input: _matrixBase(
          distanceMeters: 700,
          muzzleVelocityMps: 840,
          ballisticCoefficient: 0.35,
          bcMachSegments: const [
            BcMachSegment(machMin: 2.2, bc: 0.42),
            BcMachSegment(machMin: 1.0, bc: 0.38),
            BcMachSegment(machMin: 0.0, bc: 0.33),
          ],
        ),
        tofMin: 720,
        tofMax: 1550,
        dropMilMin: 4,
        dropMilMax: 30,
      ),
    ];

    for (final s in scenarios) {
      test(s.name, () {
        final out = BallisticsEngine.solve(s.input);
        expect(out.timeOfFlightMs, greaterThanOrEqualTo(s.tofMin));
        expect(out.timeOfFlightMs, lessThanOrEqualTo(s.tofMax));
        expect(out.dropMil, greaterThanOrEqualTo(s.dropMilMin));
        expect(out.dropMil, lessThanOrEqualTo(s.dropMilMax));
        expect(out.adjustedMuzzleVelocityMps, greaterThan(100));
        expect(out.appliedBallisticCoefficient, greaterThan(0.02));
      });
    }
  });

  group('G1 / G7 aynı menzilde tutarlılık', () {
    test('G7 düşük sayısal BC ile G1 orta BC benzer menzilde sonuç üretir', () {
      final g1 = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 500,
          muzzleVelocityMps: 800,
          bcKind: BcKind.g1,
          ballisticCoefficient: 0.45,
        ),
      );
      final g7 = BallisticsEngine.solve(
        _matrixBase(
          distanceMeters: 500,
          muzzleVelocityMps: 800,
          bcKind: BcKind.g7,
          ballisticCoefficient: 0.255,
        ),
      );
      final ratio = g7.dropMil / g1.dropMil;
      expect(ratio, greaterThan(0.75));
      expect(ratio, lessThan(1.35));
    });
  });
}
