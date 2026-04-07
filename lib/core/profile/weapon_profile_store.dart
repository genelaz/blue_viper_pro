import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ballistics/bc_kind.dart';
import '../ballistics/click_units.dart';

class WeaponProfile {
  final String name;
  final double muzzleVelocityMps;
  final double ballisticCoefficientG1;
  /// G7 modunda kayıtlı BC; yoksa eski sürümlerde [ballisticCoefficientG1] G7 olarak girilmiş olabilir.
  final double? ballisticCoefficientG7;
  final BcKind bcKind;
  final double sightHeightM;
  final double zeroRangeM;
  final ClickUnit clickUnit;
  final double clickValue;

  const WeaponProfile({
    required this.name,
    required this.muzzleVelocityMps,
    required this.ballisticCoefficientG1,
    this.ballisticCoefficientG7,
    this.bcKind = BcKind.g1,
    this.sightHeightM = 0.038,
    this.zeroRangeM = 100,
    required this.clickUnit,
    required this.clickValue,
  });

  /// Forma / haritada gösterilecek BC ([bcKind]’e göre).
  double get displayBallisticCoefficient => switch (bcKind) {
        BcKind.g1 => ballisticCoefficientG1,
        BcKind.g7 => ballisticCoefficientG7 ?? ballisticCoefficientG1,
      };

  Map<String, dynamic> toJson() => {
        'name': name,
        'muzzleVelocityMps': muzzleVelocityMps,
        'ballisticCoefficientG1': ballisticCoefficientG1,
        if (ballisticCoefficientG7 != null) 'ballisticCoefficientG7': ballisticCoefficientG7,
        'bcKind': bcKind.name,
        'sightHeightM': sightHeightM,
        'zeroRangeM': zeroRangeM,
        'clickUnit': clickUnit.name,
        'clickValue': clickValue,
      };

  static WeaponProfile? fromJson(Map<String, dynamic>? map) {
    if (map == null) return null;
    final name = map['name'] as String?;
    final mv = (map['muzzleVelocityMps'] as num?)?.toDouble();
    final bc = (map['ballisticCoefficientG1'] as num?)?.toDouble();
    final bc7 = (map['ballisticCoefficientG7'] as num?)?.toDouble();
    final cuName = map['clickUnit'] as String?;
    final cv = (map['clickValue'] as num?)?.toDouble();
    if (name == null || mv == null || bc == null || cuName == null || cv == null) {
      return null;
    }
    ClickUnit unit = ClickUnit.mil;
    try {
      unit = ClickUnit.values.byName(cuName);
    } catch (_) {
      unit = ClickUnit.mil;
    }
    BcKind bk = BcKind.g1;
    try {
      final s = map['bcKind'] as String?;
      if (s != null) bk = BcKind.values.byName(s);
    } catch (_) {}
    final sh = (map['sightHeightM'] as num?)?.toDouble() ?? 0.038;
    final zr = (map['zeroRangeM'] as num?)?.toDouble() ?? 100.0;
    return WeaponProfile(
      name: name,
      muzzleVelocityMps: mv,
      ballisticCoefficientG1: bc,
      ballisticCoefficientG7: bc7,
      bcKind: bk,
      sightHeightM: sh,
      zeroRangeM: zr,
      clickUnit: unit,
      clickValue: cv,
    );
  }
}

class WeaponProfileStore {
  static const _prefsKey = 'weapon_profile_v1';

  static final ValueNotifier<WeaponProfile?> current = ValueNotifier<WeaponProfile?>(null);

  static Future<void> loadPersisted() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final profile = WeaponProfile.fromJson(map);
      if (profile != null) current.value = profile;
    } catch (_) {
      // Yüklenemezse sessiz; kullanıcı yeni profil kaydeder.
    }
  }

  static Future<void> save(WeaponProfile profile) async {
    current.value = profile;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, jsonEncode(profile.toJson()));
    } catch (_) {
      /// Bellekte yine güncel; kalıcı yazılamazsa kullanıcı fark etmeyebilir.
    }
  }

  static Future<void> clear() async {
    current.value = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefsKey);
  }
}
