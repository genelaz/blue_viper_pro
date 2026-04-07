import 'dart:convert';

import 'package:flutter/services.dart';

import 'catalog_data.dart';

/// Paket içi katalog (Türkiye + NATO öncelikli).
class BundledCatalog {
  final List<WeaponType> weapons;
  final List<ScopeType> scopes;
  final List<AmmoType> ammos;

  const BundledCatalog({
    required this.weapons,
    required this.scopes,
    required this.ammos,
  });

  static const empty = BundledCatalog(
    weapons: [],
    scopes: [],
    ammos: [],
  );
}

class CatalogLoader {
  static const assetTurkeyNato = 'assets/catalog/turkey_nato.json';

  static Future<BundledCatalog> loadTurkeyNato() async {
    try {
      final raw = await rootBundle.loadString(assetTurkeyNato);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final weapons = (map['weapons'] as List<dynamic>? ?? [])
          .map((e) => WeaponType.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      final scopes = (map['scopes'] as List<dynamic>? ?? [])
          .map((e) => ScopeType.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      final ammos = (map['ammos'] as List<dynamic>? ?? [])
          .map((e) => AmmoType.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      return BundledCatalog(
        weapons: weapons,
        scopes: scopes,
        ammos: ammos,
      );
    } catch (_) {
      return BundledCatalog.empty;
    }
  }

  static List<WeaponType> mergeWeapons(
    List<WeaponType> base,
    List<WeaponType> overlay,
    List<WeaponType> user,
  ) {
    final map = <String, WeaponType>{};
    final order = <String>[];
    void addAll(List<WeaponType> list) {
      for (final w in list) {
        if (!map.containsKey(w.id)) order.add(w.id);
        map[w.id] = w;
      }
    }

    addAll(base);
    addAll(overlay);
    addAll(user);
    return [for (final id in order) map[id]!];
  }

  static List<ScopeType> mergeScopes(
    List<ScopeType> base,
    List<ScopeType> overlay,
    List<ScopeType> user,
  ) {
    final map = <String, ScopeType>{};
    final order = <String>[];
    void addAll(List<ScopeType> list) {
      for (final s in list) {
        if (!map.containsKey(s.id)) order.add(s.id);
        map[s.id] = s;
      }
    }

    addAll(base);
    addAll(overlay);
    addAll(user);
    return [for (final id in order) map[id]!];
  }

  static List<AmmoType> mergeAmmos(
    List<AmmoType> base,
    List<AmmoType> overlay,
    List<AmmoType> user,
  ) {
    final map = <String, AmmoType>{};
    final order = <String>[];
    void addAll(List<AmmoType> list) {
      for (final a in list) {
        if (!map.containsKey(a.id)) order.add(a.id);
        map[a.id] = a;
      }
    }

    addAll(base);
    addAll(overlay);
    addAll(user);
    return [for (final id in order) map[id]!];
  }
}
