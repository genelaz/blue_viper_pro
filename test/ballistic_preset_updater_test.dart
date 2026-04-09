import 'dart:convert';

import 'package:blue_viper_pro/core/catalog/ballistic_preset_updater.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOkClient extends http.BaseClient {
  _FakeOkClient(this.body);
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream<List<int>>.fromIterable([body.codeUnits]), 200);
  }
}

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

  test('updateFromUrl rejects invalid url', () async {
    final res = await BallisticPresetUpdater.updateFromUrl('not-a-url');
    expect(res.success, isFalse);
  });

  test('updateFromUrl applies valid payload and persists url', () async {
    final bundle = {
      'weaponPresets': {
        'r700_308': {
          'muzzleVelocityMps': 801,
          'ballisticCoefficientG1': 0.48,
        },
      },
      'caliberFallbackPresets': {
        '.308 Win': {
          'muzzleVelocityMps': 790,
          'ballisticCoefficientG1': 0.45,
        },
      },
    };
    final digest = sha256.convert(utf8.encode(_canonicalJson(bundle))).toString();
    final payload = jsonEncode({
      'manifest': {
        'schemaVersion': 1,
        'dataVersion': 'remote-updater-v1',
        'updatedAt': '2026-04-09T13:00:00Z',
        'source': 'remote',
      },
      'bundle': bundle,
      'bundleSha256': digest,
    });

    final res = await BallisticPresetUpdater.updateFromUrl(
      'https://example.com/presets.json',
      httpClient: _FakeOkClient(payload),
    );
    expect(res.success, isTrue);
    final savedUrl = await BallisticPresetUpdater.getRemoteUrl();
    expect(savedUrl, 'https://example.com/presets.json');
  });

  test('updateFromUrl skips apply when dataVersion unchanged', () async {
    final bundle = {
      'weaponPresets': {
        'r700_308': {
          'muzzleVelocityMps': 801,
          'ballisticCoefficientG1': 0.48,
        },
      },
      'caliberFallbackPresets': {
        '.308 Win': {
          'muzzleVelocityMps': 790,
          'ballisticCoefficientG1': 0.45,
        },
      },
    };
    final digest = sha256.convert(utf8.encode(_canonicalJson(bundle))).toString();
    final payload = jsonEncode({
      'manifest': {
        'schemaVersion': 1,
        'dataVersion': 'same-version',
        'updatedAt': '2026-04-09T13:00:00Z',
        'source': 'remote',
      },
      'bundle': bundle,
      'bundleSha256': digest,
    });
    final first = await BallisticPresetUpdater.updateFromUrl(
      'https://example.com/presets.json',
      httpClient: _FakeOkClient(payload),
    );
    expect(first.success, isTrue);
    expect(first.skipped, isFalse);

    final second = await BallisticPresetUpdater.updateFromUrl(
      'https://example.com/presets.json',
      httpClient: _FakeOkClient(payload),
    );
    expect(second.success, isTrue);
    expect(second.skipped, isTrue);
    expect(second.dataVersion, 'same-version');

    final forced = await BallisticPresetUpdater.updateFromUrl(
      'https://example.com/presets.json',
      httpClient: _FakeOkClient(payload),
      force: true,
    );
    expect(forced.success, isTrue);
    expect(forced.skipped, isFalse);
    expect(forced.dataVersion, 'same-version');
  });
}

