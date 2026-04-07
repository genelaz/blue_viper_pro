import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Retikül favorileri ve son kullanılan id listesi (hızlı seçim).
class ReticleUserPrefs {
  ReticleUserPrefs._();

  static const _recentKey = 'reticle_recent_ids_v1';
  static const _favoritesKey = 'reticle_favorite_ids_v1';
  static const _maxRecent = 12;

  static Future<List<String>> recentIds() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_recentKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return list.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _saveRecent(List<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_recentKey, jsonEncode(ids));
  }

  /// Seçimi en üste alır; katalogda olmayan id’ler [recordUsed] ile eklenmez (sadece mevcut seçim).
  static Future<void> recordUsed(String id) async {
    if (id.isEmpty) return;
    var list = List<String>.from(await recentIds());
    list.remove(id);
    list.insert(0, id);
    if (list.length > _maxRecent) {
      list = list.sublist(0, _maxRecent);
    }
    await _saveRecent(list);
  }

  static Future<List<String>> favoriteIds() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_favoritesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return list.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _saveFavorites(List<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_favoritesKey, jsonEncode(ids));
  }

  static Future<void> toggleFavorite(String id) async {
    if (id.isEmpty) return;
    var list = List<String>.from(await favoriteIds());
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.insert(0, id);
    }
    await _saveFavorites(list);
  }
}
