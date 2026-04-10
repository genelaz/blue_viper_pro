import 'dart:math' as math;

import 'ballistics_output_convention.dart';

enum ClickUnit {
  mil,
  moa,
  cmPer100m,
  inPer100yd,
}

extension ClickUnitLabel on ClickUnit {
  String get label => switch (this) {
        ClickUnit.mil => 'MIL (mrad)',
        ClickUnit.moa => 'MOA',
        ClickUnit.cmPer100m => 'cm / 100m',
        ClickUnit.inPer100yd => 'in / 100yd',
      };
}

/// Bir MOA kliğinin (veya alt bölümünün) ürettiği «düzeltme mili» — [correctionMil] ile aynı
/// [angularMilConvention] içinde ifade edilir.
double perClickMilForMoaScopeClick({
  required double clickValue,
  required MoaDisplayConvention moaClickConvention,
  required AngularMilConvention angularMilConvention,
}) {
  if (clickValue <= 0 || !clickValue.isFinite) return 0;
  switch (moaClickConvention) {
    case MoaDisplayConvention.legacyFromMil:
      // Eski mil×3.438 gösterimiyle aynı ölçek.
      return clickValue / 3.438;
    case MoaDisplayConvention.trueArcminute:
      final tanAng = math.tan(clickValue * math.pi / (180.0 * 60.0));
      return switch (angularMilConvention) {
        AngularMilConvention.linear => tanAng * 1000.0,
        AngularMilConvention.trueAngle => math.atan2(tanAng, 1.0) * 1000.0,
      };
    case MoaDisplayConvention.shooterInchesPer100Yd:
      final deltaOverR = clickValue * 1.047 * 0.0254 / (100.0 * 0.9144);
      return switch (angularMilConvention) {
        AngularMilConvention.linear => deltaOverR * 1000.0,
        AngularMilConvention.trueAngle => math.atan2(deltaOverR, 1.0) * 1000.0,
      };
  }
}

/// Düzeltme ([milFromLateralMeters] ile üretilen correction mil) için klik sayısı.
///
/// [clickUnit] `moa` iken [moaClickConvention] ve [angularMilConvention], dürbün taksimatının
/// anlamı ile çözümdeki mil tanımını hizalar.
double clicksForCorrectionMil({
  required double correctionMil,
  required ClickUnit clickUnit,
  required double clickValue,
  MoaDisplayConvention moaClickConvention = MoaDisplayConvention.legacyFromMil,
  AngularMilConvention angularMilConvention = AngularMilConvention.linear,
}) {
  double perClickMil() {
    switch (clickUnit) {
      case ClickUnit.mil:
        return clickValue;
      case ClickUnit.moa:
        return perClickMilForMoaScopeClick(
          clickValue: clickValue,
          moaClickConvention: moaClickConvention,
          angularMilConvention: angularMilConvention,
        );
      case ClickUnit.cmPer100m:
        return clickValue / 10.0;
      case ClickUnit.inPer100yd:
        return clickValue / 3.6;
    }
  }

  final v = perClickMil();
  if (v <= 0) return 0;
  return correctionMil / v;
}
