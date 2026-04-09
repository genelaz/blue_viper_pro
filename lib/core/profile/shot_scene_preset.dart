import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ortam + rüzgâr + barut sıcaklığı eğrisi + (P/T/Δh/eğim) birim tercihleri.
/// Silah profilinden ayrı tutulur; aynı silahla farklı sahneler kombinlenebilir.
class ShotScenePreset {
  final String id;
  final String name;
  /// İsteğe bağlı: hangi silah defteri satırıyla eşlendi.
  final String? linkedWeaponProfileId;

  final String? temperatureUnitKey;
  final String? pressureUnitKey;
  final String? heightUnitKey;
  final String? slopeUnitKey;
  final double? temperatureValue;
  final double? pressureValue;
  final double? humidityPercent;
  final double? densityAltitudeValue;
  final double? targetElevationDeltaValue;
  final double? slopeValue;
  final bool useMetWindVector;
  final double? crossWindValue;
  final double? windSpeedValue;
  final double? windFromValue;
  final double? powderT1;
  final double? powderV1;
  final double? powderT2;
  final double? powderV2;
  final double? powderCurrentT;

  const ShotScenePreset({
    this.id = '',
    this.name = 'Sahne',
    this.linkedWeaponProfileId,
    this.temperatureUnitKey,
    this.pressureUnitKey,
    this.heightUnitKey,
    this.slopeUnitKey,
    this.temperatureValue,
    this.pressureValue,
    this.humidityPercent,
    this.densityAltitudeValue,
    this.targetElevationDeltaValue,
    this.slopeValue,
    this.useMetWindVector = false,
    this.crossWindValue,
    this.windSpeedValue,
    this.windFromValue,
    this.powderT1,
    this.powderV1,
    this.powderT2,
    this.powderV2,
    this.powderCurrentT,
  });

  static const Set<String> embeddedWeaponMapSceneKeys = {
    'temperatureUnitKey',
    'pressureUnitKey',
    'heightUnitKey',
    'slopeUnitKey',
    'temperatureValue',
    'pressureValue',
    'humidityPercent',
    'densityAltitudeValue',
    'targetElevationDeltaValue',
    'slopeValue',
    'useMetWindVector',
    'crossWindValue',
    'windSpeedValue',
    'windFromValue',
    'powderT1',
    'powderV1',
    'powderT2',
    'powderV2',
    'powderCurrentT',
  };

  /// Eski tek JSON haritasından sahne alanlarını okur ve [map]ten siler.
  static ShotScenePreset? peelEmbeddedFromWeaponJsonMap(Map<String, dynamic> map) {
    if (!embeddedWeaponMapSceneKeys.any(map.containsKey)) return null;
    final wpId = (map['id'] as String?)?.trim();
    final wpName = map['name'] as String?;
    final tUnit = (map['temperatureUnitKey'] as String?)?.trim();
    final pUnit = (map['pressureUnitKey'] as String?)?.trim();
    final hUnit = (map['heightUnitKey'] as String?)?.trim();
    final sUnit = (map['slopeUnitKey'] as String?)?.trim();
    final uw = map['useMetWindVector'];
    final scene = ShotScenePreset(
      id: (wpId != null && wpId.isNotEmpty) ? 'scene_$wpId' : '',
      name: (wpName != null && wpName.isNotEmpty) ? '$wpName — sahne' : 'Sahne',
      linkedWeaponProfileId: (wpId != null && wpId.isNotEmpty) ? wpId : null,
      temperatureUnitKey: (tUnit != null && tUnit.isNotEmpty) ? tUnit : null,
      pressureUnitKey: (pUnit != null && pUnit.isNotEmpty) ? pUnit : null,
      heightUnitKey: (hUnit != null && hUnit.isNotEmpty) ? hUnit : null,
      slopeUnitKey: (sUnit != null && sUnit.isNotEmpty) ? sUnit : null,
      temperatureValue: (map['temperatureValue'] as num?)?.toDouble(),
      pressureValue: (map['pressureValue'] as num?)?.toDouble(),
      humidityPercent: (map['humidityPercent'] as num?)?.toDouble(),
      densityAltitudeValue: (map['densityAltitudeValue'] as num?)?.toDouble(),
      targetElevationDeltaValue: (map['targetElevationDeltaValue'] as num?)?.toDouble(),
      slopeValue: (map['slopeValue'] as num?)?.toDouble(),
      useMetWindVector: uw is bool ? uw : false,
      crossWindValue: (map['crossWindValue'] as num?)?.toDouble(),
      windSpeedValue: (map['windSpeedValue'] as num?)?.toDouble(),
      windFromValue: (map['windFromValue'] as num?)?.toDouble(),
      powderT1: (map['powderT1'] as num?)?.toDouble(),
      powderV1: (map['powderV1'] as num?)?.toDouble(),
      powderT2: (map['powderT2'] as num?)?.toDouble(),
      powderV2: (map['powderV2'] as num?)?.toDouble(),
      powderCurrentT: (map['powderCurrentT'] as num?)?.toDouble(),
    );
    for (final k in embeddedWeaponMapSceneKeys) {
      map.remove(k);
    }
    return scene;
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        if (linkedWeaponProfileId != null && linkedWeaponProfileId!.isNotEmpty)
          'linkedWeaponProfileId': linkedWeaponProfileId,
        if (temperatureUnitKey != null && temperatureUnitKey!.isNotEmpty)
          'temperatureUnitKey': temperatureUnitKey,
        if (pressureUnitKey != null && pressureUnitKey!.isNotEmpty) 'pressureUnitKey': pressureUnitKey,
        if (heightUnitKey != null && heightUnitKey!.isNotEmpty) 'heightUnitKey': heightUnitKey,
        if (slopeUnitKey != null && slopeUnitKey!.isNotEmpty) 'slopeUnitKey': slopeUnitKey,
        if (temperatureValue != null) 'temperatureValue': temperatureValue,
        if (pressureValue != null) 'pressureValue': pressureValue,
        if (humidityPercent != null) 'humidityPercent': humidityPercent,
        if (densityAltitudeValue != null) 'densityAltitudeValue': densityAltitudeValue,
        if (targetElevationDeltaValue != null) 'targetElevationDeltaValue': targetElevationDeltaValue,
        if (slopeValue != null) 'slopeValue': slopeValue,
        'useMetWindVector': useMetWindVector,
        if (crossWindValue != null) 'crossWindValue': crossWindValue,
        if (windSpeedValue != null) 'windSpeedValue': windSpeedValue,
        if (windFromValue != null) 'windFromValue': windFromValue,
        if (powderT1 != null) 'powderT1': powderT1,
        if (powderV1 != null) 'powderV1': powderV1,
        if (powderT2 != null) 'powderT2': powderT2,
        if (powderV2 != null) 'powderV2': powderV2,
        if (powderCurrentT != null) 'powderCurrentT': powderCurrentT,
      };

  static ShotScenePreset? fromJson(Map<String, dynamic>? map) {
    if (map == null) return null;
    final id = (map['id'] as String?)?.trim() ?? '';
    final name = map['name'] as String?;
    if (name == null) return null;
    final lnk = (map['linkedWeaponProfileId'] as String?)?.trim();
    final tUnit = (map['temperatureUnitKey'] as String?)?.trim();
    final pUnit = (map['pressureUnitKey'] as String?)?.trim();
    final hUnit = (map['heightUnitKey'] as String?)?.trim();
    final sUnit = (map['slopeUnitKey'] as String?)?.trim();
    final uw = map['useMetWindVector'];
    return ShotScenePreset(
      id: id,
      name: name,
      linkedWeaponProfileId: (lnk != null && lnk.isNotEmpty) ? lnk : null,
      temperatureUnitKey: (tUnit != null && tUnit.isNotEmpty) ? tUnit : null,
      pressureUnitKey: (pUnit != null && pUnit.isNotEmpty) ? pUnit : null,
      heightUnitKey: (hUnit != null && hUnit.isNotEmpty) ? hUnit : null,
      slopeUnitKey: (sUnit != null && sUnit.isNotEmpty) ? sUnit : null,
      temperatureValue: (map['temperatureValue'] as num?)?.toDouble(),
      pressureValue: (map['pressureValue'] as num?)?.toDouble(),
      humidityPercent: (map['humidityPercent'] as num?)?.toDouble(),
      densityAltitudeValue: (map['densityAltitudeValue'] as num?)?.toDouble(),
      targetElevationDeltaValue: (map['targetElevationDeltaValue'] as num?)?.toDouble(),
      slopeValue: (map['slopeValue'] as num?)?.toDouble(),
      useMetWindVector: uw is bool ? uw : false,
      crossWindValue: (map['crossWindValue'] as num?)?.toDouble(),
      windSpeedValue: (map['windSpeedValue'] as num?)?.toDouble(),
      windFromValue: (map['windFromValue'] as num?)?.toDouble(),
      powderT1: (map['powderT1'] as num?)?.toDouble(),
      powderV1: (map['powderV1'] as num?)?.toDouble(),
      powderT2: (map['powderT2'] as num?)?.toDouble(),
      powderV2: (map['powderV2'] as num?)?.toDouble(),
      powderCurrentT: (map['powderCurrentT'] as num?)?.toDouble(),
    );
  }

  ShotScenePreset copyWith({
    String? id,
    String? name,
    String? linkedWeaponProfileId,
    bool clearLinkedWeaponProfileId = false,
    String? temperatureUnitKey,
    String? pressureUnitKey,
    String? heightUnitKey,
    String? slopeUnitKey,
    double? temperatureValue,
    double? pressureValue,
    double? humidityPercent,
    double? densityAltitudeValue,
    double? targetElevationDeltaValue,
    double? slopeValue,
    bool? useMetWindVector,
    double? crossWindValue,
    double? windSpeedValue,
    double? windFromValue,
    double? powderT1,
    double? powderV1,
    double? powderT2,
    double? powderV2,
    double? powderCurrentT,
  }) {
    return ShotScenePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      linkedWeaponProfileId: clearLinkedWeaponProfileId
          ? null
          : (linkedWeaponProfileId ?? this.linkedWeaponProfileId),
      temperatureUnitKey: temperatureUnitKey ?? this.temperatureUnitKey,
      pressureUnitKey: pressureUnitKey ?? this.pressureUnitKey,
      heightUnitKey: heightUnitKey ?? this.heightUnitKey,
      slopeUnitKey: slopeUnitKey ?? this.slopeUnitKey,
      temperatureValue: temperatureValue ?? this.temperatureValue,
      pressureValue: pressureValue ?? this.pressureValue,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      densityAltitudeValue: densityAltitudeValue ?? this.densityAltitudeValue,
      targetElevationDeltaValue: targetElevationDeltaValue ?? this.targetElevationDeltaValue,
      slopeValue: slopeValue ?? this.slopeValue,
      useMetWindVector: useMetWindVector ?? this.useMetWindVector,
      crossWindValue: crossWindValue ?? this.crossWindValue,
      windSpeedValue: windSpeedValue ?? this.windSpeedValue,
      windFromValue: windFromValue ?? this.windFromValue,
      powderT1: powderT1 ?? this.powderT1,
      powderV1: powderV1 ?? this.powderV1,
      powderT2: powderT2 ?? this.powderT2,
      powderV2: powderV2 ?? this.powderV2,
      powderCurrentT: powderCurrentT ?? this.powderCurrentT,
    );
  }

  String? get summaryLine {
    final hasEnv = temperatureValue != null ||
        pressureValue != null ||
        humidityPercent != null ||
        densityAltitudeValue != null;
    final hasWind = crossWindValue != null || windSpeedValue != null || windFromValue != null;
    final hasPowder =
        powderT1 != null || powderV1 != null || powderT2 != null || powderV2 != null;
    if (!hasEnv && !hasWind && !hasPowder) return null;
    final tags = <String>[];
    if (hasEnv) tags.add('Ortam');
    if (hasWind) tags.add(useMetWindVector ? 'Rüzgar(vect)' : 'Rüzgar(cross)');
    if (hasPowder) tags.add('Barut eğrisi');
    return tags.join(' · ');
  }
}

/// Sahne defteri + aktif sahne.
class ShotScenePresetBookStore {
  static const _bookKey = 'shot_scene_book_v1';

  static final ValueNotifier<List<ShotScenePreset>> entries = ValueNotifier<List<ShotScenePreset>>([]);

  static final ValueNotifier<ShotScenePreset?> current = ValueNotifier<ShotScenePreset?>(null);

  static Future<void> loadPersisted() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_bookKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final list = (map['entries'] as List<dynamic>)
            .map((e) => ShotScenePreset.fromJson(Map<String, dynamic>.from(e as Map)))
            .whereType<ShotScenePreset>()
            .toList();
        entries.value = list;
        final aid = map['activeEntryId'] as String?;
        ShotScenePreset? pick;
        if (aid != null && aid.isNotEmpty) {
          for (final e in list) {
            if (e.id == aid) pick = e;
          }
        }
        pick ??= list.isNotEmpty ? list.first : null;
        current.value = pick;
      } catch (_) {
        entries.value = [];
        current.value = null;
      }
      return;
    }
    entries.value = [];
    current.value = null;
  }

  /// Eski tek `weapon_profile_v1` kaydinda gömülü sahne varsa cikarir ve prefs'i sadelestirir.
  static Future<void> tryImportLegacySingleWeaponPrefs() async {
    if (entries.value.isNotEmpty) return;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('weapon_profile_v1');
      if (raw == null || raw.trim().isEmpty) return;
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>);
      final scene = ShotScenePreset.peelEmbeddedFromWeaponJsonMap(m);
      if (scene == null) return;
      final wpId = (m['id'] as String?)?.trim() ?? '';
      final fixed = scene.copyWith(
        id: wpId.isNotEmpty ? 'scene_$wpId' : scene.id.isNotEmpty ? scene.id : 'scene_legacy',
        name: scene.name,
      );
      entries.value = [fixed];
      current.value = fixed;
      await p.setString(_bookKey, jsonEncode(_bookPayload()));
      final trimmed = jsonEncode(m);
      await p.setString('weapon_profile_v1', trimmed);
    } catch (_) {}
  }

  static Map<String, dynamic> _bookPayload() => {
        'entries': entries.value.map((e) => e.toJson()).toList(),
        'activeEntryId': current.value?.id ?? '',
      };

  static Future<void> _persistBook() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_bookKey, jsonEncode(_bookPayload()));
  }

  /// Silah defterinden cikarilan sahneleri birlestirir. [current] bossa aktif silaha uygun olani dener.
  static Future<void> mergeMigratedPresets(
    List<ShotScenePreset> peeled,
    String? activeWeaponProfileId,
  ) async {
    if (peeled.isEmpty) return;
    final list = List<ShotScenePreset>.from(entries.value);
    for (final s in peeled) {
      final idx = list.indexWhere((e) => e.id == s.id);
      if (idx >= 0) {
        list[idx] = s;
      } else {
        list.add(s);
      }
    }
    entries.value = list;

    if (current.value == null) {
      ShotScenePreset? pick;
      if (activeWeaponProfileId != null && activeWeaponProfileId.isNotEmpty) {
        final want = 'scene_$activeWeaponProfileId';
        for (final s in list) {
          if (s.id == want) pick = s;
        }
      }
      current.value = pick ?? (list.isNotEmpty ? list.first : null);
    }
    await _persistBook();
  }

  static Future<ShotScenePreset> upsertAndActivate(ShotScenePreset preset) async {
    var p = preset;
    if (p.id.isEmpty) {
      p = p.copyWith(id: 'sc_${DateTime.now().millisecondsSinceEpoch}');
    }
    final list = List<ShotScenePreset>.from(entries.value);
    final idx = list.indexWhere((e) => e.id == p.id);
    if (idx >= 0) {
      list[idx] = p;
    } else {
      list.add(p);
    }
    entries.value = list;
    current.value = p;
    await _persistBook();
    return p;
  }

  static Future<void> remove(String id) async {
    if (id.isEmpty) return;
    final list = entries.value.where((e) => e.id != id).toList();
    entries.value = list;
    if (current.value?.id == id) {
      current.value = list.isNotEmpty ? list.first : null;
    }
    await _persistBook();
  }

  static Future<void> setActive(ShotScenePreset preset) async {
    if (preset.id.isEmpty) return;
    current.value = preset;
    await _persistBook();
  }
}
