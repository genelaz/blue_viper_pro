import 'package:blue_viper_pro/core/profile/shot_scene_preset.dart';
import 'package:blue_viper_pro/core/profile/weapon_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ShotScenePreset roundtrip', () {
    const p = ShotScenePreset(
      id: 'sc_1',
      name: 'Kış',
      temperatureUnitKey: 'c',
      temperatureValue: 5,
      useMetWindVector: true,
      windSpeedValue: 4,
    );
    final decoded = ShotScenePreset.fromJson(p.toJson())!;
    expect(decoded.name, 'Kış');
    expect(decoded.temperatureValue, 5);
    expect(decoded.useMetWindVector, true);
  });

  test('peelEmbedded strips scene keys; WeaponProfile still parses', () {
    final m = <String, dynamic>{
      'id': 'wp_x',
      'name': 'Gun',
      'muzzleVelocityMps': 800.0,
      'ballisticCoefficientG1': 0.45,
      'clickUnit': 'mil',
      'clickValue': 0.1,
      'temperatureValue': 12.0,
      'pressureValue': 1013.0,
      'useMetWindVector': false,
    };
    final peeled = ShotScenePreset.peelEmbeddedFromWeaponJsonMap(m);
    expect(peeled, isNotNull);
    expect(peeled!.id, 'scene_wp_x');
    expect(m.containsKey('temperatureValue'), false);
    final w = WeaponProfile.fromJson(m);
    expect(w, isNotNull);
    expect(w!.name, 'Gun');
  });
}
