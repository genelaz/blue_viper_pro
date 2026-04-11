import 'dart:math' as math;

import 'atmosphere.dart';
import 'g1_drag.dart' show airDensityKgPerM3;

/// Coriolis + spin drift + aerodynamic jump (yaklaşık, küçük açı).
class SecondaryCorrections {
  final double coriolisLateralM;
  final double coriolisVerticalM;
  final double spinDriftM;
  final double aeroJumpVerticalM;

  const SecondaryCorrections({
    required this.coriolisLateralM,
    required this.coriolisVerticalM,
    required this.spinDriftM,
    required this.aeroJumpVerticalM,
  });
}

/// [latitudeDeg] enlem (kuzey +), [azimuthFromNorthDeg] atış yönü (kuzeyden saat yönü).
/// [rangeM] yatay menzil, [tofS] uçuş süresi, [avgVelocityMps] ortalama hız yaklaşımı.
/// [temperatureC] / [pressureHpa] / [relativeHumidityPercent]: Miller SF için çözüm ortamı
/// (önceden sabit 15 °C / 29,92 inHg idi; ana balistik ile uyumlu).
SecondaryCorrections computeSecondaryCorrections({
  required bool enableCoriolis,
  required double latitudeDeg,
  required double azimuthFromNorthDeg,
  required double rangeM,
  required double tofS,
  required double avgVelocityMps,
  required bool enableSpinDrift,
  required int twistDirection,
  required double? bulletMassGrains,
  required double? caliberInches,
  required double? twistInchesPerTurn,
  required bool enableAeroJump,
  required double crossWindMps,
  required double temperatureC,
  required double pressureHpa,
  double relativeHumidityPercent = 0,
}) {
  var coriolisLateral = 0.0;
  var coriolisVertical = 0.0;
  if (enableCoriolis && tofS > 1e-6 && rangeM > 1) {
    final lat = latitudeDeg * math.pi / 180.0;
    final az = azimuthFromNorthDeg * math.pi / 180.0;
    const omega = 7.2921159e-5;
    coriolisLateral =
        omega * rangeM * tofS * math.sin(lat) * math.sin(az + math.pi / 2);
    coriolisVertical =
        omega * rangeM * tofS * math.cos(lat) * math.sin(az) * 0.15;
  }

  var spin = 0.0;
  if (enableSpinDrift && tofS > 1e-6) {
    var sf = 1.35;
    final m = bulletMassGrains;
    final d = caliberInches;
    final t = twistInchesPerTurn;
    if (m != null && d != null && t != null && m > 0 && d > 0 && t > 0) {
      var pInHg = pressureHpa * 0.029529983071445;
      final tempF = temperatureC * 9.0 / 5.0 + 32.0;
      if (relativeHumidityPercent > 0.5) {
        final tempK = temperatureC + 273.15;
        final pPa = pressureHpa * 100.0;
        final rhoW = humidAirDensityKgPerM3(
          pressurePa: pPa,
          tempK: tempK,
          relativeHumidityPercent: relativeHumidityPercent,
        );
        final rhoD = airDensityKgPerM3(pressurePa: pPa, tempK: tempK);
        if (rhoD > 1e-9 && rhoW > 1e-9) {
          // Nemli hava daha seyrek; Miller f basıncına oransal yansıtılır.
          pInHg *= (rhoW / rhoD).clamp(0.88, 1.0);
        }
      }
      sf = _millerStabilityApprox(
        massGrains: m,
        caliberIn: d,
        twistIn: t,
        muzzleVelocityFps: avgVelocityMps * 3.28084,
        tempF: tempF,
        pressureInHg: pInHg,
      ).clamp(1.05, 3.0);
    }
    final sign = twistDirection >= 0 ? 1.0 : -1.0;
    spin = sign * 0.00085 * math.pow(tofS, 1.28) * math.sqrt(sf);
  }

  var jump = 0.0;
  if (enableAeroJump && crossWindMps.abs() > 1e-6 && avgVelocityMps > 1) {
    jump = -0.00012 * crossWindMps * (avgVelocityMps / 340.0);
  }

  return SecondaryCorrections(
    coriolisLateralM: coriolisLateral,
    coriolisVerticalM: coriolisVertical,
    spinDriftM: spin,
    aeroJumpVerticalM: jump,
  );
}

/// StreLok tarzı **SF** göstergesi (Miller yeşil skor, ~1,3–2,5 tipik).
/// [bulletMassGrains] / [caliberInches] / [twistInchesPerTurn] eksikse `null`.
double? millerStabilityFactorGreen({
  required double? bulletMassGrains,
  required double? caliberInches,
  required double? twistInchesPerTurn,
  required double avgVelocityMps,
  required double temperatureC,
  required double pressureHpa,
  double relativeHumidityPercent = 0,
}) {
  final m = bulletMassGrains;
  final d = caliberInches;
  final t = twistInchesPerTurn;
  if (m == null || d == null || t == null || m <= 0 || d <= 0 || t <= 0) return null;
  var pInHg = pressureHpa * 0.029529983071445;
  final tempF = temperatureC * 9.0 / 5.0 + 32.0;
  if (relativeHumidityPercent > 0.5) {
    final tempK = temperatureC + 273.15;
    final pPa = pressureHpa * 100.0;
    final rhoW = humidAirDensityKgPerM3(
      pressurePa: pPa,
      tempK: tempK,
      relativeHumidityPercent: relativeHumidityPercent,
    );
    final rhoD = airDensityKgPerM3(pressurePa: pPa, tempK: tempK);
    if (rhoD > 1e-9 && rhoW > 1e-9) {
      pInHg *= (rhoW / rhoD).clamp(0.88, 1.0);
    }
  }
  return _millerStabilityApprox(
    massGrains: m,
    caliberIn: d,
    twistIn: t,
    muzzleVelocityFps: avgVelocityMps * 3.28084,
    tempF: tempF,
    pressureInHg: pInHg,
  );
}

/// Basitleştirilmiş Miller kuralı (SF₁, yeşil skor).
double _millerStabilityApprox({
  required double massGrains,
  required double caliberIn,
  required double twistIn,
  required double muzzleVelocityFps,
  required double tempF,
  required double pressureInHg,
}) {
  final t = tempF + 460;
  final p = pressureInHg / 29.92;
  final l = massGrains * math.pow(caliberIn, -2) *
      math.pow(twistIn, -1) *
      math.pow(muzzleVelocityFps / 2800, 1.0 / 3.0);
  final f = math.pow(t / 519.0, 1.2) * p;
  return 1.07 * l / f;
}
