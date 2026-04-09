import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ballistics_engine.dart';
import 'bc_kind.dart';
import 'bc_mach_segment.dart';
import 'click_units.dart';
import 'powder_temperature.dart';

const _prefsKey = 'ballistic_profile_compare_ref_v1';

Map<String, dynamic> _inputToJson(BallisticsSolveInput i) {
  return {
    'distanceMeters': i.distanceMeters,
    'muzzleVelocityMps': i.muzzleVelocityMps,
    'bcKind': i.bcKind.name,
    'ballisticCoefficient': i.ballisticCoefficient,
    'temperatureC': i.temperatureC,
    'pressureHpa': i.pressureHpa,
    'relativeHumidityPercent': i.relativeHumidityPercent,
    'densityAltitudeMeters': i.densityAltitudeMeters,
    'targetElevationDeltaMeters': i.targetElevationDeltaMeters,
    'slopeAngleDegrees': i.slopeAngleDegrees,
    'sightHeightMeters': i.sightHeightMeters,
    'zeroRangeMeters': i.zeroRangeMeters,
    'crossWindMps': i.crossWindMps,
    'enableCoriolis': i.enableCoriolis,
    'latitudeDegrees': i.latitudeDegrees,
    'azimuthFromNorthDegrees': i.azimuthFromNorthDegrees,
    'enableSpinDrift': i.enableSpinDrift,
    'riflingTwistSign': i.riflingTwistSign,
    'bulletMassGrains': i.bulletMassGrains,
    'bulletCaliberInches': i.bulletCaliberInches,
    'twistInchesPerTurn': i.twistInchesPerTurn,
    'enableAerodynamicJump': i.enableAerodynamicJump,
    'clickUnit': i.clickUnit.name,
    'clickValue': i.clickValue,
    'powderTempVelocityPairs': [
      for (final p in i.powderTempVelocityPairs)
        {'tempC': p.tempC, 'velocityMps': p.velocityMps},
    ],
    'powderTemperatureC': i.powderTemperatureC,
    'bcMachSegments': i.bcMachSegments
        ?.map((s) => {'machMin': s.machMin, 'bc': s.bc})
        .toList(),
    'customDragMachNodes': i.customDragMachNodes,
    'customDragI': i.customDragI,
    'targetCrossTrackMps': i.targetCrossTrackMps,
  };
}

List<double>? _jsonToDoubleList(Object? v) {
  if (v == null) return null;
  if (v is! List) return null;
  final out = <double>[];
  for (final e in v) {
    final n = (e as num?)?.toDouble();
    if (n == null) return null;
    out.add(n);
  }
  return out;
}

BallisticsSolveInput? _inputFromJson(Object? raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  try {
    final bcKind = BcKind.values.byName(m['bcKind'] as String);
    final clickUnit = ClickUnit.values.byName(m['clickUnit'] as String);
    final pairsRaw = m['powderTempVelocityPairs'];
    final pairs = <TempVelocityPair>[];
    if (pairsRaw is List) {
      for (final e in pairsRaw) {
        if (e is! Map) continue;
        final em = Map<String, dynamic>.from(e);
        final tc = (em['tempC'] as num?)?.toDouble();
        final vm = (em['velocityMps'] as num?)?.toDouble();
        if (tc == null || vm == null) continue;
        pairs.add(TempVelocityPair(tempC: tc, velocityMps: vm));
      }
    }
    List<BcMachSegment>? segs;
    final segRaw = m['bcMachSegments'];
    if (segRaw is List) {
      final tmp = <BcMachSegment>[];
      for (final e in segRaw) {
        if (e is! Map) continue;
        final em = Map<String, dynamic>.from(e);
        final mm = (em['machMin'] as num?)?.toDouble();
        final bc = (em['bc'] as num?)?.toDouble();
        if (mm == null || bc == null) continue;
        tmp.add(BcMachSegment(machMin: mm, bc: bc));
      }
      if (tmp.length >= 2) {
        tmp.sort((a, b) => b.machMin.compareTo(a.machMin));
        segs = tmp;
      }
    }
    final da = m['densityAltitudeMeters'];
    final daM = da == null ? null : (da as num?)?.toDouble();
    final ptc = m['powderTemperatureC'];
    final ptcD = ptc == null ? null : (ptc as num?)?.toDouble();
    final bmg = m['bulletMassGrains'];
    final bci = m['bulletCaliberInches'];
    final tit = m['twistInchesPerTurn'];
    return BallisticsSolveInput(
      distanceMeters: (m['distanceMeters'] as num).toDouble(),
      muzzleVelocityMps: (m['muzzleVelocityMps'] as num).toDouble(),
      bcKind: bcKind,
      ballisticCoefficient: (m['ballisticCoefficient'] as num).toDouble(),
      temperatureC: (m['temperatureC'] as num).toDouble(),
      pressureHpa: (m['pressureHpa'] as num).toDouble(),
      relativeHumidityPercent: (m['relativeHumidityPercent'] as num?)?.toDouble() ?? 0,
      densityAltitudeMeters: daM,
      targetElevationDeltaMeters: (m['targetElevationDeltaMeters'] as num?)?.toDouble() ?? 0,
      slopeAngleDegrees: (m['slopeAngleDegrees'] as num?)?.toDouble() ?? 0,
      sightHeightMeters: (m['sightHeightMeters'] as num).toDouble(),
      zeroRangeMeters: (m['zeroRangeMeters'] as num).toDouble(),
      crossWindMps: (m['crossWindMps'] as num?)?.toDouble() ?? 0,
      enableCoriolis: m['enableCoriolis'] == true,
      latitudeDegrees: (m['latitudeDegrees'] as num?)?.toDouble() ?? 0,
      azimuthFromNorthDegrees: (m['azimuthFromNorthDegrees'] as num?)?.toDouble() ?? 0,
      enableSpinDrift: m['enableSpinDrift'] == true,
      riflingTwistSign: (m['riflingTwistSign'] as num?)?.toInt() ?? 1,
      bulletMassGrains: bmg == null ? null : (bmg as num).toDouble(),
      bulletCaliberInches: bci == null ? null : (bci as num).toDouble(),
      twistInchesPerTurn: tit == null ? null : (tit as num).toDouble(),
      enableAerodynamicJump: m['enableAerodynamicJump'] == true,
      clickUnit: clickUnit,
      clickValue: (m['clickValue'] as num).toDouble(),
      powderTempVelocityPairs: pairs,
      powderTemperatureC: ptcD,
      bcMachSegments: segs,
      customDragMachNodes: _jsonToDoubleList(m['customDragMachNodes']),
      customDragI: _jsonToDoubleList(m['customDragI']),
      targetCrossTrackMps: (m['targetCrossTrackMps'] as num?)?.toDouble() ?? 0,
    );
  } catch (_) {
    return null;
  }
}

/// «Profil karşılaştırması» için yakalanan tam [BallisticsSolveInput] anlığını diskte tutar.
class BallisticCompareRefStore {
  static Future<void> save(BallisticsSolveInput input) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, jsonEncode(_inputToJson(input)));
  }

  static Future<BallisticsSolveInput?> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_prefsKey);
    if (s == null || s.trim().isEmpty) return null;
    try {
      return _inputFromJson(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefsKey);
  }
}
