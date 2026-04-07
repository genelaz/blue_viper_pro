import 'dart:convert';

import 'package:blue_viper_pro/core/profile/weapon_profile_store.dart';
import 'package:blue_viper_pro/core/sync/app_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    WeaponProfileStore.current.value = null;
  });

  test('collectPayload includes backupSchemaVersion', () async {
    final p = await AppBackupService.collectPayload();
    expect(p['backupSchemaVersion'], AppBackupService.backupSchemaVersion);
    expect(p['backupVersion'], AppBackupService.backupVersion);
  });

  test('restore rejects missing schema', () async {
    const json = '{"prefs":{}}';
    await expectLater(
      AppBackupService.restoreFromJson(json),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('şema'),
        ),
      ),
    );
  });

  test('restore rejects future schema', () async {
    final json = jsonEncode({
      'backupSchemaVersion': 999,
      'prefs': {},
    });
    await expectLater(
      AppBackupService.restoreFromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('restore accepts legacy backupVersion only', () async {
    final json = jsonEncode({
      'backupVersion': 1,
      'prefs': {'foo': 'bar'},
    });
    await AppBackupService.restoreFromJson(json);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('foo'), 'bar');
  });

  test('restore merge false clears prefs not in backup', () async {
    final p = await SharedPreferences.getInstance();
    await p.setString('only_before', 'gone');
    await p.setString('in_backup', 'old');
    final json = jsonEncode({
      'backupSchemaVersion': 1,
      'prefs': {'in_backup': 'new'},
    });
    await AppBackupService.restoreFromJson(json, merge: false);
    expect(p.getString('only_before'), isNull);
    expect(p.getString('in_backup'), 'new');
  });

  test('restore merge true keeps prefs not listed in backup', () async {
    final p = await SharedPreferences.getInstance();
    await p.setString('only_local', 'keep');
    final json = jsonEncode({
      'backupSchemaVersion': 1,
      'prefs': {'from_backup': 'y'},
    });
    await AppBackupService.restoreFromJson(json, merge: true);
    expect(p.getString('only_local'), 'keep');
    expect(p.getString('from_backup'), 'y');
  });
}
