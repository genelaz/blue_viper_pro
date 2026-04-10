import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ballistics/bc_kind.dart';
import '../ballistics/click_units.dart';
import 'shot_scene_preset.dart';

class WeaponProfile {
  /// Boşsa yeni defter kaydi; doluysa guncelleme/ silme icin anahtar.
  final String id;
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

  /// Katalog [WeaponType.id]; bos/null = eski / silahtan bagimsiz kayit.
  final String? weaponCatalogId;

  /// Katalog [ScopeType.id]; deftere dürbün seçimini kalıcı yazar.
  final String? scopeCatalogId;

  /// Katalog [AmmoType.id].
  final String? ammoCatalogId;

  /// Secili [AmmoBarrelVariant.id] ([ammoCatalogId] ile birlikte).
  final String? ammoVariantId;

  /// Açıksa saha kronometre Vo’su korunur; mühimmat/namlu bandı seçimi Vo alanını değiştirmez.
  final bool chronoMuzzleVelocityLocked;

  /// Elle girilen namlu uzunluğu (inç). Varyant eşleştirme ve kayıt için tutulur.
  final double? preferredBarrelInches;

  /// Spin drift (Miller); forma / defter kaydinda saklanir.
  final bool enableSpinDrift;
  final bool twistRightHanded;
  final double? bulletMassGrains;
  final double? bulletCaliberInches;
  /// in/tur
  final double? twistInchesPerTurn;

  /// Coriolis / aerodynamic jump (forma ile senkron).
  final bool enableCoriolis;
  /// Enlem derece (+ kuzey); opsiyonel, eski kayitlarda yok.
  final double? latitudeDegrees;
  final bool enableAerodynamicJump;
  /// Atış azimutu kuzeyden °; Coriolis ve met rüzgârı ile ortak.
  final double? azimuthFromNorthDegrees;

  const WeaponProfile({
    this.id = '',
    required this.name,
    required this.muzzleVelocityMps,
    required this.ballisticCoefficientG1,
    this.ballisticCoefficientG7,
    this.bcKind = BcKind.g1,
    this.sightHeightM = 0.038,
    this.zeroRangeM = 100,
    required this.clickUnit,
    required this.clickValue,
    this.weaponCatalogId,
    this.scopeCatalogId,
    this.ammoCatalogId,
    this.ammoVariantId,
    this.chronoMuzzleVelocityLocked = false,
    this.preferredBarrelInches,
    this.enableSpinDrift = false,
    this.twistRightHanded = true,
    this.bulletMassGrains,
    this.bulletCaliberInches,
    this.twistInchesPerTurn,
    this.enableCoriolis = false,
    this.latitudeDegrees,
    this.enableAerodynamicJump = false,
    this.azimuthFromNorthDegrees,
  });

  /// Forma / haritada gösterilecek BC ([bcKind]’e göre).
  double get displayBallisticCoefficient => switch (bcKind) {
        BcKind.g1 => ballisticCoefficientG1,
        BcKind.g7 => ballisticCoefficientG7 ?? ballisticCoefficientG1,
      };

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        'muzzleVelocityMps': muzzleVelocityMps,
        'ballisticCoefficientG1': ballisticCoefficientG1,
        if (ballisticCoefficientG7 != null) 'ballisticCoefficientG7': ballisticCoefficientG7,
        'bcKind': bcKind.name,
        'sightHeightM': sightHeightM,
        'zeroRangeM': zeroRangeM,
        'clickUnit': clickUnit.name,
        'clickValue': clickValue,
        if (weaponCatalogId != null && weaponCatalogId!.isNotEmpty) 'weaponCatalogId': weaponCatalogId,
        if (scopeCatalogId != null && scopeCatalogId!.isNotEmpty) 'scopeCatalogId': scopeCatalogId,
        if (ammoCatalogId != null && ammoCatalogId!.isNotEmpty) 'ammoCatalogId': ammoCatalogId,
        if (ammoVariantId != null && ammoVariantId!.isNotEmpty) 'ammoVariantId': ammoVariantId,
        'chronoMuzzleVelocityLocked': chronoMuzzleVelocityLocked,
        if (preferredBarrelInches != null) 'preferredBarrelInches': preferredBarrelInches,
        'enableSpinDrift': enableSpinDrift,
        'twistRightHanded': twistRightHanded,
        if (bulletMassGrains != null) 'bulletMassGrains': bulletMassGrains,
        if (bulletCaliberInches != null) 'bulletCaliberInches': bulletCaliberInches,
        if (twistInchesPerTurn != null) 'twistInchesPerTurn': twistInchesPerTurn,
        'enableCoriolis': enableCoriolis,
        if (latitudeDegrees != null) 'latitudeDegrees': latitudeDegrees,
        'enableAerodynamicJump': enableAerodynamicJump,
        if (azimuthFromNorthDegrees != null) 'azimuthFromNorthDegrees': azimuthFromNorthDegrees,
      };

  static WeaponProfile? fromJson(Map<String, dynamic>? map) {
    if (map == null) return null;
    final id = (map['id'] as String?)?.trim() ?? '';
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
    final wcid = (map['weaponCatalogId'] as String?)?.trim();
    final scid = (map['scopeCatalogId'] as String?)?.trim();
    final aid = (map['ammoCatalogId'] as String?)?.trim();
    final avid = (map['ammoVariantId'] as String?)?.trim();
    final cmvl = map['chronoMuzzleVelocityLocked'];
    final pbi = (map['preferredBarrelInches'] as num?)?.toDouble();
    final esd = map['enableSpinDrift'];
    final trh = map['twistRightHanded'];
    final bmg = (map['bulletMassGrains'] as num?)?.toDouble();
    final bciOrig = (map['bulletCaliberInches'] as num?)?.toDouble();
    final tit = (map['twistInchesPerTurn'] as num?)?.toDouble();
    final eco = map['enableCoriolis'];
    final lat = (map['latitudeDegrees'] as num?)?.toDouble();
    final eaj = map['enableAerodynamicJump'];
    final azi = (map['azimuthFromNorthDegrees'] as num?)?.toDouble();
    return WeaponProfile(
      id: id,
      name: name,
      muzzleVelocityMps: mv,
      ballisticCoefficientG1: bc,
      ballisticCoefficientG7: bc7,
      bcKind: bk,
      sightHeightM: sh,
      zeroRangeM: zr,
      clickUnit: unit,
      clickValue: cv,
      weaponCatalogId: (wcid != null && wcid.isNotEmpty) ? wcid : null,
      scopeCatalogId: (scid != null && scid.isNotEmpty) ? scid : null,
      ammoCatalogId: (aid != null && aid.isNotEmpty) ? aid : null,
      ammoVariantId: (avid != null && avid.isNotEmpty) ? avid : null,
      chronoMuzzleVelocityLocked: cmvl is bool ? cmvl : false,
      preferredBarrelInches: pbi,
      enableSpinDrift: esd is bool ? esd : false,
      twistRightHanded: trh is bool ? trh : true,
      bulletMassGrains: bmg,
      bulletCaliberInches: bciOrig,
      twistInchesPerTurn: tit,
      enableCoriolis: eco is bool ? eco : false,
      latitudeDegrees: lat,
      enableAerodynamicJump: eaj is bool ? eaj : false,
      azimuthFromNorthDegrees: azi,
    );
  }

  WeaponProfile copyWith({
    String? id,
    String? name,
    double? muzzleVelocityMps,
    double? ballisticCoefficientG1,
    double? ballisticCoefficientG7,
    BcKind? bcKind,
    double? sightHeightM,
    double? zeroRangeM,
    ClickUnit? clickUnit,
    double? clickValue,
    String? weaponCatalogId,
    bool clearWeaponCatalogId = false,
    String? scopeCatalogId,
    bool clearScopeCatalogId = false,
    String? ammoCatalogId,
    bool clearAmmoCatalogId = false,
    String? ammoVariantId,
    bool clearAmmoVariantId = false,
    bool? chronoMuzzleVelocityLocked,
    double? preferredBarrelInches,
    bool? enableSpinDrift,
    bool? twistRightHanded,
    double? bulletMassGrains,
    double? bulletCaliberInches,
    double? twistInchesPerTurn,
    bool? enableCoriolis,
    double? latitudeDegrees,
    bool? enableAerodynamicJump,
    double? azimuthFromNorthDegrees,
  }) {
    return WeaponProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      muzzleVelocityMps: muzzleVelocityMps ?? this.muzzleVelocityMps,
      ballisticCoefficientG1: ballisticCoefficientG1 ?? this.ballisticCoefficientG1,
      ballisticCoefficientG7: ballisticCoefficientG7 ?? this.ballisticCoefficientG7,
      bcKind: bcKind ?? this.bcKind,
      sightHeightM: sightHeightM ?? this.sightHeightM,
      zeroRangeM: zeroRangeM ?? this.zeroRangeM,
      clickUnit: clickUnit ?? this.clickUnit,
      clickValue: clickValue ?? this.clickValue,
      weaponCatalogId:
          clearWeaponCatalogId ? null : (weaponCatalogId ?? this.weaponCatalogId),
      scopeCatalogId: clearScopeCatalogId ? null : (scopeCatalogId ?? this.scopeCatalogId),
      ammoCatalogId: clearAmmoCatalogId ? null : (ammoCatalogId ?? this.ammoCatalogId),
      ammoVariantId: clearAmmoVariantId ? null : (ammoVariantId ?? this.ammoVariantId),
      chronoMuzzleVelocityLocked:
          chronoMuzzleVelocityLocked ?? this.chronoMuzzleVelocityLocked,
      preferredBarrelInches: preferredBarrelInches ?? this.preferredBarrelInches,
      enableSpinDrift: enableSpinDrift ?? this.enableSpinDrift,
      twistRightHanded: twistRightHanded ?? this.twistRightHanded,
      bulletMassGrains: bulletMassGrains ?? this.bulletMassGrains,
      bulletCaliberInches: bulletCaliberInches ?? this.bulletCaliberInches,
      twistInchesPerTurn: twistInchesPerTurn ?? this.twistInchesPerTurn,
      enableCoriolis: enableCoriolis ?? this.enableCoriolis,
      latitudeDegrees: latitudeDegrees ?? this.latitudeDegrees,
      enableAerodynamicJump: enableAerodynamicJump ?? this.enableAerodynamicJump,
      azimuthFromNorthDegrees: azimuthFromNorthDegrees ?? this.azimuthFromNorthDegrees,
    );
  }
}

/// Birden fazla silah balistik profili (defter); [WeaponProfileStore.current] aktif satir.
class WeaponProfileBookStore {
  static const _bookKey = 'weapon_profile_book_v1';

  static final ValueNotifier<List<WeaponProfile>> entries = ValueNotifier<List<WeaponProfile>>([]);

  static Future<void> loadPersisted() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_bookKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final rawList = map['entries'] as List<dynamic>;
        final migratedScenes = <ShotScenePreset>[];
        final list = <WeaponProfile>[];
        for (final entry in rawList) {
          final m = Map<String, dynamic>.from(entry as Map);
          final peeled = ShotScenePreset.peelEmbeddedFromWeaponJsonMap(m);
          if (peeled != null) migratedScenes.add(peeled);
          final w = WeaponProfile.fromJson(m);
          if (w != null) list.add(w);
        }
        entries.value = list;
        final aid = map['activeEntryId'] as String?;
        WeaponProfile? pick;
        if (aid != null && aid.isNotEmpty) {
          for (final e in list) {
            if (e.id == aid) pick = e;
          }
        }
        pick ??= list.isNotEmpty ? list.first : null;
        if (pick != null) {
          await WeaponProfileStore.save(pick);
        } else {
          WeaponProfileStore.current.value = null;
        }
        await ShotScenePresetBookStore.mergeMigratedPresets(migratedScenes, pick?.id);
        await _persistBook();
      } catch (_) {
        entries.value = [];
      }
      return;
    }

    await WeaponProfileStore.loadPersisted();
    final leg = WeaponProfileStore.current.value;
    if (leg != null) {
      final withId = leg.id.isEmpty
          ? leg.copyWith(id: 'migrated_${DateTime.now().millisecondsSinceEpoch}')
          : leg;
      entries.value = [withId];
      await WeaponProfileStore.save(withId);
      await _persistBook();
    } else {
      entries.value = [];
    }
  }

  static Future<void> _persistBook() async {
    final p = await SharedPreferences.getInstance();
    final cur = WeaponProfileStore.current.value;
    await p.setString(
      _bookKey,
      jsonEncode({
        'entries': entries.value.map((e) => e.toJson()).toList(),
        'activeEntryId': cur?.id ?? '',
      }),
    );
  }

  /// Yeni id uretir veya mevcut [profile.id] ile satiri gunceller; aktif profili ayarlar.
  static Future<WeaponProfile> upsertAndActivate(WeaponProfile profile) async {
    var p = profile;
    if (p.id.isEmpty) {
      p = p.copyWith(id: 'wp_${DateTime.now().millisecondsSinceEpoch}');
    }
    final list = List<WeaponProfile>.from(entries.value);
    final idx = list.indexWhere((e) => e.id == p.id);
    if (idx >= 0) {
      list[idx] = p;
    } else {
      list.add(p);
    }
    entries.value = list;
    await WeaponProfileStore.save(p);
    await _persistBook();
    return p;
  }

  static Future<void> remove(String id) async {
    if (id.isEmpty) return;
    final list = entries.value.where((e) => e.id != id).toList();
    entries.value = list;
    final cur = WeaponProfileStore.current.value;
    if (cur?.id == id) {
      if (list.isNotEmpty) {
        await WeaponProfileStore.save(list.first);
      } else {
        await WeaponProfileStore.clear();
      }
    }
    await _persistBook();
  }

  static Future<void> setActive(WeaponProfile profile) async {
    if (profile.id.isEmpty) return;
    await WeaponProfileStore.save(profile);
    await _persistBook();
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
