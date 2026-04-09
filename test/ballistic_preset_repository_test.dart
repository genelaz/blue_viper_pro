import 'package:blue_viper_pro/core/catalog/ballistic_preset_repository.dart';
import 'package:blue_viper_pro/core/catalog/weapon_ballistic_presets.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

String _canonicalJson(Object? value) {
  Object? normalize(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((e) => e.toString()).toList()..sort();
      return {for (final k in keys) k: normalize(v[k])};
    }
    if (v is List) return [for (final e in v) normalize(e)];
    return v;
  }

  return jsonEncode(normalize(value));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads built-in bundle when active missing', () async {
    final bundle = await BallisticPresetRepository.loadActiveOrBuiltIn();
    expect(bundle.weaponPresets.isNotEmpty, isTrue);
    expect(bundle.caliberFallbackPresets.isNotEmpty, isTrue);
    expect(bundle.manifest.source, isNotEmpty);
  });

  test('peekPreviousManifest reflects last replaced active bundle', () async {
    expect(await BallisticPresetRepository.peekPreviousManifest(), isNull);
    final base = BallisticPresetRepository.builtInBundle();
    final override = BallisticPresetBundle(
      manifest: const BallisticPresetManifest(
        schemaVersion: 1,
        dataVersion: 'peek-remote',
        updatedAtIso: '2026-04-09T10:00:00Z',
        source: 'remote',
      ),
      weaponPresets: base.weaponPresets,
      caliberFallbackPresets: base.caliberFallbackPresets,
    );
    await BallisticPresetRepository.applyBundle(base);
    expect(await BallisticPresetRepository.peekPreviousManifest(), isNull);
    await BallisticPresetRepository.applyBundle(override);
    final peek = await BallisticPresetRepository.peekPreviousManifest();
    expect(peek?.dataVersion, base.manifest.dataVersion);
    expect(peek?.source, base.manifest.source);
  });

  test('apply and rollback swaps active bundle', () async {
    final base = BallisticPresetRepository.builtInBundle();
    final override = BallisticPresetBundle(
      manifest: const BallisticPresetManifest(
        schemaVersion: 1,
        dataVersion: 'remote-2026-04-09',
        updatedAtIso: '2026-04-09T10:00:00Z',
        source: 'remote',
      ),
      weaponPresets: {
        ...base.weaponPresets,
        'r700_308': const WeaponBallisticPreset(
          muzzleVelocityMps: 777,
          ballisticCoefficientG1: 0.4,
        ),
      },
      caliberFallbackPresets: base.caliberFallbackPresets,
    );

    await BallisticPresetRepository.applyBundle(base);
    await BallisticPresetRepository.applyBundle(override);
    var active = await BallisticPresetRepository.loadActiveOrBuiltIn();
    expect(active.manifest.dataVersion, 'remote-2026-04-09');
    expect(active.weaponPresets['r700_308']?.muzzleVelocityMps, 777);

    final rolledBack = await BallisticPresetRepository.rollbackToPrevious();
    expect(rolledBack, isTrue);
    active = await BallisticPresetRepository.loadActiveOrBuiltIn();
    expect(active.weaponPresets['r700_308']?.muzzleVelocityMps, isNot(777));
  });

  test('applyRemotePayloadJson applies when checksum valid', () async {
    final bundle = {
      'caliberFallbackPresets': {
        '.308 Win': {
          'muzzleVelocityMps': 790,
          'ballisticCoefficientG1': 0.45,
        },
      },
      'weaponPresets': {
        'r700_308': {
          'ballisticCoefficientG1': 0.47,
          'muzzleVelocityMps': 799,
        },
      },
    };
    final digest = sha256.convert(utf8.encode(_canonicalJson(bundle))).toString();
    final payload = jsonEncode({
      'manifest': {
        'schemaVersion': 1,
        'dataVersion': 'remote-v2',
        'updatedAt': '2026-04-09T12:00:00Z',
        'source': 'remote',
      },
      'bundle': bundle,
      'bundleSha256': digest,
    });
    await BallisticPresetRepository.applyRemotePayloadJson(payload);
    final active = await BallisticPresetRepository.loadActiveOrBuiltIn();
    expect(active.manifest.dataVersion, 'remote-v2');
    expect(active.weaponPresets['r700_308']?.muzzleVelocityMps, 799);
  });

  test('applyRemotePayloadJson rejects invalid checksum', () async {
    final payload = jsonEncode({
      'manifest': {
        'schemaVersion': 1,
        'dataVersion': 'remote-v3',
        'updatedAt': '2026-04-09T12:00:00Z',
        'source': 'remote',
      },
      'bundle': {
        'weaponPresets': {
          'r700_308': {
            'muzzleVelocityMps': 799,
            'ballisticCoefficientG1': 0.47,
          },
        },
        'caliberFallbackPresets': {
          '.308 Win': {
            'muzzleVelocityMps': 790,
            'ballisticCoefficientG1': 0.45,
          },
        },
      },
      'bundleSha256': 'bad',
    });
    expect(
      () => BallisticPresetRepository.applyRemotePayloadJson(payload),
      throwsA(isA<FormatException>()),
    );
  });
}

