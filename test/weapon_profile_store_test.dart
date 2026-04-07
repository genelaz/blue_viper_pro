import 'dart:convert';

import 'package:blue_viper_pro/core/ballistics/bc_kind.dart';
import 'package:blue_viper_pro/core/ballistics/click_units.dart';
import 'package:blue_viper_pro/core/profile/weapon_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WeaponProfileStore.clear();
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
    );
    final map = original.toJson();
    final decoded = WeaponProfile.fromJson(map)!;
    expect(decoded.name, original.name);
    expect(decoded.muzzleVelocityMps, original.muzzleVelocityMps);
    expect(decoded.bcKind, original.bcKind);
  });

  test('fromJson returns null for missing fields', () {
    expect(WeaponProfile.fromJson({'name': 'a'}), isNull);
    expect(WeaponProfile.fromJson(jsonDecode('{"name":"a","muzzleVelocityMps":1}') as Map<String, dynamic>), isNull);
  });
}
