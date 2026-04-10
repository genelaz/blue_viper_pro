import 'dart:math' as math;

/// Mil gösterimi: küçük açı yaklaşımı (klasik) veya gerçek açı.
enum AngularMilConvention {
  /// \((\Delta / R) \times 1000\)
  linear,

  /// \(\operatorname{atan2}(\Delta, R) \times 1000\) mrad
  trueAngle,
}

/// Dikey/yatay MOA gösterimi (tıklar mil üzerinden kalır).
enum MoaDisplayConvention {
  /// Mevcut: `mil × 3.438`
  legacyFromMil,

  /// Gerçek yay dakikası: \(mil \times \frac{180 \times 60}{\pi \times 1000}\)
  trueArcminute,

  /// «Shooter» MOA: inç / (100 yd başına) / 1.047
  shooterInchesPer100Yd,
}

double milFromLateralMeters({
  required double deltaM,
  required double rangeM,
  required AngularMilConvention convention,
}) {
  if (rangeM <= 0 || !deltaM.isFinite || !rangeM.isFinite) return 0;
  return switch (convention) {
    AngularMilConvention.linear => deltaM / rangeM * 1000.0,
    AngularMilConvention.trueAngle => math.atan2(deltaM, rangeM) * 1000.0,
  };
}

double moaFromMilAndGeometry({
  required double mil,
  required double deltaM,
  required double rangeM,
  required MoaDisplayConvention convention,
}) {
  return switch (convention) {
    MoaDisplayConvention.legacyFromMil => mil * 3.438,
    MoaDisplayConvention.trueArcminute => mil * (180.0 * 60.0) / (math.pi * 1000.0),
    MoaDisplayConvention.shooterInchesPer100Yd => shooterMoaFromDelta(deltaM, rangeM),
  };
}

/// IPHY: sapma inç / (menzil yd / 100) / 1.047
double shooterMoaFromDelta(double deltaM, double rangeM) {
  if (rangeM <= 0 || !deltaM.isFinite || !rangeM.isFinite) return 0;
  const inchPerM = 39.3700787;
  const ydPerM = 1.0 / 0.9144;
  final deltaIn = deltaM * inchPerM;
  final rangeYd = rangeM * ydPerM;
  if (rangeYd <= 0) return 0;
  return deltaIn / (rangeYd / 100.0) / 1.047;
}

/// Gözlenen dikey tutma (MOA, [moaConvention] anlamında) → [milFromLateralMeters] ile aynı mil çerçevesi.
double observationMoaToCorrectionMil({
  required double observationMoa,
  required double rangeMeters,
  required MoaDisplayConvention moaConvention,
  required AngularMilConvention angularConvention,
}) {
  if (!observationMoa.isFinite || rangeMeters <= 0) return 0;
  switch (moaConvention) {
    case MoaDisplayConvention.legacyFromMil:
      return observationMoa / 3.438;
    case MoaDisplayConvention.trueArcminute:
      final tanAng = math.tan(observationMoa * math.pi / (180.0 * 60.0));
      final deltaM = rangeMeters * tanAng;
      return milFromLateralMeters(
        deltaM: deltaM,
        rangeM: rangeMeters,
        convention: angularConvention,
      );
    case MoaDisplayConvention.shooterInchesPer100Yd:
      const ydPerM = 1.0 / 0.9144;
      final rangeYd = rangeMeters * ydPerM;
      if (rangeYd <= 0) return 0;
      final deltaIn = observationMoa * 1.047 * (rangeYd / 100.0);
      final deltaM = deltaIn * 0.0254;
      return milFromLateralMeters(
        deltaM: deltaM,
        rangeM: rangeMeters,
        convention: angularConvention,
      );
  }
}

