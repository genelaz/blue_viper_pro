import 'dart:math' as math;

import 'package:blue_viper_pro/core/ballistics/ballistics_output_convention.dart';
import 'package:blue_viper_pro/core/ballistics/click_units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('observationMoaToCorrectionMil legacy matches obs/3.438', () {
    final m = observationMoaToCorrectionMil(
      observationMoa: 3.438,
      rangeMeters: 500,
      moaConvention: MoaDisplayConvention.legacyFromMil,
      angularConvention: AngularMilConvention.linear,
    );
    expect(m, closeTo(1.0, 1e-9));
  });

  test('MOA legacy per-click mil matches 1/3.438 scale', () {
    final v = perClickMilForMoaScopeClick(
      clickValue: 0.25,
      moaClickConvention: MoaDisplayConvention.legacyFromMil,
      angularMilConvention: AngularMilConvention.linear,
    );
    expect(v, closeTo(0.25 / 3.438, 1e-9));
  });

  test('true arcminute + linear ≈ tan(α)×1000; differs slightly from legacy', () {
    final vTrue = perClickMilForMoaScopeClick(
      clickValue: 1.0,
      moaClickConvention: MoaDisplayConvention.trueArcminute,
      angularMilConvention: AngularMilConvention.linear,
    );
    final tan1 = math.tan(math.pi / (180.0 * 60.0));
    expect(vTrue, closeTo(tan1 * 1000.0, 1e-9));
    final vLeg = 1.0 / 3.438;
    expect((vTrue - vLeg).abs(), greaterThan(1e-6)); // küçük ama sıfır değil
  });

  test('shooter IPHY per-click linear mil matches in/100yd scale', () {
    final v = perClickMilForMoaScopeClick(
      clickValue: 1.0,
      moaClickConvention: MoaDisplayConvention.shooterInchesPer100Yd,
      angularMilConvention: AngularMilConvention.linear,
    );
    final deltaOverR = 1.047 * 0.0254 / (100.0 * 0.9144);
    expect(v, closeTo(deltaOverR * 1000.0, 1e-9));
  });

  test('clicksForCorrectionMil uses moa convention', () {
    const corr = 1.0;
    final leg = clicksForCorrectionMil(
      correctionMil: corr,
      clickUnit: ClickUnit.moa,
      clickValue: 0.1,
      moaClickConvention: MoaDisplayConvention.legacyFromMil,
    );
    final arc = clicksForCorrectionMil(
      correctionMil: corr,
      clickUnit: ClickUnit.moa,
      clickValue: 0.1,
      moaClickConvention: MoaDisplayConvention.trueArcminute,
      angularMilConvention: AngularMilConvention.linear,
    );
    expect(leg, isNot(closeTo(arc, 1e-6)));
  });
}
