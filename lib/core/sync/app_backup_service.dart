import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../profile/weapon_profile_store.dart';

/// Cihazlar arası yedek: SharedPreferences anahtarlarını tek JSON’da toplar / geri yükler.
/// Gerçek bulut hesabı yok; dosyayı Drive / iCloud / e-posta ile taşıyın.
class AppBackupService {
  /// Anlamsal yedek şeması; geri yüklerken [restoreFromJson] uyumluluğu buna bakar.
  static const backupSchemaVersion = 1;

  /// Eski dışa aktarmalarla uyum için aynı değer; yeni alan adı [backupSchemaVersion].
  static const backupVersion = backupSchemaVersion;

  static int _schemaFromExport(Map<String, dynamic> map) {
    final v = map['backupSchemaVersion'] ?? map['backupVersion'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static void _ensureSchemaSupported(int schema) {
    if (schema < 1 || schema > backupSchemaVersion) {
      throw FormatException(
        'Yedek şema sürümü ($schema) bu uygulama ile uyumlu değil '
        '(desteklenen: 1–$backupSchemaVersion).',
      );
    }
  }

  static Future<Map<String, dynamic>> collectPayload() async {
    final p = await SharedPreferences.getInstance();
    final keys = p.getKeys();
    final raw = <String, dynamic>{
      'backupSchemaVersion': backupSchemaVersion,
      'backupVersion': backupVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'prefs': <String, dynamic>{},
    };
    for (final k in keys) {
      final v = p.get(k);
      if (v is String || v is int || v is double || v is bool) {
        (raw['prefs'] as Map<String, dynamic>)[k] = v;
      } else if (v is List<String>) {
        (raw['prefs'] as Map<String, dynamic>)[k] = v;
      }
    }
    return raw;
  }

  static String payloadToJson(Map<String, dynamic> payload) =>
      const JsonEncoder.withIndent('  ').convert(payload);

  /// [merge]: false ise yalnızca yedekteki anahtarlar yazılır; true iken mevcutla birleştirilir (basit).
  static Future<void> restoreFromJson(
    String json, {
    bool merge = true,
  }) async {
    final map = jsonDecode(json) as Map<String, dynamic>;
    _ensureSchemaSupported(_schemaFromExport(map));
    final prefsMap = map['prefs'] as Map<String, dynamic>?;
    if (prefsMap == null) return;
    final p = await SharedPreferences.getInstance();
    if (!merge) {
      await p.clear();
    }
    for (final e in prefsMap.entries) {
      final key = e.key;
      final v = e.value;
      if (v is String) {
        await p.setString(key, v);
      } else if (v is int) {
        await p.setInt(key, v);
      } else if (v is double) {
        await p.setDouble(key, v);
      } else if (v is bool) {
        await p.setBool(key, v);
      } else if (v is List) {
        await p.setStringList(key, v.map((x) => '$x').toList());
      }
    }
    await WeaponProfileStore.loadPersisted();
  }
}
