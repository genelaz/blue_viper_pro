import 'dart:math' as math;

import 'atmosphere.dart';
import 'ballistics_corrections.dart';
import 'bc_kind.dart';
import 'bc_mach_segment.dart';
import 'click_units.dart';
import 'custom_drag_table.dart';
import 'g1_drag.dart';
import 'g7_drag.dart';
import 'ballistics_output_convention.dart';
import 'powder_temperature.dart';

class BallisticsSolveInput {
  final double distanceMeters;
  final double muzzleVelocityMps;
  final BcKind bcKind;
  /// G1 veya G7 BC (lb/in²), [bcKind] ile seçilir.
  final double ballisticCoefficient;
  final double temperatureC;
  final double pressureHpa;
  final double relativeHumidityPercent;
  /// Verilirse basınç ISA rakım modelinden; [pressureHpa] göz ardı edilir (yoğunluk oranı için).
  final double? densityAltitudeMeters;
  final double targetElevationDeltaMeters;
  final double slopeAngleDegrees;
  /// Namlu ekseninden dürbün eksenine dikey mesafe (+ yukarı), metre.
  final double sightHeightMeters;
  /// Sıfırlama menzili (yatay), metre.
  final double zeroRangeMeters;
  /// Yan rüzgâr (+ = mermiyi sağa iter, yani hedefte sağa düşer).
  final double crossWindMps;
  final bool enableCoriolis;
  final double latitudeDegrees;
  final double azimuthFromNorthDegrees;
  final bool enableSpinDrift;
  /// +1 sağ el twist, −1 sol.
  final int riflingTwistSign;
  final double? bulletMassGrains;
  final double? bulletCaliberInches;
  final double? twistInchesPerTurn;
  final bool enableAerodynamicJump;

  final ClickUnit clickUnit;
  final double clickValue;

  /// Barut sıcaklığı tablosu (≥2 çift) ve şu anki barut sıcaklığı.
  final List<TempVelocityPair> powderTempVelocityPairs;
  final double? powderTemperatureC;

  /// Mach eşiklerine göre parçalı BC (yüksek Mach’tan düşüğe sıralı; boş = tek BC).
  final List<BcMachSegment>? bcMachSegments;

  /// Özel i(Mach) tablosu (G1 biçimi); doluysa standart G1/G7 eğrisi yerine kullanılır.
  final List<double>? customDragMachNodes;
  final List<double>? customDragI;

  /// Hedefin çizgisine dik hız bileşeni (+ = hedef sağa, m/s). Küçük açı öncüsü.
  final double targetCrossTrackMps;

  /// Mil gösterimi: küçük açı (`Δ/R×1000`) veya `atan2(Δ,R)×1000`.
  final AngularMilConvention angularMilConvention;

  /// MOA gösterimi (tıklar yine mil üzerinden).
  final MoaDisplayConvention moaDisplayConvention;

  /// Bazı dürbün / uygulama işaretleri için yan rüzgâr girişini tersler (çözüme giren değer).
  final bool invertCrossWindSign;

  BallisticsSolveInput({
    required this.distanceMeters,
    required this.muzzleVelocityMps,
    this.bcKind = BcKind.g1,
    required this.ballisticCoefficient,
    this.temperatureC = 15,
    this.pressureHpa = 1013,
    this.relativeHumidityPercent = 0,
    this.densityAltitudeMeters,
    this.targetElevationDeltaMeters = 0,
    this.slopeAngleDegrees = 0,
    this.sightHeightMeters = 0.038,
    this.zeroRangeMeters = 100,
    this.crossWindMps = 0,
    this.enableCoriolis = false,
    this.latitudeDegrees = 0,
    this.azimuthFromNorthDegrees = 0,
    this.enableSpinDrift = false,
    this.riflingTwistSign = 1,
    this.bulletMassGrains,
    this.bulletCaliberInches,
    this.twistInchesPerTurn,
    this.enableAerodynamicJump = false,
    required this.clickUnit,
    required this.clickValue,
    this.powderTempVelocityPairs = const [],
    this.powderTemperatureC,
    this.bcMachSegments,
    this.customDragMachNodes,
    this.customDragI,
    this.targetCrossTrackMps = 0,
    this.angularMilConvention = AngularMilConvention.linear,
    this.moaDisplayConvention = MoaDisplayConvention.legacyFromMil,
    this.invertCrossWindSign = false,
  });

  /// Eski çağrılar: sadece G1 ve temel alanlar.
  factory BallisticsSolveInput.legacyG1({
    required double distanceMeters,
    required double muzzleVelocityMps,
    required double ballisticCoefficientG1,
    required double temperatureC,
    required double pressureHpa,
    required double targetElevationDeltaMeters,
    required double slopeAngleDegrees,
    required ClickUnit clickUnit,
    required double clickValue,
  }) {
    return BallisticsSolveInput(
      distanceMeters: distanceMeters,
      muzzleVelocityMps: muzzleVelocityMps,
      bcKind: BcKind.g1,
      ballisticCoefficient: ballisticCoefficientG1,
      temperatureC: temperatureC,
      pressureHpa: pressureHpa,
      targetElevationDeltaMeters: targetElevationDeltaMeters,
      slopeAngleDegrees: slopeAngleDegrees,
      clickUnit: clickUnit,
      clickValue: clickValue,
    );
  }

  /// Aynı atmosfer ve balistik girdilerle yalnızca menzil + hedef rakım farkını değiştirir (kayıtlı hedefler).
  BallisticsSolveInput withTargetGeometry({
    required double distanceMeters,
    required double targetElevationDeltaMeters,
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
      sightHeightMeters: sightHeightMeters,
      zeroRangeMeters: zeroRangeMeters,
      crossWindMps: crossWindMps,
      enableCoriolis: enableCoriolis,
      latitudeDegrees: latitudeDegrees,
      azimuthFromNorthDegrees: azimuthFromNorthDegrees,
      enableSpinDrift: enableSpinDrift,
      riflingTwistSign: riflingTwistSign,
      bulletMassGrains: bulletMassGrains,
      bulletCaliberInches: bulletCaliberInches,
      twistInchesPerTurn: twistInchesPerTurn,
      enableAerodynamicJump: enableAerodynamicJump,
      clickUnit: clickUnit,
      clickValue: clickValue,
      powderTempVelocityPairs: powderTempVelocityPairs,
      powderTemperatureC: powderTemperatureC,
      bcMachSegments: bcMachSegments,
      customDragMachNodes: customDragMachNodes,
      customDragI: customDragI,
      targetCrossTrackMps: targetCrossTrackMps,
      angularMilConvention: angularMilConvention,
      moaDisplayConvention: moaDisplayConvention,
      invertCrossWindSign: invertCrossWindSign,
    );
  }

  BallisticsSolveInput withTargetCrossTrackMps(double targetCrossTrackMps) {
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
      sightHeightMeters: sightHeightMeters,
      zeroRangeMeters: zeroRangeMeters,
      crossWindMps: crossWindMps,
      enableCoriolis: enableCoriolis,
      latitudeDegrees: latitudeDegrees,
      azimuthFromNorthDegrees: azimuthFromNorthDegrees,
      enableSpinDrift: enableSpinDrift,
      riflingTwistSign: riflingTwistSign,
      bulletMassGrains: bulletMassGrains,
      bulletCaliberInches: bulletCaliberInches,
      twistInchesPerTurn: twistInchesPerTurn,
      enableAerodynamicJump: enableAerodynamicJump,
      clickUnit: clickUnit,
      clickValue: clickValue,
      powderTempVelocityPairs: powderTempVelocityPairs,
      powderTemperatureC: powderTemperatureC,
      bcMachSegments: bcMachSegments,
      customDragMachNodes: customDragMachNodes,
      customDragI: customDragI,
      targetCrossTrackMps: targetCrossTrackMps,
      angularMilConvention: angularMilConvention,
      moaDisplayConvention: moaDisplayConvention,
      invertCrossWindSign: invertCrossWindSign,
    );
  }

  /// [this] balistik profili (Vo, BC, nişan/sıfır, barut eğrisi, spin verileri) korur;
  /// menzil, hedef geometrisi, atmosfer, rüzgâr ve Coriolis/azimut gibi atış koşullarını [shot]tan alır.
  BallisticsSolveInput withShotConditionsFrom(BallisticsSolveInput shot) {
    return BallisticsSolveInput(
      distanceMeters: shot.distanceMeters,
      muzzleVelocityMps: muzzleVelocityMps,
      bcKind: bcKind,
      ballisticCoefficient: ballisticCoefficient,
      temperatureC: shot.temperatureC,
      pressureHpa: shot.pressureHpa,
      relativeHumidityPercent: shot.relativeHumidityPercent,
      densityAltitudeMeters: shot.densityAltitudeMeters,
      targetElevationDeltaMeters: shot.targetElevationDeltaMeters,
      slopeAngleDegrees: shot.slopeAngleDegrees,
      sightHeightMeters: sightHeightMeters,
      zeroRangeMeters: zeroRangeMeters,
      crossWindMps: shot.crossWindMps,
      enableCoriolis: shot.enableCoriolis,
      latitudeDegrees: shot.latitudeDegrees,
      azimuthFromNorthDegrees: shot.azimuthFromNorthDegrees,
      enableSpinDrift: enableSpinDrift,
      riflingTwistSign: riflingTwistSign,
      bulletMassGrains: bulletMassGrains,
      bulletCaliberInches: bulletCaliberInches,
      twistInchesPerTurn: twistInchesPerTurn,
      enableAerodynamicJump: shot.enableAerodynamicJump,
      clickUnit: shot.clickUnit,
      clickValue: shot.clickValue,
      powderTempVelocityPairs: powderTempVelocityPairs,
      powderTemperatureC: shot.powderTemperatureC,
      bcMachSegments: bcMachSegments,
      customDragMachNodes: customDragMachNodes,
      customDragI: customDragI,
      targetCrossTrackMps: shot.targetCrossTrackMps,
      angularMilConvention: shot.angularMilConvention,
      moaDisplayConvention: shot.moaDisplayConvention,
      invertCrossWindSign: shot.invertCrossWindSign,
    );
  }
}

class BallisticsSolveOutput {
  final double dropMil;
  final double dropMoa;
  final double windMil;
  final double windMoa;
  final double timeOfFlightMs;
  /// Yükseliş (eski alan adı uyumluluğu).
  final double clicks;
  final double windClicks;
  final double adjustedMuzzleVelocityMps;
  final double appliedBallisticCoefficient;
  /// Hedef mesafesindeki mermi hızı (m/s).
  final double impactVelocityMps;
  /// 0.5·m·v²; mermi kütlesi yoksa null.
  final double? impactEnergyJoules;

  /// Hareketli hedef öncüsü (mil); çizgiye dik hedef hızından.
  final double leadMil;
  final double leadMoa;
  final double leadClicks;

  /// Yatay tutma: rüzgâr/yörünge (+ spin/coriolis yanal) + öncü.
  final double combinedLateralMil;
  final double combinedLateralMoa;
  final double combinedLateralClicks;

  /// Hedefte dikey tutma (LOS’a göre mermi konumu), m — cm için ×100.
  final double verticalHoldDeltaMeters;
  /// Saf yanal (rüzgâr + spin/Coriolis yanal), m.
  final double windLateralDeltaMeters;
  /// Öncü (çizgiye dik hedef hızı × TOF), m — cm için ×100.
  final double leadLateralDeltaMeters;
  /// Öncü dahil toplam yanal sapma, m.
  final double combinedLateralDeltaMeters;

  /// Coriolis / spin / aero jump bileşenleri (çözüm çizgisinde mil öncesi).
  final SecondaryCorrections secondaryCorrections;

  /// Çözüm sıcaklığındaki ses hızı (m/s).
  final double speedOfSoundMps;

  /// Yörünge boyunca (entegrasyon çerçevesinde) maksimum dikey konum, m.
  final double apexHeightAlongPathM;

  const BallisticsSolveOutput({
    required this.dropMil,
    required this.dropMoa,
    required this.windMil,
    required this.windMoa,
    required this.timeOfFlightMs,
    required this.clicks,
    required this.windClicks,
    required this.adjustedMuzzleVelocityMps,
    required this.appliedBallisticCoefficient,
    required this.impactVelocityMps,
    required this.impactEnergyJoules,
    required this.leadMil,
    required this.leadMoa,
    required this.leadClicks,
    required this.combinedLateralMil,
    required this.combinedLateralMoa,
    required this.combinedLateralClicks,
    required this.verticalHoldDeltaMeters,
    required this.windLateralDeltaMeters,
    required this.leadLateralDeltaMeters,
    required this.combinedLateralDeltaMeters,
    required this.secondaryCorrections,
    required this.speedOfSoundMps,
    required this.apexHeightAlongPathM,
  });
}

class BallisticsEngine {
  static BallisticsSolveOutput solve(BallisticsSolveInput i) {
    final vPowder = muzzleVelocityFromPowderTable(
      fallbackMps: i.muzzleVelocityMps,
      powderTempC: i.powderTemperatureC ?? i.temperatureC,
      pairs: i.powderTempVelocityPairs,
    );

    final bc = i.ballisticCoefficient.clamp(0.02, 2.5);
    final segs = i.bcMachSegments;
    final useSegs = segs != null && segs.length >= 2;
    final cm = i.customDragMachNodes;
    final ci = i.customDragI;
    List<double>? customMSorted;
    List<double>? customISorted;
    if (cm != null && ci != null && cm.length >= 2 && cm.length == ci.length) {
      final order = List<int>.generate(cm.length, (idx) => idx);
      order.sort((a, b) => cm[a].compareTo(cm[b]));
      customMSorted = [for (final j in order) cm[j]];
      customISorted = [for (final j in order) ci[j]];
    }
    final dragCfg = _DragConfig(
      bcBase: bc,
      bcKind: i.bcKind,
      segments: useSegs ? segs : null,
      customMachs: customMSorted,
      customIs: customISorted,
    );
    final rhoRatio = densityRatioFromAtmosphere(
      temperatureC: i.temperatureC,
      pressureHpa: i.pressureHpa,
      relativeHumidityPercent: i.relativeHumidityPercent,
      densityAltitudeMeters: i.densityAltitudeMeters,
    );
    final sound = soundSpeedForSolve(i.temperatureC);
    const g = 9.80665;
    final d = i.distanceMeters.clamp(1.0, 100_000.0);
    final windCross = i.invertCrossWindSign ? -i.crossWindMps : i.crossWindMps;
    final v0 = vPowder.clamp(50.0, 2000.0);

    var elevM = i.targetElevationDeltaMeters;
    if (elevM.abs() < 1e-6 && i.slopeAngleDegrees.abs() > 1e-6) {
      elevM = d * math.tan(i.slopeAngleDegrees * math.pi / 180.0);
    }
    final thetaLos = math.atan2(elevM, d);
    final boreKick = math.atan2(
      i.sightHeightMeters.clamp(0.0, 0.2),
      i.zeroRangeMeters.clamp(1.0, 5000.0),
    );
    final phi = thetaLos + boreKick;
    final vx0 = v0 * math.cos(phi);
    final vy0 = v0 * math.sin(phi);

    final s = _State3(
      x: 0,
      y: 0,
      z: 0,
      vx: vx0,
      vy: vy0,
      vz: 0,
      t: 0,
    );

    const dt = 6e-5;
    const maxSteps = 1_000_000;
    var prevX = 0.0;
    var prevY = 0.0;
    var prevZ = 0.0;
    var prevVx = 0.0;
    var prevVy = 0.0;
    var prevVz = 0.0;
    var prevT = 0.0;
    var crossed = false;
    double yAt = 0;
    double zAt = 0;
    double tAt = 0;
    double vmAt = v0;
    var apexY = s.y;

    for (var step = 0; step < maxSteps && !crossed; step++) {
      prevX = s.x;
      prevY = s.y;
      prevZ = s.z;
      prevVx = s.vx;
      prevVy = s.vy;
      prevVz = s.vz;
      prevT = s.t;
      _rk4Step3(
        s: s,
        dt: dt,
        drag: dragCfg,
        rhoRatio: rhoRatio,
        sound: sound,
        g: g,
        windCrossMps: windCross,
      );
      if (s.y > apexY) apexY = s.y;
      if (s.x >= d && prevX < d) {
        final f = (d - prevX) / (s.x - prevX);
        yAt = prevY + f * (s.y - prevY);
        zAt = prevZ + f * (s.z - prevZ);
        tAt = prevT + f * (s.t - prevT);
        final vxm = prevVx + f * (s.vx - prevVx);
        final vym = prevVy + f * (s.vy - prevVy);
        final vzm = prevVz + f * (s.vz - prevVz);
        vmAt = math.sqrt(vxm * vxm + vym * vym + vzm * vzm);
        crossed = true;
      }
    }

    if (!crossed) {
      if (s.x > prevX && s.x > 1) {
        final f = (d - prevX) / (s.x - prevX);
        yAt = prevY + f * (s.y - prevY);
        zAt = prevZ + f * (s.z - prevZ);
        tAt = prevT + f * (s.t - prevT);
        vmAt = math.sqrt(s.vx * s.vx + s.vy * s.vy + s.vz * s.vz);
      } else {
        yAt = s.y;
        zAt = s.z;
        tAt = s.t;
        vmAt = math.sqrt(s.vx * s.vx + s.vy * s.vy + s.vz * s.vz);
      }
    }

    final avgV = (v0 + vmAt) * 0.5;
    final sec = computeSecondaryCorrections(
      enableCoriolis: i.enableCoriolis,
      latitudeDeg: i.latitudeDegrees,
      azimuthFromNorthDeg: i.azimuthFromNorthDegrees,
      rangeM: d,
      tofS: tAt,
      avgVelocityMps: avgV.clamp(100.0, 2000.0),
      enableSpinDrift: i.enableSpinDrift,
      twistDirection: i.riflingTwistSign,
      bulletMassGrains: i.bulletMassGrains,
      caliberInches: i.bulletCaliberInches,
      twistInchesPerTurn: i.twistInchesPerTurn,
      enableAeroJump: i.enableAerodynamicJump,
      crossWindMps: windCross,
      temperatureC: i.temperatureC,
      pressureHpa: i.pressureHpa,
      relativeHumidityPercent: i.relativeHumidityPercent,
    );

    final yTot = yAt + sec.coriolisVerticalM + sec.aeroJumpVerticalM;
    final zTot = zAt + sec.coriolisLateralM + sec.spinDriftM;

    final dropDeltaM = elevM - yTot;
    final windDeltaM = zTot;
    final leadDeltaM = i.targetCrossTrackMps * tAt;
    final latCombinedDeltaM = windDeltaM + leadDeltaM;

    final milConv = i.angularMilConvention;
    final moaConv = i.moaDisplayConvention;
    final dropMil = milFromLateralMeters(deltaM: dropDeltaM, rangeM: d, convention: milConv);
    final windMil = milFromLateralMeters(deltaM: windDeltaM, rangeM: d, convention: milConv);
    final leadMil = milFromLateralMeters(deltaM: leadDeltaM, rangeM: d, convention: milConv);
    final combinedLateralMil =
        milFromLateralMeters(deltaM: latCombinedDeltaM, rangeM: d, convention: milConv);

    final dropMoa =
        moaFromMilAndGeometry(mil: dropMil, deltaM: dropDeltaM, rangeM: d, convention: moaConv);
    final windMoa =
        moaFromMilAndGeometry(mil: windMil, deltaM: windDeltaM, rangeM: d, convention: moaConv);
    final leadMoa =
        moaFromMilAndGeometry(mil: leadMil, deltaM: leadDeltaM, rangeM: d, convention: moaConv);
    final combinedLateralMoa = moaFromMilAndGeometry(
      mil: combinedLateralMil,
      deltaM: latCombinedDeltaM,
      rangeM: d,
      convention: moaConv,
    );
    final tofMs = tAt * 1000.0;

    final clickElev = clicksForCorrectionMil(
      correctionMil: dropMil,
      clickUnit: i.clickUnit,
      clickValue: i.clickValue,
      moaClickConvention: i.moaDisplayConvention,
      angularMilConvention: i.angularMilConvention,
    );
    final clickWind = clicksForCorrectionMil(
      correctionMil: windMil,
      clickUnit: i.clickUnit,
      clickValue: i.clickValue,
      moaClickConvention: i.moaDisplayConvention,
      angularMilConvention: i.angularMilConvention,
    );

    final clickLead = clicksForCorrectionMil(
      correctionMil: leadMil,
      clickUnit: i.clickUnit,
      clickValue: i.clickValue,
      moaClickConvention: i.moaDisplayConvention,
      angularMilConvention: i.angularMilConvention,
    );
    final clickCombinedLat = clicksForCorrectionMil(
      correctionMil: combinedLateralMil,
      clickUnit: i.clickUnit,
      clickValue: i.clickValue,
      moaClickConvention: i.moaDisplayConvention,
      angularMilConvention: i.angularMilConvention,
    );

    double? ej;
    final gr = i.bulletMassGrains;
    if (gr != null && gr > 0) {
      final kg = gr * 64.79891e-6;
      ej = 0.5 * kg * vmAt * vmAt;
    }

    return BallisticsSolveOutput(
      dropMil: dropMil,
      dropMoa: dropMoa,
      windMil: windMil,
      windMoa: windMoa,
      timeOfFlightMs: tofMs,
      clicks: clickElev,
      windClicks: clickWind,
      adjustedMuzzleVelocityMps: vPowder,
      appliedBallisticCoefficient: bc,
      impactVelocityMps: vmAt,
      impactEnergyJoules: ej,
      leadMil: leadMil,
      leadMoa: leadMoa,
      leadClicks: clickLead,
      combinedLateralMil: combinedLateralMil,
      combinedLateralMoa: combinedLateralMoa,
      combinedLateralClicks: clickCombinedLat,
      verticalHoldDeltaMeters: dropDeltaM,
      windLateralDeltaMeters: windDeltaM,
      leadLateralDeltaMeters: leadDeltaM,
      combinedLateralDeltaMeters: latCombinedDeltaM,
      secondaryCorrections: sec,
      speedOfSoundMps: sound,
      apexHeightAlongPathM: apexY,
    );
  }

  /// StreLok tarzı: gözlenen yükseliş düzeltmesine (mil) uyan BC (mevcut [bcKind]).
  static double? trueBallisticCoefficientForObservedDrop({
    required BallisticsSolveInput template,
    required double observedDropMil,
    double bcMin = 0.08,
    double bcMax = 1.2,
    int iterations = 24,
  }) {
    if (bcMax <= bcMin || iterations < 4) return null;
    var lo = bcMin;
    var hi = bcMax;
    BallisticsSolveOutput run(double b) => solve(BallisticsSolveInput(
          distanceMeters: template.distanceMeters,
          muzzleVelocityMps: template.muzzleVelocityMps,
          bcKind: template.bcKind,
          ballisticCoefficient: b,
          temperatureC: template.temperatureC,
          pressureHpa: template.pressureHpa,
          relativeHumidityPercent: template.relativeHumidityPercent,
          densityAltitudeMeters: template.densityAltitudeMeters,
          targetElevationDeltaMeters: template.targetElevationDeltaMeters,
          slopeAngleDegrees: template.slopeAngleDegrees,
          sightHeightMeters: template.sightHeightMeters,
          zeroRangeMeters: template.zeroRangeMeters,
          crossWindMps: template.crossWindMps,
          enableCoriolis: template.enableCoriolis,
          latitudeDegrees: template.latitudeDegrees,
          azimuthFromNorthDegrees: template.azimuthFromNorthDegrees,
          enableSpinDrift: template.enableSpinDrift,
          riflingTwistSign: template.riflingTwistSign,
          bulletMassGrains: template.bulletMassGrains,
          bulletCaliberInches: template.bulletCaliberInches,
          twistInchesPerTurn: template.twistInchesPerTurn,
          enableAerodynamicJump: template.enableAerodynamicJump,
          clickUnit: template.clickUnit,
          clickValue: template.clickValue,
          powderTempVelocityPairs: template.powderTempVelocityPairs,
          powderTemperatureC: template.powderTemperatureC,
          bcMachSegments: template.bcMachSegments,
          customDragMachNodes: template.customDragMachNodes,
          customDragI: template.customDragI,
          targetCrossTrackMps: template.targetCrossTrackMps,
          angularMilConvention: template.angularMilConvention,
          moaDisplayConvention: template.moaDisplayConvention,
          invertCrossWindSign: template.invertCrossWindSign,
        ));
    for (var k = 0; k < iterations; k++) {
      final mid = (lo + hi) * 0.5;
      final out = run(mid);
      if (out.dropMil > observedDropMil) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) * 0.5;
  }

  /// Gözlenen yükseliş düzeltmesine (mil) uyan namlu çıkış hızı (m/s).
  static double? trueMuzzleVelocityForObservedDrop({
    required BallisticsSolveInput template,
    required double observedDropMil,
    double mvMinMps = 120,
    double mvMaxMps = 1600,
    int iterations = 24,
  }) {
    if (mvMaxMps <= mvMinMps || iterations < 4) return null;
    var lo = mvMinMps;
    var hi = mvMaxMps;
    BallisticsSolveOutput run(double mv) => solve(BallisticsSolveInput(
          distanceMeters: template.distanceMeters,
          muzzleVelocityMps: mv,
          bcKind: template.bcKind,
          ballisticCoefficient: template.ballisticCoefficient,
          temperatureC: template.temperatureC,
          pressureHpa: template.pressureHpa,
          relativeHumidityPercent: template.relativeHumidityPercent,
          densityAltitudeMeters: template.densityAltitudeMeters,
          targetElevationDeltaMeters: template.targetElevationDeltaMeters,
          slopeAngleDegrees: template.slopeAngleDegrees,
          sightHeightMeters: template.sightHeightMeters,
          zeroRangeMeters: template.zeroRangeMeters,
          crossWindMps: template.crossWindMps,
          enableCoriolis: template.enableCoriolis,
          latitudeDegrees: template.latitudeDegrees,
          azimuthFromNorthDegrees: template.azimuthFromNorthDegrees,
          enableSpinDrift: template.enableSpinDrift,
          riflingTwistSign: template.riflingTwistSign,
          bulletMassGrains: template.bulletMassGrains,
          bulletCaliberInches: template.bulletCaliberInches,
          twistInchesPerTurn: template.twistInchesPerTurn,
          enableAerodynamicJump: template.enableAerodynamicJump,
          clickUnit: template.clickUnit,
          clickValue: template.clickValue,
          powderTempVelocityPairs: template.powderTempVelocityPairs,
          powderTemperatureC: template.powderTemperatureC,
          bcMachSegments: template.bcMachSegments,
          customDragMachNodes: template.customDragMachNodes,
          customDragI: template.customDragI,
          targetCrossTrackMps: template.targetCrossTrackMps,
          angularMilConvention: template.angularMilConvention,
          moaDisplayConvention: template.moaDisplayConvention,
          invertCrossWindSign: template.invertCrossWindSign,
        ));
    for (var k = 0; k < iterations; k++) {
      final mid = (lo + hi) * 0.5;
      final out = run(mid);
      if (out.dropMil > observedDropMil) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) * 0.5;
  }
}

class RangeTableRow {
  final int rangeMeters;
  final double dropMil;
  final double dropMoa;
  final double windMil;
  final double windMoa;
  final double leadMil;
  final double leadMoa;
  final double combinedLateralMil;
  final double combinedLateralMoa;
  final double tofMs;
  final double elevClicks;
  final double windClicks;
  final double leadClicks;
  final double combinedLateralClicks;
  final double impactVelocityMps;
  final double? impactEnergyJoules;
  final double dropCmApprox;
  final double windCmApprox;
  final double leadCmApprox;
  final double combinedLateralCmApprox;

  const RangeTableRow({
    required this.rangeMeters,
    required this.dropMil,
    required this.dropMoa,
    required this.windMil,
    required this.windMoa,
    required this.leadMil,
    required this.leadMoa,
    required this.combinedLateralMil,
    required this.combinedLateralMoa,
    required this.tofMs,
    required this.elevClicks,
    required this.windClicks,
    required this.leadClicks,
    required this.combinedLateralClicks,
    required this.impactVelocityMps,
    required this.impactEnergyJoules,
    required this.dropCmApprox,
    required this.windCmApprox,
    required this.leadCmApprox,
    required this.combinedLateralCmApprox,
  });

  factory RangeTableRow.fromSolveOutput(int rangeMeters, BallisticsSolveOutput o) {
    return RangeTableRow(
      rangeMeters: rangeMeters,
      dropMil: o.dropMil,
      dropMoa: o.dropMoa,
      windMil: o.windMil,
      windMoa: o.windMoa,
      leadMil: o.leadMil,
      leadMoa: o.leadMoa,
      combinedLateralMil: o.combinedLateralMil,
      combinedLateralMoa: o.combinedLateralMoa,
      tofMs: o.timeOfFlightMs,
      elevClicks: o.clicks,
      windClicks: o.windClicks,
      leadClicks: o.leadClicks,
      combinedLateralClicks: o.combinedLateralClicks,
      impactVelocityMps: o.impactVelocityMps,
      impactEnergyJoules: o.impactEnergyJoules,
      dropCmApprox: o.verticalHoldDeltaMeters * 100.0,
      windCmApprox: o.windLateralDeltaMeters * 100.0,
      leadCmApprox: o.leadLateralDeltaMeters * 100.0,
      combinedLateralCmApprox: o.combinedLateralDeltaMeters * 100.0,
    );
  }
}

List<RangeTableRow> buildBallisticsRangeTable({
  required BallisticsSolveInput template,
  required int startMeters,
  required int endMeters,
  required int stepMeters,
}) {
  final rows = <RangeTableRow>[];
  final step = stepMeters.clamp(1, 5000);
  for (var r = startMeters; r <= endMeters; r += step) {
    final out = BallisticsEngine.solve(
      BallisticsSolveInput(
        distanceMeters: r.toDouble(),
        muzzleVelocityMps: template.muzzleVelocityMps,
        bcKind: template.bcKind,
        ballisticCoefficient: template.ballisticCoefficient,
        temperatureC: template.temperatureC,
        pressureHpa: template.pressureHpa,
        relativeHumidityPercent: template.relativeHumidityPercent,
        densityAltitudeMeters: template.densityAltitudeMeters,
        targetElevationDeltaMeters: template.targetElevationDeltaMeters,
        slopeAngleDegrees: template.slopeAngleDegrees,
        sightHeightMeters: template.sightHeightMeters,
        zeroRangeMeters: template.zeroRangeMeters,
        crossWindMps: template.crossWindMps,
        enableCoriolis: template.enableCoriolis,
        latitudeDegrees: template.latitudeDegrees,
        azimuthFromNorthDegrees: template.azimuthFromNorthDegrees,
        enableSpinDrift: template.enableSpinDrift,
        riflingTwistSign: template.riflingTwistSign,
        bulletMassGrains: template.bulletMassGrains,
        bulletCaliberInches: template.bulletCaliberInches,
        twistInchesPerTurn: template.twistInchesPerTurn,
        enableAerodynamicJump: template.enableAerodynamicJump,
        clickUnit: template.clickUnit,
        clickValue: template.clickValue,
        powderTempVelocityPairs: template.powderTempVelocityPairs,
        powderTemperatureC: template.powderTemperatureC,
        bcMachSegments: template.bcMachSegments,
        customDragMachNodes: template.customDragMachNodes,
        customDragI: template.customDragI,
        targetCrossTrackMps: template.targetCrossTrackMps,
        angularMilConvention: template.angularMilConvention,
        moaDisplayConvention: template.moaDisplayConvention,
        invertCrossWindSign: template.invertCrossWindSign,
      ),
    );
    rows.add(RangeTableRow.fromSolveOutput(r, out));
  }
  return rows;
}

class _State3 {
  double x;
  double y;
  double z;
  double vx;
  double vy;
  double vz;
  double t;

  _State3({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.t,
  });
}

class _Deriv3 {
  final double dx;
  final double dy;
  final double dz;
  final double dvx;
  final double dvy;
  final double dvz;

  const _Deriv3({
    required this.dx,
    required this.dy,
    required this.dz,
    required this.dvx,
    required this.dvy,
    required this.dvz,
  });

  _Deriv3 plus(_Deriv3 o) => _Deriv3(
        dx: dx + o.dx,
        dy: dy + o.dy,
        dz: dz + o.dz,
        dvx: dvx + o.dvx,
        dvy: dvy + o.dvy,
        dvz: dvz + o.dvz,
      );

  _Deriv3 operator *(double s) => _Deriv3(
        dx: dx * s,
        dy: dy * s,
        dz: dz * s,
        dvx: dvx * s,
        dvy: dvy * s,
        dvz: dvz * s,
      );
}

class _DragConfig {
  final double bcBase;
  final BcKind bcKind;
  final List<BcMachSegment>? segments;
  final List<double>? customMachs;
  final List<double>? customIs;

  const _DragConfig({
    required this.bcBase,
    required this.bcKind,
    this.segments,
    this.customMachs,
    this.customIs,
  });
}

double _dragAccelerationMagnitude({
  required double vm,
  required double mach,
  required _DragConfig cfg,
  required double rhoRatio,
}) {
  final segs = cfg.segments;
  final bcUse = (segs != null && segs.isNotEmpty)
      ? bcForMachFromSegments(mach, segs, cfg.bcBase)
      : cfg.bcBase;
  if (vm < 1e-6 || bcUse < 1e-9) return 0;
  final cm = cfg.customMachs;
  final ci = cfg.customIs;
  final useCustom = cm != null && ci != null && cm.length >= 2 && cm.length == ci.length;
  if (useCustom) {
    final iM = customIDragAtMach(mach, cm, ci);
    return kG1DragSi * rhoRatio * vm * vm * iM / bcUse;
  }
  return switch (cfg.bcKind) {
    BcKind.g1 => g1DragAccelerationMagnitude(
        velocityMps: vm,
        mach: mach,
        bcG1LbPerSqIn: bcUse,
        densityRatio: rhoRatio,
      ),
    BcKind.g7 => g7DragAccelerationMagnitude(
        velocityMps: vm,
        mach: mach,
        bcG7LbPerSqIn: bcUse,
        densityRatio: rhoRatio,
      ),
  };
}

_Deriv3 _deriv3({
  required _State3 s,
  required _DragConfig drag,
  required double rhoRatio,
  required double sound,
  required double g,
  required double windCrossMps,
}) {
  final vrx = s.vx;
  final vry = s.vy;
  final vrz = s.vz - windCrossMps;
  final vm = math.sqrt(vrx * vrx + vry * vry + vrz * vrz);
  if (vm < 1e-4) {
    return _Deriv3(dx: 0, dy: 0, dz: 0, dvx: 0, dvy: -g, dvz: 0);
  }
  final mach = (vm / sound).clamp(0.01, 10.0);
  final dragAcc = _dragAccelerationMagnitude(
    vm: vm,
    mach: mach,
    cfg: drag,
    rhoRatio: rhoRatio,
  );
  final inv = 1.0 / vm;
  final ax = -dragAcc * vrx * inv;
  final ay = -dragAcc * vry * inv - g;
  final az = -dragAcc * vrz * inv;
  return _Deriv3(
    dx: s.vx,
    dy: s.vy,
    dz: s.vz,
    dvx: ax,
    dvy: ay,
    dvz: az,
  );
}

void _rk4Step3({
  required _State3 s,
  required double dt,
  required _DragConfig drag,
  required double rhoRatio,
  required double sound,
  required double g,
  required double windCrossMps,
}) {
  final k1 = _deriv3(
    s: s,
    drag: drag,
    rhoRatio: rhoRatio,
    sound: sound,
    g: g,
    windCrossMps: windCrossMps,
  );
  final s2 = _State3(
    x: s.x + 0.5 * dt * k1.dx,
    y: s.y + 0.5 * dt * k1.dy,
    z: s.z + 0.5 * dt * k1.dz,
    vx: s.vx + 0.5 * dt * k1.dvx,
    vy: s.vy + 0.5 * dt * k1.dvy,
    vz: s.vz + 0.5 * dt * k1.dvz,
    t: s.t,
  );
  final k2 = _deriv3(
    s: s2,
    drag: drag,
    rhoRatio: rhoRatio,
    sound: sound,
    g: g,
    windCrossMps: windCrossMps,
  );
  final s3 = _State3(
    x: s.x + 0.5 * dt * k2.dx,
    y: s.y + 0.5 * dt * k2.dy,
    z: s.z + 0.5 * dt * k2.dz,
    vx: s.vx + 0.5 * dt * k2.dvx,
    vy: s.vy + 0.5 * dt * k2.dvy,
    vz: s.vz + 0.5 * dt * k2.dvz,
    t: s.t,
  );
  final k3 = _deriv3(
    s: s3,
    drag: drag,
    rhoRatio: rhoRatio,
    sound: sound,
    g: g,
    windCrossMps: windCrossMps,
  );
  final s4 = _State3(
    x: s.x + dt * k3.dx,
    y: s.y + dt * k3.dy,
    z: s.z + dt * k3.dz,
    vx: s.vx + dt * k3.dvx,
    vy: s.vy + dt * k3.dvy,
    vz: s.vz + dt * k3.dvz,
    t: s.t,
  );
  final k4 = _deriv3(
    s: s4,
    drag: drag,
    rhoRatio: rhoRatio,
    sound: sound,
    g: g,
    windCrossMps: windCrossMps,
  );
  final sum = k1.plus(k2 * 2.0).plus(k3 * 2.0).plus(k4);
  s.x += dt * sum.dx / 6.0;
  s.y += dt * sum.dy / 6.0;
  s.z += dt * sum.dz / 6.0;
  s.vx += dt * sum.dvx / 6.0;
  s.vy += dt * sum.dvy / 6.0;
  s.vz += dt * sum.dvz / 6.0;
  s.t += dt;
}

