import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weapon_ballistic_presets.dart';

class BallisticPresetManifest {
  const BallisticPresetManifest({
    required this.schemaVersion,
    required this.dataVersion,
    required this.updatedAtIso,
    required this.source,
  });

  final int schemaVersion;
  final String dataVersion;
  final String updatedAtIso;
  final String source;

  factory BallisticPresetManifest.builtIn() => BallisticPresetManifest(
        schemaVersion: 1,
        dataVersion: 'builtin-v1',
        updatedAtIso: DateTime.now().toUtc().toIso8601String(),
        source: 'bundled',
      );

  Map<String, dynamic> toMap() => {
        'schemaVersion': schemaVersion,
        'dataVersion': dataVersion,
        'updatedAt': updatedAtIso,
        'source': source,
      };

  factory BallisticPresetManifest.fromMap(Map<String, dynamic> map) {
    final schema = (map['schemaVersion'] as num?)?.toInt() ?? 1;
    final dataVersion = (map['dataVersion'] as String?)?.trim();
    final updatedAt = (map['updatedAt'] as String?)?.trim();
    final source = (map['source'] as String?)?.trim();
    if (dataVersion == null || dataVersion.isEmpty) {
      throw const FormatException('dataVersion zorunlu');
    }
    return BallisticPresetManifest(
      schemaVersion: schema,
      dataVersion: dataVersion,
      updatedAtIso: (updatedAt == null || updatedAt.isEmpty)
          ? DateTime.now().toUtc().toIso8601String()
          : updatedAt,
      source: (source == null || source.isEmpty) ? 'unknown' : source,
    );
  }
}

class BallisticPresetBundle {
  const BallisticPresetBundle({
    required this.manifest,
    required this.weaponPresets,
    required this.caliberFallbackPresets,
  });

  final BallisticPresetManifest manifest;
  final Map<String, WeaponBallisticPreset> weaponPresets;
  final Map<String, WeaponBallisticPreset> caliberFallbackPresets;

  Map<String, dynamic> toMap() => {
        'manifest': manifest.toMap(),
        'weaponPresets': {
          for (final e in weaponPresets.entries) e.key: e.value.toMap(),
        },
        'caliberFallbackPresets': {
          for (final e in caliberFallbackPresets.entries) e.key: e.value.toMap(),
        },
      };

  factory BallisticPresetBundle.fromMap(Map<String, dynamic> map) {
    final manifestRaw = map['manifest'];
    if (manifestRaw is! Map) {
      throw const FormatException('manifest zorunlu');
    }
    final weaponRaw = map['weaponPresets'];
    final caliberRaw = map['caliberFallbackPresets'];
    if (weaponRaw is! Map || caliberRaw is! Map) {
      throw const FormatException('weaponPresets/caliberFallbackPresets zorunlu');
    }
    return BallisticPresetBundle(
      manifest: BallisticPresetManifest.fromMap(Map<String, dynamic>.from(manifestRaw)),
      weaponPresets: {
        for (final e in weaponRaw.entries)
          e.key.toString(): WeaponBallisticPreset.fromMap(
            Map<String, dynamic>.from(e.value as Map),
          ),
      },
      caliberFallbackPresets: {
        for (final e in caliberRaw.entries)
          e.key.toString(): WeaponBallisticPreset.fromMap(
            Map<String, dynamic>.from(e.value as Map),
          ),
      },
    );
  }
}

class BallisticPresetRepository {
  static const _activeKey = 'ballistic_preset_bundle_active_v1';
  static const _previousKey = 'ballistic_preset_bundle_previous_v1';

  static BallisticPresetBundle builtInBundle() => BallisticPresetBundle(
        manifest: BallisticPresetManifest.builtIn(),
        weaponPresets: Map<String, WeaponBallisticPreset>.from(weaponBallisticPresets),
        caliberFallbackPresets: Map<String, WeaponBallisticPreset>.from(caliberFallbackPresets),
      );

  static Future<BallisticPresetBundle> loadActiveOrBuiltIn() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_activeKey);
    if (raw == null || raw.trim().isEmpty) return builtInBundle();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return BallisticPresetBundle.fromMap(map);
    } catch (_) {
      return builtInBundle();
    }
  }

  static Future<void> applyBundle(BallisticPresetBundle next) async {
    final p = await SharedPreferences.getInstance();
    final current = p.getString(_activeKey);
    if (current != null && current.trim().isNotEmpty) {
      await p.setString(_previousKey, current);
    }
    await p.setString(_activeKey, jsonEncode(next.toMap()));
  }

  /// Remote payload format:
  /// {
  ///   "manifest": { ... },
  ///   "bundle": { "weaponPresets": {...}, "caliberFallbackPresets": {...} },
  ///   "bundleSha256": "hex digest"
  /// }
  static Future<void> applyRemotePayloadJson(String payloadJson) async {
    final map = jsonDecode(payloadJson);
    if (map is! Map<String, dynamic>) {
      throw const FormatException('Remote payload JSON nesne olmalı');
    }
    final manifestRaw = map['manifest'];
    final bundleRaw = map['bundle'];
    final checksumRaw = map['bundleSha256']?.toString().trim();
    if (manifestRaw is! Map || bundleRaw is! Map) {
      throw const FormatException('manifest ve bundle zorunlu');
    }
    if (checksumRaw == null || checksumRaw.isEmpty) {
      throw const FormatException('bundleSha256 zorunlu');
    }
    final manifest = BallisticPresetManifest.fromMap(
      Map<String, dynamic>.from(manifestRaw),
    );
    if (manifest.schemaVersion != 1) {
      throw FormatException('Desteklenmeyen schemaVersion: ${manifest.schemaVersion}');
    }

    final bundleMap = Map<String, dynamic>.from(bundleRaw);
    final checksumCanonical = _canonicalJson(bundleMap);
    final digest = sha256.convert(utf8.encode(checksumCanonical)).toString();
    if (digest.toLowerCase() != checksumRaw.toLowerCase()) {
      throw const FormatException('bundleSha256 doğrulaması başarısız');
    }

    final next = BallisticPresetBundle.fromMap({
      'manifest': manifest.toMap(),
      ...bundleMap,
    });

    // Güvenli apply: önce eski aktif kaydedilir, yazım sonrası parse ile geri okunur.
    await applyBundle(next);
    await loadActiveOrBuiltIn();
  }

  /// Kayıtlı önceki paketin manifest özeti; geri alma yoksa null.
  static Future<BallisticPresetManifest?> peekPreviousManifest() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_previousKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final manifestRaw = map['manifest'];
      if (manifestRaw is! Map) return null;
      return BallisticPresetManifest.fromMap(Map<String, dynamic>.from(manifestRaw));
    } catch (_) {
      return null;
    }
  }

  static Future<bool> rollbackToPrevious() async {
    final p = await SharedPreferences.getInstance();
    final prev = p.getString(_previousKey);
    if (prev == null || prev.trim().isEmpty) return false;
    final cur = p.getString(_activeKey);
    await p.setString(_activeKey, prev);
    if (cur != null && cur.trim().isNotEmpty) {
      await p.setString(_previousKey, cur);
    } else {
      await p.remove(_previousKey);
    }
    return true;
  }

  static Future<void> clearActive() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_activeKey);
  }
}

String _canonicalJson(Object? value) {
  Object? normalize(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((e) => e.toString()).toList()..sort();
      return {for (final k in keys) k: normalize(v[k])};
    }
    if (v is List) return [for (final e in v) normalize(e)];
    return v;
  }

  return jsonEncode(normalize(value));
}

