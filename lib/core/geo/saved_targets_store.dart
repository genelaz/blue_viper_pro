import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Hızlı erişim için kayıtlı hedef ön ayarları (çoklu mesafe / çözüm).
class SavedTargetPreset {
  final String id;
  final String name;
  final double distanceMeters;
  final double elevationDeltaMeters;

  const SavedTargetPreset({
    required this.id,
    required this.name,
    required this.distanceMeters,
    required this.elevationDeltaMeters,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'distanceMeters': distanceMeters,
        'elevationDeltaMeters': elevationDeltaMeters,
      };

  factory SavedTargetPreset.fromMap(Map<String, dynamic> m) => SavedTargetPreset(
        id: m['id'] as String,
        name: m['name'] as String,
        distanceMeters: (m['distanceMeters'] as num).toDouble(),
        elevationDeltaMeters: (m['elevationDeltaMeters'] as num).toDouble(),
      );
}

class SavedTargetsStore {
  static const _key = 'saved_target_presets_v1';

  static Future<List<SavedTargetPreset>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map>();
      return list
          .map((e) => SavedTargetPreset.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<SavedTargetPreset> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(items.map((e) => e.toMap()).toList()));
  }
}
