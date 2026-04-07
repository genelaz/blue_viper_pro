import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'catalog_data.dart';

class UserCatalogStore {
  static const _weaponsKey = 'user_weapons_v1';
  static const _scopesKey = 'user_scopes_v1';
  static const _ammosKey = 'user_ammos_v1';

  static Future<List<WeaponType>> loadWeapons() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_weaponsKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = (jsonDecode(raw) as List).cast<Map>().map((e) {
      return WeaponType.fromMap(Map<String, dynamic>.from(e));
    }).toList();
    return list;
  }

  static Future<List<ScopeType>> loadScopes() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_scopesKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = (jsonDecode(raw) as List).cast<Map>().map((e) {
      return ScopeType.fromMap(Map<String, dynamic>.from(e));
    }).toList();
    return list;
  }

  static Future<List<AmmoType>> loadAmmos() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_ammosKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = (jsonDecode(raw) as List).cast<Map>().map((e) {
      return AmmoType.fromMap(Map<String, dynamic>.from(e));
    }).toList();
    return list;
  }

  static Future<void> saveWeapons(List<WeaponType> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_weaponsKey, jsonEncode(items.map((e) => e.toMap()).toList()));
  }

  static Future<void> saveScopes(List<ScopeType> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_scopesKey, jsonEncode(items.map((e) => e.toMap()).toList()));
  }

  static Future<void> saveAmmos(List<AmmoType> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_ammosKey, jsonEncode(items.map((e) => e.toMap()).toList()));
  }
}

