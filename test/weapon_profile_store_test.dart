import 'dart:convert';

import 'package:blue_viper_pro/core/ballistics/bc_kind.dart';
import 'package:blue_viper_pro/core/ballistics/click_units.dart';
import 'package:blue_viper_pro/core/profile/shot_scene_preset.dart';
import 'package:blue_viper_pro/core/profile/weapon_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WeaponProfileStore.clear();
    WeaponProfileBookStore.entries.value = [];
    ShotScenePresetBookStore.entries.value = [];
    ShotScenePresetBookStore.current.value = null;
  });

  test('save persists and loadPersisted restores', () async {
    const p = WeaponProfile(
      name: 'Test-Rifle',
      muzzleVelocityMps: 820,
      ballisticCoefficientG1: 0.4,
      ballisticCoefficientG7: 0.19,
      bcKind: BcKind.g7,
      sightHeightM: 0.04,
      zeroRangeM: 100,
      clickUnit: ClickUnit.moa,
      clickValue: 0.25,
    );
    await WeaponProfileStore.save(p);
    WeaponProfileStore.current.value = null;

    await WeaponProfileStore.loadPersisted();

    final got = WeaponProfileStore.current.value!;
    expect(got.name, p.name);
    expect(got.muzzleVelocityMps, p.muzzleVelocityMps);
    expect(got.ballisticCoefficientG1, p.ballisticCoefficientG1);
    expect(got.ballisticCoefficientG7, p.ballisticCoefficientG7);
    expect(got.bcKind, BcKind.g7);
    expect(got.sightHeightM, p.sightHeightM);
    expect(got.zeroRangeM, p.zeroRangeM);
    expect(got.clickUnit, ClickUnit.moa);
    expect(got.clickValue, p.clickValue);
    expect(got.displayBallisticCoefficient, 0.19);
    expect(got.enableSpinDrift, false);
    expect(got.twistRightHanded, true);
    expect(got.enableCoriolis, false);
    expect(got.enableAerodynamicJump, false);
  });

  test('clear removes prefs and notifier', () async {
    await WeaponProfileStore.save(
      const WeaponProfile(
        name: 'x',
        muzzleVelocityMps: 800,
        ballisticCoefficientG1: 0.45,
        clickUnit: ClickUnit.mil,
        clickValue: 0.1,
      ),
    );
    await WeaponProfileStore.clear();
    expect(WeaponProfileStore.current.value, isNull);
    final raw = SharedPreferences.getInstance().then((p) => p.getString('weapon_profile_v1'));
    expect(await raw, isNull);
  });

  test('WeaponProfile toJson / fromJson roundtrip', () {
    const original = WeaponProfile(
      name: 'R',
      muzzleVelocityMps: 790,
      ballisticCoefficientG1: 0.42,
      bcKind: BcKind.g1,
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
      weaponCatalogId: 'tr_knt76',
      scopeCatalogId: 'scope_nx8',
      ammoCatalogId: 'ammo_match',
      ammoVariantId: 'var_20in',
      chronoMuzzleVelocityLocked: true,
      preferredBarrelInches: 21.5,
      enableSpinDrift: true,
      twistRightHanded: false,
      bulletMassGrains: 175,
      bulletCaliberInches: 0.308,
      twistInchesPerTurn: 10,
      enableCoriolis: true,
      latitudeDegrees: 41.2,
      enableAerodynamicJump: true,
      azimuthFromNorthDegrees: 45,
    );
    final map = original.toJson();
    final decoded = WeaponProfile.fromJson(map)!;
    expect(decoded.name, original.name);
    expect(decoded.muzzleVelocityMps, original.muzzleVelocityMps);
    expect(decoded.bcKind, original.bcKind);
    expect(decoded.weaponCatalogId, 'tr_knt76');
    expect(decoded.scopeCatalogId, 'scope_nx8');
    expect(decoded.ammoCatalogId, 'ammo_match');
    expect(decoded.ammoVariantId, 'var_20in');
    expect(decoded.chronoMuzzleVelocityLocked, true);
    expect(decoded.preferredBarrelInches, 21.5);
    expect(decoded.enableSpinDrift, true);
    expect(decoded.twistRightHanded, false);
    expect(decoded.bulletMassGrains, 175);
    expect(decoded.bulletCaliberInches, 0.308);
    expect(decoded.twistInchesPerTurn, 10);
    expect(decoded.enableCoriolis, true);
    expect(decoded.latitudeDegrees, 41.2);
    expect(decoded.enableAerodynamicJump, true);
    expect(decoded.azimuthFromNorthDegrees, 45);
  });

  test('fromJson returns null for missing fields', () {
    expect(WeaponProfile.fromJson({'name': 'a'}), isNull);
    expect(WeaponProfile.fromJson(jsonDecode('{"name":"a","muzzleVelocityMps":1}') as Map<String, dynamic>), isNull);
  });

  test('WeaponProfileBookStore upsert keeps multiple entries', () async {
    const a = WeaponProfile(
      id: '',
      name: 'A',
      muzzleVelocityMps: 800,
      ballisticCoefficientG1: 0.45,
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    );
    const b = WeaponProfile(
      id: '',
      name: 'B',
      muzzleVelocityMps: 780,
      ballisticCoefficientG1: 0.40,
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    );
    final sa = await WeaponProfileBookStore.upsertAndActivate(a);
    final sb = await WeaponProfileBookStore.upsertAndActivate(b);
    expect(sa.id, isNotEmpty);
    expect(sb.id, isNotEmpty);
    expect(sa.id, isNot(equals(sb.id)));
    expect(WeaponProfileBookStore.entries.value.length, 2);
    expect(WeaponProfileStore.current.value?.name, 'B');
  });

  test('WeaponProfileBookStore remove drops one entry', () async {
    const a = WeaponProfile(
      id: '',
      name: 'A',
      muzzleVelocityMps: 800,
      ballisticCoefficientG1: 0.45,
      clickUnit: ClickUnit.mil,
      clickValue: 0.1,
    );
    final sa = await WeaponProfileBookStore.upsertAndActivate(a);
    await WeaponProfileBookStore.remove(sa.id);
    expect(WeaponProfileBookStore.entries.value, isEmpty);
    expect(WeaponProfileStore.current.value, isNull);
  });
}
